import json
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from tracking.models import Trip
from tracking.live_engine import process_gps_ping, get_live_snapshot

class DriverTripConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket endpoint for Drivers to stream live GPS telemetry:
    ws://domain/ws/driver/trip/<trip_id>/?token=<driver_jwt>
    """
    async def connect(self):
        self.trip_id = int(self.scope['url_route']['kwargs']['trip_id'])
        user = self.scope.get('user')

        # Authentication and authorization checks
        if not user or not user.is_authenticated or user.is_blocked:
            await self.close(code=4001)
            return

        if user.role != 'driver' or not user.is_verified:
            await self.close(code=4003)
            return

        # Check driver owns active trip
        owns_trip = await self.check_driver_owns_trip(user, self.trip_id)
        if not owns_trip:
            await self.close(code=4003)
            return

        self.driver_group_name = f"driver_trip_{self.trip_id}"
        await self.channel_layer.group_add(self.driver_group_name, self.channel_name)
        await self.accept()

    @database_sync_to_async
    def check_driver_owns_trip(self, user, trip_id):
        return Trip.objects.filter(
            id=trip_id,
            driver__user=user,
            status='active'
        ).exists()

    async def disconnect(self, close_code):
        if hasattr(self, 'driver_group_name'):
            await self.channel_layer.group_discard(self.driver_group_name, self.channel_name)

    async def receive_json(self, content):
        lat = content.get('lat') if content.get('lat') is not None else content.get('latitude')
        lng = content.get('lng') if content.get('lng') is not None else content.get('longitude')
        speed = content.get('speed_kmh') if content.get('speed_kmh') is not None else content.get('speed', 0.0)
        heading = content.get('heading', 0.0)

        if lat is None or lng is None:
            await self.send_json({'error': 'lat and lng are required.'})
            return

        # Process GPS ping in memory & evaluate geofences
        payload = await process_gps_ping(self.trip_id, lat, lng, speed, heading)
        if not payload:
            await self.send_json({'error': 'Trip not active or not found.'})
            return

        route_id = payload['route_id']

        # Broadcast live location update to students tracking this route
        await self.channel_layer.group_send(
            f"route_{route_id}",
            {
                "type": "bus_location_broadcast",
                "data": payload
            }
        )

        # Broadcast to admin fleet monitor
        await self.channel_layer.group_send(
            "admin_fleet",
            {
                "type": "bus_location_broadcast",
                "data": payload
            }
        )

        # If a stop was skipped, broadcast alert to admin fleet
        if payload.get('stop_skip_alert'):
            await self.channel_layer.group_send(
                "admin_fleet",
                {
                    "type": "stop_skip_broadcast",
                    "alert": payload['stop_skip_alert']
                }
            )

        # Ack to driver
        await self.send_json({
            'status': 'ok',
            'trip_id': self.trip_id,
            'current_stop_order': payload['current_stop_order'],
            'stop_skip_alert': bool(payload.get('stop_skip_alert'))
        })


class RouteTrackingConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket endpoint for Students/Passengers to track live buses on a Route:
    ws://domain/ws/route/<route_id>/?token=<user_jwt>
    """
    async def connect(self):
        self.route_id = int(self.scope['url_route']['kwargs']['route_id'])
        user = self.scope.get('user')

        if not user or not user.is_authenticated or user.is_blocked:
            await self.close(code=4001)
            return

        self.route_group_name = f"route_{self.route_id}"
        await self.channel_layer.group_add(self.route_group_name, self.channel_name)
        await self.accept()

        # Send initial snapshot of all active buses on this route
        buses = get_live_snapshot(self.route_id)
        await self.send_json({
            'type': 'route_snapshot',
            'route_id': self.route_id,
            'buses': buses
        })

    async def disconnect(self, close_code):
        if hasattr(self, 'route_group_name'):
            await self.channel_layer.group_discard(self.route_group_name, self.channel_name)

    async def bus_location_broadcast(self, event):
        await self.send_json({
            'type': 'bus_location_update',
            'data': event['data']
        })

    async def trip_alert_broadcast(self, event):
        await self.send_json({
            'type': 'trip_alert',
            'alert': event['alert']
        })


class AdminFleetConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket endpoint for Admins to monitor entire fleet, stop-skip violations & emergency SOS alerts:
    ws://domain/ws/admin/fleet/?token=<admin_jwt>
    """
    async def connect(self):
        user = self.scope.get('user')

        if not user or not user.is_authenticated or user.is_blocked:
            await self.close(code=4001)
            return

        if user.role not in ['sub_admin', 'super_admin']:
            await self.close(code=4003)
            return

        self.fleet_group_name = "admin_fleet"
        await self.channel_layer.group_add(self.fleet_group_name, self.channel_name)
        await self.accept()

        # Send initial snapshot of all active buses across all routes
        all_buses = get_live_snapshot()
        await self.send_json({
            'type': 'fleet_snapshot',
            'total_active': len(all_buses),
            'buses': all_buses
        })

    async def disconnect(self, close_code):
        if hasattr(self, 'fleet_group_name'):
            await self.channel_layer.group_discard(self.fleet_group_name, self.channel_name)

    async def bus_location_broadcast(self, event):
        await self.send_json({
            'type': 'bus_location_update',
            'data': event['data']
        })

    async def stop_skip_broadcast(self, event):
        await self.send_json({
            'type': 'stop_skip_alert',
            'alert': event['alert']
        })

    async def trip_alert_broadcast(self, event):
        await self.send_json({
            'type': 'trip_alert',
            'alert': event['alert']
        })

    async def sos_alert_broadcast(self, event):
        await self.send_json({
            'type': 'sos_alert',
            'sos': event['sos']
        })

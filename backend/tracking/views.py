from rest_framework import views, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils import timezone
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from .models import Trip, TripStopEvent, TripAlert
from .serializers import TripSerializer, TripStopEventSerializer, TripAlertSerializer
from .utils import haversine_distance_km, calculate_eta_minutes
from .live_engine import LIVE_TRIPS, init_live_trip_sync, remove_live_trip
from accounts.permissions import IsVerifiedDriver, IsAdminStaff, IsNotBlocked
from transit.models import Route, Bus, Stop, RouteStop
from schedules.models import SlotBusAssignment, TimeSlot
from operations.models import EmergencySOS, ChangeRequest
from django.contrib.auth import get_user_model

User = get_user_model()

# --- Driver Endpoints ---

class DriverTripStartView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def post(self, request):
        driver_profile = request.user.driver_profile
        bus_id = request.data.get('bus_id')
        route_id = request.data.get('route_id')
        slot_assignment_id = request.data.get('slot_assignment_id')

        if not bus_id or not route_id:
            return Response({'detail': 'bus_id and route_id are required.'}, status=status.HTTP_400_BAD_REQUEST)

        bus = get_object_or_404(Bus, pk=bus_id)
        route = get_object_or_404(Route, pk=route_id)
        slot_assignment = SlotBusAssignment.objects.filter(pk=slot_assignment_id).first() if slot_assignment_id else None

        # Check if driver already has an active trip
        active_trip = Trip.objects.filter(driver=driver_profile, status='active').first()
        if active_trip:
            return Response(
                {'detail': 'Driver already has an active trip.', 'active_trip_id': active_trip.id},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Set driver status online
        driver_profile.duty_status = 'online'
        driver_profile.save(update_fields=['duty_status'])

        # Start location at origin hub
        initial_lat = route.origin_hub.latitude
        initial_lng = route.origin_hub.longitude

        trip = Trip.objects.create(
            slot_assignment=slot_assignment,
            route=route,
            bus=bus,
            driver=driver_profile,
            service_date=timezone.localdate(),
            status='active',
            started_at=timezone.now(),
            current_stop_order=1,
            crowd_status='seats_available',
            last_lat=initial_lat,
            last_lng=initial_lng,
            last_speed_kmh=0.0,
        )

        # Create started alert
        TripAlert.objects.create(
            trip=trip,
            alert_type='started',
            message=f"Bus #{bus.bus_number} departed from {route.origin_hub.name} on route {route.name}."
        )

        # Record departure from origin stop if exists
        first_route_stop = route.route_stops.order_by('sequence_order').first()
        if first_route_stop:
            TripStopEvent.objects.create(
                trip=trip,
                stop=first_route_stop.stop,
                event_type='departed',
                recorded_at=timezone.now(),
                speed_kmh=0.0,
                dwell_seconds=60,
            )

        # Initialize in-memory live tracking state (Write Shield)
        init_live_trip_sync(trip)

        ordered_stops = [
            {
                'sequence_order': rs.sequence_order,
                'stop_id': rs.stop.id,
                'stop_name': rs.stop.name,
                'latitude': rs.stop.latitude,
                'longitude': rs.stop.longitude,
                'avg_min_from_start': rs.avg_min_from_start,
                'distance_from_start_km': rs.distance_from_start_km,
            }
            for rs in route.route_stops.select_related('stop').order_by('sequence_order')
        ]

        return Response({
            'message': 'Trip started successfully.',
            'trip_id': trip.id,
            'route': {
                'id': route.id,
                'name': route.name,
                'polyline_json': route.polyline_json,
                'ordered_stops': ordered_stops,
            },
            'trip': TripSerializer(trip).data
        }, status=status.HTTP_201_CREATED)


class DriverTripStopView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def post(self, request, pk):
        driver_profile = request.user.driver_profile
        trip = get_object_or_404(Trip, pk=pk, driver=driver_profile, status='active')

        trip.status = 'completed'
        trip.ended_at = timezone.now()
        trip.save(update_fields=['status', 'ended_at'])

        # Remove from in-memory cache
        remove_live_trip(trip.id)

        # Set driver offline
        driver_profile.duty_status = 'offline'
        driver_profile.save(update_fields=['duty_status'])

        TripAlert.objects.create(
            trip=trip,
            alert_type='ended',
            message=f"Trip for Bus #{trip.bus.bus_number} completed successfully."
        )

        # Notify active clients that trip has ended
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"route_{trip.route.id}",
                {
                    "type": "trip_alert_broadcast",
                    "alert": {
                        "trip_id": trip.id,
                        "bus_number": trip.bus.bus_number,
                        "alert_type": "ended",
                        "message": f"Bus #{trip.bus.bus_number} completed its trip."
                    }
                }
            )

        return Response({
            'message': 'Trip ended successfully.',
            'trip': TripSerializer(trip).data
        })


class DriverTripCrowdStatusView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def patch(self, request, pk):
        driver_profile = request.user.driver_profile
        trip = get_object_or_404(Trip, pk=pk, driver=driver_profile, status='active')
        crowd_status = request.data.get('crowd_status')
        if crowd_status not in ['seats_available', 'standing', 'full']:
            return Response(
                {'detail': "Invalid crowd_status. Allowed: 'seats_available', 'standing', 'full'"},
                status=status.HTTP_400_BAD_REQUEST
            )
        trip.crowd_status = crowd_status
        trip.save(update_fields=['crowd_status'])
        return Response({'message': 'Crowd status updated.', 'crowd_status': trip.crowd_status})


class DriverTripAlertCreateView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def post(self, request, pk):
        driver_profile = request.user.driver_profile
        trip = get_object_or_404(Trip, pk=pk, driver=driver_profile, status='active')
        alert_type = request.data.get('alert_type')
        message = request.data.get('message', '')

        if alert_type not in ['breakdown', 'delay', 'message']:
            return Response(
                {'detail': "Invalid alert_type. Allowed: 'breakdown', 'delay', 'message'"},
                status=status.HTTP_400_BAD_REQUEST
            )

        alert = TripAlert.objects.create(
            trip=trip,
            alert_type=alert_type,
            message=message or f"Alert ({alert_type}) reported by driver."
        )

        # Broadcast live alert to route group and admin fleet
        channel_layer = get_channel_layer()
        if channel_layer:
            alert_data = {
                'trip_id': trip.id,
                'bus_number': trip.bus.bus_number,
                'route_id': trip.route.id,
                'route_name': trip.route.name,
                'alert_type': alert.alert_type,
                'message': alert.message,
                'created_at': alert.created_at.isoformat(),
            }
            async_to_sync(channel_layer.group_send)(
                f"route_{trip.route.id}",
                {"type": "trip_alert_broadcast", "alert": alert_data}
            )
            async_to_sync(channel_layer.group_send)(
                "admin_fleet",
                {"type": "trip_alert_broadcast", "alert": alert_data}
            )

        return Response(TripAlertSerializer(alert).data, status=status.HTTP_201_CREATED)


class DriverLocationUpdateView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def post(self, request, pk):
        driver_profile = request.user.driver_profile
        trip = get_object_or_404(Trip, pk=pk, driver=driver_profile, status='active')

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        speed = float(request.data.get('speed_kmh', 0.0))
        current_stop_order = request.data.get('current_stop_order')

        if lat is not None and lng is not None:
            trip.last_lat = float(lat)
            trip.last_lng = float(lng)
            trip.last_speed_kmh = speed

        if current_stop_order is not None:
            trip.current_stop_order = int(current_stop_order)

        trip.save(update_fields=['last_lat', 'last_lng', 'last_speed_kmh', 'current_stop_order'])

        # Record Stop event if passed
        stop_id = request.data.get('stop_id')
        event_type = request.data.get('event_type')  # arrived, departed, skipped
        if stop_id and event_type in ['arrived', 'departed', 'skipped']:
            stop = Stop.objects.filter(id=stop_id).first()
            if stop:
                dwell = int(request.data.get('dwell_seconds', 0))
                TripStopEvent.objects.create(
                    trip=trip,
                    stop=stop,
                    event_type=event_type,
                    recorded_at=timezone.now(),
                    speed_kmh=speed,
                    dwell_seconds=dwell
                )

        return Response({
            'message': 'Location and telemetry updated.',
            'last_lat': trip.last_lat,
            'last_lng': trip.last_lng,
            'current_stop_order': trip.current_stop_order
        })


class DriverActiveTripView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def get(self, request):
        driver_profile = request.user.driver_profile
        active_trip = Trip.objects.filter(driver=driver_profile, status='active').first()
        if not active_trip:
            return Response({'active_trip': None})
        return Response({'active_trip': TripSerializer(active_trip).data})


class DriverTripHistoryView(views.APIView):
    permission_classes = [IsVerifiedDriver]

    def get(self, request):
        driver_profile = request.user.driver_profile
        trips = Trip.objects.filter(driver=driver_profile).order_by('-started_at')[:30]
        return Response(TripSerializer(trips, many=True).data)


# --- Student Track-My-Train Stop Feed ---

class StudentStopFeedView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        stop_id = request.query_params.get('stop_id')
        if not stop_id:
            return Response({'detail': 'stop_id query parameter is required.'}, status=status.HTTP_400_BAD_REQUEST)

        target_stop = get_object_or_404(Stop, pk=stop_id)
        student_lat = float(request.query_params.get('lat')) if request.query_params.get('lat') else None
        student_lng = float(request.query_params.get('lng')) if request.query_params.get('lng') else None
        gender_filter = request.query_params.get('gender')
        tag_filter = request.query_params.get('tag')

        # Find all active trips today
        active_trips = Trip.objects.filter(
            status='active',
            service_date=timezone.localdate()
        ).select_related(
            'route', 'bus', 'bus__default_gender', 'driver__user',
            'slot_assignment__time_slot'
        ).prefetch_related(
            'route__route_stops__stop',
            'slot_assignment__tags',
            'stop_events__stop'
        )

        buses_feed = []

        for trip in active_trips:
            # Check in-memory live engine state for real-time telemetry (falling back to DB fields)
            live_state = LIVE_TRIPS.get(trip.id)
            current_order = (live_state['current_stop_order'] if live_state else trip.current_stop_order) or 1
            last_lat = (live_state['last_lat'] if live_state else trip.last_lat) or trip.route.origin_hub.latitude
            last_lng = (live_state['last_lng'] if live_state else trip.last_lng) or trip.route.origin_hub.longitude
            last_speed = (live_state['speed_kmh'] if live_state else trip.last_speed_kmh) or 0.0

            # Check if target stop is on this route
            route_stops = list(trip.route.route_stops.select_related('stop').order_by('sequence_order'))
            target_rs = next((rs for rs in route_stops if rs.stop_id == target_stop.id), None)
            if not target_rs:
                continue  # Stop not on this route

            target_order = target_rs.sequence_order

            # If the bus has already crossed the student's stop, exclude it
            if current_order > target_order:
                continue

            # Apply gender filter
            if gender_filter and trip.bus.default_gender.name.lower() != gender_filter.lower():
                continue

            # Apply tag filter
            tags = []
            if trip.slot_assignment:
                tags = [t.code for t in trip.slot_assignment.tags.all()]
            if tag_filter and tag_filter.upper() not in tags:
                continue

            # Distances and ETA using freshest real-time coordinates
            dist_to_stop = haversine_distance_km(
                last_lat, last_lng, target_stop.latitude, target_stop.longitude
            )
            dist_to_student = None
            if student_lat is not None and student_lng is not None:
                dist_to_student = haversine_distance_km(
                    last_lat, last_lng, student_lat, student_lng
                )

            eta_min = calculate_eta_minutes(dist_to_stop, last_speed)

            # Slot counters
            slot_info = None
            if trip.slot_assignment and trip.slot_assignment.time_slot:
                slot = trip.slot_assignment.time_slot
                total_buses = slot.bus_assignments.filter(is_active=True).count()
                dispatched_count = Trip.objects.filter(
                    slot_assignment__time_slot=slot, service_date=timezone.localdate()
                ).count()
                remaining_count = max(0, total_buses - dispatched_count)
                is_last_bus = bool(total_buses > 0 and remaining_count <= 1)
                slot_info = {
                    'slot_id': slot.id,
                    'departure_time': slot.departure_time.strftime('%I:%M %p'),
                    'total_buses': total_buses,
                    'dispatched_count': dispatched_count,
                    'remaining_count': remaining_count,
                    'is_last_bus': is_last_bus,
                }

            # Build full ordered stop timeline
            events_dict = {
                e.stop_id: e for e in trip.stop_events.all()
            }
            stop_timeline = []
            for rs in route_stops:
                if rs.sequence_order < current_order:
                    stop_status = 'crossed'
                elif rs.sequence_order == current_order:
                    stop_status = 'current'
                else:
                    stop_status = 'upcoming'

                event = events_dict.get(rs.stop_id)
                recorded_time = event.recorded_at.strftime('%I:%M %p') if event else None

                stop_timeline.append({
                    'sequence_order': rs.sequence_order,
                    'stop_id': rs.stop.id,
                    'stop_name': rs.stop.name,
                    'latitude': rs.stop.latitude,
                    'longitude': rs.stop.longitude,
                    'status': stop_status,
                    'is_student_target': (rs.stop_id == target_stop.id),
                    'recorded_at': recorded_time,
                })

            buses_feed.append({
                'trip_id': trip.id,
                'bus_number': trip.bus.bus_number,
                'plate_number': trip.bus.plate_number,
                'route_id': trip.route.id,
                'route_name': trip.route.name,
                'driver_name': trip.driver.user.name,
                'driver_phone': trip.driver.user.phone,
                'gender': trip.bus.default_gender.name,
                'tags': tags,
                'crowd_status': trip.crowd_status,
                'last_lat': last_lat,
                'last_lng': last_lng,
                'last_speed_kmh': last_speed,
                'distance_to_stop_km': dist_to_stop,
                'distance_to_student_km': dist_to_student,
                'eta_minutes': eta_min,
                'slot_info': slot_info,
                'stop_timeline': stop_timeline,
            })

        # Sort buses by nearest ETA
        buses_feed.sort(key=lambda x: x['eta_minutes'])

        return Response({
            'target_stop': {
                'id': target_stop.id,
                'name': target_stop.name,
                'latitude': target_stop.latitude,
                'longitude': target_stop.longitude,
            },
            'approaching_buses_count': len(buses_feed),
            'buses': buses_feed,
        })


# --- Admin Monitoring Endpoints ---

class AdminActiveTripsView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        active_trips = Trip.objects.filter(status='active').order_by('-started_at')
        return Response(TripSerializer(active_trips, many=True).data)


class AdminTripHistoryView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        date_param = request.query_params.get('date')
        trips = Trip.objects.all().order_by('-started_at')
        if date_param:
            trips = trips.filter(service_date=date_param)
        return Response(TripSerializer(trips[:50], many=True).data)


class AdminStopSkipAlertsView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        skipped_events = TripStopEvent.objects.filter(
            event_type='skipped'
        ).select_related('trip', 'trip__bus', 'stop').order_by('-recorded_at')[:50]
        serializer = TripStopEventSerializer(skipped_events, many=True)
        return Response(serializer.data)


class AdminAnalyticsSummaryView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        today = timezone.localdate()
        active_buses = Trip.objects.filter(status='active', service_date=today).count()
        total_students = User.objects.filter(role='student').count()
        total_drivers = User.objects.filter(role='driver').count()
        trips_today = Trip.objects.filter(service_date=today).count()
        open_sos = EmergencySOS.objects.filter(status='open').count()
        pending_approvals = ChangeRequest.objects.filter(status='pending').count()

        return Response({
            'active_buses': active_buses,
            'total_students': total_students,
            'total_drivers': total_drivers,
            'trips_today': trips_today,
            'open_sos': open_sos,
            'pending_approvals': pending_approvals,
        })

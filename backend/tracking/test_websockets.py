import datetime
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework_simplejwt.tokens import RefreshToken
from channels.testing import WebsocketCommunicator

from unitransit_backend.asgi import application
from accounts.models import DriverProfile, StudentProfile
from transit.models import Hub, RouteCategory, GenderCategory, Stop, Route, RouteStop, Bus
from schedules.models import ScheduleProfile, TimeSlot, SlotBusAssignment
from tracking.models import Trip, TripStopEvent
from tracking.live_engine import LIVE_TRIPS

User = get_user_model()

class WebSocketLiveTrackingTests(TestCase):
    def setUp(self):
        LIVE_TRIPS.clear()

        # Users
        self.super_admin = User.objects.create_superuser(
            email="admin_ws@test.com", password="AdminPassword123!", name="Admin WS",
            role="super_admin", is_staff=True, is_verified=True
        )
        self.driver_user = User.objects.create_user(
            email="driver_ws@test.com", password="DriverPassword123!", name="Driver WS",
            role="driver", is_verified=True
        )
        self.driver_profile = DriverProfile.objects.create(
            user=self.driver_user, cnic="31202-9999999-1", license_no="BWP-999", duty_status="online"
        )
        self.student_user = User.objects.create_user(
            email="student_ws@test.com", password="StudentPassword123!", name="Student WS",
            role="student", is_verified=True
        )
        self.student_profile = StudentProfile.objects.create(
            user=self.student_user, roll_no="CS-999", department="CS"
        )
        self.blocked_user = User.objects.create_user(
            email="blocked_ws@test.com", password="BlockedPassword123!", name="Blocked User",
            role="student", is_blocked=True
        )

        # Transit setup
        self.hub_ac = Hub.objects.create(code="AC", name="Abbasia Campus", latitude=29.398233, longitude=71.692013)
        self.hub_bjc = Hub.objects.create(code="BJC", name="Baghdad Campus", latitude=29.378301, longitude=71.756057)
        self.cat = RouteCategory.objects.create(slug="inter_campus", name="Inter Campus")
        self.gender = GenderCategory.objects.create(name="Boys")

        self.stop1 = Stop.objects.create(name="Abbasia", latitude=29.398233, longitude=71.692013, geofence_radius_m=70.0)
        self.stop2 = Stop.objects.create(name="Saddar Pully", latitude=29.392557, longitude=71.692327, geofence_radius_m=70.0)
        self.stop3 = Stop.objects.create(name="One Unit", latitude=29.390194, longitude=71.698230, geofence_radius_m=70.0)

        self.route = Route.objects.create(
            name="AC to BJC", origin_hub=self.hub_ac, destination_hub=self.hub_bjc,
            category=self.cat, distance_km=14.5, est_duration_min=35
        )
        RouteStop.objects.create(route=self.route, stop=self.stop1, sequence_order=1)
        RouteStop.objects.create(route=self.route, stop=self.stop2, sequence_order=2)
        RouteStop.objects.create(route=self.route, stop=self.stop3, sequence_order=3)

        self.bus = Bus.objects.create(bus_number="B101", capacity=50, default_gender=self.gender, assigned_driver=self.driver_profile)

        self.trip = Trip.objects.create(
            route=self.route, bus=self.bus, driver=self.driver_profile,
            service_date=timezone.localdate(), status='active', current_stop_order=1,
            last_lat=self.stop1.latitude, last_lng=self.stop1.longitude
        )

        # Generate tokens
        self.admin_token = str(RefreshToken.for_user(self.super_admin).access_token)
        self.driver_token = str(RefreshToken.for_user(self.driver_user).access_token)
        self.student_token = str(RefreshToken.for_user(self.student_user).access_token)
        self.blocked_token = str(RefreshToken.for_user(self.blocked_user).access_token)

    # 1. Unauthenticated or blocked users rejected
    async def test_01_unauthenticated_or_blocked_rejected(self):
        # Missing token
        comm_no_token = WebsocketCommunicator(application, f"/ws/route/{self.route.id}/")
        connected, code = await comm_no_token.connect()
        self.assertFalse(connected)
        await comm_no_token.disconnect()

        # Blocked user token
        comm_blocked = WebsocketCommunicator(application, f"/ws/route/{self.route.id}/?token={self.blocked_token}")
        connected, code = await comm_blocked.connect()
        self.assertFalse(connected)
        await comm_blocked.disconnect()

        # Student trying to connect to driver trip endpoint -> 4003 rejected
        comm_unauth_driver = WebsocketCommunicator(application, f"/ws/driver/trip/{self.trip.id}/?token={self.student_token}")
        connected, code = await comm_unauth_driver.connect()
        self.assertFalse(connected)
        self.assertEqual(code, 4003)
        await comm_unauth_driver.disconnect()

    # 2. Driver GPS inside Stop geofence at low speed -> Arrived event in DB & real-time broadcast to Student
    async def test_02_driver_geofence_arrival_and_student_broadcast(self):
        # Student connects to route stream
        comm_student = WebsocketCommunicator(application, f"/ws/route/{self.route.id}/?token={self.student_token}")
        connected, _ = await comm_student.connect()
        self.assertTrue(connected)
        init_msg = await comm_student.receive_json_from()
        self.assertEqual(init_msg['type'], 'route_snapshot')

        # Driver connects to trip stream
        comm_driver = WebsocketCommunicator(application, f"/ws/driver/trip/{self.trip.id}/?token={self.driver_token}")
        connected, _ = await comm_driver.connect()
        self.assertTrue(connected)

        # Driver sends GPS ping exactly at Saddar Pully (Stop 2) at 6 km/h (< 12 km/h)
        await comm_driver.send_json_to({
            'lat': 29.392557,
            'lng': 71.692327,
            'speed_kmh': 6.0,
            'heading': 180.0
        })

        # Driver receives confirmation
        ack = await comm_driver.receive_json_from()
        self.assertEqual(ack['status'], 'ok')
        self.assertEqual(ack['current_stop_order'], 2)

        # Student receives real-time broadcast
        broadcast = await comm_student.receive_json_from()
        self.assertEqual(broadcast['type'], 'bus_location_update')
        data = broadcast['data']
        self.assertEqual(data['trip_id'], self.trip.id)
        self.assertEqual(data['bus_number'], 'B101')
        self.assertEqual(data['current_stop_order'], 2)
        self.assertEqual(data['current_stop_name'], 'Saddar Pully')

        # Verify ONE TripStopEvent(event_type='arrived') was logged to SQLite3
        arrived_exists = await TripStopEvent.objects.filter(
            trip=self.trip, stop=self.stop2, event_type='arrived'
        ).aexists()
        self.assertTrue(arrived_exists)

        await comm_driver.disconnect()
        await comm_student.disconnect()

    # 3. Stop-Skip Violation Detection -> Logs 'skipped' in DB & broadcasts stop_skip_alert to Admin Fleet
    async def test_03_stop_skip_violation_and_admin_alert(self):
        # Admin connects to admin fleet monitor
        comm_admin = WebsocketCommunicator(application, f"/ws/admin/fleet/?token={self.admin_token}")
        connected, _ = await comm_admin.connect()
        self.assertTrue(connected)
        init_msg = await comm_admin.receive_json_from()
        self.assertEqual(init_msg['type'], 'fleet_snapshot')

        # Driver connects
        comm_driver = WebsocketCommunicator(application, f"/ws/driver/trip/{self.trip.id}/?token={self.driver_token}")
        connected, _ = await comm_driver.connect()
        self.assertTrue(connected)

        # Driver passes Stop 2 at high speed (35 km/h >= 25 km/h) without stopping
        await comm_driver.send_json_to({
            'lat': 29.392557,
            'lng': 71.692327,
            'speed_kmh': 35.0,
            'heading': 185.0
        })

        ack = await comm_driver.receive_json_from()
        self.assertEqual(ack['status'], 'ok')
        self.assertTrue(ack['stop_skip_alert'])

        # Admin receives bus location update AND stop_skip_alert
        msg1 = await comm_admin.receive_json_from()
        self.assertEqual(msg1['type'], 'bus_location_update')

        msg2 = await comm_admin.receive_json_from()
        self.assertEqual(msg2['type'], 'stop_skip_alert')
        alert = msg2['alert']
        self.assertEqual(alert['skipped_stop_name'], 'Saddar Pully')
        self.assertIn('bypassed', alert['message'].lower())

        # Verify TripStopEvent(event_type='skipped') was logged in SQLite3
        skipped_exists = await TripStopEvent.objects.filter(
            trip=self.trip, stop=self.stop2, event_type='skipped'
        ).aexists()
        self.assertTrue(skipped_exists)

        await comm_driver.disconnect()
        await comm_admin.disconnect()

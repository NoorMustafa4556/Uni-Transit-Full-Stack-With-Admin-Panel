import datetime
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status

from accounts.models import StudentProfile, DriverProfile
from transit.models import Hub, RouteCategory, RouteTag, GenderCategory, Stop, Route, RouteStop, Bus
from schedules.models import ScheduleProfile, TimeSlot, SlotBusAssignment
from tracking.models import Trip, TripStopEvent
from operations.models import ChangeRequest, AuditLog

User = get_user_model()

class UniTransitPhase2APITests(APITestCase):
    def setUp(self):
        # 1. Users
        self.super_admin = User.objects.create_superuser(
            email="superadmin@test.com", password="AdminPassword123!", name="Super Admin User"
        )
        self.sub_admin = User.objects.create_user(
            email="subadmin@test.com", password="SubPassword123!", name="Sub Admin User",
            role="sub_admin", is_staff=True, is_verified=True
        )
        self.driver_user = User.objects.create_user(
            email="driver@test.com", password="DriverPassword123!", name="Test Driver",
            role="driver", is_verified=True
        )
        self.driver_profile = DriverProfile.objects.create(
            user=self.driver_user, cnic="31202-0000000-1", license_no="BWP-123", duty_status="offline"
        )

        self.student_user = User.objects.create_user(
            email="student@test.com", password="StudentPassword123!", name="Test Student",
            role="student", is_verified=True
        )
        self.student_profile = StudentProfile.objects.create(
            user=self.student_user, roll_no="CS-001", department="CS", gender="Male"
        )

        self.blocked_user = User.objects.create_user(
            email="blocked@test.com", password="BlockedPassword123!", name="Blocked Student",
            role="student", is_blocked=True
        )

        # 2. Transit Setup
        self.hub_ac = Hub.objects.create(code="AC", name="Abbasia Campus", latitude=29.3982, longitude=71.6920)
        self.hub_bjc = Hub.objects.create(code="BJC", name="Baghdad Campus", latitude=29.3783, longitude=71.7560)
        self.category = RouteCategory.objects.create(slug="inter_campus", name="Inter Campus", is_active=True)
        self.gender_boys = GenderCategory.objects.create(name="Boys", is_active=True)
        self.tag_staff = RouteTag.objects.create(code="S", label="Staff Colony", is_active=True)

        self.stop1 = Stop.objects.create(name="Abbasia Stop", latitude=29.3982, longitude=71.6920)
        self.stop2 = Stop.objects.create(name="Saddar Pully", latitude=29.3925, longitude=71.6923)
        self.stop3 = Stop.objects.create(name="Baghdad Gate", latitude=29.3813, longitude=71.7357)

        self.route = Route.objects.create(
            name="AC to BJC", origin_hub=self.hub_ac, destination_hub=self.hub_bjc,
            category=self.category, distance_km=14.5, est_duration_min=35, is_active=True
        )
        RouteStop.objects.create(route=self.route, stop=self.stop1, sequence_order=1)
        RouteStop.objects.create(route=self.route, stop=self.stop2, sequence_order=2)
        RouteStop.objects.create(route=self.route, stop=self.stop3, sequence_order=3)

        self.bus1 = Bus.objects.create(bus_number="101", capacity=50, default_gender=self.gender_boys, assigned_driver=self.driver_profile)
        self.bus2 = Bus.objects.create(bus_number="102", capacity=50, default_gender=self.gender_boys)

        # 3. Schedule Profile & Slots
        self.profile = ScheduleProfile.objects.create(
            name="Active Spring Schedule", effective_from=datetime.date(2026, 1, 1), is_active=True
        )
        self.slot = TimeSlot.objects.create(
            profile=self.profile, route=self.route, shift="morning", day_type="weekday",
            departure_time=datetime.time(8, 0), is_active=True
        )
        self.assignment1 = SlotBusAssignment.objects.create(
            time_slot=self.slot, bus=self.bus1, driver=self.driver_profile,
            gender=self.gender_boys, dispatch_order=1, is_active=True
        )
        self.assignment2 = SlotBusAssignment.objects.create(
            time_slot=self.slot, bus=self.bus2,
            gender=self.gender_boys, dispatch_order=2, is_active=True
        )

    # TEST 1: JWT Login & Blocked User Rejection
    def test_01_jwt_login_and_blocked_user_rejection(self):
        # Successful student login
        resp = self.client.post('/api/v1/auth/login/', {
            'email': 'student@test.com',
            'password': 'StudentPassword123!'
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('tokens', resp.data)
        self.assertIn('access', resp.data['tokens'])
        self.assertEqual(resp.data['user']['name'], 'Test Student')

        # Blocked user login rejected with 403
        resp_blocked = self.client.post('/api/v1/auth/login/', {
            'email': 'blocked@test.com',
            'password': 'BlockedPassword123!'
        })
        self.assertEqual(resp_blocked.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('blocked', resp_blocked.data['detail'].lower())

    # TEST 2: Active Schedule Slots Counters
    def test_02_active_schedule_slots_live_counters(self):
        resp = self.client.get('/api/v1/schedules/active-slots/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data['slots']), 1)
        slot_data = resp.data['slots'][0]

        # 2 buses assigned, 0 dispatched today
        self.assertEqual(slot_data['total_buses'], 2)
        self.assertEqual(slot_data['dispatched_count'], 0)
        self.assertEqual(slot_data['remaining_count'], 2)
        self.assertFalse(slot_data['is_last_bus'])

        # Now simulate 1 bus dispatched today
        Trip.objects.create(
            slot_assignment=self.assignment1, route=self.route, bus=self.bus1,
            driver=self.driver_profile, service_date=timezone.localdate(), status='active'
        )

        resp2 = self.client.get('/api/v1/schedules/active-slots/')
        slot_data2 = resp2.data['slots'][0]
        self.assertEqual(slot_data2['total_buses'], 2)
        self.assertEqual(slot_data2['dispatched_count'], 1)
        self.assertEqual(slot_data2['remaining_count'], 1)
        self.assertTrue(slot_data2['is_last_bus'])  # remaining <= 1

    # TEST 3: Driver Trip Lifecycle & Student Live Bus Stop Feed (Track My Point)
    def test_03_driver_trip_lifecycle_and_student_stop_feed(self):
        # Driver starts trip
        self.client.force_authenticate(user=self.driver_user)
        start_resp = self.client.post('/api/v1/tracking/driver/trips/start/', {
            'bus_id': self.bus1.id,
            'route_id': self.route.id,
            'slot_assignment_id': self.assignment1.id
        })
        self.assertEqual(start_resp.status_code, status.HTTP_201_CREATED)
        trip_id = start_resp.data['trip_id']

        self.driver_profile.refresh_from_db()
        self.assertEqual(self.driver_profile.duty_status, 'online')

        # Driver updates GPS near Stop 1 heading to Stop 2
        loc_resp = self.client.post(f'/api/v1/tracking/driver/trips/{trip_id}/location/', {
            'latitude': 29.3950,
            'longitude': 71.6921,
            'speed_kmh': 35.0,
            'current_stop_order': 1,
        })
        self.assertEqual(loc_resp.status_code, status.HTTP_200_OK)

        # Student checks Live Bus Feed for Stop 2 (Saddar Pully)
        self.client.force_authenticate(user=None)  # Public or Student
        feed_resp = self.client.get(f'/api/v1/tracking/student/stop-feed/?stop_id={self.stop2.id}&lat=29.3925&lng=71.6923')
        self.assertEqual(feed_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(feed_resp.data['approaching_buses_count'], 1)

        bus_feed = feed_resp.data['buses'][0]
        self.assertEqual(bus_feed['bus_number'], '101')
        self.assertGreater(bus_feed['distance_to_stop_km'], 0)
        self.assertGreater(bus_feed['eta_minutes'], 0)
        self.assertEqual(len(bus_feed['stop_timeline']), 3)

        # First stop timeline should be current or crossed
        self.assertIn(bus_feed['stop_timeline'][0]['status'], ['current', 'crossed'])
        # Target stop (Stop 2) should be upcoming and target
        self.assertEqual(bus_feed['stop_timeline'][1]['status'], 'upcoming')
        self.assertTrue(bus_feed['stop_timeline'][1]['is_student_target'])

        # Driver ends trip
        self.client.force_authenticate(user=self.driver_user)
        stop_resp = self.client.post(f'/api/v1/tracking/driver/trips/{trip_id}/stop/')
        self.assertEqual(stop_resp.status_code, status.HTTP_200_OK)
        self.driver_profile.refresh_from_db()
        self.assertEqual(self.driver_profile.duty_status, 'offline')

    # TEST 4: Maker-Checker Workflow (Sub-Admin 202 -> Super-Admin Approval -> Live Mutation)
    def test_04_maker_checker_workflow(self):
        # 1. Sub-admin attempts to create a new Stop
        self.client.force_authenticate(user=self.sub_admin)
        create_resp = self.client.post('/api/v1/transit/stops/', {
            'name': 'Model Town C Chowk',
            'latitude': 29.3800,
            'longitude': 71.7100,
            'geofence_radius_m': 75.0,
            'is_active': True
        })

        # MUST return HTTP 202 Accepted and create a pending ChangeRequest
        self.assertEqual(create_resp.status_code, status.HTTP_202_ACCEPTED)
        self.assertIn('change_request', create_resp.data)
        cr_id = create_resp.data['change_request']['id']

        # Verify live Stop table was NOT mutated yet
        self.assertFalse(Stop.objects.filter(name='Model Town C Chowk').exists())

        # 2. Super-admin inspects approvals queue and approves the request
        self.client.force_authenticate(user=self.super_admin)
        queue_resp = self.client.get('/api/v1/operations/approvals/?status=pending')
        self.assertEqual(queue_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(any(item['id'] == cr_id for item in queue_resp.data))

        # Approve
        approve_resp = self.client.post(f'/api/v1/operations/approvals/{cr_id}/approve/', {
            'review_note': 'Approved after campus planning review.'
        })
        self.assertEqual(approve_resp.status_code, status.HTTP_200_OK)

        # 3. Verify live Stop table NOW has the new stop
        self.assertTrue(Stop.objects.filter(name='Model Town C Chowk').exists())
        new_stop = Stop.objects.get(name='Model Town C Chowk')
        self.assertEqual(new_stop.latitude, 29.3800)

        # 4. Verify AuditLog was recorded
        audit = AuditLog.objects.filter(actor=self.super_admin, action__contains='approve').first()
        self.assertIsNotNone(audit)
        self.assertIn('Approved after campus planning review', audit.details)

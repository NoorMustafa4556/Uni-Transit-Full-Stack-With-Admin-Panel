from rest_framework import serializers
from django.utils import timezone
from .models import ScheduleProfile, TimeSlot, SlotBusAssignment
from transit.serializers import RouteSerializer, BusSerializer, GenderCategorySerializer, RouteTagSerializer
from tracking.models import Trip

class ScheduleProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = ScheduleProfile
        fields = ['id', 'name', 'effective_from', 'is_active']


class SlotBusAssignmentSerializer(serializers.ModelSerializer):
    bus_number = serializers.CharField(source='bus.bus_number', read_only=True)
    plate_number = serializers.CharField(source='bus.plate_number', read_only=True)
    gender_name = serializers.CharField(source='gender.name', read_only=True)
    tags_list = RouteTagSerializer(source='tags', many=True, read_only=True)
    driver_name = serializers.CharField(source='driver.user.name', read_only=True, default=None)
    is_dispatched = serializers.SerializerMethodField()
    active_trip_id = serializers.SerializerMethodField()

    class Meta:
        model = SlotBusAssignment
        fields = [
            'id', 'time_slot', 'bus', 'bus_number', 'plate_number',
            'driver', 'driver_name', 'gender', 'gender_name',
            'tags', 'tags_list', 'dispatch_order', 'is_active',
            'is_dispatched', 'active_trip_id'
        ]

    def get_is_dispatched(self, obj):
        today = timezone.localdate()
        return Trip.objects.filter(slot_assignment=obj, service_date=today).exists()

    def get_active_trip_id(self, obj):
        today = timezone.localdate()
        trip = Trip.objects.filter(slot_assignment=obj, service_date=today, status='active').first()
        return trip.id if trip else None


class TimeSlotSerializer(serializers.ModelSerializer):
    route_name = serializers.CharField(source='route.name', read_only=True)
    origin_hub = serializers.CharField(source='route.origin_hub.name', read_only=True)
    destination_hub = serializers.CharField(source='route.destination_hub.name', read_only=True)
    bus_assignments = SlotBusAssignmentSerializer(many=True, read_only=True)

    # Live counters computed dynamically for today
    total_buses = serializers.SerializerMethodField()
    dispatched_count = serializers.SerializerMethodField()
    remaining_count = serializers.SerializerMethodField()
    is_last_bus = serializers.SerializerMethodField()

    class Meta:
        model = TimeSlot
        fields = [
            'id', 'profile', 'route', 'route_name', 'origin_hub', 'destination_hub',
            'shift', 'day_type', 'departure_time', 'is_active',
            'total_buses', 'dispatched_count', 'remaining_count', 'is_last_bus',
            'bus_assignments'
        ]

    def get_total_buses(self, obj):
        return obj.bus_assignments.filter(is_active=True).count()

    def get_dispatched_count(self, obj):
        today = timezone.localdate()
        return Trip.objects.filter(slot_assignment__time_slot=obj, service_date=today).count()

    def get_remaining_count(self, obj):
        total = self.get_total_buses(obj)
        dispatched = self.get_dispatched_count(obj)
        return max(0, total - dispatched)

    def get_is_last_bus(self, obj):
        total = self.get_total_buses(obj)
        remaining = self.get_remaining_count(obj)
        return bool(total > 0 and remaining <= 1)

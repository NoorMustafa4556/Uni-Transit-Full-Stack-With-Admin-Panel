from rest_framework import serializers
from .models import Trip, TripStopEvent, TripAlert
from transit.serializers import RouteSerializer, BusSerializer, StopSerializer
from accounts.serializers import UserSerializer

class TripStopEventSerializer(serializers.ModelSerializer):
    stop_name = serializers.CharField(source='stop.name', read_only=True)

    class Meta:
        model = TripStopEvent
        fields = ['id', 'stop', 'stop_name', 'event_type', 'recorded_at', 'speed_kmh', 'dwell_seconds']


class TripAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = TripAlert
        fields = ['id', 'alert_type', 'message', 'created_at']


class TripSerializer(serializers.ModelSerializer):
    route_name = serializers.CharField(source='route.name', read_only=True)
    bus_number = serializers.CharField(source='bus.bus_number', read_only=True)
    plate_number = serializers.CharField(source='bus.plate_number', read_only=True)
    gender_name = serializers.CharField(source='bus.default_gender.name', read_only=True)
    driver_name = serializers.CharField(source='driver.user.name', read_only=True)
    driver_phone = serializers.CharField(source='driver.user.phone', read_only=True)
    stop_events = TripStopEventSerializer(many=True, read_only=True)
    alerts = TripAlertSerializer(many=True, read_only=True)

    class Meta:
        model = Trip
        fields = [
            'id', 'slot_assignment', 'route', 'route_name',
            'bus', 'bus_number', 'plate_number', 'gender_name',
            'driver', 'driver_name', 'driver_phone',
            'service_date', 'status', 'started_at', 'ended_at',
            'current_stop_order', 'crowd_status',
            'last_lat', 'last_lng', 'last_speed_kmh',
            'stop_events', 'alerts'
        ]

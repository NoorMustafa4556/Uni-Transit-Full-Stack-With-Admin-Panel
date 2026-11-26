from rest_framework import serializers
from .models import Hub, RouteCategory, RouteTag, GenderCategory, Stop, Route, RouteStop, Bus
from accounts.models import DriverProfile

class HubSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hub
        fields = ['id', 'code', 'name', 'latitude', 'longitude', 'is_active']


class RouteCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = RouteCategory
        fields = ['id', 'slug', 'name', 'is_active']


class RouteTagSerializer(serializers.ModelSerializer):
    class Meta:
        model = RouteTag
        fields = ['id', 'code', 'label', 'color_hex', 'is_active']


class GenderCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = GenderCategory
        fields = ['id', 'name', 'color_hex', 'is_active']


class StopSerializer(serializers.ModelSerializer):
    class Meta:
        model = Stop
        fields = ['id', 'name', 'latitude', 'longitude', 'geofence_radius_m', 'is_active']


class RouteStopSerializer(serializers.ModelSerializer):
    stop_name = serializers.CharField(source='stop.name', read_only=True)
    stop_lat = serializers.FloatField(source='stop.latitude', read_only=True)
    stop_lng = serializers.FloatField(source='stop.longitude', read_only=True)

    class Meta:
        model = RouteStop
        fields = [
            'id', 'stop', 'stop_name', 'stop_lat', 'stop_lng',
            'sequence_order', 'avg_min_from_start', 'distance_from_start_km'
        ]


class RouteSerializer(serializers.ModelSerializer):
    origin_hub_details = HubSerializer(source='origin_hub', read_only=True)
    destination_hub_details = HubSerializer(source='destination_hub', read_only=True)
    category_details = RouteCategorySerializer(source='category', read_only=True)
    route_stops = RouteStopSerializer(many=True, read_only=True)

    class Meta:
        model = Route
        fields = [
            'id', 'name', 'origin_hub', 'destination_hub', 'category',
            'origin_hub_details', 'destination_hub_details', 'category_details',
            'polyline_json', 'distance_km', 'est_duration_min', 'is_active', 'route_stops'
        ]


class BusSerializer(serializers.ModelSerializer):
    default_gender_name = serializers.CharField(source='default_gender.name', read_only=True)
    driver_name = serializers.CharField(source='assigned_driver.user.name', read_only=True)

    class Meta:
        model = Bus
        fields = [
            'id', 'bus_number', 'plate_number', 'capacity',
            'default_gender', 'default_gender_name',
            'assigned_driver', 'driver_name', 'status'
        ]

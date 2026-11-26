from django.contrib import admin
from .models import Hub, RouteCategory, RouteTag, GenderCategory, Stop, Route, RouteStop, Bus

class RouteStopInline(admin.TabularInline):
    model = RouteStop
    extra = 1
    ordering = ('sequence_order',)

@admin.register(Hub)
class HubAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'latitude', 'longitude', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('code', 'name')

@admin.register(RouteCategory)
class RouteCategoryAdmin(admin.ModelAdmin):
    list_display = ('slug', 'name', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('slug', 'name')

@admin.register(RouteTag)
class RouteTagAdmin(admin.ModelAdmin):
    list_display = ('code', 'label', 'color_hex', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('code', 'label')

@admin.register(GenderCategory)
class GenderCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'color_hex', 'is_active')
    list_filter = ('is_active',)

@admin.register(Stop)
class StopAdmin(admin.ModelAdmin):
    list_display = ('name', 'latitude', 'longitude', 'geofence_radius_m', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name',)

@admin.register(Route)
class RouteAdmin(admin.ModelAdmin):
    list_display = ('name', 'origin_hub', 'destination_hub', 'category', 'distance_km', 'est_duration_min', 'is_active')
    list_filter = ('category', 'is_active')
    search_fields = ('name',)
    inlines = [RouteStopInline]

@admin.register(RouteStop)
class RouteStopAdmin(admin.ModelAdmin):
    list_display = ('route', 'sequence_order', 'stop', 'avg_min_from_start', 'distance_from_start_km')
    list_filter = ('route',)
    ordering = ('route', 'sequence_order')

@admin.register(Bus)
class BusAdmin(admin.ModelAdmin):
    list_display = ('bus_number', 'plate_number', 'capacity', 'default_gender', 'assigned_driver', 'status')
    list_filter = ('status', 'default_gender')
    search_fields = ('bus_number', 'plate_number')

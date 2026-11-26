from django.contrib import admin
from .models import Trip, TripStopEvent, TripAlert

class TripStopEventInline(admin.TabularInline):
    model = TripStopEvent
    extra = 0
    readonly_fields = ('stop', 'event_type', 'recorded_at', 'speed_kmh', 'dwell_seconds')

class TripAlertInline(admin.TabularInline):
    model = TripAlert
    extra = 0

@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = ('id', 'route', 'bus', 'driver', 'service_date', 'status', 'crowd_status', 'started_at', 'ended_at')
    list_filter = ('status', 'crowd_status', 'service_date')
    search_fields = ('route__name', 'bus__bus_number', 'driver__user__name')
    inlines = [TripStopEventInline, TripAlertInline]

@admin.register(TripStopEvent)
class TripStopEventAdmin(admin.ModelAdmin):
    list_display = ('trip', 'stop', 'event_type', 'recorded_at', 'speed_kmh', 'dwell_seconds')
    list_filter = ('event_type',)
    search_fields = ('trip__id', 'stop__name')

@admin.register(TripAlert)
class TripAlertAdmin(admin.ModelAdmin):
    list_display = ('trip', 'alert_type', 'message', 'created_at')
    list_filter = ('alert_type',)
    search_fields = ('trip__id', 'message')

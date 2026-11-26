from django.contrib import admin
from .models import ScheduleProfile, TimeSlot, SlotBusAssignment

class SlotBusAssignmentInline(admin.TabularInline):
    model = SlotBusAssignment
    extra = 1

@admin.register(ScheduleProfile)
class ScheduleProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'effective_from', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name',)

@admin.register(TimeSlot)
class TimeSlotAdmin(admin.ModelAdmin):
    list_display = ('route', 'departure_time', 'shift', 'day_type', 'profile', 'is_active')
    list_filter = ('shift', 'day_type', 'is_active', 'profile')
    search_fields = ('route__name',)
    inlines = [SlotBusAssignmentInline]

@admin.register(SlotBusAssignment)
class SlotBusAssignmentAdmin(admin.ModelAdmin):
    list_display = ('time_slot', 'bus', 'driver', 'gender', 'dispatch_order', 'is_active')
    list_filter = ('gender', 'is_active')
    search_fields = ('bus__bus_number', 'driver__user__name')

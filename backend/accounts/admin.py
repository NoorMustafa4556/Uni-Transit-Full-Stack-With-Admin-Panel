from django.contrib import admin
from .models import User, StudentProfile, DriverProfile

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('email', 'name', 'phone', 'role', 'is_verified', 'is_blocked', 'is_staff')
    list_filter = ('role', 'is_verified', 'is_blocked', 'is_staff')
    search_fields = ('email', 'name', 'phone')
    ordering = ('email',)

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'roll_no', 'department', 'semester', 'gender', 'default_stop')
    list_filter = ('gender', 'department', 'semester')
    search_fields = ('user__name', 'user__email', 'roll_no', 'reg_no')

@admin.register(DriverProfile)
class DriverProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'license_no', 'cnic', 'duty_status', 'license_expiry')
    list_filter = ('duty_status',)
    search_fields = ('user__name', 'user__email', 'cnic', 'license_no')

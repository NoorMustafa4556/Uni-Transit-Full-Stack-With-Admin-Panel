from django.contrib import admin
from .models import (
    ChangeRequest, EmergencySOS, SupportTicket,
    Notification, AuditLog, TransportContact, Faq, AppConfig
)

@admin.register(ChangeRequest)
class ChangeRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'entity_type', 'action', 'requested_by', 'status', 'reviewed_by', 'created_at')
    list_filter = ('entity_type', 'action', 'status')
    search_fields = ('requested_by__name', 'requested_by__email', 'entity_id')

@admin.register(EmergencySOS)
class EmergencySOSAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'trip', 'status', 'created_at', 'resolved_by')
    list_filter = ('status', 'created_at')
    search_fields = ('user__name', 'user__email', 'message')

@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'issue', 'status', 'user_read', 'admin_read', 'created_at')
    list_filter = ('status', 'user_read', 'admin_read')
    search_fields = ('user__name', 'user__email', 'issue')

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('title', 'target_role', 'target_user', 'notification_type', 'is_read', 'created_at')
    list_filter = ('target_role', 'is_read')
    search_fields = ('title', 'message')

@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('created_at', 'actor', 'action', 'target')
    list_filter = ('action', 'created_at')
    search_fields = ('actor__name', 'actor__email', 'target', 'details')

@admin.register(TransportContact)
class TransportContactAdmin(admin.ModelAdmin):
    list_display = ('route_scope', 'shift', 'phone_number', 'is_whatsapp', 'is_active')
    list_filter = ('shift', 'is_whatsapp', 'is_active')
    search_fields = ('route_scope', 'phone_number')

@admin.register(Faq)
class FaqAdmin(admin.ModelAdmin):
    list_display = ('question', 'category', 'order', 'is_active')
    list_filter = ('category', 'is_active')
    search_fields = ('question', 'answer')

@admin.register(AppConfig)
class AppConfigAdmin(admin.ModelAdmin):
    list_display = ('app_name', 'university', 'version', 'complaint_whatsapp')

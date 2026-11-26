from rest_framework import serializers
from .models import (
    ChangeRequest, EmergencySOS, SupportTicket,
    Notification, AuditLog, TransportContact, Faq, AppConfig
)

class ChangeRequestSerializer(serializers.ModelSerializer):
    requested_by_name = serializers.CharField(source='requested_by.name', read_only=True)
    reviewed_by_name = serializers.CharField(source='reviewed_by.name', read_only=True, default=None)

    class Meta:
        model = ChangeRequest
        fields = [
            'id', 'requested_by', 'requested_by_name',
            'entity_type', 'entity_id', 'action', 'payload_json',
            'status', 'reviewed_by', 'reviewed_by_name', 'review_note',
            'created_at', 'reviewed_at'
        ]
        read_only_fields = ['id', 'requested_by', 'status', 'reviewed_by', 'reviewed_at', 'created_at']


class EmergencySOSSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.name', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    resolved_by_name = serializers.CharField(source='resolved_by.name', read_only=True, default=None)

    class Meta:
        model = EmergencySOS
        fields = [
            'id', 'user', 'user_name', 'user_phone', 'trip',
            'latitude', 'longitude', 'message', 'status',
            'resolved_by', 'resolved_by_name', 'review_rating', 'review_comment',
            'created_at', 'resolved_at'
        ]
        read_only_fields = ['id', 'user', 'status', 'resolved_by', 'resolved_at', 'created_at']


class SupportTicketSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.name', read_only=True)
    user_role = serializers.CharField(source='user.role', read_only=True)

    class Meta:
        model = SupportTicket
        fields = [
            'id', 'user', 'user_name', 'user_role', 'trip', 'issue',
            'status', 'admin_reply', 'user_read', 'admin_read',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'user_read', 'admin_read', 'created_at', 'updated_at']


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id', 'title', 'message', 'notification_type',
            'target_role', 'target_user', 'image', 'is_read', 'created_at'
        ]


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.name', read_only=True, default="System")
    actor_email = serializers.CharField(source='actor.email', read_only=True, default=None)

    class Meta:
        model = AuditLog
        fields = ['id', 'actor', 'actor_name', 'actor_email', 'action', 'target', 'details', 'created_at']


class TransportContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = TransportContact
        fields = ['id', 'shift', 'route_scope', 'phone_number', 'is_whatsapp', 'is_active']


class FaqSerializer(serializers.ModelSerializer):
    class Meta:
        model = Faq
        fields = ['id', 'question', 'answer', 'category', 'order', 'is_active']


class AppConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppConfig
        fields = [
            'app_name', 'tagline', 'university', 'version',
            'primary_color', 'accent_color', 'complaint_whatsapp', 'extra_json'
        ]

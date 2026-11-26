from django.db import models
from django.conf import settings

class ChangeRequest(models.Model):
    ENTITY_TYPE_CHOICES = [
        ('hub', 'Hub'),
        ('stop', 'Stop'),
        ('route', 'Route'),
        ('route_category', 'Route Category'),
        ('schedule_profile', 'Schedule Profile'),
        ('time_slot', 'Time Slot'),
        ('slot_assignment', 'Slot Assignment'),
    ]

    ACTION_CHOICES = [
        ('create', 'Create'),
        ('update', 'Update'),
        ('delete', 'Delete'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    requested_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='change_requests')
    entity_type = models.CharField(max_length=30, choices=ENTITY_TYPE_CHOICES)
    entity_id = models.CharField(max_length=50, null=True, blank=True)
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    payload_json = models.JSONField(default=dict)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reviewed_change_requests'
    )
    review_note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"CR #{self.id}: {self.action} {self.entity_type} ({self.get_status_display()})"


class EmergencySOS(models.Model):
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('resolved', 'Resolved'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='emergency_sos_list')
    trip = models.ForeignKey('tracking.Trip', on_delete=models.SET_NULL, null=True, blank=True, related_name='sos_alerts')
    latitude = models.FloatField()
    longitude = models.FloatField()
    message = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='resolved_sos_list'
    )
    review_rating = models.IntegerField(null=True, blank=True)
    review_comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Emergency SOS"
        verbose_name_plural = "Emergency SOS Alerts"

    def __str__(self):
        return f"SOS #{self.id} by {self.user.name} - {self.get_status_display()}"


class SupportTicket(models.Model):
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='support_tickets')
    trip = models.ForeignKey('tracking.Trip', on_delete=models.SET_NULL, null=True, blank=True, related_name='support_tickets')
    issue = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    admin_reply = models.TextField(blank=True)
    user_read = models.BooleanField(default=False)
    admin_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Ticket #{self.id} ({self.user.name}) - {self.get_status_display()}"


class Notification(models.Model):
    TARGET_ROLE_CHOICES = [
        ('all', 'All Users'),
        ('student', 'Students Only'),
        ('driver', 'Drivers Only'),
        ('admin', 'Admins Only'),
    ]

    title = models.CharField(max_length=150)
    message = models.TextField()
    notification_type = models.CharField(max_length=50, default='general')
    target_role = models.CharField(max_length=20, choices=TARGET_ROLE_CHOICES, default='all')
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='personal_notifications'
    )
    image = models.ImageField(upload_to='notifications/', blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification: {self.title} ({self.target_role})"


class AuditLog(models.Model):
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='audit_logs'
    )
    action = models.CharField(max_length=100)
    target = models.CharField(max_length=150)
    details = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        actor_name = self.actor.name if self.actor else "System"
        return f"{self.created_at.strftime('%Y-%m-%d %H:%M')} | {actor_name}: {self.action} on {self.target}"


class TransportContact(models.Model):
    shift = models.CharField(max_length=50, help_text="e.g. Morning, Evening, General")
    route_scope = models.CharField(max_length=150, help_text="e.g. AC to BJC/KHFC, BJC to AC, Complaint WhatsApp")
    phone_number = models.CharField(max_length=30)
    is_whatsapp = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.route_scope} ({self.shift}): {self.phone_number}"


class Faq(models.Model):
    question = models.CharField(max_length=255)
    answer = models.TextField()
    category = models.CharField(max_length=100, default='General')
    order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['order', 'id']

    def __str__(self):
        return self.question


class AppConfig(models.Model):
    app_name = models.CharField(max_length=100, default='UniTransit')
    tagline = models.CharField(max_length=200, default='IUB Smart University Bus Tracking System')
    university = models.CharField(max_length=150, default='The Islamia University of Bahawalpur')
    version = models.CharField(max_length=50, default='1.0.0')
    primary_color = models.CharField(max_length=20, default='#1E88E5')
    accent_color = models.CharField(max_length=20, default='#FFC107')
    complaint_whatsapp = models.CharField(max_length=30, default='0300-6809094')
    extra_json = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name = "App Configuration"
        verbose_name_plural = "App Configuration"

    def save(self, *args, **kwargs):
        # Enforce singleton
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def get_config(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj

    def __str__(self):
        return f"{self.app_name} Configuration (v{self.version})"

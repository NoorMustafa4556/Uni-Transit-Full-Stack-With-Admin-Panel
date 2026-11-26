from django.db import models
from django.utils import timezone

class Trip(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('aborted', 'Aborted'),
    ]

    CROWD_STATUS_CHOICES = [
        ('seats_available', 'Seats Available'),
        ('standing', 'Standing'),
        ('full', 'Full / Overcrowded'),
    ]

    slot_assignment = models.ForeignKey(
        'schedules.SlotBusAssignment',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='trips'
    )
    route = models.ForeignKey('transit.Route', on_delete=models.CASCADE, related_name='trips')
    bus = models.ForeignKey('transit.Bus', on_delete=models.CASCADE, related_name='trips')
    driver = models.ForeignKey('accounts.DriverProfile', on_delete=models.CASCADE, related_name='trips')
    service_date = models.DateField(default=timezone.localdate)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    started_at = models.DateTimeField(default=timezone.now)
    ended_at = models.DateTimeField(null=True, blank=True)
    current_stop_order = models.IntegerField(default=0)
    crowd_status = models.CharField(max_length=30, choices=CROWD_STATUS_CHOICES, default='seats_available')
    last_lat = models.FloatField(null=True, blank=True)
    last_lng = models.FloatField(null=True, blank=True)
    last_speed_kmh = models.FloatField(default=0.0)

    def __str__(self):
        return f"Trip {self.id}: {self.route.name} (Bus #{self.bus.bus_number}) - {self.get_status_display()}"


class TripStopEvent(models.Model):
    EVENT_TYPE_CHOICES = [
        ('arrived', 'Arrived'),
        ('departed', 'Departed'),
        ('skipped', 'Skipped'),
    ]

    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='stop_events')
    stop = models.ForeignKey('transit.Stop', on_delete=models.CASCADE, related_name='trip_events')
    event_type = models.CharField(max_length=20, choices=EVENT_TYPE_CHOICES)
    recorded_at = models.DateTimeField(default=timezone.now)
    speed_kmh = models.FloatField(default=0.0)
    dwell_seconds = models.IntegerField(default=0)

    class Meta:
        ordering = ['recorded_at']

    def __str__(self):
        return f"Trip #{self.trip_id} - Stop {self.stop.name}: {self.event_type} at {self.recorded_at.strftime('%H:%M:%S')}"


class TripAlert(models.Model):
    ALERT_TYPE_CHOICES = [
        ('started', 'Started'),
        ('ended', 'Ended'),
        ('breakdown', 'Breakdown'),
        ('delay', 'Delay'),
        ('message', 'Message'),
    ]

    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='alerts')
    alert_type = models.CharField(max_length=30, choices=ALERT_TYPE_CHOICES)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Trip #{self.trip_id} [{self.alert_type}]: {self.message[:40]}"

from django.db import models

class ScheduleProfile(models.Model):
    name = models.CharField(max_length=150)
    effective_from = models.DateField()
    is_active = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if self.is_active:
            # Ensure saving is_active=True deactivates other profiles
            ScheduleProfile.objects.filter(is_active=True).exclude(pk=self.pk).update(is_active=False)
        super().save(*args, **kwargs)

    def __str__(self):
        status = "Active" if self.is_active else "Inactive"
        return f"{self.name} (w.e.f {self.effective_from}) [{status}]"


class TimeSlot(models.Model):
    SHIFT_CHOICES = [
        ('morning', 'Morning'),
        ('evening', 'Evening'),
    ]

    DAY_TYPE_CHOICES = [
        ('weekday', 'Weekday (Mon - Fri)'),
        ('saturday_offday', 'Saturday / Off Day'),
    ]

    profile = models.ForeignKey(ScheduleProfile, on_delete=models.CASCADE, related_name='time_slots')
    route = models.ForeignKey('transit.Route', on_delete=models.CASCADE, related_name='time_slots')
    shift = models.CharField(max_length=20, choices=SHIFT_CHOICES)
    day_type = models.CharField(max_length=30, choices=DAY_TYPE_CHOICES, default='weekday')
    departure_time = models.TimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['departure_time', 'shift']

    def __str__(self):
        return f"{self.route.name} | {self.departure_time.strftime('%I:%M %p')} ({self.get_shift_display()})"


class SlotBusAssignment(models.Model):
    time_slot = models.ForeignKey(TimeSlot, on_delete=models.CASCADE, related_name='bus_assignments')
    bus = models.ForeignKey('transit.Bus', on_delete=models.CASCADE, related_name='slot_assignments')
    driver = models.ForeignKey(
        'accounts.DriverProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='slot_assignments'
    )
    gender = models.ForeignKey('transit.GenderCategory', on_delete=models.PROTECT, related_name='slot_assignments')
    tags = models.ManyToManyField('transit.RouteTag', blank=True, related_name='slot_assignments')
    dispatch_order = models.PositiveIntegerField(default=1)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['dispatch_order']

    def __str__(self):
        return f"Slot: {self.time_slot} -> Bus #{self.bus.bus_number} (Order: {self.dispatch_order})"

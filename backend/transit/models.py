from django.db import models

class Hub(models.Model):
    code = models.CharField(max_length=20, unique=True, help_text="e.g. AC, BJC, KHFC, FG")
    name = models.CharField(max_length=150)
    latitude = models.FloatField()
    longitude = models.FloatField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.name} ({self.code})"


class RouteCategory(models.Model):
    slug = models.SlugField(max_length=50, unique=True, help_text="e.g. inter_campus, out_city, shuttle")
    name = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "Route categories"

    def __str__(self):
        return self.name


class RouteTag(models.Model):
    code = models.CharField(max_length=20, unique=True, help_text="e.g. S, SB, R, I, B")
    label = models.CharField(max_length=100)
    color_hex = models.CharField(max_length=20, default="#1E88E5")
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.code} - {self.label}"


class GenderCategory(models.Model):
    name = models.CharField(max_length=50, unique=True, help_text="e.g. Boys, Girls, Combined")
    color_hex = models.CharField(max_length=20, default="#000000")
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "Gender categories"

    def __str__(self):
        return self.name


class Stop(models.Model):
    name = models.CharField(max_length=150)
    latitude = models.FloatField()
    longitude = models.FloatField()
    geofence_radius_m = models.FloatField(default=70.0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class Route(models.Model):
    name = models.CharField(max_length=150)
    origin_hub = models.ForeignKey(Hub, on_delete=models.PROTECT, related_name='origin_routes')
    destination_hub = models.ForeignKey(Hub, on_delete=models.PROTECT, related_name='destination_routes')
    category = models.ForeignKey(RouteCategory, on_delete=models.PROTECT, related_name='routes')
    polyline_json = models.JSONField(default=list, blank=True)
    distance_km = models.FloatField(default=0.0)
    est_duration_min = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.name} ({self.origin_hub.code} -> {self.destination_hub.code})"


class RouteStop(models.Model):
    route = models.ForeignKey(Route, on_delete=models.CASCADE, related_name='route_stops')
    stop = models.ForeignKey(Stop, on_delete=models.CASCADE, related_name='stop_routes')
    sequence_order = models.PositiveIntegerField()
    avg_min_from_start = models.IntegerField(default=0)
    distance_from_start_km = models.FloatField(default=0.0)

    class Meta:
        unique_together = ('route', 'sequence_order')
        ordering = ['route', 'sequence_order']

    def __str__(self):
        return f"{self.route.name} - Stop #{self.sequence_order}: {self.stop.name}"


class Bus(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('maintenance', 'Maintenance'),
        ('inactive', 'Inactive'),
    ]

    bus_number = models.CharField(max_length=50, unique=True)
    plate_number = models.CharField(max_length=50, blank=True)
    capacity = models.IntegerField(default=50)
    default_gender = models.ForeignKey(GenderCategory, on_delete=models.PROTECT, related_name='buses')
    assigned_driver = models.ForeignKey(
        'accounts.DriverProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_buses'
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')

    class Meta:
        verbose_name_plural = "Buses"

    def __str__(self):
        return f"Bus #{self.bus_number} ({self.default_gender.name})"

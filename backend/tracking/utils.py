import math

def haversine_distance_km(lat1, lon1, lat2, lon2):
    """
    Computes great-circle distance between two GPS coordinates in kilometers.
    """
    if None in (lat1, lon1, lat2, lon2):
        return 0.0

    R = 6371.0  # Earth's radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2.0) ** 2 +
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
        math.sin(dlon / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(R * c, 2)


def calculate_eta_minutes(distance_km, speed_kmh=0.0):
    """
    Estimates arrival time in minutes.
    Uses current bus speed when > 8 km/h, otherwise falls back to university route average (25 km/h).
    """
    if distance_km <= 0.0:
        return 1

    effective_speed = speed_kmh if (speed_kmh and speed_kmh > 8.0) else 25.0
    hours = distance_km / effective_speed
    return max(1, round(hours * 60))

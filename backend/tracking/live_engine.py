import time
import asyncio
from datetime import datetime
from django.utils import timezone
from channels.db import database_sync_to_async
from tracking.utils import haversine_distance_km, calculate_eta_minutes
from tracking.models import Trip, TripStopEvent
from transit.models import RouteStop

# In-Memory Trip State Cache (SQLite3 Write Shield)
# trip_id -> state dict
LIVE_TRIPS = {}

def get_trip_db_sync(trip_id):
    return Trip.objects.select_related(
        'route', 'bus', 'bus__default_gender', 'driver__user', 'slot_assignment'
    ).prefetch_related(
        'route__route_stops__stop', 'slot_assignment__tags'
    ).filter(id=trip_id, status='active').first()


def init_live_trip_sync(trip):
    route_stops = []
    for rs in trip.route.route_stops.select_related('stop').order_by('sequence_order'):
        route_stops.append({
            'stop_id': rs.stop.id,
            'stop_name': rs.stop.name,
            'sequence_order': rs.sequence_order,
            'latitude': rs.stop.latitude,
            'longitude': rs.stop.longitude,
            'geofence_radius_m': getattr(rs.stop, 'geofence_radius_m', 70.0) or 70.0,
        })

    tags = []
    if trip.slot_assignment:
        tags = [t.code for t in trip.slot_assignment.tags.all()]

    # Fetch previously recorded arrived/skipped stop IDs for this trip from DB
    existing_events = TripStopEvent.objects.filter(trip=trip).values_list('stop_id', 'event_type')
    arrived_set = {stop_id for stop_id, ev_type in existing_events if ev_type == 'arrived'}
    skipped_set = {stop_id for stop_id, ev_type in existing_events if ev_type == 'skipped'}

    state = {
        'trip_id': trip.id,
        'route_id': trip.route.id,
        'route_name': trip.route.name,
        'bus_number': trip.bus.bus_number,
        'plate_number': trip.bus.plate_number,
        'driver_id': trip.driver.id,
        'driver_name': trip.driver.user.name,
        'driver_phone': trip.driver.user.phone,
        'gender': trip.bus.default_gender.name,
        'tags': tags,
        'crowd_status': trip.crowd_status,
        'current_stop_order': trip.current_stop_order or 1,
        'last_lat': trip.last_lat or trip.route.origin_hub.latitude,
        'last_lng': trip.last_lng or trip.route.origin_hub.longitude,
        'speed_kmh': trip.last_speed_kmh or 0.0,
        'heading': 0.0,
        'last_updated': timezone.now().isoformat(),
        'route_stops': route_stops,
        'arrived_stop_ids': arrived_set,
        'skipped_stop_ids': skipped_set,
    }
    LIVE_TRIPS[trip.id] = state
    return state


@database_sync_to_async
def get_or_load_live_trip_async(trip_id):
    if trip_id in LIVE_TRIPS:
        return LIVE_TRIPS[trip_id]
    trip = get_trip_db_sync(trip_id)
    if not trip:
        return None
    return init_live_trip_sync(trip)


@database_sync_to_async
def record_stop_arrived_db(trip_id, stop_id, order, speed_kmh, lat, lng):
    now = timezone.now()
    TripStopEvent.objects.get_or_create(
        trip_id=trip_id,
        stop_id=stop_id,
        event_type='arrived',
        defaults={'speed_kmh': speed_kmh, 'recorded_at': now}
    )
    Trip.objects.filter(id=trip_id).update(
        current_stop_order=order,
        last_lat=lat,
        last_lng=lng,
        last_speed_kmh=speed_kmh
    )


@database_sync_to_async
def record_stop_skipped_db(trip_id, stop_id, speed_kmh):
    now = timezone.now()
    TripStopEvent.objects.get_or_create(
        trip_id=trip_id,
        stop_id=stop_id,
        event_type='skipped',
        defaults={'speed_kmh': speed_kmh, 'recorded_at': now}
    )


async def process_gps_ping(trip_id, lat, lng, speed_kmh, heading=0.0):
    """
    Processes routine GPS ping.
    - Routine movements: update in-memory dict ONLY (0 SQLite writes).
    - Geofence arrival: speed < 12 km/h inside radius -> 1 write to TripStopEvent + Trip update.
    - Stop skip violation: high speed through geofence or jumping past intermediate stop -> 1 write + alert.
    """
    state = await get_or_load_live_trip_async(trip_id)
    if not state:
        return None

    lat = float(lat)
    lng = float(lng)
    speed_kmh = float(speed_kmh)
    heading = float(heading or 0.0)

    # 1. Update in-memory state (Write Shield)
    state['last_lat'] = lat
    state['last_lng'] = lng
    state['speed_kmh'] = speed_kmh
    state['heading'] = heading
    state['last_updated'] = timezone.now().isoformat()

    route_stops = state['route_stops']
    arrived_ids = state['arrived_stop_ids']
    skipped_ids = state['skipped_stop_ids']
    curr_order = state['current_stop_order']

    stop_skip_alert = None

    # 2. Check Geofences
    for s in route_stops:
        stop_id = s['stop_id']
        stop_order = s['sequence_order']
        stop_lat = s['latitude']
        stop_lng = s['longitude']
        radius_m = s['geofence_radius_m']

        dist_m = haversine_distance_km(lat, lng, stop_lat, stop_lng) * 1000.0

        # Inside Geofence
        if dist_m <= radius_m:
            # Case A: Arrived at stop (bus slowed down to < 12 km/h)
            if speed_kmh < 12.0:
                if stop_id not in arrived_ids:
                    # Check for missed intermediate stops between curr_order and this stop
                    for prev_s in route_stops:
                        if curr_order <= prev_s['sequence_order'] < stop_order:
                            if prev_s['stop_id'] not in arrived_ids and prev_s['stop_id'] not in skipped_ids:
                                skipped_ids.add(prev_s['stop_id'])
                                await record_stop_skipped_db(trip_id, prev_s['stop_id'], speed_kmh)
                                stop_skip_alert = {
                                    'alert_type': 'stop_skipped',
                                    'trip_id': trip_id,
                                    'bus_number': state['bus_number'],
                                    'skipped_stop_id': prev_s['stop_id'],
                                    'skipped_stop_name': prev_s['stop_name'],
                                    'sequence_order': prev_s['sequence_order'],
                                    'speed_kmh': speed_kmh,
                                    'message': f"Bus #{state['bus_number']} jumped past stop '{prev_s['stop_name']}' without stopping."
                                }

                    arrived_ids.add(stop_id)
                    state['current_stop_order'] = stop_order
                    await record_stop_arrived_db(trip_id, stop_id, stop_order, speed_kmh, lat, lng)

            # Case B: High Speed Pass Violation (passing through geofence at >= 25 km/h without arriving)
            elif speed_kmh >= 25.0:
                if stop_id not in arrived_ids and stop_id not in skipped_ids:
                    skipped_ids.add(stop_id)
                    await record_stop_skipped_db(trip_id, stop_id, speed_kmh)
                    stop_skip_alert = {
                        'alert_type': 'stop_skipped',
                        'trip_id': trip_id,
                        'bus_number': state['bus_number'],
                        'skipped_stop_id': stop_id,
                        'skipped_stop_name': s['stop_name'],
                        'sequence_order': stop_order,
                        'speed_kmh': speed_kmh,
                        'message': f"Bus #{state['bus_number']} bypassed stop '{s['stop_name']}' at {speed_kmh:.1f} km/h."
                    }

    # 3. Derive current and next stop names & ETA
    curr_stop_name = None
    next_stop_name = None
    eta_to_next_min = 1
    crossed_stops_count = 0

    for s in route_stops:
        if s['sequence_order'] == state['current_stop_order']:
            curr_stop_name = s['stop_name']
        elif s['sequence_order'] == state['current_stop_order'] + 1:
            next_stop_name = s['stop_name']
            dist_next_km = haversine_distance_km(lat, lng, s['latitude'], s['longitude'])
            eta_to_next_min = calculate_eta_minutes(dist_next_km, speed_kmh)

        if s['sequence_order'] <= state['current_stop_order']:
            crossed_stops_count += 1

    return {
        'trip_id': trip_id,
        'route_id': state['route_id'],
        'route_name': state['route_name'],
        'bus_number': state['bus_number'],
        'plate_number': state['plate_number'],
        'driver_name': state['driver_name'],
        'driver_phone': state['driver_phone'],
        'gender': state['gender'],
        'tags': state['tags'],
        'lat': lat,
        'lng': lng,
        'speed_kmh': speed_kmh,
        'heading': heading,
        'current_stop_order': state['current_stop_order'],
        'current_stop_name': curr_stop_name or state['route_name'],
        'next_stop_name': next_stop_name or "Destination",
        'eta_to_next_stop_min': eta_to_next_min,
        'crowd_status': state['crowd_status'],
        'crossed_stops': crossed_stops_count,
        'stop_skip_alert': stop_skip_alert,
        'last_updated': state['last_updated'],
    }


def get_live_snapshot(route_id=None):
    """
    Returns live in-memory snapshots for all active trips (optionally filtered by route_id).
    """
    results = []
    for trip_id, state in list(LIVE_TRIPS.items()):
        if route_id and str(state.get('route_id')) != str(route_id):
            continue
        results.append({
            'trip_id': trip_id,
            'route_id': state.get('route_id'),
            'route_name': state.get('route_name'),
            'bus_number': state.get('bus_number'),
            'plate_number': state.get('plate_number'),
            'gender': state.get('gender'),
            'tags': state.get('tags'),
            'lat': state.get('last_lat'),
            'lng': state.get('last_lng'),
            'speed_kmh': state.get('speed_kmh'),
            'heading': state.get('heading'),
            'current_stop_order': state.get('current_stop_order'),
            'crowd_status': state.get('crowd_status'),
            'last_updated': state.get('last_updated'),
        })
    return results


def remove_live_trip(trip_id):
    """
    Removes trip from live in-memory cache when completed.
    """
    LIVE_TRIPS.pop(trip_id, None)

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

class LocationService {
  RealtimeChannel? _trackingChannel;

  /// 🔋 BATTERY OPT: Driver GPS stream — high accuracy, 10m filter (was 5m)
  /// 10m reduces GPS wake-ups by ~50% while still providing smooth bus tracking
  Stream<Position> get locationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );

  /// 🔋 BATTERY OPT: Student GPS — low accuracy, only for "my location" dot
  /// Uses significantly less battery since students don't need precise GPS
  Stream<Position> get studentLocationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    ),
  );

  /// Checks and requests location permission. Returns true if granted.
  /// Shows the system permission dialog if not yet decided.
  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.warning("Location services are disabled on device");
      return false;
    }

    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      AppLogger.info("Requesting location permission from user...");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.warning("Location permission denied by user");
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      AppLogger.warning("Location permission permanently denied");
      return false;
    }
    
    AppLogger.info("Location permission granted: $permission");
    return true;
  }

  /// Returns the current permission status without requesting.
  static Future<LocationPermission> checkPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Opens the device's app settings page so user can manually enable permissions.
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Opens the device's location settings page so user can enable GPS.
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<void> startSharingLocation(
    String uid, String busNumber, {
    required String from, required String to, 
    required String gender, required String driverName,
    required String departureTime, required String arrivalTime,
    required double lat, required double lng,
    String plateNumber = "",
    String remainingTime = "Calculating...",
    String remainingDistance = "Calculating...",
    String scheduleId = "",
  }) async {
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    
    if (busNumber.trim().isEmpty) {
      throw Exception("Bus number cannot be empty");
    }
    
    final client = Supabase.instance.client;
    
    // Initialize WebSockets channel for broadcast
    _trackingChannel = client.channel('live-bus-tracking');
    _trackingChannel!.subscribe();

    // 1. Insert/Update active bus record in public.active_buses table
    await client.from('active_buses').upsert({
      'bus_number': busNumber,
      'driver_id': uid,
      'driver_name': driverName,
      'plate_number': plateNumber,
      'latitude': lat,
      'longitude': lng,
      'heading': 0.0,
      'speed': 0.0,
      'from_hub': from,
      'to_hub': to,
      'gender': gender,
      'status': 'active',
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'remaining_time': remainingTime,
      'remaining_distance': remainingDistance,
      'schedule_id': scheduleId,
      'trip_id': tripId,
      'last_updated': DateTime.now().toIso8601String(),
    });

    // 2. Set driver status to Online in profiles
    try {
      await client.from('profiles').update({'status': 'Online'}).eq('id', uid);
    } catch (e) {
      AppLogger.warning("Failed to update status to Online: $e");
    }

    // 3. Write record into completed_trips with status 'active'
    try {
      await client.from('completed_trips').insert({
        'trip_id': tripId,
        'driver_id': uid,
        'driver_name': driverName,
        'bus_number': busNumber,
        'plate_number': plateNumber,
        'from_hub': from,
        'to_hub': to,
        'gender': gender,
        'start_time': DateTime.now().toIso8601String(),
        'status': 'active',
        'schedule_id': scheduleId,
        'date': todayStr,
        'revenue': 0.0,
      });
    } catch (e) {
      AppLogger.warning("Failed to write to completed_trips collection: $e");
    }
  }

  /// Updates the live tracking data for a bus.
  /// Now includes speed tracking and real-time ETA for students.
  Future<void> updateTracking(
    String busNumber, 
    double lat, 
    double lng, 
    double heading, {
    double speed = 0.0,
    String remainingTime = "",
    String remainingDistance = "",
    String arrivalTime = "",
  }) async {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      AppLogger.warning("Invalid coordinates rejected: ($lat, $lng)");
      return;
    }
    
    final client = Supabase.instance.client;

    // 1. Broadcast details over WebSockets (highly optimized, no DB costs)
    _trackingChannel ??= client.channel('live-bus-tracking');
    await _trackingChannel!.sendBroadcastMessage(
      event: 'location_update',
      payload: {
        'bus_number': busNumber,
        'latitude': lat,
        'longitude': lng,
        'heading': heading,
        'speed': speed,
        'remaining_time': remainingTime,
        'remaining_distance': remainingDistance,
        'arrival_time': arrivalTime,
      },
    );

    // 2. Also update database record for fallback reads
    try {
      await client.from('active_buses').update({
        'latitude': lat,
        'longitude': lng,
        'heading': heading,
        'speed': speed,
        'remaining_time': remainingTime,
        if (remainingDistance.isNotEmpty) 'remaining_distance': remainingDistance,
        'arrival_time': arrivalTime,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('bus_number', busNumber);
    } catch (e) {
      AppLogger.warning("Failed to update active_buses: $e");
    }
  }

  /// Stops location sharing: removes the bus from active_buses table and marks the trip as completed.
  Future<void> stopSharingLocation(String uid, String busNumber, String tripId) async {
    final client = Supabase.instance.client;

    // 1. Delete active bus record from database
    try {
      await client.from('active_buses').delete().eq('bus_number', busNumber);
    } catch (e) {
      AppLogger.warning("Failed to delete active bus: $e");
    }
    
    // Broadcast termination signal
    _trackingChannel ??= client.channel('live-bus-tracking');
    await _trackingChannel!.sendBroadcastMessage(
      event: 'trip_stopped',
      payload: {'bus_number': busNumber},
    );

    // 2. Update status to Offline in profiles
    try {
      await client.from('profiles').update({'status': 'Offline'}).eq('id', uid);
    } catch (e) {
      AppLogger.warning("Failed to update status to Offline: $e");
    }

    // 3. Mark the specific trip as completed in database
    try {
      await client.from('completed_trips').update({
        'end_time': DateTime.now().toIso8601String(),
        'status': 'completed',
      }).eq('trip_id', tripId);
    } catch (e) {
      AppLogger.warning("Failed to update completed_trips collection: $e");
    }

    // 4. Cleanup other active trips for this driver
    try {
      await client.from('completed_trips').update({
        'end_time': DateTime.now().toIso8601String(),
        'status': 'completed',
      }).eq('driver_id', uid).eq('status', 'active');
    } catch (e) {
      AppLogger.warning("Failed to run active trips cleanup: $e");
    }
  }

  Future<Map<String, dynamic>?> getActiveTrip(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('completed_trips')
          .select()
          .eq('driver_id', uid)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }

  /// Restores bus tracking entry in public.active_buses when driver returns to an active trip.
  Future<void> restoreTracking(String uid, String busNumber) async {
    try {
      final activeTrip = await getActiveTrip(uid);
      if (activeTrip == null) return;
      
      final client = Supabase.instance.client;
      final busCheck = await client
          .from('active_buses')
          .select()
          .eq('bus_number', busNumber)
          .maybeSingle();
          
      if (busCheck == null) {
        AppLogger.info("Restoring bus tracking for $busNumber");
        await client.from('active_buses').insert({
          'bus_number': busNumber,
          'driver_id': uid,
          'driver_name': activeTrip['driver_name'] ?? 'Driver',
          'plate_number': activeTrip['plate_number'] ?? '',
          'latitude': 0.0,
          'longitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'from_hub': activeTrip['from_hub'] ?? '',
          'to_hub': activeTrip['to_hub'] ?? '',
          'gender': activeTrip['gender'] ?? 'Combined',
          'status': 'active',
          'departure_time': 'Restored',
          'arrival_time': 'Pending',
          'remaining_time': 'Calculating...',
          'remaining_distance': 'Calculating...',
          'trip_id': activeTrip['trip_id'],
          'last_updated': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      AppLogger.error("Failed to restore tracking: $e");
    }
  }

  /// Fetches the entire trip history for a specific driver
  Future<List<Map<String, dynamic>>> getTripHistory(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('completed_trips')
          .select()
          .eq('driver_id', uid)
          .order('start_time', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  /// Stream of trip history for a specific driver
  Stream<List<Map<String, dynamic>>> getTripHistoryStream(String uid) {
    return Supabase.instance.client
        .from('completed_trips')
        .stream(primaryKey: ['id'])
        .eq('driver_id', uid)
        .map((maps) {
          final list = List<Map<String, dynamic>>.from(maps);
          list.sort((a, b) => (b['start_time'] ?? '').toString().compareTo((a['start_time'] ?? '').toString()));
          return list;
        });
  }

  /// Listens to all active buses for student-side tracking
  Stream<List<Map<String, dynamic>>> get activeBusesStream =>
      Supabase.instance.client.from('active_buses').stream(primaryKey: ['bus_number']);
}

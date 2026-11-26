import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Network/WebSocketService.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

class LocationService {
  final ApiClient _api = ApiClient();
  final WebSocketService _ws = WebSocketService();

  /// 🔋 Driver GPS stream — high accuracy, 10m filter
  Stream<Position> get locationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );

  /// 🔋 Student GPS — medium accuracy, only for "my location" dot
  Stream<Position> get studentLocationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    ),
  );

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

  static Future<LocationPermission> checkPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Start sharing location for a driver trip via WebSocket with REST fallback
  Future<void> startSharingLocation(
    String uid,
    String busNumber, {
    required String from,
    required String to,
    required String gender,
    required String driverName,
    required String departureTime,
    required String arrivalTime,
    required double lat,
    required double lng,
    String plateNumber = "",
    String remainingTime = "Calculating...",
    String remainingDistance = "Calculating...",
    String scheduleId = "",
    int? activeTripId,
  }) async {
    if (activeTripId != null) {
      // Connect to WebSocket channel for this trip
      await _ws.connectDriverTrip(activeTripId);

      // Send initial GPS ping via WebSocket
      _ws.sendDriverGps(
        latitude: lat,
        longitude: lng,
        speedKmh: 0.0,
        heading: 0.0,
      );

      // Also trigger initial location REST endpoint
      try {
        await _api.post(
          ApiConfig.driverTripLocation(activeTripId),
          data: {
            'lat': lat,
            'lng': lng,
            'speed_kmh': 0.0,
            'heading': 0.0,
          },
        );
      } catch (_) {}
    }
  }

  /// Broadcast live location update for active trip
  Future<void> updateDriverLocation({
    required int tripId,
    required double lat,
    required double lng,
    double speedKmh = 0.0,
    double heading = 0.0,
  }) async {
    // 1. Primary: Ultra-fast in-memory WebSocket update (0 DB write)
    _ws.sendDriverGps(
      latitude: lat,
      longitude: lng,
      speedKmh: speedKmh,
      heading: heading,
    );

    // 2. Secondary fallback via REST
    try {
      await _api.post(
        ApiConfig.driverTripLocation(tripId),
        data: {
          'lat': lat,
          'lng': lng,
          'speed_kmh': speedKmh,
          'heading': heading,
        },
      );
    } catch (_) {}
  }

  /// Stop sharing location & disconnect websocket
  Future<void> stopSharingLocation(String busNumber, {int? activeTripId}) async {
    if (activeTripId != null) {
      try {
        await _api.post(ApiConfig.driverTripStop(activeTripId));
      } catch (_) {}
    }
    _ws.disconnectDriverTrip();
  }

  /// Trip history stream for driver
  Stream<List<Map<String, dynamic>>> getTripHistoryStream([String? uid]) async* {
    try {
      final res = await _api.get(ApiConfig.driverTripHistory);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        yield list.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        yield [];
      }
    } catch (_) {
      yield [];
    }
  }
}

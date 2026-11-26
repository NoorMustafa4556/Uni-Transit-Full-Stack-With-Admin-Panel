import 'dart:async';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Services/LocationService.dart';
import 'package:uni_transit/Services/RoutingService.dart';
import 'package:uni_transit/Services/NotificationService.dart';
import 'package:uni_transit/Core/Util/Logger.dart';
import 'package:uni_transit/Core/Constants/CampusLocations.dart';
import 'package:uni_transit/Core/Constants/CustomRoutes.dart';
import 'package:uni_transit/Models/EtaInfo.dart';

class DriverTripState {
  final bool isTripStarted;
  final int? activeTripId;
  final String busNumber;
  final String plateNumber;
  final String? from;
  final String? to;
  final String gender;
  final String departureTime;
  final String scheduleId;
  final String crowdStatus; // 'seats_available', 'standing', 'full'
  final List<LatLng> routePoints;
  final String remainingDistance;
  final String remainingTime;
  final LatLng currentLocation;
  final double heading;
  final double speed;
  final bool isLoading;
  final bool hasRestored;

  DriverTripState({
    this.isTripStarted = false,
    this.activeTripId,
    this.busNumber = "",
    this.plateNumber = "",
    this.from,
    this.to,
    this.gender = "Combined",
    this.departureTime = "",
    this.scheduleId = "",
    this.crowdStatus = "seats_available",
    this.routePoints = const [],
    this.remainingDistance = "---",
    this.remainingTime = "---",
    this.currentLocation = const LatLng(29.3794, 71.6707),
    this.heading = 0.0,
    this.speed = 0.0,
    this.isLoading = false,
    this.hasRestored = false,
  });

  DriverTripState copyWith({
    bool? isTripStarted,
    int? activeTripId,
    String? busNumber,
    String? plateNumber,
    String? from,
    String? to,
    String? gender,
    String? departureTime,
    String? scheduleId,
    String? crowdStatus,
    List<LatLng>? routePoints,
    String? remainingDistance,
    String? remainingTime,
    LatLng? currentLocation,
    double? heading,
    double? speed,
    bool? isLoading,
    bool? hasRestored,
  }) {
    return DriverTripState(
      isTripStarted: isTripStarted ?? this.isTripStarted,
      activeTripId: activeTripId ?? this.activeTripId,
      busNumber: busNumber ?? this.busNumber,
      plateNumber: plateNumber ?? this.plateNumber,
      from: from ?? this.from,
      to: to ?? this.to,
      gender: gender ?? this.gender,
      departureTime: departureTime ?? this.departureTime,
      scheduleId: scheduleId ?? this.scheduleId,
      crowdStatus: crowdStatus ?? this.crowdStatus,
      routePoints: routePoints ?? this.routePoints,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingTime: remainingTime ?? this.remainingTime,
      currentLocation: currentLocation ?? this.currentLocation,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isLoading: isLoading ?? this.isLoading,
      hasRestored: hasRestored ?? this.hasRestored,
    );
  }
}

class DriverTripNotifier extends Notifier<DriverTripState> {
  final LocationService _locationService = LocationService();
  final ApiClient _api = ApiClient();
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  static const _refreshInterval = Duration(seconds: 15);

  @override
  DriverTripState build() {
    return DriverTripState();
  }

  void updateLocation(LatLng loc, double heading, {double speed = 0.0}) {
    state = state.copyWith(
      currentLocation: loc,
      heading: heading,
      speed: speed,
    );
    if (state.isTripStarted && state.activeTripId != null) {
      final now = DateTime.now();
      if (now.difference(_lastRefresh) > _refreshInterval) {
        _lastRefresh = now;
        _refreshNavigation();
      }
      _locationService.updateDriverLocation(
        tripId: state.activeTripId!,
        lat: loc.latitude,
        lng: loc.longitude,
        speedKmh: speed,
        heading: heading,
      );
    }
  }

  void updateInputs({
    String? bus,
    String? plate,
    String? from,
    String? to,
    String? gender,
    String? departureTime,
    String? scheduleId,
  }) {
    final safeFrom = (from != null && from.trim().isNotEmpty && from.trim().toLowerCase() != 'null')
        ? from.trim()
        : state.from;
    final safeTo = (to != null && to.trim().isNotEmpty && to.trim().toLowerCase() != 'null')
        ? to.trim()
        : state.to;

    state = state.copyWith(
      busNumber: (bus != null && bus.trim().isNotEmpty) ? bus.trim() : null,
      plateNumber: plate,
      from: safeFrom,
      to: safeTo,
      gender: gender,
      departureTime: (departureTime != null && departureTime.trim().isNotEmpty)
          ? departureTime.trim()
          : null,
      scheduleId: scheduleId,
    );

    if (safeFrom != null && safeTo != null) {
      _refreshNavigation();
    }
  }

  Future<void> updateCrowdStatus(String status) async {
    state = state.copyWith(crowdStatus: status);
    if (state.isTripStarted && state.activeTripId != null) {
      try {
        await _api.patch(
          ApiConfig.driverTripCrowdStatus(state.activeTripId!),
          data: {'crowd_status': status},
        );
        NotificationService.show(
          title: "Crowd Status Updated",
          message: "Bus crowd status set to: ${status.replaceAll('_', ' ').toUpperCase()}",
          type: NotificationType.info,
        );
      } catch (e) {
        AppLogger.error("Failed to update crowd status: $e");
      }
    }
  }

  Future<void> reportAlert(String alertType, String message) async {
    if (state.isTripStarted && state.activeTripId != null) {
      try {
        await _api.post(
          ApiConfig.driverTripAlert(state.activeTripId!),
          data: {
            'alert_type': alertType,
            'message': message,
          },
        );
        NotificationService.show(
          title: "Alert Reported",
          message: "Reported: $message",
          type: NotificationType.warning,
        );
      } catch (e) {
        NotificationService.show(
          title: "Error",
          message: "Failed to submit alert: $e",
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> restoreActiveTrip(String uid) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get(ApiConfig.driverActiveTrip);
      if (res.statusCode == 200 && res.data != null && res.data['active'] == true) {
        final trip = res.data['trip'];
        final tripId = trip['id'] as int;
        state = state.copyWith(
          isTripStarted: true,
          activeTripId: tripId,
          busNumber: trip['bus']?['bus_number'] ?? 'Bus',
          plateNumber: trip['bus']?['plate_number'] ?? '',
          from: trip['route']?['start_hub']?['name'] ?? 'Abbasia Campus',
          to: trip['route']?['end_hub']?['name'] ?? 'Baghdad Campus',
          crowdStatus: trip['crowd_status'] ?? 'seats_available',
        );
        await _refreshNavigation();
      }
    } catch (e) {
      AppLogger.error("Restore failed: $e");
    } finally {
      state = state.copyWith(isLoading: false, hasRestored: true);
    }
  }

  Future<void> _refreshNavigation() async {
    if (state.from == null || state.to == null) return;
    final routeName = "${state.from} ➔ ${state.to}";
    final manualPoints = CustomRoutes.getRoutePoints(routeName);

    final startHubCoord = _getHubCoord(state.from!);
    final target = _getHubCoord(state.to!);
    if (target == null) return;

    final origin = state.isTripStarted
        ? state.currentLocation
        : (startHubCoord ?? state.currentLocation);

    final fallbackEta = EtaInfo.estimateFromCoordinates(origin, target);
    final fallbackDistance = fallbackEta.distanceDisplay;
    final fallbackTime = fallbackEta.etaDisplay;

    if (manualPoints.isNotEmpty && manualPoints.length > 2) {
      final routeData = await RoutingService.getFullRoute([origin, target]);
      state = state.copyWith(
        routePoints: manualPoints,
        remainingDistance: routeData != null
            ? "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM"
            : (state.remainingDistance != "---" ? state.remainingDistance : fallbackDistance),
        remainingTime: routeData != null
            ? "${(routeData.durationSeconds / 60).ceil()} MIN"
            : (state.remainingTime != "---" ? state.remainingTime : fallbackTime),
      );
    } else {
      final routeData = await RoutingService.getFullRoute([origin, target]);
      if (routeData != null) {
        state = state.copyWith(
          routePoints: routeData.points,
          remainingDistance: "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM",
          remainingTime: "${(routeData.durationSeconds / 60).ceil()} MIN",
        );
      } else {
        state = state.copyWith(
          remainingDistance: state.remainingDistance != "---" ? state.remainingDistance : fallbackDistance,
          remainingTime: state.remainingTime != "---" ? state.remainingTime : fallbackTime,
        );
      }
    }
  }

  Future<void> toggleTrip(String uid, String driverName) async {
    if (!state.isTripStarted) {
      if (state.busNumber.trim().isEmpty) {
        NotificationService.show(
          title: "Missing Info",
          message: "Please enter or select a Bus before starting.",
          type: NotificationType.warning,
        );
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition();
        final nowFormatted = DateFormat('hh:mm a').format(DateTime.now());

        // Call Django backend to start trip
        final startRes = await _api.post(
          ApiConfig.driverTripStart,
          data: {
            'bus_number': state.busNumber,
            'from_hub': state.from ?? 'Abbasia Campus',
            'to_hub': state.to ?? 'Baghdad-ul-Jadeed Campus',
            'gender': state.gender,
          },
        );

        int tripId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (startRes.statusCode == 201 && startRes.data != null) {
          tripId = startRes.data['id'] ?? tripId;
        }

        await _locationService.startSharingLocation(
          uid,
          state.busNumber,
          from: state.from ?? 'Abbasia Campus',
          to: state.to ?? 'Baghdad-ul-Jadeed Campus',
          gender: state.gender,
          driverName: driverName,
          departureTime: nowFormatted,
          arrivalTime: "Calculating...",
          plateNumber: state.plateNumber,
          lat: pos.latitude,
          lng: pos.longitude,
          activeTripId: tripId,
        );

        state = state.copyWith(
          isTripStarted: true,
          activeTripId: tripId,
        );

        await _refreshNavigation();

        NotificationService.show(
          title: "Trip Started",
          message: "You are now live-tracking from ${state.from} to ${state.to}.",
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationService.show(
          title: "Error",
          message: "Failed to start trip: $e",
          type: NotificationType.error,
        );
      }
    } else {
      final oldTripId = state.activeTripId;
      await _locationService.stopSharingLocation(state.busNumber, activeTripId: oldTripId);

      state = state.copyWith(
        isTripStarted: false,
        activeTripId: null,
        busNumber: "",
        plateNumber: "",
        from: null,
        to: null,
        scheduleId: "",
        routePoints: [],
        remainingDistance: "---",
        remainingTime: "---",
      );

      NotificationService.show(
        title: "Route Completed! 🎉",
        message: "Congratulations! You have successfully completed your assigned route.",
        type: NotificationType.success,
      );
    }
  }

  LatLng? _getHubCoord(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('baghdad')) return CampusLocations.baghdadCampus;
    if (lower.contains('abbasia') || lower.contains('abasia') || lower.contains('old')) return CampusLocations.abbasiaCampus;
    if (lower.contains('railway')) return const LatLng(29.3970, 71.6850);
    return null;
  }
}

final driverTripProvider =
    NotifierProvider<DriverTripNotifier, DriverTripState>(
      () => DriverTripNotifier(),
    );

final driverTripHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient().get(ApiConfig.driverTripHistory);
    if (res.statusCode == 200 && res.data != null) {
      final List list = res.data is List ? res.data : (res.data['results'] ?? []);
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  } catch (_) {}
  return [];
});

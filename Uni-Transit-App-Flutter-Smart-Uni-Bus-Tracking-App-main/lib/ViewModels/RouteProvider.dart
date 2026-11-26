import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';

class RouteState {
  final Map<String, dynamic> officialRoutes;
  final Map<String, List<LatLng>> manualRoutes;
  final String? selectedRoute;
  final List<LatLng> routePoints;
  final String? fromHub;
  final String? toHub;
  final bool isFetching;

  RouteState({
    this.officialRoutes = const {},
    this.manualRoutes = const {},
    this.selectedRoute,
    this.routePoints = const [],
    this.fromHub,
    this.toHub,
    this.isFetching = false,
  });

  RouteState copyWith({
    Map<String, dynamic>? officialRoutes,
    Map<String, List<LatLng>>? manualRoutes,
    String? selectedRoute,
    List<LatLng>? routePoints,
    String? fromHub,
    String? toHub,
    bool? isFetching,
  }) {
    return RouteState(
      officialRoutes: officialRoutes ?? this.officialRoutes,
      manualRoutes: manualRoutes ?? this.manualRoutes,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      routePoints: routePoints ?? this.routePoints,
      fromHub: fromHub ?? this.fromHub,
      toHub: toHub ?? this.toHub,
      isFetching: isFetching ?? this.isFetching,
    );
  }
}

class RouteNotifier extends Notifier<RouteState> {
  final ApiClient _api = ApiClient();

  @override
  RouteState build() {
    _fetchRoutes();
    return RouteState();
  }

  Future<void> _fetchRoutes() async {
    try {
      final res = await _api.get(ApiConfig.routes);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        final Map<String, dynamic> merged = {};
        for (var row in list) {
          final code = row['code'] ?? row['title'];
          final startHub = row['start_hub']?['name'] ?? 'Abbasia Campus';
          final endHub = row['end_hub']?['name'] ?? 'Baghdad-ul-Jadeed Campus';
          merged[code.toString()] = {
            "id": row['id'],
            "title": row['title'],
            "code": code,
            "from": startHub,
            "to": endHub,
            "stops": row['stops'] ?? [],
          };
        }
        state = state.copyWith(officialRoutes: merged);
      }
    } catch (_) {}
  }

  void selectRoute(String routeKey, {List<LatLng>? fallbackPoints}) {
    final routeInfo = state.officialRoutes[routeKey];
    state = state.copyWith(
      selectedRoute: routeKey,
      routePoints: fallbackPoints ?? [],
      fromHub: routeInfo?['from'],
      toHub: routeInfo?['to'],
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedRoute: null,
      routePoints: [],
      fromHub: null,
      toHub: null,
    );
  }
}

final routeProvider = NotifierProvider<RouteNotifier, RouteState>(() {
  return RouteNotifier();
});

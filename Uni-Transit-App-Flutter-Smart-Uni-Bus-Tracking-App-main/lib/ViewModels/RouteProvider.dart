import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../Core/Constants/CampusLocations.dart';
import '../Core/Constants/CustomRoutes.dart';

Map<String, dynamic> _toCamelCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final camelKey = key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
    result[camelKey] = value;
  });
  return result;
}

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
  @override
  RouteState build() {
    _listenToOfficialRoutes();
    _listenToCustomPolylines();
    return RouteState();
  }

  void _listenToOfficialRoutes() {
    final sub = Supabase.instance.client
        .from('schedules')
        .stream(primaryKey: ['id'])
        .listen((event) {
      final Map<String, dynamic> mergedRoutes = {};

      for (var row in event) {
        final data = _toCamelCase(row);
        final route = data['route'] as String?;
        final from = data['from'] as String?;
        final to = data['to'] as String?;

        final date = data['date'] as String?;
        final operatingDays = data['operatingDays'] as List?;
        final departureTime = data['departureTime'] as String?;

        final hasNoDate = date == null || date.isEmpty;
        final hasNoOperatingDays = operatingDays == null || operatingDays.isEmpty;
        final hasNoTime = departureTime == null ||
            departureTime.isEmpty ||
            departureTime == 'TBA' ||
            departureTime == 'Live';

        if (route != null && from != null && to != null && hasNoDate && hasNoOperatingDays && hasNoTime) {
          String cleanKey = route.trim();
          mergedRoutes[cleanKey] = {
            "from": from,
            "to": to,
          };
        }
      }

      state = state.copyWith(officialRoutes: mergedRoutes);
    });
    ref.onDispose(() => sub.cancel());
  }

  void _listenToCustomPolylines() {
    final sub = Supabase.instance.client
        .from('custom_polylines')
        .stream(primaryKey: ['route_name'])
        .listen((event) {
      final Map<String, List<LatLng>> newRoutes = {};

      for (var row in event) {
        final routeName = row['route_name'].toString();
        final points = row['coordinates'];
        if (points is List) {
          newRoutes[routeName] = points.map((p) {
            if (p is List && p.length >= 2) {
              return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
            } else {
              final point = Map<String, dynamic>.from(p as Map);
              return LatLng(
                (point['lat'] ?? point['latitude'] ?? 0.0 as num).toDouble(),
                (point['lng'] ?? point['longitude'] ?? 0.0 as num).toDouble(),
              );
            }
          }).toList();
        }
      }

      state = state.copyWith(manualRoutes: newRoutes);
    });
    ref.onDispose(() => sub.cancel());
  }

  void selectRoute(String? route) {
    if (route == null) {
      state = state.copyWith(
        selectedRoute: null,
        routePoints: [],
        fromHub: null,
        toHub: null,
      );
      return;
    }

    final data = state.officialRoutes[route];
    if (data != null) {
      final from = data['from'] as String?;
      final to = data['to'] as String?;
      final manualPoints = state.manualRoutes[route];

      state = state.copyWith(
        selectedRoute: route,
        fromHub: from,
        toHub: to,
        routePoints: manualPoints ?? [],
      );
    }
  }

  void clearSelection() {
    selectRoute(null);
  }

  void updateRoutePoints(List<LatLng> points) {
    state = state.copyWith(routePoints: points);
  }
}

final routeProvider = NotifierProvider<RouteNotifier, RouteState>(() {
  return RouteNotifier();
});

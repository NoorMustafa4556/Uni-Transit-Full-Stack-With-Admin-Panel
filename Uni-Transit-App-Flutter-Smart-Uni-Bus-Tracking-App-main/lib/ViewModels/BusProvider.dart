import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Network/WebSocketService.dart';
import '../Core/Constants/CampusLocations.dart';

Map<String, dynamic> _toCamelCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final camelKey = key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
    result[camelKey] = value;
  });
  return result;
}

class BusState {
  final Map<String, dynamic> liveBusData;
  BusState({this.liveBusData = const {}});
}

class BusNotifier extends Notifier<BusState> {
  final ApiClient _api = ApiClient();
  final WebSocketService _ws = WebSocketService();
  StreamSubscription? _wsSub;

  @override
  BusState build() {
    _fetchBuses();
    _listenToWebSocket();
    return BusState();
  }

  Future<void> _fetchBuses() async {
    try {
      final res = await _api.get(ApiConfig.buses);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        final Map<String, dynamic> mapped = {};
        for (var row in list) {
          final key = row['bus_number'].toString();
          final camelRow = _toCamelCase(Map<String, dynamic>.from(row));
          camelRow['id'] = key;
          mapped[key] = camelRow;
        }
        state = BusState(liveBusData: mapped);
      }
    } catch (_) {}
  }

  void _listenToWebSocket() {
    _wsSub = _ws.routeUpdatesStream.listen((event) {
      if (event['type'] == 'gps_update' || event['type'] == 'trip_update') {
        final busNumber = event['bus_number']?.toString() ?? event['bus_id']?.toString() ?? '';
        if (busNumber.isNotEmpty) {
          final updated = Map<String, dynamic>.from(state.liveBusData);
          updated[busNumber] = {
            ...(updated[busNumber] ?? {}),
            ..._toCamelCase(event),
            'latitude': event['lat'] ?? event['latitude'],
            'longitude': event['lng'] ?? event['longitude'],
            'speed': event['speed_kmh'] ?? event['speed'],
            'heading': event['heading'] ?? 0.0,
            'crowdStatus': event['crowd_status'],
            'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          };
          state = BusState(liveBusData: updated);
        }
      }
    });
    ref.onDispose(() => _wsSub?.cancel());
  }
}

final busProvider = NotifierProvider<BusNotifier, BusState>(() {
  return BusNotifier();
});

class StopState {
  final Map<String, dynamic> stopsData;
  StopState({this.stopsData = const {}});
}

class StopNotifier extends Notifier<StopState> {
  final ApiClient _api = ApiClient();

  @override
  StopState build() {
    _fetchStops();
    return StopState(stopsData: {
      "1": {
        "name": "One Uni Point",
        "latitude": 29.3850,
        "longitude": 71.7350,
        "route": "Baghdad ➔ Abbasia",
      },
    });
  }

  Future<void> _fetchStops() async {
    try {
      final res = await _api.get(ApiConfig.stops);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        final Map<String, dynamic> mapped = {};
        for (var row in list) {
          mapped[row['id'].toString()] = _toCamelCase(Map<String, dynamic>.from(row));
        }
        if (mapped.isNotEmpty) {
          state = StopState(stopsData: mapped);
        }
      }
    } catch (_) {}
  }
}

final stopProvider = NotifierProvider<StopNotifier, StopState>(() {
  return StopNotifier();
});

class HubState {
  final Map<String, dynamic> hubsData;
  HubState({this.hubsData = const {}});
}

class HubNotifier extends Notifier<HubState> {
  final ApiClient _api = ApiClient();

  @override
  HubState build() {
    _fetchHubs();
    return HubState(hubsData: {
      CampusLocations.abbasiaName: {
        "latitude": CampusLocations.abbasiaCampus.latitude,
        "longitude": CampusLocations.abbasiaCampus.longitude,
      },
      CampusLocations.baghdadName: {
        "latitude": CampusLocations.baghdadCampus.latitude,
        "longitude": CampusLocations.baghdadCampus.longitude,
      },
    });
  }

  Future<void> _fetchHubs() async {
    try {
      final res = await _api.get(ApiConfig.hubs);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        final Map<String, dynamic> mergedHubs = {
          CampusLocations.abbasiaName: {
            "latitude": CampusLocations.abbasiaCampus.latitude,
            "longitude": CampusLocations.abbasiaCampus.longitude,
          },
          CampusLocations.baghdadName: {
            "latitude": CampusLocations.baghdadCampus.latitude,
            "longitude": CampusLocations.baghdadCampus.longitude,
          },
        };
        for (var row in list) {
          mergedHubs[row['name'].toString()] = _toCamelCase(Map<String, dynamic>.from(row));
        }
        state = HubState(hubsData: mergedHubs);
      }
    } catch (_) {}
  }
}

final hubProvider = NotifierProvider<HubNotifier, HubState>(() {
  return HubNotifier();
});

class GenderState {
  final Map<String, dynamic> genderConfigs;
  GenderState({this.genderConfigs = const {}});
}

class GenderConfigNotifier extends Notifier<GenderState> {
  final ApiClient _api = ApiClient();

  @override
  GenderState build() {
    _fetchGenderConfigs();
    return GenderState(genderConfigs: {
      "Girls Special": {"color": "0xFFFF4081"},
      "Boys Special": {"color": "0xFF448AFF"},
      "Combined": {"color": "0xFF9C27B0"},
      "Staff": {"color": "0xFF00B0FF"},
    });
  }

  Future<void> _fetchGenderConfigs() async {
    try {
      final res = await _api.get(ApiConfig.genderCategories);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        final Map<String, dynamic> parsed = {};
        for (var row in list) {
          final name = row['name']?.toString() ?? '';
          final color = (row['color_code'] ?? '0xFF9C27B0').toString().replaceAll('#', '0xFF');
          parsed[name] = {"color": color};
        }
        if (parsed.isNotEmpty) {
          state = GenderState(genderConfigs: parsed);
        }
      }
    } catch (_) {}
  }
}

final genderConfigProvider = NotifierProvider<GenderConfigNotifier, GenderState>(() {
  return GenderConfigNotifier();
});

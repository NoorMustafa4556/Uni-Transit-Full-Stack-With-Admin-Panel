import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  @override
  BusState build() {
    _listenToBuses();
    return BusState();
  }

  void _listenToBuses() {
    final sub = Supabase.instance.client
        .from('active_buses')
        .stream(primaryKey: ['bus_number'])
        .listen((event) {
          final Map<String, dynamic> mapped = {};
          for (var row in event) {
            final key = row['bus_number'].toString();
            final camelRow = _toCamelCase(row);
            camelRow['id'] = key;
            mapped[key] = camelRow;
          }
          state = BusState(liveBusData: mapped);
        });
    ref.onDispose(() => sub.cancel());
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
  @override
  StopState build() {
    _listenToStops();
    return StopState();
  }

  void _listenToStops() {
    final sub = Supabase.instance.client
        .from('stops')
        .stream(primaryKey: ['id'])
        .listen((event) {
          final Map<String, dynamic> mapped = {};
          for (var row in event) {
            mapped[row['id'].toString()] = _toCamelCase(row);
          }
          state = StopState(stopsData: mapped.isNotEmpty ? mapped : {
            "default_stop_1": {
              "name": "One Uni Point",
              "latitude": 29.3850,
              "longitude": 71.7350,
              "route": "Baghdad ➔ Abbasia",
            },
          });
        });
    ref.onDispose(() => sub.cancel());
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
  @override
  HubState build() {
    _listenToHubs();
    return HubState();
  }

  void _listenToHubs() {
    final sub = Supabase.instance.client
        .from('hubs')
        .stream(primaryKey: ['name'])
        .listen((event) {
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

          for (var row in event) {
            mergedHubs[row['name'].toString()] = _toCamelCase(row);
          }
          state = HubState(hubsData: mergedHubs);
        });
    ref.onDispose(() => sub.cancel());
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
  @override
  GenderState build() {
    _listenToGenderConfigs();
    return GenderState(genderConfigs: {
      "Girls Special": {"color": "0xFFFF4081"},
      "Boys Special": {"color": "0xFF448AFF"},
      "Combined": {"color": "0xFF9C27B0"},
    });
  }

  void _listenToGenderConfigs() {
    final sub = Supabase.instance.client
        .from('app_settings')
        .stream(primaryKey: ['key'])
        .eq('key', 'gender_configs')
        .listen((event) {
          if (event.isNotEmpty) {
            final rawData = Map<String, dynamic>.from(event.first['value'] as Map);
            final Map<String, dynamic> parsed = {};
            rawData.forEach((key, value) {
              final String valStr = value.toString().replaceAll('#', '0xFF');
              parsed[key] = {"color": valStr};
            });
            state = GenderState(genderConfigs: parsed);
          }
        });
    ref.onDispose(() => sub.cancel());
  }
}

final genderConfigProvider = NotifierProvider<GenderConfigNotifier, GenderState>(() {
  return GenderConfigNotifier();
});

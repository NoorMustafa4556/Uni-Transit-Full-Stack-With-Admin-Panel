import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Core/Constants/CampusLocations.dart';

class MapUiState {
  final LatLng userLocation;
  final bool hasUserLocation;
  final String selectedGender;
  final Set<String> notifiedBuses;

  MapUiState({
    required this.userLocation,
    this.hasUserLocation = false,
    this.selectedGender = "All",
    this.notifiedBuses = const {},
  });

  MapUiState copyWith({
    LatLng? userLocation,
    bool? hasUserLocation,
    String? selectedGender,
    Set<String>? notifiedBuses,
  }) {
    return MapUiState(
      userLocation: userLocation ?? this.userLocation,
      hasUserLocation: hasUserLocation ?? this.hasUserLocation,
      selectedGender: selectedGender ?? this.selectedGender,
      notifiedBuses: notifiedBuses ?? this.notifiedBuses,
    );
  }
}

class MapUiNotifier extends Notifier<MapUiState> {
  @override
  MapUiState build() {
    _loadGenderPreference();
    return MapUiState(
      userLocation: CampusLocations.baghdadCampus,
    );
  }

  Future<void> _loadGenderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pref_gender_filter');
    if (saved != null) {
      state = state.copyWith(selectedGender: saved);
    }
  }

  void updateUserLocation(LatLng location) {
    state = state.copyWith(
      userLocation: location,
      hasUserLocation: true,
    );
  }

  void updateGenderPreference(String gender) {
    state = state.copyWith(selectedGender: gender);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('pref_gender_filter', gender);
    });
  }

  void addNotifiedBus(String busId) {
    final newSet = Set<String>.from(state.notifiedBuses)..add(busId);
    state = state.copyWith(notifiedBuses: newSet);
  }

  void clearNotifications() {
    state = state.copyWith(notifiedBuses: const {});
  }
}

final mapUiProvider = NotifierProvider<MapUiNotifier, MapUiState>(() {
  return MapUiNotifier();
});

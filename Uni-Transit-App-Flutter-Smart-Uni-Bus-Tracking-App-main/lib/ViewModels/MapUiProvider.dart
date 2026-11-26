import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Util/CloudFirestoreCompat.dart';
import 'package:flutter/foundation.dart';
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
    _listenToUserPreferences();
    return MapUiState(
      userLocation: CampusLocations.baghdadCampus,
    );
  }

  void _listenToUserPreferences() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('students')
          .doc(user.id)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data.containsKey('gender_preference')) {
            state = state.copyWith(
              selectedGender: data['gender_preference'] ?? "All",
            );
          }
        }
      });
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
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('students')
          .doc(user.id)
          .update({
            'gender_preference': gender,
          }).catchError((e) {
        debugPrint("Error updating gender preference: $e");
      });
    }
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

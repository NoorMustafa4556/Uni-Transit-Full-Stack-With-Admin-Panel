class StopSkipAlertModel {
  final int id;
  final int tripId;
  final String busNumber;
  final String routeName;
  final String driverName;
  final String stopName;
  final int stopSequence;
  final String reason;
  final double distanceKm;
  final DateTime detectedAt;

  StopSkipAlertModel({
    required this.id,
    required this.tripId,
    required this.busNumber,
    required this.routeName,
    required this.driverName,
    required this.stopName,
    required this.stopSequence,
    required this.reason,
    required this.distanceKm,
    required this.detectedAt,
  });

  factory StopSkipAlertModel.fromMap(Map<String, dynamic> map) {
    DateTime ts;
    try {
      ts = map['detected_at'] != null ? DateTime.parse(map['detected_at'].toString()) : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    return StopSkipAlertModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      tripId: map['trip_id'] is int ? map['trip_id'] : int.tryParse(map['trip_id']?.toString() ?? '0') ?? 0,
      busNumber: map['bus_number'] ?? 'Bus',
      routeName: map['route_name'] ?? 'Route',
      driverName: map['driver_name'] ?? 'Driver',
      stopName: map['stop_name'] ?? 'Stop',
      stopSequence: map['stop_sequence'] ?? 0,
      reason: map['reason'] ?? 'Vehicle bypassed stop geofence without stopping',
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      detectedAt: ts,
    );
  }
}

class BusSchedule {
  final String id;
  final String? busNumber;
  final String route;
  final String from;
  final String to;
  final String? departureTime;
  final List<String> stops;
  final String type; // Boys Special, Girls Special, Combined
  final List<String>? operatingDays; // e.g., ["Monday", "Tuesday"]
  final String? date; // Specific date in YYYY-MM-DD format
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? assignedConductorName;
  final int totalBuses;
  final int dispatchedCount;
  final bool isLastBus;

  BusSchedule({
    required this.id,
    this.busNumber,
    required this.route,
    required this.from,
    required this.to,
    this.departureTime,
    required this.stops,
    required this.type,
    this.operatingDays,
    this.date,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedConductorName,
    this.totalBuses = 0,
    this.dispatchedCount = 0,
    this.isLastBus = false,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'busNumber': busNumber ?? 'TBA',
      'route': route,
      'fromHub': from,
      'toHub': to,
      'departureTime': departureTime ?? 'Live',
      'stops': stops,
      'type': type,
      'operatingDays': operatingDays ?? [],
      'date': date,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedConductorName': assignedConductorName,
    };
  }

  // Create Object from Firestore Map
  factory BusSchedule.fromMap(String id, Map<String, dynamic> map) {
    return BusSchedule(
      id: id,
      busNumber: map['busNumber'],
      route: map['route'] ?? '',
      from: map['fromHub'] ?? map['from'] ?? '',
      to: map['toHub'] ?? map['to'] ?? '',
      departureTime: map['departureTime'],
      stops: List<String>.from(map['stops'] ?? []),
      type: map['type'] ?? 'Combined',
      operatingDays: map['operatingDays'] != null ? List<String>.from(map['operatingDays']) : null,
      date: map['date'],
      assignedDriverId: map['assignedDriverId'],
      assignedDriverName: map['assignedDriverName'],
      assignedConductorName: map['assignedConductorName'],
      totalBuses: (map['total_buses'] ?? map['totalBuses'] ?? 0) is int ? (map['total_buses'] ?? map['totalBuses'] ?? 0) : int.tryParse((map['total_buses'] ?? map['totalBuses'] ?? '0').toString()) ?? 0,
      dispatchedCount: (map['dispatched_count'] ?? map['dispatchedCount'] ?? 0) is int ? (map['dispatched_count'] ?? map['dispatchedCount'] ?? 0) : int.tryParse((map['dispatched_count'] ?? map['dispatchedCount'] ?? '0').toString()) ?? 0,
      isLastBus: map['is_last_bus'] == true || map['isLastBus'] == true,
    );
  }

  BusSchedule copyWith({
    String? id,
    String? busNumber,
    String? route,
    String? from,
    String? to,
    String? departureTime,
    List<String>? stops,
    String? type,
    List<String>? operatingDays,
    String? date,
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedConductorName,
    int? totalBuses,
    int? dispatchedCount,
    bool? isLastBus,
  }) {
    return BusSchedule(
      id: id ?? this.id,
      busNumber: busNumber ?? this.busNumber,
      route: route ?? this.route,
      from: from ?? this.from,
      to: to ?? this.to,
      departureTime: departureTime ?? this.departureTime,
      stops: stops ?? this.stops,
      type: type ?? this.type,
      operatingDays: operatingDays ?? this.operatingDays,
      date: date ?? this.date,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedConductorName: assignedConductorName ?? this.assignedConductorName,
      totalBuses: totalBuses ?? this.totalBuses,
      dispatchedCount: dispatchedCount ?? this.dispatchedCount,
      isLastBus: isLastBus ?? this.isLastBus,
    );
  }
}

import 'package:unitransit_admin/Models/RouteCategoryModel.dart';

class ScheduleProfileModel {
  final int id;
  final String name;
  final String effectiveFrom;
  final bool isActive;

  ScheduleProfileModel({
    required this.id,
    required this.name,
    required this.effectiveFrom,
    required this.isActive,
  });

  factory ScheduleProfileModel.fromMap(Map<String, dynamic> map) {
    return ScheduleProfileModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      name: map['name'] ?? '',
      effectiveFrom: map['effective_from'] ?? '',
      isActive: map['is_active'] ?? false,
    );
  }
}

class AdminTimeSlotModel {
  final int id;
  final int profileId;
  final int routeId;
  final String routeName;
  final String originHub;
  final String destinationHub;
  final String shift;
  final String dayType;
  final String departureTime;
  final bool isActive;
  final int totalBuses;
  final int dispatchedCount;
  final int remainingCount;
  final bool isLastBus;
  final List<AdminSlotBusAssignmentModel> busAssignments;

  AdminTimeSlotModel({
    required this.id,
    required this.profileId,
    required this.routeId,
    required this.routeName,
    required this.originHub,
    required this.destinationHub,
    required this.shift,
    required this.dayType,
    required this.departureTime,
    required this.isActive,
    required this.totalBuses,
    required this.dispatchedCount,
    required this.remainingCount,
    required this.isLastBus,
    required this.busAssignments,
  });

  factory AdminTimeSlotModel.fromMap(Map<String, dynamic> map) {
    final rawList = map['bus_assignments'] as List? ?? [];
    return AdminTimeSlotModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      profileId: map['profile'] is int ? map['profile'] : int.tryParse(map['profile']?.toString() ?? '0') ?? 0,
      routeId: map['route'] is int ? map['route'] : int.tryParse(map['route']?.toString() ?? '0') ?? 0,
      routeName: map['route_name'] ?? 'Route',
      originHub: map['origin_hub'] ?? '',
      destinationHub: map['destination_hub'] ?? '',
      shift: map['shift'] ?? 'morning',
      dayType: map['day_type'] ?? 'regular',
      departureTime: map['departure_time'] ?? '',
      isActive: map['is_active'] ?? true,
      totalBuses: map['total_buses'] ?? 0,
      dispatchedCount: map['dispatched_count'] ?? 0,
      remainingCount: map['remaining_count'] ?? 0,
      isLastBus: map['is_last_bus'] ?? false,
      busAssignments: rawList.map((e) => AdminSlotBusAssignmentModel.fromMap(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class AdminSlotBusAssignmentModel {
  final int id;
  final int timeSlotId;
  final int busId;
  final String busNumber;
  final String plateNumber;
  final int? driverId;
  final String? driverName;
  final int genderId;
  final String genderName;
  final List<RouteTagModel> tags;
  final int dispatchOrder;
  final bool isActive;
  final bool isDispatched;
  final int? activeTripId;

  AdminSlotBusAssignmentModel({
    required this.id,
    required this.timeSlotId,
    required this.busId,
    required this.busNumber,
    required this.plateNumber,
    this.driverId,
    this.driverName,
    required this.genderId,
    required this.genderName,
    required this.tags,
    required this.dispatchOrder,
    required this.isActive,
    required this.isDispatched,
    this.activeTripId,
  });

  factory AdminSlotBusAssignmentModel.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags_list'] as List? ?? [];
    return AdminSlotBusAssignmentModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      timeSlotId: map['time_slot'] is int ? map['time_slot'] : int.tryParse(map['time_slot']?.toString() ?? '0') ?? 0,
      busId: map['bus'] is int ? map['bus'] : int.tryParse(map['bus']?.toString() ?? '0') ?? 0,
      busNumber: map['bus_number'] ?? '',
      plateNumber: map['plate_number'] ?? '',
      driverId: map['driver'] != null ? int.tryParse(map['driver'].toString()) : null,
      driverName: map['driver_name'],
      genderId: map['gender'] is int ? map['gender'] : int.tryParse(map['gender']?.toString() ?? '0') ?? 0,
      genderName: map['gender_name'] ?? 'Combined',
      tags: rawTags.map((e) => RouteTagModel.fromMap(Map<String, dynamic>.from(e))).toList(),
      dispatchOrder: map['dispatch_order'] ?? 1,
      isActive: map['is_active'] ?? true,
      isDispatched: map['is_dispatched'] ?? false,
      activeTripId: map['active_trip_id'] != null ? int.tryParse(map['active_trip_id'].toString()) : null,
    );
  }
}

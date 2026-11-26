import 'dart:async';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Util/Logger.dart';
import 'package:uni_transit/Models/BusSchedule.dart';

class SlotCounterModel {
  final int totalBuses;
  final int dispatchedCount;
  final int remainingCount;
  final bool isLastBus;

  SlotCounterModel({
    required this.totalBuses,
    required this.dispatchedCount,
    required this.remainingCount,
    required this.isLastBus,
  });

  factory SlotCounterModel.fromMap(Map<String, dynamic> map) {
    return SlotCounterModel(
      totalBuses: map['total_buses'] ?? 1,
      dispatchedCount: map['dispatched_count'] ?? 0,
      remainingCount: map['remaining_count'] ?? 1,
      isLastBus: map['is_last_bus'] ?? false,
    );
  }
}

class ScheduleService {
  final ApiClient _api = ApiClient();

  // Fetch active slots from Django REST backend
  Future<List<Map<String, dynamic>>> getActiveSlots({
    int? routeId,
    String? shift,
    String? dayType,
    String? gender,
    String? tag,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (routeId != null) query['route_id'] = routeId;
      if (shift != null) query['shift'] = shift;
      if (dayType != null) query['day_type'] = dayType;
      if (gender != null) query['gender'] = gender;
      if (tag != null) query['tag'] = tag;

      final response = await _api.get(ApiConfig.activeSlots, queryParameters: query);
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data is List ? response.data : (response.data['results'] ?? []);
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      AppLogger.error("Failed to load active slots: $e");
    }
    return [];
  }

  // Fetch active schedule profiles
  Future<List<Map<String, dynamic>>> getScheduleProfiles() async {
    try {
      final response = await _api.get(ApiConfig.scheduleProfiles);
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data is List ? response.data : (response.data['results'] ?? []);
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      AppLogger.error("Failed to load schedule profiles: $e");
    }
    return [];
  }

  // Stream of BusSchedule for backward-compatibility with existing views
  Stream<List<BusSchedule>> getSchedules() async* {
    try {
      final slots = await getActiveSlots();
      final schedules = slots.map((s) {
        final routeObj = s['route'] as Map<String, dynamic>?;
        final routeTitle = routeObj != null ? (routeObj['title'] ?? '') : (s['route_title'] ?? '');
        return BusSchedule(
          id: s['id'].toString(),
          busNumber: s['assigned_bus']?['bus_number'] ?? 'Bus ${s['id']}',
          route: routeTitle,
          departureTime: s['departure_time'] ?? '',
          stops: (routeObj?['stops'] as List? ?? []).map((e) => e['name'].toString()).toList(),
          type: s['gender_type'] ?? 'Combined',
          operatingDays: [s['day_type'] ?? 'Everyday'],
          date: DateTime.now().toIso8601String().split('T').first,
        );
      }).toList();
      yield schedules;
    } catch (_) {
      yield [];
    }
  }

  // Add / Delete compatibility stubs
  Future<void> addSchedule(BusSchedule schedule) async {}
  Future<void> deleteSchedule(String id) async {}
}

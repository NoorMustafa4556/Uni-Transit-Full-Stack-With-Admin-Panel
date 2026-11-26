import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Models/BusSchedule.dart';

Map<String, dynamic> _toSnakeCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final snakeKey = key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
    result[snakeKey] = value;
  });
  return result;
}

Map<String, dynamic> _toCamelCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final camelKey = key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
    result[camelKey] = value;
  });
  return result;
}

class ScheduleService {
  final _client = Supabase.instance.client;

  // Add a new Schedule (Admin/Driver)
  Future<void> addSchedule(BusSchedule schedule) async {
    try {
      final data = _toSnakeCase(schedule.toMap());
      data.remove('id');
      await _client.from('schedules').insert(data);
    } catch (e) {
      throw Exception("Failed to add schedule: $e");
    }
  }

  // Get Stream of Schedules (For Real-time updates)
  Stream<List<BusSchedule>> getSchedules() {
    return _client.from('schedules').stream(primaryKey: ['id']).map((event) {
      return event.map((row) {
        return BusSchedule.fromMap(row['id'].toString(), _toCamelCase(row));
      }).toList();
    });
  }

  // Delete Schedule
  Future<void> deleteSchedule(String id) async {
    await _client.from('schedules').delete().eq('id', id);
  }
}

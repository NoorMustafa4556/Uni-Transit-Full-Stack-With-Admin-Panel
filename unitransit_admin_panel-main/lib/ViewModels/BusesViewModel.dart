import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusesViewModel extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> get buses => _buses;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BusesViewModel() {
    fetchBuses();
  }

  Future<void> fetchBuses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _client.from('buses').select();
      _buses = response.map((row) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row);
        data['busNumber'] = row['bus_number'] ?? '';
        data['plateNumber'] = row['plate_number'] ?? '';
        data['id'] = row['id'].toString();
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching buses: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addBus(Map<String, dynamic> busData) async {
    _errorMessage = null;
    try {
      await _client.from('buses').insert({
        'bus_number': busData['busNumber'],
        'plate_number': busData['plateNumber'],
        'capacity': busData['capacity'] is String 
            ? int.tryParse(busData['capacity']) ?? 50 
            : (busData['capacity'] ?? 50),
        'type': busData['type'] ?? 'Standard',
        'status': busData['status'] ?? 'Active',
      });
      await fetchBuses();
      return null; // success
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error adding bus: $e");
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> updateBus(String id, Map<String, dynamic> busData) async {
    try {
      await _client.from('buses').update({
        'bus_number': busData['busNumber'],
        'plate_number': busData['plateNumber'],
        'capacity': busData['capacity'] is String 
            ? int.tryParse(busData['capacity']) ?? 50 
            : (busData['capacity'] ?? 50),
        'status': busData['status'] ?? 'Active',
      }).eq('id', id);
      await fetchBuses();
    } catch (e) {
      debugPrint("Error updating bus: $e");
    }
  }

  Future<void> deleteBus(String id) async {
    try {
      await _client.from('buses').delete().eq('id', id);
      await fetchBuses();
    } catch (e) {
      debugPrint("Error deleting bus: $e");
    }
  }
}

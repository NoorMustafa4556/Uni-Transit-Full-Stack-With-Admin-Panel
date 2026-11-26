import 'package:flutter/material.dart';
import 'package:unitransit_admin/Core/Network/ApiClient.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';

class BusesViewModel extends ChangeNotifier {
  final ApiClient _client = ApiClient();
  
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
      final response = await _client.get(ApiConfig.buses);
      if (response.statusCode == 200 && response.data is List) {
        _buses = (response.data as List).map((row) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
          data['busNumber'] = row['bus_number'] ?? '';
          data['plateNumber'] = row['plate_number'] ?? '';
          data['id'] = row['id'].toString();
          return data;
        }).toList();
      }
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
      final res = await _client.post(ApiConfig.buses, data: {
        'bus_number': busData['busNumber'],
        'plate_number': busData['plateNumber'],
        'capacity': busData['capacity'] is String 
            ? int.tryParse(busData['capacity']) ?? 50 
            : (busData['capacity'] ?? 50),
        'is_active': (busData['status'] ?? 'Active') == 'Active',
      });
      await fetchBuses();
      if (res.isPendingApproval) {
        return 'Submitted for Higher Authority approval.';
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error adding bus: $e");
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> updateBus(String id, Map<String, dynamic> busData) async {
    try {
      final numId = int.tryParse(id) ?? 0;
      await _client.patch(ApiConfig.busDetail(numId), data: {
        'bus_number': busData['busNumber'],
        'plate_number': busData['plateNumber'],
        'capacity': busData['capacity'] is String 
            ? int.tryParse(busData['capacity']) ?? 50 
            : (busData['capacity'] ?? 50),
        'is_active': (busData['status'] ?? 'Active') == 'Active',
      });
      await fetchBuses();
    } catch (e) {
      debugPrint("Error updating bus: $e");
    }
  }

  Future<void> deleteBus(String id) async {
    try {
      final numId = int.tryParse(id) ?? 0;
      await _client.delete(ApiConfig.busDetail(numId));
      await fetchBuses();
    } catch (e) {
      debugPrint("Error deleting bus: $e");
    }
  }
}

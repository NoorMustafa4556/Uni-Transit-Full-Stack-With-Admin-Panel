import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:unitransit_admin/Models/BusScheduleModel.dart';

Map<String, dynamic> _toCamelCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final camelKey = key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
    result[camelKey] = value;
  });
  return result;
}

class FleetOperationsViewModel extends ChangeNotifier {
  StreamSubscription? _busesSubscription;
  StreamSubscription? _schedulesSubscription;
  StreamSubscription? _polylinesSubscription;

  // --- State ---
  List<Map<String, dynamic>> _allBuses = [];
  List<Map<String, dynamic>> _filteredBuses = [];
  List<BusSchedule> _schedules = [];
  Map<String, List<LatLng>> _polylines = {};
  bool _isSuperAdmin = false;

  String? _selectedBusId;
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedGenderFilter = 'All';
  String _selectedRouteFilter = 'All';
  String _selectedBusNumberFilter = 'All';

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  // --- Getters ---
  List<Map<String, dynamic>> get allBuses => _allBuses;
  List<Map<String, dynamic>> get filteredBuses => _filteredBuses;
  List<BusSchedule> get schedules => _schedules;
  Map<String, List<LatLng>> get polylines => _polylines;
  String? get selectedBusId => _selectedBusId;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedGenderFilter => _selectedGenderFilter;
  String get selectedRouteFilter => _selectedRouteFilter;
  String get selectedBusNumberFilter => _selectedBusNumberFilter;
  DateTime get selectedDate => _selectedDate;
  DateTime get currentMonth => _currentMonth;
  int get activeCount => _allBuses.length;
  bool get isSuperAdmin => _isSuperAdmin;

  void setSuperAdmin(bool value) {
    if (_isSuperAdmin != value) {
      _isSuperAdmin = value;
      applyFilters();
    }
  }

  Map<String, dynamic>? get selectedBus {
    if (_selectedBusId == null) return null;
    final match = _filteredBuses.where((b) => b['id'] == _selectedBusId);
    if (match.isEmpty) return null;
    final bus = match.first;
    return bus.isNotEmpty ? bus : null;
  }

  bool get hasActiveFilters =>
      _selectedGenderFilter != 'All' ||
      _selectedRouteFilter != 'All' ||
      _selectedBusNumberFilter != 'All' ||
      _searchQuery.isNotEmpty;

  // --- Initialization ---
  FleetOperationsViewModel() {
    _listenToActiveBuses();
    _listenToSchedules();
    _listenToPolylines();
  }

  void _listenToActiveBuses() {
    _busesSubscription = Supabase.instance.client
        .from('active_buses')
        .select().asStream()
        .listen((event) {
      final List<Map<String, dynamic>> loadedBuses = event.map((row) {
        final camelRow = _toCamelCase(row);
        camelRow['id'] = row['bus_number'];
        return camelRow;
      }).toList();

      _allBuses = loadedBuses;
      _isLoading = false;
      applyFilters();
    }, onError: (error) {
      debugPrint("Error loading active buses: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToSchedules() {
    _schedulesSubscription = Supabase.instance.client
        .from('schedules')
        .select().asStream()
        .listen((event) {
      _schedules = event.map((row) {
        final camelRow = _toCamelCase(row);
        return BusSchedule.fromMap(row['id'].toString(), camelRow);
      }).toList();
      notifyListeners();
    });
  }

  void _listenToPolylines() {
    _polylinesSubscription = Supabase.instance.client
        .from('custom_polylines')
        .select().asStream()
        .listen((event) {
      final Map<String, List<LatLng>> loaded = {};
      for (var row in event) {
        final routeName = row['route_name'].toString();
        final coords = row['coordinates'];
        if (coords is List) {
          final List<LatLng> path = [];
          for (var c in coords) {
            if (c is List && c.length >= 2) {
              path.add(LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()));
            } else if (c is Map) {
              final lat = (c['lat'] ?? c['latitude'] ?? 0.0) as num;
              final lng = (c['lng'] ?? c['longitude'] ?? 0.0) as num;
              path.add(LatLng(lat.toDouble(), lng.toDouble()));
            }
          }
          if (path.isNotEmpty) {
            loaded[routeName] = path;
          }
        }
      }
      _polylines = loaded;
      notifyListeners();
    });
  }

  // --- Filter Actions ---
  void updateSearchQuery(String query) {
    _searchQuery = query;
    applyFilters();
  }

  void selectGenderFilter(String gender) {
    _selectedGenderFilter = gender;
    applyFilters();
  }

  void selectRouteFilter(String route) {
    _selectedRouteFilter = route;
    applyFilters();
  }

  void selectBusNumberFilter(String busNo) {
    _selectedBusNumberFilter = busNo;
    applyFilters();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void updateCurrentMonth(DateTime month) {
    _currentMonth = month;
    notifyListeners();
  }

  // Alias setters expected by FleetOperationsScreen
  void setGenderFilter(String gender) => selectGenderFilter(gender);
  void setRouteFilter(String route) => selectRouteFilter(route);
  void setBusNumberFilter(String busNo) => selectBusNumberFilter(busNo);
  void clearAllFilters() => clearFilters();

  // Force stop tracking (alias for forceStopBus)
  Future<void> forceStopTracking(Map<String, dynamic> bus) => forceStopBus(bus);

  // Unique values for filter dropdowns
  List<String> get uniqueRoutes {
    final routes = _allBuses
        .map((b) => '${b['from']} ➔ ${b['to']}')
        .toSet()
        .toList();
    return ['All', ...routes];
  }

  List<String> get uniqueBusNumbers {
    final numbers = _allBuses
        .map((b) => (b['busNumber'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    return ['All', ...numbers];
  }

  // Schedule helpers
  BusSchedule? getMatchingSchedule(Map<String, dynamic> bus) {
    final busNumber = (bus['busNumber'] ?? '').toString();
    final gender = (bus['gender'] ?? '').toString();
    try {
      return _schedules.firstWhere(
        (s) => s.busNumber == busNumber &&
               (s.type.toLowerCase().contains(gender.toLowerCase()) ||
                gender.isEmpty || s.type.toLowerCase() == 'combined'),
      );
    } catch (_) {
      return null;
    }
  }

  int get totalSchedulesToday {
    final today = _weekdays[_selectedDate.weekday - 1];
    return _schedules
        .where((s) => s.operatingDays?.contains(today) ?? false)
        .length;
  }

  int get activeSchedulesToday {
    final today = _weekdays[_selectedDate.weekday - 1];
    // Count schedules that are active for today (all that have today in operatingDays)
    return _schedules
        .where((s) => s.operatingDays?.contains(today) ?? false)
        .length;
  }

  // Calendar helpers
  int get daysInMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[_currentMonth.month - 1];
  }

  void changeMonth(int delta) {
    final m = _currentMonth.month + delta;
    final y = _currentMonth.year + (m < 1 ? -1 : m > 12 ? 1 : 0);
    _currentMonth = DateTime(y, ((m - 1) % 12) + 1);
    notifyListeners();
  }

  String getWeekdayName(DateTime date) => _weekdays[date.weekday - 1];

  void clearFilters() {
    _searchQuery = '';
    _selectedGenderFilter = 'All';
    _selectedRouteFilter = 'All';
    _selectedBusNumberFilter = 'All';
    applyFilters();
  }

  void selectBus(String? busId) {
    _selectedBusId = busId;
    notifyListeners();
  }

  void applyFilters() {
    List<Map<String, dynamic>> results = List.from(_allBuses);

    // 1. Role Check
    if (!_isSuperAdmin) {
      results = results.where((bus) {
        return (bus['from']?.toString().toLowerCase().contains('baghdad') ?? false) ||
               (bus['to']?.toString().toLowerCase().contains('baghdad') ?? false);
      }).toList();
    }

    // 2. Search Query (Bus Number or Driver Name)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      results = results.where((bus) {
        final bNo = (bus['busNumber'] ?? '').toString().toLowerCase();
        final dName = (bus['driverName'] ?? '').toString().toLowerCase();
        final origin = (bus['from'] ?? '').toString().toLowerCase();
        final dest = (bus['to'] ?? '').toString().toLowerCase();
        return bNo.contains(q) || dName.contains(q) || origin.contains(q) || dest.contains(q);
      }).toList();
    }

    // 3. Gender Filter
    if (_selectedGenderFilter != 'All') {
      results = results.where((bus) => bus['gender'] == _selectedGenderFilter).toList();
    }

    // 4. Route Filter
    if (_selectedRouteFilter != 'All') {
      results = results.where((bus) {
        final route = "${bus['from']} ➔ ${bus['to']}";
        return route == _selectedRouteFilter;
      }).toList();
    }

    // 5. Bus Number Filter
    if (_selectedBusNumberFilter != 'All') {
      results = results.where((bus) => bus['busNumber'] == _selectedBusNumberFilter).toList();
    }

    _filteredBuses = results;
    notifyListeners();
  }

  Future<void> forceStopBus(Map<String, dynamic> bus) async {
    final busId = (bus['id'] ?? '').toString();
    final busNumber = (bus['busNumber'] ?? '').toString();
    final driverId = (bus['driverId'] ?? '').toString();
    final tripId = (bus['tripId'] ?? '').toString();

    if (busId.isEmpty) return;

    final client = Supabase.instance.client;

    // 1. Remove from active buses in Supabase active_buses table
    await client.from('active_buses').delete().eq('bus_number', busId);
    if (busNumber.isNotEmpty && busNumber != busId) {
      await client.from('active_buses').delete().eq('bus_number', busNumber);
    }
    
    // Broadcast trip stop signal so the driver app catches it!
    final channel = client.channel('live-bus-tracking');
    await channel.sendBroadcastMessage(
      event: 'trip_stopped',
      payload: {'bus_number': busId},
    );

    // 2. Clear local selection
    if (_selectedBusId == busId || _selectedBusId == busNumber) {
      _selectedBusId = null;
    }

    // 3. Update driver profile status to Offline
    if (driverId.isNotEmpty) {
      try {
        await client.from('profiles').update({'status': 'Offline'}).eq('id', driverId);
      } catch (e) {
        debugPrint("Error updating driver status: $e");
      }
    }

    // 4. Update completed_trips table
    if (tripId.isNotEmpty) {
      try {
        await client.from('completed_trips').upsert({
          'trip_id': tripId,
          'driver_id': driverId,
          'driver_name': bus['driverName'] ?? 'Driver',
          'bus_number': busNumber,
          'plate_number': bus['plateNumber'] ?? '',
          'from_hub': bus['from'] ?? 'Unknown',
          'to_hub': bus['to'] ?? 'Unknown',
          'gender': bus['gender'] ?? 'Combined',
          'start_time': DateTime.now().toIso8601String(),
          'end_time': DateTime.now().toIso8601String(),
          'status': 'force_stopped',
          'schedule_id': bus['scheduleId'] ?? '',
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'revenue': 0.0,
        });
      } catch (e) {
        debugPrint("Error creating completed trip record: $e");
      }
    }
    notifyListeners();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _busesSubscription?.cancel();
    _schedulesSubscription?.cancel();
    _polylinesSubscription?.cancel();
    super.dispose();
  }
}

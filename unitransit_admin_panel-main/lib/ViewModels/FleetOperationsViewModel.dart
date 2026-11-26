import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:unitransit_admin/Core/Services/AdminApiService.dart';
import 'package:unitransit_admin/Core/Network/ApiClient.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';
import 'package:unitransit_admin/Models/BusScheduleModel.dart';
import 'package:unitransit_admin/Models/StopSkipAlertModel.dart';

class FleetOperationsViewModel extends ChangeNotifier {
  final AdminApiService _apiService = AdminApiService();
  StreamSubscription? _busesSubscription;
  StreamSubscription? _schedulesSubscription;
  StreamSubscription? _polylinesSubscription;
  StreamSubscription? _stopSkipSubscription;

  // --- State ---
  List<Map<String, dynamic>> _allBuses = [];
  List<Map<String, dynamic>> _filteredBuses = [];
  List<BusSchedule> _schedules = [];
  Map<String, List<LatLng>> _polylines = {};
  List<StopSkipAlertModel> _stopSkipAlerts = [];
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
  List<StopSkipAlertModel> get stopSkipAlerts => _stopSkipAlerts;
  String? get selectedBusId => _selectedBusId;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedGenderFilter => _selectedGenderFilter;
  String get selectedRouteFilter => _selectedRouteFilter;
  String get selectedBusNumberFilter => _selectedBusNumberFilter;
  DateTime get selectedDate => _selectedDate;
  DateTime get currentMonth => _currentMonth;
  bool get isSuperAdmin => _isSuperAdmin;
  void setSuperAdmin(bool val) {
    _isSuperAdmin = val;
    notifyListeners();
  }

  Map<String, dynamic>? get selectedBus {
    if (_selectedBusId == null) return null;
    try {
      return _allBuses.firstWhere((b) => b['id'] == _selectedBusId);
    } catch (_) {
      return null;
    }
  }

  int get activeCount => _allBuses.length;
  List<String> get uniqueRoutes => availableRoutes;
  List<String> get uniqueBusNumbers => availableBusNumbers;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedGenderFilter != 'All' ||
      _selectedRouteFilter != 'All' ||
      _selectedBusNumberFilter != 'All';

  void clearAllFilters() {
    _searchQuery = '';
    _selectedGenderFilter = 'All';
    _selectedRouteFilter = 'All';
    _selectedBusNumberFilter = 'All';
    applyFilters();
  }

  BusSchedule? getMatchingSchedule(Map<String, dynamic> bus) {
    final busNum = (bus['busNumber'] ?? bus['bus_number'] ?? '').toString();
    try {
      return _schedules.firstWhere((s) => s.busNumber == busNum);
    } catch (_) {
      return null;
    }
  }

  Future<void> forceStopTracking(Map<String, dynamic> bus) => forceStopBus(bus);

  int get totalSchedulesToday => getSchedulesForSelectedDate().length;
  int get activeSchedulesToday => _allBuses.length;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  String get monthName => _monthNames[_currentMonth.month - 1];

  void updateSearchQuery(String query) => setSearchQuery(query);

  int get daysInMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  String getWeekdayName(DateTime date) => _weekdays[date.weekday - 1];

  List<String> get availableRoutes {
    final routes = _allBuses.map((b) => (b['route'] ?? b['routeName'] ?? '').toString()).where((r) => r.isNotEmpty).toSet().toList();
    routes.sort();
    return ['All', ...routes];
  }

  List<String> get availableBusNumbers {
    final nums = _allBuses.map((b) => (b['busNumber'] ?? b['bus_number'] ?? '').toString()).where((n) => n.isNotEmpty).toSet().toList();
    nums.sort();
    return ['All', ...nums];
  }

  FleetOperationsViewModel() {
    _initRole();
    _listenToActiveBuses();
    _listenToSchedules();
    _listenToPolylines();
    _listenToStopSkipAlerts();
  }

  Future<void> _initRole() async {
    _isSuperAdmin = await _apiService.isSuperAdmin();
    notifyListeners();
  }

  void _listenToActiveBuses() {
    _busesSubscription = _apiService.getBusesStream().listen((loadedBuses) {
      _allBuses = loadedBuses.map((b) {
        final map = Map<String, dynamic>.from(b);
        map['id'] = map['bus_number'] ?? map['id'] ?? '';
        map['busNumber'] = map['bus_number'] ?? map['busNumber'] ?? '';
        map['plateNumber'] = map['plate_number'] ?? map['plateNumber'] ?? '';
        map['latitude'] = (map['current_lat'] ?? map['latitude'] ?? 29.3800) as num;
        map['longitude'] = (map['current_lng'] ?? map['longitude'] ?? 71.6700) as num;
        map['speed'] = (map['speed_kmh'] ?? map['speed'] ?? 0) as num;
        map['heading'] = (map['heading'] ?? 0) as num;
        map['driverName'] = map['driver_name'] ?? map['driverName'] ?? 'Assigned Driver';
        map['route'] = map['route_name'] ?? map['route'] ?? 'IUB Route';
        map['gender'] = map['gender_name'] ?? map['gender'] ?? 'Combined';
        map['status'] = map['status'] ?? 'active';
        return map;
      }).toList();

      _isLoading = false;
      applyFilters();
    }, onError: (error) {
      debugPrint("Error loading active buses: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToSchedules() {
    _schedulesSubscription = _apiService.getBusSchedules().listen((event) {
      _schedules = event;
      notifyListeners();
    });
  }

  void _listenToPolylines() {
    _apiService.getRoutes().then((routes) {
      final Map<String, List<LatLng>> loaded = {};
      for (var row in routes) {
        final routeName = row['name']?.toString() ?? '';
        final coords = row['polyline_json'];
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

  void _listenToStopSkipAlerts() {
    _apiService.getStopSkipAlerts().then((alerts) {
      _stopSkipAlerts = alerts;
      notifyListeners();
    });

    _stopSkipSubscription = _apiService.ws.stopSkipAlertStream.listen((alert) {
      _stopSkipAlerts.insert(0, alert);
      notifyListeners();
    });
  }

  void selectBus(String? busId) {
    _selectedBusId = busId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    applyFilters();
  }

  void setGenderFilter(String gender) {
    _selectedGenderFilter = gender;
    applyFilters();
  }

  void setRouteFilter(String route) {
    _selectedRouteFilter = route;
    applyFilters();
  }

  void setBusNumberFilter(String busNum) {
    _selectedBusNumberFilter = busNum;
    applyFilters();
  }

  void applyFilters() {
    _filteredBuses = _allBuses.where((bus) {
      final name = (bus['driverName'] ?? '').toString().toLowerCase();
      final busNumber = (bus['busNumber'] ?? '').toString().toLowerCase();
      final route = (bus['route'] ?? '').toString().toLowerCase();
      final gender = (bus['gender'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          busNumber.contains(_searchQuery.toLowerCase()) ||
          route.contains(_searchQuery.toLowerCase());

      final matchesGender = _selectedGenderFilter == 'All' ||
          gender == _selectedGenderFilter.toLowerCase();

      final matchesRoute = _selectedRouteFilter == 'All' ||
          route == _selectedRouteFilter.toLowerCase();

      final matchesBusNumber = _selectedBusNumberFilter == 'All' ||
          busNumber == _selectedBusNumberFilter.toLowerCase();

      return matchesSearch && matchesGender && matchesRoute && matchesBusNumber;
    }).toList();

    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void changeMonth(int offset) {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    notifyListeners();
  }

  List<BusSchedule> getSchedulesForSelectedDate() {
    final weekdayName = _weekdays[_selectedDate.weekday - 1];
    final selectedDateStr = _formatDate(_selectedDate);

    return _schedules.where((schedule) {
      if (schedule.date != null && schedule.date!.isNotEmpty) {
        return schedule.date == selectedDateStr;
      }
      if (schedule.operatingDays != null && schedule.operatingDays!.isNotEmpty) {
        return schedule.operatingDays!.contains(weekdayName);
      }
      return true;
    }).toList();
  }

  Future<void> forceStopBus(Map<String, dynamic> bus) async {
    final tripId = bus['trip_id'] ?? bus['tripId'] ?? bus['active_trip_id'];
    if (tripId != null) {
      final numId = int.tryParse(tripId.toString());
      if (numId != null) {
        await ApiClient().post(ApiConfig.driverTripStop(numId));
      }
    }

    _selectedBusId = null;
    _allBuses.removeWhere((b) => b['busNumber'] == bus['busNumber']);
    applyFilters();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _busesSubscription?.cancel();
    _schedulesSubscription?.cancel();
    _polylinesSubscription?.cancel();
    _stopSkipSubscription?.cancel();
    super.dispose();
  }
}

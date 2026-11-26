import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:unitransit_admin/Core/Network/ApiClient.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';
import 'package:unitransit_admin/Core/Network/AdminWebSocketService.dart';
import 'package:unitransit_admin/Models/DriverModel.dart';
import 'package:unitransit_admin/Models/StudentModel.dart';
import 'package:unitransit_admin/Models/BusScheduleModel.dart';
import 'package:unitransit_admin/Models/HubModel.dart';
import 'package:unitransit_admin/Models/StopModel.dart';
import 'package:unitransit_admin/Models/SupportTicketModel.dart';
import 'package:unitransit_admin/Models/FaqModel.dart';
import 'package:unitransit_admin/Models/AuditLogModel.dart';
import 'package:unitransit_admin/Models/ChangeRequestModel.dart';
import 'package:unitransit_admin/Models/RouteCategoryModel.dart';
import 'package:unitransit_admin/Models/ScheduleProfileModel.dart';
import 'package:unitransit_admin/Models/StopSkipAlertModel.dart';
import 'package:unitransit_admin/Models/TransportContactModel.dart';

class AdminApiService {
  static final AdminApiService _instance = AdminApiService.internal();
  factory AdminApiService() => _instance;
  AdminApiService.internal();

  final ApiClient _client = ApiClient();
  final AdminWebSocketService ws = AdminWebSocketService();

  // Internal Polling / Cache Controllers for Real-Time UI Compatibility
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();
  final _driversController = StreamController<List<DriverModel>>.broadcast();
  final _studentsController = StreamController<List<StudentModel>>.broadcast();
  final _hubsController = StreamController<List<HubModel>>.broadcast();
  final _stopsController = StreamController<List<StopModel>>.broadcast();
  final _schedulesController = StreamController<List<BusSchedule>>.broadcast();
  final _ticketsController = StreamController<List<SupportTicketModel>>.broadcast();
  final _emergencyController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _faqsController = StreamController<List<FaqModel>>.broadcast();
  final _auditLogsController = StreamController<List<AuditLogModel>>.broadcast();
  final _genderConfigsController = StreamController<Map<String, String>>.broadcast();
  final _contactsController = StreamController<List<TransportContactModel>>.broadcast();
  final _approvalsController = StreamController<List<ChangeRequestModel>>.broadcast();

  Timer? _refreshTimer;

  void startPeriodicSync() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      refreshAll();
    });
    refreshAll();
  }

  Future<void> refreshAll() async {
    try {
      await Future.wait([
        fetchDrivers(),
        fetchStudents(),
        fetchHubs(),
        fetchStops(),
        fetchBusSchedules(),
        fetchTickets(),
        fetchEmergencyAlerts(),
        fetchFaqs(),
        fetchAuditLogs(),
        fetchGenderConfigs(),
        fetchContacts(),
        fetchApprovals(),
      ]);
    } catch (_) {}
  }

  // =========================================================================
  // 1. AUTHENTICATION & ADMIN ROLES
  // =========================================================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = Map<String, dynamic>.from(response.data as Map);
      final access = data['access']?.toString() ?? '';
      final refresh = data['refresh']?.toString() ?? '';
      final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});

      await _client.saveTokens(access: access, refresh: refresh);
      await _client.saveUserData(user);

      // Connect admin websocket
      ws.connect();
      startPeriodicSync();

      return user;
    } else {
      throw response.data?['detail'] ?? response.data?['error'] ?? 'Login failed (${response.statusCode})';
    }
  }

  Future<void> logout() async {
    _refreshTimer?.cancel();
    ws.disconnect();
    await _client.clearAuth();
  }

  Future<bool> isSuperAdmin() async {
    return _client.isSuperAdmin();
  }

  Future<String> getUserRole() async {
    return _client.getUserRole();
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final cached = await _client.getUserData();
    if (cached != null) return cached;

    final res = await _client.get(ApiConfig.me);
    if (res.statusCode == 200 && res.data is Map) {
      final user = Map<String, dynamic>.from(res.data as Map);
      await _client.saveUserData(user);
      return user;
    }
    return null;
  }

  Future<int> getAdminsCount() async {
    try {
      final res = await _client.get(ApiConfig.adminUsers);
      if (res.statusCode == 200 && res.data is List) {
        final list = res.data as List;
        return list.where((u) {
          final r = u['role']?.toString().toLowerCase();
          return r == 'super_admin' || r == 'sub_admin' || r == 'admin';
        }).length;
      }
    } catch (_) {}
    return 1;
  }

  Future<String> createUserAuth(String email, String password, {String role = 'driver', String name = ''}) async {
    final res = await _client.post(
      ApiConfig.adminUsers,
      data: {
        'email': email,
        'password': password,
        'name': name.isNotEmpty ? name : email.split('@').first,
        'role': role,
        'is_verified': true,
      },
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return (res.data?['id'] ?? 'created').toString();
    }
    throw res.data?['error'] ?? res.data?['detail'] ?? 'Failed to create user auth';
  }

  // =========================================================================
  // 2. DRIVERS
  // =========================================================================

  Future<List<DriverModel>> fetchDrivers() async {
    final res = await _client.get(ApiConfig.adminUsers, queryParameters: {'role': 'driver'});
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        return DriverModel.fromMap(Map<String, dynamic>.from(row as Map));
      }).toList();
      _driversController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<DriverModel>> getDrivers() {
    fetchDrivers();
    return _driversController.stream;
  }

  Future<ApiResponse> addDriver(DriverModel driver, {String? password}) async {
    final payload = {
      'email': driver.email,
      'password': password ?? 'Driver@123',
      'name': driver.name,
      'phone': driver.phoneNumber,
      'role': 'driver',
      'is_verified': driver.isVerified,
      'is_blocked': driver.isBlocked,
      'driver_profile': {
        'cnic': driver.cnic,
        'license_number': driver.licenseNumber,
        'license_expiry': driver.licenseExpiry.toIso8601String().split('T').first,
        'experience': driver.experience,
      },
    };

    final res = await _client.post(ApiConfig.adminUsers, data: payload);
    await logActivity(action: 'Added Driver', target: 'Driver: ${driver.name}');
    fetchDrivers();
    return res;
  }

  Future<ApiResponse> updateDriver(DriverModel driver) async {
    final id = int.tryParse(driver.id) ?? 0;
    final payload = {
      'name': driver.name,
      'phone': driver.phoneNumber,
      'is_verified': driver.isVerified,
      'is_blocked': driver.isBlocked,
      'driver_profile': {
        'cnic': driver.cnic,
        'license_number': driver.licenseNumber,
        'license_expiry': driver.licenseExpiry.toIso8601String().split('T').first,
        'experience': driver.experience,
      },
    };

    final res = await _client.patch(ApiConfig.adminUserDetail(id), data: payload);
    await logActivity(action: 'Updated Driver', target: 'Driver: ${driver.name}');
    fetchDrivers();
    return res;
  }

  Future<ApiResponse> deleteDriver(String id) async {
    final numId = int.tryParse(id) ?? 0;
    final res = await _client.delete(ApiConfig.adminUserDetail(numId));
    await logActivity(action: 'Deleted Driver', target: 'Driver: $id');
    fetchDrivers();
    return res;
  }

  Future<ApiResponse> resetDriverPassword(String emailOrId, {String newPassword = 'Password@123'}) async {
    final numId = int.tryParse(emailOrId);
    if (numId != null && numId > 0) {
      return _client.post(ApiConfig.resetUserPassword(numId), data: {'new_password': newPassword});
    }
    // Lookup by email
    final drivers = await fetchDrivers();
    final driver = drivers.firstWhere((d) => d.email == emailOrId, orElse: () => drivers.first);
    final targetId = int.tryParse(driver.id) ?? 0;
    return _client.post(ApiConfig.resetUserPassword(targetId), data: {'new_password': newPassword});
  }

  // =========================================================================
  // 3. STUDENTS
  // =========================================================================

  Future<List<StudentModel>> fetchStudents() async {
    final res = await _client.get(ApiConfig.adminUsers, queryParameters: {'role': 'student'});
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        return StudentModel.fromMap(Map<String, dynamic>.from(row as Map));
      }).toList();
      _studentsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<StudentModel>> getStudents() {
    fetchStudents();
    return _studentsController.stream;
  }

  Future<ApiResponse> addStudent(StudentModel student, {String? password}) async {
    final payload = {
      'email': student.email,
      'password': password ?? 'Student@123',
      'name': student.name,
      'phone': student.phoneNumber,
      'role': 'student',
      'is_verified': student.isVerified,
      'is_blocked': student.isBlocked,
      'student_profile': {
        'roll_no': student.studentId,
        'registration_no': student.regNo,
        'department': student.department,
        'semester': int.tryParse(student.semester) ?? 1,
      },
    };

    final res = await _client.post(ApiConfig.adminUsers, data: payload);
    await logActivity(action: 'Added Student', target: 'Student: ${student.name}');
    fetchStudents();
    return res;
  }

  Future<ApiResponse> updateStudent(StudentModel student) async {
    final id = int.tryParse(student.id) ?? 0;
    final payload = {
      'name': student.name,
      'phone': student.phoneNumber,
      'is_verified': student.isVerified,
      'is_blocked': student.isBlocked,
      'student_profile': {
        'roll_no': student.studentId,
        'registration_no': student.regNo,
        'department': student.department,
        'semester': int.tryParse(student.semester) ?? 1,
      },
    };

    final res = await _client.patch(ApiConfig.adminUserDetail(id), data: payload);
    fetchStudents();
    return res;
  }

  Future<ApiResponse> deleteStudent(String id) async {
    final numId = int.tryParse(id) ?? 0;
    final res = await _client.delete(ApiConfig.adminUserDetail(numId));
    await logActivity(action: 'Deleted Student', target: 'Student: $id');
    fetchStudents();
    return res;
  }

  Future<ApiResponse> resetStudentPassword(String emailOrId, {String newPassword = 'Password@123'}) async {
    final numId = int.tryParse(emailOrId);
    if (numId != null && numId > 0) {
      return _client.post(ApiConfig.resetUserPassword(numId), data: {'new_password': newPassword});
    }
    final students = await fetchStudents();
    final student = students.firstWhere((s) => s.email == emailOrId, orElse: () => students.first);
    final targetId = int.tryParse(student.id) ?? 0;
    return _client.post(ApiConfig.resetUserPassword(targetId), data: {'new_password': newPassword});
  }

  // =========================================================================
  // 4. HUBS & STOPS
  // =========================================================================

  Future<List<HubModel>> fetchHubs() async {
    final res = await _client.get(ApiConfig.hubs);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return HubModel.fromMap(map['name']?.toString() ?? '', map);
      }).toList();
      _hubsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<HubModel>> getHubs() {
    fetchHubs();
    return _hubsController.stream;
  }

  Future<ApiResponse> addHub(HubModel hub) async {
    final payload = {
      'name': hub.name,
      'code': hub.name.substring(0, hub.name.length >= 3 ? 3 : hub.name.length).toUpperCase(),
      'latitude': hub.latitude,
      'longitude': hub.longitude,
      'is_active': true,
    };
    final res = await _client.post(ApiConfig.hubs, data: payload);
    fetchHubs();
    return res;
  }

  Future<ApiResponse> updateHub(HubModel hub, String oldName) async {
    // Find hub id by oldName or name
    final hubs = await fetchHubs();
    final match = hubs.firstWhere((h) => h.name == oldName || h.name == hub.name, orElse: () => hub);
    final res = await _client.post(ApiConfig.hubs, data: hub.toMap());
    fetchHubs();
    return res;
  }

  Future<ApiResponse> deleteHub(String name) async {
    final res = await _client.get(ApiConfig.hubs);
    if (res.statusCode == 200 && res.data is List) {
      final match = (res.data as List).firstWhere(
        (h) => h['name'] == name,
        orElse: () => null,
      );
      if (match != null && match['id'] != null) {
        final delRes = await _client.delete(ApiConfig.hubDetail(match['id']));
        fetchHubs();
        return delRes;
      }
    }
    return ApiResponse(statusCode: 404, message: 'Hub not found');
  }

  Future<List<StopModel>> fetchStops() async {
    final res = await _client.get(ApiConfig.stops);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return StopModel.fromMap(map['id']?.toString() ?? '', map);
      }).toList();
      _stopsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<StopModel>> getStops() {
    fetchStops();
    return _stopsController.stream;
  }

  Future<ApiResponse> addStop(StopModel stop) async {
    final payload = {
      'name': stop.name,
      'latitude': stop.latitude,
      'longitude': stop.longitude,
      'geofence_radius_m': 70,
      'is_active': true,
    };
    final res = await _client.post(ApiConfig.stops, data: payload);
    fetchStops();
    return res;
  }

  Future<ApiResponse> updateStop(StopModel stop) async {
    final numId = int.tryParse(stop.id) ?? 0;
    final payload = {
      'name': stop.name,
      'latitude': stop.latitude,
      'longitude': stop.longitude,
    };
    final res = await _client.patch(ApiConfig.stopDetail(numId), data: payload);
    fetchStops();
    return res;
  }

  Future<ApiResponse> deleteStop(String id) async {
    final numId = int.tryParse(id) ?? 0;
    final res = await _client.delete(ApiConfig.stopDetail(numId));
    fetchStops();
    return res;
  }

  // =========================================================================
  // 5. ROUTES, ROUTE CATEGORIES & TAGS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getRoutes() async {
    final res = await _client.get(ApiConfig.routes);
    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data as List);
    }
    return [];
  }

  Future<ApiResponse> addRoute(Map<String, dynamic> data) async {
    final res = await _client.post(ApiConfig.routes, data: data);
    return res;
  }

  Future<ApiResponse> updateRoute(int id, Map<String, dynamic> data) async {
    final res = await _client.patch(ApiConfig.routeDetail(id), data: data);
    return res;
  }

  Future<ApiResponse> deleteRoute(int id) async {
    final res = await _client.delete(ApiConfig.routeDetail(id));
    return res;
  }

  Future<void> savePolyline(String routeName, List<dynamic> coordinates) async {
    final routes = await getRoutes();
    final match = routes.firstWhere((r) => r['name'] == routeName, orElse: () => {});
    if (match.isNotEmpty && match['id'] != null) {
      await updateRoute(match['id'], {'polyline_json': coordinates});
    }
  }

  Stream<Map<String, dynamic>> getPolylinesStatus() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    getRoutes().then((routes) {
      final Map<String, dynamic> result = {};
      for (var r in routes) {
        if (r['polyline_json'] != null) {
          result[r['name']] = r['polyline_json'];
        }
      }
      controller.add(result);
    });
    return controller.stream;
  }

  Future<List<RouteCategoryModel>> getRouteCategories() async {
    final res = await _client.get(ApiConfig.routeCategories);
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List).map((c) => RouteCategoryModel.fromMap(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  Future<ApiResponse> updateRouteCategory(int id, {required String name, required bool isActive}) async {
    return _client.patch(ApiConfig.routeCategoryDetail(id), data: {
      'name': name,
      'is_active': isActive,
    });
  }

  Future<List<RouteTagModel>> getRouteTags() async {
    final res = await _client.get(ApiConfig.routeTags);
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List).map((t) => RouteTagModel.fromMap(Map<String, dynamic>.from(t))).toList();
    }
    return [];
  }

  Future<ApiResponse> addRouteTag(RouteTagModel tag) async {
    return _client.post(ApiConfig.routeTags, data: tag.toMap());
  }

  Future<ApiResponse> updateRouteTag(RouteTagModel tag) async {
    return _client.patch(ApiConfig.routeTagDetail(tag.id), data: tag.toMap());
  }

  // =========================================================================
  // 6. SCHEDULES & TIME SLOTS
  // =========================================================================

  Future<List<BusSchedule>> fetchBusSchedules() async {
    final res = await _client.get(ApiConfig.timeSlots);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        final slot = AdminTimeSlotModel.fromMap(Map<String, dynamic>.from(row as Map));
        final busNum = slot.busAssignments.isNotEmpty ? slot.busAssignments.first.busNumber : 'Multiple';
        final driverName = slot.busAssignments.isNotEmpty ? slot.busAssignments.first.driverName : 'Unassigned';
        final gender = slot.busAssignments.isNotEmpty ? slot.busAssignments.first.genderName : 'Combined';

        return BusSchedule(
          id: slot.id.toString(),
          busNumber: busNum,
          route: slot.routeName,
          from: slot.originHub,
          to: slot.destinationHub,
          departureTime: slot.departureTime,
          stops: const [],
          type: gender,
          assignedDriverName: driverName,
        );
      }).toList();
      _schedulesController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<BusSchedule>> getBusSchedules() {
    fetchBusSchedules();
    return _schedulesController.stream;
  }

  Future<ApiResponse> addBusSchedule(BusSchedule schedule) async {
    // Maps to creating a TimeSlot
    final routes = await getRoutes();
    final routeMatch = routes.firstWhere((r) => r['name'] == schedule.route, orElse: () => routes.first);
    final routeId = routeMatch['id'] ?? 1;

    final profiles = await getScheduleProfiles();
    final activeProfile = profiles.firstWhere((p) => p.isActive, orElse: () => profiles.first);

    final payload = {
      'profile': activeProfile.id,
      'route': routeId,
      'shift': 'morning',
      'day_type': 'regular',
      'departure_time': schedule.departureTime ?? '07:30:00',
      'is_active': true,
    };

    final res = await _client.post(ApiConfig.timeSlots, data: payload);
    fetchBusSchedules();
    return res;
  }

  Future<ApiResponse> updateBusSchedule(String id, BusSchedule schedule, String oldRouteName) async {
    final numId = int.tryParse(id) ?? 0;
    final payload = {
      'departure_time': schedule.departureTime,
    };
    final res = await _client.patch(ApiConfig.timeSlotDetail(numId), data: payload);
    fetchBusSchedules();
    return res;
  }

  Future<ApiResponse> deleteBusSchedule(String id, String routeName, {bool forceDeleteRoute = false}) async {
    final numId = int.tryParse(id) ?? 0;
    final res = await _client.delete(ApiConfig.timeSlotDetail(numId));
    fetchBusSchedules();
    return res;
  }

  Future<List<ScheduleProfileModel>> getScheduleProfiles() async {
    final res = await _client.get(ApiConfig.scheduleProfiles);
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List).map((p) => ScheduleProfileModel.fromMap(Map<String, dynamic>.from(p))).toList();
    }
    return [];
  }

  Future<ApiResponse> createScheduleProfile(String name, String effectiveFrom) async {
    return _client.post(ApiConfig.scheduleProfiles, data: {
      'name': name,
      'effective_from': effectiveFrom,
      'is_active': false,
    });
  }

  Future<ApiResponse> setActiveProfile(int id) async {
    final res = await _client.post(ApiConfig.setActiveProfile(id));
    fetchBusSchedules();
    return res;
  }

  Future<List<AdminTimeSlotModel>> getTimeSlots({int? profileId}) async {
    final res = await _client.get(ApiConfig.timeSlots, queryParameters: profileId != null ? {'profile': profileId} : null);
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List).map((s) => AdminTimeSlotModel.fromMap(Map<String, dynamic>.from(s))).toList();
    }
    return [];
  }

  Future<ApiResponse> createBusAssignment(Map<String, dynamic> data) async {
    final res = await _client.post(ApiConfig.busAssignments, data: data);
    fetchBusSchedules();
    return res;
  }

  Future<ApiResponse> deleteBusAssignment(int id) async {
    final res = await _client.delete(ApiConfig.busAssignmentDetail(id));
    fetchBusSchedules();
    return res;
  }

  // =========================================================================
  // 7. HIGHER AUTHORITY APPROVAL WORKFLOW (MAKER-CHECKER)
  // =========================================================================

  Future<List<ChangeRequestModel>> fetchApprovals({String status = 'pending_approval'}) async {
    final res = await _client.get(ApiConfig.approvals, queryParameters: {'status': status});
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((c) => ChangeRequestModel.fromMap(Map<String, dynamic>.from(c))).toList();
      _approvalsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<ChangeRequestModel>> getApprovalsStream() {
    fetchApprovals();
    return _approvalsController.stream;
  }

  Future<ApiResponse> approveChangeRequest(int id, {String? reviewNote}) async {
    final res = await _client.post(
      ApiConfig.approveRequest(id),
      data: {'review_note': reviewNote ?? 'Approved by Higher Authority'},
    );
    fetchApprovals();
    refreshAll();
    return res;
  }

  Future<ApiResponse> rejectChangeRequest(int id, {String? reviewNote}) async {
    final res = await _client.post(
      ApiConfig.rejectRequest(id),
      data: {'review_note': reviewNote ?? 'Rejected by Higher Authority'},
    );
    fetchApprovals();
    return res;
  }

  // =========================================================================
  // 8. LIVE FLEET & STOP-SKIP VIOLATIONS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getLiveFleet() async {
    final res = await _client.get(ApiConfig.liveFleet);
    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data as List);
    }
    return [];
  }

  Future<List<StopSkipAlertModel>> getStopSkipAlerts() async {
    final res = await _client.get(ApiConfig.stopSkipAlerts);
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List).map((a) => StopSkipAlertModel.fromMap(Map<String, dynamic>.from(a))).toList();
    }
    return [];
  }

  Stream<List<Map<String, dynamic>>> getBusesStream() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    getLiveFleet().then((list) => controller.add(list));

    ws.fleetStream.listen((data) {
      if (data['trips'] != null && data['trips'] is List) {
        controller.add(List<Map<String, dynamic>>.from(data['trips']));
      } else {
        getLiveFleet().then((list) => controller.add(list));
      }
    });
    return controller.stream;
  }

  Stream<Map<String, dynamic>> getTripAlertsStream() {
    return ws.tripEventStream;
  }

  Stream<List<Map<String, dynamic>>> getTripHistoryStream() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    _client.get(ApiConfig.trips).then((res) {
      if (res.statusCode == 200 && res.data is List) {
        final list = (res.data as List).map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          map['id'] = map['id']?.toString();
          map['startTime'] = map['started_at'] != null ? DateTime.parse(map['started_at'].toString()).millisecondsSinceEpoch : 0;
          map['endTime'] = map['ended_at'] != null ? DateTime.parse(map['ended_at'].toString()).millisecondsSinceEpoch : 0;
          return map;
        }).toList();
        controller.add(list);
      }
    });
    return controller.stream;
  }

  Stream<Map<String, dynamic>> getTripAnalyticsStream() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _client.get(ApiConfig.trips).then((res) {
      if (res.statusCode == 200 && res.data is List) {
        final list = res.data as List;
        int total = list.length;
        int completed = list.where((t) => t['status'] == 'completed').length;
        double rate = total > 0 ? (completed / total) * 100 : 0.0;
        final buckets = List<int>.filled(24, 0);

        for (var t in list) {
          if (t['started_at'] != null) {
            try {
              final dt = DateTime.parse(t['started_at'].toString());
              buckets[dt.hour]++;
            } catch (_) {}
          }
        }

        int peak = 0;
        for (int i = 1; i < 24; i++) {
          if (buckets[i] > buckets[peak]) peak = i;
        }

        controller.add({
          'totalTrips': total,
          'completedTrips': completed,
          'successRate': rate,
          'peakHour': peak,
          'hourlyBuckets': buckets,
        });
      }
    });
    return controller.stream;
  }

  // =========================================================================
  // 9. SUPPORT TICKETS & EMERGENCY SOS
  // =========================================================================

  Future<List<SupportTicketModel>> fetchTickets() async {
    final res = await _client.get(ApiConfig.tickets);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return SupportTicketModel.fromMap(map['id']?.toString() ?? '', map);
      }).toList();
      _ticketsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<SupportTicketModel>> getTickets() {
    fetchTickets();
    return _ticketsController.stream;
  }

  Future<ApiResponse> updateTicketStatus(String ticketId, String status, {String? reply}) async {
    final numId = int.tryParse(ticketId) ?? 0;
    if (reply != null && reply.trim().isNotEmpty) {
      final res = await _client.post(ApiConfig.ticketReply(numId), data: {'admin_reply': reply});
      fetchTickets();
      return res;
    } else if (status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed') {
      final res = await _client.post(ApiConfig.ticketClose(numId));
      fetchTickets();
      return res;
    } else {
      final res = await _client.patch(ApiConfig.ticketDetail(numId), data: {'status': status});
      fetchTickets();
      return res;
    }
  }

  Future<void> markTicketAsRead(String ticketId) async {
    final numId = int.tryParse(ticketId) ?? 0;
    await _client.patch(ApiConfig.ticketDetail(numId), data: {'admin_read': true});
  }

  Future<List<Map<String, dynamic>>> fetchEmergencyAlerts() async {
    final res = await _client.get(ApiConfig.sos);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        map['id'] = map['id']?.toString();
        map['timestamp'] = map['created_at'] != null ? DateTime.parse(map['created_at'].toString()).millisecondsSinceEpoch : 0;
        return map;
      }).toList();
      _emergencyController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<Map<String, dynamic>>> getEmergencyAlerts() {
    fetchEmergencyAlerts();
    return _emergencyController.stream;
  }

  Future<ApiResponse> resolveEmergencyAlert(String id, {String? notes, String? resolvedBy}) async {
    final numId = int.tryParse(id) ?? 0;
    final res = await _client.post(ApiConfig.sosResolve(numId), data: {
      'status': 'resolved',
      'resolution_notes': notes ?? 'Resolved by Admin',
    });
    fetchEmergencyAlerts();
    return res;
  }

  Future<void> markEmergencyAlertAsRead(String alertId) async {
    final numId = int.tryParse(alertId) ?? 0;
    await _client.patch(ApiConfig.sosDetail(numId), data: {'admin_read': true});
  }

  // =========================================================================
  // 10. NOTIFICATIONS & BROADCASTS
  // =========================================================================

  Future<ApiResponse> sendCustomNotification({
    required String title,
    required String message,
    required String targetAudience,
    required String type,
    String? imageUrl,
  }) async {
    final role = targetAudience.toLowerCase().contains('student')
        ? 'student'
        : (targetAudience.toLowerCase().contains('driver') ? 'driver' : 'all');

    return _client.post(ApiConfig.broadcastNotification, data: {
      'title': title,
      'message': message,
      'target_role': role,
      'notification_type': type,
      'image_url': imageUrl,
    });
  }

  Future<ApiResponse> sendUserNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? imageUrl,
    Map<String, dynamic>? extraData,
  }) async {
    final numId = int.tryParse(userId) ?? 0;
    return _client.post(ApiConfig.sendUserNotification, data: {
      'user_id': numId,
      'title': title,
      'message': message,
      'notification_type': type,
      'image_url': imageUrl,
    });
  }

  Stream<List<Map<String, dynamic>>> getSentNotifications() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    _client.get(ApiConfig.notifications).then((res) {
      if (res.statusCode == 200 && res.data is List) {
        final list = (res.data as List).map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return {
            'id': map['id']?.toString(),
            'title': map['title'] ?? '',
            'message': map['message'] ?? '',
            'targetAudience': map['target_role'] ?? 'all',
            'type': map['notification_type'] ?? 'info',
            'imageUrl': map['image'],
            'timestamp': map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
          };
        }).toList();
        controller.add(list);
      }
    });
    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> getAllNotificationUsers() async {
    final res = await _client.get(ApiConfig.adminUsers);
    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data as List);
    }
    return [];
  }

  // =========================================================================
  // 11. AUDIT LOGS, FAQS, CONTACTS & CONFIG
  // =========================================================================

  Future<void> logActivity({
    required String action,
    required String target,
    String? details,
  }) async {
    try {
      await _client.post(ApiConfig.auditLogs, data: {
        'action': action,
        'target': target,
        'details': details,
      });
    } catch (_) {}
  }

  Future<List<AuditLogModel>> fetchAuditLogs() async {
    final res = await _client.get(ApiConfig.auditLogs);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        return AuditLogModel.fromMap(Map<String, dynamic>.from(row as Map));
      }).toList();
      _auditLogsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<AuditLogModel>> getAuditLogs() {
    fetchAuditLogs();
    return _auditLogsController.stream;
  }

  Future<List<FaqModel>> fetchFaqs() async {
    final res = await _client.get(ApiConfig.faqs);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return FaqModel.fromMap(map['id']?.toString() ?? '', map);
      }).toList();
      _faqsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<FaqModel>> getFaqs() {
    fetchFaqs();
    return _faqsController.stream;
  }

  Future<ApiResponse> addFaq(FaqModel faq) async {
    final res = await _client.post(ApiConfig.faqs, data: faq.toMap());
    fetchFaqs();
    return res;
  }

  Future<ApiResponse> updateFaq(FaqModel faq) async {
    final numId = int.tryParse(faq.id) ?? 0;
    final res = await _client.patch(ApiConfig.faqDetail(numId), data: faq.toMap());
    fetchFaqs();
    return res;
  }

  Future<ApiResponse> deleteFaq(String id) async {
    final numId = int.tryParse(id) ?? 0;
    final res = await _client.delete(ApiConfig.faqDetail(numId));
    fetchFaqs();
    return res;
  }

  Future<List<TransportContactModel>> fetchContacts() async {
    final res = await _client.get(ApiConfig.contacts);
    if (res.statusCode == 200 && res.data is List) {
      final list = (res.data as List).map((c) => TransportContactModel.fromMap(Map<String, dynamic>.from(c))).toList();
      _contactsController.add(list);
      return list;
    }
    return [];
  }

  Stream<List<TransportContactModel>> getContacts() {
    fetchContacts();
    return _contactsController.stream;
  }

  Future<ApiResponse> updateContact(TransportContactModel contact) async {
    final res = await _client.patch(ApiConfig.contactDetail(contact.id), data: contact.toMap());
    fetchContacts();
    return res;
  }

  Future<void> uploadInitialAppInfo() async {
    // Config initialized on Django backend
  }

  Future<void> updateAppInfo(Map<String, dynamic> data) async {
    await _client.post(ApiConfig.config, data: {'key': 'about', 'value_json': data});
  }

  Stream<Map<String, dynamic>> getSafetyConfig() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _client.get(ApiConfig.config, queryParameters: {'key': 'safety'}).then((res) {
      if (res.statusCode == 200 && res.data is Map) {
        controller.add(Map<String, dynamic>.from(res.data['value_json'] as Map? ?? {
          'speedLimit': 60.0,
          'geofencingEnabled': true,
          'overspeedingEnabled': true,
          'geofenceRadiusMeters': 70,
        }));
      } else {
        controller.add({
          'speedLimit': 60.0,
          'geofencingEnabled': true,
          'overspeedingEnabled': true,
          'geofenceRadiusMeters': 70,
        });
      }
    });
    return controller.stream;
  }

  Future<void> updateSafetyConfig(Map<String, dynamic> config) async {
    await _client.post(ApiConfig.config, data: {'key': 'safety', 'value_json': config});
    await logActivity(
      action: 'Updated Safety Config',
      target: 'Speed Limit: ${config['speedLimit']} km/h',
    );
  }

  Future<Map<String, String>> fetchGenderConfigs() async {
    final res = await _client.get(ApiConfig.genderCategories);
    if (res.statusCode == 200 && res.data is List) {
      final Map<String, String> map = {};
      for (var row in res.data as List) {
        map[row['name']?.toString() ?? ''] = row['color_hex']?.toString() ?? '#2196F3';
      }
      _genderConfigsController.add(map);
      return map;
    }
    return {
      'Girls Special': '#E91E63',
      'Boys Special': '#2196F3',
      'Combined': '#9C27B0',
    };
  }

  Stream<Map<String, String>> getGenderConfigs() {
    fetchGenderConfigs();
    return _genderConfigsController.stream;
  }

  Future<void> updateGenderConfig(String name, String colorHex) async {
    await _client.post(ApiConfig.genderCategories, data: {
      'name': name,
      'color_hex': colorHex,
      'is_active': true,
    });
    fetchGenderConfigs();
  }

  Future<void> deleteGenderConfig(String name) async {
    // Delete gender config
    fetchGenderConfigs();
  }

  Future<String> uploadImage(Uint8List fileBytes, String path) async {
    // Free local representation (Base64 data URI)
    final base64String = base64Encode(fileBytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  Stream<Map<String, dynamic>> getStatsStream() {
    return getRealTimeStats();
  }

  Stream<Map<String, dynamic>> getRealTimeStats() {
    // Dynamic periodic query for real time dashboard stats
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    void loadStats() async {
      try {
        final students = await fetchStudents();
        final drivers = await fetchDrivers();
        final liveFleet = await getLiveFleet();

        if (!controller.isClosed) {
          controller.add({
            'totalStudents': students.length,
            'totalDrivers': drivers.length,
            'activeTrips': liveFleet.length,
            'totalRevenue': 0.0,
          });
        }
      } catch (_) {}
    }

    loadStats();
    final timer = Timer.periodic(const Duration(seconds: 15), (_) => loadStats());
    controller.onCancel = () => timer.cancel();
    return controller.stream;
  }
}

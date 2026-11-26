import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unitransit_admin/Core/Util/CloudFirestoreCompat.dart';
import 'package:unitransit_admin/Models/DriverModel.dart';
import 'package:unitransit_admin/Models/StudentModel.dart';
import 'package:unitransit_admin/Models/BusScheduleModel.dart';
import 'package:unitransit_admin/Models/HubModel.dart';
import 'package:unitransit_admin/Models/StopModel.dart';
import 'package:unitransit_admin/Models/SupportTicketModel.dart';
import 'package:unitransit_admin/Models/FaqModel.dart';
import 'package:unitransit_admin/Models/AuditLogModel.dart';

Map<String, dynamic> toSnakeCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    // Translate key to snake_case
    final snakeKey = key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
    
    // Handle Timestamp / FieldValue translations
    if (value is Timestamp) {
      result[snakeKey] = value.toDate().toIso8601String();
    } else if (value is DateTime) {
      result[snakeKey] = value.toIso8601String();
    } else if (value is List) {
      result[snakeKey] = value.map((item) {
        if (item is Map) {
          return toSnakeCase(Map<String, dynamic>.from(item));
        }
        return item;
      }).toList();
    } else if (value is Map) {
      result[snakeKey] = toSnakeCase(Map<String, dynamic>.from(value));
    } else {
      result[snakeKey] = value;
    }
  });
  return result;
}

Map<String, dynamic> toCamelCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    // Translate key to camelCase
    final camelKey = key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
    
    // Convert string timestamps back to Timestamp compatibility object
    if (key == 'timestamp' || key == 'created_at' || key == 'resolved_at' || key == 'license_expiry' || key == 'start_time' || key == 'end_time' || key == 'updated_at') {
      if (value is String) {
        try {
          result[camelKey] = Timestamp(DateTime.parse(value));
        } catch (_) {
          result[camelKey] = Timestamp(DateTime.now());
        }
      } else if (value is DateTime) {
        result[camelKey] = Timestamp(value);
      } else {
        result[camelKey] = value;
      }
    } else if (value is List) {
      result[camelKey] = value.map((item) {
        if (item is Map) {
          return toCamelCase(Map<String, dynamic>.from(item));
        }
        return item;
      }).toList();
    } else if (value is Map) {
      result[camelKey] = toCamelCase(Map<String, dynamic>.from(value));
    } else {
      result[camelKey] = value;
    }
  });
  return result;
}

class FirebaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Create User Authentication without logging out the current admin
  Future<String> createUserAuth(String email, String password) async {
    try {
      // Use a secondary client to avoid logging out the current admin user
      final tempClient = SupabaseClient(
        'https://eplzrubpbqsdmezvkjgz.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwbHpydWJwYnFzZG1lenZramd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNDgxMjQsImV4cCI6MjEwMDcyNDEyNH0.l633BESZHDigcg9ViA_tmhkFdcxoACoKmcBRRbuyS8w',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final response = await tempClient.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) throw 'Authentication creation failed';
      return response.user!.id;
    } catch (e) {
      throw 'Authentication creation failed: $e';
    }
  }

  // Generic Image Upload
  Future<String> uploadImage(Uint8List fileBytes, String path) async {
    try {
      final cleanPath = path.replaceAll('uploads/', '').replaceAll('profile_images/', '');
      final uniquePath = "${DateTime.now().millisecondsSinceEpoch}_$cleanPath";
      await _client.storage.from('profile-images').uploadBinary(
        uniquePath,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );
      return _client.storage.from('profile-images').getPublicUrl(uniquePath);
    } catch (e) {
      print("Image upload FAILED at $path: $e");
      rethrow;
    }
  }

  // Drivers
  Future<void> addDriver(DriverModel driver) async {
    final profileData = {
      'id': driver.id,
      'name': driver.name,
      'email': driver.email,
      'role': 'Driver',
      'is_verified': driver.isVerified,
      'is_blocked': driver.isBlocked,
      'status': driver.status,
    };
    await _client.from('profiles').upsert(profileData);
    
    final driverData = toSnakeCase(driver.toMap());
    await _client.from('drivers').upsert(driverData);
    
    await logActivity(action: 'Added Driver', target: 'Driver: ${driver.name}');
  }

  Stream<List<DriverModel>> getDrivers() {
    return _client
        .from('drivers')
        .select().asStream()
        .map((event) {
          return event.map((row) {
            return DriverModel.fromMap(toCamelCase(row));
          }).toList();
        });
  }

  Future<void> updateDriver(DriverModel driver) async {
    final profileData = {
      'name': driver.name,
      'is_verified': driver.isVerified,
      'is_blocked': driver.isBlocked,
      'status': driver.status,
    };
    await _client.from('profiles').update(profileData).eq('id', driver.id);
    await _client.from('drivers').update(toSnakeCase(driver.toMap())).eq('id', driver.id);
    
    await logActivity(
      action: 'Updated Driver',
      target: 'Driver: ${driver.name}',
    );
  }

  Future<void> deleteDriver(String id) async {
    try {
      await _client.from('profiles').delete().eq('id', id);
      await logActivity(action: 'Deleted Driver', target: 'Driver: $id');
    } catch (e) {
      await _client.from('profiles').delete().eq('id', id);
    }
  }

  Future<void> resetDriverPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> resetStudentPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // Students
  Future<void> addStudent(StudentModel student) async {
    final profileData = toSnakeCase(student.toMap());
    profileData['role'] = 'Student';
    profileData['is_verified'] = student.isVerified;
    profileData['is_blocked'] = student.isBlocked;

    await _client.from('profiles').upsert(profileData);
    await logActivity(
      action: 'Added Student',
      target: 'Student: ${student.name}',
    );
  }

  Stream<List<StudentModel>> getStudents() {
    return _client
        .from('profiles')
        .select().eq('role', 'Student').asStream()
        .map((event) {
          final students = event.map((row) {
            final doc = DocumentSnapshot(row['id'], toCamelCase(row));
            return StudentModel.fromMap(doc.data()!, docId: doc.id);
          }).toList();
          students.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return students;
        });
  }

  Future<void> updateStudent(StudentModel student) async {
    final profileData = toSnakeCase(student.toMap());
    await _client.from('profiles').update(profileData).eq('id', student.id);
  }

  Future<void> deleteStudent(String id) async {
    try {
      await _client.from('profiles').delete().eq('id', id);
      await logActivity(action: 'Deleted Student', target: 'Student: $id');
    } catch (e) {
      await _client.from('profiles').delete().eq('id', id);
    }
  }

  // Routes & Schedules
  Stream<List<BusSchedule>> getBusSchedules() {
    return _client.from('schedules').select().asStream().map((event) {
      return event.map((row) {
        return BusSchedule.fromMap(row['id'].toString(), toCamelCase(row));
      }).toList();
    });
  }

  Future<void> addBusSchedule(BusSchedule schedule) async {
    final data = toSnakeCase(schedule.toMap());
    data.remove('id');
    await _client.from('schedules').insert(data);
  }

  Future<void> deleteBusSchedule(String id, String routeName, {bool forceDeleteRoute = false}) async {
    await _client.from('schedules').delete().eq('id', id);
  }

  // Hub Management (Supabase DB)
  Future<void> addHub(HubModel hub) async {
    await _client.from('hubs').insert({
      'name': hub.name,
      'latitude': hub.latitude,
      'longitude': hub.longitude,
    });
  }

  Future<void> updateHub(HubModel hub, String oldName) async {
    if (hub.name != oldName) {
      await _client.from('hubs').delete().eq('name', oldName);
    }
    await _client.from('hubs').upsert({
      'name': hub.name,
      'latitude': hub.latitude,
      'longitude': hub.longitude,
    });
  }

  Stream<List<HubModel>> getHubs() {
    return _client.from('hubs').select().asStream().map((event) {
      return event.map((row) {
        return HubModel.fromMap(row['name'].toString(), toCamelCase(row));
      }).toList();
    });
  }

  Future<void> deleteHub(String name) async {
    await _client.from('hubs').delete().eq('name', name);
  }

  // Polyline Management (Supabase DB)
  Future<void> savePolyline(String routeName, List<dynamic> coordinates) async {
    await _client.from('custom_polylines').upsert({
      'route_name': routeName,
      'coordinates': coordinates,
    });
  }

  // Stop Management (Supabase DB)
  Future<void> addStop(StopModel stop) async {
    await _client.from('stops').insert(toSnakeCase(stop.toMap()));
  }

  Future<void> updateStop(StopModel stop) async {
    await _client.from('stops').update(toSnakeCase(stop.toMap())).eq('id', stop.id);
  }

  Future<void> deleteStop(String id) async {
    await _client.from('stops').delete().eq('id', id);
  }

  Stream<List<StopModel>> getStops() {
    return _client.from('stops').select().asStream().map((event) {
      return event.map((row) {
        return StopModel.fromMap(row['id'].toString(), toCamelCase(row));
      }).toList();
    });
  }

  Future<void> updateBusSchedule(
    String id,
    BusSchedule schedule,
    String oldRouteName,
  ) async {
    await _client.from('schedules').update(toSnakeCase(schedule.toMap())).eq('id', id);
  }

  Stream<Map<String, dynamic>> getPolylinesStatus() {
    return _client.from('custom_polylines').select().asStream().map((event) {
      final Map<String, dynamic> result = {};
      for (var row in event) {
        result[row['route_name']] = row['coordinates'];
      }
      return result;
    });
  }

  // Real-time Stats Stream
  Stream<Map<String, dynamic>> getStatsStream() {
    return getRealTimeStats();
  }

  Stream<Map<String, dynamic>> getRealTimeStats() {
    late StreamController<Map<String, dynamic>> controller;
    StreamSubscription? profileSub;
    StreamSubscription? driverSub;
    StreamSubscription? activeBusSub;
    StreamSubscription? completedTripSub;

    int totalStudents = 0;
    int totalDrivers = 0;
    int activeTrips = 0;
    double totalRevenue = 0.0;

    void emit() {
      if (!controller.isClosed) {
        controller.add({
          'totalStudents': totalStudents,
          'totalDrivers': totalDrivers,
          'activeTrips': activeTrips,
          'totalRevenue': totalRevenue,
        });
      }
    }

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        profileSub = _client.from('profiles').select().eq('role', 'Student').asStream().listen((event) {
          totalStudents = event.length;
          emit();
        });
        driverSub = _client.from('drivers').select().asStream().listen((event) {
          totalDrivers = event.length;
          emit();
        });
        activeBusSub = _client.from('active_buses').select().asStream().listen((event) {
          activeTrips = event.length;
          emit();
        });
        completedTripSub = _client.from('completed_trips').select().asStream().listen((event) {
          double tempRevenue = 0.0;
          for (var row in event) {
            final val = row['revenue'];
            if (val != null) {
              tempRevenue += (val as num).toDouble();
            }
          }
          totalRevenue = tempRevenue;
          emit();
        });
      },
      onCancel: () {
        profileSub?.cancel();
        driverSub?.cancel();
        activeBusSub?.cancel();
        completedTripSub?.cancel();
      }
    );
    return controller.stream;
  }

  Future<int> getAdminsCount() async {
    final res = await _client.from('profiles').select().eq('role', 'Admin');
    return res.length;
  }

  // Gender Configuration (Supabase DB Settings Table)
  Future<void> updateGenderConfig(String name, String colorHex) async {
    final res = await _client.from('app_settings').select().eq('key', 'gender_configs').maybeSingle();
    final Map<String, dynamic> configs = res != null ? Map<String, dynamic>.from(res['value'] as Map) : {
      'Girls Special': '#E91E63',
      'Boys Special': '#2196F3',
      'Combined': '#9C27B0',
    };
    configs[name] = colorHex;
    await _client.from('app_settings').upsert({
      'key': 'gender_configs',
      'value': configs,
    });
  }

  Future<void> deleteGenderConfig(String name) async {
    final res = await _client.from('app_settings').select().eq('key', 'gender_configs').maybeSingle();
    if (res != null) {
      final Map<String, dynamic> configs = Map<String, dynamic>.from(res['value'] as Map);
      configs.remove(name);
      await _client.from('app_settings').upsert({
        'key': 'gender_configs',
        'value': configs,
      });
    }
  }

  Stream<Map<String, String>> getGenderConfigs() {
    return _client
        .from('app_settings')
        .select().eq('key', 'gender_configs').asStream()
        .map((event) {
          if (event.isEmpty) {
            return {
              'Girls Special': '#E91E63',
              'Boys Special': '#2196F3',
              'Combined': '#9C27B0',
            };
          }
          final configs = Map<String, dynamic>.from(event.first['value'] as Map);
          return configs.map((key, value) => MapEntry(key, value.toString()));
        });
  }

  // Support Tickets
  Stream<List<SupportTicketModel>> getTickets() {
    return _client.from('support_tickets').select().asStream().map((event) {
      final list = event.map((row) {
        return SupportTicketModel.fromMap(row['id'].toString(), toCamelCase(row));
      }).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> updateTicketStatus(
    String ticketId,
    String status, {
    String? reply,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'admin_read': true,
    };
    if (reply != null) {
      updates['admin_reply'] = reply;
      updates['user_read'] = false;
    }
    if (status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed') {
      updates['resolved_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('support_tickets').update(updates).eq('id', ticketId);

    if (reply != null && reply.trim().isNotEmpty) {
      try {
        final ticket = await _client.from('support_tickets').select().eq('id', ticketId).maybeSingle();
        if (ticket != null) {
          final userId = ticket['user_id'];
          final userRole = ticket['user_role'] ?? 'Student';
          
          if (userId != null) {
            await _client.from('notifications').insert({
              'user_id': userId,
              'title': 'Support Ticket Update',
              'message': 'Your support query has been resolved: "$reply"',
              'type': 'support',
              'is_read': false,
              'target_role': userRole,
              'ticket_id': ticketId,
            });
          }
        }
      } catch (e) {
        print('Error generating reply notification: $e');
      }
    }
  }

  Future<void> markTicketAsRead(String ticketId) async {
    await _client.from('support_tickets').update({'admin_read': true}).eq('id', ticketId);
  }

  Future<void> markEmergencyAlertAsRead(String alertId) async {
    await _client.from('emergency_alerts').update({'admin_read': true}).eq('id', alertId);
  }

  // App Settings / About Info
  Future<void> uploadInitialAppInfo() async {
    final doc = await _client.from('app_settings').select().eq('key', 'about').maybeSingle();
    if (doc == null) {
      await _client.from('app_settings').insert({
        'key': 'about',
        'value': {
          'vision':
              "UniTransit is a state-of-the-art solution designed for The Islamia University of Bahawalpur to digitize the bus tracking experience. It leverages real-time GPS data, Supabase synchronization, and smart routing algorithms to ensure students never miss their commute.",
          'version': "1.2.0 (Stable)",
          'university': "The Islamia University of Bahawalpur",
          'appLogoUrl': "",
          'contributors': [
            {
              "role": "Lead Developer",
              "name": "Noor Mustafa",
              "subtitle": "Roll No: F22BDOCS1M01160",
            },
            {
              "role": "Supervisor",
              "name": "Dr. Umar Farooq Shafi",
              "subtitle": "Department of CS & IT, IUB",
            },
          ],
        }
      });
    }
  }

  // FAQs
  Stream<List<FaqModel>> getFaqs() {
    return _client.from('faqs').select().asStream().map((event) {
      final list = event.map((row) {
        return FaqModel.fromMap(row['id'].toString(), toCamelCase(row));
      }).toList();
      list.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
      return list;
    });
  }

  Future<void> addFaq(FaqModel faq) async {
    final data = toSnakeCase(faq.toMap());
    data.remove('id');
    await _client.from('faqs').insert(data);
  }

  Future<void> updateFaq(FaqModel faq) async {
    await _client.from('faqs').update(toSnakeCase(faq.toMap())).eq('id', faq.id);
  }

  Future<void> deleteFaq(String id) async {
    await _client.from('faqs').delete().eq('id', id);
  }

  Future<void> updateAppInfo(Map<String, dynamic> data) async {
    await _client.from('app_settings').upsert({
      'key': 'about',
      'value': data,
    });
  }

  // Send notification to a specific user (student/driver)
  Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'info', 'alert', 'system', 'sos_resolved'
    String? imageUrl,
    Map<String, dynamic>? extraData,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'image_url': imageUrl,
      'is_read': false,
      'target_role': 'Specific User',
    });
  }

  // Send Custom Broadcast Notifications to Students, Drivers, or All
  Future<void> sendCustomNotification({
    required String title,
    required String message,
    required String targetAudience, // 'Students', 'Drivers', 'All'
    required String type, // 'info', 'alert', 'system'
    String? imageUrl,
  }) async {
    await _client.from('notifications').insert({
      'title': title,
      'message': message,
      'type': type,
      'image_url': imageUrl,
      'target_role': targetAudience,
    });
  }

  // Get sent admin notifications stream
  Stream<List<Map<String, dynamic>>> getSentNotifications() {
    return _client.from('notifications').select().asStream().map((event) {
      final list = event.map((row) {
        final data = toCamelCase(row);
        return {
          'id': data['id'],
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'targetAudience': data['targetRole'] ?? 'All',
          'type': data['type'] ?? 'info',
          'imageUrl': data['imageUrl'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
      list.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      return list;
    });
  }

  // Fetch all users eligible for receiving notifications (Students and Drivers)
  Future<List<Map<String, dynamic>>> getAllNotificationUsers() async {
    final res = await _client.from('profiles').select().or('role.eq.Student,role.eq.Driver');
    return List<Map<String, dynamic>>.from(res);
  }

  // Emergency Alerts (Supabase DB)
  Stream<List<Map<String, dynamic>>> getEmergencyAlerts() {
    return _client.from('emergency_alerts').select().asStream().map((event) {
      final list = event.map((row) {
        final data = toCamelCase(row);
        data['id'] = row['id'];
        data['timestamp'] = (data['timestamp'] as Timestamp?)?.toDate().millisecondsSinceEpoch ?? 0;
        if (data['resolvedAt'] != null && data['resolvedAt'] is Timestamp) {
          data['resolvedAt'] = (data['resolvedAt'] as Timestamp).toDate().millisecondsSinceEpoch;
        }
        return data;
      }).toList();
      list.sort((a, b) => (b['timestamp'] as num).compareTo(a['timestamp'] as num));
      return list;
    });
  }

  Future<void> resolveEmergencyAlert(
    String id, {
    String? notes,
    String? resolvedBy,
  }) async {
    try {
      final alert = await _client.from('emergency_alerts').select().eq('id', id).maybeSingle();
      if (alert != null) {
        final userId = alert['user_id'];
        if (userId != null) {
          await sendUserNotification(
            userId: userId,
            title: 'SOS Alert Resolved 🟢',
            message: 'Admin resolved your SOS: "${notes ?? 'Incident Handled'}". Please rate our assistance.',
            type: 'sos_resolved',
            extraData: {
              'alertId': id,
              'alertMessage': alert['message'] ?? 'Emergency SOS Alert',
            },
          );
        }
      }
    } catch (e) {
      print("Error triggering SOS resolution notification: $e");
    }

    await _client.from('emergency_alerts').update({
      'status': 'resolved',
      'resolution_notes': notes ?? 'Resolved by Admin',
      'resolved_by': resolvedBy ?? 'Admin',
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // Trip History (Supabase DB)
  Stream<List<Map<String, dynamic>>> getTripHistoryStream() {
    return _client.from('completed_trips').select().asStream().map((event) {
      final list = event.map((row) {
        final data = toCamelCase(row);
        data['startTime'] = (data['startTime'] as Timestamp?)?.toDate().millisecondsSinceEpoch ?? 0;
        data['endTime'] = (data['endTime'] as Timestamp?)?.toDate().millisecondsSinceEpoch ?? 0;
        return data;
      }).toList();
      list.sort((a, b) => (b['startTime'] as num).compareTo(a['startTime'] as num));
      return list;
    });
  }

  // Trip Alerts (Supabase Broadcast Channel)
  Stream<Map<String, dynamic>> getTripAlertsStream() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final channel = _client.channel('trip_alerts_channel');
    channel.onBroadcast(
      event: 'trip_started',
      callback: (payload) {
        controller.add(Map<String, dynamic>.from(payload));
      },
    ).onBroadcast(
      event: 'trip_stopped',
      callback: (payload) {
        controller.add(Map<String, dynamic>.from(payload));
      },
    ).subscribe();
    return controller.stream;
  }

  // Audit Logs
  Future<void> logActivity({
    required String action,
    required String target,
    String? details,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final adminDoc = await _client.from('profiles').select('name').eq('id', user.id).maybeSingle();
      final adminName = adminDoc?['name'] ?? user.email ?? 'Unknown Admin';

      await _client.from('audit_logs').insert({
        'admin_id': user.id,
        'admin_name': adminName,
        'action': action,
        'target': target,
        'details': details,
      });
    } catch (e) {
      print("Failed to log activity: $e");
    }
  }

  Stream<List<AuditLogModel>> getAuditLogs() {
    return _client
        .from('audit_logs')
        .select().asStream()
        .map((event) {
          final list = event.map((row) {
            return AuditLogModel.fromFirestore(DocumentSnapshot(row['id'].toString(), toCamelCase(row)));
          }).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  // Safety Configuration (Supabase app_settings table)
  Stream<Map<String, dynamic>> getSafetyConfig() {
    return _client
        .from('app_settings')
        .select().eq('key', 'safety').asStream()
        .map((event) {
          if (event.isEmpty) {
            return {
              'speedLimit': 60.0,
              'geofencingEnabled': true,
              'overspeedingEnabled': true,
              'geofenceRadiusMeters': 200,
            };
          }
          final map = Map<String, dynamic>.from(event.first['value'] as Map);
          return {
            'speedLimit': (map['speedLimit'] ?? 60).toDouble(),
            'geofencingEnabled': map['geofencingEnabled'] ?? true,
            'overspeedingEnabled': map['overspeedingEnabled'] ?? true,
            'geofenceRadiusMeters': map['geofenceRadiusMeters'] ?? 200,
          };
        });
  }

  Future<void> updateSafetyConfig(Map<String, dynamic> config) async {
    await _client.from('app_settings').upsert({
      'key': 'safety',
      'value': config,
    });
    await logActivity(
      action: 'Updated Safety Config',
      target: 'Speed Limit: ${config['speedLimit']} km/h',
    );
  }

  // Real-Time Trip Analytics Stream (Supabase DB)
  Stream<Map<String, dynamic>> getTripAnalyticsStream() {
    return _client
        .from('completed_trips')
        .select().asStream()
        .map((event) {
          int totalTrips = event.length;
          int completedTrips = event.where((t) => t['status'] == 'completed').length;
          double successRate = totalTrips > 0 ? (completedTrips / totalTrips) * 100 : 0.0;

          final List<int> hourlyBuckets = List<int>.filled(24, 0);
          for (var trip in event) {
            final startTimeVal = trip['start_time'];
            if (startTimeVal != null) {
              try {
                final dt = DateTime.parse(startTimeVal);
                hourlyBuckets[dt.hour]++;
              } catch (_) {}
            }
          }

          int peakHour = 0;
          for (int i = 1; i < 24; i++) {
            if (hourlyBuckets[i] > hourlyBuckets[peakHour]) peakHour = i;
          }

          return {
            'totalTrips': totalTrips,
            'completedTrips': completedTrips,
            'successRate': successRate,
            'peakHour': peakHour,
            'hourlyBuckets': hourlyBuckets,
          };
        });
  }

  // Buses Stream (Supabase active_buses table)
  Stream<List<Map<String, dynamic>>> getBusesStream() {
    return _client
        .from('active_buses')
        .select().asStream()
        .map((event) {
          return event.map((row) {
            final data = toCamelCase(row);
            data['id'] = row['bus_number'];
            return data;
          }).toList();
        });
  }
}


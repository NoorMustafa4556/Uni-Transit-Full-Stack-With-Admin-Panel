import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

extension SupabaseUserExtension on User {
  String get uid => id;
  String? get displayName => userMetadata?['name'] as String?;
}

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? rollNo,
    String? regNo,
    String? department,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          if (rollNo != null) 'rollNo': rollNo,
          if (regNo != null) 'regNo': regNo,
          if (department != null) 'department': department,
        },
      );
      
      return response;
    } catch (e) {
      AppLogger.error("SignUp error: $e");
      rethrow;
    }
  }

  // Login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // Mark student/driver as Online in Profiles
      final uid = response.user?.id;
      if (uid != null) {
        try {
          await _client.from('profiles').update({'status': 'Online'}).eq('id', uid);
        } catch (_) {}
      }
      
      return response;
    } catch (e) {
      AppLogger.error("Login error: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await _client.from('profiles').update({'status': 'Offline'}).eq('id', uid);
      } catch (_) {}
    }
    await _client.auth.signOut();
  }

  // Get User Role with Fallback
  Future<String?> getUserRole(String uid) async {
    try {
      // 1. Check profiles table
      final profileRes = await _client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      
      if (profileRes != null && profileRes['role'] != null) {
        return profileRes['role'] as String;
      }

      // 2. Check drivers table
      final driverRes = await _client
          .from('drivers')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      
      if (driverRes != null) {
        return 'Driver';
      }
    } catch (e) {
      AppLogger.error("Error getting user role: $e");
    }
    return null;
  }

  // Update Name
  Future<void> updateName(String uid, String newName) async {
    try {
      await _client.from('profiles').update({'name': newName}).eq('id', uid);
      await _client.auth.updateUser(
        UserAttributes(data: {'name': newName}),
      );
    } catch (e) {
      AppLogger.error("Error updating name: $e");
      rethrow;
    }
  }

  // Complete/Update Profile
  Future<void> updateProfile({
    required String uid,
    String? profileImageUrl,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (profileImageUrl != null) data['profile_image'] = profileImageUrl;
      if (rollNo != null) data['roll_no'] = rollNo;
      if (regNo != null) data['reg_no'] = regNo;
      if (department != null) data['department'] = department;
      if (semester != null) data['semester'] = semester;
      if (phone != null) data['phone'] = phone;
      
      if (data.isNotEmpty) {
        await _client.from('profiles').update(data).eq('id', uid);
      }
    } catch (e) {
      AppLogger.error("Error updating profile: $e");
      rethrow;
    }
  }

  // Change Password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      AppLogger.error("Error changing password: $e");
      rethrow;
    }
  }

  // Get Current User
  User? get currentUser => _client.auth.currentUser;

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      AppLogger.error("Error sending reset email: $e");
      rethrow;
    }
  }

  // Auth State Changes stream
  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session?.user);
}

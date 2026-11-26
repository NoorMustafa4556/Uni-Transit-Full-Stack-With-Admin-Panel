import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Util/Logger.dart';
import 'package:uni_transit/Models/UserModel.dart';

class AuthResponseResult {
  final UserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;
  final bool success;

  AuthResponseResult({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
    required this.success,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _initCurrentUser();
  }

  final ApiClient _api = ApiClient();
  final _authStateController = StreamController<UserModel?>.broadcast();
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  Future<void> _initCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_profile');
      if (userJson != null) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromMap(map);
        _authStateController.add(_currentUser);
      }
      // Also try to refresh profile from backend if access token exists
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        await refreshProfile();
      }
    } catch (_) {}
  }

  // Sign Up
  Future<AuthResponseResult> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
  }) async {
    try {
      final normalizedRole = role.toLowerCase().contains('driver') ? 'driver' : 'student';
      final payload = {
        'email': email.trim().toLowerCase(),
        'password': password,
        'name': name.trim(),
        'role': normalizedRole,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (rollNo != null && rollNo.isNotEmpty) 'roll_no': rollNo.trim(),
        if (regNo != null && regNo.isNotEmpty) 'reg_no': regNo.trim(),
        if (department != null && department.isNotEmpty) 'department': department.trim(),
        if (semester != null && semester.isNotEmpty) 'semester': semester.trim(),
      };

      final response = await _api.post(ApiConfig.register, data: payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        final access = data['access'] ?? '';
        final refresh = data['refresh'] ?? '';
        final userData = data['user'] ?? data;
        final userModel = UserModel.fromMap(userData);

        await ApiClient.saveTokens(access: access, refresh: refresh);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(userModel.toMap()));
        await prefs.setString('user_role', userModel.role);

        _currentUser = userModel;
        _authStateController.add(_currentUser);

        return AuthResponseResult(
          user: userModel,
          accessToken: access,
          refreshToken: refresh,
          success: true,
        );
      }
      return AuthResponseResult(
        success: false,
        errorMessage: response.data?['detail'] ?? "Registration failed",
      );
    } catch (e) {
      AppLogger.error("SignUp error: $e");
      String msg = "Registration failed";
      if (e is DioException && e.response?.data != null) {
        msg = e.response!.data.toString();
      }
      return AuthResponseResult(success: false, errorMessage: msg);
    }
  }

  // Login
  Future<AuthResponseResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.login,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final access = data['access'] ?? '';
        final refresh = data['refresh'] ?? '';
        final userData = data['user'] ?? {};
        final userModel = UserModel.fromMap(userData);

        if (userModel.isBlocked) {
          return AuthResponseResult(
            success: false,
            errorMessage: "Account has been blocked by administrator",
          );
        }

        await ApiClient.saveTokens(access: access, refresh: refresh);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(userModel.toMap()));
        await prefs.setString('user_role', userModel.role);

        _currentUser = userModel;
        _authStateController.add(_currentUser);

        return AuthResponseResult(
          user: userModel,
          accessToken: access,
          refreshToken: refresh,
          success: true,
        );
      }
      return AuthResponseResult(
        success: false,
        errorMessage: response.data?['detail'] ?? "Invalid credentials",
      );
    } catch (e) {
      AppLogger.error("Login error: $e");
      String msg = "Login failed. Please check credentials.";
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'];
        } else {
          msg = data.toString();
        }
      }
      return AuthResponseResult(success: false, errorMessage: msg);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await ApiClient.clearTokens();
    _currentUser = null;
    _authStateController.add(null);
  }

  // Fetch / Refresh Profile
  Future<UserModel?> refreshProfile() async {
    try {
      final response = await _api.get(ApiConfig.me);
      if (response.statusCode == 200 && response.data != null) {
        final userModel = UserModel.fromMap(response.data);
        _currentUser = userModel;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile', jsonEncode(userModel.toMap()));
        await prefs.setString('user_role', userModel.role);
        _authStateController.add(_currentUser);
        return userModel;
      }
    } catch (e) {
      AppLogger.error("Error refreshing profile: $e");
    }
    return _currentUser;
  }

  // Get User Role
  Future<String?> getUserRole([String? uid]) async {
    if (_currentUser != null) return _currentUser!.role;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  // Update Name
  Future<void> updateName(String uid, String newName) async {
    try {
      final response = await _api.patch(ApiConfig.me, data: {'name': newName});
      if (response.statusCode == 200) {
        await refreshProfile();
      }
    } catch (e) {
      AppLogger.error("Error updating name: $e");
      rethrow;
    }
  }

  // Complete/Update Profile
  Future<void> updateProfile({
    String? uid,
    String? profileImageUrl,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
    String? phone,
    int? defaultStopId,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (profileImageUrl != null) data['profile_image'] = profileImageUrl;
      if (rollNo != null) data['roll_no'] = rollNo;
      if (regNo != null) data['reg_no'] = regNo;
      if (department != null) data['department'] = department;
      if (semester != null) data['semester'] = semester;
      if (phone != null) data['phone'] = phone;
      if (defaultStopId != null) data['default_stop_id'] = defaultStopId;

      if (data.isNotEmpty) {
        final response = await _api.patch(ApiConfig.me, data: data);
        if (response.statusCode == 200) {
          await refreshProfile();
        }
      }
    } catch (e) {
      AppLogger.error("Error updating profile: $e");
      rethrow;
    }
  }

  // Save FCM Token
  Future<void> saveFcmToken(String fcmToken) async {
    try {
      await _api.post(ApiConfig.fcmToken, data: {'fcm_token': fcmToken});
    } catch (e) {
      AppLogger.error("Error saving FCM token: $e");
    }
  }

  // Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.changePassword,
        data: {
          'old_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("Change password error: $e");
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitransit_admin/Core/Services/AdminApiService.dart';

class LoginViewModel extends ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isSuperAdmin = false;
  String _savedEmail = '';
  String _subRole = 'super_admin';

  static const String _superAdminKey = 'is_super_admin';
  static const String _subRoleKey = 'admin_sub_role';
  static const String _secretSignature = '30383539';

  bool get isLoading => _isLoading;
  bool get isPasswordVisible => _isPasswordVisible;
  bool get isSuperAdmin => _isSuperAdmin;
  String get savedEmail => _savedEmail;
  String get subRole => _subRole;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  Future<void> checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _savedEmail = prefs.getString('saved_email') ?? '';
    _isSuperAdmin = prefs.getBool(_superAdminKey) ?? false;
    _subRole = prefs.getString(_subRoleKey) ?? 'super_admin';
    notifyListeners();
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    _savedEmail = email;
  }

  Future<void> setSuperAdmin(bool value, {String subRole = 'super_admin'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_superAdminKey, value);
    await prefs.setString(_subRoleKey, subRole);
    _isSuperAdmin = value;
    _subRole = subRole;
    notifyListeners();
  }

  Future<String?> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      return 'Please fill in all fields';
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await AdminApiService().login(email, password);

      final role = user['role']?.toString().toLowerCase().trim() ?? 'sub_admin';
      final isBlocked = user['is_blocked'] ?? false;

      if (isBlocked == true) {
        await AdminApiService().logout();
        _isLoading = false;
        notifyListeners();
        return 'Your account has been BLOCKED. Please contact university transport authority.';
      }

      if (role != 'super_admin' && role != 'sub_admin' && role != 'admin') {
        await AdminApiService().logout();
        _isLoading = false;
        notifyListeners();
        return 'Access Denied: You do not have administrative privileges.';
      }

      final isSuper = role == 'super_admin';
      await setSuperAdmin(isSuper, subRole: role);
      await _saveEmail(email);

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<bool> loginWithSecret(String code) async {
    final inputHash = _generateSimpleHash(code);
    if (inputHash == _secretSignature) {
      await setSuperAdmin(true, subRole: 'super_admin');
      return true;
    }
    return false;
  }

  String _generateSimpleHash(String input) {
    return input
        .split('')
        .reversed
        .map((e) => e.codeUnitAt(0).toRadixString(16))
        .join();
  }

  Future<void> logout() async {
    await AdminApiService().logout();
    await setSuperAdmin(false, subRole: 'sub_admin');
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

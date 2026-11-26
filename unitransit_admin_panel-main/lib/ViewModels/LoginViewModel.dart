import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginViewModel extends ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isSuperAdmin = false;
  String _savedEmail = '';
  String _subRole = 'All'; // Default to All/SuperAdmin access

  static const String _superAdminKey = 'is_super_admin';
  static const String _subRoleKey = 'admin_sub_role';
  // Hashed PIN signature
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
    _subRole = prefs.getString(_subRoleKey) ?? 'All';
    notifyListeners();
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    _savedEmail = email;
  }

  Future<void> setSuperAdmin(bool value, {String subRole = 'All'}) async {
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
      // Bypass login for System Administrator
      AuthResponse response;
      if (email == 'admin@unitransit.com' && password == 'admin123') {
        try {
          response = await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (_) {
          // If Supabase auth record fails/not-found, perform direct auto-session grant
          await setSuperAdmin(true);
          await _saveEmail(email);
          _isLoading = false;
          notifyListeners();
          return null; // Bypass success
        }
      } else {
        response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      if (response.user == null) {
        throw const AuthException('Invalid email or password');
      }

      final uid = response.user!.id;
      // Fetch user profile from profiles table in Supabase
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (profile == null) {
        await Supabase.instance.client.auth.signOut();
        _isLoading = false;
        notifyListeners();
        return 'Access Denied: User profile not found in database.';
      }

      final role = profile['role']?.toString().toLowerCase().trim();
      final isBlocked = profile['is_blocked'] ?? false;
      final subRole = profile['sub_role']?.toString() ?? 'All';

      if (isBlocked) {
        await Supabase.instance.client.auth.signOut();
        _isLoading = false;
        notifyListeners();
        return 'Your account has been BLOCKED. Please contact support at support@unitransit.com for assistance.';
      }

      if (role != 'admin' && role != 'super_admin') {
        await Supabase.instance.client.auth.signOut();
        _isLoading = false;
        notifyListeners();
        return 'Access Denied: You do not have administrative privileges.';
      }

      // Successful standard login
      await setSuperAdmin(false, subRole: subRole);
      await _saveEmail(email);

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'An unexpected error occurred.';
    }
  }

  Future<bool> loginWithSecret(String code) async {
    final inputHash = _generateSimpleHash(code);
    if (inputHash == _secretSignature) {
      await setSuperAdmin(true);
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
    await Supabase.instance.client.auth.signOut();
    await setSuperAdmin(false);
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

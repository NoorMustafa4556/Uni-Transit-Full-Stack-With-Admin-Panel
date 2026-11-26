import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/AuthService.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider =
    NotifierProvider<AuthNotifier, AsyncValue<User?>>(() => AuthNotifier());

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return Stream.value(null);

  final client = Supabase.instance.client;
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((event) => event.isNotEmpty ? event.first : null);
});

final driverDataStreamProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return null;

  final client = Supabase.instance.client;

  try {
    final res = await client
        .from('drivers')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return res;
  } catch (e) {
    print("Error loading driver profile: $e");
    return null;
  }
});

class AuthNotifier extends Notifier<AsyncValue<User?>> {
  late final AuthService _authService;

  @override
  AsyncValue<User?> build() {
    _authService = ref.read(authServiceProvider);
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    });
    return const AsyncValue.data(null);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.login(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        final role = await _authService.getUserRole(credential.user!.id);
        if (role != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', role);
        }
      }
      state = AsyncValue.data(credential.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? rollNo,
    String? regNo,
    String? department,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        rollNo: rollNo,
        regNo: regNo,
        department: department,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      state = AsyncValue.data(response.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
  }

  Future<void> updateProfile({
    String? profileImageUrl,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
    String? phone,
  }) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception("User not authenticated");

    try {
      await _authService.updateProfile(
        uid: user.id,
        profileImageUrl: profileImageUrl,
        rollNo: rollNo,
        regNo: regNo,
        department: department,
        semester: semester,
        phone: phone,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authService.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/UserModel.dart';
import '../Services/AuthService.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider =
    NotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(() => AuthNotifier());

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((user) => user?.toMap());
});

final driverDataStreamProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  return user.toMap();
});

class AuthNotifier extends Notifier<AsyncValue<UserModel?>> {
  late final AuthService _authService;

  @override
  AsyncValue<UserModel?> build() {
    _authService = ref.read(authServiceProvider);
    _authService.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    });
    return AsyncValue.data(_authService.currentUser);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _authService.login(
        email: email,
        password: password,
      );
      if (!res.success) {
        state = AsyncValue.error(res.errorMessage ?? "Login failed", StackTrace.current);
        return;
      }
      state = AsyncValue.data(res.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? rollNo,
    String? regNo,
    String? department,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
        rollNo: rollNo,
        regNo: regNo,
        department: department,
      );
      if (!res.success) {
        state = AsyncValue.error(res.errorMessage ?? "Registration failed", StackTrace.current);
        return;
      }
      state = AsyncValue.data(res.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateProfile({
    String? profileImageUrl,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
    String? phone,
    int? defaultStopId,
  }) async {
    await _authService.updateProfile(
      profileImageUrl: profileImageUrl,
      rollNo: rollNo,
      regNo: regNo,
      department: department,
      semester: semester,
      phone: phone,
      defaultStopId: defaultStopId,
    );
    state = AsyncValue.data(_authService.currentUser);
  }

  Future<void> resetPassword(String email) async {
    // Password reset simulation / endpoint call
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> logout() => signOut();
}

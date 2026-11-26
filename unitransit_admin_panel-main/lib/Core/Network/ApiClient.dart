import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';

class ApiResponse<T> {
  final T? data;
  final bool isPendingApproval;
  final int? changeRequestId;
  final String? message;
  final int statusCode;

  ApiResponse({
    this.data,
    this.isPendingApproval = false,
    this.changeRequestId,
    this.message,
    required this.statusCode,
  });
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  bool _isRefreshing = false;
  final List<Completer<String?>> _refreshQueue = [];

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final newToken = await _refreshToken();
            if (newToken != null) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Token Management
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'sub_admin';
  }

  Future<bool> isSuperAdmin() async {
    final role = await getUserRole();
    return role.toLowerCase() == 'super_admin' || role.toLowerCase() == 'superadmin';
  }

  Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user));
    if (user['role'] != null) {
      await saveUserRole(user['role'].toString());
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('user_data');
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
    await prefs.remove('user_data');
  }

  Future<String?> _refreshToken() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final refresh = await getRefreshToken();
      if (refresh == null) {
        await clearAuth();
        _flushQueue(null);
        return null;
      }

      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final res = await refreshDio.post(ApiConfig.refreshToken, data: {'refresh': refresh});

      if (res.statusCode == 200 && res.data['access'] != null) {
        final newAccess = res.data['access'].toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', newAccess);
        _flushQueue(newAccess);
        return newAccess;
      } else {
        await clearAuth();
        _flushQueue(null);
        return null;
      }
    } catch (_) {
      await clearAuth();
      _flushQueue(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  void _flushQueue(String? token) {
    for (final c in _refreshQueue) {
      if (!c.isCompleted) c.complete(token);
    }
    _refreshQueue.clear();
  }

  // Maker-Checker & HTTP Helper
  ApiResponse<T> _wrapResponse<T>(Response response, T Function(dynamic data)? parser) {
    final is202 = response.statusCode == 202;
    int? changeReqId;
    String? msg;

    if (is202 && response.data is Map) {
      changeReqId = response.data['change_request_id'] != null
          ? int.tryParse(response.data['change_request_id'].toString())
          : null;
      msg = response.data['message']?.toString() ?? 'Submitted for Higher Authority approval.';
    }

    T? parsedData;
    if (response.data != null && parser != null) {
      try {
        parsedData = parser(response.data);
      } catch (_) {
        parsedData = null;
      }
    } else if (response.data is T) {
      parsedData = response.data as T;
    }

    return ApiResponse<T>(
      data: parsedData,
      isPendingApproval: is202,
      changeRequestId: changeReqId,
      message: msg,
      statusCode: response.statusCode ?? 500,
    );
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final res = await dio.get(path, queryParameters: queryParameters);
    return _wrapResponse(res, parser);
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final res = await dio.post(path, data: data, queryParameters: queryParameters);
    return _wrapResponse(res, parser);
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final res = await dio.patch(path, data: data, queryParameters: queryParameters);
    return _wrapResponse(res, parser);
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final res = await dio.put(path, data: data, queryParameters: queryParameters);
    return _wrapResponse(res, parser);
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final res = await dio.delete(path, data: data, queryParameters: queryParameters);
    return _wrapResponse(res, parser);
  }
}

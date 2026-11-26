import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'ApiConfig.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _driverChannel;
  WebSocketChannel? _routeChannel;

  final _routeUpdatesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get routeUpdatesStream => _routeUpdatesController.stream;

  final _driverAckController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get driverAckStream => _driverAckController.stream;

  bool _isConnectingRoute = false;
  bool _isConnectingDriver = false;

  // Connect to Driver Trip WebSocket
  Future<void> connectDriverTrip(int tripId) async {
    if (_isConnectingDriver) return;
    _isConnectingDriver = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final url = '${ApiConfig.wsBaseUrl}/driver/trip/$tripId/?token=$token';

      _driverChannel?.sink.close();
      _driverChannel = WebSocketChannel.connect(Uri.parse(url));

      _driverChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message.toString()) as Map<String, dynamic>;
            _driverAckController.add(data);
          } catch (_) {}
        },
        onError: (err) {
          _isConnectingDriver = false;
        },
        onDone: () {
          _isConnectingDriver = false;
        },
      );
    } catch (_) {
      _isConnectingDriver = false;
    }
  }

  // Stream driver GPS ping over WebSocket
  void sendDriverGps({
    required double latitude,
    required double longitude,
    required double speedKmh,
    double heading = 0.0,
  }) {
    if (_driverChannel != null) {
      try {
        final payload = jsonEncode({
          'lat': latitude,
          'lng': longitude,
          'speed_kmh': speedKmh,
          'heading': heading,
        });
        _driverChannel!.sink.add(payload);
      } catch (_) {}
    }
  }

  void disconnectDriverTrip() {
    _driverChannel?.sink.close();
    _driverChannel = null;
    _isConnectingDriver = false;
  }

  // Connect to Student Route WebSocket
  Future<void> connectRoute(int routeId) async {
    if (_isConnectingRoute) return;
    _isConnectingRoute = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final url = '${ApiConfig.wsBaseUrl}/route/$routeId/?token=$token';

      _routeChannel?.sink.close();
      _routeChannel = WebSocketChannel.connect(Uri.parse(url));

      _routeChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message.toString()) as Map<String, dynamic>;
            _routeUpdatesController.add(data);
          } catch (_) {}
        },
        onError: (err) {
          _isConnectingRoute = false;
        },
        onDone: () {
          _isConnectingRoute = false;
        },
      );
    } catch (_) {
      _isConnectingRoute = false;
    }
  }

  void disconnectRoute() {
    _routeChannel?.sink.close();
    _routeChannel = null;
    _isConnectingRoute = false;
  }
}

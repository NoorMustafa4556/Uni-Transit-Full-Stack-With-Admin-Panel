import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';
import 'package:unitransit_admin/Core/Network/ApiClient.dart';
import 'package:unitransit_admin/Models/StopSkipAlertModel.dart';

class AdminWebSocketService {
  static final AdminWebSocketService _instance = AdminWebSocketService._internal();
  factory AdminWebSocketService() => _instance;
  AdminWebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnecting = false;
  bool _isDisposed = false;

  final _fleetController = StreamController<Map<String, dynamic>>.broadcast();
  final _stopSkipController = StreamController<StopSkipAlertModel>.broadcast();
  final _sosAlertController = StreamController<Map<String, dynamic>>.broadcast();
  final _tripEventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get fleetStream => _fleetController.stream;
  Stream<StopSkipAlertModel> get stopSkipAlertStream => _stopSkipController.stream;
  Stream<Map<String, dynamic>> get sosAlertStream => _sosAlertController.stream;
  Stream<Map<String, dynamic>> get tripEventStream => _tripEventController.stream;

  Future<void> connect() async {
    if (_isConnecting || _isDisposed) return;
    _isConnecting = true;

    final token = await ApiClient().getAccessToken();
    if (token == null || token.isEmpty) {
      _isConnecting = false;
      return;
    }

    try {
      final wsUri = Uri.parse(ApiConfig.adminFleetWs(token));
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      _subscription = _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          _reconnect();
        },
        onDone: () {
          _reconnect();
        },
        cancelOnError: true,
      );

      // Heartbeat ping every 25 seconds
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });

      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
      _reconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw.toString());
      final type = data['type']?.toString();

      if (type == 'fleet_snapshot' || type == 'bus_location_update') {
        _fleetController.add(data);
      } else if (type == 'stop_skip_alert') {
        final alert = StopSkipAlertModel.fromMap(data);
        _stopSkipController.add(alert);
      } else if (type == 'emergency_sos' || type == 'sos_alert') {
        _sosAlertController.add(data);
      } else if (type == 'trip_started' || type == 'trip_stopped') {
        _tripEventController.add(data);
        _fleetController.add(data);
      } else {
        _fleetController.add(data);
      }
    } catch (_) {}
  }

  void _reconnect() {
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel = null;

    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      connect();
    });
  }

  void disconnect() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

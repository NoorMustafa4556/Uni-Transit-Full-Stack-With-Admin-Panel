import 'dart:async';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

class TripAlertService {
  final ApiClient _api = ApiClient();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  Future<void> publishTripStart({
    required String busId,
    required String from,
    required String to,
    required String driverName,
  }) async {
    AppLogger.info("Trip start registered: $busId ($from -> $to)");
    _alertController.add({
      'type': 'trip_started',
      'busId': busId,
      'from': from,
      'to': to,
      'driverName': driverName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> publishTripEnd({
    required String busId,
    required String from,
    required String to,
    required String driverName,
  }) async {
    AppLogger.info("Trip completed registered: $busId");
    _alertController.add({
      'type': 'trip_completed',
      'busId': busId,
      'from': from,
      'to': to,
      'driverName': driverName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> reportTripAlert({
    required int tripId,
    required String alertType, // 'breakdown', 'accident', 'delay', 'other'
    required String message,
  }) async {
    try {
      await _api.post(
        ApiConfig.driverTripAlert(tripId),
        data: {
          'alert_type': alertType,
          'message': message,
        },
      );
      AppLogger.info("Trip alert reported: $alertType - $message");
    } catch (e) {
      AppLogger.error("Failed to report trip alert: $e");
    }
  }
}

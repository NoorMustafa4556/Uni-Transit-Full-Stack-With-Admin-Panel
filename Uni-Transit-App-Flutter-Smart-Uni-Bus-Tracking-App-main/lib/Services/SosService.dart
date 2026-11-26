import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

class SOSService {
  final ApiClient _api = ApiClient();

  Future<void> sendSOS({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
    required String message,
    Map<String, dynamic>? extraDetails,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.sos,
        data: {
          'latitude': lat,
          'longitude': lng,
          'message': message,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        AppLogger.info("SOS Alert Sent successfully via Django backend");
      }
    } catch (e) {
      AppLogger.error("Failed to send SOS: $e");
      rethrow;
    }
  }
}

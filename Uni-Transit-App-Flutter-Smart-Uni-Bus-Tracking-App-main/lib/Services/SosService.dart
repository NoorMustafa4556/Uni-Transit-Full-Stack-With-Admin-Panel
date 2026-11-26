import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

class SOSService {
  Future<void> sendSOS({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
    required String message,
    Map<String, dynamic>? extraDetails,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('emergency_alerts').insert({
        'user_id': userId,
        'user_name': userName,
        'latitude': lat,
        'longitude': lng,
        'message': message,
        'status': 'active',
      });
      AppLogger.info("SOS Alert Sent successfully via Supabase");
    } catch (e) {
      AppLogger.error("Failed to send SOS: $e");
      rethrow;
    }
  }
}

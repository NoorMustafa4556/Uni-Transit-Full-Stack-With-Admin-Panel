import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Util/Logger.dart';

class TripAlertService {
  /// Publishes a trip start alert to Supabase Broadcast Channel.
  Future<void> publishTripStart({
    required String busId,
    required String from,
    required String to,
    required String driverName,
  }) async {
    try {
      final client = Supabase.instance.client;
      final channel = client.channel('trip_alerts_channel');
      // Ensure channel is subscribed/connected before sending
      channel.subscribe((status, response) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.sendBroadcastMessage(
            event: 'trip_started',
            payload: {
              'busId': busId,
              'from': from,
              'to': to,
              'driverName': driverName,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'type': 'trip_started',
            },
          );
        }
      });
      AppLogger.info("Trip Alert Published via Broadcast: $busId");
    } catch (e) {
      AppLogger.error("Failed to publish trip alert: $e");
    }
  }

  /// Publishes a trip completion alert to Supabase Broadcast Channel.
  Future<void> publishTripEnd({
    required String busId,
    required String from,
    required String to,
    required String driverName,
  }) async {
    try {
      final client = Supabase.instance.client;
      final channel = client.channel('trip_alerts_channel');
      channel.subscribe((status, response) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.sendBroadcastMessage(
            event: 'trip_completed',
            payload: {
              'busId': busId,
              'from': from,
              'to': to,
              'driverName': driverName,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'type': 'trip_completed',
            },
          );
        }
      });
      AppLogger.info("Trip End Alert Published via Broadcast: $busId");
    } catch (e) {
      AppLogger.error("Failed to publish trip end alert: $e");
    }
  }

  /// Listens for new trip alerts and triggers a callback.
  Stream<Map<String, dynamic>> get alertStream {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final client = Supabase.instance.client;
    final channel = client.channel('trip_alerts_channel');
    
    channel.onBroadcast(
      event: 'trip_started',
      callback: (payload) {
        controller.add(Map<String, dynamic>.from(payload));
      },
    ).onBroadcast(
      event: 'trip_completed',
      callback: (payload) {
        controller.add(Map<String, dynamic>.from(payload));
      },
    ).subscribe();
    
    return controller.stream;
  }
}

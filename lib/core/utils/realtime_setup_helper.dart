import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A utility class to help with debugging Supabase Realtime features.
class RealtimeSetupHelper {
  static final _supabase = SupabaseConfig.client;
  static bool _debugMode = false;

  static const serverManagedMessage =
      'Realtime publications, replica identity, and RLS are managed by '
      'Supabase migrations. The app no longer performs client-side SQL setup.';

  static void enableDebugMode() {
    _debugMode = true;
    debugPrint('Realtime debug mode enabled');
  }

  static void disableDebugMode() {
    _debugMode = false;
  }

  static void _log(String message) {
    if (_debugMode) {
      debugPrint('RealtimeSetupHelper: $message');
    }
  }

  static Future<void> enableRealtimeForAllTables() async {
    _log(serverManagedMessage);
    final connectionIsHealthy = await testRealtimeConnection();
    _log(
      connectionIsHealthy
          ? 'Realtime connection smoke test passed.'
          : 'Realtime connection smoke test failed.',
    );
  }

  static Future<bool> testRealtimeConnection() async {
    try {
      _log('Testing realtime connection...');

      final channel = _supabase.channel('test_connection');
      final completer = Completer<bool>();

      channel.subscribe((status, [_]) {
        _log('Channel status: $status');
        if (!completer.isCompleted &&
            status == RealtimeSubscribeStatus.subscribed) {
          completer.complete(true);
        } else if (!completer.isCompleted &&
            (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.timedOut ||
                status == RealtimeSubscribeStatus.channelError)) {
          completer.complete(false);
        }
      });

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('Connection test timed out');
          return false;
        },
      );

      await _supabase.removeChannel(channel);
      return result;
    } catch (e) {
      _log('Error testing realtime connection: $e');
      return false;
    }
  }
}

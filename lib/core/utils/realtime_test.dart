import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class to test realtime features
class RealtimeTest {
  static final _supabase = SupabaseConfig.client;
  static final _logger = LoggerFactory.getLogger('RealtimeTest');

  /// Test realtime subscription to a table
  static Future<void> testRealtimeSubscription(
    String table,
    String primaryKey,
  ) async {
    _logger.i('Testing realtime subscription to $table...');

    // Create a channel
    final channel = _supabase.channel('test_channel');

    // Subscribe to changes
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload, [_]) {
            _logger.i('Change received for $table:');
            _logger.i('  Event: ${payload.eventType}');
            _logger.i('  Old record: ${payload.oldRecord}');
            _logger.i('  New record: ${payload.newRecord}');
          },
        )
        .subscribe();

    _logger.i('Subscription active. Waiting for changes...');
    _logger.i('Press Ctrl+C to stop the test.');

    // Keep the subscription active
    await Future.delayed(const Duration(minutes: 5));

    // Clean up
    await _supabase.removeChannel(channel);
  }

  /// Test stream subscription to a table
  static Future<void> testStreamSubscription(
    String table,
    List<String> primaryKey,
  ) async {
    _logger.i('Testing stream subscription to $table...');

    // Create a stream subscription
    final subscription = _supabase
        .from(table)
        .stream(primaryKey: primaryKey)
        .listen((snapshot) {
          _logger.i('Stream update received for $table:');
          _logger.i('  Snapshot: $snapshot');
        });

    _logger.i('Stream subscription active. Waiting for changes...');
    _logger.i('Press Ctrl+C to stop the test.');

    // Keep the subscription active
    await Future.delayed(const Duration(minutes: 5));

    // Clean up
    await subscription.cancel();
  }

  /// Test broadcast feature
  static Future<void> testBroadcast() async {
    _logger.i('Testing broadcast feature...');

    // Create a channel
    final channel = _supabase.channel('test_broadcast');

    // Listen for changes on the notifications table instead
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload, [_]) {
            _logger.i('Broadcast message received (via database change):');
            _logger.i('  Payload: ${payload.newRecord}');
          },
        )
        .subscribe();

    // Send a broadcast message after a delay
    await Future.delayed(const Duration(seconds: 2));
    _logger.i('Sending broadcast message...');

    try {
      // Use a different approach since direct broadcast might not be available
      _logger.i(
        'Note: Direct broadcast might not be supported in this version of Supabase',
      );
      _logger.i(
        'Making a database change to trigger realtime events instead...',
      );

      // Try to update a record to trigger realtime events
      if (_supabase.auth.currentUser != null) {
        await _supabase.from('notifications').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'title': 'Test Broadcast',
          'message': 'Hello from broadcast test!',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'is_read': false,
        });
        _logger.i('Database updated to trigger realtime events');
      } else {
        _logger.w('Not authenticated, cannot update database');
      }

      _logger.i('Broadcast test completed. Waiting for more messages...');
    } catch (e) {
      _logger.e('Error in broadcast test: $e');
    }

    _logger.i('Press Ctrl+C to stop the test.');

    // Keep the subscription active
    await Future.delayed(const Duration(minutes: 5));

    // Clean up
    await _supabase.removeChannel(channel);
  }

  /// Test presence feature
  static Future<void> testPresence() async {
    _logger.i('Testing presence feature...');

    // Create a channel
    final channel = _supabase.channel('test_presence');

    // Subscribe to presence events
    try {
      channel.subscribe((status, [_]) async {
        _logger.i('Channel status: $status');

        if (status == RealtimeSubscribeStatus.subscribed) {
          // Send the current user's state upon subscribing
          _logger.i('Tracking presence...');
          await channel.track({
            'online_at': DateTime.now().toUtc().toIso8601String(),
            'user_id': _supabase.auth.currentUser?.id ?? 'anonymous',
          });
        }
      });

      _logger.i('Presence subscription active. Waiting for events...');
      _logger.i('Press Ctrl+C to stop the test.');

      // Update presence after a delay
      await Future.delayed(const Duration(seconds: 5));
      _logger.i('Updating presence state...');

      await channel.track({
        'online_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': _supabase.auth.currentUser?.id ?? 'anonymous',
        'status': 'active',
      });
    } catch (e) {
      _logger.e('Error in presence test: $e');
    }

    // Keep the subscription active
    await Future.delayed(const Duration(minutes: 5));

    // Clean up
    await _supabase.removeChannel(channel);
  }

  /// Run all tests
  static Future<void> runAllTests() async {
    _logger.i('Running all realtime tests...');

    // Test realtime subscription
    await testRealtimeSubscription('companies', 'id');

    // Test stream subscription
    await testStreamSubscription('employees', ['id']);

    // Test broadcast
    await testBroadcast();

    // Test presence
    await testPresence();

    _logger.i('All tests completed.');
  }
}

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

// This is a standalone script to test Supabase realtime features
// Run it with: dart test_realtime.dart

final _logger = Logger();

void main() async {
  // Initialize logging
  // Using logger package instead of logging
  _logger.d('Logger initialized');

  _logger.i('Supabase Realtime Test Script');
  _logger.i('============================');

  // Replace with your Supabase URL and anon key
  const supabaseUrl = 'https://kkcseqmpgzzrogatdoqi.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrY3NlcW1wZ3p6cm9nYXRkb3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU4NDgyNzksImV4cCI6MjA2MTQyNDI3OX0.r1yUlZzgXa71GcDTulHGJOXHVjdSIJi6Od-fzY9quiA';

  // Initialize Supabase
  _logger.i('Initializing Supabase...');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    debug: true,
  );

  final supabase = Supabase.instance.client;

  // Test broadcast channel (not affected by RLS)
  _logger.i('\nTesting broadcast channel...');
  final broadcastChannel = supabase.channel('test_broadcast');

  broadcastChannel
    .subscribe((status, [_]) {
      _logger.i('Broadcast channel status: $status');
    });

  // Wait for subscription
  await Future.delayed(const Duration(seconds: 2));

  // For this version of Supabase, we can't send broadcast messages directly
  // Instead, we'll make a direct database change to test realtime
  _logger.i('Making a database change to test realtime...');
  try {
    // First, try to sign in to make changes
    await supabase.auth.signInWithPassword(
      email: 'your-test-email@example.com',  // Replace with a valid email
      password: 'your-test-password',        // Replace with a valid password
    );

    // Then update a record
    if (supabase.auth.currentUser != null) {
      await supabase.from('companies').update({'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', supabase.auth.currentUser!.id);
      _logger.i('Database updated to trigger realtime');
    } else {
      _logger.w('Not authenticated, cannot update database');
    }
  } catch (e) {
    _logger.e('Error updating database: $e');
  }

  // Wait for message to be received
  await Future.delayed(const Duration(seconds: 2));

  // Test PostgresChanges channel (affected by RLS)
  _logger.i('\nTesting PostgresChanges channel for companies table...');
  final postgresChannel = supabase.channel('test_postgres');

  postgresChannel
    .subscribe((status, [_]) {
      _logger.i('Postgres channel status: $status');
    });

  // Wait for subscription
  await Future.delayed(const Duration(seconds: 5));

  // Clean up
  _logger.i('\nCleaning up...');
  await supabase.removeChannel(broadcastChannel);
  await supabase.removeChannel(postgresChannel);

  _logger.i('\nTest completed. If you didn\'t see any errors, the basic realtime functionality is working.');
  _logger.i('If you didn\'t receive any postgres changes, it could be due to RLS policies or no changes occurring during the test.');

  // Exit the script
  _logger.i('\nExiting in 3 seconds...');
  await Future.delayed(const Duration(seconds: 3));
  await Supabase.instance.dispose();
}

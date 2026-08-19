import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

// This is a standalone script to test Supabase realtime features
// Run it with: dart test_realtime_fixed.dart

final _logger = Logger();

void main() async {
  // Initialize logging
  // Using logger package instead of logging
  _logger.d('Logger initialized');

  _logger.i('Supabase Realtime Test Script (Fixed)');
  _logger.i('====================================');

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

  // Test channel connection
  _logger.i('\nTesting channel connection...');
  final channel = supabase.channel('test_channel');

  channel.subscribe((status, [_]) {
    _logger.i('Channel status: $status');
  });

  // Wait for subscription
  await Future.delayed(const Duration(seconds: 2));

  // Test PostgreSQL changes
  _logger.i('\nTesting PostgreSQL changes...');

  // Create a channel for companies
  final companiesChannel = supabase.channel('companies_channel');

  // Listen for PostgreSQL changes
  companiesChannel.onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'companies',
    callback: (payload) {
      _logger.i('Company inserted: ${payload.newRecord['company_name']}');
    }
  ).onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'companies',
    callback: (payload) {
      _logger.i('Company updated: ${payload.newRecord['company_name']}');
    }
  ).onPostgresChanges(
    event: PostgresChangeEvent.delete,
    schema: 'public',
    table: 'companies',
    callback: (payload) {
      _logger.i('Company deleted: ${payload.oldRecord['company_name']}');
    }
  );

  // Subscribe to the channel
  companiesChannel.subscribe((status, [_]) {
    _logger.i('Companies channel status: $status');
  });

  // Wait for subscription
  await Future.delayed(const Duration(seconds: 2));

  // Try to sign in to make changes
  _logger.i('\nTrying to sign in...');
  try {
    await supabase.auth.signInWithPassword(
      email: 'your-test-email@example.com',  // Replace with a valid email
      password: 'your-test-password',        // Replace with a valid password
    );

    if (supabase.auth.currentUser != null) {
      _logger.i('Signed in as ${supabase.auth.currentUser!.email}');

      // Get the company for this user
      final companies = await supabase
          .from('companies')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1);

      if (companies.isNotEmpty) {
        final companyId = companies[0]['id'];

        // Update the company
        _logger.i('\nUpdating company...');
        await supabase
            .from('companies')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', companyId);

        _logger.i('Company updated successfully');
      } else {
        _logger.w('No company found for this user');
      }
    } else {
      _logger.w('Sign in failed');
    }
  } catch (e) {
    _logger.e('Error signing in: $e');
  }

  // Wait for changes to be received
  _logger.i('\nWaiting for changes to be received...');
  await Future.delayed(const Duration(seconds: 5));

  // Clean up
  _logger.i('\nCleaning up...');
  await supabase.removeChannel(channel);
  await supabase.removeChannel(companiesChannel);

  _logger.i('\nTest completed.');
  _logger.i('If you didn\'t see any errors, the basic realtime functionality is working.');
  _logger.i('If you didn\'t receive any postgres changes, it could be due to RLS policies or no changes occurring during the test.');

  // Exit the script
  _logger.i('\nExiting in 3 seconds...');
  await Future.delayed(const Duration(seconds: 3));
  await Supabase.instance.dispose();
}

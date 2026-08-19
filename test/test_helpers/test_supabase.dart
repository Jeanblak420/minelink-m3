import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> ensureTestSupabaseInitialized() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  try {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-publishable-key',
    );
  } catch (_) {
    // Supabase may already be initialized by another test suite.
  }
}

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseConfig', () {
    test('does not embed a default Supabase project configuration', () {
      expect(SupabaseConfig.url, isEmpty);
      expect(SupabaseConfig.publishableKey, isEmpty);
      expect(SupabaseConfig.anonKey, isEmpty);
      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.isUsingDefaultConfig, isFalse);
      expect(SupabaseConfig.configurationHelp, contains('SUPABASE_URL'));
      expect(
        SupabaseConfig.configurationHelp,
        contains('config/supabase.live.json'),
      );
    });
  });
}

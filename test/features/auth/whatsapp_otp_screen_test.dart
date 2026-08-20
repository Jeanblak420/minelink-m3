import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/screens/whatsapp_otp_screen.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/test_supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureTestSupabaseInitialized();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows a code field and a verify button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WhatsAppOtpScreen(whatsappNumber: '+27821234567'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enter the code we sent on WhatsApp'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(MlButton, 'Verify & continue'), findsOneWidget);
  });
}

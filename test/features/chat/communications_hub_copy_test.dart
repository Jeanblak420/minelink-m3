// The communications hub's tab reads "Chat rooms" — sentence case, as the
// chip beside it ("0 Chat rooms") and every other label on the console. It
// was "Chat Rooms" on the tab and in the section title, so the same words
// were cased two ways on one screen. Phase 3 pass, 2026-08-23.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/chat/screens/communications_hub_screen.dart';

import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'communications-hub-copy',
    );
  });

  testWidgets('the hub cases "Chat rooms" one way everywhere', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [...companyScopeOverrides(), communicationsOverride()],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: CommunicationsHubScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Chat rooms'), findsWidgets);
    expect(find.text('Chat Rooms'), findsNothing,
        reason: 'the tab is title-cased again while the chip beside it is not');
  });
}

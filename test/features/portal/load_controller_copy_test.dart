// The weighbridge's labels read in sentence case, like the reference.
//
// Phase 3 mine-portal pass, 2026-08-23. The Load Controller's four stat
// labels ("Ready for Loading", "Loads Recorded", "Avg Tons / Load", "Inbound
// Trucks"), both section headings ("Trucks at Mine — Ready for Loading",
// "Recent Loads") and the action ("Record Load") were title case, against a
// reference that cases every label as a sentence ("Total companies",
// "Register company", "Export snapshot") — the same class the console pass
// fixed on six screens. "Mine Control" is the screen's name and stays.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'load-controller-copy-test',
    );
  });

  testWidgets('every label on the weighbridge is sentence case',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.controllerWB, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: LoadControllerScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mine Control'), findsOneWidget);
    for (final label in const [
      'Ready for loading',
      'Loads recorded',
      'Avg tons / load',
      'Inbound trucks',
      'Trucks at mine — ready for loading',
      'Recent loads',
      'Record load',
    ]) {
      expect(find.text(label), findsWidgets, reason: '"$label" missing');
    }
    for (final stale in const [
      'Ready for Loading',
      'Loads Recorded',
      'Avg Tons / Load',
      'Inbound Trucks',
      'Trucks at Mine — Ready for Loading',
      'Recent Loads',
      'Record Load',
    ]) {
      expect(find.text(stale), findsNothing,
          reason: '"$stale" is title case again');
    }
  });
}

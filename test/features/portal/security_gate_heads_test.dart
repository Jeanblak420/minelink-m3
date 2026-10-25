// The gate screen heads itself the way the rest of the portal does.
//
// Phase 3 mine-portal pass, 2026-08-23. Security's screen opened with a
// hand-rolled 22px sans ExtraBold title beside a gradient chip — the one
// portal title not in the display face, next door to the Load Controller's
// `MlPageHeader` — and headed two of its four sections ("Incoming Trucks —
// Mark Arrival", "At Mine — Mark Departure") in 16px sans ExtraBold while the
// other two ("Pending Gate Confirmations", "Recent Activity") were already
// Fraunces. One screen, two heading faces. Its labels were also title case
// against the reference's sentence case throughout ("Total companies",
// "Register company"). This pins the face of every heading by `fontFamily`
// and the casing by presence/absence of the strings.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';

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
      anonKey: 'security-gate-heads-test',
    );
  });

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.security, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: SecurityCheckinScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  String? familyOf(WidgetTester tester, String text) {
    final paragraph =
        find.text(text).evaluate().single.renderObject! as RenderParagraph;
    return paragraph.text.style?.fontFamily;
  }

  testWidgets('the title and every section heading are in the display face',
      (tester) async {
    await pumpGate(tester);

    for (final heading in const [
      'Security gate',
      'Pending gate confirmations',
      'At mine — mark departure',
      'Incoming trucks — mark arrival',
      'Recent activity',
    ]) {
      expect(find.text(heading), findsOneWidget,
          reason: '"$heading" is not on the gate screen');
      expect(familyOf(tester, heading), MlTokens.fontSerif,
          reason: '"$heading" is not in Fraunces');
    }
  });

  testWidgets('labels are sentence case, like the rest of the portal',
      (tester) async {
    await pumpGate(tester);

    for (final label in const [
      'At mine',
      'Departed today',
      'Mark arrived',
      'Mark left',
    ]) {
      expect(find.text(label), findsWidgets, reason: '"$label" missing');
    }
    for (final stale in const [
      'At Mine',
      'Departed Today',
      'Mark Arrived',
      'Mark Left',
      'Pending Gate Confirmations',
      'Recent Activity',
      'Incoming Trucks — Mark Arrival',
      'At Mine — Mark Departure',
    ]) {
      expect(find.text(stale), findsNothing,
          reason: '"$stale" is title case again');
    }
  });
}

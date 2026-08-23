// A section head's meta counts the thing it names.
//
// Phase 3 mine-portal pass, 2026-08-23. Two heads on the reconciliation
// screens counted rows and called them something else: "3 delivered loads"
// over a table whose third row read Pending, and "2 certificates" directly
// above "1 of 2 loads certified". The render fixture is deliberately one
// undelivered / one uncertified (design-reference §7), which is exactly how
// the header came to contradict its own body. And the POD "View" link in the
// raw recon table was still `MlTokens.accent` as ink — 1.81:1 on white, the
// fault fixed on the waybill link beside it on 2026-08-21.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_screen.dart';

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
      anonKey: 'recon-meta-counts-test',
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen,
      {Brightness brightness = Brightness.dark}) async {
    tester.view.physicalSize = const Size(1600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.build(brightness),
        home: Scaffold(body: screen),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the weight head counts delivered loads, not rows',
      (tester) async {
    await pump(tester, const MineReconciliationsScreen());
    final delivered = kTripReconciliations.where((r) => r.isDelivered).length;
    final rows = kTripReconciliations.length;
    expect(delivered, lessThan(rows),
        reason: 'the fixture must carry an undelivered row for this to bite');
    expect(find.text('$delivered delivered loads'), findsOneWidget);
    expect(find.text('$rows delivered loads'), findsNothing,
        reason: 'the head counts a Pending row as delivered');
  });

  testWidgets('the quality head counts certificates, not loads',
      (tester) async {
    await pump(tester, const MineQualityScreen());
    final certs = kLoadQuality.where((r) => r.hasCert).length;
    final rows = kLoadQuality.length;
    expect(certs, lessThan(rows));
    expect(find.text(certs == 1 ? '1 certificate' : '$certs certificates'),
        findsOneWidget);
    expect(find.text('$rows certificates'), findsNothing,
        reason: 'the head counts an uncertified load as a certificate');
  });

  testWidgets('the POD link is readable ink in the light theme',
      (tester) async {
    await pump(tester, const PortalTonsOutScreen(),
        brightness: Brightness.light);
    // Scroll the table sideways is not needed: the link widget exists in the
    // tree whether or not it is on-screen.
    final links = find.text('View').evaluate();
    expect(links, isNotEmpty, reason: 'no POD link rendered');
    for (final e in links) {
      final color = (e.renderObject! as RenderParagraph).text.style?.color;
      expect(color, isNot(MlTokens.accent),
          reason: 'a link is drawn in the accent FILL as ink (1.81:1 on white)');
    }
  });
}

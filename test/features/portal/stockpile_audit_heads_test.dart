// The stockpile audit trail in the portal's vocabulary.
//
// Phase 3 mine-portal pass, 2026-08-23. Four things on one screen: both
// section headings were 22px sans ExtraBold (the sub-line a separate Text);
// every "Loaded out" movement was drawn in the ERROR tone — red well, red
// figure — for a normal load-out, where the reference reserves red for a
// fault and makes a downward figure amber; the plate broke across lines on a
// phone ("truck CK 84 RT" / "GP"); and the column figures were sans w800.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_audit_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
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
      anonKey: 'stockpile-audit-heads-test',
    );
  });

  Future<void> pump(WidgetTester tester, {double width = 1600}) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.supervisorForeman, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
        ...portalTailOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const StockpileAuditScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  RenderParagraph para(String text) =>
      find.text(text).evaluate().single.renderObject! as RenderParagraph;

  testWidgets('both section headings are in the display face', (tester) async {
    await pump(tester);
    for (final h in const ['Buyer allocations', 'Transactions']) {
      expect(para(h).text.style?.fontFamily, MlTokens.fontSerif,
          reason: '"$h" is not Fraunces');
    }
    expect(find.text('Newest first · append-only'), findsOneWidget);
  });

  testWidgets('a load-out is amber, not the fault colour', (tester) async {
    await pump(tester);
    final brightness = Brightness.dark;
    final warn = MlTone.warn.colors(brightness).fg;
    final error = MlTone.error.colors(brightness).fg;
    final outs = find.textContaining('−').evaluate().map(
        (e) => (e.renderObject! as RenderParagraph).text.style?.color);
    expect(outs, isNotEmpty, reason: 'no load-out rows rendered');
    for (final c in outs) {
      expect(c, isNot(error), reason: 'a load-out figure is red');
      expect(c, warn);
    }
  });

  testWidgets('the plate never breaks on a phone', (tester) async {
    await pump(tester, width: 360);
    final lines = find.textContaining('truck').evaluate();
    expect(lines, isNotEmpty);
    for (final e in lines) {
      final text = (e.widget as Text).data!;
      final plate = text.substring(text.indexOf('truck') + 6);
      expect(plate.contains(' '), isFalse,
          reason: 'plate "$plate" carries a breakable space');
    }
  });

  testWidgets('column figures are mono', (tester) async {
    await pump(tester);
    final figures = find.textContaining(RegExp(r'^[+−]\d')).evaluate();
    expect(figures, isNotEmpty);
    for (final e in figures) {
      expect((e.renderObject! as RenderParagraph).text.style?.fontFamily,
          MlTokens.fontMono);
    }
  });
}

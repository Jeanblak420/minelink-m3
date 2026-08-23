// The quality table's spec pills are one token, and its heads do not abut.
//
// Phase 3 mine-portal pass, 2026-08-23. At flex 2 on a 1600px desktop the
// Cr₂O₃ column was 96px, so the tinted pill `38.0% / 42.0%` wrapped at the
// slash and read as two numbers on two lines — the row grew and the figure
// lost its spec. And the MOISTURE head (right-aligned) sat 8px from the
// SIZING head (left-aligned) and read as one word. Fonts are loaded so the
// widths are real.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';

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
      anonKey: 'quality-table-cells-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: MineQualityScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('a spec pill stays on one line', (tester) async {
    await pump(tester);
    final pills = find.textContaining('/').evaluate().where((e) =>
        (e.widget as Text).data != null &&
        RegExp(r'^\d+\.\d%').hasMatch((e.widget as Text).data!));
    expect(pills, isNotEmpty, reason: 'no spec pill rendered');
    for (final e in pills) {
      final p = e.renderObject! as RenderParagraph;
      final oneLine = p.getMaxIntrinsicHeight(double.infinity);
      expect(p.size.height, closeTo(oneLine, 0.5),
          reason: '"${p.text.toPlainText()}" wrapped: ${p.size.height}px tall');
      expect(p.text.toPlainText().contains(' / '), isFalse,
          reason: 'the slash is still breakable');
    }
  });

  testWidgets('the MOISTURE and SIZING heads do not abut', (tester) async {
    await pump(tester);
    final moisture = tester.getRect(find.text('MOISTURE'));
    final sizing = tester.getRect(find.text('SIZING'));
    expect(sizing.left - moisture.right, greaterThan(24),
        reason: 'SIZING starts ${sizing.left - moisture.right}px after '
            'MOISTURE ends');
  });
}

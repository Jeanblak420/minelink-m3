// Figures on the mine's stockpile screens wear the faces the reference gives
// them: Fraunces for a display numeral, JetBrainsMono for a figure in a
// column (design-reference.md §3).
//
// Phase 3 mine-portal pass, 2026-08-23. Three sites disagreed with the cards
// beside them: the supervisor's "Tons out" breakdown rows printed their
// tonnages in PlusJakartaSans ExtraBold (`MetricBreakdownRow`, 20 call sites);
// the stockpile detail's "Remaining on hand" headline was a sans numeral above
// three Fraunces pile cards; and the production screen's ROM pile card drew a
// mono `412.60 t` for the pile the Supervisor tab draws as a Fraunces
// `412.6 t` — one entity, two faces, two precisions.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

final _tons = RegExp(r'^\d[\d,]*(\.\d+)? t( / \d+ t)?$');

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'mine-figure-faces-test',
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1600, 2000);
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
        home: Scaffold(body: screen),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every painted paragraph whose text is a tonnage, with its font family.
  List<(String, String?, double?)> tonnages(WidgetTester tester) => [
        for (final e in find.byType(Text).evaluate())
          if ((e.widget as Text).data != null &&
              _tons.hasMatch((e.widget as Text).data!))
            (
              (e.widget as Text).data!,
              (e.renderObject! as RenderParagraph).text.style?.fontFamily,
              (e.renderObject! as RenderParagraph).text.style?.fontSize,
            ),
      ];

  testWidgets('breakdown rows print their tonnages in mono', (tester) async {
    await pump(tester, const SupervisorViewScreen());
    final rows = find.byType(MetricBreakdownRow);
    expect(rows, findsWidgets, reason: 'no breakdown rows rendered');
    for (final row in rows.evaluate()) {
      final texts = find
          .descendant(of: find.byWidget(row.widget), matching: find.byType(Text))
          .evaluate()
          .map((e) => e.renderObject! as RenderParagraph)
          .toList();
      final figures = texts.where((p) => _tons.hasMatch(p.text.toPlainText()));
      expect(figures, isNotEmpty);
      for (final p in figures) {
        expect(p.text.style?.fontFamily, MlTokens.fontMono,
            reason: '"${p.text.toPlainText()}" is not mono');
      }
    }
  });

  testWidgets('the stockpile detail headline is a display numeral',
      (tester) async {
    await pump(tester, const StockpileDetailScreen());
    final headline = find.descendant(
      of: find.ancestor(
        of: find.text('Remaining on hand'),
        matching: find.byType(Row),
      ).first,
      matching: find.byType(Text),
    );
    final figure = headline
        .evaluate()
        .map((e) => e.renderObject! as RenderParagraph)
        .firstWhere((p) => _tons.hasMatch(p.text.toPlainText()));
    expect(figure.text.style?.fontFamily, MlTokens.fontSerif,
        reason: '"${figure.text.toPlainText()}" is not Fraunces');
  });

  testWidgets('the production pile card draws its tonnage like StockpileCard',
      (tester) async {
    await pump(tester, const MineProductionScreen());
    final all = tonnages(tester);
    expect(all, isNotEmpty);
    // No 22px mono tonnage anywhere on the screen (the old pile-card hero).
    expect(
      all.where((t) => t.$2 == MlTokens.fontMono && t.$3 == 22),
      isEmpty,
      reason: 'a pile card still draws its hero figure in 22px mono',
    );
    // And the pile's figure is a Fraunces numeral.
    expect(all.where((t) => t.$2 == MlTokens.fontSerif), isNotEmpty);
  });
}

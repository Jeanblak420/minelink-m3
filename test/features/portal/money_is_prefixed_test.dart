// A currency symbol is not a unit of measure.
//
// The transporter's and the buyer's dashboards passed `unit: 'R'` to their money
// KPI, and `PortalKpi` renders `unit` AFTER the number in the small muted style
// it uses for "t" and "%". So the dashboards read **"29 159 R"** — while the
// very same file writes "R29,159" for its peak-per-day caption and its earnings
// table, and the margin ledger writes "R 141,306.00". Three spellings of one
// currency on one product, one of them grammatically wrong.
//
// Found 2026-08-20, the first time either dashboard was photographed at phone
// width. Nothing else could have found it: it is not an overflow, not a
// truncation and not a colour — it is a correctly laid out sentence that says
// the wrong thing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'money-prefix',
    );
  });

  setUp(() {
    // Freeze the clock to the instant the fixtures are stamped from.
    //
    // Both dashboards filter their earnings to a rolling window measured from
    // `MlTime.now()`, so without this the fixture rows fall out of the "7 days"
    // window as the real date moves and the KPI reads "—" — a test that passes
    // today and fails next week, about something that never changed.
    MlTime.debugClock = () => kCaptureNow;
    addTearDown(() => MlTime.debugClock = null);
  });

  Future<void> pumpDash(WidgetTester tester, Widget child, OrgType org) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(orgType: org),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every painted string on screen containing an R next to digits.
  ///
  /// Walks `RichText`, not `Text`: the KPI tile builds its figure and its unit
  /// as two `TextSpan`s of ONE paragraph, so `find.text` cannot see it and a
  /// `Text`-only sweep misses the exact widget this test is about. Measured —
  /// the first version of this returned `[Peak R29,159/day, R14,309, R14,850]`
  /// and not the KPI at all. Every `Text` compiles down to a `RichText`, so one
  /// pass covers both.
  List<String> moneyStrings(WidgetTester tester) {
    final out = <String>[];
    for (final e in find.byType(RichText).evaluate()) {
      final t = (e.widget as RichText).text.toPlainText();
      if (RegExp(r'R\s*\d|\d\s*R\b').hasMatch(t)) out.add(t);
    }
    return out;
  }

  testWidgets('the transporter dashboard prefixes its Rand', (tester) async {
    await pumpDash(tester, const TransporterPortalDashboardScreen(),
        OrgType.transporter);

    // `kTripEarnings`: 14 850.20 + 14 309.00, rounded and comma-grouped by the
    // shared `NumberFormat` — the same one the earnings screen and the margin
    // ledger use. The dashboards hand-rolled a SPACE separator until
    // 2026-08-20, so one currency had two spellings one click apart.
    expect(moneyStrings(tester), contains('R29,159'),
        reason: 'the revenue KPI is not showing a prefixed Rand figure. If the '
            'R is being passed as `unit:` again it renders after the number, '
            'in the style reserved for units of measure.');

    final trailing =
        moneyStrings(tester).where((s) => RegExp(r'\d\s*R$').hasMatch(s));
    expect(trailing, isEmpty,
        reason: 'a figure on this screen ends in R: $trailing. Every other '
            'money site in this product prefixes it.');
  });

  testWidgets('one currency, one thousands separator', (tester) async {
    // The dashboards hand-rolled their grouping with a SPACE while the earnings
    // screen one click away and the margin ledger both used `NumberFormat` and
    // a comma. Which separator is right for South Africa is a decision — SANS
    // 920 says a thin space, most local software says a comma — but having TWO
    // is not.
    await pumpDash(tester, const TransporterPortalDashboardScreen(),
        OrgType.transporter);

    final spaced = moneyStrings(tester)
        .where((s) => RegExp(r'R\s?\d{1,3} \d{3}').hasMatch(s))
        .toList();
    expect(spaced, isEmpty,
        reason: 'these figures group their thousands with a space while the '
            'rest of the product uses `NumberFormat`: $spaced. Change the '
            'pattern in one place if the convention is meant to move — do not '
            'reintroduce a second implementation.');
  });

  testWidgets('the buyer dashboard prefixes its Rand', (tester) async {
    await pumpDash(tester, const BuyerPortalDashboardScreen(), OrgType.buyer);

    // `kBuyerValues`: payable 40 920 for the one load that has a payable value.
    expect(moneyStrings(tester), contains('R40,920'),
        reason: 'the payable KPI is not showing a prefixed Rand figure.');

    final trailing =
        moneyStrings(tester).where((s) => RegExp(r'\d\s*R$').hasMatch(s));
    expect(trailing, isEmpty,
        reason: 'a figure on this screen ends in R: $trailing.');
  });
}

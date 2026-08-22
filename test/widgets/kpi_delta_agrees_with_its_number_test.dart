// A delta badge must not contradict the number it is glued to.
//
// Photographed on the live buyer dashboard, 2026-08-22, one card apart:
//
//     ▲ −35 · 24h        Tons delivered  68.7 t     (amber)
//       −6351            Payable         R49,710    (green, no arrow, no period)
//
// Three faults in one badge, and a fourth on the transporter dashboard where
// the same component wrote `▲ −956566 · 24h` beside a value of `R156,567`:
//
//   1. The ▲ was hardcoded onto the tones `up` and `warn`. `PortalKpiRow` maps
//      the SIGN of a signed delta onto the TONE, so every unwelcome FALL drew
//      an up arrow.
//   2. Because the arrow rode on the tone, a WELCOME fall (payable dropping,
//      `deltaGoodWhenUp: false`) drew no arrow and no period at all — two
//      cards in one row printing the same kind of measurement in two shapes.
//   3. `· 24h` was a literal. Portal deltas are measured against the previous
//      window of the SELECTED period, so a 7-day movement was captioned 24h
//      and a 12-month one would have been too.
//   4. A Rand delta was written without its currency, ungrouped, beside a
//      value that had both.
//
// The arrow is now read off the sign of the delta STRING, so it cannot
// disagree with the figure whatever a caller does with the colour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';
import 'package:go_router/go_router.dart';

import '../test_helpers/real_fonts.dart';

/// The two cards that sat side by side on the live buyer dashboard: a fall
/// that is unwelcome, and a fall that is welcome.
final _kpis = <PortalKpi>[
  const PortalKpi(
    label: 'Tons delivered',
    value: '68.7',
    unit: 't',
    sublabel: 'Offload weight, 7 days',
    icon: Icons.local_shipping_outlined,
    tone: MlTone.accent,
    route: '/portal/buyer/loads-value',
    delta: -35,
  ),
  const PortalKpi(
    label: 'Payable',
    value: 'R49,710',
    sublabel: 'At the agreed rate, after quality penalty',
    icon: Icons.account_balance_wallet_outlined,
    tone: MlTone.done,
    route: '/portal/buyer/loads-value',
    delta: -6351,
    deltaPrefix: 'R',
    deltaGoodWhenUp: false,
  ),
  const PortalKpi(
    label: 'Tons out',
    value: '235.8',
    unit: 't',
    sublabel: 'Weighbridge net, 7 days',
    icon: Icons.scale_outlined,
    tone: MlTone.accent,
    route: '/portal/mine/tons-out',
    delta: 170,
  ),
];

/// The WIDEST delta the product actually produces, so the overflow sweep has
/// something real to fail on.
///
/// `−956566` was on the live transporter dashboard on 2026-08-22, beside a
/// value of `R156,567`. Written properly it is `−R956,566 · 12m` — fifteen
/// characters where the old badge was eleven, which is the whole reason the
/// unflexed `Row` had survived. A sweep run against the −6,351 buyer figure
/// passes with the `Flexible` removed; it is not a faithful scene.
final _wideKpis = <PortalKpi>[
  ..._kpis,
  const PortalKpi(
    label: 'Revenue',
    value: 'R156,567',
    sublabel: 'At your rate per ton, before costs',
    icon: Icons.account_balance_wallet_outlined,
    tone: MlTone.done,
    route: '/portal/transporter/earnings',
    delta: -956566,
    deltaPrefix: 'R',
  ),
];

Widget _app(PortalPeriod period, {List<PortalKpi>? kpis}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: PortalKpiRow(kpis: kpis ?? _kpis, period: period),
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.build(Brightness.dark),
    routerConfig: router,
  );
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('a fall draws ▼ and a rise draws ▲, whatever the colour',
      (tester) async {
    await tester.pumpWidget(_app(PortalPeriod.week));
    await tester.pumpAndSettle();

    // Two falls — one unwelcome (amber), one welcome (green). BOTH point down.
    expect(find.text('▼'), findsNWidgets(2));
    // One rise.
    expect(find.text('▲'), findsOneWidget);

    // The exact string that was on screen must never come back.
    expect(find.text('−35 · 24h'), findsNothing);
  });

  testWidgets('the period is the one the reader selected, not a literal 24h',
      (tester) async {
    for (final (period, window) in const [
      (PortalPeriod.day, '1d'),
      (PortalPeriod.week, '7d'),
      (PortalPeriod.month, '30d'),
      (PortalPeriod.year, '12m'),
    ]) {
      await tester.pumpWidget(_app(period));
      await tester.pumpAndSettle();

      expect(find.text('−35 · $window'), findsOneWidget,
          reason: 'the badge must name the window it was measured over');
      expect(find.textContaining('24h'), findsNothing);
    }
  });

  testWidgets('a Rand delta is written as Rand, grouped', (tester) async {
    await tester.pumpWidget(_app(PortalPeriod.week));
    await tester.pumpAndSettle();

    expect(find.text('−R6,351 · 7d'), findsOneWidget);
    // The bare, ungrouped form that was on the live card.
    expect(find.text('−6351 · 7d'), findsNothing);
    expect(find.text('−6351'), findsNothing);

    // A tonnage delta keeps its grouping too, and takes no prefix.
    expect(find.text('+170 · 7d'), findsOneWidget);
  });

  testWidgets('every delta wears the same shape — arrow, figure, window',
      (tester) async {
    await tester.pumpWidget(_app(PortalPeriod.week));
    await tester.pumpAndSettle();

    // Three KPIs, three deltas, three arrows, three windows. The welcome fall
    // used to have none of the three.
    expect(find.textContaining('· 7d'), findsNWidgets(3));
    expect(
      find.text('▼').evaluate().length + find.text('▲').evaluate().length,
      3,
    );
  });

  // CLAUDE.md §10.4: a `Row` hands a non-flex child unbounded width, so the
  // badge could not ellipsise — it pushed the row over. It survived only while
  // the badge was `▲ −35 · 24h`; a real currency delta is twice that.
  testWidgets('the badge never overflows its tile, even at the 2.0 text scale',
      (tester) async {
    // 1100 is the WORST width, not the narrowest: it is the exact breakpoint
    // where the row goes 4-up, so each tile is ~264px — narrower than any tile
    // in the 2-up or stacked layouts below it. Sweeping 1600/900/360 only
    // passes with the `Flexible` removed, which is a sweep that proves nothing.
    for (final width in const [1600.0, 1100.0, 900.0, 620.0, 360.0]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: _app(PortalPeriod.year, kpis: _wideKpis),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'overflowed at ${width}px × $scale');
      }
    }
  });
}

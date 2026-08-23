// The portal dashboard band vocabulary (P7-20).
//
// These are the widgets the three org dashboards are built from, so a fault
// here is a fault on every dashboard. Two things are pinned:
//
//   * **Layout** across width × text scale with the real fonts loaded — the
//     KPI row is a 4-up grid of tiles carrying a value, a unit, a label, a sub
//     and a delta badge, which is the densest row in the portal.
//   * **The null-vs-zero rule.** A KPI with no value renders a dash and its
//     reason; a queue that failed to load renders a dash; a queue at zero
//     renders its cleared message. Reporting any of those as `0` is the fault
//     that put a hardcoded 28,000 t target on the transporters chart and
//     rendered every colleague "offline" on the Employee Register.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_dashboard_widgets.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

const _widths = <double>[1600, 1280, 1024, 430];
const _scales = <double>[0.85, 1.0, 1.15, 1.3, 1.6, 2.0];

/// Deliberately awkward: a long label, a long unit, a big delta, a null value
/// and a real zero all in one row.
final _kpis = <PortalKpi>[
  const PortalKpi(
    label: 'Tons out',
    value: '12 480',
    unit: 't',
    sublabel: 'Weighbridge net, 7 days',
    icon: Icons.scale_outlined,
    tone: MlTone.accent,
    route: '/portal/mine/tons-out',
    delta: 1840.5,
  ),
  const PortalKpi(
    label: 'Stockpile balance',
    value: '2 340',
    unit: 't of 4 000',
    sublabel: '59% of ordered cap',
    icon: Icons.inventory_2_outlined,
    tone: MlTone.atMine,
    route: '/portal/mine/stockpiles',
  ),
  const PortalKpi(
    label: 'Trucks inbound',
    value: '0',
    sublabel: 'Scheduled or on the way to the gate',
    icon: Icons.login_rounded,
    tone: MlTone.transit,
    route: '/portal/mine/security',
    delta: -3,
    deltaGoodWhenUp: false,
  ),
  const PortalKpi(
    label: 'Loads awaiting weigh',
    value: null,
    sublabel: 'Checked in, not yet loaded',
    icon: Icons.pending_actions_outlined,
    tone: MlTone.warn,
    route: '/portal/mine/weighbridge',
    emptyReason: 'weighbridge queue unavailable',
  ),
];

final _queue = <PortalQueueItem>[
  const PortalQueueItem(
    label: 'Arrivals to check in',
    count: 4,
    route: '/portal/mine/security',
    icon: Icons.login_rounded,
    tone: MlTone.transit,
    clearedMessage: 'No trucks waiting at the gate',
  ),
  const PortalQueueItem(
    label: 'Loads to weigh',
    count: 0,
    route: '/portal/mine/weighbridge',
    icon: Icons.scale_outlined,
    tone: MlTone.atMine,
    clearedMessage: 'Nothing on the weighbridge queue',
  ),
  const PortalQueueItem(
    label: 'Open reconciliation disputes',
    count: null,
    route: '/portal/mine/reconciliations',
    icon: Icons.gavel_outlined,
    tone: MlTone.error,
    clearedMessage: 'No disputes open against your loads',
  ),
];

final _trucks = <PortalLiveTruck>[
  const PortalLiveTruck(
    registration: 'CA 123-456 GP',
    status: 'Arrived at Mine',
    tone: MlTone.atMine,
    detail: 'Chrome 38/40',
  ),
  const PortalLiveTruck(
    registration: 'ND 998-221 MP',
    status: 'On Route to Load',
    tone: MlTone.transit,
  ),
];

Widget _page({required PortalPeriod period}) => Builder(
      builder: (context) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PortalDashboardHeader(
                title: 'Mine overview',
                subtitle: 'Tons out, stockpile cover and the mine floor — '
                    'live, over the last 7 days.',
                period: period,
                onPeriodChanged: (_) {},
                actions: [
                  MlButton.tonal(
                    label: 'Recon tables',
                    icon: Icons.table_chart_outlined,
                    compact: true,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PortalKpiRow(kpis: _kpis, period: period),
              const SizedBox(height: 24),
              PortalActionQueue(items: _queue),
              const SizedBox(height: 24),
              PortalDashboardSection(
                title: 'On the mine floor',
                subtitle: 'Every truck between the gate and the weighbridge.',
                meta: '2 active',
                viewRoute: '/portal/mine/truck-locations',
                viewLabel: 'Truck locations',
                child: PortalLiveStrip(
                  trucks: _trucks,
                  emptyMessage: 'No trucks are inbound or on site right now.',
                ),
              ),
            ],
          ),
        ),
      ),
    );

/// The kit navigates with `context.go`, so it needs a real router above it.
Widget _app({
  required Brightness brightness,
  required double scale,
  required bool boldText,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => _page(period: PortalPeriod.week),
      ),
      for (final p in const [
        '/portal/mine/tons-out',
        '/portal/mine/stockpiles',
        '/portal/mine/security',
        '/portal/mine/weighbridge',
        '/portal/mine/reconciliations',
        '/portal/mine/truck-locations',
      ])
        GoRoute(path: p, builder: (_, __) => const Scaffold(body: Text('x'))),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale), boldText: boldText),
      child: child!,
    ),
  );
}

void main() {
  setUpAll(() async {
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
      'PlusJakartaSans-ExtraBold.ttf',
    ]);
    await _loadFont('JetBrainsMono', [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Medium.ttf',
      'JetBrainsMono-Bold.ttf',
    ]);
    await _loadFont('Fraunces', [
      'Fraunces-Medium.ttf',
      'Fraunces-MediumItalic.ttf',
      'Fraunces-SemiBold.ttf',
    ]);
  });

  Future<void> sweep(WidgetTester tester, Brightness brightness,
      {bool boldText = false}) async {
    for (final width in _widths) {
      for (final scale in _scales) {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        await tester.pumpWidget(
          _app(brightness: brightness, scale: scale, boldText: boldText),
        );
        await tester.pump(const Duration(milliseconds: 400));

        FlutterError.onError = previousOnError;
        tester.takeException();

        final faults = captured.where((d) {
          final s = d.exception.toString();
          return s.contains('overflowed') ||
              s.contains('forces an infinite') ||
              s.contains('BoxConstraints');
        }).toList();

        expect(
          faults,
          isEmpty,
          reason: 'dashboard kit (${brightness.name}) at ${width.toInt()}px × '
              '$scale${boldText ? ' bold' : ''}: '
              '${faults.map((f) => f.exception).join('; ')}',
        );

        // A clean sweep over a page that failed to render proves nothing.
        expect(find.text('Mine overview'), findsOneWidget,
            reason: 'kit did not render at ${width.toInt()}px × $scale');
      }
    }
  }

  testWidgets('dashboard kit survives width × text scale (dark)',
      (tester) async {
    await sweep(tester, Brightness.dark);
  });

  testWidgets('dashboard kit survives width × text scale (light)',
      (tester) async {
    await sweep(tester, Brightness.light);
  });

  testWidgets('dashboard kit survives bold text', (tester) async {
    await sweep(tester, Brightness.light, boldText: true);
  });

  testWidgets('a KPI with no value renders a dash and its reason, never 0',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, scale: 1.0, boldText: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The unavailable KPI.
    expect(find.text('weighbridge queue unavailable'), findsOneWidget);
    expect(find.text('Checked in, not yet loaded'), findsNothing);

    // A REAL zero still reads as 0 with its own sublabel — the distinction is
    // the whole point.
    expect(find.text('Scheduled or on the way to the gate'), findsOneWidget);

    // The dash appears for the unavailable KPI and the unavailable queue.
    // `findRichText` is needed for the KPI: `SaStatTile` paints value+unit as
    // one `RichText` so the unit can sit on the value's baseline, and a plain
    // `find.text` walks straight past it.
    expect(find.text('—', findRichText: true), findsNWidgets(2));

    // Exactly two real zeros on the page — the "Trucks inbound" KPI and the
    // cleared "Loads to weigh" queue row. If the unavailable KPI or the
    // unreadable queue had quietly become a zero there would be three or four,
    // which is the whole failure mode this test exists for.
    expect(find.text('0', findRichText: true), findsNWidgets(2));
  });

  testWidgets('the action queue distinguishes cleared from unreadable',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, scale: 1.0, boldText: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('4 waiting'), findsOneWidget);
    // Zero is good news, and says so rather than printing "0 waiting".
    expect(find.text('Nothing on the weighbridge queue'), findsOneWidget);
    // A queue that could not be read is NOT reported as cleared.
    expect(find.text('Could not read this queue'), findsOneWidget);
    expect(find.text('No disputes open against your loads'), findsNothing);
  });

  // A section head's meta and `View →` sit at the RIGHT EDGE of the band, as
  // every section header on the reference does. Until 2026-08-23 the head
  // was `Flexible(title) · Spacer() · Flexible(meta) · action` — three
  // flex-1 children splitting the free space in thirds — so the meta landed
  // at two-thirds of the row ("4 queues with work" at x≈860 in a 1570-wide
  // band), on every band of every portal dashboard. Asserting on geometry,
  // not on the absence of overflow: nothing overflowed, which is why three
  // width × scale sweeps never saw it (CLAUDE.md §10.4).
  testWidgets("the head's meta and link sit at the right edge of the band",
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, scale: 1.0, boldText: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The page pads 16, so every band ends at 1584.
    const bandRight = 1600.0 - 16;

    // Meta with no action: flush with the band's right edge.
    final queueMeta = tester.getRect(find.text('1 queue with work'));
    expect(queueMeta.right, closeTo(bandRight, 1.5),
        reason: 'action-queue meta should end at the band edge, '
            'ends at ${queueMeta.right}');

    // Meta beside a link: the link is flush right, the meta 14px before it.
    final link = tester.getRect(
      find.widgetWithText(TextButton, 'Truck locations →'),
    );
    expect(link.right, closeTo(bandRight, 1.5),
        reason: 'View link should end at the band edge, ends at ${link.right}');
    final meta = tester.getRect(find.text('2 active'));
    expect(meta.right, closeTo(link.left - 14, 1.5),
        reason: 'meta should sit 14px before the link, '
            'ends at ${meta.right} with the link at ${link.left}');
    // And the title still starts at the band's left edge, unmoved.
    expect(tester.getRect(find.text('On the mine floor')).left,
        closeTo(16, 1.5));
  });

  // The delta chip sits flush top-right of its tile, as the reference's
  // `▲ 2 · 24h` does. It was `Spacer() + Flexible(chip)` — two flex-1
  // children splitting the free space — so the chip started at the tile's
  // midpoint and ended ~55px short of the edge on every dashboard. Found by
  // two reviewers, 2026-08-23. Geometry, because nothing overflowed.
  testWidgets("the KPI delta chip is flush with the tile's right edge",
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, scale: 1.0, boldText: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final tile = tester.getRect(find.ancestor(
      of: find.text('Tons out'),
      matching: find.byType(SaStatTile),
    ));
    final chip = tester.getRect(find.textContaining('7d').first);
    // The tile pads 16; the chip's own trailing padding is a few px.
    expect(chip.right, greaterThan(tile.right - 24),
        reason: 'chip ends at ${chip.right} in a tile ending at ${tile.right}');
  });

  testWidgets('every KPI tile and queue row navigates to its screen',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, scale: 1.0, boldText: false),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Tapping the tons-out KPI leaves the dashboard for its own screen.
    await tester.tap(find.text('Tons out'));
    await tester.pumpAndSettle();
    expect(find.text('Mine overview'), findsNothing);
    expect(find.text('x'), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // The band head places its tools BY FIT, not by width.
  //
  // Buyer pass, 2026-08-23 (reviewer finding #2, seen in
  // `dash-buyer-desktop-light`). `SaSectionHeader` stacked whenever its
  // column was under a hard-coded 560px, into a plain `Wrap` — which starts
  // its run at the LEFT. The buyer dashboard's "Invoice cover" band is a
  // 497px column on a 1600px SCREEN, and "Invoice cover" + "View →" fits
  // there with room to spare: it stacked anyway, and put its action at the
  // left margin while "Delivered vs payable" beside it had meta and action on
  // the title's row at the right edge. Two bands of one dashboard, side by
  // side, in two layouts.
  //
  // `MlPageHeader` already paid 43 goldens to learn that a width rule is not
  // a fit rule (`bcb0fdb`), so its measuring layout moved to
  // `MlHeaderLayout` and this header shares it rather than repeating the
  // mistake in a third place.

  Future<void> pumpHead(
    WidgetTester tester, {
    required double width,
    required String title,
    String? meta,
    Widget? action,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: SaSectionHeader(
                title: title,
                subtitle: 'One calm sentence under the title.',
                meta: meta,
                action: action,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a narrow band whose tools FIT keeps them on the title\'s row',
      (tester) async {
    // The buyer's "Invoice cover" column, to the pixel. Under the old 560px
    // rule this stacked; it fits.
    await pumpHead(
      tester,
      width: 497,
      title: 'Invoice cover',
      action: TextButton(onPressed: () {}, child: const Text('View →')),
    );

    final titleRect = tester.getRect(find.text('Invoice cover'));
    final actionRect =
        tester.getRect(find.widgetWithText(TextButton, 'View →'));
    final description =
        tester.getRect(find.text('One calm sentence under the title.'));

    expect(
      actionRect.center.dy,
      inInclusiveRange(titleRect.top, titleRect.bottom),
      reason: 'the action shares the title\'s row — it fits',
    );
    expect(
      actionRect.right,
      closeTo(497, 1.5),
      reason: 'and it is flush with the band\'s right edge, '
          'ends at ${actionRect.right}',
    );
    expect(
      description.top,
      greaterThan(titleRect.bottom - 1),
      reason: 'the description belongs directly under its own title',
    );
  });

  testWidgets('a band whose tools do NOT fit stacks them flush RIGHT',
      (tester) async {
    // Long title, long tools, narrow band: this genuinely cannot share a row.
    await pumpHead(
      tester,
      width: 300,
      title: 'Delivered versus payable value',
      meta: 'Peak R40,920/day',
      action: TextButton(onPressed: () {}, child: const Text('View →')),
    );

    final titleRect = tester.getRect(find.text('Delivered versus payable value'));
    final actionRect =
        tester.getRect(find.widgetWithText(TextButton, 'View →'));

    expect(
      actionRect.top,
      greaterThan(titleRect.bottom),
      reason: 'these cannot share a row at 300px',
    );
    expect(
      actionRect.right,
      closeTo(300, 1.5),
      reason: 'a stacked run lands at the LEFT unless it is told otherwise, '
          'and that is the whole fault — ends at ${actionRect.right}',
    );
    // The meta rides just before it, not at the left margin either.
    expect(
      tester.getRect(find.text('Peak R40,920/day')).left,
      greaterThan(1.0),
      reason: 'the meta is part of the right-aligned run',
    );
  });
}

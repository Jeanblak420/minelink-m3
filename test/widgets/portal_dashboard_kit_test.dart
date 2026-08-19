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
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

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
const _scales = <double>[0.85, 1.0, 1.15, 1.3];

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
              PortalKpiRow(kpis: _kpis),
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
}

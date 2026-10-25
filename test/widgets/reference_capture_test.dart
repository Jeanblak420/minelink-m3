// Reference capture — renders the two screens that ARE the design reference
// and writes them to PNG, so the S5 migration has something to be compared
// against rather than a paragraph describing it.
//
// Client instruction 2026-08-14: "check how the super global admin's complete
// dash and transporters overview looks and use that as reference to continue
// forward."
//
// This is not an assertion test and deliberately makes no golden comparison —
// a golden would fail on every legitimate design change and teach everyone to
// regenerate it without looking. It renders, writes, and says where. Run:
//
//     flutter test test/widgets/reference_capture_test.dart
//
// Output: docs/design-reference/*.png — committed, so the reference is shared.
//
// The real fonts are loaded, because `flutter test` otherwise renders in a
// fallback font where every glyph is one em wide (CLAUDE.md §7) — capturing
// that would produce a "reference" that misrepresents every text width in it.

@Tags(['capture'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/overview_models.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/transporters_overview_body.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporters_overview_v2_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/portal/providers/mirror_company_context_provider.dart';
import '../fixtures/portal_capture_fixtures.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_screen.dart';

import '../fixtures/ml_sample_data.dart';
import 'package:flutter_application_1/features/portal/models/company_access.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import '../test_helpers/frozen_clock.dart';

// Written into docs/, NOT build/. build/ is gitignored, and a design reference
// that exists only on the machine that rendered it is not a reference — every
// later session and every reviewer needs to see the same images the migration
// is being judged against. Regenerating overwrites in place, which is correct:
// the images should track the design, and the diff shows what moved.
const _outDir = 'docs/design-reference';

/// Per-capture outcome: did the screen render CONTENT, or a load failure?
///
/// A capture harness that silently produced pretty empty screens would be
/// worse than the error cards it replaced, because nobody would know which
/// screens the fixture actually covers. This records it and the last test in
/// the file prints the split.
final Map<String, String> _captureOutcome = <String, String>{};

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

/// Material Icons is NOT loaded by `flutter test` by default, so every
/// `Icon(...)` rasterises as a tofu box. On a design capture that is not a
/// cosmetic detail — icon wells are a core part of this design's vocabulary,
/// and a reference full of empty squares misrepresents every card in it.
/// The font ships inside the Flutter SDK; located rather than vendored so it
/// cannot drift from the SDK actually building the app.
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (root != null)
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    if (root != null)
      '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    'C:/src/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader('MaterialIcons')
      ..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
    return;
  }
  // ignore: avoid_print
  print('WARNING  MaterialIcons not found — icons will capture as tofu boxes.');
}

Future<void> _loadRealFonts() async {
  await _loadMaterialIcons();
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
  await _loadFont('Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
  await _loadFont('Sora', [
    'Sora-Regular.ttf',
    'Sora-Medium.ttf',
    'Sora-SemiBold.ttf',
    'Sora-Bold.ttf',
  ]);
}

/// Pumps [child] at [size] in [brightness] and writes a PNG.
Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(1440, 2400),
  Brightness brightness = Brightness.dark,
  bool trackContent = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
            // The REAL app theme, not a bare ThemeData(brightness:). A bare theme
      // leaves TextButton on Material's default lavender, which made every
      // "View →" link in the first portal captures look like an off-palette
      // bug. It was the harness, not the screen — but a capture that misstates
      // a colour is worse than no capture, so it uses what the app ships.
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: MediaQueryData(size: size, platformBrightness: brightness),
          // `MaterialApp` does NOT insert a Material — `Scaffold` does. Without
          // one, Flutter marks every text run with its "no Material ancestor"
          // indicator: a YELLOW DOUBLE UNDERLINE. Every console capture taken
          // before 2026-08-15 has it under every label, figure and heading,
          // because `_capturePortal` supplies a Scaffold and the three console
          // screens went through this function bare.
          //
          // It was not read as an artifact. `docs/design-reference.md` §4
          // described the mark under the hero figure as "a cyan rule
          // underneath it" and made it a rule migrated screens must satisfy —
          // a debug indicator promoted into the spec. There is no such rule in
          // `tons_moved_card.dart`.
          //
          // Transparent so the screens keep painting their own canvas; this
          // supplies the ancestor and nothing else.
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    ),
  );

  // Let charts, gradients and any implicit animation settle. pumpAndSettle
  // would hang on a repeating animation, so pump a bounded number of frames.
  //
  // The budget has to EXCEED the longest count-up on screen, and it did not.
  // It was 6 x 120ms = 720ms against `AnimatedTons`' 850ms tween, so the mine
  // supervisor capture read `123.975 / 200 t` where the fixture says 128.4 —
  // a reference image showing a number the product never rests on. Found by
  // reading the figure off the PNG after the Fraunces change, not by any test:
  // a mid-animation frame is a perfectly valid frame, so nothing fails.
  //
  // 1.44s covers the 850ms tween with room for a chart drawn after it. If a
  // longer animation is added, this has to grow with it.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }

  // Recorded BEFORE the tree is unmounted below, and only for portal SCREEN
  // captures. The component gallery renders an MlLoadFailure ON PURPOSE — it
  // is one of the components being shown — so tracking every capture reported
  // the gallery as broken. A detector that cannot tell a rendered example from
  // a real failure is worse than none.
  if (trackContent) {
    _captureOutcome[name] = tester
            .widgetList<MlEmptyState>(find.byType(MlEmptyState))
            .any((w) => w.title.startsWith('Could not load'))
        ? 'LOAD FAILURE'
        : 'content';
  }

  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;

  // toImage/toByteData are REAL async work on the raster thread, and the test
  // binding runs in fake-async. Awaiting them directly writes the PNG and then
  // hangs the test until the 10-minute timeout — a green artifact behind a red
  // test, which is the most confusing outcome available.
  //
  // (First attempt at this was tearing the tree down afterwards, on the theory
  // that a repeating ticker held it open. That was wrong: it still hung when
  // run clean and alone. runAsync is the actual contract for real async work
  // inside testWidgets.)
  final path = '$_outDir/$name.png';
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_outDir).createSync(recursive: true);
      File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
  // ignore: avoid_print
  print('CAPTURED  $path  (${size.width.toInt()}x${size.height.toInt()}, $brightness)');

  // Unmount so any ticker the screen started does not outlive the test.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
    // The portal dashboards touch Supabase.instance while building. A dummy
    // instance is enough to get them rendering; no request is ever made, and
    // every provider resolves to its empty state — which is exactly the state
    // worth looking at, because it is what a new org sees on day one.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'design-reference-capture',
    );
  });

  testWidgets('capture: super admin dashboard (dark)', (tester) async {
    await _capture(
      tester,
      'super-admin-dashboard-dark',
      MineLinkDashboardScreen(
        orgAggregates: MlSampleData.orgAggregates,
        pendingRequests: MlSampleData.pendingRequests,
        registry: MlSampleData.registry,
        recentOrgs: MlSampleData.recentOrgs,
      ),
    );
  });

  testWidgets('capture: super admin dashboard (light)', (tester) async {
    await _capture(
      tester,
      'super-admin-dashboard-light',
      MineLinkDashboardScreen(
        orgAggregates: MlSampleData.orgAggregates,
        pendingRequests: MlSampleData.pendingRequests,
        registry: MlSampleData.registry,
        recentOrgs: MlSampleData.recentOrgs,
      ),
      brightness: Brightness.light,
    );
  });

  testWidgets('capture: transporters overview (dark)', (tester) async {
    await _capture(
      tester,
      'transporters-overview-dark',
      TransportersOverviewBody(data: _transportersFixture()),
      // Narrower + shorter than the dashboard: this body is a tall scrollable
      // and rasterising it at 1440x2400 took minutes without finishing.
      size: const Size(1280, 1600),
    );
  });

  // ---------------------------------------------------------------------
  // The three org portals — S5-20 / S5-21. These are what the migration has
  // to bring up to the console's standard, so they are captured BEFORE any of
  // it, as the before-image to compare against.
  //
  // Rendered with no data: every provider resolves empty here. That is not a
  // limitation, it is the most important state to look at — it is what a real
  // org sees on its first day, and an empty state that looks broken is a
  // first impression you only get once.
  // ---------------------------------------------------------------------

  testWidgets('capture: mine portal dashboard (dark)', (tester) async {
    await _capturePortal(tester, 'portal-mine-dashboard-dark',
        const MineSupplierPortalDashboardScreen());
  });

  testWidgets('capture: buyer portal dashboard (dark)', (tester) async {
    await _capturePortal(tester, 'portal-buyer-dashboard-dark',
        const BuyerPortalDashboardScreen());
  });

  testWidgets('capture: transporter portal dashboard (dark)', (tester) async {
    await _capturePortal(tester, 'portal-transporter-dashboard-dark',
        const TransporterPortalDashboardScreen());
  });


  // ---------------------------------------------------------------------
  // The MINE portal's screens — S5-20. Captured before migration so the
  // "after" has something to be compared against.
  // ---------------------------------------------------------------------
  for (final entry in <String, Widget>{
    'portal-mine-stockpiles': const StockpileDetailScreen(),
    'portal-mine-production': const MineProductionScreen(),
    'portal-mine-quality': const MineQualityScreen(),
    'portal-mine-reconciliations': const MineReconciliationsScreen(),
    'portal-mine-supervisor': const SupervisorViewScreen(),
    'portal-mine-security': const SecurityCheckinScreen(),
    'portal-mine-weighbridge': const LoadControllerScreen(),
    'portal-mine-tons-out': const PortalTonsOutScreen(),
  }.entries) {
    testWidgets('capture: ${entry.key}', (tester) async {
      await _capturePortal(tester, '${entry.key}-dark', entry.value);
    });
  }

  // ---------------------------------------------------------------------
  // The shared portal components, on their own.
  //
  // Added because the screen captures could not show them. Every portal
  // screen here renders with no backend, so the screens that use MlStatCard
  // resolve to an error or empty state and the card never appears — a
  // component could be migrated, tested and committed without one person
  // having looked at it. That is the exact gap the capture loop exists to
  // close, so the components get their own page with data in them.
  // ---------------------------------------------------------------------

  for (final brightness in [Brightness.dark, Brightness.light]) {
    final name = brightness == Brightness.dark ? 'dark' : 'light';
    testWidgets('capture: portal components ($name)', (tester) async {
      await _capture(
        tester,
        'portal-components-$name',
        Builder(
          builder: (context) => Scaffold(
            backgroundColor: MlSemantic.of(context).surfaceApp,
            body: const MlPageBody(child: _ComponentGallery()),
          ),
        ),
        size: const Size(1100, 1150),
        brightness: brightness,
      );
    });
  }

  // The two S8 surfaces, rendered so they can be looked at. Both are dialogs
  // and banners that no screen capture reaches, which is exactly how a
  // component gets shipped without anyone seeing it.
  testWidgets('capture: chat states (dark)', (tester) async {
    await _capture(
      tester,
      'chat-states-dark',
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: MlSemantic.of(context).surfaceApp,
          body: const MlPageBody(child: _ChatStatesGallery()),
        ),
      ),
      size: const Size(900, 640),
    );
  });

  test('report which captures show CONTENT and which show a load failure', () {
    final failures = _captureOutcome.entries
        .where((e) => e.value != 'content')
        .map((e) => e.key)
        .toList()
      ..sort();
    // ignore: avoid_print
    print('\nCAPTURE CONTENT — ${_captureOutcome.length - failures.length} of '
        '${_captureOutcome.length} render content');
    for (final f in failures) {
      // ignore: avoid_print
      print('  LOAD FAILURE  $f  (no fixture covers its providers yet)');
    }
    // Deliberately NOT an assertion. The fixture does not cover every screen,
    // and failing here would either block the run or push somebody to fake a
    // provider just to go green. The number is the point; it belongs in the
    // run log next to the images, where a reader can see what a capture is
    // worth before trusting it.
  });

  test('record the reference palette in the run log', () {
    // Printed so the numbers behind the images are in the same artifact as the
    // images, rather than in a paragraph somebody has to trust.
    // ignore: avoid_print
    print('REFERENCE ACCENT  MlGlass.dark.accent = ${MlGlass.dark.accent}  '
        'MlGlass.light.accent = ${MlGlass.light.accent}  '
        'MlOv.dark.acc = ${MlOv.dark.acc}');
    // ignore: avoid_print
    print('REFERENCE SANS    MlGlass.sans = ${MlGlass.sans}  '
        'MlOv.sans = ${MlOv.sans}');
    expect(MlGlass.dark.accent, MlOv.dark.acc,
        reason: 'both reference surfaces must resolve to ONE accent');
  });
}

/// The chat states added by S8-3 and S8-4, which live in a dialog and a banner
/// and so appear in no screen capture.
class _ChatStatesGallery extends StatelessWidget {
  const _ChatStatesGallery();

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    Widget contactRow(ChatContact c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(c.displayName,
                    style: TextStyle(color: semantic.textStrong)),
              ),
              Tooltip(
                message: c.blockedTooltip,
                child: MlStatusBadge(
                  label: c.blockedLabel,
                  tone: c.isBlockedByExpiry
                      ? MlTone.warn
                      : c.isBlockedByHierarchy
                          ? MlTone.neutral
                          : MlTone.error,
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MlPageHeader(
          title: 'Chat states',
          description: 'Why a contact is unreachable, and what an ended '
              'conversation looks like.',
        ),
        const MlSectionTitle(
          'Blocked contacts — three reasons, three sentences',
          icon: Icons.person_off_outlined,
          subtitle: 'Each says what to do instead. None of them says only '
              '"Blocked".',
        ),
        contactRow(const ChatContact(
            userId: '1', displayName: 'Thandi (driver)',
            isBlocked: true, blockReason: 'hierarchy')),
        contactRow(const ChatContact(
            userId: '2', displayName: 'Sipho (colleague)',
            isBlocked: true, blockReason: 'token_expired')),
        contactRow(const ChatContact(
            userId: '3', displayName: 'Atlas Buyer Group',
            isBlocked: true, blockReason: 'org_revoked')),
        const SizedBox(height: 26),
        const MlSectionTitle(
          'Ended conversation',
          icon: Icons.do_not_disturb_on_outlined,
          subtitle: 'Neutral, not red — a chat closed on purpose is not a '
              'fault.',
        ),
        MlCard(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: semantic.surfaceSunken,
            child: Row(
              children: [
                Icon(Icons.do_not_disturb_on_outlined,
                    color: semantic.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This conversation has been ended. Everything said is '
                    'still here to read, but no new messages can be sent.',
                    style: TextStyle(
                      color: semantic.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Every shared portal component the S5 migration touches, with real-shaped
/// data in it, so the treatment can be looked at rather than inferred from a
/// test that says `fontFamily == 'Fraunces'`.
///
/// The figures are illustrative and are NOT a claim about any KPI — the
/// standing caveat applies (94.1% of live tonnage is seeded), and these are
/// not even that: they are typed in here to exercise the layout.
class _ComponentGallery extends StatelessWidget {
  const _ComponentGallery();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MlPageHeader(
          title: 'Portal components',
          description:
              'The shared vocabulary every portal screen is assembled from, '
              'shown against the design reference.',
          meta: 'MlPageHeader · meta line',
        ),
        const MlSectionTitle(
          'Stat cards',
          icon: Icons.insights_outlined,
          subtitle: 'Tone bar left, Fraunces figure, mono sub-caption.',
          meta: 'MlSectionTitle · subtitle + meta',
        ),
        Row(
          children: const [
            Expanded(
              child: MlStatCard(
                label: 'Tons out',
                value: '1,193.7',
                icon: Icons.scale_outlined,
                caption: 'Net mass · all time',
                tone: MlTone.accent,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: MlStatCard(
                label: 'Trucks on route',
                value: '24',
                icon: Icons.local_shipping_outlined,
                caption: 'available_6 · maintenance_2',
                tone: MlTone.transit,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: MlStatCard(
                label: 'PODs missing',
                value: '3',
                icon: Icons.photo_camera_outlined,
                caption: 'action_needed',
                tone: MlTone.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const MlSectionTitle(
          'Section header with a link',
          icon: Icons.table_chart_outlined,
          subtitle: 'The View → arrow is appended by the component.',
          link: 'View all',
        ),
        const SizedBox(height: 10),
        const MlSectionTitle('Plain section header, no meta'),
        const SizedBox(height: 26),
        const MlSectionTitle(
          'Restricted company notice',
          icon: Icons.hourglass_disabled_rounded,
          subtitle: 'Warn-toned, not error — a lapsed token is a billing state '
              'the customer can fix, not a fault.',
        ),
        MlExpiryNotice(
          access: CompanyAccess(
            isActive: false,
            isPlatformAdmin: false,
            companyId: 'c1',
            companyName: 'SteelWorks SA',
            status: 'expired',
            tokenExpiresAt: DateTime.utc(2026, 4, 23),
            daysSinceExpiry: 113,
          ),
          onRequestRenewal: () {},
          onMessageMineLink: () {},
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MlLockedBadge(
              access: CompanyAccess(
                isActive: false,
                isPlatformAdmin: false,
                companyId: 'c1',
                status: 'expired',
              ),
              action: 'record loads',
            ),
          ],
        ),
        const SizedBox(height: 26),
        const MlSectionTitle(
          'Load failure',
          icon: Icons.wifi_off_rounded,
          subtitle: 'Names what failed, and always offers a way back.',
        ),
        MlCard(
          child: SizedBox(
            height: 260,
            child: MlLoadFailure(
              subject: 'the gate queue',
              error: 'PostgrestException(message: , code: 400)',
              onRetry: () {},
            ),
          ),
        ),
      ],
    );
  }
}

/// The sweep test's fixture, copied verbatim so the captured reference shows
/// the same data the layout tests already exercise — long company names, five
/// fleets, a zero-tons transporter and a real variance row.
OverviewData _transportersFixture({double? target}) {
  final now = DateTime(2026, 8, 20, 12);

  CompanyMonthlyOpsStats company(
    String name, {
    required double tons,
    required int trips,
    required int fleet,
    required int done,
    required int open,
  }) =>
      CompanyMonthlyOpsStats(
        companyId: name,
        companyName: name,
        orgType: 'transporter',
        fleetVehicles: fleet,
        drivers: fleet - 4,
        employees: fleet + 12,
        routesDistinct: 9,
        trips: trips,
        loadsCount: trips,
        tonsMoved: tons,
        completedWaybills: done,
        pendingWaybills: open,
      );

  final companies = [
    company('Roadhaul Logistics & Bulk Haulage',
        tons: 12420.5, trips: 180, fleet: 42, done: 140, open: 6),
    company('Trans African Haul', tons: 9880.1, trips: 140, fleet: 31, done: 96, open: 9),
    company('Corridor Freight', tons: 6940.1, trips: 100, fleet: 23, done: 82, open: 3),
    company('b man trans', tons: 0, trips: 0, fleet: 6, done: 0, open: 0),
    company('Land Rover Transport', tons: 120.4, trips: 2, fleet: 4, done: 2, open: 1),
  ];

  final rows = <RawReconRow>[
    for (var day = 1; day <= 20; day++)
      RawReconRow(
        tripId: 'aug-$day',
        tripDate: DateTime(2026, 8, day),
        timeIn: DateTime(2026, 8, day, 7),
        timeOut: DateTime(2026, 8, day, 14),
        transporterName: 'Roadhaul Logistics & Bulk Haulage',
        truckReg: 'RH ${100 + day} GP',
        netMass: 900 + day * 31.5,
        deliveredTons: 900 + day * 31.5,
        tripStatus: 'completed',
        podPhotoPath: day.isEven ? 'pod/$day.jpg' : null,
      ),
    for (var day = 1; day <= 31; day++)
      RawReconRow(
        tripId: 'jul-$day',
        tripDate: DateTime(2026, 7, day),
        transporterName: 'Trans African Haul',
        truckReg: 'TH ${200 + day} GP',
        netMass: 700 + day * 12.0,
      ),
    RawReconRow(
      tripId: 'variance',
      tripDate: DateTime(2026, 8, 11),
      transporterName: 'Corridor Freight',
      truckReg: 'CF 001 GP',
      netMass: 34.2,
      deliveredTons: 29.4,
    ),
  ];

  return TransportersOverviewMapper.build(
    bundle: MonthlyInsightsBundle(
      companies: companies,
      aggregate: OrgTypeAggregateStats(
        orgType: 'transporter',
        companyCount: companies.length,
        activeTripsApprox: 12,
        fleetVehiclesTotal: companies.fold(0, (s, c) => s + c.fleetVehicles),
        tonsMoved: 29240.5,
        transactionsTotal: 422,
        completedWaybills: 320,
        pendingWaybills: 19,
      ),
    ),
    rows: rows,
    targetTons: target,
    now: now,
  );
}

/// Portal screens are ConsumerWidgets and need a ProviderScope.
///
/// They also return a `PortalScrollBody`, NOT a Scaffold — in the running app
/// `PortalShellLayout` supplies the Scaffold and paints the background. Capture
/// it without one and the page renders on bare white, which is a lie about how
/// the screen looks: the first version of this harness produced exactly that
/// and it read as "the portal ignores dark mode", which is not true. The
/// Scaffold below is the shell's contribution, nothing more.
///
/// Captures a portal screen with its data providers resolved to fixtures.
///
/// Until 2026-08-15 this rendered the screens with **no backend**, and every
/// portal capture in `docs/design-reference/` was a picture of an error card:
/// "Could not load this / The server refused the request", centred on an empty
/// canvas. The files were named as though they were the screens, so anyone
/// reaching for "the mine dashboard reference" got a failure state — and
/// S5-20/21, which ask for a per-screen *visual comparison*, had no surface to
/// compare against.
///
/// [portalCaptureOverrides] resolves the data providers to fixtures. The seam
/// is the provider rather than the service: every portal data provider is a
/// `FutureProvider.family` reading a service, so overriding the provider skips
/// the network without anyone implementing a service interface.
///
/// A screen whose providers are NOT in that list still renders its error state,
/// and that is deliberate — a silent fallback to a pretty empty screen would
/// hide which screens the fixture does not yet cover. `_reportCaptureContent`
/// prints the split so the gap stays visible.
Future<void> _capturePortal(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size size = const Size(1280, 1600),
}) async {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (_) {};
  try {
    await _capture(
      tester,
      name,
      ProviderScope(
        overrides: [
          // Get past `resolvePortalCompanyId`, which otherwise short-circuits
          // every portal dashboard to "Company not loaded" before any layout
          // is built.
          mirrorCompanyIdProvider.overrideWith((ref) => 'capture-company'),
          ...portalCaptureOverrides(),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: MlSemantic.of(context).surfaceApp,
            body: screen,
          ),
        ),
      ),
      size: size,
      trackContent: true,
    );
  } finally {
    FlutterError.onError = previousOnError;
  }
}

// The three scope screens — the chrome around the shared workspace.
//
// Data is injected through the provider, so nothing here touches the network:
// what is under test is that each screen puts the right scope in front of the
// user, and that the band, the org-type switch and the company picker survive
// the width x text-scale corners the console actually allows.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_org_type_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_platform_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';
import '../fixtures/ml_targets_sample.dart';

const _widths = <double>[1612, 1280, 1024, 860, 700];
const _scales = <double>[0.85, 1.0, 1.3, 1.6, 2.0];

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

final _companies = <Map<String, dynamic>>[
  {'id': 'c1', 'company_name': 'Roadhaul Logistics', 'org_type': 'transporter'},
  {'id': 'c2', 'company_name': 'Iron Hills Mining', 'org_type': 'mineSupplier'},
  {'id': 'c3', 'company_name': 'Atlas Buyer Group', 'org_type': 'buyer'},
];

List<Override> _overrides(Iterable<TargetScope> scopes) => [
      organizationsProvider.overrideWith((ref) async => _companies),
      for (final s in scopes)
        targetsProvider(s).overrideWith(
          (ref) => Stream<MlTargetsData>.value(MlTargetsSample.build()),
        ),
    ];

Widget _host(
  Widget child, {
  required List<Override> overrides,
  double width = 1612,
  double scale = 1.0,
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(width: width, height: 1000, child: child),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
    await _loadFont(
        'Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);

    // The repository provider builds a client eagerly; the screens never reach
    // the network here because the data provider itself is overridden.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'targets-screen-test-key',
    );
  });

  void sized(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width + 80, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('platform', () {
    testWidgets('names its scope and shows the live month-to-date band',
        (tester) async {
      sized(tester, 1612);
      await tester.pumpWidget(_host(
        const TargetsPlatformScreen(),
        overrides: _overrides([TargetScope.platform]),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Platform targets'), findsOneWidget);
      expect(find.text('PLATFORM-WIDE'), findsOneWidget);
      // The sample's current month is Aug 2026 and its cycle is locked. Twice:
      // once as the band's stat label, once as the current month's dial.
      expect(find.text('AUG 2026'), findsNWidgets(2));
      // Band-only wording — 'ATTAINMENT' is also a column in the month table.
      expect(find.text('moved so far'), findsOneWidget);
      expect(find.text('CYCLE LOCKED'), findsOneWidget);
      // …and the workspace below it really rendered.
      expect(find.text('Set monthly targets'), findsOneWidget);
    });
  });

  group('org type', () {
    testWidgets('offers all three types and marks the one in view',
        (tester) async {
      sized(tester, 1612);
      await tester.pumpWidget(_host(
        const TargetsOrgTypeScreen(orgType: TargetOrgType.buyer),
        overrides: _overrides([const TargetScope.orgType('buyer')]),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Buyers targets'), findsOneWidget);
      expect(find.text('BY ORG TYPE'), findsOneWidget);
      for (final o in TargetOrgType.values) {
        expect(find.text(o.label), findsOneWidget, reason: o.label);
      }
      expect(find.text('Set monthly targets'), findsOneWidget);
    });

    // Found by opening the screen in a browser on 2026-08-17, not by any test
    // here: the band read "Every load WHAT was hauled", on all three types.
    //
    // `lens` is written for the scope pill, where "WHAT WAS HAULED" is a
    // correct standalone answer, and it was interpolated straight into a
    // sentence where it is not. Nothing detected it — the string was
    // well-formed, the layout was fine, and every assertion in this file is
    // about scope and geometry. So this one is about the prose.
    for (final o in TargetOrgType.values) {
      testWidgets('the ${o.wire} band reads as a sentence', (tester) async {
        sized(tester, 1612);
        await tester.pumpWidget(_host(
          TargetsOrgTypeScreen(orgType: o),
          overrides: _overrides([TargetScope.orgType(o.wire)]),
        ));
        await tester.pumpAndSettle();

        final subtitle = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .firstWhere((s) => s.startsWith('Every load '), orElse: () => '');

        expect(subtitle, isNotEmpty, reason: 'no band subtitle for ${o.wire}');
        expect(subtitle, startsWith('Every load that '),
            reason: '"$subtitle" — a relative clause, not the pill label');
        expect(subtitle, isNot(contains('load what')), reason: subtitle);
        expect(subtitle, isNot(contains('  ')),
            reason: 'double space: $subtitle');

        // The pill keeps the standalone form; the two must not be collapsed
        // back into one string, in either direction.
        expect(o.lens, startsWith('what '), reason: o.wire);
        expect(find.text(o.lens.toUpperCase()), findsWidgets, reason: o.wire);
      });
    }

    testWidgets('every type resolves from its wire string', (tester) async {
      expect(TargetOrgType.parse('mineSupplier'), TargetOrgType.mineSupplier);
      expect(TargetOrgType.parse('buyer'), TargetOrgType.buyer);
      expect(TargetOrgType.parse('transporter'), TargetOrgType.transporter);
      expect(TargetOrgType.parse('nonsense'), TargetOrgType.transporter);
      expect(TargetOrgType.parse(null), TargetOrgType.transporter);
    });
  });

  group('company', () {
    testWidgets('with nothing picked it asks, and creates nothing',
        (tester) async {
      sized(tester, 1612);
      await tester.pumpWidget(_host(
        const TargetsCompanyScreen(),
        overrides: _overrides(const <TargetScope>[]),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Company targets'), findsOneWidget);
      expect(find.text('Choose a company'), findsOneWidget);
      // No scope means no workspace, so no cycle is minted just by browsing.
      expect(find.text('Set monthly targets'), findsNothing);
      for (final c in _companies) {
        expect(find.text(c['company_name'] as String), findsOneWidget);
      }
    });

    testWidgets('picking one titles the screen and opens the workspace',
        (tester) async {
      sized(tester, 1612);
      await tester.pumpWidget(_host(
        const TargetsCompanyScreen(companyId: 'c2'),
        overrides: _overrides([const TargetScope.company('c2')]),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Iron Hills Mining targets'), findsOneWidget);
      expect(find.text('BY COMPANY'), findsOneWidget);
      expect(find.text('Set monthly targets'), findsOneWidget);
    });

    testWidgets('the search narrows the picker', (tester) async {
      sized(tester, 1612);
      await tester.pumpWidget(_host(
        const TargetsCompanyScreen(),
        overrides: _overrides(const <TargetScope>[]),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'iron');
      await tester.pumpAndSettle();

      expect(find.text('Iron Hills Mining'), findsOneWidget);
      expect(find.text('Roadhaul Logistics'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No organization matches'), findsOneWidget);
    });
  });

  group('the chrome holds at every width x text scale', () {
    Future<void> sweep(
      WidgetTester tester,
      Widget Function() build,
      List<Override> overrides,
    ) async {
      for (final width in _widths) {
        for (final scale in _scales) {
          sized(tester, width);
          final captured = <String>[];
          final prior = FlutterError.onError;
          FlutterError.onError = (d) {
            captured.add(d
                .toDiagnosticsNode(style: DiagnosticsTreeStyle.error)
                .toStringDeep());
            prior?.call(d);
          };
          await tester.pumpWidget(_host(build(),
              overrides: overrides, width: width, scale: scale));
          await tester.pumpAndSettle();
          FlutterError.onError = prior;

          // Capture the full FlutterErrorDetails, not just the exception.
          // `takeException()` drops the "relevant error-causing widget" line,
          // which is the only part that says WHERE to fix it — the console
          // sweep learned this and this one had not.
          final failure = tester.takeException();
          if (failure != null) {
            fail('Layout error at width=$width textScale=$scale: $failure\n'
                '${captured.join('\n')}');
          }
        }
      }
    }

    testWidgets('platform', (tester) async {
      await sweep(tester, () => const TargetsPlatformScreen(),
          _overrides([TargetScope.platform]));
    });

    testWidgets('org type', (tester) async {
      await sweep(
        tester,
        () => const TargetsOrgTypeScreen(orgType: TargetOrgType.transporter),
        _overrides([const TargetScope.orgType('transporter')]),
      );
    });

    testWidgets('company', (tester) async {
      await sweep(
        tester,
        () => const TargetsCompanyScreen(companyId: 'c1'),
        _overrides([const TargetScope.company('c1')]),
      );
    });
  });
}

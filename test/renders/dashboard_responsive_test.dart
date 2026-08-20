// The console dashboard is the platform admin's landing screen and the design
// reference the rest of the app is being migrated onto. It renders clean on a
// desktop; it did not on a phone.
//
// The redesign renders reported "4 layout fault(s) at 412x915" and "2 at
// 760x1400" without naming a widget. Resolving them found one shape, four
// times: the "Recently active organizations" table. Its token-expiry column
// (flex 24 of 86, beside a fixed 76px action column) resolves to about 74px at
// 412px and has to hold a status dot, a `42d 08 : 34 : 55` countdown and a
// date. It cannot at any text scale, and the date was unflexed on top of that,
// so it could not even ellipsize (CLAUDE.md §10.4).
//
// Below 720px the table is now a list of cards. These tests hold both ends of
// that: no overflow on a phone, and the table itself still drawn on a desktop.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import '../fixtures/ml_sample_data.dart';
import '../test_helpers/real_fonts.dart';

Widget _dashboard() => MineLinkDashboardScreen(
      orgAggregates: MlSampleData.orgAggregates,
      pendingRequests: MlSampleData.pendingRequests,
      registry: MlSampleData.registry,
      recentOrgs: MlSampleData.recentOrgs,
      // Populated deliberately: the expired banner and the 24h meta line only
      // render when the caller has figures, and an empty screen would not
      // exercise the widest rows.
      newCompanies24h: 2,
      newUsers24h: 14,
      expiredCompanies: 3,
    );

void main() {
  // Real fonts, or the metrics are a fallback font's and every measurement
  // below is fiction (CLAUDE.md §7, §10.5).
  setUpAll(loadRealFonts);

  /// Renders at [width] and returns every layout fault raised while painting.
  Future<List<String>> faultsAt(WidgetTester tester, double width,
      {double scale = 1.0}) async {
    final faults = <String>[];
    final prior = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (s.contains('overflowed') || s.contains('BoxConstraints')) {
        faults.add(s.split('\n').first);
      } else {
        prior?.call(d);
      }
    };
    addTearDown(() => FlutterError.onError = prior);

    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: _dashboard()),
      ),
    ));
    await tester.pump();
    FlutterError.onError = prior;
    return faults;
  }

  group('the dashboard survives a phone', () {
    // 412 is the render harness's phone width; 360 is the narrowest Android
    // phone in common use and the width CLAUDE.md §10.4 keeps naming.
    for (final width in <double>[360, 412, 600, 760]) {
      for (final scale in <double>[1.0, 1.3, 1.6, 2.0]) {
        testWidgets('no layout faults at ${width.toInt()}px / scale $scale',
            (tester) async {
          final faults = await faultsAt(tester, width, scale: scale);
          expect(faults, isEmpty,
              reason: 'layout faults at ${width.toInt()}px x $scale:\n'
                  '${faults.join('\n')}');
        });
      }
    }
  });

  group('the responsive split is a split, not a deletion', () {
    testWidgets('a phone shows the cards and no column headings',
        (tester) async {
      await faultsAt(tester, 412);
      // The table's own headings are gone...
      expect(find.text('COMPANY'), findsNothing);
      // ...but the card's labelled fields carry the same information, and the
      // expiry cell that could not fit as a column now has a heading of its
      // own rather than being dropped.
      expect(find.text('TOKEN EXPIRY'), findsWidgets);
      expect(find.text('SEATS'), findsWidgets);
    });

    testWidgets('a desktop still gets the table', (tester) async {
      await faultsAt(tester, 1400);
      expect(find.text('COMPANY'), findsOneWidget);
      expect(find.text('ORG TYPE'), findsOneWidget);
      expect(find.text('TOKEN EXPIRY'), findsOneWidget);
    });

    testWidgets('every organization survives the change of shape',
        (tester) async {
      final names =
          MlSampleData.recentOrgs.map((o) => o.name).toList(growable: false);

      await faultsAt(tester, 1400);
      for (final n in names) {
        expect(find.text(n), findsOneWidget, reason: '$n missing from table');
      }

      await faultsAt(tester, 412);
      for (final n in names) {
        expect(find.text(n), findsOneWidget, reason: '$n missing from cards');
      }
    });
  });
}

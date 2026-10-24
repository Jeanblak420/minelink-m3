// The company portals on a phone (Jean's go-ahead, 2026-10-24): wide tables
// show one card per row instead of a table to swipe sideways, as the admin
// console's do since the phone audit.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_data_table.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';
import 'package:flutter_application_1/features/portal/screens/tons_out_detail_screen.dart';

import '../../test_helpers/real_fonts.dart';

/// Every `MlDataTable(` / `RawReconView(` construction in [src], with the
/// text up to its matching close paren.
List<String> _constructions(String src, String name) {
  final out = <String>[];
  var i = src.indexOf('$name(');
  while (i >= 0) {
    var depth = 0, j = i + name.length;
    do {
      if (src[j] == '(') depth++;
      if (src[j] == ')') depth--;
      j++;
    } while (depth > 0 && j < src.length);
    out.add(src.substring(i, j));
    i = src.indexOf('$name(', j);
  }
  return out;
}

void main() {
  test('every portal table opts in to cards on a phone', () {
    final files = [
      ...Directory('lib/features/portal').listSync(recursive: true),
      ...Directory('lib/features/fleet').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    final missing = <String>[];
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final name in ['MlDataTable', 'RawReconView']) {
        for (final c in _constructions(src, name)) {
          // The widget's own declaration is not a use.
          if (c.startsWith('RawReconView({')) continue;
          if (!c.contains('cardsOnPhone')) {
            missing.add('${f.path}: ${c.split('\n').first}');
          }
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  group('the tons-out search results', () {
    setUpAll(loadRealFonts);

    final entries = [
      for (final (i, t) in [(0, 30.5), (1, 12.0), (2, 41.25)])
        TonsOutEntry(
          date: DateTime(2026, 10, 20 + i),
          time: '0$i:15',
          transporter: 'AB trans',
          truckReg: 'RT45${i}MP',
          destination: 'Maputo',
          product: 'Coal',
          customer: 'AB buyer',
          netMass: t,
        ),
    ];

    Future<List<String>> pump(WidgetTester tester, double width) async {
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final m = d.exception.toString();
        m.contains('overflowed') ? overflows.add(m.split('\n').first) : previous?.call(d);
      };
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: TonsOutDetailScreen(entries: entries)),
      ));
      await tester.pumpAndSettle();
      FlutterError.onError = previous;
      return overflows;
    }

    testWidgets('phone: cards, no table, and nothing overflows', (tester) async {
      expect(await pump(tester, 360), isEmpty);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('NET MASS'), findsNWidgets(3), reason: 'one per card');
    });

    testWidgets('phone: Sort by still sorts', (tester) async {
      await pump(tester, 360);
      Iterable<double> masses() => tester
          .widgetList<Text>(find.descendant(
              of: find.byType(MlDataTable),
              matching: find.textContaining(RegExp(r'^\d+\.\d+ t$'))))
          .map((t) => double.parse(t.data!.split(' ').first));
      await tester.tap(find.byKey(const ValueKey('tons-out-sort-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Net mass').last);
      await tester.pumpAndSettle();
      expect(masses().toList(), [12.0, 30.5, 41.25]);
      await tester.tap(find.byKey(const ValueKey('tons-out-sort-direction')));
      await tester.pumpAndSettle();
      expect(masses().toList(), [41.25, 30.5, 12.0]);
    });

    testWidgets('desktop: the sortable table as it was', (tester) async {
      await pump(tester, 1400);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byKey(const ValueKey('tons-out-sort-field')), findsNothing);
    });
  });
}

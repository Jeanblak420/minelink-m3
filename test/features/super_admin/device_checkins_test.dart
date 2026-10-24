// The Crash reports page's "Devices" line (Jean's go-ahead, 2026-10-24):
// which devices are checking in, and which have gone quiet, so a quiet crash
// table can be told apart from one that nothing can write to.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/data/models/device_checkin_row.dart';
import 'package:flutter_application_1/features/super_admin/widgets/device_checkins.dart';

import '../../test_helpers/real_fonts.dart';

final _now = DateTime.utc(2026, 10, 24, 10);

DeviceCheckinRow _row(String id, Duration ago, {String? who = 'Eli Mans'}) =>
    DeviceCheckinRow(
      deviceId: id,
      userLabel: who,
      platform: 'android',
      appVersion: '1.0.0',
      firstSeenAt: _now.subtract(const Duration(days: 30)),
      lastSeenAt: _now.subtract(ago),
      checkins: 12,
    );

void main() {
  final rows = [
    _row('a', const Duration(hours: 2)),
    _row('b', const Duration(hours: 23)),
    _row('c', const Duration(days: 2)),
    _row('d', const Duration(days: 5), who: null),
  ];

  test('today is the last 24 hours; quiet is 3 days or more', () {
    final c = deviceCheckinCounts(rows, _now);
    expect(c.today, 2);
    expect(c.quiet, 1);
  });

  test('the line says it in words', () {
    expect(deviceCheckinSummary(rows, _now),
        '2 devices checked in today · 1 quiet for 3+ days');
    expect(deviceCheckinSummary([rows.first], _now),
        '1 device checked in today');
    expect(deviceCheckinSummary(const [], _now),
        'No device has checked in yet.');
  });

  group('the device list', () {
    setUpAll(loadRealFonts);

    Future<List<String>> pump(WidgetTester tester, double width) async {
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final m = d.exception.toString();
        m.contains('overflowed') ? overflows.add(m.split('\n').first) : previous?.call(d);
      };
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: DeviceCheckinList(rows: rows, now: _now)),
      ));
      await tester.pumpAndSettle();
      FlutterError.onError = previous;
      return overflows;
    }

    testWidgets('marks the quiet device, and a device nobody is signed in to',
        (tester) async {
      await pump(tester, 1000);
      expect(find.text('QUIET 5 DAYS'), findsOneWidget);
      expect(find.text('TODAY'), findsNWidgets(2));
      expect(find.text('No one signed in'), findsOneWidget);
    });

    testWidgets('fits a phone', (tester) async {
      expect(await pump(tester, 360), isEmpty);
    });
  });
}

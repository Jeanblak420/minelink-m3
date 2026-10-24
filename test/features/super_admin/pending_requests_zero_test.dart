// Zero is not news (admin phone audit, 2026-10-24): with every request inbox
// empty the dashboard read "Pending requests · NEW · 0 open" over three cards
// each carrying an orange "0" badge and "0 new · Review →".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import '../../fixtures/ml_sample_data.dart';

List<MlPendingRequest> _withCounts(List<int> counts) => [
      for (var i = 0; i < counts.length; i++)
        MlPendingRequest(
          id: MlSampleData.pendingRequests[i].id,
          label: MlSampleData.pendingRequests[i].label,
          icon: MlSampleData.pendingRequests[i].icon,
          count: counts[i],
          sub: MlSampleData.pendingRequests[i].sub,
          tone: MlSampleData.pendingRequests[i].tone,
        ),
    ];

Future<void> _pump(WidgetTester tester, List<int> counts) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: MineLinkDashboardScreen(
        orgAggregates: MlSampleData.orgAggregates,
        pendingRequests: _withCounts(counts),
        registry: MlSampleData.registry,
        recentOrgs: MlSampleData.recentOrgs,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('nothing waiting: no NEW pill, no "0" badges, says so', (tester) async {
    await _pump(tester, [0, 0, 0]);
    expect(find.text('NEW'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('0 open'), findsNothing);
    expect(find.text('Nothing waiting'), findsOneWidget);
    expect(find.text('None waiting · Open →'), findsNWidgets(3));
  });

  testWidgets('one inbox with work: the pill, its badge, the others quiet', (tester) async {
    // The sample registry shows other "2"s; count against the same screen
    // with every inbox empty, so only the badge can make the difference.
    await _pump(tester, [0, 0, 0]);
    final twosWhenEmpty = find.text('2').evaluate().length;
    await _pump(tester, [0, 2, 0]);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('2 open'), findsOneWidget);
    expect(find.text('2').evaluate().length, twosWhenEmpty + 1,
        reason: 'exactly one badge: on the card with work');
    expect(find.text('0'), findsNothing);
    expect(find.text('2 waiting · Review →'), findsOneWidget);
    expect(find.text('None waiting · Open →'), findsNWidgets(2));
  });
}

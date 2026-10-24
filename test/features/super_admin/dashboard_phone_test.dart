// The dashboard on a phone (admin phone audit, 2026-10-24): ~9 screens long,
// with zero-only stat tiles, empty request inboxes and a second copy of the
// Organizations page. Desktop is unchanged (redesign renders).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import '../../fixtures/ml_sample_data.dart';

MlRegistryStat _stat(String id, String label, String value) => MlRegistryStat(
    id: id, label: label, value: value, icon: Icons.circle, tone: MlChipTone.cyan, sub: '');

List<MlPendingRequest> _pending(List<int> counts) => [
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

Future<List<String>> _pump(WidgetTester tester, double width,
    {List<int> counts = const [0, 0, 0]}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: MineLinkDashboardScreen(
        onNavigate: opened.add,
        orgAggregates: MlSampleData.orgAggregates,
        pendingRequests: _pending(counts),
        registry: [
          _stat('orgs.total', 'Total companies', '3'),
          _stat('orgs.expired', 'Expired', '0'),
          _stat('orgs.suspended', 'Suspended', '0'),
          _stat('users.total', 'Total users', '5'),
        ],
        recentOrgs: MlSampleData.recentOrgs,
      ),
    ),
  ));
  await tester.pump();
  return opened;
}

void main() {
  testWidgets('phone: zero tiles fold into one line of chips that still open',
      (tester) async {
    final opened = await _pump(tester, 360);
    expect(find.text('Nothing in:'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Expired'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Suspended'), findsOneWidget);
    expect(find.text('0'), findsNothing, reason: 'a zero tile is still a tile');
    expect(find.text('Total companies'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Expired'));
    await tester.tap(find.widgetWithText(ActionChip, 'Expired'));
    expect(opened, contains('orgs.expired'));
  });

  testWidgets('phone: no request waiting \u2192 no request section', (tester) async {
    await _pump(tester, 360);
    expect(find.text('Pending requests'), findsNothing);
  });

  testWidgets('phone: only the inboxes with work', (tester) async {
    await _pump(tester, 360, counts: [0, 2, 0]);
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('Requested product'), findsOneWidget);
    expect(find.text('Requested routes'), findsNothing);
    expect(find.text('None waiting \u00b7 Open \u2192'), findsNothing);
  });

  testWidgets('desktop is unchanged: every tile, every inbox', (tester) async {
    await _pump(tester, 1400);
    expect(find.text('Nothing in:'), findsNothing);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('None waiting \u00b7 Open \u2192'), findsNWidgets(3));
  });
}

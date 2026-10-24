// "Needs your attention" at the top of the phone dashboard (admin phone
// audit, 2026-10-24): what is waiting, most urgent first, each a tap away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_dashboard_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import '../../fixtures/ml_sample_data.dart';

List<MlAttentionItem> _items({
  int expired = 0, int expiring = 0, int tokens = 0, int mine = 0, int buyer = 0,
  int product = 0, int buyers = 0, int disputes = 0, int waybills = 0,
}) =>
    dashboardAttentionItems(
      expiredCompanies: expired, tokensExpiringSoon: expiring,
      openTokenRequests: tokens, mineTransport: mine, buyerTransport: buyer,
      productRequests: product, buyerRequests: buyers, openDisputes: disputes,
      openWaybills: waybills,
    );

Future<List<String>> _pump(WidgetTester tester, double width,
    List<MlAttentionItem>? attention) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: MineLinkDashboardScreen(
        onNavigate: opened.add,
        attention: attention,
        orgAggregates: MlSampleData.orgAggregates,
        pendingRequests: MlSampleData.pendingRequests,
        registry: MlSampleData.registry,
        recentOrgs: MlSampleData.recentOrgs,
        expiredCompanies: 3,
      ),
    ),
  ));
  await tester.pump();
  return opened;
}

void main() {
  group('which items, in what order', () {
    test('nothing waiting \u2192 nothing listed', () => expect(_items(), isEmpty));

    test('only queues with something in them, most urgent first', () {
      final items = _items(waybills: 15, tokens: 4, expired: 3, mine: 2, buyer: 3, disputes: 1);
      expect(items.map((i) => i.label), [
        'Access expired', 'Open disputes', 'Token requests',
        'Requested routes', 'Open waybills',
      ]);
      expect(items.firstWhere((i) => i.label == 'Requested routes').count, 5,
          reason: 'routes from mines and from buyers are one queue');
    });

    test('every item opens somewhere', () {
      final items = _items(expired: 1, expiring: 1, tokens: 1, mine: 1,
          product: 1, buyers: 1, disputes: 1, waybills: 1);
      for (final i in items) {
        expect(dashboardNavRoute(i.id), isNotNull, reason: i.id);
      }
      expect(dashboardNavRoute('attention.disputes'), '/super-admin/disputes');
    });
  });

  testWidgets('phone: the list comes first and its rows open their screens',
      (tester) async {
    final opened = await _pump(tester, 360, _items(tokens: 4, disputes: 1));
    final head = tester.getTopLeft(find.text('Needs your attention')).dy;
    final orgTypes = tester.getTopLeft(find.text('Live operations by organization type')).dy;
    expect(head, lessThan(orgTypes), reason: 'the list is not first');
    await tester.tap(find.text('Open disputes'));
    expect(opened, ['attention.disputes']);
    // It stands in for the request cards and the expired banner on a phone.
    expect(find.text('Pending requests'), findsNothing);
    expect(find.text('Expired token requests'), findsNothing);
  });

  testWidgets('phone: nothing waiting says so', (tester) async {
    await _pump(tester, 360, const []);
    expect(find.text('All clear'), findsOneWidget);
  });

  testWidgets('desktop: no list, the dashboard as it was', (tester) async {
    await _pump(tester, 1400, _items(tokens: 4));
    expect(find.text('Needs your attention'), findsNothing);
    expect(find.text('Pending requests'), findsOneWidget);
  });
}

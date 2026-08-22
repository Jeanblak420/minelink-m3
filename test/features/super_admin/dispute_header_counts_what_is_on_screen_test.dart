// A header count must describe the list it is a header for.
//
// Found by driving the live console on 2026-08-22. The platform has exactly one
// reconciliation dispute and it is **resolved**, so the screen opened on its
// default Active filter and read:
//
//     Reconciliation disputes                              1 dispute
//     ┌──────────────────────────────────────────────────────────┐
//     │                    No open disputes                      │
//     └──────────────────────────────────────────────────────────┘
//
// The header said one, the body said none, and both were separately correct:
// `meta:` counted the whole list while the body counted the ACTIVE subset. Two
// readers of one list, each applying its own rule.
//
// It cannot be caught by a count-formatting check — "1 dispute" is perfectly
// well-formed English about a real number. The only way to see it is to render
// the screen in the state the data is actually in, which is what this does.
//
// The fix is `visibleDisputes(...)`, read by BOTH the header and the list, so
// they cannot drift again. The second case below is the one that makes this
// test bite on the shape rather than on one string: with the filter turned off
// the same header must go back to naming the total.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/super_admin/screens/dispute_inbox_screen.dart';

import '../../test_helpers/test_supabase.dart';

/// One dispute, resolved — the exact shape production was in when this was
/// found. `DisputeStatus.resolved.isTerminal` is true, so the Active filter
/// hides it and the two counts can disagree.
final _oneResolved = <ReconDispute>[
  ReconDispute(
    id: 'dp-resolved',
    tripId: 't-1',
    transactionId: 'txn-1',
    category: DisputeCategory.weightVariance,
    reason: 'Richards Bay recorded 34.05 t against the mine\'s 34.22 t.',
    status: DisputeStatus.resolved,
    claimedTons: 34.05,
    reference: 'TRP-6120B6A561',
    truckReg: 'S6W001GP',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    transporterName: 'Roadhaul Logistics',
    mineNetTons: 34.22,
    deliveredTons: 34.05,
    variance: -0.17,
    raisedByName: 'Admin',
    commentCount: 1,
    createdAt: DateTime.utc(2026, 8, 15, 21, 37),
    updatedAt: DateTime.utc(2026, 8, 16, 8, 0),
  ),
];

/// Every string the tree draws, TextSpans included.
String _renderedText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join(' | ');

Future<void> _pumpInbox(WidgetTester tester, List<ReconDispute> data) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [reconDisputesProvider.overrideWith((ref, _) async => data)],
      // `theme:`, not a bare MaterialApp — stock Material's type scale is a
      // measurement of text this app never draws
      // (`test-renders-under-the-app-theme`).
      child: MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: const Scaffold(body: DisputeInboxScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(ensureTestSupabaseInitialized);

  testWidgets(
    'the Active filter hiding every dispute leaves a header that says so',
    (tester) async {
      await _pumpInbox(tester, _oneResolved);

      // The state the console was actually in.
      expect(
        find.text('No open disputes'),
        findsOneWidget,
        reason: 'the one dispute is resolved, so Active must hide it',
      );

      // The fault, named directly: the header must not claim a dispute is
      // showing while the body says none is.
      expect(
        find.text('1 dispute'),
        findsNothing,
        reason: '"1 dispute" over "No open disputes" is the whole bug',
      );
      expect(
        find.text('0 open disputes'),
        findsOneWidget,
        reason: 'the header counts what the filter is showing, and says which',
      );
    },
  );

  testWidgets('switching to All puts the total back in the header', (
    tester,
  ) async {
    await _pumpInbox(tester, _oneResolved);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // The resolved dispute is now on screen, so the header naming one is
    // correct here — which is why the first case cannot be satisfied by
    // deleting the count.
    expect(find.text('1 dispute'), findsOneWidget);
    expect(find.text('No open disputes'), findsNothing);
    // Positive evidence the row itself rendered, read off the widget tree
    // rather than off `find.text` — the status chip is a TextSpan, which
    // `find.text` cannot see (CLAUDE.md §5).
    expect(_renderedText(tester), contains('Richards Bay'));
    expect(_renderedText(tester), contains('RESOLVED'));
  });

  testWidgets('an active dispute is counted as open on the Active filter', (
    tester,
  ) async {
    await _pumpInbox(tester, [
      _oneResolved.first,
      ReconDispute(
        id: 'dp-open',
        tripId: 't-2',
        transactionId: 'txn-2',
        category: DisputeCategory.shortDelivery,
        reason: 'Two tons short on arrival.',
        status: DisputeStatus.open,
        commentCount: 0,
        createdAt: DateTime.utc(2026, 8, 20, 6, 0),
        updatedAt: DateTime.utc(2026, 8, 20, 6, 0),
      ),
    ]);

    // One of the two is showing, and the header says one — singular, and
    // scoped to the filter.
    expect(find.text('1 open dispute'), findsOneWidget);
    expect(find.text('2 disputes'), findsNothing);
  });
}

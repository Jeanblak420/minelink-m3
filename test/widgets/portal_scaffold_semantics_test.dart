import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_scaffold.dart';

/// Two things are pinned here.
///
/// 1. The desktop accessibility gap found 2026-07-16: on the WIDE portal
///    layout the sidebar and app bar emitted no semantics nodes, so screen
///    readers could not reach portal navigation (the narrow drawer layout was
///    fine).
/// 2. The rail behaviour introduced by the nav rebuild (P7-03/04/06) — group
///    dropdowns, collapsed-rail flyouts, integer badges and tree-wide search.
void main() {
  final mineTree = portalNavTree(
    orgType: OrgType.mineSupplier,
    role: UserRole.admin,
  );

  Widget shell({
    String selectedRoute = '/portal/mine',
    bool expanded = true,
    Map<PortalNavBadge, int> badges = const {},
    void Function(String route)? onNavigate,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: PortalScaffold(
        nav: mineTree,
        selectedRoute: selectedRoute,
        onNavigate: onNavigate ?? (_) {},
        badgeCounts: badges,
        navLocked: false,
        sidebarExpanded: expanded,
        onSidebarExpandedChanged: (_) {},
        sidebarBrandTitle: 'Iron Hills Mining',
        userName: 'Iron Hills Mining',
        userMeta: 'Mine/Supplier',
        onLogout: () {},
        onNotifications: () {},
        onProfile: () {},
        title: 'Dashboard',
        // Mirror the real app: the body is a nested (go_router ShellRoute)
        // Navigator whose ModalRoute carries BlockSemantics — which drops the
        // semantics of everything painted before it (sidebar, in-body app bar).
        body: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Center(child: Text('page content')),
          ),
        ),
      ),
    );
  }

  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('wide layout exposes sidebar navigation to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    wide(tester);

    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();

    // Groups start CLOSED as of 2026-08-22 (jean), so a leaf nested inside one
    // has to be opened before it is in the tree at all. Opening it here is the
    // point of the check that follows: a destination reachable only through a
    // group must still reach the semantics tree, or it is unreachable to a
    // screen reader.
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();

    // A top-level destination, two group headers, a leaf nested inside the
    // group just opened, and the footer action.
    // 'Logout' is no longer a rail entry. The M3 redesign moved the per-user
    // actions (profile, notifications, appearance, theme, sign out) into the
    // identity flyout at the foot of the rail, which is where the super-admin
    // console has always kept them and which is what "every role follows the
    // console's UX" resolves to here. Sign-out is still one tap from the top
    // bar's overflow as well, so nothing became harder to reach.
    for (final label in [
      'Dashboard',
      'Operations',
      'Logistics',
      'Stockpiles',
      'Iron Hills Mining',
    ]) {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(label))),
        findsWidgets,
        reason: 'sidebar "$label" missing from the semantics tree',
      );
    }

    // The app bar title and the page content must be reachable too.
    expect(find.bySemanticsLabel(RegExp('page content')), findsWidgets);

    semantics.dispose();
  });

  testWidgets('narrow layout still exposes app bar + drawer', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Open navigation menu')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('page content')), findsWidgets);

    semantics.dispose();
  });

  testWidgets('a leaf navigates to its route, not to a tab index', (
    tester,
  ) async {
    wide(tester);
    final taps = <String>[];
    await tester.pumpWidget(shell(onNavigate: taps.add));
    await tester.pumpAndSettle();

    // Production lives inside Operations, which now starts closed.
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Production'));
    await tester.pumpAndSettle();

    expect(taps, ['/portal/mine/production']);
  });

  testWidgets('a group starts closed, then opens and recloses', (tester) async {
    // Reversed on 2026-08-22: groups now START closed, so this walks the whole
    // cycle rather than only the closing half. The behaviour it protects is
    // unchanged — the header is the toggle and it really hides its children.
    wide(tester);
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();

    expect(
      find.text('Quality'),
      findsNothing,
      reason: 'a group whose children are visible before anyone opened it is '
          'the default jean asked to reverse',
    );

    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    expect(find.text('Quality'), findsOneWidget,
        reason: 'the header must open the group it names');

    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    expect(
      find.text('Quality'),
      findsNothing,
      reason: 'closing a group must hide its children',
    );
  });

  testWidgets('the group holding the current route stays open', (tester) async {
    wide(tester);
    await tester.pumpWidget(shell(selectedRoute: '/portal/mine/quality'));
    await tester.pumpAndSettle();

    // Auto-open by route prefix (P7-03): you can always see where you are.
    expect(find.text('Quality'), findsOneWidget);
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    expect(
      find.text('Quality'),
      findsOneWidget,
      reason:
          'the group containing the active route must not close under '
          'you while you are inside it',
    );
  });

  testWidgets('a detail route keeps its parent destination selected', (
    tester,
  ) async {
    wide(tester);
    // Longest-match selection: exact equality would leave every detail page
    // with no highlight at all.
    await tester.pumpWidget(
      shell(selectedRoute: '/portal/mine/trips/abc/waybill'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
  });

  testWidgets('badges render an integer and sum onto the group header', (
    tester,
  ) async {
    wide(tester);
    await tester.pumpWidget(
      shell(
        badges: {
          PortalNavBadge.arrivalsAwaitingCheckIn: 3,
          PortalNavBadge.loadsAwaitingWeigh: 4,
        },
      ),
    );
    await tester.pumpAndSettle();

    // CLOSED, which is now the default — and this is exactly why a shut group
    // sums its children onto its header. With the rail collapsed by default,
    // that sum is often the ONLY thing telling somebody there is work waiting
    // behind the group, so it is asserted before the group is opened.
    expect(find.text('7'), findsOneWidget,
        reason: 'Operations holds both queues; a shut group must carry the sum');
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsNothing);

    // And the individual counts once it is open.
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('an empty queue shows no badge at all', (tester) async {
    wide(tester);
    await tester.pumpWidget(
      shell(badges: {PortalNavBadge.arrivalsAwaitingCheckIn: 0}),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing, reason: 'an empty queue is not news');
  });

  testWidgets('search reaches a leaf nested inside a group', (tester) async {
    wide(tester);
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'quality');
    await tester.pumpAndSettle();

    // The flat list could only ever match top-level labels (P7-06).
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('Production'), findsNothing);
  });

  testWidgets('the collapsed rail opens a group as a flyout', (tester) async {
    wide(tester);
    await tester.pumpWidget(shell(expanded: false));
    await tester.pumpAndSettle();

    // Collapsed: labels are gone, so children are not inline anywhere.
    expect(find.text('Quality'), findsNothing);

    await tester.tap(find.byIcon(Icons.precision_manufacturing_outlined));
    await tester.pumpAndSettle();

    // …until the group's icon opens its overlay (P7-03). Without this a
    // collapsed rail either hides every nested destination or flattens the
    // tree back into the undifferentiated list the rebuild replaces.
    expect(find.text('Quality'), findsOneWidget);
  });
}

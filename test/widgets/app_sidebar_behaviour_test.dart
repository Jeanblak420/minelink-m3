import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_app.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_core.dart';

/// The app rail's behaviour is the part of the drop most likely to rot in a
/// refactor: the lag, the auto-collapse, the section clearing and the forced
/// compact mode are all invisible in a screenshot and none of them are typed.
void main() {
  const user = MlSidebarUser(name: 'jean', email: 'jean@cyberhouse.co.za');

  /// Hosts the rail with the collapsed flag lifted into the harness, the way
  /// the console shell owns it.
  Future<_Host> pump(
    WidgetTester tester, {
    bool collapsed = true,
    Size size = const Size(1400, 1000),
    bool autoCollapseOnNavigate = true,
  }) async {
    final host = _Host(collapsed: collapsed);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              host.rebuild = setState;
              return Row(
                children: [
                  MineLinkAppSidebar(
                    selectedId: host.selected,
                    onSelect: (id) => setState(() => host.selected = id),
                    collapsed: host.collapsed,
                    onCollapsedChanged: (v) =>
                        setState(() => host.collapsed = v),
                    user: user,
                    autoCollapseOnNavigate: autoCollapseOnNavigate,
                  ),
                  const Expanded(child: SizedBox()),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return host;
  }

  double railWidth(WidgetTester tester) =>
      tester.getSize(find.byType(MineLinkAppSidebar)).width;

  group('expand controls', () {
    testWidgets('collapsed shows the expand chevron, expanded shows collapse',
        (tester) async {
      final host = await pump(tester, collapsed: true);

      // Control #2 — chevron-right under the mark.
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
      expect(find.byTooltip('Collapse sidebar'), findsNothing);

      await tester.tap(find.byTooltip('Expand sidebar'));
      await tester.pumpAndSettle();
      expect(host.collapsed, isFalse);

      // Control #1 — chevron-left, top-right of the brand header.
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
      expect(find.byTooltip('Expand sidebar'), findsNothing);
    });

    testWidgets('the bottom bar is a third control and labels itself',
        (tester) async {
      final host = await pump(tester, collapsed: false);
      // Expanded: the bottom bar carries the word.
      expect(find.text('Collapse'), findsOneWidget);

      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      expect(host.collapsed, isTrue);

      // Collapsed: the bar is still there, now unlabelled (chevron flipped).
      expect(find.text('Collapse'), findsNothing);
      expect(find.byType(AnimatedRotation), findsWidgets);
    });

    testWidgets('all three controls hide below the compact breakpoint',
        (tester) async {
      await pump(
        tester,
        collapsed: false,
        size: Size(MlSidebarMetrics.compactBreakpoint - 1, 1000),
      );
      expect(find.byTooltip('Expand sidebar'), findsNothing);
      expect(find.byTooltip('Collapse sidebar'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
    });
  });

  group('forced compact', () {
    testWidgets('below 768 the rail is collapsed even when told to expand',
        (tester) async {
      await pump(
        tester,
        collapsed: false,
        size: Size(MlSidebarMetrics.compactBreakpoint - 1, 1000),
      );
      expect(railWidth(tester), MlSidebarMetrics.collapsedWidth);
      // Labels must not paint in a 68px rail.
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('above 768 the same flags give the full panel', (tester) async {
      await pump(
        tester,
        collapsed: false,
        size: Size(MlSidebarMetrics.compactBreakpoint + 1, 1000),
      );
      expect(railWidth(tester), MlSidebarMetrics.expandedWidth);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });

  group('content lag', () {
    testWidgets('expanding holds the labels back, collapsing drops them at once',
        (tester) async {
      final host = await pump(tester, collapsed: true);
      expect(find.text('Dashboard'), findsNothing);

      // Start expanding.
      host.rebuild(() => host.collapsed = false);
      await tester.pump();

      // Part-way through the width animation the labels must NOT be painting
      // yet — this is the whole point of the lag.
      await tester.pump(MlSidebarMetrics.contentLag ~/ 2);
      expect(
        find.text('Dashboard'),
        findsNothing,
        reason: 'labels painted inside a still-narrow rail',
      );

      // Once the lag elapses they arrive.
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);

      // Collapsing is asymmetric: content goes immediately, no lag.
      host.rebuild(() => host.collapsed = true);
      await tester.pump();
      expect(
        find.text('Dashboard'),
        findsNothing,
        reason: 'content should drop on the same frame when collapsing',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('the lag is two-thirds of the width animation', (tester) async {
      expect(
        MlSidebarMetrics.contentLag.inMilliseconds,
        MlSidebarMetrics.expandDuration.inMilliseconds * 2 ~/ 3,
      );
      expect(MlSidebarMetrics.contentLag.inMilliseconds, 146);
    });
  });

  group('navigation', () {
    testWidgets('auto-collapses after a navigation', (tester) async {
      final host = await pump(tester, collapsed: false);
      expect(host.collapsed, isFalse);

      await tester.tap(find.text('Margin ledger History'));
      await tester.pumpAndSettle();

      expect(host.selected, 'margin-ledger');
      expect(host.collapsed, isTrue, reason: 'rail should close after a jump');
    });

    testWidgets('auto-collapse can be turned off by the host', (tester) async {
      final host =
          await pump(tester, collapsed: false, autoCollapseOnNavigate: false);
      await tester.tap(find.text('Margin ledger History'));
      await tester.pumpAndSettle();

      expect(host.selected, 'margin-ledger');
      expect(host.collapsed, isFalse);
    });
  });

  group('sections', () {
    testWidgets('collapsing clears every open dropdown', (tester) async {
      // Taller than the default harness: with all three groups open the rail
      // is longer than 1000px, and the rail is a ListView, so a row below the
      // fold is not built and cannot be tapped. That is a viewport limit, not
      // the behaviour under test — the real rail scrolls.
      final host =
          await pump(tester, collapsed: false, size: const Size(1400, 1600));

      // Open all three groupings.
      for (final label in ['Insights', 'Tokens & Seats', 'Requests']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(find.text('Transporters'), findsOneWidget);
      expect(find.text('Organizations'), findsOneWidget);
      expect(find.text('Buyer transport'), findsOneWidget);

      // Collapse, then expand again — none should be restored.
      host.rebuild(() => host.collapsed = true);
      await tester.pumpAndSettle();
      host.rebuild(() => host.collapsed = false);
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Transporters'), findsNothing);
      expect(find.text('Organizations'), findsNothing);
      expect(find.text('Buyer transport'), findsNothing);
    });

    testWidgets('the three section headings render as caps, then as rules',
        (tester) async {
      await pump(tester, collapsed: false);
      for (final s in ['CONTROL', 'LEDGERS', 'NETWORK']) {
        expect(find.text(s), findsOneWidget, reason: '$s heading missing');
      }

      // On the rail they become dividers, not text.
      await pump(tester, collapsed: true);
      for (final s in ['CONTROL', 'LEDGERS', 'NETWORK']) {
        expect(find.text(s), findsNothing);
      }
    });

    testWidgets('Settings offers all three of our children', (tester) async {
      await pump(tester, collapsed: false);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Account security'), findsOneWidget);
      expect(find.text('User Preferences'), findsOneWidget);
      expect(find.text('Platform settings'), findsOneWidget);
    });
  });
}

class _Host {
  _Host({required this.collapsed});

  bool collapsed;
  String selected = 'dashboard';
  late void Function(VoidCallback) rebuild;
}

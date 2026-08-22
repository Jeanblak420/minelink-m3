// Every destination in the phone's bottom bar has to be readable, in every
// tree, at the narrowest width this product supports.
//
// `NavigationBar` does not ellipsize — the shell's own comment says so, and it
// was written after "Mine/Supplier transport" wrapped to three lines and
// overlapped both neighbours. The fix at the time was to put the GROUP in the
// bar rather than its first leaf, which shortened most labels and was never
// checked against the trees that are FLAT.
//
// A flat tree has no groups to shorten anything. A mine's Security guard gets
// `Security gate · Incidents & gate checks · Compliance · My profile`, and on a
// 412px phone that renders as two-line labels whose second line is cut off by
// the bottom of the bar, with "Incidents &" running under its neighbour and
// "Security" starting at x=0. Found 2026-08-20 by looking at
// `screen-security-checkin-phone-dark.png`.
//
// None of that raises. A wrapped label inside a fixed-height bar is CLIPPED,
// not overflowed, so the render harness's overflow capture printed nothing and
// every layout sweep passed. Geometry is the only thing that sees it:
// CLAUDE.md §10.4's closing rule — assert on geometry, not on the absence of an
// overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  /// Every tree the product can hand the shell: each org type by each role it
  /// offers, plus the company-account tree (role null), plus the console.
  ///
  /// Enumerated from `UserRole.getRolesForOrgType` rather than listed by hand,
  /// so a role added later is covered without anyone remembering to come here.
  Map<String, List<MlNavNode>> trees() {
    final out = <String, List<MlNavNode>>{};
    for (final org in OrgType.values) {
      out['${org.name} / company account'] =
          portalNavTree(orgType: org, role: null);
      for (final role in UserRole.getRolesForOrgType(org)) {
        out['${org.name} / ${role.name}'] =
            portalNavTree(orgType: org, role: role);
      }
    }
    out['console'] = consoleNavTree();
    return out;
  }

  Future<void> pumpBar(
    WidgetTester tester,
    List<MlNavNode> tree,
    double width,
    double textScale,
    bool boldText,
  ) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
          // The console offers bold text as a reader setting, and it is the
          // difference between fitting and not: measured on 2026-08-22, a
          // 360px phone at scale 1.05 breaks "Dashboard" with bold on and not
          // with it off. Sweeping only the unbolded case would have left that
          // reader unprotected by exactly one setting.
          boldText: boldText,
        ),
        child: MlAppShell(
          tree: tree,
          selectedRoute: tree.first.isGroup
              ? tree.first.leaves.first.route
              : tree.first.route,
          onNavigate: (_) {},
          title: 'Fixture',
          child: const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The labels the bar is ACTUALLY showing, read off the rendered
  /// `NavigationDestination`s.
  ///
  /// It used to mirror `_bottomDestinations` by hand — `tree.take(4)` plus
  /// "More" — and that stopped being true on 2026-08-22, when the bar started
  /// dropping a destination rather than letting a label break in half. A test
  /// that predicts what the widget will draw is testing its own copy of the
  /// widget; this one reads the widget.
  List<String> barLabels(WidgetTester tester) => tester
      .widgetList<NavigationDestination>(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ))
      .map((d) => d.label)
      .toList();

  // 360 is the narrowest phone this product supports. 412 is the width the
  // renders are taken at, and the width the fault was found at — both, because
  // a label can fit one and not the other.
  // 1.3 is the top of `ConsolePrefs.textScale`. A bar whose height is a
  // constant can only be right at one of these.
  // THE BAND BETWEEN 1.0 AND 1.3 WAS NEVER SWEPT, and that is where the fault
  // photographed on a real handset on 2026-08-22 lives. Measured across every
  // tree: the first one-word break at 412px is at 1.2, and at 360px it is at
  // 1.05 with bold text on. Two samples at the ends of a range say nothing
  // about the middle of it — the same shape as the overflow sweep that passed
  // with the fix removed because 1100px, not 360, was the worst width.
  for (final width in const [360.0, 384.0, 412.0]) {
    for (final textScale in const [0.85, 1.0, 1.05, 1.1, 1.15, 1.2, 1.3]) {
     for (final boldText in const [false, true]) {
      testWidgets('no bottom-nav label is clipped or collides at '
          '${width.toInt()}px x $textScale'
          '${boldText ? ' bold' : ''}', (tester) async {
      final problems = <String>[];

      for (final entry in trees().entries) {
        await pumpBar(tester, entry.value, width, textScale, boldText);

        final barFinder = find.byType(NavigationBar);
        expect(barFinder, findsOneWidget,
            reason: '${entry.key}: the shell did not put a bottom bar at '
                '${width.toInt()}px, so this test is measuring nothing.');
        final bar = tester.getRect(barFinder);

        final rects = <String, Rect>{};
        for (final label in barLabels(tester)) {
          final f = find.descendant(
              of: barFinder, matching: find.text(label));
          if (f.evaluate().isEmpty) {
            problems.add('${entry.key}: "$label" is not painted in the bar');
            continue;
          }
          rects[label] = tester.getRect(f.first);
        }

        // "More" is always one word and always fits, so its paragraph height is
        // the one-line reference for this width and text scale — measured from
        // the same render rather than hardcoded from a font metric.
        final oneLine = rects['More']?.height;

        for (final e in rects.entries) {
          // THREE LINES OR MORE. Two is allowed and the bar is sized for it —
          // the alternative is abbreviating "Reconciliation" until it stops
          // naming anything. Three is not: nothing in this product needs it,
          // and the bar cannot hold it. The node gets a `shortLabel`.
          if (oneLine != null && e.value.height > oneLine * 2.4) {
            problems.add('${entry.key}: "${e.key}" needs three or more lines '
                '(${e.value.height.toStringAsFixed(1)}px against a one-line '
                '${oneLine.toStringAsFixed(1)}px) — give the node a '
                'shortLabel');
          }
          // A SINGLE WORD BROKEN IN HALF, at ANY size text is read at.
          //
          // Two lines are allowed above, and the bar is sized for them —
          // because a label like "Loads & value" breaks at its space and both
          // halves are still words. A label with NO space in it has nowhere
          // legitimate to break, so `NavigationBar` breaks it between two
          // letters: at 412px the Reconciliation tab rendered
          //
          //     Reconciliatio
          //     n
          //
          // with the orphaned "n" on the bar's bottom edge. That passes every
          // rule above — two lines, inside the bar, no overlap — and reads as
          // a corrupted string rather than a destination.
          //
          // ## This rule used to be switched off above text scale 1.0
          //
          // The reasoning was sound and the conclusion was wrong. It said that
          // at 1.3 on a 360px phone a 72px slot cannot hold "Dashboard",
          // "Logistics" or "Stockpiles" either, and that the only ways out
          // were abbreviating ordinary English until it stops naming anything,
          // or hiding half the destinations from anyone who turned their type
          // up. Both are worse than a wrapped word, so the rule was limited to
          // 1.0 — and that limit is exactly why a real SM-G780G could show
          //
          //     Dashboar
          //     d
          //
          // to the platform admin on 2026-08-22 with this file green.
          //
          // There was a third way out. The slot is `width / 5` because the bar
          // always showed four destinations plus More, whatever the reader's
          // type size. It now shows as many as FIT (`_bottomDestinations` in
          // `ml_app_shell.dart`): three plus More is 103px a tile at 412, two
          // is 137px, and the destination that steps out is one tap away in
          // the drawer with its badge folded into More's. Nothing is renamed,
          // nothing shrinks, and the rule can hold at every size.
          //
          // 1.4 rather than 2.4: this is "more than one line", not "more than
          // two".
          if (oneLine != null &&
              !e.key.contains(' ') &&
              e.value.height > oneLine * 1.4) {
            problems.add('${entry.key}: "${e.key}" is ONE WORD and does not '
                'fit on one line (${e.value.height.toStringAsFixed(1)}px '
                'against a one-line ${oneLine.toStringAsFixed(1)}px), so it '
                'is broken between two letters. The bar is meant to drop a '
                'destination before this happens — see _bottomDestinations.');
          }
          // CLEARANCE, not merely "inside". At 412px the two-line labels ended
          // 2px from the bottom of the screen: not clipped by a measurement,
          // and unmistakably clipped to look at — descenders sitting on the
          // edge, and on a real handset exactly where the gesture bar is.
          if (e.value.bottom > bar.bottom - 6) {
            problems.add('${entry.key}: "${e.key}" leaves only '
                '${(bar.bottom - e.value.bottom).toStringAsFixed(1)}px under '
                'it inside a ${bar.height.toStringAsFixed(0)}px bar');
          }
          // Off the left or right edge of the screen.
          if (e.value.left < -0.5 || e.value.right > width + 0.5) {
            problems.add('${entry.key}: "${e.key}" is outside the screen '
                '(${e.value.left.toStringAsFixed(1)}'
                '..${e.value.right.toStringAsFixed(1)} of $width)');
          }
        }

        // THE BAR MUST STAY A BAR. Dropping destinations to make labels fit
        // is only a good trade while there is still navigation in it; a bar
        // showing nothing but "More" is a menu button pretending to be one.
        if (rects.length < 3) {
          problems.add('${entry.key}: the bar is down to ${rects.length} '
              'destinations (${rects.keys.join(', ')}) — below two plus More '
              'it has stopped being navigation');
        }

        // Two labels sharing horizontal space. A destination is a tap target;
        // two labels on top of each other means neither names what it hits.
        final ordered = rects.entries.toList()
          ..sort((a, b) => a.value.left.compareTo(b.value.left));
        for (var i = 1; i < ordered.length; i++) {
          final prev = ordered[i - 1], cur = ordered[i];
          if (cur.value.left < prev.value.right - 0.5) {
            problems.add('${entry.key}: "${prev.key}" and "${cur.key}" '
                'overlap by '
                '${(prev.value.right - cur.value.left).toStringAsFixed(1)}px');
          }
        }
      }

      expect(problems, isEmpty,
          reason: 'NavigationBar does not ellipsize, so a label too long for '
              'its slot wraps, and a wrapped label in a fixed-height bar is '
              'CLIPPED rather than overflowed — nothing raises and every sweep '
              'stays green. Give the offending node a `shortLabel`; the full '
              'label stays on its long-press tooltip and in the drawer.\n'
              '  ${problems.join('\n  ')}');
      });
     }
    }
  }

  test('a shortLabel is only worth having if it is actually shorter', () {
    // A `shortLabel` that repeats the label is dead weight that reads, to the
    // next person, as "this one was already considered and is fine".
    final bad = <String>[];
    void walk(String tree, MlNavNode n) {
      if (n.shortLabel != null && n.shortLabel!.length >= n.label.length) {
        bad.add('$tree: "${n.label}" -> "${n.shortLabel}"');
      }
      for (final c in n.children) {
        walk(tree, c);
      }
    }

    for (final entry in trees().entries) {
      for (final n in entry.value) {
        walk(entry.key, n);
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}

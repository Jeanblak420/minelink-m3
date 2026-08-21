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

  /// The labels the bar is showing, in order. Mirrors `_bottomDestinations`.
  List<String> barLabels(List<MlNavNode> tree) =>
      [...tree.take(4).map((n) => n.compactLabel), 'More'];

  // 360 is the narrowest phone this product supports. 412 is the width the
  // renders are taken at, and the width the fault was found at — both, because
  // a label can fit one and not the other.
  // 1.3 is the top of `ConsolePrefs.textScale`. A bar whose height is a
  // constant can only be right at one of these.
  for (final width in const [360.0, 412.0]) {
    for (final textScale in const [1.0, 1.3]) {
      testWidgets('no bottom-nav label is clipped or collides at '
          '${width.toInt()}px x $textScale', (tester) async {
      final problems = <String>[];

      for (final entry in trees().entries) {
        await pumpBar(tester, entry.value, width, textScale);

        final barFinder = find.byType(NavigationBar);
        expect(barFinder, findsOneWidget,
            reason: '${entry.key}: the shell did not put a bottom bar at '
                '${width.toInt()}px, so this test is measuring nothing.');
        final bar = tester.getRect(barFinder);

        final rects = <String, Rect>{};
        for (final label in barLabels(entry.value)) {
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
          // A SINGLE WORD BROKEN IN HALF, at the size text is read at.
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
          // a corrupted string rather than a destination. Found 2026-08-21 in
          // `screen-buyer-waybills-phone-dark.png`, which is the first time
          // anybody had looked at one.
          //
          // **Only at text scale 1.0**, and that is a decision rather than an
          // oversight. Flutter's `NavigationBar` clamps its label scaling at
          // 1.3, so 1.3 is the real ceiling — and at 1.3 on a 360px phone the
          // 72px slot cannot hold "Dashboard", "Logistics" or "Stockpiles" on
          // one line either. The only ways out of that are to abbreviate
          // ordinary English words until they stop naming anything, or to move
          // half the destinations behind "More" for anyone who turned their
          // text up. Both are worse than a word wrapping. The bar is sized for
          // two lines precisely so the large-text case degrades legibly; what
          // this rule protects is the size the product is actually read at.
          //
          // 1.4 rather than 2.4: this is "more than one line", not "more than
          // two".
          if (oneLine != null &&
              textScale == 1.0 &&
              !e.key.contains(' ') &&
              e.value.height > oneLine * 1.4) {
            problems.add('${entry.key}: "${e.key}" is ONE WORD and does not '
                'fit on one line (${e.value.height.toStringAsFixed(1)}px '
                'against a one-line ${oneLine.toStringAsFixed(1)}px), so it '
                'is broken between two letters — give the node a shortLabel');
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

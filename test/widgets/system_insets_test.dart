// Screens that draw their own chrome have to clear the system bars.
//
// `flutter_test` reports a MediaQuery padding of ZERO. Every one of the 240
// renders is therefore taken on a device with no status bar, no gesture pill
// and no notch — so a screen that ignores the inset looks perfect in all of
// them and collides on every real handset.
//
// Run on an Android 14 emulator on 2026-08-21 (1080x2400 @ 420dpi — the same
// 412dp viewport as the phone renders, and the same panel as Jean's SM-G780G),
// the sign-in screen's brand header was drawn UNDER the status bar: the chain
// mark sat on the "5:02", the "M" of MineLink was behind a notification dot,
// and the wordmark ran under the wifi and battery icons. It is the first screen
// of the product, and it had never been seen on a device.
//
// The rule this file holds is narrow and checkable: **a screen that is its own
// Scaffold body, with no AppBar and no SafeArea above it, must not paint
// content in the top inset.** It does not try to police every screen — the two
// shells put an `AppBar` at the top, and an AppBar reserves the inset itself.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_screen.dart';

/// The topmost inked pixel row a paragraph occupies.
double _highestText(WidgetTester tester) {
  var top = double.infinity;
  void walk(RenderObject node) {
    if (node is RenderParagraph &&
        node.hasSize &&
        !node.debugNeedsLayout &&
        node.text.toPlainText().trim().isNotEmpty) {
      final y = node.localToGlobal(Offset.zero).dy;
      if (y < top) top = y;
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return top;
}

Future<void> _pumpSignIn(
  WidgetTester tester, {
  required double statusBar,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(top: statusBar),
          viewPadding: EdgeInsets.only(top: statusBar),
        ),
        child: MineLinkSignInScreen(
          onPasswordSignIn: (_, __, ___) async => null,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // 24 is a plain Android status bar; 48 is a tall one with a cutout. Jean's
  // emulator reports the first.
  for (final statusBar in <double>[24, 48]) {
    testWidgets('the sign-in header clears a ${statusBar.toInt()}dp status bar',
        (tester) async {
      await _pumpSignIn(tester, statusBar: statusBar);

      expect(
        _highestText(tester),
        greaterThanOrEqualTo(statusBar),
        reason: 'the phone header paints text inside the top inset — on a real '
            'device that is under the clock and the status icons, which is '
            'exactly how it shipped until 2026-08-21',
      );
    });
  }

  testWidgets('with NO status bar the header does not float', (tester) async {
    // The inset is added, not baked in: a window with no system bar — the web,
    // a desktop build — must keep the original 20px of breathing room and not
    // grow a gap.
    await _pumpSignIn(tester, statusBar: 0);

    final top = _highestText(tester);
    expect(top, greaterThanOrEqualTo(0));
    expect(
      top,
      lessThan(48),
      reason: 'without a system bar the header should sit where it always did',
    );
  });
}

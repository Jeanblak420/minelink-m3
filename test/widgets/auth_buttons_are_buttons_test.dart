// The sign-in card's two buttons, as assistive technology sees them.
//
// ## Why this file exists
//
// On 2026-08-21 the redesign was driven in a real browser for the first time.
// Flutter web publishes a live accessibility tree, and the sign-in card came
// out like this — on the empty form, which is how every user first meets it:
//
//     button     "Show password"
//     button     "Forgot password?"
//     StaticText "Sign in"                    <- the primary action
//     button     "Sign in with WhatsApp code"
//
// The product's primary action was the one control on the card that was not a
// button. Chasing it turned up three faults, and only the first is visible in
// that tree:
//
//  1. **A disabled button vanished rather than announcing as disabled.**
//     `onPressed` is null until the form validates, so `GestureDetector.onTap`
//     was null, so the node carried no tap action and collapsed to a bare
//     string. A screen-reader user was told the sign-in screen has no sign-in
//     control — rather than that it has one and it is not ready yet, which is
//     the whole message that state exists to send.
//
//  2. **Neither button was a button even when ENABLED.** The browser was being
//     generous: Flutter's web engine maps any tappable node to `role=button`
//     in the DOM, so the ghost button *looked* right in that tree while
//     carrying no `isButton` flag at all. Under `flutter test`, which reads
//     the real semantics, both failed — and so would every platform that
//     infers less than the web does.
//
//  3. **Neither could be reached by keyboard.** A `GestureDetector` takes no
//     focus, so Tab walked email -> password -> Show password -> Forgot
//     password and then past both buttons to the legal links. Enter appeared
//     to work only because the text field's own submit action fires the same
//     callback.
//
// Five of the six tests below failed against the code as it stood.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_theme.dart';

/// [settle] is false for the BUSY case only: that button holds a
/// `CircularProgressIndicator`, which never stops, so `pumpAndSettle` cannot
/// return and times the test out after ten minutes. One frame is enough — the
/// semantics node is built on the first one.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The app's theme, not stock Material's — `test-renders-under-the-app-theme`
      // exists because a bare MaterialApp measures type the product never draws.
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('an ENABLED primary button announces as an enabled button',
      (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, MlPrimaryButton(label: 'Sign in', onPressed: () {}));

    expect(
      t.getSemantics(find.byType(MlPrimaryButton)),
      isSemantics(
        label: 'Sign in',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets(
      'a DISABLED primary button is still a button, marked disabled — this is '
      'the case that was broken, and it is the state the screen opens in',
      (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, const MlPrimaryButton(label: 'Sign in', onPressed: null));

    expect(
      t.getSemantics(find.byType(MlPrimaryButton)),
      isSemantics(
        label: 'Sign in',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
      reason: 'with onPressed null this collapsed to StaticText, so a screen '
          'reader was told the sign-in screen has no sign-in control',
    );
    handle.dispose();
  });

  testWidgets('a BUSY button announces its busy label, not its idle one',
      (t) async {
    final handle = t.ensureSemantics();
    await _pump(
      t,
      MlPrimaryButton(
        label: 'Sign in',
        busyLabel: 'Signing in…',
        busy: true,
        onPressed: () {},
      ),
      settle: false,
    );

    expect(
      t.getSemantics(find.byType(MlPrimaryButton)),
      isSemantics(label: 'Signing in…', isButton: true),
    );
    handle.dispose();
  });

  testWidgets('the ghost button announces as a button in BOTH states',
      (t) async {
    final handle = t.ensureSemantics();

    await _pump(
      t,
      MlGhostButton(label: 'Sign in with WhatsApp code', onPressed: () {}),
    );
    expect(
      t.getSemantics(find.byType(MlGhostButton)),
      isSemantics(
        label: 'Sign in with WhatsApp code',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );

    await _pump(
      t,
      const MlGhostButton(
        label: 'Sign in with WhatsApp code',
        onPressed: null,
      ),
    );
    expect(
      t.getSemantics(find.byType(MlGhostButton)),
      isSemantics(
        label: 'Sign in with WhatsApp code',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('both buttons take keyboard focus and activate on Enter/Space',
      (t) async {
    var primary = 0;
    var ghost = 0;
    await _pump(
      t,
      Column(
        children: [
          MlPrimaryButton(label: 'Sign in', onPressed: () => primary++),
          MlGhostButton(label: 'WhatsApp', onPressed: () => ghost++),
        ],
      ),
    );

    // A GestureDetector takes no focus at all, so before the fix this walked
    // straight past both and neither counter moved.
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(primary, 1, reason: 'the primary button did not take focus');

    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pumpAndSettle();
    expect(ghost, 1, reason: 'the ghost button did not take focus');
  });

  testWidgets('a DISABLED button is skipped by Tab, not focused-and-inert',
      (t) async {
    // A control that definitely takes focus, placed AFTER both buttons. If a
    // disabled button swallowed the first Tab, focus would stop there and this
    // field would never get it — which is what a naive `Focus` wrapper around
    // a disabled control produces.
    final sink = FocusNode(debugLabel: 'sink');
    addTearDown(sink.dispose);

    await _pump(
      t,
      Column(
        children: [
          const MlPrimaryButton(label: 'Sign in', onPressed: null),
          const MlGhostButton(label: 'WhatsApp', onPressed: null),
          TextField(focusNode: sink),
        ],
      ),
    );

    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();

    expect(
      sink.hasFocus,
      isTrue,
      reason: 'Tab must walk past two disabled buttons and land on the next '
          'real control',
    );
  });
}

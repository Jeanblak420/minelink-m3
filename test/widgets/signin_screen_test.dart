// Sign-in screen (2026-08-10 drop) — behaviour and layout.
//
// The screen is deliberately self-contained: no Riverpod, no Supabase, no
// session. Every credential leaves through a callback and comes back as either
// null or the message to show. That makes it testable without any of the auth
// layer, so these tests drive the real widget with stub callbacks.
//
// Two things make the layout half of this meaningful rather than decorative:
//
//  1. It loads the REAL fonts. `flutter test` otherwise renders every glyph one
//     em wide, so text-metric overflows do not reproduce — and phantom ones
//     appear (CLAUDE.md §10.5).
//  2. It sweeps width x text-scale. The four widths are the ones the drop's
//     integration guide names, including 1040 exactly — the brand-panel
//     breakpoint, which is `>=`, so 1040 must still be the wide layout.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_brand.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_fields.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_screen.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_theme.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

Future<void> _loadRealFonts() async {
  await _loadFont('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await _loadFont('JetBrainsMono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
  await _loadFont('Fraunces', [
    'Fraunces-Medium.ttf',
    'Fraunces-MediumItalic.ttf',
    'Fraunces-SemiBold.ttf',
  ]);
}

/// 1040 is the split breakpoint itself; 820 and 380 are the compact layout.
const _widths = <double>[1440, 1040, 820, 380];

/// 1.0 plus both ends of the console's text-size range.
const _scales = <double>[0.85, 1.0, 1.3, 1.6, 2.0];

void main() {
  setUpAll(_loadRealFonts);

  /// Pumps the screen at [width], honouring reduce motion by default.
  ///
  /// Reduce motion matters here beyond accessibility: with it off, the brand
  /// panel's clock repeats forever and `pumpAndSettle` never returns.
  Future<void> pumpScreen(
    WidgetTester tester, {
    double width = 1440,
    double scale = 1.0,
    bool disableAnimations = true,
    Future<String?> Function(String, String, bool)? onPasswordSignIn,
    Future<String?> Function(String)? onRequestWhatsAppCode,
    Future<String?> Function(String, String)? onVerifyWhatsAppCode,
    VoidCallback? onForgotPassword,
    VoidCallback? onSignedIn,
    bool showRemember = false,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        // Inside MaterialApp: its own MediaQuery.fromView would otherwise
        // replace an outer one.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: MineLinkSignInScreen(
          // A fresh key per pump. Without one, pumping the same widget type at
          // the same position UPDATES the existing State rather than replacing
          // it, so a sweep corner that ended in the code view started the next
          // corner already in it — and the button it wanted to tap was gone.
          key: UniqueKey(),
          onPasswordSignIn:
              onPasswordSignIn ?? (_, __, ___) async => 'not wired',
          onRequestWhatsAppCode: onRequestWhatsAppCode,
          onVerifyWhatsAppCode: onVerifyWhatsAppCode,
          onForgotPassword: onForgotPassword,
          onSignedIn: onSignedIn,
          showRemember: showRemember,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A bounded pump, for use once the code view is open.
  ///
  /// `pumpAndSettle` is the wrong tool there: the resend countdown schedules a
  /// `setState` every second for 30 seconds, so settling walks 30 s of fake time
  /// one 100 ms frame at a time — 300 pumps per corner, and the sweep has 24 of
  /// them. Reduce motion is on, so 350 ms is well past every transition here.
  Future<void> nudge(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  TextField identityField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).at(0));
  TextField passwordField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).at(1));
  MlPrimaryButton submitButton(WidgetTester tester) =>
      tester.widget<MlPrimaryButton>(find.byType(MlPrimaryButton));

  // =========================================================================
  // The identity rule
  // =========================================================================

  group('MlIdentityField.read', () {
    test('reads email, phone and neither', () {
      expect(MlIdentityField.read('a@b.co'), MlIdentityKind.email);
      expect(MlIdentityField.read('a@b'), MlIdentityKind.unknown);
      expect(MlIdentityField.read('082 123 4567'), MlIdentityKind.phone);
      expect(MlIdentityField.read('+27821234567'), MlIdentityKind.phone);
      expect(MlIdentityField.read('12345'), MlIdentityKind.unknown);
      expect(MlIdentityField.read(''), MlIdentityKind.unknown);
      expect(MlIdentityField.read('   '), MlIdentityKind.unknown);
    });

    test('accepts other countries only in explicit E.164', () {
      // The form this screen replaces accepted any 6+ digits and handed them to
      // `whatsappToE164`, so refusing every non-SA number would have removed a
      // capability. Requiring the `+` keeps a bare run of digits refused.
      expect(MlIdentityField.read('+44 7911 123456'), MlIdentityKind.phone);
      expect(MlIdentityField.read('+1 415 555 2671'), MlIdentityKind.phone);
      expect(MlIdentityField.read('447911123456'), MlIdentityKind.unknown);
      expect(MlIdentityField.read('123456'), MlIdentityKind.unknown);
      // E.164 tops out at 15 digits.
      expect(MlIdentityField.read('+1234567890123456'), MlIdentityKind.unknown);
    });
  });

  // =========================================================================
  // Submit gating
  // =========================================================================

  testWidgets('submit is disabled until the identity parses and the password '
      'is long enough', (tester) async {
    await pumpScreen(tester);

    expect(submitButton(tester).onPressed, isNull,
        reason: 'empty form must not be submittable');

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull,
        reason: 'identity alone is not enough');

    await tester.enterText(find.byType(TextField).at(1), '12345');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull,
        reason: '5 characters is one short of the 6-character floor');

    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);

    // A half-typed email takes it away again.
    await tester.enterText(find.byType(TextField).at(0), 'user@');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('the field names the credential it read', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.pump();
    expect(find.text('Signing in with email'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '082 123 4567');
    await tester.pump();
    expect(find.text('Signing in with WhatsApp number'), findsOneWidget);
    expect(find.text('Signing in with email'), findsNothing);
  });

  testWidgets('the label uppercases once it floats', (tester) async {
    await pumpScreen(tester);

    // The identity field is autofocused, so it is floated from the start; the
    // password field is empty and unfocused, so it can be seen at rest.
    expect(find.text('EMAIL OR WHATSAPP NUMBER'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('PASSWORD'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), 'hunter42');
    await tester.pump();

    // Floated: the reference applies `text-transform:uppercase` only in that
    // state, which one label string cannot express.
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Password'), findsNothing);

    // And it un-floats again: typing into the password moved focus off an empty
    // identity field, so that label drops back to sentence case.
    expect(find.text('Email or WhatsApp number'), findsOneWidget);
    expect(find.text('EMAIL OR WHATSAPP NUMBER'), findsNothing);
  });

  // =========================================================================
  // Refusal
  // =========================================================================

  testWidgets('a refused password keeps what was typed', (tester) async {
    var calls = 0;
    await pumpScreen(
      tester,
      onPasswordSignIn: (identity, password, remember) async {
        calls++;
        return 'Your password is not correct.';
      },
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter42');
    await tester.pump();
    await tester.tap(find.byType(MlPrimaryButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
    // The server's own wording, not a generic line.
    expect(find.text('Your password is not correct.'), findsOneWidget);
    expect(find.byType(MlBanner), findsOneWidget);
    // The typed value survives. It is NOT selected: on a genuine mistype
    // select-all saves a moment, and on a network failure it would leave a
    // correct password one keystroke from being destroyed.
    final pw = passwordField(tester).controller!;
    expect(pw.text, 'hunter42');
    // The identity is untouched too.
    expect(identityField(tester).controller!.text, 'user@example.com');
  });

  testWidgets('a failure that is NOT the password does not blame the password',
      (tester) async {
    // The screen used to mark the password field red with "Check your password
    // and try again" on EVERY failure. Caught by signing in while the auth
    // service was unreachable: the banner said the password had *not* been
    // rejected while the field beneath it said the opposite — and the red field
    // is the more actionable-looking of the two, so it sends somebody off
    // resetting a password that works.
    await pumpScreen(
      tester,
      onPasswordSignIn: (identity, password, remember) async =>
          'Signing in is taking longer than expected. Check your connection and '
          'try again — your password has not been rejected.',
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'correct-horse');
    await tester.pump();
    await tester.tap(find.byType(MlPrimaryButton));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('your password has not been rejected'),
      findsOneWidget,
      reason: 'the banner carries the real reason',
    );
    expect(
      find.text('Check your password and try again'),
      findsNothing,
      reason: 'nothing on screen may contradict the banner about whose fault '
          'it was',
    );
    // And the correct password is still there, intact and unselected.
    final pw = passwordField(tester).controller!;
    expect(pw.text, 'correct-horse');
    expect(pw.selection.baseOffset == pw.selection.extentOffset, isTrue,
        reason: 'a correct password must not be left selected for overtyping');
  });

  testWidgets('remember defaults to true and reaches the callback',
      (tester) async {
    bool? seen;
    await pumpScreen(
      tester,
      onPasswordSignIn: (identity, password, remember) async {
        seen = remember;
        return 'no';
      },
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter42');
    await tester.pump();
    await tester.tap(find.byType(MlPrimaryButton));
    await tester.pumpAndSettle();

    // The toggle is hidden because MineLink has no session lifetime for it to
    // control, so the value passed must be the behaviour the app actually has:
    // the session persists.
    expect(find.text('Keep me signed in'), findsNothing);
    expect(seen, isTrue);
  });

  // =========================================================================
  // Success
  // =========================================================================

  testWidgets('success shows the overlay, then calls onSignedIn',
      (tester) async {
    var signedIn = 0;
    await pumpScreen(
      tester,
      onPasswordSignIn: (_, __, ___) async => null,
      onSignedIn: () => signedIn++,
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter42');
    await tester.pump();
    await tester.tap(find.byType(MlPrimaryButton));
    await tester.pump();

    expect(find.text('Signed in'), findsOneWidget);
    expect(signedIn, 0, reason: 'navigation waits for the overlay');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(signedIn, 1);
  });

  // =========================================================================
  // WhatsApp path
  // =========================================================================

  testWidgets('the WhatsApp path is absent when the callbacks are null',
      (tester) async {
    await pumpScreen(tester);

    // NB: not `findsNothing` on 'WhatsApp' generally — the identity field is
    // labelled "Email or WhatsApp number" and stays either way. What must
    // disappear is the button and the divider that introduces it.
    expect(find.text('Or sign in with WhatsApp code'), findsNothing);
    expect(find.text('OR'), findsNothing);
    expect(find.byType(MlGhostButton), findsNothing);
  });

  testWidgets('the WhatsApp path is present when the callbacks are supplied',
      (tester) async {
    await pumpScreen(
      tester,
      onRequestWhatsAppCode: (_) async => null,
      onVerifyWhatsAppCode: (_, __) async => null,
    );

    expect(find.text('Or sign in with WhatsApp code'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
  });

  testWidgets('requesting a code without a number refuses and does not call out',
      (tester) async {
    var requests = 0;
    await pumpScreen(
      tester,
      onRequestWhatsAppCode: (_) async {
        requests++;
        return null;
      },
      onVerifyWhatsAppCode: (_, __) async => null,
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.pump();
    await tester.tap(find.text('Or sign in with WhatsApp code'));
    await nudge(tester);

    expect(requests, 0, reason: 'an email is not somewhere to send a code');
    expect(find.byType(MlOtpRow), findsNothing);
    expect(
      find.text(
          'Enter your WhatsApp number first so we know where to send the code'),
      findsOneWidget,
    );
  });

  testWidgets('pasting six digits fills the row and submits', (tester) async {
    String? verified;
    await pumpScreen(
      tester,
      onRequestWhatsAppCode: (_) async => null,
      onVerifyWhatsAppCode: (identity, code) async {
        verified = code;
        return null;
      },
      onSignedIn: () {},
    );

    await tester.enterText(find.byType(TextField).at(0), '082 123 4567');
    await tester.pump();
    await tester.tap(find.text('Or sign in with WhatsApp code'));
    await nudge(tester);

    expect(find.byType(MlOtpRow), findsOneWidget);
    expect(find.text('Resend in 30s'), findsOneWidget);

    // One paste into the first box must land across all six and submit itself.
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await nudge(tester);
    // Verification succeeded, so the success overlay's 900 ms delay is in
    // flight; pump past it or the binding reports a pending timer.
    await tester.pump(const Duration(milliseconds: 1000));

    expect(verified, '123456');
    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      expect(
        tester.widget<TextField>(boxes.at(i)).controller!.text,
        '${i + 1}',
        reason: 'box $i should hold one digit of the pasted code',
      );
    }
  });

  testWidgets('a refused code clears the row but keeps the view',
      (tester) async {
    await pumpScreen(
      tester,
      onRequestWhatsAppCode: (_) async => null,
      onVerifyWhatsAppCode: (_, __) async => 'That code has expired.',
    );

    await tester.enterText(find.byType(TextField).at(0), '082 123 4567');
    await tester.pump();
    await tester.tap(find.text('Or sign in with WhatsApp code'));
    await nudge(tester);

    await tester.enterText(find.byType(TextField).at(0), '123456');
    await nudge(tester);

    expect(find.text('That code has expired.'), findsOneWidget);
    expect(find.byType(MlOtpRow), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(0))
        .controller!.text, '');
  });

  testWidgets('the code view can go back to the password view', (tester) async {
    await pumpScreen(
      tester,
      onRequestWhatsAppCode: (_) async => null,
      onVerifyWhatsAppCode: (_, __) async => null,
    );

    await tester.enterText(find.byType(TextField).at(0), '082 123 4567');
    await tester.pump();
    await tester.tap(find.text('Or sign in with WhatsApp code'));
    await nudge(tester);
    expect(find.byType(MlOtpRow), findsOneWidget);

    await tester.tap(find.text('Use password instead'));
    await nudge(tester);

    expect(find.byType(MlOtpRow), findsNothing);
    // The number typed before switching is still there.
    expect(identityField(tester).controller!.text, '082 123 4567');
  });

  // =========================================================================
  // Motion
  // =========================================================================

  testWidgets('no ticker runs when animations are disabled', (tester) async {
    // The brand panel only renders on the wide layout, so this has to be wide
    // to be testing anything at all.
    await pumpScreen(tester, width: 1440, disableAnimations: true);
    await tester.pumpAndSettle();

    expect(find.byType(MlBrandPanel), findsOneWidget);
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: 'a repeating controller that ignores reduce motion burns a frame '
          'callback forever on a screen people leave open',
    );
  });

  testWidgets('the reduce-motion notice is offered only when motion is off',
      (tester) async {
    await pumpScreen(tester, disableAnimations: true);
    expect(find.byType(MlMotionNotice), findsOneWidget);
    expect(find.text('Animation is switched off on this device'), findsOneWidget);
    expect(find.text('Play anyway'), findsOneWidget);

    await pumpScreen(tester, disableAnimations: false);
    expect(find.byType(MlMotionNotice), findsNothing,
        reason: 'nothing to explain when the panel is already moving');
  });

  testWidgets('Play anyway starts the ambient clock and retires the notice',
      (tester) async {
    await pumpScreen(tester, width: 1440, disableAnimations: true);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);

    await tester.tap(find.text('Play anyway'));
    await tester.pump();

    expect(find.byType(MlMotionNotice), findsNothing,
        reason: 'the override answers the question the card was asking');
    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'the panel must actually start moving');

    // Leave it stopped so the tester does not report a live ticker.
    await pumpScreen(tester, width: 1440, disableAnimations: true);
    await tester.pumpAndSettle();
  });

  testWidgets('dismissing the notice leaves the motion off', (tester) async {
    await pumpScreen(tester, width: 1440, disableAnimations: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byType(MlMotionNotice), findsNothing);
    expect(tester.binding.transientCallbackCount, 0,
        reason: '× is "stop telling me", not "play it"');
  });

  testWidgets('the ambient clock does run when motion is allowed',
      (tester) async {
    await pumpScreen(tester, width: 1440, disableAnimations: false);

    expect(find.byType(MlBrandPanel), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0),
        reason: 'the panel is meant to move for people who allow motion');

    // Leave it stopped, or the tester complains about a pending timer.
    await pumpScreen(tester, width: 1440, disableAnimations: true);
    await tester.pumpAndSettle();
  });

  // =========================================================================
  // Layout
  // =========================================================================

  testWidgets('the wordmark stops growing at 268px', (tester) async {
    final wordmark = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == MlAuth.logoAsset);

    // A full screen. Uncapped 64% would be ~506px here, which is what made the
    // lockup swamp the mark and the headline beneath it.
    await pumpScreen(tester, width: 1920);
    expect(tester.getSize(wordmark).width, closeTo(268, 0.5));

    // Just at the breakpoint the 64% is still the smaller of the two, so the cap
    // must not be what decides it.
    await pumpScreen(tester, width: 1040);
    final narrow = tester.getSize(wordmark).width;
    expect(narrow, lessThan(268));
    expect(narrow, greaterThan(180));
  });

  testWidgets('the brand panel is replaced, not stacked, below 1040',
      (tester) async {
    await pumpScreen(tester, width: 1040);
    expect(find.byType(MlBrandPanel), findsOneWidget,
        reason: '1040 is the boundary and the test is >=');

    await pumpScreen(tester, width: 1039);
    expect(find.byType(MlBrandPanel), findsNothing);
    // Replaced by the compact header, which carries the mark and the name.
    expect(find.text('MineLink Technologies'), findsOneWidget);
    expect(find.text('Mineral logistics, connected'), findsOneWidget);
  });

  bool isLayoutFault(FlutterErrorDetails d) {
    final s = d.exception.toString();
    return s.contains('overflowed') ||
        s.contains('forces an infinite') ||
        s.contains('BoxConstraints');
  }

  /// Runs [body] with `FlutterError.onError` captured, and returns the layout
  /// faults it produced.
  ///
  /// The restore is in a `finally` on purpose. When it was not, a single
  /// unreachable tap threw inside the captured region, `onError` stayed
  /// redirected into a list for the rest of the run, and the binding failed
  /// with "overrode FlutterError.onError but failed to return it" — a message
  /// about the harness that says nothing about the screen.
  Future<List<FlutterErrorDetails>> layoutFaults(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
      tester.takeException();
    }
    return captured.where(isLayoutFault).toList();
  }

  testWidgets('password view: no overflow across width x text scale',
      (tester) async {
    for (final width in _widths) {
      for (final scale in _scales) {
        // showRemember is off in the app, but sweep it on too — the toggle sits
        // in a Row beside "Forgot password?" and that pair is the tightest
        // horizontal run in this view.
        for (final remember in const [false, true]) {
          final faults = await layoutFaults(tester, () async {
            await pumpScreen(
              tester,
              width: width,
              scale: scale,
              showRemember: remember,
              onRequestWhatsAppCode: (_) async => null,
              onVerifyWhatsAppCode: (_, __) async => null,
              onForgotPassword: () {},
              onPasswordSignIn: (_, __, ___) async =>
                  'A refusal, so the banner is on screen at its longest.',
            );
            await tester.enterText(
                find.byType(TextField).at(0), 'someone@example.com');
            await tester.enterText(find.byType(TextField).at(1), 'hunter42');
            await nudge(tester);
            await tester.tap(find.byType(MlPrimaryButton));
            await nudge(tester);
          });

          expect(
            faults,
            isEmpty,
            reason: 'layout fault at width $width, text scale $scale, '
                'showRemember $remember:\n'
                '${faults.map((f) => f.toString()).join('\n\n')}',
          );
        }
      }
    }
  });

  testWidgets('code view: no overflow across width x text scale',
      (tester) async {
    for (final width in _widths) {
      for (final scale in _scales) {
        final faults = await layoutFaults(tester, () async {
          await pumpScreen(
            tester,
            width: width,
            scale: scale,
            onRequestWhatsAppCode: (_) async => null,
            onVerifyWhatsAppCode: (_, __) async =>
                'That code has expired. Ask for a new one.',
          );
          await tester.enterText(find.byType(TextField).at(0), '082 123 4567');
          await tester.pump();
          await tester.tap(find.text('Or sign in with WhatsApp code'),
              warnIfMissed: false);
          await nudge(tester);
          // Six boxes, a banner and the two-label row, all at once.
          await tester.enterText(find.byType(TextField).at(0), '123456');
          await nudge(tester);
        });

        expect(
          faults,
          isEmpty,
          reason: 'layout fault at width $width, text scale $scale:\n'
              '${faults.map((f) => f.toString()).join('\n\n')}',
        );
      }
    }
  });
}

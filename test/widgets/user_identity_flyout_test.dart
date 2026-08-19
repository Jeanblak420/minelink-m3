// The sidebar user chip: hover shows the identity card, click opens the
// profile.
//
// Before this, the chip was decorative on three of the four console skins —
// no tap target, no way to reach the signed-in account from it at all. The
// classic rail navigated but offered only a Tooltip carrying the words
// "Profile & settings", so the signed-in address was never legible anywhere
// once the chip had ellipsised it.
//
// Real fonts are loaded because these assertions are about layout (§7): under
// the test fallback font every glyph is one em wide, so a mono email at
// fontSize 10.5 measures roughly double its real width and the card's own
// max-width would report overflows that do not exist in the app.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';

import '../test_helpers/real_fonts.dart';

const _user = UserIdentity(
  name: 'jean',
  email: 'jean@cyberhouse.co.za',
  roleLabel: 'Super Admin',
);

/// The chip as the App-nav skin draws it: avatar, name, mono email, trailing
/// online dot. Narrow enough that the email genuinely ellipsises, which is the
/// case the card exists for.
Widget _chip() => const SizedBox(
      width: 240,
      child: Row(
        children: [
          SizedBox(width: 32, height: 32),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('jean', maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('jean@cyberhouse.co.za',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onOpenProfile,
  List<UserIdentityAction> actions = const <UserIdentityAction>[],
  double textScale = 1.0,
  bool boldText = false,
  bool reduceMotion = false,
  Size size = const Size(1280, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            boldText: boldText,
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            // Bottom-left, the way every rail places it — the card has to grow
            // upward from there rather than off the bottom of the window.
            body: Align(
              alignment: Alignment.bottomLeft,
              child: UserIdentityFlyout(
                user: _user,
                onOpenProfile: onOpenProfile,
                actions: actions,
                child: _chip(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Moves a real mouse onto the chip and waits out the open delay.
Future<TestGesture> _hoverChip(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(find.byType(UserIdentityFlyout)));
  await tester.pump();
  // Open delay is 120ms; give it room and let the overlay build.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  setUpAll(loadRealFonts);

  group('hover', () {
    testWidgets('shows the identity card', (tester) async {
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
            icon: Icons.shield_outlined,
            label: 'Profile & account security',
            onTap: () {}),
      ]);

      expect(find.byType(UserIdentityCard), findsNothing,
          reason: 'the card must not be in the tree before a hover');

      await _hoverChip(tester);

      expect(find.byType(UserIdentityCard), findsOneWidget);
      expect(find.text('Profile & account security'), findsOneWidget);
      expect(find.text('SUPER ADMIN'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
    });

    testWidgets('prints the whole address the chip had to ellipsise',
        (tester) async {
      await _pump(tester, onOpenProfile: () {});
      await _hoverChip(tester);

      // Two now: the chip's truncated copy and the card's full one. The card's
      // is the point of the feature.
      final inCard = find.descendant(
        of: find.byType(UserIdentityCard),
        matching: find.text('jean@cyberhouse.co.za'),
      );
      expect(inCard, findsOneWidget);

      final text = tester.widget<Text>(inCard);
      expect(text.maxLines, 2,
          reason: 'the card wraps the address rather than truncating it again');
    });

    testWidgets('closes when the pointer leaves both chip and card',
        (tester) async {
      await _pump(tester, onOpenProfile: () {});
      final gesture = await _hoverChip(tester);
      expect(find.byType(UserIdentityCard), findsOneWidget);

      await gesture.moveTo(const Offset(1200, 40));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(UserIdentityCard), findsNothing);
    });

    testWidgets('stays open while the pointer is on the card itself',
        (tester) async {
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
            icon: Icons.tune_rounded, label: 'User preferences', onTap: () {}),
      ]);
      final gesture = await _hoverChip(tester);

      // Cross onto the panel. If the anchor's exit closed it unconditionally
      // the card would be unreachable with a mouse and its rows unclickable.
      await gesture.moveTo(tester.getCenter(find.byType(UserIdentityCard)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(UserIdentityCard), findsOneWidget);
    });

    testWidgets('an identity-only chip with no email and no actions '
        'opens nothing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: UserIdentityFlyout(
                user: const UserIdentity(name: 'jean', email: ''),
                onOpenProfile: () {},
                child: _chip(),
              ),
            ),
          ),
        ),
      );
      await _hoverChip(tester);
      expect(find.byType(UserIdentityCard), findsNothing,
          reason: 'an empty card is worse than no card');
    });
  });

  group('click', () {
    testWidgets('opens the profile', (tester) async {
      var opened = 0;
      await _pump(tester, onOpenProfile: () => opened++);

      await tester.tap(find.byType(UserIdentityFlyout));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('dismisses the card first, so it cannot outlive the route',
        (tester) async {
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
            icon: Icons.tune_rounded, label: 'User preferences', onTap: () {}),
      ]);
      await _hoverChip(tester);
      expect(find.byType(UserIdentityCard), findsOneWidget);

      await tester.tap(find.byType(UserIdentityFlyout));
      await tester.pumpAndSettle();

      expect(find.byType(UserIdentityCard), findsNothing);
    });

    testWidgets('a card row fires its action and closes the card',
        (tester) async {
      var preferences = 0;
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
          icon: Icons.tune_rounded,
          label: 'User preferences',
          onTap: () => preferences++,
        ),
      ]);
      await _hoverChip(tester);

      await tester.tap(find.text('User preferences'));
      await tester.pumpAndSettle();

      expect(preferences, 1);
      expect(find.byType(UserIdentityCard), findsNothing);
    });

    testWidgets('long-press opens the card on a touch device', (tester) async {
      // Phones never hover, so without this the card is unreachable there.
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
            icon: Icons.tune_rounded, label: 'User preferences', onTap: () {}),
      ], size: const Size(420, 860));

      await tester.longPress(find.byType(UserIdentityFlyout));
      await tester.pumpAndSettle();

      expect(find.byType(UserIdentityCard), findsOneWidget);
    });
  });

  group('layout', () {
    // The console lets each admin set a text scale of 0.85–1.3 and bold text.
    // A card that fits at 1.0 and not at 1.3 is broken for whoever moved the
    // slider — which is the only reason the slider's own screen exists.
    for (final scale in <double>[0.85, 1.0, 1.15, 1.3]) {
      testWidgets('survives text scale $scale, bold, reduce-motion',
          (tester) async {
        await _pump(
          tester,
          onOpenProfile: () {},
          textScale: scale,
          boldText: true,
          reduceMotion: true,
          actions: [
            UserIdentityAction(
                icon: Icons.shield_outlined,
                label: 'Profile & account security',
                onTap: () {}),
            UserIdentityAction(
                icon: Icons.tune_rounded,
                label: 'User preferences',
                onTap: () {}),
            UserIdentityAction(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                onTap: () {},
                danger: true),
          ],
        );
        await _hoverChip(tester);

        expect(find.byType(UserIdentityCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('grows upward, so it never runs off the bottom of the window',
        (tester) async {
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
            icon: Icons.shield_outlined,
            label: 'Profile & account security',
            onTap: () {}),
        UserIdentityAction(
            icon: Icons.tune_rounded, label: 'User preferences', onTap: () {}),
        UserIdentityAction(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            onTap: () {},
            danger: true),
      ]);
      await _hoverChip(tester);

      final chip = tester.getRect(find.byType(UserIdentityFlyout));
      final card = tester.getRect(find.byType(UserIdentityCard));

      // Anchored bottom-to-bottom: the card's floor sits on the chip's floor
      // and its body extends up. Anchoring by centre — which is what the
      // rail's own MlFlyout does for submenus — would put half of this card
      // below the bottom edge of an 800px window.
      expect(card.bottom, closeTo(chip.bottom, 1));
      expect(card.top, lessThan(chip.top));
      expect(card.bottom, lessThanOrEqualTo(800));

      // And it clears the rail rather than sitting on top of it.
      expect(card.left, greaterThanOrEqualTo(chip.right));
    });

    testWidgets('the card keeps its own width bounds', (tester) async {
      await _pump(tester, onOpenProfile: () {}, actions: [
        UserIdentityAction(
            icon: Icons.shield_outlined,
            label: 'Profile & account security',
            onTap: () {}),
      ]);
      await _hoverChip(tester);

      final card = tester.getRect(find.byType(UserIdentityCard));
      expect(card.width, greaterThanOrEqualTo(244));
      expect(card.width, lessThanOrEqualTo(312));
    });
  });

  group('accessibility', () {
    testWidgets('the chip announces itself as a button naming the person',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, onOpenProfile: () {});

      expect(
        find.bySemanticsLabel('jean, jean@cyberhouse.co.za'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an inert chip is not announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      final node = tester.getSemantics(
        find.bySemanticsLabel('jean, jean@cyberhouse.co.za'),
      );
      expect(node.flagsCollection.isButton, isFalse);
      handle.dispose();
    });
  });

  group('tokens', () {
    testWidgets('the card takes its accent from the caller, not a literal',
        (tester) async {
      // Each console skin passes its own accent (the Haul skin is gold, the
      // rest follow the admin's chosen colour). A hardcoded cyan card would
      // look foreign in three of the five surfaces.
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: UserIdentityFlyout(
                user: _user,
                accent: MlTokens.orange500,
                onOpenProfile: () {},
                actions: [
                  UserIdentityAction(
                      icon: Icons.tune_rounded,
                      label: 'User preferences',
                      onTap: () {}),
                ],
                child: _chip(),
              ),
            ),
          ),
        ),
      );
      await _hoverChip(tester);

      final card = tester.widget<UserIdentityCard>(
        find.byType(UserIdentityCard),
      );
      expect(card.accent, MlTokens.orange500);
    });
  });
}

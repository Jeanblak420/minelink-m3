// The user chip, in the real rails rather than in a harness of its own.
//
// `user_identity_flyout_test.dart` proves the flyout works. It does NOT prove
// any rail actually uses it — and three of the four console skins carried a
// chip that was pure decoration, so "the widget works" and "you can reach your
// profile" were separate facts. This file pumps each real skin and drives the
// chip the way a person does.
//
// Every skin is exercised at both rail widths, because the collapsed rail
// draws a different chip (avatar only) through a different branch, and that
// branch is the easier one to forget to wrap.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_app.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_haul.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_weighbridge.dart';

import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  late int profileOpened;
  late int preferencesOpened;
  late int signedOut;

  setUp(() {
    profileOpened = 0;
    preferencesOpened = 0;
    signedOut = 0;
  });

  /// The user exactly as `console_sidebar_bridge.dart` builds it.
  MlSidebarUser wiredUser() => MlSidebarUser(
        name: 'jean',
        email: 'jean@cyberhouse.co.za',
        roleLabel: 'Super Admin',
        onOpenProfile: () => profileOpened++,
        actions: [
          UserIdentityAction(
            icon: Icons.shield_outlined,
            label: 'Profile & account security',
            onTap: () => profileOpened++,
          ),
          UserIdentityAction(
            icon: Icons.tune_rounded,
            label: 'User preferences',
            onTap: () => preferencesOpened++,
          ),
          UserIdentityAction(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            onTap: () => signedOut++,
            danger: true,
          ),
        ],
      );

  Future<void> pumpRail(WidgetTester tester, Widget rail) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Row(
            children: [rail, const Expanded(child: SizedBox())],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Hovers the rail's own footer chip — found by the flyout the rail wrapped
  /// it in, which is the thing under test.
  ///
  /// Pass [reuse] to hover again in the same test. A second `addPointer` while
  /// the first is still registered trips a MouseTracker assertion, so there is
  /// exactly one mouse per test.
  Future<TestGesture> hoverChip(WidgetTester tester,
      {TestGesture? reuse}) async {
    final chip = find.byType(UserIdentityFlyout);
    expect(chip, findsOneWidget,
        reason: 'this rail never wrapped its footer chip at all');

    final TestGesture gesture;
    if (reuse != null) {
      gesture = reuse;
    } else {
      gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
    }
    await gesture.moveTo(tester.getCenter(chip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    return gesture;
  }

  /// A row *inside the card*. Every rail already draws its own "Sign out"
  /// control a few pixels away, so an unscoped `find.text` matches two widgets
  /// and taps neither.
  Finder cardRow(String label) => find.descendant(
        of: find.byType(UserIdentityCard),
        matching: find.text(label),
      );

  final skins = <String, Widget Function(MlSidebarUser, bool)>{
    'App nav': (user, collapsed) => MineLinkAppSidebar(
          selectedId: 'dashboard',
          onSelect: (_) {},
          collapsed: collapsed,
          onCollapsedChanged: (_) {},
          user: user,
        ),
    'Haul': (user, collapsed) => HaulSidebar(
          selectedId: 'dashboard',
          onSelect: (_) {},
          collapsed: collapsed,
          onCollapsedChanged: (_) {},
          user: user,
        ),
    'Weighbridge': (user, collapsed) => WeighbridgeSidebar(
          selectedId: 'dashboard',
          onSelect: (_) {},
          collapsed: collapsed,
          onCollapsedChanged: (_) {},
          user: user,
        ),
  };

  for (final entry in skins.entries) {
    final skin = entry.key;
    final build = entry.value;

    group(skin, () {
      testWidgets('expanded: hover opens the card, click opens the profile',
          (tester) async {
        await pumpRail(tester, build(wiredUser(), false));

        expect(find.byType(UserIdentityCard), findsNothing);
        await hoverChip(tester);
        expect(find.byType(UserIdentityCard), findsOneWidget);
        expect(cardRow('Profile & account security'), findsOneWidget);
        expect(cardRow('SUPER ADMIN'), findsOneWidget);

        await tester.tap(find.byType(UserIdentityFlyout));
        await tester.pumpAndSettle();
        expect(profileOpened, 1);
      });

      testWidgets('collapsed: the avatar-only chip works the same',
          (tester) async {
        await pumpRail(tester, build(wiredUser(), true));

        await hoverChip(tester);
        expect(find.byType(UserIdentityCard), findsOneWidget,
            reason: 'the collapsed branch draws a different chip and is the '
                'one most easily left unwrapped');

        await tester.tap(find.byType(UserIdentityFlyout));
        await tester.pumpAndSettle();
        expect(profileOpened, 1);
      });

      testWidgets('every card row reaches its destination', (tester) async {
        await pumpRail(tester, build(wiredUser(), false));
        final mouse = await hoverChip(tester);

        await tester.tap(cardRow('User preferences'));
        await tester.pumpAndSettle();
        expect(preferencesOpened, 1);

        // Off the chip and back, so the card genuinely reopens rather than
        // the row being tapped on a stale overlay.
        await mouse.moveTo(const Offset(1200, 40));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        await hoverChip(tester, reuse: mouse);
        await tester.tap(cardRow('Sign out'));
        await tester.pumpAndSettle();
        expect(signedOut, 1);
      });

      testWidgets('an unwired user leaves the chip exactly as the drop drew it',
          (tester) async {
        // The drop ships its own previews with a bare MlSidebarUser. Those
        // must keep building, and must not sprout a hover card with nothing
        // in it.
        await pumpRail(
          tester,
          build(
            const MlSidebarUser(name: 'jean', email: 'jean@cyberhouse.co.za'),
            false,
          ),
        );
        expect(find.byType(UserIdentityFlyout), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

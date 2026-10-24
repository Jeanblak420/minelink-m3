// Tap targets on a phone are at least 48px (admin phone audit, 2026-10-24):
// the chat window's corner buttons were 31px, the registry's page arrows 34px
// and the targets' − / + 26px. Desktop keeps its sizes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_management_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_org_type_screen.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../fixtures/shared_tail_fixtures.dart';
import '../../test_helpers/frozen_clock.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pumpScreen(WidgetTester tester, double width, Widget screen) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...companyScopeOverrides(),
      ...consoleCaptureOverrides(),
      ...portalCaptureOverrides(),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: screen)),
  ));
  await _settle(tester);
}

/// The size of the tappable box behind each tooltip [message].
List<Size> _targets(WidgetTester tester, String message) => [
      for (final e in find.byTooltip(message).evaluate())
        tester.getSize(find.descendant(
                of: find.byWidget(e.widget), matching: find.byType(InkWell))
            .first),
    ];

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://localhost:54321', anonKey: 'tap-targets');
  });

  for (final (width, min) in [(360.0, 48.0), (1280.0, 0.0)]) {
    final where = width < 600 ? 'phone' : 'desktop';

    testWidgets('$where: registry page arrows', (tester) async {
      await _pumpScreen(tester, width, const OrganizationManagementScreen());
      final arrows = [
        for (final icon in [Icons.chevron_left_rounded, Icons.chevron_right_rounded])
          // The button is the SMALLEST Container around the icon.
          (find.ancestor(of: find.byIcon(icon), matching: find.byType(Container))
                  .evaluate()
                  .map((e) => tester.getSize(find.byWidget(e.widget).first))
                  .toList()
                ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height)))
              .first,
      ];
      for (final s in arrows) {
        if (where == 'phone') {
          expect(s.width, greaterThanOrEqualTo(min));
          expect(s.height, greaterThanOrEqualTo(min));
        } else {
          expect(s.width, 34, reason: 'desktop size changed');
        }
      }
    });

    testWidgets('$where: targets \u2212 / +', (tester) async {
      await _pumpScreen(tester, width,
          const TargetsOrgTypeScreen(orgType: TargetOrgType.transporter));
      for (final tip in ['Decrease', 'Increase']) {
        final box = tester.getSize(find.descendant(
                of: find.byTooltip(tip).first, matching: find.byType(Container))
            .first);
        if (where == 'phone') {
          expect(box.width, greaterThanOrEqualTo(min), reason: tip);
          expect(box.height, greaterThanOrEqualTo(min), reason: tip);
        } else {
          expect(box.width, 26, reason: 'desktop size changed');
        }
      }
    });

    testWidgets('$where: chat window buttons', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
          chatDeliveryProvider.overrideWithValue(null),
          chatConversationsProvider.overrideWith((ref) => Stream.value(kConversations)),
          chatContactsProvider.overrideWith((ref) async => kChatContacts),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: ChatDock(
            launcherInAppBarOnPhone: true,
            child: Scaffold(
              appBar: AppBar(actions: const [ChatDockAppBarButton()]),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ));
      await _settle(tester);
      if (where == 'phone') {
        await tester.tap(find.byKey(const ValueKey('chat-dock-appbar-launcher')));
      } else {
        await tester.tap(find.byKey(const ValueKey('chat-dock-launcher')));
      }
      await _settle(tester);
      for (final tip in ['Minimize', 'Close']) {
        final sizes = _targets(tester, tip);
        expect(sizes, isNotEmpty, reason: '$tip not found');
        for (final s in sizes) {
          if (where == 'phone') {
            expect(s.width, greaterThanOrEqualTo(min), reason: tip);
            expect(s.height, greaterThanOrEqualTo(min), reason: tip);
          } else {
            expect(s.width, 31, reason: 'desktop size changed');
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

// The company portals on a phone (Jean's go-ahead, 2026-10-24): chat opens
// from the top bar like the admin console's, not from a disc floating over
// the page. To keep the bar at four icons — a fifth would push every page
// title onto its own row — "Take a tour" moves into More on a phone.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/notifications/widgets/animated_notification_bell.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_shell_layout.dart';

void main() {
  late BuildContext ctx;

  Future<void> grabContext(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
  }

  List<Widget> actions({required bool phone, bool tourSeen = true}) =>
      portalShellActions(
        phone: phone,
        waitingForRole: false,
        tourSeen: tourSeen,
        darkTheme: true,
        onTour: () {},
        onMenu: (_) {},
      );

  List<String> menuValues(Widget more) {
    final items = (more as PopupMenuButton<String>).itemBuilder(ctx);
    return [for (final i in items) (i as PopupMenuItem<String>).value!];
  }

  testWidgets('phone: chat first, tour in More, still four icons',
      (tester) async {
    await grabContext(tester);
    final a = actions(phone: true);
    expect(a.first, isA<ChatDockAppBarButton>());
    expect(a.whereType<IconButton>(), isEmpty, reason: 'the tour button');
    expect(a, hasLength(4));
    expect(menuValues(a.last), contains('tour'));
  });

  testWidgets('phone: an unseen tour still shows its dot, on More',
      (tester) async {
    await grabContext(tester);
    final more = actions(phone: true, tourSeen: false).last as PopupMenuButton<String>;
    expect(more.icon, isA<Badge>());
  });

  testWidgets('desktop: the bar is as it was', (tester) async {
    await grabContext(tester);
    final a = actions(phone: false);
    expect(a.whereType<IconButton>(), hasLength(1), reason: 'the tour button');
    expect(a.whereType<AnimatedNotificationBell>(), hasLength(1));
    expect(menuValues(a.last), isNot(contains('tour')));
  });

  test('the portal shell opts its dock in and uses these actions', () {
    final src =
        File('lib/features/portal/widgets/portal_shell_layout.dart').readAsStringSync();
    expect(src, contains('ChatDock(launcherInAppBarOnPhone: true, child: content)'));
    expect(src, contains('actions: portalShellActions('));
  });
}

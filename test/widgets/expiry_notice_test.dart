// The restricted-company explanation layer.
//
// Token expiry became enforceable in the database on 2026-08-15 (migration
// 20260815094000): an expired company's writes are refused by row-level
// security. Correct — but until this layer existed the block was SILENT. A
// write failed with an RLS error and nothing on screen said a lapsed token
// caused it, that reading and messaging MineLink still worked, or that renewing
// was the fix. These tests pin the explanation, not the enforcement; RLS is the
// boundary and holds with or without any of this.
//
// Real fonts loaded (CLAUDE.md §7). One brightness per test — pumping two into
// one test lets the element short-circuit and reports the first theme's ink for
// both, which has already impersonated a hardcoded-colour bug on this suite.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_expiry_notice.dart';
import 'package:flutter_application_1/core/design/components/ml_locked_action.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/company_access.dart';

CompanyAccess _access({
  required String status,
  bool isActive = false,
  DateTime? expiresAt,
  int? daysSince,
}) =>
    CompanyAccess(
      isActive: isActive,
      isPlatformAdmin: false,
      companyId: 'c1',
      companyName: 'SteelWorks SA',
      orgType: 'buyer',
      status: status,
      tokenExpiresAt: expiresAt,
      daysSinceExpiry: daysSince,
    );

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

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 900,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SizedBox(width: width, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
      'PlusJakartaSans-ExtraBold.ttf',
    ]);
    await _loadFont('JetBrainsMono', ['JetBrainsMono-Regular.ttf']);
    await _loadFont(
        'Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
  });

  group('what the copy actually says', () {
    test('an expired company is told the date, the age, and what still works',
        () {
      final a = _access(
        status: 'expired',
        expiresAt: DateTime.utc(2026, 4, 23),
        daysSince: 113,
      );
      expect(a.headline, 'Your MineLink token has expired');
      expect(a.explanation, contains('23 April 2026'));
      expect(a.explanation, contains('113 days ago'));
      // Leads with what is still possible — a notice that only lists refusals
      // produces the support call it should have prevented.
      expect(a.explanation, contains('view your records'));
      expect(a.explanation, contains('message MineLink'));
      expect(a.explanation, contains('request a renewal'));
      expect(a.explanation, contains('log a support ticket'));
    });

    test('a never-activated company is told to activate, not to renew', () {
      final a = _access(status: 'pendingActivation');
      expect(a.headline, contains('not active yet'));
      expect(a.explanation, contains('has not been activated'));
      // Telling somebody to renew something they never had is the kind of
      // small wrongness that makes a product feel untrustworthy.
      expect(a.explanation.toLowerCase(), isNot(contains('renew')));
    });

    test('a suspended company is pointed at MineLink, not at self-service', () {
      final a = _access(status: 'suspended');
      expect(a.headline, contains('suspended'));
      expect(a.explanation, contains('Message MineLink'));
    });

    test('an active company is not restricted and says nothing', () {
      final a = _access(status: 'active', isActive: true);
      expect(a.isRestricted, isFalse);
    });

    test('a platform admin is never restricted', () {
      const a = CompanyAccess(
          isActive: false, isPlatformAdmin: true, companyId: 'c1');
      expect(a.isRestricted, isFalse);
    });
  });

  testWidgets('the notice renders nothing for an active company',
      (tester) async {
    await _pump(tester,
        MlExpiryNotice(access: _access(status: 'active', isActive: true)));
    expect(find.byType(MlExpiryNotice), findsOneWidget);
    expect(find.textContaining('expired'), findsNothing);
  });

  testWidgets('the notice shows the headline, the reason and both routes out',
      (tester) async {
    var renew = 0, message = 0;
    await _pump(
      tester,
      MlExpiryNotice(
        access: _access(
            status: 'expired',
            expiresAt: DateTime.utc(2026, 4, 23),
            daysSince: 113),
        onRequestRenewal: () => renew++,
        onMessageMineLink: () => message++,
      ),
    );
    expect(find.text('Your MineLink token has expired'), findsOneWidget);
    expect(find.textContaining('23 April 2026'), findsOneWidget);

    await tester.tap(find.text('Request renewal'));
    await tester.tap(find.text('Message MineLink'));
    await tester.pump();
    expect(renew, 1);
    expect(message, 1);
  });

  testWidgets('a pending company is offered activation, not renewal',
      (tester) async {
    await _pump(
      tester,
      MlExpiryNotice(
        access: _access(status: 'pendingActivation'),
        onRequestRenewal: () {},
      ),
    );
    expect(find.text('Request activation'), findsOneWidget);
    expect(find.text('Request renewal'), findsNothing);
  });

  testWidgets('expiry is warn-toned, suspension is error-toned',
      (tester) async {
    // The semantic decision, pinned. An expired token is a billing state the
    // customer can fix themselves, not a fault — painting it red would
    // misrepresent a routine commercial event as a system failure. Suspension
    // is the one they cannot lift alone.
    final warn = MlTone.warn.colors(Brightness.dark).fg;
    final error = MlTone.error.colors(Brightness.dark).fg;
    expect(warn, isNot(error));

    // The accent rule is a Positioned DecoratedBox, not a Container — a
    // stretched Row child threw "BoxConstraints forces an infinite height"
    // inside the scroll view the notice actually lives in (CLAUDE.md §10.4).
    // Matches on either, so the assertion survives that kind of restructuring.
    bool paintsWith(WidgetTester t, Color c) => t
        .widgetList<Widget>(find.byWidgetPredicate((w) =>
            w is Container || w is DecoratedBox))
        .any((w) {
      final d = w is Container ? w.decoration : (w as DecoratedBox).decoration;
      return (d is BoxDecoration) && d.color == c;
    });

    await _pump(tester, MlExpiryNotice(access: _access(status: 'expired')));
    expect(paintsWith(tester, warn), isTrue,
        reason: 'an expired token must use the warn tone, never error');
    expect(paintsWith(tester, error), isFalse,
        reason: 'red would read as a fault; expiry is a fixable billing state');

    await _pump(tester, MlExpiryNotice(access: _access(status: 'suspended')));
    expect(paintsWith(tester, error), isTrue);
  });

  testWidgets('the notice survives 360px at text scale 1.3', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await _pump(
      tester,
      MlExpiryNotice(
        access: _access(
            status: 'expired',
            expiresAt: DateTime.utc(2026, 4, 23),
            daysSince: 113),
        onRequestRenewal: () {},
        onMessageMineLink: () {},
        compact: true,
      ),
      width: 360,
      textScale: 1.3,
    );
    FlutterError.onError = previous;
    expect(errors.where((e) => e.exception.toString().contains('overflowed')),
        isEmpty);
  });

  group('MlLockedAction', () {
    testWidgets('passes the child straight through when unrestricted',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        MlLockedAction(
          access: _access(status: 'active', isActive: true),
          child: ElevatedButton(
              onPressed: () => taps++, child: const Text('Record load')),
        ),
      );
      await tester.tap(find.text('Record load'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('makes the control inert when restricted', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        MlLockedAction(
          access: _access(status: 'expired'),
          child: ElevatedButton(
              onPressed: () => taps++, child: const Text('Record load')),
        ),
      );
      await tester.tap(find.text('Record load'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0, reason: 'a blocked control must not fire');
    });

    testWidgets('carries a tooltip that says what is needed', (tester) async {
      await _pump(
        tester,
        MlLockedAction(
          access: _access(status: 'expired'),
          child: const Text('Record load'),
        ),
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Needs a renewed token — your token has expired.');
      // Not "Disabled" — the tooltip has to name the fix.
      expect(tooltip.message, contains('renewed token'));
    });

    testWidgets('the tooltip is not swallowed by the pointer blocker',
        (tester) async {
      // The obvious way to write this widget puts IgnorePointer around the
      // Tooltip, which eats the hover the tooltip needs and leaves a silently
      // dead control. The Tooltip must be the OUTER widget.
      await _pump(
        tester,
        MlLockedAction(
          access: _access(status: 'expired'),
          child: const Text('Record load'),
        ),
      );
      final tooltipEl = find.byType(Tooltip);
      final ignoreEl = find.byType(IgnorePointer);
      expect(tooltipEl, findsOneWidget);
      expect(
        find.descendant(of: tooltipEl, matching: ignoreEl),
        findsOneWidget,
        reason: 'IgnorePointer must sit INSIDE the Tooltip, not around it',
      );
    });
  });

  testWidgets('the locked badge names the action, not just "unavailable"',
      (tester) async {
    await _pump(
      tester,
      MlLockedBadge(access: _access(status: 'expired'), action: 'record loads'),
    );
    expect(find.text('Renew your token to record loads'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile/models/account_deactivation_request.dart';
import 'package:flutter_application_1/features/profile/services/account_deactivation_service.dart';
import 'package:flutter_application_1/features/profile/widgets/deactivate_account_card.dart';
import '../test_helpers/real_fonts.dart';

class _FakeService implements AccountDeactivationService {
  _FakeService({this.existing, this.throwCode, this.reauthThrowCode});
  AccountDeactivationRequest? existing;
  final String? throwCode;

  /// When set, [reauthenticate] throws an [AccountDeactivationException]
  /// with this code (e.g. `AUTH_FAILED`) instead of succeeding.
  final String? reauthThrowCode;

  String? requestedReason;
  bool cancelled = false;

  /// The exact password [reauthenticate] was called with, so a test can
  /// prove the widget passed through what the user typed rather than
  /// something else (or nothing).
  String? reauthPassword;

  /// Whether [request] was ever invoked. The regression test for the
  /// password-bypass bug asserts this stays `false` when the confirm action
  /// is (correctly) unreachable.
  bool requestCalled = false;

  @override
  Future<AccountDeactivationRequest?> current() async => existing;

  @override
  Future<void> reauthenticate(String password) async {
    reauthPassword = password;
    if (reauthThrowCode != null) {
      throw AccountDeactivationException(reauthThrowCode!, 'wrong password');
    }
  }

  @override
  Future<void> request(String? reason) async {
    requestCalled = true;
    if (throwCode != null) {
      throw AccountDeactivationException(throwCode!, 'nope');
    }
    requestedReason = reason;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

/// Same shape as [_FakeService.request], but the thrown message is
/// caller-supplied rather than the fixed `'nope'` — used to prove the dialog
/// survives a hostile (unbroken, very long) server message on the MLD01
/// path, per CLAUDE.md §10.4 and the lesson in Ruling 11 / Task 4's
/// empty-fixture defect: a long *sentence* wraps harmlessly, only an
/// unbroken token actually exercises the overflow hazard.
class _HostileFakeService implements AccountDeactivationService {
  _HostileFakeService({required this.code, required this.message});
  final String code;
  final String message;

  @override
  Future<AccountDeactivationRequest?> current() async => null;

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> request(String? reason) async {
    throw AccountDeactivationException(code, message);
  }

  @override
  Future<void> cancel() async {}
}

/// Hosts the card under **the app's own theme**, not a bare `MaterialApp`.
///
/// It used to be bare, which meant `Theme.of(context).textTheme` was stock
/// Material — a different type scale, in a different family, from anything
/// that ships. That was survivable only while every component hard-coded its
/// own `TextStyle`; now that they take type from the theme (which is what
/// makes one design system one system), a themeless host measures text the app
/// will never draw. Same family of fault as the fallback-font trap in
/// `CLAUDE.md` §10.5: the test was green about a rendering nobody sees.
///
/// 20 other test files still host this way — recorded in
/// `docs/redesign/VERIFICATION.md` rather than fixed in passing.
Widget _host(Widget child, {double scale = 1.0}) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

AccountDeactivationRequest _req(String status, {String? note}) =>
    AccountDeactivationRequest(
      status: status,
      requestedAt: DateTime.utc(2026, 8, 19),
      autoApplyAt: DateTime.utc(2026, 9, 18),
      reviewNote: note,
    );

/// An unbroken 300-character token — no spaces, so nothing about it can wrap
/// at a word boundary. This is what actually overflows a `Row` (CLAUDE.md
/// §10.4); a long ordinary *sentence* wraps harmlessly and proves nothing
/// (Ruling 11 in the release-hardening ledger — Task 4's empty-fixture sweep
/// repeated this exact mistake once already).
final String _unbrokenToken = List.generate(300, (i) => 'x').join();

void main() {
  setUpAll(loadRealFonts);

  testWidgets('offers deactivation when there is no open request',
      (tester) async {
    await tester.pumpWidget(_host(DeactivateAccountCard(service: _FakeService())));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate my account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('never uses the word delete anywhere on the card',
      (tester) async {
    await tester.pumpWidget(_host(DeactivateAccountCard(service: _FakeService())));
    await tester.pumpAndSettle();
    // The product does not delete. Copy that says otherwise misleads the user
    // about what happened to their data.
    expect(find.textContaining(RegExp(r'delet', caseSensitive: false)),
        findsNothing);
  });

  testWidgets('a pending request shows status and a way out', (tester) async {
    final svc = _FakeService(existing: _req('pending'));
    await tester.pumpWidget(_host(DeactivateAccountCard(service: svc)));
    await tester.pumpAndSettle();
    expect(find.textContaining('being reviewed'), findsOneWidget);
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(svc.cancelled, isTrue);
  });

  testWidgets('an approved request cannot be cancelled', (tester) async {
    await tester.pumpWidget(
        _host(DeactivateAccountCard(service: _FakeService(existing: _req('approved')))));
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsNothing);
  });

  testWidgets('a rejection shows the admin note', (tester) async {
    await tester.pumpWidget(_host(DeactivateAccountCard(
        service: _FakeService(
            existing: _req('rejected', note: 'Settle the open dispute first.')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Settle the open dispute first.'), findsOneWidget);
  });

  testWidgets('MLD01 names the suspension route, by SQLSTATE not wording',
      (tester) async {
    await tester.pumpWidget(
        _host(DeactivateAccountCard(service: _FakeService(throwCode: 'MLD01'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate my account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
    // The password gate is hard (Critical 1 fix, fix round 1): the confirm
    // button stays disabled without it, so this field must be filled for
    // the tap below to reach the RPC at all.
    await tester.enterText(find.byType(TextField).at(1), 'correct-password');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate my account').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('suspended'), findsOneWidget);
  });

  group('password re-auth gate (fix round 1, Critical 1)', () {
    testWidgets(
        'an empty password disables the confirm action -- typing DEACTIVATE alone must not submit',
        (tester) async {
      final svc = _FakeService();
      await tester.pumpWidget(_host(DeactivateAccountCard(service: svc)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate my account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
      await tester.pumpAndSettle();
      // Password field deliberately left empty. This is the regression test
      // for the bug: re-auth used to run only `if (password.isNotEmpty)`,
      // so nothing stopped DEACTIVATE-alone from reaching the RPC.
      final confirmButton = tester.widget<MlButton>(find.byType(MlButton).last);
      expect(confirmButton.onPressed, isNull,
          reason:
              'the confirm action must be genuinely disabled, not merely a '
              'no-op, until a password is entered');
      // Belt-and-braces: even attempting the tap must not reach the service.
      await tester.tap(find.text('Deactivate my account').last,
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(svc.requestCalled, isFalse);
      expect(svc.reauthPassword, isNull);
    });

    testWidgets(
        'a wrong password does not submit, and does not clear the typed DEACTIVATE text',
        (tester) async {
      final svc = _FakeService(reauthThrowCode: 'AUTH_FAILED');
      await tester.pumpWidget(_host(DeactivateAccountCard(service: svc)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate my account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate my account').last);
      await tester.pumpAndSettle();
      expect(svc.reauthPassword, 'wrong-password');
      expect(svc.requestCalled, isFalse,
          reason: 'the RPC must never be reached when re-auth itself fails');
      expect(find.textContaining('not correct'), findsOneWidget);
      // A password typo must not force the user to re-type DEACTIVATE too.
      expect(find.widgetWithText(TextField, 'DEACTIVATE'), findsOneWidget);
    });

    testWidgets(
        'the correct password submits, passing through exactly what was typed',
        (tester) async {
      final svc = _FakeService();
      await tester.pumpWidget(_host(DeactivateAccountCard(service: svc)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate my account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
      await tester.enterText(
          find.byType(TextField).at(1), 'correct-horse-battery-staple');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate my account').last);
      await tester.pumpAndSettle();
      expect(svc.reauthPassword, 'correct-horse-battery-staple');
      expect(svc.requestCalled, isTrue);
      // Dialog closed on success.
      expect(find.text('Confirm account deactivation'), findsNothing);
    });
  });

  for (final width in <double>[360, 800]) {
    for (final scale in <double>[0.85, 1.0, 1.3]) {
      testWidgets('no overflow at ${width}px / scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            DeactivateAccountCard(service: _FakeService()), scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  // ---------------------------------------------------------------------
  // Beyond the brief: populated-state sweeps + hostile fixtures.
  //
  // Task 4's sweep only ever rendered an empty state and proved nothing —
  // `expect(tester.takeException(), isNull)` passes happily on a screen that
  // rendered almost nothing at all. The sweep above has exactly that shape
  // (only the `none` state, only a short static string), so it is repeated
  // here against every populated state, and against fixtures deliberately
  // built to overflow: an unbroken 300-character token standing in for a
  // rejection note or a server message, so the assertion is actually
  // exercising the wrap/ellipsis rules in CLAUDE.md §10.4 rather than a
  // layout that was never going to overflow regardless of how it was built.
  // ---------------------------------------------------------------------

  group('populated states, real content, no overflow', () {
    for (final width in <double>[360, 800]) {
      for (final scale in <double>[0.85, 1.0, 1.3]) {
        testWidgets('pending at ${width}px / scale $scale', (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              DeactivateAccountCard(
                  service: _FakeService(existing: _req('pending'))),
              scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Content assertion, not just absence of overflow (CLAUDE.md
          // §10.5 — a green sweep over a blank screen proves nothing).
          expect(find.textContaining('being reviewed'), findsOneWidget);
          expect(find.text('Cancel request'), findsOneWidget);
        });

        testWidgets('approved at ${width}px / scale $scale', (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              DeactivateAccountCard(
                  service: _FakeService(existing: _req('approved'))),
              scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // MlStatusBadge renders its label uppercased.
          expect(find.text('APPROVED'), findsOneWidget);
          expect(find.text('Cancel request'), findsNothing);
        });

        testWidgets(
            'rejected with an unbroken 300-char note at ${width}px / scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              DeactivateAccountCard(
                  service: _FakeService(
                      existing: _req('rejected', note: _unbrokenToken))),
              scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining(_unbrokenToken), findsOneWidget);
        });
      }
    }
  });

  group('hostile MLD01 / MLD02 server messages, no overflow', () {
    for (final width in <double>[360, 800]) {
      for (final scale in <double>[0.85, 1.0, 1.3]) {
        testWidgets(
            'MLD01 with an unbroken long company-bearing message at ${width}px / scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          // Stands in for the real RPC message, which names the actual
          // company (spec §2.3) — here rendered unbreakable, as a company
          // name legitimately could be. Deliberately worded differently from
          // the card's own fixed MLD01 sentence, so this test can tell the
          // two apart: it asserts the fixed sentence is present exactly
          // once (proving the card branches on the CODE, not this message)
          // and that this raw detail also renders without overflowing.
          final hostileMessage = 'Owning company on file: $_unbrokenToken.';
          await tester.pumpWidget(_host(
              DeactivateAccountCard(
                  service: _HostileFakeService(
                      code: 'MLD01', message: hostileMessage)),
              scale: scale));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Deactivate my account'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
          await tester.enterText(find.byType(TextField).at(1), 'password');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Deactivate my account').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // The fixed, code-derived sentence is always present regardless of
          // server wording.
          expect(find.textContaining('suspended'), findsOneWidget);
          // The raw (hostile) server detail is also shown, and did not
          // crash the layout.
          expect(find.textContaining(_unbrokenToken), findsOneWidget);
        });

        testWidgets('MLD02 with an unbroken long message at ${width}px / scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              DeactivateAccountCard(
                  service: _HostileFakeService(
                      code: 'MLD02', message: _unbrokenToken)),
              scale: scale));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Deactivate my account'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
          await tester.enterText(find.byType(TextField).at(1), 'password');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Deactivate my account').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('already have a deactivation request'),
              findsOneWidget);
        });
      }
    }
  });
}

// The super-admin "Login" dialog: what it sends back for each way it can be
// used, and that it can be filled in on a phone with the keyboard open.
//
// Login methods (2026-10-24): a user signs in with an email and/or a WhatsApp
// number — one password — and one of the two is primary. The dialog reads the
// user's real methods when it opens, never lets the last method be switched
// off, keeps the primary on a method that is on, and sends only what changed.
//
// Found resetting a test driver's password on a Galaxy S25 Ultra, 2026-10-24:
// with the keyboard open the Confirm field was out of view and the keyboard's
// button did not move to it. Next now steps password → confirm, Done saves.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/data/models/login_methods.dart';
import 'package:flutter_application_1/features/super_admin/widgets/edit_login_dialog.dart';

const _whatsappOnly = LoginMethods(
    email: null, phone: '+27833067846', primary: 'whatsapp', hasWhatsapp: true);
const _emailOnly = LoginMethods(
    email: 'eli@example.com', phone: null, primary: 'email', hasWhatsapp: false);
const _both = LoginMethods(
    email: 'eli@example.com', phone: '+27833067846', primary: 'whatsapp', hasWhatsapp: true);

void main() {
  late LoginEdit? result;
  late bool popped;

  Future<void> open(WidgetTester tester, Future<LoginMethods> methods) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    result = null;
    popped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showDialog<LoginEdit>(
                  context: context,
                  builder: (_) => EditLoginDialog(name: 'Eli Mans', methods: methods),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    // Not pumpAndSettle: while the methods load, the dialog's spinner never
    // settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder toggle(String title) => find.widgetWithText(SwitchListTile, title);
  Future<void> save(WidgetTester t) async {
    await t.ensureVisible(find.text('Save changes'));
    await t.tap(find.text('Save changes'));
    await t.pumpAndSettle();
  }

  testWidgets('shows a spinner until the methods arrive, Save held back',
      (tester) async {
    final pending = Completer<LoginMethods>();
    await open(tester, pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save changes')).onPressed,
        isNull);
    pending.complete(_whatsappOnly);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(field('WhatsApp number'), findsOneWidget);
  });

  testWidgets('WhatsApp-only: the number is prefilled, its switch is locked on',
      (tester) async {
    await open(tester, Future.value(_whatsappOnly));
    expect(find.text('0833067846'), findsOneWidget, reason: 'shown the way people type it');
    expect(field('Email'), findsNothing);
    expect(tester.widget<SwitchListTile>(toggle('Sign in with WhatsApp number')).onChanged, isNull,
        reason: 'the only way in cannot be switched off');
    expect(find.text('Primary sign-in'), findsNothing, reason: 'nothing to choose with one method');
  });

  testWidgets('add an email to a WhatsApp account, then make it primary',
      (tester) async {
    await open(tester, Future.value(_whatsappOnly));
    await tester.tap(toggle('Sign in with email'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email'), 'eli@example.com');
    expect(find.text('Primary sign-in'), findsOneWidget);
    await tester.tap(find.text('Email').last);
    await tester.pumpAndSettle();
    await save(tester);
    expect(popped, isTrue);
    expect(result?.email, 'eli@example.com');
    expect(result?.primary, 'email');
    expect(result?.phone, isNull, reason: 'the number was not touched');
    expect(result?.removePhone, isFalse);
    expect(result?.password, isNull);
  });

  testWidgets('switch from WhatsApp to email: turning WhatsApp off moves the primary',
      (tester) async {
    await open(tester, Future.value(_both));
    await tester.tap(toggle('Sign in with WhatsApp number'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle('Sign in with email')).onChanged, isNull,
        reason: 'email is now the only way in, so it is locked on');
    await save(tester);
    expect(result?.removePhone, isTrue);
    expect(result?.primary, 'email', reason: 'the primary followed the method still on');
    expect(result?.removeEmail, isFalse);
  });

  testWidgets('switch from email to WhatsApp on an email-only account', (tester) async {
    await open(tester, Future.value(_emailOnly));
    await tester.tap(toggle('Sign in with WhatsApp number'));
    await tester.pumpAndSettle();
    await tester.enterText(field('WhatsApp number'), '082 123 4567');
    await tester.tap(toggle('Sign in with email'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(result?.phone, '082 123 4567');
    expect(result?.removeEmail, isTrue);
    expect(result?.primary, 'whatsapp');
  });

  testWidgets('re-typing the same number in another shape is not a change',
      (tester) async {
    await open(tester, Future.value(_whatsappOnly));
    await tester.enterText(field('WhatsApp number'), '+27 83 306 7846');
    await save(tester);
    expect(popped, isTrue);
    expect(result, isNull, reason: 'nothing changed, so nothing is sent');
  });

  testWidgets('an internal WhatsApp login address is refused as an email',
      (tester) async {
    await open(tester, Future.value(_whatsappOnly));
    await tester.tap(toggle('Sign in with email'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email'), 'wa-0833067846@wa.mineralguide.com');
    await save(tester);
    expect(popped, isFalse);
    expect(find.text('That is an internal WhatsApp login address'), findsOneWidget);
  });

  testWidgets('Next moves from the new password to Confirm, Done saves',
      (tester) async {
    await open(tester, Future.value(_whatsappOnly));
    await tester.ensureVisible(field('New password'));
    await tester.tap(field('New password'));
    await tester.enterText(field('New password'), 'MineLinkTest2410');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final confirm = tester.widget<EditableText>(find.descendant(
        of: field('Confirm new password'), matching: find.byType(EditableText)));
    expect(confirm.focusNode.hasFocus, isTrue, reason: 'Next did not move to Confirm');

    await tester.enterText(field('Confirm new password'), 'MineLinkTest2410');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(popped, isTrue, reason: 'Done on Confirm did not save');
    expect(result?.password, 'MineLinkTest2410');
    expect(result?.email, isNull);
    expect(result?.phone, isNull);
    expect(result?.primary, isNull);
  });

  testWidgets('a mismatched confirmation does not save', (tester) async {
    await open(tester, Future.value(_whatsappOnly));
    await tester.enterText(field('New password'), 'MineLinkTest2410');
    await tester.enterText(field('Confirm new password'), 'Different2410');
    await save(tester);
    expect(popped, isFalse);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('a failed read says so instead of showing an empty form',
      (tester) async {
    // As showAdminEditLogin passes it: already failing, marked as handled.
    await open(tester, Future<LoginMethods>.error(Exception('offline'))..ignore());
    expect(find.textContaining('Could not read their login details'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(result, isNull);
  });
}

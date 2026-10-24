// The super-admin "Login details" dialog: what it sends back, and that it can
// be filled in on a phone with the keyboard open.
//
// Found resetting a test driver's password on a Galaxy S25 Ultra, 2026-10-24:
// once the keyboard opened the Confirm field was out of view and the keyboard's
// button did not move to it. Next now steps password → confirm, and Done on
// the confirm field saves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/widgets/edit_login_dialog.dart';

void main() {
  late LoginEdit? result;
  late bool popped;

  Future<void> open(WidgetTester tester, {bool whatsappOnly = true}) async {
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
                  builder: (_) => EditLoginDialog(
                    name: 'Eli Mans',
                    currentEmail: whatsappOnly ? '' : 'eli@example.com',
                    currentPhone: '0833067846',
                    whatsappOnly: whatsappOnly,
                  ),
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
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('Next moves from the new password to Confirm, Done saves',
      (tester) async {
    await open(tester);

    await tester.tap(field('New password'));
    await tester.enterText(field('New password'), 'MineLinkTest2410');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    final confirm = tester.widget<EditableText>(
        find.descendant(of: field('Confirm new password'), matching: find.byType(EditableText)));
    expect(confirm.focusNode.hasFocus, isTrue,
        reason: 'Next did not move to the Confirm field');

    await tester.enterText(field('Confirm new password'), 'MineLinkTest2410');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(popped, isTrue, reason: 'Done on Confirm did not save');
    expect(result?.password, 'MineLinkTest2410');
    expect(result?.email, isNull, reason: 'a WhatsApp-only login has no email to send');
    expect(result?.phone, isNull, reason: 'the number was not changed');
  });

  testWidgets('a mismatched confirmation does not save', (tester) async {
    await open(tester);
    await tester.enterText(field('New password'), 'MineLinkTest2410');
    await tester.enterText(field('Confirm new password'), 'Different2410');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(popped, isFalse);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('a WhatsApp-only login shows no email field', (tester) async {
    await open(tester);
    expect(field('Email'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(result, isNull, reason: 'Cancel sends nothing');
    await open(tester, whatsappOnly: false);
    expect(field('Email'), findsOneWidget);
  });
}

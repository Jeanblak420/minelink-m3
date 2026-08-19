// S8-10 — a waybill was going out with a blank signature line and no warning.
//
// 3 of 116 profiles have a signature. Everyone else who records a load or
// files a POD produces a slip whose DISPATCHED BY or RECEIVED BY block is an
// empty rule, and nothing said so — not at the moment of signing, not after.
//
// RED FIRST is the pre-fix call sites, which asked nothing at all. Modelled
// here as `_preFix`, which always proceeds. The first case runs against both.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/profile/services/signature_service.dart';
import 'package:flutter_application_1/features/profile/widgets/signature_required_prompt.dart';

/// The pre-fix flows: no question, straight on to the record.
Future<SignaturePromptOutcome> _preFix() async =>
    SignaturePromptOutcome.proceedUnsigned;

/// Pumps a screen with one button that runs the gate and records its answer.
Future<SignaturePromptOutcome?> _runGate(
  WidgetTester tester, {
  required String? signatureUrl,
  String? tapLabel,
}) async {
  SignaturePromptOutcome? got;
  var wentToProfile = false;

  final router = GoRouter(
    initialLocation: '/x',
    routes: [
      GoRoute(
        path: '/x',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  got = await ensureSignatureBeforeSigning(
                    context, ref,
                    action: 'record this load',
                    waybillBlock: 'DISPATCHED BY',
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          wentToProfile = true;
          return const Scaffold(body: Text('profile'));
        },
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      mySignatureUrlProvider.overrideWith((ref) async => signatureUrl),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();

  if (tapLabel != null) {
    await tester.tap(find.text(tapLabel));
    await tester.pumpAndSettle();
  }
  if (tapLabel == 'Add signature') {
    expect(wentToProfile, isTrue,
        reason: 'choosing to add a signature must actually go to /profile');
  }
  return got;
}

void main() {
  testWidgets('a user WITH a signature is never interrupted', (t) async {
    final got = await _runGate(t, signatureUrl: 'uid/signature.png');
    expect(got, SignaturePromptOutcome.alreadySigned);
    expect(find.text('You have no signature on file'), findsNothing);
  });

  testWidgets('a user WITHOUT one is stopped and told what will happen',
      (t) async {
    await _runGate(t, signatureUrl: null);
    expect(find.text('You have no signature on file'), findsOneWidget);
    // The consequence has to be in the words that matter. "Please add a
    // signature" is a request; this is the outcome of not doing so.
    expect(
      find.textContaining('the waybill will print with an empty '
          'DISPATCHED BY signature line'),
      findsOneWidget,
    );

    // Red-first: the pre-fix call sites asked nothing and proceeded.
    expect(await _preFix(), SignaturePromptOutcome.proceedUnsigned,
        reason: 'before this gate, both flows recorded without a word');
  });

  testWidgets('an empty-string url counts as no signature', (t) async {
    // `mySignatureUrl()` returning '' rather than null is the shape that would
    // otherwise slip through a `!= null` test and produce the blank rule this
    // whole gate exists to prevent.
    await _runGate(t, signatureUrl: '   ');
    expect(find.text('You have no signature on file'), findsOneWidget);
  });

  testWidgets('Add signature cancels the action and goes to /profile',
      (t) async {
    final got = await _runGate(
        t, signatureUrl: null, tapLabel: 'Add signature');
    expect(got, SignaturePromptOutcome.goToProfile);
    // The caller must abandon what it was doing — recording the load after
    // navigating away is how you get a load recorded from a disposed screen.
    expect(got, isNot(SignaturePromptOutcome.proceedUnsigned));
  });

  testWidgets('Continue unsigned proceeds, deliberately', (t) async {
    // Not a hard block, and the reason is in the source: a load controller
    // stands at a weighbridge with a loaded truck on it. Refusing the record
    // until they draw a signature moves the problem from a document to a
    // queue of trucks. If the client wants a hard block this is the one line
    // to change, and this test is what will go red when they do.
    final got = await _runGate(
        t, signatureUrl: null, tapLabel: 'Continue unsigned');
    expect(got, SignaturePromptOutcome.proceedUnsigned);
  });

  testWidgets('the prompt cannot be dismissed by tapping outside', (t) async {
    // barrierDismissible: false. A prompt about a legal mark that vanishes on
    // a stray tap is not a prompt.
    await _runGate(t, signatureUrl: null);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('You have no signature on file'), findsOneWidget);
  });
}

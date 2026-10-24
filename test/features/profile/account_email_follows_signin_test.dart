// Account & security must show the account that is signed in NOW (emulator
// walk, 2026-10-24): signed in as a transporter manager, the change-password
// card read "For role.walk.sec…" — the Security user who had signed in on that
// device two sign-ins earlier. `accountEmailProvider` read the session once
// and was then cached for the life of the app, so the card would also have
// checked "current password" against the previous user's account.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/profile/providers/account_email_provider.dart';

final _signedIn = StateProvider<String?>((ref) => 'first@example.com');

void main() {
  test('a new sign-in changes the email; signing out clears it', () {
    final c = ProviderContainer(overrides: [
      accountEmailSourceProvider.overrideWith((ref) => ref.watch(_signedIn)),
    ]);
    addTearDown(c.dispose);
    // Something on screen keeps listening, as the screen does.
    c.listen(accountEmailProvider, (_, __) {}, fireImmediately: true);
    expect(c.read(accountEmailProvider), 'first@example.com');

    c.read(_signedIn.notifier).state = '  second@example.com ';
    expect(c.read(accountEmailProvider), 'second@example.com');

    c.read(_signedIn.notifier).state = null;
    expect(c.read(accountEmailProvider), isNull);

    c.read(_signedIn.notifier).state = '';
    expect(c.read(accountEmailProvider), isNull);
  });
}

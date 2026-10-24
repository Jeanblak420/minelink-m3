// What an admin reads about a user's login (found on a Galaxy S25 Ultra,
// 2026-10-24): a WhatsApp-only driver's card showed the internal
// `wa-…@wa.mineralguide.com` address as their email, and saving the login
// dialog said "Updated removed email, primary: whatsapp".
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_application_1/features/super_admin/data/models/login_methods.dart';

void main() {
  test('the internal WhatsApp login address is never shown as an email', () {
    expect(realEmailOrNull('wa-0833067846@wa.mineralguide.com'), isNull);
    expect(realEmailOrNull('WA-27833067846@WA.MINERALGUIDE.COM'), isNull);
    expect(realEmailOrNull('  '), isNull);
    expect(realEmailOrNull(null), isNull);
    expect(realEmailOrNull(' eli@example.com '), 'eli@example.com');
  });

  test('the save message reads as a sentence', () {
    expect(loginChangeSummary(['removed email', 'primary: whatsapp']),
        'email sign-in removed; primary is now WhatsApp');
    expect(loginChangeSummary(['email', 'primary: email']), 'email saved; primary is now email');
    expect(loginChangeSummary(['password']), 'password changed');
    expect(loginChangeSummary(['removed WhatsApp number']), 'WhatsApp sign-in removed');
  });
}

import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeWhatsappNumber', () {
    test('strips spaces, +, dashes and parentheses', () {
      expect(normalizeWhatsappNumber('+27 (82) 123-4567'), '27821234567');
    });

    test('empty when no digits', () {
      expect(normalizeWhatsappNumber('  +- '), '');
    });
  });

  group('whatsappAuthEmail', () {
    test('builds a deterministic synthetic email from the number', () {
      expect(
        whatsappAuthEmail('+27 82 123 4567'),
        'wa-27821234567@wa.mineralguide.com',
      );
    });

    test('is stable across different formattings of the same number', () {
      expect(
        whatsappAuthEmail('+27-82-123-4567'),
        whatsappAuthEmail('27 821 234 567'),
      );
    });

    test('returns empty string when there are no digits', () {
      expect(whatsappAuthEmail('not a number'), '');
    });
  });

  group('looksLikeEmail', () {
    test('true for an email, false for a bare number', () {
      expect(looksLikeEmail('owner@mineralguide.com'), isTrue);
      expect(looksLikeEmail('+27821234567'), isFalse);
    });
  });

  group('whatsappToE164', () {
    test('prefixes a plus and strips formatting', () {
      expect(whatsappToE164('+27 (82) 123-4567'), '+27821234567');
      expect(whatsappToE164('27821234567'), '+27821234567');
    });

    test('returns empty string when there are no digits', () {
      expect(whatsappToE164('nope'), '');
    });
  });
}

import 'package:flutter_application_1/features/auth/utils/reverification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requiresReverification (rolling interval)', () {
    final now = DateTime(2026, 6, 17, 12);

    test('default interval is 30 days', () {
      expect(kReverificationInterval, const Duration(days: 30));
    });

    test('true when never verified on this device', () {
      expect(requiresReverification(null, now), isTrue);
    });

    test('false while still within the interval', () {
      expect(
        requiresReverification(now.subtract(const Duration(days: 10)), now),
        isFalse,
      );
      expect(
        requiresReverification(
            now.subtract(const Duration(days: 29, hours: 23)), now),
        isFalse,
      );
    });

    test('true once the interval has elapsed', () {
      expect(
        requiresReverification(now.subtract(const Duration(days: 30)), now),
        isTrue,
      );
      expect(
        requiresReverification(now.subtract(const Duration(days: 45)), now),
        isTrue,
      );
    });

    test('boundary: exactly the interval requires re-verification', () {
      expect(
        requiresReverification(now.subtract(kReverificationInterval), now),
        isTrue,
      );
    });

    test('honors a custom interval override', () {
      expect(
        requiresReverification(now.subtract(const Duration(days: 5)), now,
            interval: const Duration(days: 3)),
        isTrue,
      );
      expect(
        requiresReverification(now.subtract(const Duration(days: 2)), now,
            interval: const Duration(days: 3)),
        isFalse,
      );
    });
  });
}

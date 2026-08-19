import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';

void main() {
  // CLAUDE.md §4 is explicit: use the corrected `?q=lat,lng` form, never the
  // malformed `https://google.com{lat},${lng}`. Guard against regressions.
  test('googleMapsLink produces the corrected universal ?q= link', () {
    expect(
      googleMapsLink(-29.12345, 24.6789),
      'https://www.google.com/maps?q=-29.12345,24.6789',
    );
  });

  test('link is never the malformed form', () {
    final link = googleMapsLink(-26.2041, 28.0473);
    expect(link.startsWith('https://www.google.com/maps?q='), isTrue);
    expect(link.contains('?q='), isTrue);
    // The malformed form concatenated the coords straight onto the host.
    expect(link.contains('google.com-'), isFalse);
    expect(link.contains(r'${'), isFalse);
  });
}

import 'package:flutter_application_1/core/routing/return_to.dart';
import 'package:flutter_test/flutter_test.dart';

/// `safeReturnTo` decides whether a value that arrived inside a URL may be
/// handed to `context.go`. It is the app's only open-redirect boundary, so the
/// refusals matter more than the acceptances.
void main() {
  group('safeReturnTo accepts an in-app destination', () {
    for (final path in <String>[
      '/portal/mine/production',
      '/portal/driver/trip',
      '/super-admin/targets',
      '/portal/mine/trips/abc-123/waybill',
      '/notifications/manage?title=Fleet',
      '/portal/buyer/requests?status=sent_back',
    ]) {
      test(path, () => expect(safeReturnTo(path), path));
    }
  });

  group('safeReturnTo refuses', () {
    // Each of these, honoured, would land a user who has just typed their
    // password on a page that is not this app.
    const cases = <String, String>{
      'null': '',
      'an absolute http URL': 'http://evil.example/steal',
      'an absolute https URL': 'https://evil.example/steal',
      // The important one. A naive `startsWith("/")` check passes this, and
      // browsers read it as `https://evil.example`.
      'a protocol-relative URL': '//evil.example/steal',
      'a protocol-relative URL with a path': '//evil.example',
      // Several browsers normalise a backslash to a forward slash first.
      'a backslash-escaped authority': r'/\evil.example',
      'a scheme-relative javascript URI': 'javascript:alert(1)',
      'a data URI': 'data:text/html,<script>alert(1)</script>',
      'a bare host': 'evil.example',
      'a relative path': 'portal/mine',
      // Returning to the login screen after signing in is a redirect loop.
      'the login screen itself': '/login',
      'the login screen with a query': '/login?from=/portal/mine',
    };
    cases.forEach((name, value) {
      test(name, () => expect(safeReturnTo(value), isNull, reason: name));
    });

    test('an empty or absent value', () {
      expect(safeReturnTo(null), isNull);
      expect(safeReturnTo(''), isNull);
    });
  });

  test('the query key is the one the router reads', () {
    expect(kReturnToKey, 'from');
  });
}

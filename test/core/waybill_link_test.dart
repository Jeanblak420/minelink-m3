// S6-27 / ruling 5 — the four waybill routes existed but nothing emitted one.
//
// RED FIRST: before `waybill_link.dart` there was no function to call. The
// closest thing to a pre-fix behaviour is "the modal offers no link at all",
// modelled below as `_preFix` returning null for every shell — the first test
// runs against both and shows they disagree everywhere a waybill can be
// opened.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/waybill_link.dart';

/// Before this work, no shell could produce a waybill URL.
String? _preFix(String currentPath, String tripId) => null;

const _id = '11111111-2222-3333-4444-555555555555';

void main() {
  group('waybillRouteFor — which route, per shell', () {
    test('each portal org maps to its own waybill route', () {
      final cases = <String, String>{
        '/portal/mine/tons-out': '/portal/mine/trips/$_id/waybill',
        '/portal/mine': '/portal/mine/trips/$_id/waybill',
        '/portal/buyer/loads-value': '/portal/buyer/trips/$_id/waybill',
        '/portal/transporter/trips':
            '/portal/transporter/trips/$_id/waybill',
      };
      cases.forEach((path, expected) {
        expect(waybillRouteFor(currentPath: path, tripId: _id), expected,
            reason: 'from $path');
        // Red-first: the pre-fix state offered nothing from any of these.
        expect(_preFix(path, _id), isNull);
      });
    });

    test("the driver's route is /trip/ singular, not /trips/", () {
      // The one route whose shape differs. Deriving it from the pattern the
      // other three follow produces a 404 that only a driver would ever hit.
      expect(
        waybillRouteFor(currentPath: '/portal/driver/trip', tripId: _id),
        '/portal/driver/trip/$_id/waybill',
      );
      expect(
        waybillRouteFor(currentPath: '/portal/driver/home', tripId: _id),
        isNot(contains('/trips/')),
      );
    });

    test('the super-admin console yields no link, deliberately', () {
      // It can open the modal from the combined recon table, but no
      // /super-admin/**/waybill route exists. Null is the honest answer; a
      // synthesised /portal/mine URL would be a link into a shell the admin
      // does not use.
      expect(
        waybillRouteFor(
            currentPath: '/super-admin/recon-tables', tripId: _id),
        isNull,
      );
    });

    test('non-portal and empty inputs yield no link', () {
      expect(waybillRouteFor(currentPath: '/operations', tripId: _id), isNull);
      expect(waybillRouteFor(currentPath: '/home', tripId: _id), isNull);
      expect(
          waybillRouteFor(currentPath: '/portal/mine', tripId: ''), isNull);
      expect(
          waybillRouteFor(currentPath: '/portal/mine', tripId: '   '), isNull);
    });

    test('a prefix that merely starts the same does not match', () {
      // `/portal/minerals` is not `/portal/mine`.
      expect(
        waybillRouteFor(currentPath: '/portal/minerals', tripId: _id),
        isNull,
      );
    });

    test('the trip id is percent-encoded into the path', () {
      final route =
          waybillRouteFor(currentPath: '/portal/mine', tripId: 'a b/../c');
      expect(route, isNotNull);
      // The separator must not survive as a path separator, or the id can
      // climb out of its segment.
      expect(route, isNot(contains('/../')));
      expect(route, contains('a%20b'));
    });
  });

  group('waybillLinkToCopy — what lands on the clipboard', () {
    const route = '/portal/mine/trips/abc/waybill';

    test('web link keeps the # because this app ships hash routing', () {
      // No usePathUrlStrategy() anywhere in lib/ or web/. Without the '#'
      // the link resolves to the document root and 404s on any host that
      // does not blanket-rewrite to index.html.
      expect(
        waybillLinkToCopy(
            base: Uri.parse('https://app.example.com/#/portal/mine/tons-out'),
            route: route,
            isWeb: true),
        'https://app.example.com/#$route',
      );
    });

    test('a deployment sub-path is preserved', () {
      // Dropping base.path would build https://host/#/... and miss the app.
      expect(
        waybillLinkToCopy(
            base: Uri.parse('https://example.com/minelink/#/portal/mine'),
            route: route,
            isWeb: true),
        'https://example.com/minelink/#$route',
      );
    });

    test('non-web copies the bare route, not a file: URI', () {
      // Uri.base in a Windows or Android build is a file: URI of the working
      // directory. `file:///C:/src/#/portal/...` helps nobody.
      expect(
        waybillLinkToCopy(
            base: Uri.parse('file:///C:/src/minelink/'),
            route: route,
            isWeb: false),
        route,
      );
    });

    test('a non-http base is refused even if isWeb is somehow true', () {
      expect(
        waybillLinkToCopy(
            base: Uri.parse('file:///C:/src/'), route: route, isWeb: true),
        route,
      );
    });
  });
}

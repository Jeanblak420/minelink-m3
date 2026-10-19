import 'package:flutter_application_1/core/routing/initial_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initialLocationFrom', () {
    test('web hash deep link is restored', () {
      expect(
        initialLocationFrom(Uri.parse('http://host/#/portal/mine/tons-out')),
        '/portal/mine/tons-out',
      );
    });

    test('bare web origin falls through to the router default', () {
      expect(initialLocationFrom(Uri.parse('http://host/')), isNull);
    });

    test('Windows working directory is not a route', () {
      expect(
        initialLocationFrom(Uri.parse(
          'file:///C:/Users/Somebody%20Someone/Music/SHOWME!/MineLink-M3/'
          'release/MineLink-M3-Windows-2026-10-17/',
        )),
        isNull,
      );
    });

    test('Android working directory is not a route', () {
      expect(initialLocationFrom(Uri.parse('file:///')), isNull);
    });
  });
}

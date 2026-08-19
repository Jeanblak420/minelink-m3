import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/utils/maps_short_link.dart';

void main() {
  group('latLngFromExpandedMapsUrl', () {
    test('parses place-pin !3d/!4d form (authoritative over @viewport)', () {
      final p = latLngFromExpandedMapsUrl(
          'https://www.google.com/maps/place/SPAR+Kingfisher/@-26.0285039,27.999412,17z/'
          'data=!3m1!4b1!4m6!3m5!1s0x1e95774af82ae7c3:0xd9da9d64c5f0a485'
          '!8m2!3d-26.0285039!4d28.0019869!16s%2Fg%2F11h5mkjb0r');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-26.0285039, 1e-7));
      expect(p.longitude, closeTo(28.0019869, 1e-7)); // NOT 27.999412
    });

    test('falls back to @lat,lng viewport form', () {
      final p = latLngFromExpandedMapsUrl(
          'https://www.google.com/maps/@-29.85,31.02,12z');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-29.85, 1e-9));
      expect(p.longitude, closeTo(31.02, 1e-9));
    });

    test('parses ?q= form', () {
      final p = latLngFromExpandedMapsUrl(
          'https://www.google.com/maps?q=-26.03,28.0');
      expect(p, equals(const LatLng(-26.03, 28.0)));
    });

    test('rejects junk', () {
      expect(latLngFromExpandedMapsUrl('https://example.com/nothing'), isNull);
      expect(latLngFromExpandedMapsUrl('not a url'), isNull);
    });
  });

  group('resolveMapsLink', () {
    test('already-parseable ?q= link needs no network', () async {
      final p = await resolveMapsLink('https://www.google.com/maps?q=-1.5,30.5',
          client: MockClient(
              (_) async => throw StateError('no network expected')));
      expect(p, equals(const LatLng(-1.5, 30.5)));
    });

    test('short link follows redirect Location header', () async {
      final client = MockClient((req) async {
        expect(req.url.host, 'maps.app.goo.gl');
        return http.Response('', 302, headers: {
          'location':
              'https://www.google.com/maps/place/X/@-26.0285039,27.999412,17z/'
                  'data=!8m2!3d-26.0285039!4d28.0019869'
        });
      });
      final p = await resolveMapsLink(
          'https://maps.app.goo.gl/XcJEYHJFu15XyLY67',
          client: client);
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-26.0285039, 1e-7));
      expect(p.longitude, closeTo(28.0019869, 1e-7));
    });

    test('network failure returns null (never throws)', () async {
      final client =
          MockClient((_) async => throw http.ClientException('down'));
      final p =
          await resolveMapsLink('https://maps.app.goo.gl/abc', client: client);
      expect(p, isNull);
    });
  });
}

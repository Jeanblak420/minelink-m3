// The location picker's address search.
//
// Written after the picker looked broken in the app (2026-08-15): typing
// "Trumpet On Keyes, 21 Keyes Ave, Rosebank, Johannesburg" produced nothing at
// all. Measured against the live services, Nominatim answers HTTP 200 with an
// EMPTY list for that string — it does not fuzzy-match a venue name it has no
// record of — and the dialog then rendered no list, no message and no error.
//
// So these tests pin two separate things: that the query is relaxed and failed
// over until something answers, and that an empty answer is still an answer the
// user can see.

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/config/place_index_config.dart';
import 'package:flutter_application_1/features/portal/services/place_search_service.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';

/// The real query from the screenshot that started this.
const _typed = 'Trumpet On Keyes, 21 Keyes Ave, Rosebank, Johannesburg';
const _relaxed = '21 Keyes Ave, Rosebank, Johannesburg';

String _nominatimBody(List<(String, double, double)> rows) => jsonEncode([
  for (final (name, lat, lon) in rows)
    {'display_name': name, 'lat': '$lat', 'lon': '$lon'},
]);

/// Photon returns GeoJSON — `[lon, lat]`, the reverse of everything else in
/// this codebase — and fields rather than a rendered address.
String _photonBody(List<(Map<String, String>, double, double)> rows) =>
    jsonEncode({
      'features': [
        for (final (props, lat, lon) in rows)
          {
            'geometry': {
              'type': 'Point',
              'coordinates': [lon, lat],
            },
            'properties': props,
          },
      ],
    });

/// Records every URL asked for, so a test can assert WHICH query was sent and
/// in what order — the relaxation is invisible from the result alone.
class _Recorder {
  final List<Uri> calls = [];

  http.Client client(String Function(Uri uri) respond) =>
      MockClient((req) async {
        calls.add(req.url);
        return http.Response(
          respond(req.url),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

  bool get hitPhoton => calls.any((u) => u.host.contains('photon'));

  /// Link resolution also uses the client (it follows redirects), so "made no
  /// geocoder call" has to be asked specifically.
  List<Uri> get geocoderCalls => [
    for (final u in calls)
      if (u.host.contains('photon') || u.host.contains('nominatim')) u,
  ];

  List<String> get queries => [
    for (final u in calls) u.queryParameters['q'] ?? '',
  ];
}

PlaceSearchService _service(
  http.Client client, {
  Future<List<PlaceHit>> Function(String)? savedPlaces,
  Future<List<PlaceHit>> Function(String)? placeIndex,
}) => PlaceSearchService(
  client: client,
  // Zero gap: the 1.1s Nominatim spacing is real in the app and would make
  // this suite sleep for minutes.
  minNominatimGap: Duration.zero,
  // Hermetic by default — both real lookups reach Supabase.
  savedPlaces: savedPlaces ?? (_) async => const <PlaceHit>[],
  placeIndex: placeIndex ?? (_) async => const <PlaceHit>[],
);

void main() {
  group('query relaxation', () {
    test('drops leading comma-segments, longest first, and stops at three', () {
      expect(PlaceSearchService.relaxations(_typed), [
        _relaxed,
        'Rosebank, Johannesburg',
        'Johannesburg',
      ]);
    });

    test('a query with no commas has nothing to relax', () {
      // Which is exactly why "Steelpoort chrome mine" has to reach Photon.
      expect(PlaceSearchService.relaxations('Steelpoort chrome mine'), isEmpty);
    });
  });

  group('PlaceSearchService.search', () {
    test('an address Nominatim knows is answered on the first call', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client(
          (uri) => _nominatimBody([
            (
              'Keyes Avenue, Rosebank, Johannesburg, South Africa',
              -26.1409765,
              28.0359834,
            ),
          ]),
        ),
      ).search(_relaxed);

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.nominatim);
      expect(rec.calls, hasLength(1), reason: 'no fallback should have run');
      expect(
        hits.single.matchedQuery,
        isNull,
        reason: 'an exact match carries no caption',
      );
    });

    testWidgets('a broadened match is captioned in the dialog', (tester) async {
      // What "13 Westway Rd, Fourways, Sandton, 2055" really does: OSM has no
      // Westway Road, so the ladder falls back to the suburb. The user must be
      // told the options below are the AREA, not their street.
      final service = _service(
        MockClient((req) async {
          final q = req.url.queryParameters['q'];
          return http.Response(
            q == 'Fourways, Sandton, 2055'
                ? _nominatimBody([
                    (
                      'Fourways, Randburg, Johannesburg, Gauteng, South Africa',
                      -26.0136,
                      28.0094,
                    ),
                  ])
                : _nominatimBody(const []),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: LocationPickerDialog(searchService: service)),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        '13 Westway Rd, Fourways, Sandton, 2055',
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // The typed text also contains the relaxed query, so match the caption.
      expect(
        find.textContaining('showing results for “Fourways, Sandton, 2055”'),
        findsOneWidget,
      );
      expect(find.textContaining('No exact match'), findsOneWidget);
    });

    test('the screenshot query resolves by dropping the venue name', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client((uri) {
          // Nominatim knows the street but not "Trumpet On Keyes".
          final q = uri.queryParameters['q'];
          return _nominatimBody(
            q == _relaxed
                ? [
                    (
                      'Keyes Avenue, Parktown North, Rosebank, Johannesburg, '
                          'Gauteng, South Africa',
                      -26.1409765,
                      28.0359834,
                    ),
                  ]
                : const [],
          );
        }),
      ).search(_typed);

      expect(hits, hasLength(1));
      expect(hits.single.label, contains('Keyes Avenue'));
      expect(hits.single.point.latitude, closeTo(-26.14098, 0.00001));
      expect(rec.queries, [_typed, _relaxed]);
      expect(
        hits.single.matchedQuery,
        _relaxed,
        reason:
            'a broadened match must carry the query it actually matched, '
            'or the picker passes it off as the address that was typed',
      );
      expect(
        rec.hitPhoton,
        isFalse,
        reason: 'relaxation answered; Photon was not needed',
      );
    });

    test('a venue with no comma to drop falls through to Photon', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client(
          (uri) => uri.host.contains('photon')
              ? _photonBody([
                  (
                    {
                      'name': 'Tubatse Chrome Smelter',
                      'state': 'Limpopo',
                      'country': 'South Africa',
                    },
                    -24.7433,
                    30.1964,
                  ),
                ])
              : _nominatimBody(const []),
        ),
      ).search('Steelpoort chrome mine');

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.photon);
      expect(
        hits.single.label,
        'Tubatse Chrome Smelter, Limpopo, South Africa',
      );
      // GeoJSON is [lon, lat]. Reading it in order puts Limpopo in the Indian
      // Ocean off Somalia, and the pin is what a driver gets routed to.
      expect(hits.single.point.latitude, closeTo(-24.7433, 0.0001));
      expect(hits.single.point.longitude, closeTo(30.1964, 0.0001));
    });

    test('both providers are asked to prefer southern Africa', () async {
      // Without the Photon bbox, "Richards Bay Dry Bulk Terminal" returns a
      // dock in Basra, Iraq as its top hit (measured 2026-08-15). A confident
      // answer on the wrong continent is worse than no answer.
      final rec = _Recorder();
      await _service(
        rec.client(
          (uri) => uri.host.contains('photon')
              ? _photonBody(const [])
              : _nominatimBody(const []),
        ),
      ).search('Richards Bay Dry Bulk Terminal');

      final nominatim = rec.calls.firstWhere(
        (u) => u.host.contains('nominatim'),
      );
      final photon = rec.calls.firstWhere((u) => u.host.contains('photon'));
      expect(nominatim.queryParameters['viewbox'], '10,-36,42,-4');
      expect(
        nominatim.queryParameters['bounded'],
        '0',
        reason:
            'a viewbox must rank, not exclude — Maputo and Walvis Bay '
            'are real destinations',
      );
      expect(photon.queryParameters['bbox'], '10,-36,42,-4');
    });

    test('nothing anywhere is an empty answer, not a failure', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client(
          (uri) => uri.host.contains('photon')
              ? _photonBody(const [])
              : _nominatimBody(const []),
        ),
      ).search('qwertyuiop asdfghjkl');

      expect(hits, isEmpty);
      expect(
        rec.hitPhoton,
        isTrue,
        reason: 'every stage should have been tried',
      );
    });

    test('one provider down still returns the other\'s results', () async {
      final client = MockClient(
        (req) async => req.url.host.contains('photon')
            ? http.Response(
                _photonBody([
                  (
                    {
                      'name': 'Sandton City',
                      'city': 'Sandton',
                      'country': 'South Africa',
                    },
                    -26.1090,
                    28.0524,
                  ),
                ]),
                200,
              )
            : http.Response('upstream is down', 503),
      );

      final hits = await _service(client).search('Sandton City');
      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.photon);
    });

    test('every provider down is reported, not silently swallowed', () async {
      final client = MockClient((req) async => http.Response('nope', 503));
      await expectLater(
        _service(client).search('Sandton City'),
        throwsA(isA<PlaceSearchUnavailable>()),
      );
    });

    test('a query too short to be meaningful makes no request', () async {
      final rec = _Recorder();
      expect(await _service(rec.client((_) => '[]')).search('Jo'), isEmpty);
      expect(rec.calls, isEmpty);
    });

    test('Photon walks the same ladder, not just the query as typed', () async {
      // The real 6-segment address from the field. Photon returns 0 for it at
      // full length and 3 once the leading segments are gone, so asking Photon
      // only for the full string made it useless in the one case it exists for.
      const long =
          'ATLAS L Group, 2nd Floor, Trumpet On Keyes, '
          '21 Keyes Ave, Rosebank, Johannesburg';
      final rec = _Recorder();
      final hits = await _service(
        rec.client((uri) {
          final q = uri.queryParameters['q'];
          if (!uri.host.contains('photon')) return _nominatimBody(const []);
          return _photonBody(
            q == _relaxed
                ? [
                    (
                      {
                        'name': 'Keyes Avenue',
                        'city': 'Rosebank',
                        'country': 'South Africa',
                      },
                      -26.1446,
                      28.0367,
                    ),
                  ]
                : const [],
          );
        }),
      ).search(long);

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.photon);
      final photonQueries = [
        for (final u in rec.calls)
          if (u.host.contains('photon')) u.queryParameters['q'],
      ];
      expect(
        photonQueries,
        contains(_relaxed),
        reason: 'Photon must be offered the relaxed query too',
      );
    });
  });

  group('places this company already saved', () {
    final atlas = PlaceHit(
      label: 'ATLAS L Group — saved location (primary)',
      point: const LatLng(-26.143482, 28.0363163),
      source: PlaceSource.saved,
    );

    test('answer first, without asking any geocoder', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client((_) => '[]'),
        savedPlaces: (q) async =>
            q.toLowerCase().contains('atlas') ? [atlas] : const <PlaceHit>[],
      ).search('atlas');

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.saved);
      expect(hits.single.point.latitude, closeTo(-26.143482, 0.000001));
      expect(
        rec.geocoderCalls,
        isEmpty,
        reason: 'a name this company has already pinned needs no lookup',
      );
    });

    test('do not block the geocoders when nothing is saved', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client(
          (_) => _nominatimBody([
            ('Sandton, Johannesburg, Gauteng, South Africa', -26.1, 28.05),
          ]),
        ),
        savedPlaces: (_) async => const <PlaceHit>[],
      ).search('Sandton');

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.nominatim);
    });

    test(
      'a broken saved-place lookup costs the shortcut, not the search',
      () async {
        final rec = _Recorder();
        final hits = await _service(
          rec.client(
            (_) => _nominatimBody([
              ('Sandton, Johannesburg, Gauteng, South Africa', -26.1, 28.05),
            ]),
          ),
          savedPlaces: (_) async => throw Exception('offline'),
        ).search('Sandton');

        expect(hits, hasLength(1));
        expect(hits.single.source, PlaceSource.nominatim);
      },
    );
  });

  group("MineLink's own place index", () {
    // The whole reason the index exists: OSM has no Westway Road in Fourways,
    // so Nominatim and Photon can never answer this. Overture has 15 and 39.
    final westway = PlaceHit(
      label: 'Micro-Ctrl, 15 Westway Rd, Fourways, Sandton, ZA',
      point: const LatLng(-26.033955, 27.998734),
      source: PlaceSource.placeIndex,
    );

    test('answers a street the geocoders do not have', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client((_) => _nominatimBody(const [])),
        placeIndex: (q) async => q.toLowerCase().contains('westway')
            ? [westway]
            : const <PlaceHit>[],
      ).search('13 Westway Rd, Fourways, Sandton, 2055');

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.placeIndex);
      expect(hits.single.point.latitude, closeTo(-26.033955, 0.000001));
      expect(
        rec.geocoderCalls,
        isEmpty,
        reason:
            'our own index is one round trip and has no rate limit — '
            'there is no reason to ask Nominatim first',
      );
    });

    test('an unloaded index is inert, not fatal', () async {
      // How this ships: the table exists and is empty until the Overture
      // import is run, so every query must fall straight through.
      final rec = _Recorder();
      final hits = await _service(
        rec.client(
          (_) => _nominatimBody([
            ('Sandton, Johannesburg, Gauteng, South Africa', -26.1, 28.05),
          ]),
        ),
        placeIndex: (_) async => const <PlaceHit>[],
      ).search('Sandton');

      expect(hits.single.source, PlaceSource.nominatim);
    });

    test('a failing index costs the stage, not the search', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client(
          (_) => _nominatimBody([
            ('Sandton, Johannesburg, Gauteng, South Africa', -26.1, 28.05),
          ]),
        ),
        placeIndex: (_) async => throw Exception('rpc missing'),
      ).search('Sandton');

      expect(hits.single.source, PlaceSource.nominatim);
    });

    // A timeout is not the same failure as an outage, and the difference is
    // the sentence the user reads.
    //
    // The index holds ~612k South African rows precisely because no OSM-backed
    // geocoder holds them. So when the index times out and the geocoders then
    // find nothing, "no matches for that address" asserts as fact the one
    // thing we know we did not check. Measured warm against the live project
    // on 2026-08-17: `Sandton` 500/57014 at 4.12s and `Durban` 500/57014 at
    // 3.22s, in the same run as five 200s.
    test('a timed-out index with nothing behind it is reported, not passed '
        'off as "no such place"', () async {
      final rec = _Recorder();
      await expectLater(
        _service(
          rec.client((_) => _nominatimBody(const [])),
          placeIndex: (q) async => throw PlaceIndexTimedOut(q),
        ).search('Westway Rd, Fourways'),
        throwsA(isA<PlaceSearchUnavailable>()),
      );
      expect(
        rec.geocoderCalls,
        isNotEmpty,
        reason:
            'the geocoders must still be given their chance — the index '
            'timing out is a reason to be honest, not a reason to stop',
      );
    });

    test(
      'a timed-out index still yields to a geocoder that CAN answer',
      () async {
        final rec = _Recorder();
        final hits = await _service(
          rec.client(
            (_) => _nominatimBody([
              ('Sandton, Johannesburg, Gauteng, South Africa', -26.1, 28.05),
            ]),
          ),
          placeIndex: (q) async => throw PlaceIndexTimedOut(q),
        ).search('Sandton');

        expect(
          hits.single.source,
          PlaceSource.nominatim,
          reason: 'a real answer beats an honest error',
        );
      },
    );

    // The other half of the same rule, pinned so the fix above cannot quietly
    // swallow it: a PAUSED extras project is a normal state (free plan, ~7
    // quiet days) and must keep costing the shortcut and nothing else.
    test(
      'an index that is merely unavailable still reads as "no such place"',
      () async {
        final rec = _Recorder();
        final hits = await _service(
          rec.client((_) => _nominatimBody(const [])),
          placeIndex: (_) async => throw Exception('project is paused'),
        ).search('Westway Rd, Fourways');

        expect(
          hits,
          isEmpty,
          reason:
              'the geocoders answered and knew nothing — that is an '
              'answer, and it must not become an error banner',
        );
      },
    );

    // Everything above injects the seam. This one exercises the REAL default,
    // `_placeIndexLookup`, which since 2026-08-16 reads the SECOND Supabase
    // project (Mine-Link_Extra_Data) through PlaceIndexConfig rather than the
    // app database — place_index was moved off main, so the RPC no longer
    // exists there at all.
    //
    // Two things must hold when that project is unconfigured or paused, and
    // paused is a NORMAL state: it is on the free plan and Supabase pauses free
    // projects after ~7 quiet days, while the picker is used irregularly.
    //   1. the lookup returns nothing instead of throwing, and
    //   2. the search still completes on the geocoders.
    // Without this the picker would go down whenever the reference database
    // did, and it would fail as a thrown exception rather than as "no results".
    test('the real place-index lookup degrades when the extras project is '
        'unconfigured', () async {
      PlaceIndexConfig.overrideForTesting(); // no url, no key
      addTearDown(PlaceIndexConfig.overrideForTesting);

      expect(PlaceIndexConfig.isConfigured, isFalse);
      expect(
        PlaceIndexConfig.client,
        isNull,
        reason:
            'an unconfigured extras project must yield no client, never '
            'a client pointed at the main database',
      );

      final rec = _Recorder();
      final hits = await PlaceSearchService(
        client: rec.client(
          (_) => _nominatimBody([
            ('Sandton, Johannesburg, Gauteng, South Africa', -26.1, 28.05),
          ]),
        ),
        minNominatimGap: Duration.zero,
        savedPlaces: (_) async => const <PlaceHit>[],
        // placeIndex deliberately NOT injected — that is the point.
      ).search('Sandton');

      expect(hits.single.source, PlaceSource.nominatim);
    });
  });

  group('a pasted point beats any geocoder', () {
    // OSM holds neither "Trumpet on Keyes" nor house number 21 on Keyes Avenue
    // (measured 2026-08-15 — Nominatim free-form AND structured, and Photon,
    // all return nothing). Pasting the link is the only keyless way to reach
    // the building itself, so it has to work.
    test('a long Google Maps URL resolves to its place pin, offline', () async {
      final rec = _Recorder();
      final hits = await _service(rec.client((_) => '[]')).search(
        'https://www.google.com/maps/place/Trumpet+on+Keyes/'
        '@-26.1447,28.0372,17z/data=!3m1!4b1!4m6!3m5!1s0x1e950d1f0!8m2!'
        '3d-26.1447329!4d28.0371884!16s%2Fg%2F11c1234',
      );

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.mapLink);
      // !3d/!4d is the PLACE pin, not the @ viewport centre — the viewport is
      // wherever the map happened to be scrolled.
      expect(hits.single.point.latitude, closeTo(-26.1447329, 0.0000001));
      expect(hits.single.point.longitude, closeTo(28.0371884, 0.0000001));
      expect(rec.calls, isEmpty, reason: 'the URL already carried the point');
    });

    test(
      'a short maps.app.goo.gl link is followed to its coordinates',
      () async {
        final client = MockClient(
          (req) async => http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://www.google.com/maps/place/Trumpet+on+Keyes/'
                  '@-26.1447,28.0372,17z/data=!8m2!3d-26.1447329!4d28.0371884',
            },
          ),
        );
        final hits = await _service(
          client,
        ).search('https://maps.app.goo.gl/aBcDeFgH1');

        expect(hits, hasLength(1));
        expect(hits.single.source, PlaceSource.mapLink);
        expect(hits.single.point.latitude, closeTo(-26.1447329, 0.0000001));
      },
    );

    test('a raw "lat, lng" pair is taken at face value', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client((_) => '[]'),
      ).search('-26.14473, 28.03719');

      expect(hits, hasLength(1));
      expect(hits.single.source, PlaceSource.coordinates);
      expect(hits.single.point.latitude, closeTo(-26.14473, 0.00001));
      expect(hits.single.point.longitude, closeTo(28.03719, 0.00001));
      expect(rec.calls, isEmpty);
    });

    test('a link that carries no point is not sent to the geocoders', () async {
      final rec = _Recorder();
      final hits = await _service(
        rec.client((_) => '[]'),
      ).search('https://example.invalid/not-a-map');

      expect(hits, isEmpty);
      expect(
        rec.geocoderCalls,
        isEmpty,
        reason:
            'a URL is never an address — four rate-limited calls to '
            'arrive at the same nothing is pure waste',
      );
    });

    test('looksLikeLink separates a URL from an address', () {
      expect(
        PlaceSearchService.looksLikeLink('https://maps.app.goo.gl/x'),
        isTrue,
      );
      expect(
        PlaceSearchService.looksLikeLink('www.google.com/maps?q=1,2'),
        isTrue,
      );
      expect(PlaceSearchService.looksLikeLink(_typed), isFalse);
      expect(PlaceSearchService.looksLikeLink('21 Keyes Ave'), isFalse);
    });
  });

  group('the dialog', () {
    Future<void> pump(WidgetTester tester, PlaceSearchService service) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: LocationPickerDialog(searchService: service)),
        ),
      );
    }

    Future<void> type(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField), q);
      // Past the 1.1s debounce, then let the search settle.
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    }

    testWidgets('says so when nothing matched, instead of going blank', (
      tester,
    ) async {
      final service = _service(
        MockClient(
          (req) async => http.Response(
            req.url.host.contains('photon')
                ? _photonBody(const [])
                : _nominatimBody(const []),
            200,
          ),
        ),
      );

      await pump(tester, service);
      await type(tester, 'qwertyuiop asdfghjkl');

      expect(
        find.textContaining('No matches for'),
        findsOneWidget,
        reason:
            'an empty result used to render nothing at all, which is what '
            'made a working search look broken',
      );
      // And it must point at the way out, because for a building OSM does not
      // hold, no amount of retyping will work.
      expect(find.textContaining('paste its link'), findsOneWidget);
    });

    testWidgets('a dud link is told apart from an address that found nothing', (
      tester,
    ) async {
      await pump(
        tester,
        _service(MockClient((_) async => http.Response('', 404))),
      );
      await type(tester, 'https://example.invalid/not-a-map');

      expect(
        find.textContaining('That link did not carry a location'),
        findsOneWidget,
      );
      expect(find.textContaining('No matches for'), findsNothing);
    });

    testWidgets('lists what it found, labelled all the way to the country', (
      tester,
    ) async {
      final service = _service(
        MockClient(
          (req) async => http.Response(
            _nominatimBody([
              (
                'Keyes Avenue, Parktown North, Rosebank, Johannesburg, '
                    'Gauteng, South Africa',
                -26.1409765,
                28.0359834,
              ),
            ]),
            200,
          ),
        ),
      );

      await pump(tester, service);
      await type(tester, _relaxed);

      expect(find.textContaining('Keyes Avenue'), findsOneWidget);
      expect(find.textContaining('South Africa'), findsOneWidget);
      expect(find.textContaining('No matches for'), findsNothing);
    });

    testWidgets(
      'picking a result drops the pin and enables the confirm button',
      (tester) async {
        final service = _service(
          MockClient(
            (req) async => http.Response(
              _nominatimBody([
                (
                  'Keyes Avenue, Rosebank, Johannesburg, South Africa',
                  -26.1409765,
                  28.0359834,
                ),
              ]),
              200,
            ),
          ),
        );

        await pump(tester, service);
        await type(tester, _relaxed);

        final confirm = find.widgetWithText(FilledButton, 'Use this location');
        expect(
          tester.widget<FilledButton>(confirm).onPressed,
          isNull,
          reason: 'nothing picked yet',
        );

        await tester.tap(find.textContaining('Keyes Avenue'));
        await tester.pump();

        expect(
          find.textContaining('Selected: -26.14098, 28.03598'),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      },
    );
  });
}

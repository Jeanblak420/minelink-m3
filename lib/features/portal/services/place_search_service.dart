import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/config/place_index_config.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/services/company_location_service.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';
import 'package:flutter_application_1/features/portal/utils/maps_short_link.dart';

/// Free, key-less geocoding for the location picker (CLAUDE.md §4 — "build it
/// 100% free, no billing, no API key"). Both hosts are overridable so a
/// self-hosted instance can replace the public one without a code change:
/// --dart-define=NOMINATIM_BASE_URL=... / PHOTON_BASE_URL=...
const kNominatimBaseUrl = String.fromEnvironment('NOMINATIM_BASE_URL',
    defaultValue: 'https://nominatim.openstreetmap.org');
const kPhotonBaseUrl = String.fromEnvironment('PHOTON_BASE_URL',
    defaultValue: 'https://photon.komoot.io');

/// `minLon,minLat,maxLon,maxLat` over southern Africa — the Atlantic off
/// Namibia to the Mozambique Channel, the Congo copper belt down to the Cape.
/// Every mine-to-port corridor MineLink runs is inside it.
///
/// Nominatim takes it as `viewbox` with `bounded=0`, which only RANKS: a
/// legitimate address elsewhere is still returned. Photon takes it as `bbox`,
/// which genuinely EXCLUDES, and there it is load-bearing rather than
/// cosmetic — measured 2026-08-15, "Richards Bay Dry Bulk Terminal" without it
/// returns a dock in Basra, Iraq as the top hit. A picked place becomes the
/// pin a driver is routed to, so a confident answer on the wrong continent is
/// worse than no answer.
const _southernAfrica = '10,-36,42,-4';

enum PlaceSource {
  /// A location this company has already saved and named. Exact, instant, and
  /// the only source that gets better with use: paste a place's link once,
  /// name it, and everyone in the org can find it by that name afterwards.
  saved,

  nominatim,
  photon,

  /// A Google Maps link the user pasted, resolved to its place pin.
  ///
  /// This is the only path that reaches building precision, and it exists
  /// because OpenStreetMap frequently does not hold the building. Measured
  /// 2026-08-15: neither Nominatim (free-form OR structured) nor Photon has
  /// any record of "Trumpet on Keyes", or of house number 21 on Keyes Avenue —
  /// the best either can return is the street centreline. Google does hold it,
  /// and a pasted link carries the coordinate without an API key or a bill.
  mapLink,

  /// MineLink's own Overture-derived place index (`place_index`). Holds South
  /// African businesses and street numbers that OSM does not — measured
  /// 2026-08-15: OSM has no Westway Road in Fourways, Overture has 15 and 39
  /// Westway Rd with coordinates.
  ///
  /// Not named `index` — that collides with `Enum.index`.
  placeIndex,

  /// A raw `lat, lng` pair typed or pasted straight in.
  coordinates,
}

class PlaceHit {
  const PlaceHit({
    required this.label,
    required this.point,
    required this.source,
    this.matchedQuery,
  });

  /// Full place context, always ending in the country, so a hit outside the
  /// region announces itself instead of hiding behind a bare street name.
  final String label;
  final LatLng point;
  final PlaceSource source;

  /// The query that actually produced this hit, when it is NOT what the user
  /// typed — i.e. the search had to broaden to find anything.
  ///
  /// This has to be surfaced. Typing "13 Westway Rd, Fourways, Sandton, 2055"
  /// and being handed "Fourways, Randburg" is the search answering a different
  /// question: OSM has no Westway Road at all, so the ladder fell back to the
  /// suburb. Offered without a caption it reads as "found your address", and
  /// the pin a driver gets sent to is 2 km from the gate.
  final String? matchedQuery;
}

/// Raised when no provider could be reached at all. Distinct from an empty
/// result list, which means the providers answered and knew nothing — the
/// picker has to tell those apart or an outage reads as "no such place".
class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable(this.cause);
  final Object cause;

  @override
  String toString() => 'PlaceSearchUnavailable: $cause';
}

/// The place index ran out of clock — Postgres `57014`, both attempts.
///
/// Deliberately NOT the same thing as the index being unavailable, and the
/// difference decides what the user is told:
///
/// * **Unavailable** (paused project, missing grant, dropped function) — the
///   index cannot answer and will not this time either. Falling through to the
///   geocoders is exactly right, and an empty result genuinely means nobody
///   knows the place. That path stays silent, by design.
/// * **Timed out** — the index is up and holds ~612k South African rows that
///   Nominatim and Photon structurally cannot hold (CLAUDE.md §4). The query
///   was fine; the clock ran out. Falling through then reporting "no such
///   place" states as fact the one thing we know we did not check.
///
/// Measured against the live extras project, warm, 2026-08-17 — eight
/// consecutive terms, two of them the country's largest business district and
/// its third-largest city:
///
/// ```
/// Sandton 4.12s 500 57014   Durban  3.22s 500 57014   Polokwane 2.58s 200
/// Rosebank 0.74s 200        Emalahleni 0.84s 200      Richards Bay 1.29s 200
/// Nelspruit 0.55s 200       Durban  3.03s 200  (the retry landing)
/// ```
class PlaceIndexTimedOut implements Exception {
  const PlaceIndexTimedOut(this.query);
  final String query;

  @override
  String toString() => 'PlaceIndexTimedOut: $query';
}

/// Address lookup for the location picker.
///
/// Nominatim alone does not fuzzy-match: a query naming a venue it does not
/// hold returns `[]`, and that is most of what a person actually types.
/// Measured against the live services on 2026-08-15:
///
/// | query                                                  | Nominatim | Photon |
/// |--------------------------------------------------------|-----------|--------|
/// | `Trumpet On Keyes, 21 Keyes Ave, Rosebank, Johannesburg` | 0        | 3      |
/// | `21 Keyes Ave, Rosebank, Johannesburg`                   | 3        | 3      |
/// | `Steelpoort chrome mine`                                 | 0        | 3      |
///
/// So the search runs in three stages, stopping at the first that answers:
///
/// 1. **Nominatim, as typed** — precise, and right for anything address-shaped.
/// 2. **Nominatim, relaxed** — drop leading comma-segments. This is what turns
///    the first row of that table into the second: the venue name is the part
///    Nominatim cannot match, and the address behind it resolves cleanly.
/// 3. **Photon** — fuzzy, and the only one of the two that finds a mine or a
///    venue by name.
class PlaceSearchService {
  PlaceSearchService({
    http.Client? client,
    this.minNominatimGap = const Duration(milliseconds: 1100),
    Future<List<PlaceHit>> Function(String query)? savedPlaces,
    Future<List<PlaceHit>> Function(String query)? placeIndex,
  })  : _client = client,
        _savedPlaces = savedPlaces ?? _companyLocationLookup,
        _placeIndex = placeIndex ?? _placeIndexLookup;

  static final _log = LoggerFactory.getLogger('PlaceSearchService');

  final http.Client? _client;

  /// Looked up before any geocoder is asked. Injected so tests need no
  /// Supabase, and so the lookup can be swapped for a wider index later.
  final Future<List<PlaceHit>> Function(String query) _savedPlaces;

  /// MineLink's own place index, asked before the third-party geocoders.
  final Future<List<PlaceHit>> Function(String query) _placeIndex;

  /// The default: `search_place_index`, over the Overture-derived table.
  ///
  /// **This reads the SECOND Supabase project**, not the app database. The
  /// place index was 413 MB of a 477 MB main database on a 500 MB free-tier
  /// ceiling, so it was moved to `Mine-Link_Extra_Data` — see
  /// [PlaceIndexConfig] and `docs/place-index-second-project-runbook.md`.
  /// [SupabaseConfig] is the wrong client for this call and would raise a
  /// "function does not exist" once the table is dropped from the main project.
  ///
  /// Degrades to nothing rather than throwing, for the same reason
  /// [_companyLocationLookup] does — and it matters more here, because that
  /// project is on the free plan and pauses after ~7 days of no traffic. An
  /// unreachable reference database must cost the shortcut, not the screen:
  /// the search falls through to Nominatim exactly as it did before this table
  /// existed.
  static Future<List<PlaceHit>> _placeIndexLookup(String query) async {
    final client = PlaceIndexConfig.client;
    if (client == null) return const [];
    try {
      List rows;
      try {
        rows = await client.rpc(
          'search_place_index',
          params: {'p_query': query, 'p_limit': 6},
        ) as List;
      } catch (e) {
        // One retry, and ONLY for a statement timeout.
        //
        // Measured against the live extras project on 2026-08-17: the search
        // is uncomfortably close to that project's ~3s `anon` statement
        // timeout even when warm — "Durban" took 3.26s and failed, "Polokwane"
        // 3.75s and failed, while "Rosebank" answered in 1.07s. A repeat of a
        // failed query usually lands (3.77s fail -> 2.13s success), because the
        // first attempt warms the pages the second one needs.
        //
        // Worth the extra wait *here specifically*: the fallback is Nominatim,
        // which reads OSM and therefore cannot answer South African addresses
        // at all (CLAUDE.md §4). Silently returning nothing costs the user the
        // address they came for.
        //
        // This is mitigation, not the fix. The fix is on the extras project and
        // needs a credential this repo does not carry:
        //   alter role anon in database postgres set statement_timeout = '8s';
        if (!isStatementTimeout(e)) rethrow;
        _log.w('place-index timed out on "$query"; retrying once');
        try {
          rows = await client.rpc(
            'search_place_index',
            params: {'p_query': query, 'p_limit': 6},
          ) as List;
        } catch (again) {
          // Both attempts ran out of clock. Escapes the outer catch as a
          // distinct type so the search can tell the user the index was not
          // consulted, instead of reporting the geocoders' silence as a fact
          // about the world. See [PlaceIndexTimedOut].
          if (isStatementTimeout(again)) throw PlaceIndexTimedOut(query);
          rethrow;
        }
      }
      return [
        for (final r in rows.cast<Map<String, dynamic>>())
          if (_point(r['lat'], r['lon']) case final LatLng p)
            PlaceHit(
              label: [
                r['name'],
                r['addr_street'],
                r['addr_locality'],
                r['addr_region'],
                r['addr_country'],
              ]
                  .map((e) => e?.toString().trim())
                  .where((s) => s != null && s.isNotEmpty)
                  .join(', '),
              point: p,
              source: PlaceSource.placeIndex,
            ),
      ];
    } on PlaceIndexTimedOut {
      // Deliberately NOT swallowed. This is the one place-index failure that
      // must not degrade quietly — see [PlaceIndexTimedOut].
      rethrow;
    } catch (e) {
      _log.w('place-index lookup unavailable: $e');
      return const [];
    }
  }

  /// Whether [error] is Postgres saying it gave up on the query.
  ///
  /// `57014` is `query_canceled`, which is what a `statement_timeout` raises.
  /// It is the ONE error worth repeating: it says the query was fine and the
  /// clock ran out. Everything else — a paused project, a missing grant, a
  /// dropped function — will fail again identically, and retrying it just makes
  /// the user wait twice before falling through to Nominatim.
  ///
  /// Matches on the code rather than the message so it does not depend on
  /// Postgres's wording, but accepts either shape because the transport is not
  /// guaranteed to surface a typed `PostgrestException`.
  @visibleForTesting
  static bool isStatementTimeout(Object error) {
    if (error is PostgrestException) return error.code == '57014';
    final s = error.toString();
    return s.contains('57014') || s.contains('canceling statement due to');
  }

  /// The default: this company's own named locations. Degrades to nothing
  /// rather than throwing — an unreachable database must cost the shortcut,
  /// not the whole search.
  static Future<List<PlaceHit>> _companyLocationLookup(String query) async {
    try {
      final saved = await CompanyLocationService().searchByName(query);
      return [
        for (final loc in saved)
          if (latLngFromMapsLink(loc.mapLink) case final LatLng p)
            PlaceHit(
              label: '${loc.name} — saved location'
                  '${loc.isPrimary ? ' (primary)' : ''}',
              point: p,
              source: PlaceSource.saved,
            ),
      ];
    } catch (e) {
      _log.w('saved-location lookup unavailable: $e');
      return const [];
    }
  }

  /// Nominatim's usage policy is an absolute maximum of 1 request/second, and
  /// clients that breach it get blocked — which would break this picker far
  /// more thoroughly than the bug this class was written to fix. The stage-2
  /// retries are back-to-back, so the gap is enforced here rather than left to
  /// the caller's debounce. Photon is a different host and is not gated by it.
  final Duration minNominatimGap;

  DateTime? _lastNominatimAt;

  /// At most this many relaxed retries, so a comma-heavy paste cannot turn into
  /// an unbounded chain of rate-limited requests.
  static const _maxRelaxedAttempts = 3;

  Future<List<PlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    // Both providers walk the SAME ladder. Photon used to be asked only for the
    // query as typed, which was useless in exactly the case it exists for: a
    // real pasted address — "ATLAS L Group, 2nd Floor, Trumpet On Keyes, 21
    // Keyes Ave, Rosebank, Johannesburg" — returns 0 from Photon at full
    // length and 3 from the same Photon once the leading segments are gone.
    // Found by driving the live dialog, not by a test; the fakes were happy.
    final ladder = [q, ...relaxations(q)];

    final client = _client ?? http.Client();

    // A pasted link or coordinate pair is not a search — it is already an
    // answer, and a more precise one than any free geocoder can give.
    final direct = await _direct(client, q);
    if (direct != null) return [direct];

    // Places this company has already named beat every geocoder: they are
    // exact, they need no network round-trip to a third party, and they are
    // the only source that improves as the platform is used.
    //
    // Guarded HERE rather than inside the lookup: this is a shortcut, and a
    // shortcut that fails must cost the shortcut, never the search. The
    // default implementation catches its own errors, but an injected one has
    // made no such promise.
    try {
      final saved = await _savedPlaces(q);
      if (saved.isNotEmpty) return saved;
    } catch (e) {
      _log.w('saved-place stage skipped for "$q": $e');
    }

    // MineLink's own index next. It is one round trip to a database we own,
    // with no rate limit and better South African street coverage than either
    // geocoder — OSM has no Westway Road in Fourways; this table has two
    // numbers on it. Inert until the Overture import has been run.
    //
    // A timeout here is remembered rather than swallowed: it is the difference
    // between "nobody holds that address" and "the one index that holds South
    // African addresses was never consulted".
    var indexTimedOut = false;
    try {
      final indexed = await _placeIndex(q);
      if (indexed.isNotEmpty) return indexed;
    } on PlaceIndexTimedOut catch (e) {
      indexTimedOut = true;
      _log.w('place-index timed out twice for "$q": $e');
    } catch (e) {
      _log.w('place-index stage skipped for "$q": $e');
    }
    // A URL is never an address. Sending it to the geocoders would waste four
    // rate-limited calls to arrive at the same nothing.
    if (looksLikeLink(q)) return const [];

    Object? firstFailure;
    var anyProviderAnswered = false;

    Future<List<PlaceHit>?> attempt(Future<List<PlaceHit>> Function() run) async {
      try {
        final hits = await run();
        anyProviderAnswered = true;
        return hits.isEmpty ? null : hits;
      } catch (e) {
        firstFailure ??= e;
        _log.w('place search stage failed for "$q": $e');
        return null;
      }
    }

    /// Stamps the query that produced them, so the picker can caption a
    /// broadened match rather than passing it off as the address typed.
    List<PlaceHit> tag(List<PlaceHit> hits, String candidate) => candidate == q
        ? hits
        : [
            for (final h in hits)
              PlaceHit(
                label: h.label,
                point: h.point,
                source: h.source,
                matchedQuery: candidate,
              ),
          ];

    try {
      // Nominatim first, whole ladder: precise, and right for anything
      // address-shaped. Rate-gapped, so this is the slow half.
      for (final candidate in ladder) {
        final hits = await attempt(() => _nominatim(client, candidate));
        if (hits != null) return tag(hits, candidate);
      }

      // Then Photon, same ladder: fuzzy, and the only one of the two that finds
      // a mine or a venue by name. Not rate-limited, so this half is quick.
      for (final candidate in ladder) {
        final hits = await attempt(() => _photon(client, candidate));
        if (hits != null) return tag(hits, candidate);
      }

      if (!anyProviderAnswered && firstFailure != null) {
        throw PlaceSearchUnavailable(firstFailure!);
      }
      // The geocoders answered and knew nothing — but the index that would
      // have known was never consulted, so "no matches" is not a fact we hold.
      // Only reached when nothing was found: a real hit from any source is
      // still a better answer than an honest error.
      if (indexTimedOut) {
        throw PlaceSearchUnavailable(PlaceIndexTimedOut(q));
      }
      return const [];
    } finally {
      if (_client == null) client.close();
    }
  }

  /// `lat, lng` typed straight in — the form the picker itself prints back
  /// under the map, so a coordinate copied from one MineLink screen pastes
  /// into another.
  static final _coordinatePair = RegExp(
    r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*[,;]\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
  );

  /// Whether this looks like a URL rather than something to geocode.
  static bool looksLikeLink(String q) {
    final s = q.trim().toLowerCase();
    return s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('www.') ||
        s.contains('maps.app.goo.gl') ||
        s.contains('google.com/maps') ||
        s.contains('openstreetmap.org');
  }

  /// A point the query already carries, or null if it carries none.
  Future<PlaceHit?> _direct(http.Client client, String q) async {
    final coords = _coordinatePair.firstMatch(q);
    if (coords != null) {
      final p = _point(coords.group(1), coords.group(2));
      if (p != null) {
        return PlaceHit(
          label: 'Coordinates ${p.latitude.toStringAsFixed(5)}, '
              '${p.longitude.toStringAsFixed(5)}',
          point: p,
          source: PlaceSource.coordinates,
        );
      }
    }

    if (!looksLikeLink(q)) return null;
    // Handles the long `/place/…!3d…!4d…` form (the place pin Google holds for
    // the building), `?q=lat,lng`, `@lat,lng`, and short maps.app.goo.gl links
    // via their redirect chain. Never throws; null when nothing parses.
    final point = await resolveMapsLink(q, client: client);
    if (point == null) return null;
    return PlaceHit(
      label: 'Pinned from map link — ${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}',
      point: point,
      source: PlaceSource.mapLink,
    );
  }

  /// The query with its leading comma-segments removed, longest first. Empty
  /// for a query with no commas — there is nothing to relax, which is why
  /// "Steelpoort chrome mine" has to reach Photon to be found at all.
  static List<String> relaxations(String query) {
    final segments = [
      for (final s in query.split(',')) s.trim(),
    ]..removeWhere((s) => s.isEmpty);
    return [
      for (var drop = 1;
          drop < segments.length && drop <= _maxRelaxedAttempts;
          drop++)
        segments.sublist(drop).join(', '),
    ];
  }

  Future<void> _respectNominatimRate() async {
    final last = _lastNominatimAt;
    if (last != null) {
      final since = DateTime.now().difference(last);
      if (since < minNominatimGap) await Future.delayed(minNominatimGap - since);
    }
    _lastNominatimAt = DateTime.now();
  }

  Future<List<PlaceHit>> _nominatim(http.Client client, String q) async {
    await _respectNominatimRate();
    final uri = Uri.parse('$kNominatimBaseUrl/search').replace(
      queryParameters: <String, String>{
        'format': 'jsonv2',
        'limit': '6',
        'q': q,
        'viewbox': _southernAfrica,
        // 0 = prefer, not restrict. A Maputo or Walvis Bay address still
        // resolves; it simply ranks below a local one.
        'bounded': '0',
      },
    );
    // Nominatim's policy requires an identifying User-Agent. Browsers refuse to
    // let a page set it and drop it silently (verified in Chrome — no throw, no
    // preflight), so on web this is inert; on mobile and desktop it is not.
    final res = await client.get(uri, headers: const {
      'User-Agent': 'MineLink/1.0 (mineral logistics app)',
    });
    if (res.statusCode != 200) {
      throw 'Address search failed (${res.statusCode})';
    }
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return [
      for (final m in list)
        if (_point(m['lat'], m['lon']) case final LatLng p)
          PlaceHit(
            label: (m['display_name'] as String?)?.trim().isNotEmpty == true
                ? (m['display_name'] as String).trim()
                : 'Location',
            point: p,
            source: PlaceSource.nominatim,
          ),
    ];
  }

  Future<List<PlaceHit>> _photon(http.Client client, String q) async {
    final uri = Uri.parse('$kPhotonBaseUrl/api/').replace(
      queryParameters: <String, String>{
        'q': q,
        'limit': '6',
        'lang': 'en',
        'bbox': _southernAfrica,
      },
    );
    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw 'Place search failed (${res.statusCode})';
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final features = (body['features'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final hits = <PlaceHit>[];
    for (final f in features) {
      final coords = (f['geometry'] as Map?)?['coordinates'] as List?;
      if (coords == null || coords.length < 2) continue;
      // GeoJSON is [lon, lat] — the reverse of every other coordinate in this
      // codebase. Swapping these silently puts the pin in the wrong hemisphere.
      final point = _point(coords[1], coords[0]);
      if (point == null) continue;
      final label = _photonLabel(
        Map<String, dynamic>.from((f['properties'] as Map?) ?? const {}),
      );
      hits.add(PlaceHit(
        label: label.isEmpty ? 'Location' : label,
        point: point,
        source: PlaceSource.photon,
      ));
    }
    return hits;
  }

  /// Photon returns fields, not a rendered address. Assembled widest-last so
  /// the label always ends in the country.
  static String _photonLabel(Map<String, dynamic> p) {
    final parts = <String>[];
    for (final key in const [
      'name',
      'housenumber',
      'street',
      'district',
      'city',
      'county',
      'state',
      'country',
    ]) {
      final v = p[key]?.toString().trim();
      if (v == null || v.isEmpty) continue;
      if (parts.isNotEmpty && parts.last == v) continue; // e.g. city == district
      parts.add(v);
    }
    return parts.join(', ');
  }

  static LatLng? _point(dynamic lat, dynamic lon) {
    final a = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final b = lon is num ? lon.toDouble() : double.tryParse('$lon');
    if (a == null || b == null) return null;
    if (a.abs() > 90 || b.abs() > 180) return null;
    return LatLng(a, b);
  }
}

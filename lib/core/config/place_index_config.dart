import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The **second** Supabase project — `Mine-Link_Extra_Data`
/// (`qbydiuplqhmkaxarnuza`), which holds bulk reference data only.
///
/// ## Why MineLink talks to two databases
///
/// Everything transactional — auth, profiles, companies, trips, stockpiles,
/// recon, targets, chat, storage — lives in the main project and is reached
/// through [SupabaseConfig]. This class is for the other one, and today it has
/// exactly one tenant: `place_index`, the Overture Maps address table behind
/// the location picker.
///
/// That table was 413 MB of a 477 MB database on a 500 MB free-tier ceiling
/// (95.4%), while all 68 other tables together came to 47 MB. It is also
/// genuinely standalone — no foreign keys in either direction, no dependent
/// views, and only `search_place_index` / `_place_index_rank` touch it — so it
/// was moved out rather than trimmed down. See
/// `docs/place-index-second-project-runbook.md`.
///
/// ## Read this before adding anything else here
///
/// **Auth does not cross the boundary.** A JWT minted by the main project's
/// GoTrue is not valid here — different project, different JWT secret. A
/// signed-in MineLink user arrives at this database as `anon`, which is why
/// `search_place_index` is granted to `anon` on this project and not only to
/// `authenticated` as it is on the main one.
///
/// That grant is safe *because of what this database contains*: nothing but
/// open Overture Maps data (CDLA-Permissive-2.0), with RLS on and no policy or
/// grant on the table itself, so the SECURITY DEFINER wrapper stays the only
/// way in. **Do not put user, company or trip data in this project** — there is
/// no session here to scope it by, and an `anon` grant over that would be a
/// data breach rather than a reference lookup.
///
/// ## Degrading
///
/// If this project is unconfigured or unreachable, [client] is null and callers
/// must fall back rather than throw. The picker already degrades to Nominatim
/// when the place index returns nothing, so an unreachable reference database
/// costs a search shortcut, not the screen.
class PlaceIndexConfig {
  static const String _configuredUrl = String.fromEnvironment(
    'PLACE_INDEX_SUPABASE_URL',
    defaultValue: '',
  );
  static const String _configuredPublishableKey = String.fromEnvironment(
    'PLACE_INDEX_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _bundledConfigAsset = 'config/place_index.live.json';

  static String _resolvedUrl = _configuredUrl;
  static String _resolvedKey = _configuredPublishableKey;
  static String _source = _configuredUrl.isNotEmpty
      ? 'PLACE_INDEX_SUPABASE_URL dart-define'
      : 'unresolved';
  static SupabaseClient? _client;

  static final _logger = LoggerFactory.getLogger('PlaceIndexConfig');

  static String get url => _resolvedUrl;
  static String get publishableKey => _resolvedKey;
  static String get configurationSource => _source;
  static bool get isConfigured => _resolvedUrl.isNotEmpty && _resolvedKey.isNotEmpty;

  /// A client for the extras project, or null when it is not configured.
  ///
  /// Deliberately **not** `Supabase.instance.client` — that singleton belongs to
  /// the main project and calling `Supabase.initialize` a second time would
  /// replace it, pointing the whole app at the wrong database.
  static SupabaseClient? get client {
    if (!isConfigured) return null;
    return _client ??= SupabaseClient(_resolvedUrl, _resolvedKey);
  }

  /// Resolves configuration. Safe to call more than once, and never throws —
  /// an unconfigured extras project is a degraded search, not a failed boot.
  static Future<void> initialize() async {
    if (_configuredUrl.isNotEmpty && _configuredPublishableKey.isNotEmpty) {
      _resolvedUrl = _configuredUrl;
      _resolvedKey = _configuredPublishableKey;
      _source = 'PLACE_INDEX_SUPABASE_URL dart-define';
      _logger.i('Place index configured from dart-define for $_resolvedUrl');
      return;
    }

    try {
      // Consult the manifest first: asking the bundle for a file that is not
      // there makes the web engine log a 404 before Dart can catch it.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(_bundledConfigAsset)) {
        _logger.i(
          'No $_bundledConfigAsset bundled — the place index is disabled and '
          'address search will fall through to Nominatim.',
        );
        return;
      }
    } catch (e) {
      _logger.d('Asset manifest unavailable, probing directly: $e');
    }

    try {
      final decoded = jsonDecode(await rootBundle.loadString(_bundledConfigAsset));
      if (decoded is! Map<String, dynamic>) {
        _logger.w('Ignoring invalid place index config at $_bundledConfigAsset');
        return;
      }
      final url = (decoded['PLACE_INDEX_SUPABASE_URL'] ?? '').toString().trim();
      final key =
          (decoded['PLACE_INDEX_SUPABASE_PUBLISHABLE_KEY'] ?? '').toString().trim();
      if (url.isEmpty || key.isEmpty) {
        _logger.w('Ignoring incomplete place index config at $_bundledConfigAsset');
        return;
      }
      _resolvedUrl = url;
      _resolvedKey = key;
      _source = '$_bundledConfigAsset bundled asset';
      _logger.i('Place index configured from $_source for $url');
    } catch (e) {
      _logger.w('Place index config unavailable, address search will fall '
          'through to Nominatim: $e');
    }
  }

  /// Test seam — lets a test point the place index somewhere else, or clear it.
  @visibleForTesting
  static void overrideForTesting({String? url, String? publishableKey}) {
    _resolvedUrl = url ?? '';
    _resolvedKey = publishableKey ?? '';
    _source = 'test override';
    _client = null;
  }
}

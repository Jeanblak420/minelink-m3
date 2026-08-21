import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The tile layer shared by every MineLink map — ONE place for the tile URL,
/// attribution, user agent and tile provider.
///
/// ## Tile host (production rollout)
/// Defaults to the community `tile.openstreetmap.org` server, which is fine
/// for development but rate-limited for commercial traffic. For production,
/// point the app at a commercial host's free tier via dart-defines — no code
/// change needed (mirrors how the Supabase config is injected):
///
/// ```
/// flutter run --dart-define=MAP_TILE_URL=https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=YOUR_KEY \
///             --dart-define=MAP_TILE_ATTRIBUTION="© Stadia Maps © OpenStreetMap contributors"
/// ```
///
/// Example URLs (all have free tiers; sign up for a key first):
/// - Stadia:  https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png?api_key=KEY
/// - MapTiler: https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=KEY
/// - Thunderforest: https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=KEY
///
/// ## Caching
/// Native targets (Android driver devices, Windows desktop) get a disk-backed
/// cache via `cached_network_image`, so previously seen tiles keep working in
/// poor-signal areas and repeat views stop re-downloading. Web keeps
/// flutter_map v8's abortable network provider (pan/zoom cancels in-flight
/// requests) + the browser's own HTTP cache — `flutter_cache_manager` has no
/// persistent store on web.
const _kTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);
const _kTileAttribution = String.fromEnvironment(
  'MAP_TILE_ATTRIBUTION',
  defaultValue: 'OpenStreetMap contributors',
);

/// Tile pixel size: 256 (OSM & most hosts) or 512 (Esri static basemap
/// tiles). 512 needs a -1 zoom offset so labels render at the right scale.
const _kTileSize = int.fromEnvironment('MAP_TILE_SIZE', defaultValue: 256);

/// The tile provider every map uses, replaceable by a test.
///
/// `_CachedTileProvider` goes through `flutter_cache_manager`, which keeps a
/// **housekeeping timer** alive on its `CacheStore` — and a pending timer fails
/// a widget test outright: *"A Timer is still pending even after the widget
/// tree was disposed"*, thrown by the binding AFTER the body has finished, with
/// the golden already written. The console's live map hit it the first time it
/// was rendered; the phone frame survived only because it asks for fewer tiles.
///
/// There is no way to render a map in a test without this seam, which is the
/// same reason `routingServiceProvider` and [MlTime.debugClock] exist. A test
/// installs `NetworkTileProvider()` — flutter_map's own, and the one this app
/// ALREADY ships on web — so the swap exercises a real code path rather than a
/// stub written for the harness.
///
/// **Never set outside a test.** Nothing in `lib/` writes it.
@visibleForTesting
TileProvider Function()? mlTileProviderOverride;

TileLayer mlOsmTileLayer() => TileLayer(
      urlTemplate: _kTileUrl,
      userAgentPackageName: 'com.flutter_application_1.app',
      tileDimension: _kTileSize,
      zoomOffset: _kTileSize == 512 ? -1 : 0,
      tileProvider: mlTileProviderOverride?.call() ??
          (kIsWeb ? NetworkTileProvider() : _CachedTileProvider()),
    );

/// What a map shows where a tile has not arrived.
///
/// `MapOptions.backgroundColor` defaults to `0xFFE0E0E0` — near-white — and not
/// one of the five `MapOptions` in this app set it. In a dark console that is a
/// **large white rectangle**, and it is not only a test artefact: it is the
/// first paint of every map before any tile lands, every map on a bad
/// connection, and the whole map offline. Photographed 2026-08-21 on the
/// console's live map, where the trucks float on a sheet of near-white in an
/// otherwise navy screen.
///
/// `surfaceSunken` is the token for "a well the content sits in", which is
/// exactly what an un-tiled map is, and it moves with the theme — so a light
/// build still gets a light ground rather than this being a dark-mode patch.
Color mlMapBackground(BuildContext context) =>
    MlSemantic.of(context).surfaceSunken;

/// Matching attribution overlay — add as the LAST child of every FlutterMap
/// so the credit always names whichever host [mlOsmTileLayer] is serving.
Widget mlMapAttribution() => RichAttributionWidget(
      animationConfig: const ScaleRAWA(),
      attributions: const [
        TextSourceAttribution(_kTileAttribution, prependCopyright: false),
      ],
    );

class _CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedNetworkImageProvider(
        getTileUrl(coordinates, options),
        headers: headers,
      );
}

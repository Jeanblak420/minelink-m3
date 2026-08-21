import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
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

/// The tile layer, **turned dark when the app is dark**.
///
/// ## Why this exists
///
/// Every tile host the product can be pointed at serves a LIGHT basemap — OSM
/// standard, Esri streets, Stadia osm_bright. `flutter_test` answers every HTTP
/// request with a 400, so in 218 renders no tile ever arrived and the map was
/// judged on its background colour alone. Driving the built app in a browser on
/// 2026-08-21 was the first time tiles had ever been seen in this product, and
/// the console's live map came out as **a bright beige rectangle in the middle
/// of a navy console** — brighter than anything else on the screen, next to a
/// card of dark chrome, at the biggest size any single element gets.
///
/// The sibling note on [mlMapBackground] fixed the *un-tiled* ground on the
/// same day and stopped one step short: it made the map dark until the tiles
/// landed.
///
/// ## Why a filter rather than a dark tile host
///
/// A dark basemap (Carto dark_matter and friends) would mean a second provider,
/// a second attribution, a second rate limit and a second thing to configure —
/// and it would be undone the moment somebody sets `MAP_TILE_URL` to their own
/// host, which is exactly what the docs above tell them to do for production.
/// A filter is applied to whatever host is configured, so the map stays in
/// theme however it is served.
///
/// ## The matrix
///
/// Invert, then hue-rotate 180°, composed into one matrix — the standard
/// treatment, and the composition matters. Inversion ALONE turns green parks
/// magenta and blue water orange; rotating the hue back puts them where a
/// reader expects. Checked by hand before it was written:
///
/// | in | out |
/// |---|---|
/// | white `255,255,255` (paper) | `0,0,0` |
/// | black `0,0,0` (label ink) | `255,255,255` |
/// | park `200,230,200` | `12,42,12` — still green |
/// | water `170,210,240` | `18,58,88` — still blue |
///
/// Each row of the hue-rotate matrix sums to 1 (it preserves luminance), which
/// is why every translation term here is exactly 255 rather than three
/// different numbers.
///
/// **Only the tiles are filtered.** The markers, the route line, the truck
/// puck and the attribution are siblings in `FlutterMap.children`, so they keep
/// their own colours — inverting those would turn the brand cyan into a muddy
/// orange and the "loaded" green into magenta.
Widget mlOsmTiles(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (!dark) return mlOsmTileLayer();
  return ColorFiltered(
    colorFilter: _darkenTiles,
    child: mlOsmTileLayer(),
  );
}

const ColorFilter _darkenTiles = ColorFilter.matrix(<double>[
  0.574, -1.430, -0.144, 0, 255, //
  -0.426, -0.430, -0.144, 0, 255, //
  -0.426, -1.430, 0.856, 0, 255, //
  0, 0, 0, 1, 0, //
]);

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

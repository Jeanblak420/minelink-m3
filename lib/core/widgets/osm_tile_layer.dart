import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

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

TileLayer mlOsmTileLayer() => TileLayer(
      urlTemplate: _kTileUrl,
      userAgentPackageName: 'com.flutter_application_1.app',
      tileDimension: _kTileSize,
      zoomOffset: _kTileSize == 512 ? -1 : 0,
      tileProvider: kIsWeb ? NetworkTileProvider() : _CachedTileProvider(),
    );

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

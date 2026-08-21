// The basemap has to be in theme, and the things drawn ON it must not be.
//
// No render could have found this. `flutter_test` answers every HTTP request
// with a 400, so across 218 renders not one map tile ever arrived and every map
// was judged on its background colour alone. The first time tiles were seen in
// this product was 2026-08-21, driving the built web app in a browser: the
// console's live map was a bright beige rectangle in the middle of a navy
// console — the brightest thing on the screen, at the largest size any single
// element gets.
//
// So the check cannot be a picture either. It asserts the SHAPE: in dark, the
// tile layer sits under a `ColorFiltered`; in light it does not; and the
// filter's arithmetic is checked against the four colours the doc comment on
// `mlOsmTiles` claims for it, so the table there is a measurement rather than a
// note.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';

/// Applies the filter the way the engine does: a row of five is
/// `[r, g, b, a, translation]`, and the translation is in 0–255.
List<int> _apply(List<double> m, List<int> rgb) {
  final out = <int>[];
  for (var i = 0; i < 3; i++) {
    final row = m.sublist(i * 5, i * 5 + 5);
    final v = row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2] + row[4];
    out.add(v.clamp(0, 255).round());
  }
  return out;
}

Future<void> _pumpMap(WidgetTester tester, Brightness brightness) async {
  mlTileProviderOverride = () => NetworkTileProvider();
  addTearDown(() => mlTileProviderOverride = null);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness),
      home: Scaffold(
        body: Builder(
          builder: (context) => FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(-26.0, 28.0),
              backgroundColor: mlMapBackground(context),
            ),
            children: [mlOsmTiles(context)],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('in DARK the tiles are filtered', (tester) async {
    await _pumpMap(tester, Brightness.dark);

    expect(
      find.ancestor(
        of: find.byType(TileLayer),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
      reason: 'a light basemap in a navy console is the brightest thing on '
          'the screen',
    );
  });

  testWidgets('in LIGHT the tiles are left alone', (tester) async {
    await _pumpMap(tester, Brightness.light);

    expect(
      find.ancestor(
        of: find.byType(TileLayer),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
      reason: 'the hosts all serve a light basemap, which is already right '
          'for a light build — filtering it would invert it into a dark map '
          'on a white page',
    );
  });

  testWidgets('only the TILES are filtered, never what is drawn on them',
      (tester) async {
    mlTileProviderOverride = () => NetworkTileProvider();
    addTearDown(() => mlTileProviderOverride = null);

    const markerKey = Key('a-truck');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(-26.0, 28.0),
                backgroundColor: mlMapBackground(context),
              ),
              children: [
                mlOsmTiles(context),
                const MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(-26.0, 28.0),
                      child: ColoredBox(
                        key: markerKey,
                        color: Color(0xFF22D3EE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byKey(markerKey),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
      reason: 'inverting the overlays would turn the brand cyan muddy orange '
          'and the "loaded" green magenta',
    );
  });

  testWidgets('the filter does what its doc comment says', (tester) async {
    await _pumpMap(tester, Brightness.dark);

    // Read off the pumped tree, so the table in the doc comment and the
    // constant in the code cannot drift apart.
    final filtered = tester.widget<ColorFiltered>(
      find.ancestor(
        of: find.byType(TileLayer),
        matching: find.byType(ColorFiltered),
      ),
    );
    expect(
      filtered.colorFilter,
      const ColorFilter.matrix(_expected),
      reason: 'the shipped filter is not the one this file measures',
    );

    expect(_apply(_expected, [255, 255, 255]), [0, 0, 0],
        reason: 'white paper must go black');
    expect(_apply(_expected, [0, 0, 0]), [255, 255, 255],
        reason: 'black label ink must go white');

    final park = _apply(_expected, [200, 230, 200]);
    expect(park, [12, 42, 12]);
    expect(park[1], greaterThan(park[0]),
        reason: 'a park must stay green, not turn magenta');
    expect(park[1], greaterThan(park[2]));

    final water = _apply(_expected, [170, 210, 240]);
    expect(water, [18, 58, 88]);
    expect(water[2], greaterThan(water[1]),
        reason: 'water must stay blue, not turn orange');
    expect(water[2], greaterThan(water[0]));
  });
}

const List<double> _expected = <double>[
  0.574, -1.430, -0.144, 0, 255, //
  -0.426, -0.430, -0.144, 0, 255, //
  -0.426, -1.430, 0.856, 0, 255, //
  0, 0, 0, 1, 0, //
];

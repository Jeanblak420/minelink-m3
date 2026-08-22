// The map controls, and the three states of the my-location button.
//
// Added 2026-08-22 on jean's instruction: *"for the driver side map there needs
// to be a button to re-center and or re-focus … on the user's current location
// for incase he swipes on the map to check something. also add more functions
// and features to the maps which are similar to google map's mobile features"*.
//
// Two things are asserted that a picture cannot show:
//
//   * the ZOOM BUTTONS ACTUALLY MOVE THE CAMERA. A render photographs a `+`
//     that may or may not be wired to anything, and this whole control column
//     is new — nothing else in the product would notice if `_zoomBy` were a
//     no-op.
//   * the my-location button is ABSENT, not merely dim, when there is nothing
//     to centre on. The first render of the live map showed a permanently
//     crossed-out location disc on a two-truck fleet map, which reads as a
//     broken control rather than an inapplicable one.
//
// Touch targets are measured rather than trusted: this is used one-handed, in
// a moving truck, and 48 is the Material minimum.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/design/components/ml_map_controls.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';

import '../../test_helpers/real_fonts.dart';

Finder get _zoomIn => find.byKey(const ValueKey('map-zoom-in'));
Finder get _zoomOut => find.byKey(const ValueKey('map-zoom-out'));
Finder get _recenter => find.byKey(const ValueKey('map-recenter'));
Finder get _overview => find.byTooltip('Show everything');
Finder get _compass => find.byTooltip('Point the map north');

const _somewhere = LatLng(-25.7461, 28.1881);

/// A real `FlutterMap` under the controls, because the controls read
/// `MapController.camera` — which THROWS until the map has been laid out once,
/// and that guard is one of the things worth proving.
Future<MapController> _pump(
  WidgetTester tester, {
  bool hasFix = true,
  bool following = false,
  VoidCallback? onRecenter,
  VoidCallback? onOverview,
  bool allowRotation = true,
  bool withMap = true,
}) async {
  // flutter_test answers every HTTP request with a 400, so a real network tile
  // provider logs a storm of failures. The app's own seam, same as the render
  // harness uses.
  mlTileProviderOverride = NetworkTileProvider.new;
  addTearDown(() => mlTileProviderOverride = null);

  final controller = MapController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: Scaffold(
        body: Stack(
          children: [
            if (withMap)
              FlutterMap(
                mapController: controller,
                options: const MapOptions(
                  backgroundColor: Color(0xFF0B1524),
                  initialCenter: _somewhere,
                  initialZoom: 12,
                ),
                children: const [],
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: MlMapControls(
                controller: controller,
                hasFix: hasFix,
                following: following,
                onRecenter: onRecenter,
                onOverview: onOverview,
                allowRotation: allowRotation,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  setUpAll(loadRealFonts);

  group('zoom', () {
    testWidgets('the + and - buttons really move the camera', (tester) async {
      final c = await _pump(tester, onRecenter: () {});
      final before = c.camera.zoom;

      await tester.tap(_zoomIn);
      await tester.pump();
      expect(c.camera.zoom, greaterThan(before),
          reason: 'the + button did nothing');

      final zoomedIn = c.camera.zoom;
      await tester.tap(_zoomOut);
      await tester.pump();
      expect(c.camera.zoom, lessThan(zoomedIn),
          reason: 'the - button did nothing');
    });

    testWidgets('zoom does not drift the centre', (tester) async {
      // Google Maps zooms about the centre. Moving the map sideways while
      // zooming would lose whatever the driver was looking at.
      final c = await _pump(tester, onRecenter: () {});
      final centre = c.camera.center;
      await tester.tap(_zoomIn);
      await tester.pump();
      expect(c.camera.center.latitude, closeTo(centre.latitude, 0.0001));
      expect(c.camera.center.longitude, closeTo(centre.longitude, 0.0001));
    });

    testWidgets('zoom is clamped to a level tiles exist at', (tester) async {
      // Unclamped, flutter_map accepts zoom 30 and then asks the host for a
      // tile that does not exist — which a driver reads as the map going
      // blank, not as a bad number.
      final c = await _pump(tester, onRecenter: () {});
      for (var i = 0; i < 25; i++) {
        await tester.tap(_zoomIn);
        await tester.pump();
      }
      expect(c.camera.zoom, lessThanOrEqualTo(19.0));

      for (var i = 0; i < 40; i++) {
        await tester.tap(_zoomOut);
        await tester.pump();
      }
      expect(c.camera.zoom, greaterThanOrEqualTo(2.0));
    });

    testWidgets('a tap before the map has laid out does not throw',
        (tester) async {
      // `MapController.camera` throws "You need to have the FlutterMap widget
      // rendered at least once before using the MapController". These controls
      // are built in the same frame as the map they sit on.
      await _pump(tester, onRecenter: () {}, withMap: false);
      await tester.tap(_zoomIn);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the my-location button', () {
    testWidgets('is ABSENT when the map has no "me"', (tester) async {
      await _pump(tester, onRecenter: null);
      expect(_recenter, findsNothing,
          reason: 'a fleet map has no user position; the control must not be '
              'drawn at all rather than drawn dead');
      // The rest of the column is still there.
      expect(_zoomIn, findsOneWidget);
    });

    testWidgets('is present but not tappable when there is no fix yet',
        (tester) async {
      var taps = 0;
      await _pump(tester, hasFix: false, onRecenter: () => taps++);
      expect(_recenter, findsOneWidget);
      expect(find.byIcon(Icons.location_disabled_rounded), findsOneWidget);

      await tester.tap(_recenter);
      await tester.pump();
      expect(taps, 0, reason: 'there is no position to centre on');
    });

    testWidgets('says whether it is following, and calls back when tapped',
        (tester) async {
      var taps = 0;
      await _pump(tester, hasFix: true, following: false,
          onRecenter: () => taps++);
      // Not following: the hollow "searching" icon, Google's own distinction.
      expect(find.byIcon(Icons.location_searching_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsNothing);

      await tester.tap(_recenter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('following is the filled icon', (tester) async {
      await _pump(tester, hasFix: true, following: true, onRecenter: () {});
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byIcon(Icons.location_searching_rounded), findsNothing);
    });
  });

  group('overview', () {
    testWidgets('absent unless the caller offers one', (tester) async {
      await _pump(tester, onRecenter: () {});
      expect(_overview, findsNothing);
    });

    testWidgets('calls back when tapped', (tester) async {
      var taps = 0;
      await _pump(tester, onRecenter: () {}, onOverview: () => taps++);
      await tester.tap(_overview);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('the compass', () {
    testWidgets('is hidden while the map points north', (tester) async {
      await _pump(tester, onRecenter: () {});
      expect(_compass, findsNothing,
          reason: 'a compass that always points up is decoration');
    });

    testWidgets('appears once the map is turned, and puts north back',
        (tester) async {
      final c = await _pump(tester, onRecenter: () {});
      c.rotate(40);
      // The controls listen to the map's event stream, so the rebuild lands
      // on the frame after the rotation.
      await tester.pump();
      await tester.pump();
      expect(_compass, findsOneWidget);

      await tester.tap(_compass);
      await tester.pump();
      expect(c.camera.rotation, closeTo(0, 0.01));
    });

    testWidgets('never appears on a map that cannot rotate', (tester) async {
      // The live map and the truck-locations map exclude rotation from their
      // interaction flags, so a compass there could only ever point north.
      final c = await _pump(tester, onRecenter: () {}, allowRotation: false);
      c.rotate(40);
      await tester.pump();
      await tester.pump();
      expect(_compass, findsNothing);
    });
  });

  testWidgets('every control meets the 48px touch minimum', (tester) async {
    // Used one-handed, in a moving truck, sometimes with gloves on.
    await _pump(tester, onRecenter: () {}, onOverview: () {});
    for (final f in <Finder>[_zoomIn, _zoomOut, _recenter, _overview]) {
      final r = tester.getRect(f);
      expect(r.width, greaterThanOrEqualTo(48),
          reason: 'control is ${r.width}px wide');
      expect(r.height, greaterThanOrEqualTo(48),
          reason: 'control is ${r.height}px tall');
    }
  });
}

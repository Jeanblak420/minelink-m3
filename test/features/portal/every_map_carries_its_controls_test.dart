// Every map a person can touch has controls, and answers a long press.
//
// The components added on 2026-08-22 ([MlMapControls], [MlDroppedPinSheet])
// are tested in `test/core/design/`. This file is the other half: that the
// maps actually MOUNT them. A control column nobody puts on a map is a
// component with a passing test and no effect, and the product had exactly
// that shape before — five `FlutterMap`s and one control between them.
//
// Source-reading, with comments STRIPPED first. A `contains` check that
// matches the prose explaining a rule, rather than the code obeying it, is a
// green test over nothing — which is how a chat test passed on 2026-08-22 by
// matching the comment describing the bug it was written for. Every doc block
// in these files quotes `onLongPress` and `MlMapControls` by name.
//
// A widget test would be better and is not available: mounting `LiveTripMapView`
// means standing up Supabase, the live-tracking stream, the hazard provider and
// a company scope, to assert one constructor argument.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Maps a person can pan, and what each must carry.
const _interactiveMaps = <String, String>{
  'lib/features/portal/screens/driver_navigation_screen.dart':
      "the driver's turn-by-turn map",
  'lib/features/portal/widgets/live_trip_map_view.dart': 'the live trip map',
  'lib/features/portal/widgets/vehicle_positions_map.dart':
      'the truck-locations map',
  'lib/features/portal/widgets/location_picker.dart': 'the location picker',
};

/// The one map that must NOT have controls, and why.
///
/// `super_admin_company_mirror_screen.dart` draws a map preview with
/// `InteractiveFlag.none`, inside an `IgnorePointer`, inside a `GestureDetector`
/// whose tap opens the real map. The whole tile is a button. Controls there
/// would be controls on a picture of a map — and the long-press would fight
/// the tap that opens it.
const _deliberatelyInert =
    'lib/features/super_admin/screens/super_admin_company_mirror_screen.dart';

/// [path]'s source with `//` and `///` comments removed.
String _codeOnly(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path has moved');
  return f
      .readAsLinesSync()
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');
}

void main() {
  group('every interactive map', () {
    _interactiveMaps.forEach((path, what) {
      test('$what answers a long press', () {
        expect(
          _codeOnly(path),
          contains('onLongPress:'),
          reason: 'press-and-hold does nothing on $what. Every MapOptions in '
              'this product left onLongPress null until 2026-08-22, which is '
              'the gap jean asked to close.',
        );
      });
    });

    // The picker owns its long press for its own purpose — it is how a pin is
    // placed — so it does not mount the dropped-pin sheet. It still needs the
    // zoom column, which is checked below.
    for (final path in const [
      'lib/features/portal/screens/driver_navigation_screen.dart',
      'lib/features/portal/widgets/live_trip_map_view.dart',
      'lib/features/portal/widgets/vehicle_positions_map.dart',
    ]) {
      test('${_interactiveMaps[path]} opens the shared dropped-pin sheet', () {
        expect(
          _codeOnly(path),
          contains('showMlDroppedPin('),
          reason: 'holding a finger on this map must say where that is, and '
              'through the ONE sheet — four maps drifting into four detail '
              'panels is what the component layer exists to stop',
        );
      });
    }

    _interactiveMaps.forEach((path, what) {
      test('$what carries the control column', () {
        expect(
          _codeOnly(path),
          contains('MlMapControls('),
          reason: 'no zoom buttons and no way back on $what',
        );
      });
    });

    _interactiveMaps.forEach((path, what) {
      test('$what credits OpenStreetMap', () {
        // The driver's navigation map was the only one of the five without
        // this, and it is the fullscreen one a driver looks at for an hour.
        // The licence asks for the credit.
        expect(
          _codeOnly(path),
          contains('mlMapAttribution('),
          reason: '$what shows OSM tiles with no attribution',
        );
      });
    });

    _interactiveMaps.forEach((path, what) {
      test('$what shows a scale', () {
        expect(
          _codeOnly(path),
          contains('mlMapScaleBar('),
          reason: 'without a scale, $what asks the reader to guess whether a '
              'gap is 200 m or 20 km — on a haul road that is the difference '
              'between "just there" and half an hour',
        );
      });
    });
  });

  group('the deliberately inert preview', () {
    test('has no controls, and is still a real map preview', () {
      final src = _codeOnly(_deliberatelyInert);
      expect(
        src,
        isNot(contains('MlMapControls(')),
        reason: 'this tile is a BUTTON that opens the real map — see the note '
            'at the top of this file. If it has become pannable, it should '
            'join _interactiveMaps rather than quietly gain half a treatment.',
      );
      expect(
        src,
        contains('InteractiveFlag.none'),
        reason: 'the exemption above rests on this map being un-pannable',
      );
      // The symmetric half: it is still a map, and still credits OSM.
      expect(src, contains('mlMapAttribution('));
    });
  });
}

// How a coordinate, a distance and a direction are written.
//
// Pure functions, so this is the cheap half of the map work added on
// 2026-08-22 — and it is where the two arithmetic traps live:
//
//   1. `%` on a negative double is NEGATIVE in Dart, so an un-normalised
//      `atan2` bearing returns -90 where it means 270 and every westward
//      heading names a compass point on the wrong side of the map.
//   2. The sixteen-point compass's FIRST sector straddles north, so the index
//      needs half a segment of offset. Without it 350° reads "NNW".
//
// Both are the kind of thing that looks right in the source and is wrong on
// the screen, which is why they are asserted against hand-worked answers
// rather than against a re-implementation of the same formula.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/utils/geo_format.dart';

// Iron Hills Mining's neighbourhood, so the numbers are the product's own.
const _mine = LatLng(-25.7461, 28.1881);

void main() {
  group('mlLatLngText', () {
    test('six places, signed, padded', () {
      expect(mlLatLngText(_mine), '-25.746100, 28.188100');
    });

    test('a whole number still shows its places', () {
      // The case a bare toString() gets wrong: `-26.0, 28.0`.
      expect(mlLatLngText(const LatLng(-26, 28)), '-26.000000, 28.000000');
    });
  });

  group('mlBearingDeg', () {
    test('due north is 0', () {
      expect(mlBearingDeg(_mine, const LatLng(-25.6461, 28.1881)), closeTo(0, 0.5));
    });

    test('due east is 90', () {
      expect(mlBearingDeg(_mine, const LatLng(-25.7461, 28.2881)), closeTo(90, 0.5));
    });

    test('due south is 180', () {
      expect(
        mlBearingDeg(_mine, const LatLng(-25.8461, 28.1881)),
        closeTo(180, 0.5),
      );
    });

    test('due WEST is 270, not -90', () {
      // THE TRAP. `atan2` answers -90 here, and Dart's `%` keeps the sign, so
      // an un-normalised result stays negative and `mlCompassPoint` indexes
      // off the front of the table.
      final west = mlBearingDeg(_mine, const LatLng(-25.7461, 28.0881));
      expect(west, closeTo(270, 0.5));
      expect(west, greaterThanOrEqualTo(0),
          reason: 'a bearing is never negative; see the note above');
    });

    test('every answer is inside [0, 360)', () {
      for (var dLat = -1.0; dLat <= 1.0; dLat += 0.25) {
        for (var dLng = -1.0; dLng <= 1.0; dLng += 0.25) {
          if (dLat == 0 && dLng == 0) continue;
          final b = mlBearingDeg(
            _mine,
            LatLng(_mine.latitude + dLat, _mine.longitude + dLng),
          );
          expect(b, greaterThanOrEqualTo(0));
          expect(b, lessThan(360));
        }
      }
    });
  });

  group('mlCompassPoint', () {
    test('the cardinals', () {
      expect(mlCompassPoint(0), 'N');
      expect(mlCompassPoint(90), 'E');
      expect(mlCompassPoint(180), 'S');
      expect(mlCompassPoint(270), 'W');
    });

    test('north STRADDLES the first sector', () {
      // The half-segment offset. Without it these read NNW and NNE.
      expect(mlCompassPoint(350), 'N');
      expect(mlCompassPoint(11), 'N');
      expect(mlCompassPoint(359.9), 'N');
    });

    test('the sixteen-point names', () {
      expect(mlCompassPoint(22.5), 'NNE');
      expect(mlCompassPoint(45), 'NE');
      expect(mlCompassPoint(135), 'SE');
      expect(mlCompassPoint(225), 'SW');
      expect(mlCompassPoint(315), 'NW');
    });

    test('a negative or over-turned input is normalised', () {
      expect(mlCompassPoint(-90), 'W');
      expect(mlCompassPoint(450), 'E');
    });
  });

  group('mlDistanceText', () {
    test('metres below a kilometre', () {
      expect(mlDistanceText(0), '0 m');
      expect(mlDistanceText(820), '820 m');
      expect(mlDistanceText(999.4), '999 m');
    });

    test('one decimal of a kilometre above it', () {
      expect(mlDistanceText(1000), '1.0 km');
      expect(mlDistanceText(12449), '12.4 km');
    });

    test('a broken number says so rather than printing NaN', () {
      expect(mlDistanceText(double.nan), '—');
      expect(mlDistanceText(double.infinity), '—');
    });
  });

  group('mlRelativePositionText', () {
    test('names the distance and the direction', () {
      // ~0.09° of latitude north ≈ 10 km.
      final text = mlRelativePositionText(
        _mine,
        LatLng(_mine.latitude + 0.09, _mine.longitude),
      );
      expect(text, isNotNull);
      expect(text, contains('km'));
      expect(text, endsWith('N of you'));
    });

    test('says nothing about "you" when there is no you', () {
      // The whole reason this returns null: the live map is watched by office
      // staff whose position the app does not know, and "12 km NE of you"
      // there is a claim about somebody sitting in another province.
      expect(mlRelativePositionText(null, _mine), isNull);
    });

    test('does not claim a direction the hardware cannot support', () {
      // A few metres away is inside GPS noise; naming a compass point for it
      // would be inventing precision.
      final text = mlRelativePositionText(
        _mine,
        LatLng(_mine.latitude + 0.00002, _mine.longitude),
      );
      expect(text, 'where you are standing');
    });
  });
}

// A distance in a chip row has to say what it measures.
//
// `TransportationRequest.distance` is free text a requester typed, and they
// have not been consistent. Read off the transporter's Routes & dispatches
// screen as `roadhaul.admin`, 2026-08-23 — nine cards, one column:
//
//     640 km · 620 · 640 · 640 km · (none) · (none) · 520 km · 120 · 120
//
// Four with a unit, three without, two absent. A bare `120` in a chip row
// beside `2 trucks` and `R 1000.00 / ton` does not say whether it is
// kilometres, tons or something else — and it is the number a transporter
// costs the job from.
//
// `tonsAvailable`, the same kind of field, already goes through `mlCountText`
// at every site, so it always carries the word "tons". Distance was the last
// member of that family with nothing on it.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/ml_count.dart';

void main() {
  group('a bare number gets the unit', () {
    test('the three live values that had none', () {
      expect(mlDistanceText('620'), '620 km');
      expect(mlDistanceText('640'), '640 km');
      expect(mlDistanceText('120'), '120 km');
    });

    test('decimals and padding', () {
      expect(mlDistanceText('12.5'), '12.5 km');
      expect(mlDistanceText('  640  '), '640 km');
    });
  });

  group('anything the requester wrote in words is left exactly as typed', () {
    test('the ones that already had a unit', () {
      expect(mlDistanceText('640 km'), '640 km');
      expect(mlDistanceText('520 km'), '520 km');
    });

    test('a unit written without a space', () {
      expect(mlDistanceText('640km'), '640km');
    });

    test('a DIFFERENT unit is not overwritten', () {
      // The whole reason this only touches bare numbers. Appending "km" here
      // would change what the requester said, on the figure a transporter
      // prices the job from.
      expect(mlDistanceText('620 miles'), '620 miles');
      expect(mlDistanceText('about 600 km'), 'about 600 km');
    });
  });

  group('nothing typed is nothing shown', () {
    test('null, empty and whitespace all drop the chip', () {
      expect(mlDistanceText(null), isNull);
      expect(mlDistanceText(''), isNull);
      expect(mlDistanceText('   '), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart';

/// A real `valhalla1.openstreetmap.de` leg shape, captured 2026-08-16 for the
/// live Durban Port trip's load leg (Sandton → Iron Hills Mining's primary
/// collection point). Truck costing, `units: kilometers`; the reply's own
/// summary says **10.011 km / 1152 s over 9 maneuvers**, which is what the
/// decode is checked against.
///
/// A synthetic shape would not have caught the defect this guards. The deltas
/// that break under dart2js are the FIRST pair — a whole coordinate, ~26 bits
/// — and every hand-written fixture in this file starts near zero.
const _liveValhallaShape =
    r'''bpbwp@mi`ot@qYas@oK_VwKdAmMpAaQvDoVbG}_A~Zw@V{zAxg@{jCn|@y]xMuAp@mAj@us@h\qZfN}P|KyJvJmAbBsAvBqAdCaPl\cBnGeDnHyPj_@uZdl@}HdRwF~M}Pji@eKd^uHz\sExRoD~OuCzOiF|m@eBnd@qAf{@Ftj@DjXm@~NwApKmDdMsIrUyBtEg@nBSvDT~Cl@jBlAbBpDhDdDbFnBvFhAfGjE~Zn@zAh@`CnAfHp@pEnC|Nl@nFfAjGbDjTtApHNfA\dCx@bFTnA~Z`{BbNn{@vCfQ|Fb_@NtANfAp@fF|G`h@lGv`@fCtO|Fd[~D|UnD`T|AzKvB~Nb@xC`AtLR|DDpCExCYxCQdBs@xHkAfJg@fEeA|JSlBy@rGyAUoAOmC_@s[wE}JyA_UuCsMiA{E[wPg@iLU_KEoI?yPPcJPsFRwLh@eId@qIl@iThCkTtCi[`GsVvE{uA~WijAhT_UbEcWxEyB^wKrBqr@fN_iAvSmVlEmKpAkMzAiLnAeN`By@JmANaNbBoOnB}VrDcO~BclAjR}i@xI{Cf@uEn@sa@jHm]nGmi@nKkS~Dwk@nL{FbAoJrBcIxA_wAjWu{@xPg\bGyYnGqa@vJ{Bh@wU|Cc_@bCsUzAia@`EaUv@eg@vCgBJm\`Bw^`CwSfBeOfBiFlAqLtBoJ`B{StEqNrDoTxGaD|@{HnCaLlEsElBqWzL_QnK_O~Ky[tUm`@x`@cE|E{A|BcAlAi@p@oh@vn@aQpUaa@hg@mJvL{\tb@wCnDkKxL_FzFq_@|X}k@dZeh@jWyTzLoz@|c@{BlAqMpHeKdGwCfBmo@r\wD|ByFvCgj@~ZoAr@i`@hS}NvHqIbEmQ`HwDxAuFxBcDpA{x@p[c^tMqKfDo`@lJkPdDaAVl@xO`BnUnCh\tB``@j@nSH`KlDj[v@bHlAdPrL~}A|Et\hJpb@tKr^sv@|YmNxB{\l@k`@c@sQy@aOuB{c@kJkg@yLsb@_B{`@`A?VCXITMTQNSHWFrAfh@l@zUKdYyBf`@_DYsLiA''';

double _pathLengthM(List<LatLng> points) {
  const d = Distance();
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += d.as(LengthUnit.Meter, points[i - 1], points[i]);
  }
  return total;
}

void main() {
  group('encodePolyline5 / decodePolyline5', () {
    test('round-trips within 1e-5 (the trip_nav_state watcher contract)', () {
      const points = [
        LatLng(-26.204103, 28.047305),
        LatLng(-26.195246, 28.034088),
        LatLng(-25.746111, 28.188056),
        LatLng(0.0, 0.0),
        LatLng(-25.7461117, 28.1880565), // sub-precision digits get rounded
      ];
      final decoded = decodePolyline5(encodePolyline5(points));
      expect(decoded.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(decoded[i].latitude, closeTo(points[i].latitude, 1e-5));
        expect(decoded[i].longitude, closeTo(points[i].longitude, 1e-5));
      }
    });

    test('matches the known OSRM reference encoding', () {
      // Google's documented polyline-5 example.
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final decoded = decodePolyline5(encoded);
      expect(decoded, const [
        LatLng(38.5, -120.2),
        LatLng(40.7, -120.95),
        LatLng(43.252, -126.453),
      ]);
      expect(encodePolyline5(decoded), encoded);
    });
  });

  group('decodeValhallaShape6 — a real 10 km leg', () {
    // This is the shape of the bug fixed on 2026-08-16: on the web the codec
    // used to decode this exact string to a first point of (4268.882158,
    // 28.050087) and a 599 295 km path, because Dart's `~` is unsigned 32-bit
    // under dart2js. The assertions below are the numbers Valhalla itself
    // reports, so any drift back into bitwise arithmetic fails loudly.
    //
    // NOTE: this test passes on the VM even with the bug present — the VM was
    // never wrong. What actually holds the line on the web is the
    // `no-bitwise-in-polyline-codec` release guard; this test holds the maths.
    test('decodes to the geometry Valhalla says it sent', () {
      final points = decodeValhallaShape6(_liveValhallaShape);
      expect(points.length, 255);
      expect(points.first.latitude, closeTo(-26.085138, 1e-9));
      expect(points.first.longitude, closeTo(28.050087, 1e-9));
      expect(points.last.latitude, closeTo(-26.028474, 1e-9));
      expect(points.last.longitude, closeTo(28.001773, 1e-9));
      // Valhalla's own summary: 10.011 km. Allow 100 m for the difference
      // between its road-length sum and a haversine walk of the shape.
      expect(_pathLengthM(points), closeTo(10011, 100));
      // Every point must be a real coordinate — the failure mode being
      // guarded is coordinates leaving the planet, not small drift.
      for (final p in points) {
        expect(p.latitude.abs(), lessThanOrEqualTo(90));
        expect(p.longitude.abs(), lessThanOrEqualTo(180));
      }
    });

    test('survives the precision-5 round trip published to watchers', () {
      // `trip_nav_state.route_polyline` is precision-5 by contract, so a
      // Valhalla route is re-encoded before it leaves the device. Watchers
      // must get back the same road, to within the 1e-5 the format allows.
      final points = decodeValhallaShape6(_liveValhallaShape);
      final roundTripped = decodePolyline5(encodePolyline5(points));
      expect(roundTripped.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(roundTripped[i].latitude, closeTo(points[i].latitude, 1e-5));
        expect(roundTripped[i].longitude, closeTo(points[i].longitude, 1e-5));
      }
      expect(_pathLengthM(roundTripped), closeTo(10011, 150));
    });

    test('a truncated shape stops cleanly instead of throwing', () {
      // A short read on a haul road must degrade, not crash the nav screen.
      expect(
          () => decodeValhallaShape6(
              _liveValhallaShape.substring(0, 40)),
          returnsNormally);
    });
  });

  group('decodeValhallaShape6', () {
    test('decodes at 1e6 precision (10x finer than polyline-5)', () {
      // The same deltas decoded at 1e6 must equal the 1e5 result / 10.
      const encoded = '_p~iF~ps|U_ulLnnqC';
      final p5 = decodePolyline5(encoded);
      final p6 = decodeValhallaShape6(encoded);
      expect(p6.length, p5.length);
      for (var i = 0; i < p5.length; i++) {
        expect(p6[i].latitude, closeTo(p5[i].latitude / 10, 1e-9));
        expect(p6[i].longitude, closeTo(p5[i].longitude / 10, 1e-9));
      }
    });
  });

  group('NavStep.fromValhalla', () {
    const shape = [
      LatLng(-26.1, 28.0),
      LatLng(-26.2, 28.1),
      LatLng(-26.3, 28.2),
    ];

    test('maps numeric maneuver types onto NavManeuver', () {
      NavStep step(int type) =>
          NavStep.fromValhalla({'type': type, 'begin_shape_index': 1}, shape);
      expect(step(1).maneuver, NavManeuver.depart);
      expect(step(4).maneuver, NavManeuver.arrive);
      expect(step(10).maneuver, NavManeuver.turnRight);
      expect(step(15).maneuver, NavManeuver.turnLeft);
      expect(step(26).maneuver, NavManeuver.roundabout);
      expect(step(8).maneuver, NavManeuver.continueStraight);
    });

    test('converts km to meters and resolves the shape location', () {
      final step = NavStep.fromValhalla({
        'type': 10,
        'length': 1.25, // km
        'time': 90,
        'begin_shape_index': 2,
        'street_names': ['R59'],
      }, shape);
      expect(step.distanceM, closeTo(1250, 1e-9));
      expect(step.durationS, 90);
      expect(step.location, shape[2]);
      expect(step.roadName, 'R59');
      expect(step.instruction, 'Turn right onto R59');
    });

    test('tolerates missing fields and out-of-range indices', () {
      final step = NavStep.fromValhalla({'begin_shape_index': 99}, shape);
      expect(step.location, shape.last);
      expect(step.maneuver, NavManeuver.continueStraight);
      final empty = NavStep.fromValhalla(const {}, const []);
      expect(empty.location, const LatLng(0, 0));
    });
  });
}

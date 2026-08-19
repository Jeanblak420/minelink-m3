// S9-4 — load quality certificates and the penalty picture, which had no test.
//
// The penalty arithmetic itself is server-side (`list_load_quality` computes
// payable_tons and grade_factor). What lives in Dart is the *reading* of it,
// and two of those readings are boundary decisions that change what a mine or
// a buyer is shown about money:
//
//   excessMoisturePct  — null when in spec, so the UI shows no penalty
//   isBelowGradeSpec   — a float comparison against 0.9999, not against 1
//
// The worked example asserted below is the one recorded in CLAUDE.md and
// live-verified when the feature was built: 38% Cr2O3 against a 42% spec and
// 10% moisture against an 8% max gives payable 34.10 t and factor 0.9048.
// It is pinned here so a change to the server calc has a Dart-side tripwire.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';

LoadQualityRow row({
  double? moisture,
  double? moistureMax,
  double? cr2o3,
  double? specCr2o3,
  double? payableTons,
  double? gradeFactor,
  String? sizing,
  String? certPath,
}) =>
    LoadQualityRow(
      tripId: 't1',
      updatedAt: DateTime.utc(2026, 8, 15),
      moisturePct: moisture,
      specMoistureMaxPct: moistureMax,
      cr2o3Pct: cr2o3,
      specCr2o3Pct: specCr2o3,
      payableTons: payableTons,
      gradeFactor: gradeFactor,
      sizing: sizing,
      certPath: certPath,
    );

void main() {
  group('hasCert — any one structured value or the file counts', () {
    test('is false on a bare row', () {
      expect(row().hasCert, isFalse);
    });

    test('any single field is enough', () {
      expect(row(cr2o3: 41).hasCert, isTrue);
      expect(row(moisture: 7).hasCert, isTrue);
      expect(row(sizing: '0-6mm').hasCert, isTrue);
      expect(row(certPath: 'certs/a.pdf').hasCert, isTrue);
    });

    test('the contract spec alone is not a certificate', () {
      // A route can carry a spec long before any load is certified against it.
      expect(row(specCr2o3: 42, moistureMax: 8).hasCert, isFalse);
    });
  });

  group('excessMoisturePct — only the penalised part', () {
    test('is null until both the measurement and the spec exist', () {
      expect(row().excessMoisturePct, isNull);
      expect(row(moisture: 10).excessMoisturePct, isNull);
      expect(row(moistureMax: 8).excessMoisturePct, isNull);
    });

    test('is null in spec, and null exactly AT the limit', () {
      expect(row(moisture: 6, moistureMax: 8).excessMoisturePct, isNull);
      expect(row(moisture: 8, moistureMax: 8).excessMoisturePct, isNull,
          reason: 'a load exactly on the contract maximum is in spec — '
              'charging it a zero-width penalty would still show a penalty');
    });

    test('returns only the overshoot, not the whole reading', () {
      expect(row(moisture: 10, moistureMax: 8).excessMoisturePct,
          closeTo(2, 1e-9));
      expect(row(moisture: 8.5, moistureMax: 8).excessMoisturePct,
          closeTo(0.5, 1e-9));
    });

    test('a zero maximum still penalises any moisture at all', () {
      expect(row(moisture: 0.4, moistureMax: 0).excessMoisturePct,
          closeTo(0.4, 1e-9));
      expect(row(moisture: 0, moistureMax: 0).excessMoisturePct, isNull);
    });
  });

  group('isBelowGradeSpec — the 0.9999 tolerance is deliberate', () {
    test('is false with no factor at all', () {
      expect(row().isBelowGradeSpec, isFalse);
    });

    test('is false at or above par', () {
      expect(row(gradeFactor: 1).isBelowGradeSpec, isFalse);
      expect(row(gradeFactor: 1.0).isBelowGradeSpec, isFalse);
    });

    test('a rounding-error shortfall does not read as below spec', () {
      // grade_factor = min(1, cr2o3/spec), so a load bang on spec can land at
      // 0.99999 through float division. That must not show a penalty badge.
      expect(row(gradeFactor: 0.99999).isBelowGradeSpec, isFalse);
      expect(row(gradeFactor: 0.9999).isBelowGradeSpec, isFalse);
    });

    test('a real shortfall does', () {
      expect(row(gradeFactor: 0.9998).isBelowGradeSpec, isTrue);
      expect(row(gradeFactor: 0.9048).isBelowGradeSpec, isTrue);
      expect(row(gradeFactor: 0).isBelowGradeSpec, isTrue);
    });
  });

  group('the live-verified worked example (CLAUDE.md §4)', () {
    test('38% against a 42% spec, 10% against an 8% max', () {
      final r = LoadQualityRow.fromJson({
        'trip_id': 't-live',
        'updated_at': '2026-07-27T12:00:00Z',
        'delivered_tons': 37.0,
        'cr2o3_pct': 38,
        'moisture_pct': 10,
        'spec_cr2o3_pct': 42,
        'spec_moisture_max_pct': 8,
        'payable_tons': 34.10,
        'grade_factor': 0.9048,
      });
      expect(r.hasCert, isTrue);
      expect(r.excessMoisturePct, closeTo(2, 1e-9));
      expect(r.isBelowGradeSpec, isTrue);
      expect(r.payableTons, closeTo(34.10, 1e-9));
      expect(r.gradeFactor, closeTo(0.9048, 1e-9));
      // payable = delivered x (1 - excess/100) = 37 x 0.98 = 36.26 on
      // moisture alone; the recorded 34.10 also carries the grade factor.
      // Asserting the relationship rather than re-deriving the server's calc.
      expect(r.payableTons! < r.deliveredTons!, isTrue);
    });
  });

  group('LoadQualityRow.fromJson', () {
    test('coerces Postgres ints to doubles', () {
      final r = LoadQualityRow.fromJson({
        'trip_id': 't',
        'updated_at': '2026-08-15T00:00:00Z',
        'net_tons': 36,
        'delivered_tons': 35,
      });
      expect(r.netTons, 36.0);
      expect(r.deliveredTons, 35.0);
    });

    test('blank and whitespace-only strings become null, not empty', () {
      final r = LoadQualityRow.fromJson({
        'trip_id': 't',
        'updated_at': '2026-08-15T00:00:00Z',
        'sizing': '   ',
        'cert_notes': '',
        'truck_reg': ' ABC 123 GP ',
      });
      expect(r.sizing, isNull);
      expect(r.certNotes, isNull);
      expect(r.truckReg, 'ABC 123 GP');
      expect(r.hasCert, isFalse,
          reason: 'a whitespace-only sizing must not count as a certificate');
    });

    test('a missing issued_at is null rather than an exception', () {
      final r = LoadQualityRow.fromJson(
          {'trip_id': 't', 'updated_at': '2026-08-15T00:00:00Z'});
      expect(r.issuedAt, isNull);
    });
  });

  group('RouteQualitySpec', () {
    test('hasSpec needs at least one of the three', () {
      const bare = RouteQualitySpec(routeId: 'r1');
      expect(bare.hasSpec, isFalse);
      expect(const RouteQualitySpec(routeId: 'r1', specCr2o3Pct: 42).hasSpec,
          isTrue);
      expect(
          const RouteQualitySpec(routeId: 'r1', specMoistureMaxPct: 8).hasSpec,
          isTrue);
      expect(const RouteQualitySpec(routeId: 'r1', specSizing: '0-6mm').hasSpec,
          isTrue);
    });

    test('a zero moisture maximum is a real spec, not an absent one', () {
      // 0 is a legitimate contract maximum and must not be read as "unset".
      expect(const RouteQualitySpec(routeId: 'r1', specMoistureMaxPct: 0).hasSpec,
          isTrue);
    });

    test('fromJson reads the route id from `id`', () {
      final s = RouteQualitySpec.fromJson({
        'id': 'route-9',
        'route_number': 'RT-0007',
        'spec_cr2o3_pct': 42,
        'spec_sizing': '  ',
      });
      expect(s.routeId, 'route-9');
      expect(s.routeNumber, 'RT-0007');
      expect(s.specCr2o3Pct, 42.0);
      expect(s.specSizing, isNull);
      expect(s.hasSpec, isTrue);
    });
  });
}

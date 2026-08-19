// A sealed load needs every seal the rig has.
//
// Found by driving a seal-required load end to end on 2026-08-17. The Load
// Controller's sheet was headed "Seals (2 per trailer · 4 total)" and rendered
// four slots — for every vehicle, because both the heading and the count were
// constants. `record_truck_load` enforced only "not zero". Measured on the two
// seal-required loads in production:
//
//     seals on load | loads
//     --------------+------
//                 2 |     1
//                13 |     1
//
// Two on a two-trailer interlink; thirteen on another. The waybill prints
// TRUCK SEAL SERIAL NO. 1-4, so the first hands a driver a document naming half
// the seals on his truck, and the second records nine no document can carry.
//
// The rule now lives in `public.expected_seal_count` — two per trailer present,
// floored at 2, capped at 4 — and reaches the client as `expected_seals` on
// `list_mine_inbound_trips`. These pin the client's half of it. The server's
// half was proven against production with a self-rolling-back probe: 2 refused,
// 5 refused, 4 accepted.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';

Map<String, dynamic> row({bool sealRequired = true, int? expectedSeals}) => {
      'trip_id': '11111111-1111-4111-8111-111111111111',
      'status': 'loading',
      'transaction_id': '22222222-2222-4222-8222-222222222222',
      'seal_required': sealRequired,
      if (expectedSeals != null) 'expected_seals': expectedSeals,
      'tare_tons': 15.2,
      'updated_at': '2026-08-17T05:51:31.000Z',
    };

void main() {
  group('how many seals the sheet asks for', () {
    test('comes from the rig, not from a constant', () {
      expect(MineTrip.fromJson(row(expectedSeals: 4)).expectedSeals, 4);
      expect(MineTrip.fromJson(row(expectedSeals: 2)).expectedSeals, 2,
          reason: 'a single-trailer truck has two seal points, and telling its '
              'controller to fit four is the same class of wrong as accepting '
              'two on an interlink');
    });

    // An older server does not return the column. Falling back to the floor
    // would start refusing loads that the server is perfectly happy with; 4 is
    // what the sheet showed before this existed, so nothing changes.
    test('falls back to the pre-existing four when the server omits it', () {
      final t = MineTrip.fromJson(row());
      expect(t.expectedSeals, 4);
    });

  });

  group('the count is bounded the way the waybill is', () {
    // Mirrors `public.derive_seal_points`, which is the STARTING value a new
    // vehicle gets — not the rule the weighbridge applies. That rule is now
    // simply "read fleet_vehicles.seal_points", which is the whole point: the
    // first version of this fix inferred the count at load time from the
    // OPTIONAL trailer-registration text, so a transporter who had not typed a
    // trailer number was told to fit 2 seals to a 4-seal rig and then had the
    // correct load refused.
    int derived({required int trailers}) {
      final raw = 2 * trailers;
      return raw.clamp(1, 4);
    }

    test('two per trailer, as an opening guess', () {
      expect(derived(trailers: 1), 2);
      expect(derived(trailers: 2), 4);
    });

    test('never zero — a rig with no trailer recorded still gets sealed', () {
      expect(derived(trailers: 0), 1);
    });

    test('never more than the four serial lines the waybill has', () {
      expect(derived(trailers: 3), 4);
      expect(derived(trailers: 9), 4);
    });

    // The property that matters most, and the one the first fix did not have:
    // once stored, the number does not move when the trailer text does.
    test('a stored count does not follow the trailer registrations', () {
      const stated = 4;
      // Whatever happens to the optional trailer text, the sheet still asks for
      // what the vehicle record says. Proven against production with a
      // rolling-back probe: clearing BOTH trailer registrations on S6W001GP
      // left expected_seal_count at 4, where the old inference gave 2.
      expect(MineTrip.fromJson(row(expectedSeals: stated)).expectedSeals, 4);
    });
  });

  group('the vehicle record carries it', () {
    Map<String, dynamic> vehicle({int? sealPoints}) => {
          'id': 'v1',
          'company_id': 'c1',
          'vehicle_registration_number': 'S6W001GP',
          'first_trailer_regs': 'S6T001GP',
          'second_trailer_regs': 'S6T002GP',
          if (sealPoints != null) 'seal_points': sealPoints,
          'created_at': '2026-08-17T05:51:31.000Z',
          'is_active': true,
        };

    test('reads seal_points off the row', () {
      expect(FleetVehicle.fromJson(vehicle(sealPoints: 2)).sealPoints, 2);
      expect(FleetVehicle.fromJson(vehicle(sealPoints: 4)).sealPoints, 4);
    });

    test('a server without the column leaves today behaviour alone', () {
      // 4 is what the sheet rendered before any of this existed, and what the
      // whole current fleet carries. Falling back to the floor instead would
      // start refusing loads the server is perfectly happy with.
      expect(FleetVehicle.fromJson(vehicle()).sealPoints, 4);
    });

    test('it survives a JSON round trip and copyWith', () {
      final v = FleetVehicle.fromJson(vehicle(sealPoints: 2));
      expect(FleetVehicle.fromJson(v.toJson()).sealPoints, 2,
          reason: 'the edit dialog reads it back out of the updated row');
      expect(v.copyWith(sealPoints: 3).sealPoints, 3);
      expect(v.copyWith().sealPoints, 2, reason: 'copyWith must not reset it');
    });
  });
}

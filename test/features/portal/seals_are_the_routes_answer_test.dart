// The sheet a transporter accepts from must state the condition their driver
// will actually be judged by.
//
// `transportation_requests.seal_required` and `routes.seal_required` are two
// columns, and they diverge: the platform admin sets the route's condition at
// linking, while the request carries whatever the requester ticked.
//
// Measured on production while driving a load through the whole mine floor,
// 2026-08-23 — route `56a1209a`, RT-DDC02437:
//
//     transportation_requests.seal_required   false
//     routes.seal_required                    true
//
// `record_truck_load` reads the ROUTE. So the Load Controller's sheet opened on
// "Seals (4 on this rig) — SEALS REQUIRED" and would refuse the load without
// four numbered, photographed seals, while the route sheet the transporter had
// accepted from read "Seals — Not required". The admin had written "Seals
// required on this route" into the free-text notes, which is the only place a
// transporter could have learned it.
//
// A transporter that believes the sheet sends a truck with no seals and their
// driver is turned away at the weighbridge, 640 km from home.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/transportation_request.dart';

TransportationRequest _request({required bool sealRequired}) =>
    TransportationRequest(
      id: 'req-1',
      requestingCompanyId: 'mine-1',
      requestType: 'transportation',
      status: RequestStatus.linked,
      createdAt: DateTime.utc(2026, 8, 17, 3, 43),
      updatedAt: DateTime.utc(2026, 8, 17, 3, 43),
      sealRequired: sealRequired,
    );

DispatchedRoute _dispatch({
  required bool requestSeal,
  bool? routeSeal,
}) =>
    DispatchedRoute(
      dispatchId: 'd-1',
      transporterCompanyId: 't-1',
      status: DispatchStatus.dispatched,
      dispatchedAt: DateTime.utc(2026, 8, 17, 3, 43),
      routeId: 'route-1',
      routeNumber: 'RT-DDC02437',
      routeSealRequired: routeSeal,
      request: _request(sealRequired: requestSeal),
    );

void main() {
  test('the ROUTE wins when the two disagree — the live case', () {
    final d = _dispatch(requestSeal: false, routeSeal: true);

    expect(d.sealRequired, isTrue,
        reason: 'the request says no and the route says yes. The weighbridge '
            'reads the route, so the transporter has to be told yes.');
  });

  test('and it wins in the other direction too', () {
    // Not symmetry for its own sake: an admin can also RELAX the condition at
    // linking, and a sheet that kept saying "Required" would have a
    // transporter fitting seals nobody asks for.
    final d = _dispatch(requestSeal: true, routeSeal: false);

    expect(d.sealRequired, isFalse);
  });

  test('with no route row yet, the request is all there is', () {
    final d = _dispatch(requestSeal: true, routeSeal: null);

    expect(d.sealRequired, isTrue);
    expect(_dispatch(requestSeal: false, routeSeal: null).sealRequired, isFalse);
  });

  test('agreement is unremarkable and stays that way', () {
    expect(_dispatch(requestSeal: true, routeSeal: true).sealRequired, isTrue);
    expect(_dispatch(requestSeal: false, routeSeal: false).sealRequired, isFalse);
  });

  test('the flag is parsed off the embedded routes row', () {
    // The parse half. The FETCH half cannot be reached from here — it is a
    // PostgREST select string — so it has its own case below.
    final d = DispatchedRoute.fromJson({
      'id': 'd-1',
      'transporter_company_id': 't-1',
      'status': 'dispatched',
      'dispatched_at': '2026-08-17T01:43:00Z',
      'route_id': 'route-1',
      'routes': {'route_number': 'RT-DDC02437', 'seal_required': true},
      'transportation_requests': {
        'id': 'req-1',
        'requesting_company_id': 'mine-1',
        'request_type': 'transportation',
        'status': 'linked',
        'created_at': '2026-08-17T01:43:00Z',
        'updated_at': '2026-08-17T01:43:00Z',
        'seal_required': false,
      },
    });

    expect(d.routeSealRequired, isTrue);
    expect(d.request.sealRequired, isFalse);
    expect(d.sealRequired, isTrue);
  });

  test('the service actually ASKS for the column', () {
    // Everything above is true of a row that already carries `seal_required`.
    // If the embedded select stops fetching it, `routeSealRequired` is null on
    // every row, the getter falls back to the request, and the whole fix
    // silently reverts to the state that sent a truck 640 km without seals —
    // with every test above still green.
    //
    // A network select string is not reachable from a unit test, so read the
    // source. `readAsStringSync` in a plain `test`, never inside
    // `testWidgets`, where real file I/O does not complete.
    final source = File(
      'lib/features/portal/services/request_service.dart',
    ).readAsStringSync();

    expect(source, contains("routes(route_number, seal_required)"),
        reason: 'listTransporterDispatches no longer fetches '
            '`routes.seal_required`, so the route sheet is back to showing '
            "the REQUEST's flag — which said 'Not required' on a route the "
            'weighbridge refuses without four seals.');
  });
}

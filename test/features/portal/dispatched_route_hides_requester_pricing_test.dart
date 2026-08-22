// The transporter must never be able to derive the platform admin's margin.
//
// CLAUDE.md §4: *"The transporter only ever sees their resulting price, never
// the admin's margin."* `DispatchedRoute`'s own doc comment says it twice, and
// the admin's due-diligence preview dialog says it to the admin's face —
// *"The transporter never sees your margin — only this price."* — in the last
// dialog before dispatch.
//
// It was not true. Driven on the live app on 2026-08-22 as
// `roadhaul.admin@mineralguide.com`, the route-detail sheet for a route
// dispatched minutes earlier printed, four rows apart in one grid:
//
//     Your price / ton    R 820.00
//     Rate                950
//
// R950 − R820 = R130, the exact margin the admin had typed. The list card
// behind it carried `950` as a chip.
//
// Nothing in the suite could see it, for two reasons this file fixes together:
// the leak itself, and the fixture that hid it — `_request` set no `rate`, so
// the surface had nothing to leak in a render. `rate` is deliberately set now.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/widgets/dispatch_route_widgets.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

/// A dispatch row exactly as PostgREST hands it over, including the three
/// columns a transporter is not entitled to. If the narrowed `select` in
/// `RequestService.listTransporterDispatches` is ever widened back to `*`,
/// this is the shape that arrives.
Map<String, dynamic> _rowWithRequesterPricing() => {
      'id': 'dsp-1',
      'transporter_company_id': 'co-t',
      'status': 'dispatched',
      'dispatched_at': '2026-08-22T01:30:04Z',
      'transporter_price_per_ton': 820.0,
      'route_id': 'rt-1',
      'routes': {'route_number': 'RT-52619BC4'},
      'transportation_requests': {
        'id': 'r-1',
        'requesting_company_id': 'co-b',
        'buyer_company_id': 'co-b',
        'supplier_company_id': 'co-m',
        'request_type': 'transportation',
        'status': 'linked',
        'commodity': 'Chrome Ore',
        'distance': '620',
        'tons_available': '120',
        'num_slots': '1',
        'payment_terms': '30 days',
        'diesel': 'On transporter',
        'contract_duration': '30 days',
        'operating_hours_24h': true,
        'seal_required': false,
        'loading_point': 'Iron Hills Mining - primary collection point',
        'offloading_point': 'Richards Bay Dry Bulk Terminal, Berth 704',
        'route_notes': 'M3 end-to-end verification run.',
        'starting_date': '2026-08-24',
        'ending_date': '2026-09-23',
        'is_ongoing': false,
        'created_at': '2026-08-22T01:26:58Z',
        'updated_at': '2026-08-22T01:30:04Z',
        // The three that must not survive the parse.
        'rate': '950',
        'price_per_ton': 1200.0,
        'admin_notes': 'Phoned the buyer — they will re-send with the assay.',
      },
    };

void main() {
  setUpAll(loadRealFonts);

  group('DispatchedRoute drops the requester-only columns', () {
    test('rate, price_per_ton and admin_notes never reach the model', () {
      final route = DispatchedRoute.fromJson(_rowWithRequesterPricing());

      expect(route.request.rate, isNull,
          reason: "the buyer's rate is the admin's margin, restated");
      expect(route.request.pricePerTon, isNull);
      expect(route.request.adminNotes, isNull);

      // The transporter's own price is untouched — it is theirs to see.
      expect(route.transporterPricePerTon, 820.0);
    });

    // Guards the narrowed column list in
    // `RequestService.listTransporterDispatches`. Drop a column from it and
    // the transporter's route sheet renders a blank row rather than throwing,
    // which is exactly the kind of silence this repo keeps being caught by.
    test('every field the transporter surfaces read still arrives', () {
      final r = DispatchedRoute.fromJson(_rowWithRequesterPricing()).request;

      expect(r.commodity, 'Chrome Ore');
      expect(r.distance, '620');
      expect(r.tonsAvailable, '120');
      expect(r.numSlots, '1');
      expect(r.paymentTerms, '30 days');
      expect(r.diesel, 'On transporter');
      expect(r.contractDuration, '30 days');
      expect(r.operatingHours24h, isTrue);
      expect(r.sealRequired, isFalse);
      expect(r.loadingPoint, 'Iron Hills Mining - primary collection point');
      expect(r.offloadingPoint, 'Richards Bay Dry Bulk Terminal, Berth 704');
      expect(r.routeNotes, 'M3 end-to-end verification run.');
      expect(r.startingDate, isNotNull);
      expect(r.endingDate, isNotNull);
      expect(r.isOngoing, isFalse);
      expect(r.supplierCompanyId, 'co-m');
    });
  });

  group('the transporter surfaces themselves', () {
    // The fixture request DOES carry rate '950' (see `_request`). If the card
    // ever renders `r.rate` again, this fails.
    testWidgets('the route card shows the transporter price, not the rate',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(Brightness.dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DispatchRouteCard(
                  route: kDispatches.first,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('950'), findsNothing);
      expect(find.text('R 410.00 / ton'), findsOneWidget);
      // The rest of the card is unchanged.
      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('620 km'), findsOneWidget);
    });

    testWidgets('the route-detail sheet has no Rate row at all',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(Brightness.dark),
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => showDispatchedRouteDetailSheet(
                      context: context,
                      ref: ref,
                      route: kDispatches.first,
                      companyId: 'co-transporter',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Your price / ton'), findsOneWidget);
      expect(find.text('R 410.00'), findsOneWidget);

      // The label is gone, and so is the value it used to carry.
      expect(find.text('Rate'), findsNothing);
      expect(find.text('950'), findsNothing);

      // And the sheet still says everything else it is meant to.
      expect(find.text('RT-0042'), findsOneWidget);
      expect(find.text('620 km'), findsOneWidget);
      expect(find.text('On transporter'), findsOneWidget);
    });
  });
}

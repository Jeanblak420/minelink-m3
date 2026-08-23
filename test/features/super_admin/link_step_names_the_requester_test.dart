// The link step's "…asked for" line names whoever raised the request.
//
// Mines raise transport requests too — their own haul, no buyer on it yet —
// and on 2026-08-23, linking one, the admin was told that the BUYER asked for
// a loading point the mine had typed, on a request with no buyer at all. The
// same class of slip as the send-back dialog's "to buyer", fixed earlier.
//
// Sabotage: hard-code 'Buyer' back into the line in `_DispatchStep` and the
// mine case fails; the buyer case stays green, so the fix is proven not to
// have flipped the label the other way.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_review_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/frozen_clock.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/test_supabase.dart';

TransportationRequest _approved({
  required String id,
  required String requester,
  required String orgType,
  required String offloading,
  String? buyer,
}) =>
    TransportationRequest(
      id: id,
      requestingCompanyId: requester,
      buyerCompanyId: buyer,
      requestType: 'transportation',
      status: RequestStatus.approved,
      loadingPoint: 'Iron Hills Mining — primary collection point',
      offloadingPoint: offloading,
      commodity: 'Chrome Ore',
      tonsAvailable: '2400',
      numSlots: '2',
      paymentTerms: '30 days',
      createdAt: DateTime(2026, 8, 23),
      updatedAt: DateTime(2026, 8, 23),
      requesterOrgType: orgType,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<TransportationRequest> queue,
  required String origin,
}) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...companyScopeOverrides(),
      ...portalTailOverrides(),
      ...portalCaptureOverrides(),
    ],
    child: MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: ProviderScope(
        overrides: [
          adminRequestQueueProvider.overrideWith((ref, _) async => queue),
        ],
        child: Scaffold(
          body: RequestReviewScreen(
            requestType: 'transportation',
            origin: origin,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadRealFonts);
  setUpAll(ensureTestSupabaseInitialized);
  setUp(freezeCaptureClock);

  testWidgets('a mine-raised request says the MINE asked for the point',
      (tester) async {
    await _pump(
      tester,
      origin: 'mine',
      queue: [
        _approved(
          id: 'mine-req',
          requester: 'co-mine',
          orgType: 'mineSupplier',
          offloading: 'Saldanha Bay Ore Terminal, Berth 2',
        ),
      ],
    );
    await tester.tap(find.textContaining('Saldanha Bay Ore Terminal').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Mine asked for:'), findsOneWidget);
    expect(find.textContaining('Buyer asked for:'), findsNothing);
  });

  testWidgets('a buyer-raised request still says the BUYER asked for it',
      (tester) async {
    await _pump(
      tester,
      origin: 'buyer',
      queue: [
        _approved(
          id: 'buyer-req',
          requester: 'co-buyer',
          buyer: 'co-buyer',
          orgType: 'buyer',
          offloading: 'Atlas Buyer Group, Vanderbijlpark works',
        ),
      ],
    );
    await tester.tap(find.textContaining('Vanderbijlpark works').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Buyer asked for:'), findsOneWidget);
    expect(find.textContaining('Mine asked for:'), findsNothing);
  });
}

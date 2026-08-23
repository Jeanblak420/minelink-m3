// A truck that has left the mine is in transit, on every surface that draws it.
//
// Buyer pass, 2026-08-23 (reviewer finding #4, seen in
// `dash-buyer-desktop-light`). The "Trucks inbound" KPI was `MlTone.atMine` —
// the amber CLAUDE.md §5 defines as "at mine / pending" — while its own
// sublabel read "Left the mine, not yet offloaded", the live strip eighty
// lines below it toned the SAME trips `transit`, and the mine dashboard's
// identically-named KPI is `transit`. One set of trips, two colours, one
// screen, and the tile's colour contradicting the tile's own caption.
//
// `inbound` is every trip at or past `leftMine` and before `offloaded`, so
// there was nothing to weigh up.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/frozen_clock.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/test_supabase.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    await ensureTestSupabaseInitialized();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget dashboard, {
    required OrgType orgType,
  }) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authOverride(userType: UserType.employee),
          companyOverride(orgType: orgType),
          employeeOverride(orgType: orgType),
          ...portalTailOverrides(),
          ...portalCaptureOverrides(),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: dashboard),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The tone the KPI labelled [label] was actually built with.
  ///
  /// `PortalKpi` is a data class, not a widget — it is read off the
  /// `PortalKpiRow` the dashboard hands it to.
  MlTone toneOf(WidgetTester tester, String label) => tester
      .widgetList<PortalKpiRow>(find.byType(PortalKpiRow))
      .expand((row) => row.kpis)
      .firstWhere(
        (k) => k.label == label,
        orElse: () => throw StateError('no "$label" KPI on this dashboard'),
      )
      .tone;

  test('the trips the tile counts really are on the road', () {
    // The window `inbound` uses. If either bound moves, the tone stops being
    // the obvious answer and this should be re-read rather than re-fixed.
    expect(TripStatus.leftMine.step,
        greaterThan(TripStatus.arrivedAtMine.step));
    expect(TripStatus.offloaded.step, greaterThan(TripStatus.leftMine.step));
    expect(TripStatus.enRouteToOffload.step,
        inInclusiveRange(TripStatus.leftMine.step,
            TripStatus.offloaded.step - 1));
  });

  testWidgets('the buyer\'s "Trucks inbound" tile is toned transit', (
    tester,
  ) async {
    await mount(
      tester,
      const BuyerPortalDashboardScreen(),
      orgType: OrgType.buyer,
    );

    expect(
      toneOf(tester, 'Trucks inbound'),
      MlTone.transit,
      reason:
          'amber means AT THE MINE (CLAUDE.md §5); this tile counts trucks '
          'that have left it, which is what its own sublabel says',
    );
    expect(toneOf(tester, 'Trucks inbound'), isNot(MlTone.atMine));
  });

  // The GREEN case, and the reason this is not a matter of taste: the mine
  // dashboard has a KPI with the SAME LABEL and it was already transit. Two
  // dashboards disagreeing about one word is the fault; this keeps them
  // agreeing, in both directions.
  testWidgets('the mine\'s KPI of the same name is toned the same way', (
    tester,
  ) async {
    await mount(
      tester,
      const MineSupplierPortalDashboardScreen(),
      orgType: OrgType.mineSupplier,
    );
    expect(toneOf(tester, 'Trucks inbound'), MlTone.transit);
  });

  // And the other tones on the buyer's band are untouched — a sweep that
  // recoloured everything would pass the two assertions above.
  testWidgets('the rest of the buyer band keeps its own tones', (
    tester,
  ) async {
    await mount(
      tester,
      const BuyerPortalDashboardScreen(),
      orgType: OrgType.buyer,
    );

    expect(toneOf(tester, 'Tons delivered'), isNot(MlTone.transit));
    expect(toneOf(tester, 'Payable'), MlTone.done);
  });
}

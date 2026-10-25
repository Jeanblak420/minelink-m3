import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/animated_notification_bell.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/utils/driver_week.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/screens/driver_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/live_trip_map_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_positions_screen.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/screens/fuel_costs_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/driver_live_tracking_card.dart';
import 'package:flutter_application_1/features/portal/widgets/driver_resolution_error.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart'
    show formatTons;
import 'package:flutter_application_1/features/profile/widgets/profile_signature_card.dart';
import 'package:flutter_application_1/features/profile_setup/widgets/profile_setup_banner.dart';
import 'package:flutter_application_1/features/tabs/screens/driver_tab_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/driver_app_keys.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

/// Driver mobile app shell (spec 2026-07-16 §5) — 3-tab bottom-nav scaffold
/// matching the approved design (Dashboard · Trip · Profile). The **Trip**
/// tab is the existing [DriverRoutesScreen] unchanged; **Dashboard** lands
/// first and shows only this driver's own trips; every screen the driver had
/// in the old sidebar stays reachable via quick links (feature parity).
class DriverAppScreen extends StatefulWidget {
  /// Starting tab: 0 = Dashboard, 1 = Trip, 2 = Profile. Deep-linked by the
  /// `/portal/driver/{home,trip,profile}` routes (phase-2 nav merge, T2);
  /// defaults to Dashboard, the main landing page (spec).
  final int initialTab;

  const DriverAppScreen({super.key, this.initialTab = 0});

  @override
  State<DriverAppScreen> createState() => _DriverAppScreenState();
}

class _DriverAppScreenState extends State<DriverAppScreen> {
  late int _tab = widget.initialTab.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => DriverDashboardTab(onOpenTrip: () => setState(() => _tab = 1)),
      // The Trip tab carries the same header as the other two, so its chat
      // button and bell sit where they do on Dashboard and Profile.
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  _gutter(context), _gutter(context), _gutter(context), 0),
              child: const _DashboardHeader(
                title: 'Trip',
                subtitle: 'Your current load',
              ),
            ),
            const Expanded(child: DriverRoutesScreen()),
          ],
        ),
      _ => const DriverProfileTab(),
    };

    // shell-ground-exempt: the driver app is SELF-CHROMED. `PortalShellLayout`
    // renders these three tabs bare for a driver employee, so this Scaffold is
    // the only one on screen and its ground is the page.
    final scaffold = Scaffold(
      // The driver shell bypasses the portal scaffold, so it mounts its own
      // account-setup nag (renders nothing once setup is complete).
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ProfileSetupBanner(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Trip',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );

    // Phone Back on the Trip or Profile tab returns to the Dashboard tab
    // first; on the Dashboard it falls through to the shell's SystemBackHandler.
    // Needs a Router above it, which the app always has and bare-widget tests
    // do not.
    if (Router.maybeOf(context) == null) return scaffold;
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (GoRouter.maybeOf(context)?.canPop() ?? false) return false;
        if (_tab == 0) return false;
        setState(() => _tab = 0);
        return true;
      },
      child: scaffold,
    );
  }
}

/// Matches a driver to their truck the same way DriverRoutesScreen does:
/// driver_assignments first (authoritative under multi-driver), then the
/// embedded primary-driver mirror.
FleetVehicle? driverAssignedVehicle(
  List<FleetVehicle> vehicles,
  List<VehicleDriver> assignments,
  String employeeId,
) {
  for (final a in assignments) {
    if (a.driverEmployeeId == employeeId) {
      for (final v in vehicles) {
        if (v.id == a.vehicleId) return v;
      }
    }
  }
  for (final v in vehicles) {
    if (v.assignedDriverEmployeeId == employeeId) return v;
  }
  return null;
}

void _pushScreen(BuildContext context, String title, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: screen),
      ),
    ),
  );
}

/// ---------------------------------------------------------------------------
/// DASHBOARD TAB — this driver's own trips only, real data.
/// ---------------------------------------------------------------------------
class DriverDashboardTab extends ConsumerWidget {
  final VoidCallback? onOpenTrip;
  const DriverDashboardTab({this.onOpenTrip, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final employee = ref.watch(employeeProvider).employee;
    final fleet = ref.watch(fleetProvider(companyId));
    final assignmentsAsync = ref.watch(vehicleDriversProvider(companyId));
    final dispatchesAsync = ref.watch(transporterDispatchesProvider(companyId));
    final async = ref.watch(logisticsSnapshotProvider(companyId));

    // A failure resolving the driver's assignment / dispatched routes must
    // surface as an error with retry — never a silent "no active trip", which
    // is indistinguishable from a genuinely idle driver.
    if (assignmentsAsync.hasError || dispatchesAsync.hasError) {
      return DriverResolutionError(
        onRetry: () {
          ref.invalidate(vehicleDriversProvider(companyId));
          ref.invalidate(transporterDispatchesProvider(companyId));
          ref.invalidate(logisticsSnapshotProvider(companyId));
        },
      );
    }
    if (assignmentsAsync.isLoading || dispatchesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final assignments = assignmentsAsync.requireValue;
    final myVehicle = employee == null
        ? null
        : driverAssignedVehicle(fleet.activeVehicles, assignments, employee.id);
    final dispatches = dispatchesAsync.requireValue;
    final routeByDispatch = {for (final d in dispatches) d.dispatchId: d};
    final nameParts = (employee?.fullName ?? 'Driver').trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : 'Driver';

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DriverResolutionError(
        onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        final myTrips = myVehicle == null
            ? <TripRecord>[]
            : (snap.trips.where((t) => t.vehicleId == myVehicle.id).toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
        final delivered = myTrips
            .where((t) => TripStatus.parse(t.status) == TripStatus.completed)
            .toList();
        final active = myTrips
            .where((t) => TripStatus.parse(t.status).isActive)
            .toList();
        final current = active.isEmpty ? null : active.first;
        final currentReq = current?.dispatchId == null
            ? null
            : routeByDispatch[current!.dispatchId]?.request;

        // Week windows (Mon–Sun) for the stats + chart.
        //
        // Both sides of the comparison are on the mine's clock. The boundary
        // used to come from the device while `t.updatedAt` was the raw UTC
        // instant, so a Monday-morning load could fall in the previous week.
        final now = MlTime.now();
        final today = MlTime.startOfDay(now);
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        final prevWeekStart = weekStart.subtract(const Duration(days: 7));
        bool inWeek(TripRecord t) =>
            !MlTime.sast(t.updatedAt).isBefore(weekStart);
        bool inPrevWeek(TripRecord t) =>
            !MlTime.sast(t.updatedAt).isBefore(prevWeekStart) &&
            MlTime.sast(t.updatedAt).isBefore(weekStart);

        final weekLoads = myTrips
            .where((t) => t.netTons != null && inWeek(t))
            .toList();
        final weekTons = weekLoads.fold<double>(
          0,
          (s, t) => s + (t.netTons ?? 0),
        );
        final totalTons = myTrips.fold<double>(
          0,
          (s, t) => s + (t.netTons ?? 0),
        );

        // Tons delivered per weekday. See [tonsByWeekday] for the day this
        // asked UTC what weekday it was and drew 33.7 t on a Sunday that had
        // not happened yet — under a week TOTAL that was correct to the
        // kilogram, which is why nothing noticed.
        final byDay = tonsByWeekday(
          delivered.where(inWeek),
          weekStart: weekStart,
        );
        final prevWeekTons = delivered
            .where(inPrevWeek)
            .fold<double>(0, (s, t) => s + (t.netTons ?? 0));
        final weekDeliveredTons = byDay.fold<double>(0, (s, v) => s + v);

        final heroStatus = current == null
            ? 'NO ACTIVE TRIP'
            : TripStatus.parse(current.status).label.toUpperCase();
        final heroRoute = current == null
            ? 'Your next load will appear here.'
            : currentReq?.routeLabel ??
                  '${currentReq?.loadingPoint ?? '?'} → '
                      '${currentReq?.offloadingPoint ?? '?'}';
        // Words, not a bare dash, when the driver has no truck yet.
        final heroPlate = current?.truckReg ??
            myVehicle?.vehicleRegistrationNumber ??
            'No truck yet';

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TourTarget(
                id: 'driver.dashboard',
                targetKey: DriverAppTourKeys.dashboard,
                child: _DashboardHeader(
                  title: 'Dashboard',
                  subtitle: '$firstName — your week at a glance',
                ),
              ),
              const SizedBox(height: 16),
              TourTarget(
                id: 'driver.trip',
                targetKey: DriverAppTourKeys.tripCard,
                child: _ActiveTripHero(
                  plate: heroPlate,
                  route: heroRoute,
                  statusLabel: heroStatus,
                  onTap: current == null ? null : onOpenTrip,
                  onNavigate: current == null
                      ? null
                      : () => context.push(
                          '/portal/driver/navigate/${current.id}',
                        ),
                  onStartRoute:
                      (current != null &&
                          TripStatus.parse(current.status) ==
                              TripStatus.scheduled)
                      ? () => _startRoute(context, ref, current, companyId)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // `IntrinsicHeight` + `stretch`, so the pair CANNOT sit crooked.
              //
              // `_MiniStat`'s label has no `maxLines` — it wraps rather than
              // truncating, which is right for a label a driver has to read
              // outdoors. But a `Row` of two `Expanded` cards centres children
              // of different heights, so the moment one label wrapped and the
              // other did not the two cards sat 20px out of line. Measured on
              // renaming the tonnage card: 134 px beside 154 px at 360 px, and
              // 150 beside 176 at text scale 1.3.
              //
              // Trimming the words to match lengths would be fixing the
              // symptom, and it would come back the next time a label changed.
              //
              // NOT bare `CrossAxisAlignment.stretch`: this Row sits in a
              // scrollable Column, so its cross axis is unbounded and stretch
              // alone throws "BoxConstraints forces an infinite height"
              // (CLAUDE.md §10.4). `IntrinsicHeight` bounds it to the taller
              // child first, which is exactly the height wanted.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.local_shipping_outlined,
                        tone: MlTone.accent,
                        value: '${weekLoads.length}',
                        label: 'Loads this week',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.monitor_weight_outlined,
                        tone: MlTone.transit,
                        value: formatTons(weekTons),
                        // "loaded", because the chart further down this same
                        // screen is headed `Tons delivered / This week` and
                        // shows a DIFFERENT figure — 170.5 t here against
                        // 136.3 t there, measured on a real driver 2026-08-23
                        // with one load weighed and still on the road. Both are
                        // right; only one of the two labels said what it
                        // counted, and the driver is paid on the other one.
                        label: 'Tons loaded this week',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // The all-time pair, held level the same way — see above.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.check_circle_outline,
                        tone: MlTone.done,
                        value: '${delivered.length}',
                        label: 'Deliveries',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.scale_outlined,
                        tone: MlTone.atMine,
                        value: formatTons(totalTons),
                        label: 'Total tons',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DriverLiveTrackingCard(hasActiveTrip: active.isNotEmpty),
              if (myVehicle != null) ...[
                const SizedBox(height: 12),
                MlButton.tonal(
                  label: 'Log fuel',
                  icon: Icons.local_gas_station_outlined,
                  expand: true,
                  onPressed: () => showLogFuelDialog(
                    context,
                    ref,
                    companyId: companyId,
                    lockedVehicleId: myVehicle.id,
                    lockedVehicleReg: myVehicle.vehicleRegistrationNumber,
                    tripId: current?.id,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _WeekChartCard(
                byDay: byDay,
                weekTotal: weekDeliveredTons,
                prevWeekTotal: prevWeekTons,
                todayIndex: now.weekday - 1,
              ),
              const SizedBox(height: 16),
              // Feature parity with the old driver sidebar: every screen the
              // driver had stays one tap away.
              const _QuickLinksCard(),
            ],
          ),
        );
      },
    );
  }

  /// Same call the Trip tab's "Start route" makes — `scheduled` →
  /// `en_route_to_load`, which is what puts this truck on the mine's inbound
  /// queue and every party's live map.
  Future<void> _startRoute(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    String companyId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(lifecycleServiceProvider)
          .setTripStatus(trip.id, TripStatus.enRouteToLoad);
      ref.invalidateIfMounted(logisticsSnapshotProvider(companyId));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Trip started — you are en route to load. Turn on '
            'Live location sharing so the parties can follow your truck.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not start the trip. ${friendlyError(e)}'),
        ),
      );
    }
  }
}

/// [MlPageBody]'s gutter, for a header that sits outside one.
double _gutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? 16 : MlTokens.contentPadding;

class _DashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _DashboardHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Row(
      children: [
        const MlIconWell(
          icon: Icons.grid_view_rounded,
          tone: MlTone.accent,
          size: 50,
          radius: 14,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.mlText.titleLarge.copyWith(
                  color: semantic.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textMuted,
                ),
              ),
            ],
          ),
        ),
        // Chat opens from here on a phone, beside the bell, instead of from
        // a disc floating over the page: on all three tabs it covered the
        // bottom card ("Total tons", the Account setup row) on the S25-matched
        // emulator (2026-10-24). Draws nothing on a wide window, where the
        // dock keeps its disc.
        const ChatDockAppBarButton(),
        const AnimatedNotificationBell(),
      ],
    );
  }
}

/// The hero, reachable by a test.
///
/// A seam rather than a refactor: the card is one of very few places in this
/// product where two strings can contradict each other in a single row, and it
/// did — see `driver_hero_does_not_contradict_itself_test.dart`. Building the
/// whole driver dashboard to assert on two words would mean stubbing every
/// provider behind it, which is how a check ends up proving something about a
/// fixture instead of about the card.
@visibleForTesting
class DriverActiveTripHeroForTest extends StatelessWidget {
  const DriverActiveTripHeroForTest({
    super.key,
    required this.plate,
    required this.route,
    required this.statusLabel,
  });

  final String plate;
  final String route;
  final String statusLabel;

  @override
  Widget build(BuildContext context) =>
      _ActiveTripHero(plate: plate, route: route, statusLabel: statusLabel);
}

/// Cyan→navy promo hero for the driver's current trip (approved design
/// gradient — the one sanctioned raw-colour exception).
class _ActiveTripHero extends StatelessWidget {
  final String plate;
  final String route;
  final String statusLabel;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;

  /// Present only while the trip is still `scheduled` — the one action the
  /// lifecycle is actually waiting on.
  ///
  /// The dashboard is where a driver lands, and its only action used to be
  /// "Navigate". So the first thing the app offered was the thing that tells
  /// nobody anything: the trip stayed `scheduled`, the mine's gate queue never
  /// saw the truck coming and the buyer's live map stayed empty, while the
  /// driver was already on the road. "Start route" was on the Trip tab, one
  /// tap away, below two other buttons.
  final VoidCallback? onStartRoute;

  const _ActiveTripHero({
    required this.plate,
    required this.route,
    required this.statusLabel,
    this.onTap,
    this.onNavigate,
    this.onStartRoute,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MlTokens.rXl),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MlTokens.rXl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MlTokens.cyan650, MlTokens.navy700],
          ),
          boxShadow: const [
            BoxShadow(
              color: MlTokens.navyShadowSoft,
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A WRAP THAT CLAIMS THE ROW, not a Row with a Spacer.
            //
            // Neither the eyebrow nor the status pill was flexible, so at
            // 360 px and text scale 1.3 — a narrow phone with the platform
            // text size turned up, which is a driver standing outdoors — the
            // pair overflowed by 44 px and Flutter painted the yellow-and-black
            // stripe across the driver's hero card. Measured 2026-08-23 with a
            // real trip loaded; `EN ROUTE TO OFFLOAD` is five characters longer
            // than the `NO ACTIVE TRIP` the empty state shows, which is why the
            // portal overflow sweep — which pumps this screen with NO trip
            // data — has always passed on it (CLAUDE.md §10.5).
            //
            // Making either side `Flexible` would ellipsise it, and both are
            // things the driver needs whole: the eyebrow names the slot and the
            // pill is the trip's live state. So the pill DROPS TO A SECOND LINE
            // instead. `SizedBox(width: double.infinity)` because a `Wrap`
            // sizes to its content, so `spaceBetween` has no free space to
            // distribute until the wrap is told to fill the row (§10.4).
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: MlTokens.cyan250,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // "CURRENT TRIP", not "ACTIVE TRIP".
                      //
                      // The pill on the right of this same row carries the live
                      // state, and when there is no trip it reads NO ACTIVE TRIP.
                      // Beside a fixed eyebrow saying ACTIVE TRIP that is a card
                      // contradicting itself in one line — photographed on an
                      // Android emulator on 2026-08-21, driver signed in, no trip
                      // assigned:
                      //
                      //     ● ACTIVE TRIP                    [ NO ACTIVE TRIP ]
                      //
                      // The eyebrow names the SLOT and has to stay true whatever is
                      // in it; the pill says what is in it.
                      const Text(
                        'CURRENT TRIP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          // FULL white, not `inkOnFill70`.
                          //
                          // That token is documented for "the driver card's
                          // navy gradient", and this is the CYAN end of it. On
                          // a saturated cyan there is no room for a quieter
                          // white at all: solving for the alpha that reaches
                          // 4.5:1 gives 0.965, which is white. So the eyebrow
                          // is white and stays quieter by being 11px, w800 and
                          // tracked out beside a 12px pill - size and weight,
                          // the same answer `textFaint` reached.
                          color: MlTokens.inkOnFill,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MlTokens.inkOnFill.withValues(alpha: 0.16),
                      borderRadius: MlShape.pill,
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: MlTokens.inkOnFill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: MlTokens.inkOnFill.withValues(alpha: 0.15),
                    borderRadius: MlShape.radiusLarge,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 28,
                    color: MlTokens.inkOnFill,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plate,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: MlTokens.inkOnFill,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        route,
                        // Two lines: at the S25's 1.3 text size one line cut
                        // "Your next load will appear here." (2026-10-24).
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          // Same as the eyebrow above: the cyan end of
                          // this gradient has no room for a 70% white.
                          fontSize: 13,
                          color: MlTokens.inkOnFill,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: MlTokens.inkOnFill),
              ],
            ),
            if (onStartRoute != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MlTokens.inkOnFill,
                    foregroundColor: MlTokens.navy700,
                  ),
                  onPressed: onStartRoute,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start route',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
            if (onNavigate != null) ...[
              SizedBox(height: onStartRoute != null ? 8 : 14),
              TourTarget(
                id: 'driver.navigation',
                targetKey: DriverAppTourKeys.navigation,
                child: SizedBox(
                  width: double.infinity,
                  child: onStartRoute != null
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MlTokens.inkOnFill,
                            side: BorderSide(
                              color: MlTokens.inkOnFill.withValues(alpha: 0.45),
                            ),
                          ),
                          onPressed: onNavigate,
                          icon: const Icon(Icons.navigation_rounded, size: 19),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      : FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: MlTokens.inkOnFill,
                            foregroundColor: MlTokens.navy700,
                          ),
                          onPressed: onNavigate,
                          icon: const Icon(Icons.navigation_rounded, size: 19),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final MlTone tone;
  final String value;
  final String label;
  const _MiniStat({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlIconWell(icon: icon, tone: tone, size: 38, radius: 11),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.headlineSmall.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: context.mlText.bodyMedium.copyWith(
              color: semantic.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly tons-delivered bar chart (dependency-free, per the export design)
/// wired to the driver's real completed trips.
class _WeekChartCard extends StatelessWidget {
  final List<double> byDay; // Mon..Sun
  final double weekTotal;
  final double prevWeekTotal;
  final int todayIndex;
  const _WeekChartCard({
    required this.byDay,
    required this.weekTotal,
    required this.prevWeekTotal,
    required this.todayIndex,
  });

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final max = byDay.fold<double>(0, (m, v) => v > m ? v : m);
    final delta = weekTotal - prevWeekTotal;
    final deltaUp = delta >= 0;

    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tons delivered',
                      style: context.mlText.titleMedium.copyWith(
                        color: semantic.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This week',
                      style: context.mlText.bodyMedium.copyWith(
                        color: semantic.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTons(weekTotal),
                    style: context.mlText.code(
                      color: semantic.textStrong,
                      size: 22,
                      weight: FontWeight.w800,
                    ),
                  ),
                  if (prevWeekTotal > 0)
                    Text(
                      '${deltaUp ? '▲' : '▼'} '
                      '${formatTons(delta.abs())} vs last week',
                      style: context.mlText.labelMedium.copyWith(
                        color: (deltaUp ? MlTone.done : MlTone.warn)
                            .colors(brightness)
                            .fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // NOTHING DELIVERED THIS WEEK IS A SENTENCE, NOT A CHART.
          //
          // `max <= 0` used to fall through to `heightFactor: 0.03`, so a week
          // with no deliveries drew seven identical grey stubs under 116px of
          // empty plot. A driver on their first Monday, or anyone between
          // loads, opened the app to what reads as a chart that failed to
          // load. Photographed 2026-08-21, the first time this tab was
          // rendered.
          if (max <= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'No deliveries recorded this week yet.',
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textMuted,
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < byDay.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == byDay.length - 1 ? 0 : 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: max <= 0
                                      ? 0.03
                                      : (byDay[i] / max).clamp(0.03, 1.0),
                                  widthFactor: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: byDay[i] == 0
                                          ? semantic.divider
                                          : i == todayIndex
                                          ? MlTokens.accent
                                          : MlTone.accent.well(brightness),
                                      borderRadius: MlShape.radiusSmall,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _labels[i],
                              style: context.mlText.labelSmall.copyWith(
                                color: i == todayIndex
                                    ? MlTokens.accent
                                    : semantic.textFaint,
                                fontWeight: i == todayIndex
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Every screen from the old driver sidebar, one tap away (feature parity).
class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context) {
    return MlCard(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          _ProfileRow(
            icon: Icons.gps_fixed_rounded,
            tone: MlTone.accent,
            label: 'Live map',
            value: 'Active trips with live truck positions',
            onTap: () =>
                _pushScreen(context, 'Live map', const LiveTripMapScreen()),
          ),
          _ProfileRow(
            icon: Icons.map_outlined,
            tone: MlTone.transit,
            label: 'Truck locations',
            value: 'Latest known truck positions',
            onTap: () => _pushScreen(
              context,
              'Truck locations',
              const TransporterTruckLocationsScreen(),
            ),
          ),
          _ProfileRow(
            icon: Icons.place_outlined,
            tone: MlTone.atMine,
            label: 'Truck positions',
            value: 'Position history & pings',
            onTap: () => _pushScreen(
              context,
              'Truck positions',
              const TransporterTruckPositionsScreen(),
            ),
          ),
          _ProfileRow(
            icon: Icons.local_shipping_outlined,
            tone: MlTone.done,
            label: 'My workspace',
            value: 'Assignment, company & notifications',
            onTap: () =>
                _pushScreen(context, 'My workspace', const DriverTabScreen()),
            last: true,
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// PROFILE TAB — real identity, signature, history; nothing orphaned.
/// ---------------------------------------------------------------------------
class DriverProfileTab extends ConsumerWidget {
  const DriverProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final employeeState = ref.watch(employeeProvider);
    final employee = employeeState.employee;
    final companyId = resolvePortalCompanyId(ref);
    final fleet = companyId == null
        ? null
        : ref.watch(fleetProvider(companyId));
    final assignments = companyId == null
        ? const <VehicleDriver>[]
        : ref.watch(vehicleDriversProvider(companyId)).asData?.value ??
              const <VehicleDriver>[];
    final myVehicle = (employee == null || fleet == null)
        ? null
        : driverAssignedVehicle(fleet.activeVehicles, assignments, employee.id);
    final snap = companyId == null
        ? null
        : ref.watch(logisticsSnapshotProvider(companyId)).asData?.value;
    final delivered = (snap == null || myVehicle == null)
        ? const <TripRecord>[]
        : (snap.trips
              .where(
                (t) =>
                    t.vehicleId == myVehicle.id &&
                    TripStatus.parse(t.status) == TripStatus.completed,
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

    final name = employee?.fullName.trim() ?? 'Driver';
    final initials = name.isEmpty
        ? 'D'
        : name
              .split(RegExp(r'\s+'))
              .where((p) => p.isNotEmpty)
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardHeader(
            title: 'Profile',
            subtitle: 'Account & settings',
          ),
          const SizedBox(height: 16),
          MlCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [MlTokens.cyan650, MlTokens.navy700],
                    ),
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: MlTokens.inkOnFill,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: context.mlText.titleLarge.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Driver · ${employeeState.company?.companyName ?? ''}',
                  style: context.mlText.bodyMedium.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                // A plate badge only when there is a plate: with no truck it
                // drew an empty number plate holding a dash.
                if (myVehicle?.vehicleRegistrationNumber case final reg?)
                  MlPlatePill(reg, fontSize: 12)
                else
                  Text(
                    'No truck assigned yet',
                    style: context.mlText.bodySmall.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MlCard(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.draw_outlined,
                  tone: MlTone.accent,
                  label: 'My signature',
                  value: 'Auto-placed on PODs & waybills',
                  onTap: () => _pushScreen(
                    context,
                    'My signature',
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: ProfileSignatureCard(),
                      ),
                    ),
                  ),
                ),
                _ProfileRow(
                  icon: Icons.checklist_rounded,
                  tone: MlTone.warn,
                  label: 'Account setup',
                  value: 'Licence, PrDP, medicals & documents',
                  onTap: () => context.go('/account-setup'),
                ),
                _ProfileRow(
                  icon: Icons.history,
                  tone: MlTone.transit,
                  label: 'Trip history',
                  value: '${delivered.length} completed trips',
                  onTap: () => _pushScreen(
                    context,
                    'Trip history',
                    _TripHistoryList(delivered),
                  ),
                ),
                _ProfileRow(
                  icon: Icons.notifications_outlined,
                  tone: MlTone.atMine,
                  label: 'Notifications',
                  value: 'Dispatch & route alerts',
                  onTap: () => context.go('/notifications'),
                ),
                _ProfileRow(
                  icon: Icons.person_outline_rounded,
                  tone: MlTone.done,
                  label: 'Full profile',
                  value: 'Photo, documents & password',
                  onTap: () => context.go('/profile'),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) => MlButton.danger(
              label: 'Sign out',
              icon: Icons.logout,
              expand: true,
              onPressed: () =>
                  LogoutService.logoutWithConfirmation(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripHistoryList extends StatelessWidget {
  final List<TripRecord> trips;
  const _TripHistoryList(this.trips);

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    if (trips.isEmpty) {
      return const MlEmptyState(
        icon: Icons.history,
        title: 'No completed trips yet.',
        message: 'Delivered loads appear here with their tonnage.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = trips[i];
        return MlCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const MlIconWell(
                icon: Icons.check_circle_outline,
                tone: MlTone.done,
                size: 38,
                radius: 11,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.truckReg ?? 'Trip ${t.id.substring(0, 6)}…',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: semantic.textStrong,
                      ),
                    ),
                    Text(
                      '${MlTime.sast(t.updatedAt).toString().substring(0, 16)}'
                      '${t.netTons != null ? ' · ${formatTons(t.netTons!)}' : ''}',
                      style: context.mlText.bodySmall.copyWith(
                        color: semantic.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final MlTone tone;
  final String label;
  final String value;
  final bool last;
  final VoidCallback? onTap;
  const _ProfileRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: last
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: semantic.divider)),
              ),
        child: Row(
          children: [
            MlIconWell(icon: icon, tone: tone, size: 40, radius: 12),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.mlText.titleMedium.copyWith(
                      color: semantic.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: context.mlText.bodyMedium.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: semantic.textFaint),
          ],
        ),
      ),
    );
  }
}

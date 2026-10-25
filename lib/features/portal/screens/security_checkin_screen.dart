import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/models/workflow_notification.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/security_confirmation_provider.dart';
import 'package:flutter_application_1/features/portal/providers/workflow_notification_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/mine_dashboard_keys.dart';

/// Mine Security — the guard's mobile gate-control screen on real trips
/// (ui_kits/mine-supplier MineSecurity). Search inbound registrations,
/// mark arrivals (→ arrived_at_mine, hands off to the load controller) and
/// departures (→ left_mine, only once the controller recorded the load),
/// with live incoming / at-mine / departed counts and recent activity.
class SecurityCheckinScreen extends ConsumerStatefulWidget {
  const SecurityCheckinScreen({super.key, this.focusDepartures = false});

  /// Gate mode (phase-2 nav merge T4, the `/portal/mine/gate` deep link):
  /// same screen, but the "At Mine — Mark Departure" section is shown first
  /// so the check-out flow leads. Default keeps the arrivals-first order.
  final bool focusDepartures;

  @override
  ConsumerState<SecurityCheckinScreen> createState() =>
      _SecurityCheckinScreenState();
}

class _SecurityCheckinScreenState extends ConsumerState<SecurityCheckinScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _selectedTripId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _consumePending(List<MineTrip> trips) {
    final pending = ref.watch(pendingSelectionProvider);
    if (pending == null || pending.tab != 'Security') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cur = ref.read(pendingSelectionProvider);
      if (cur == null || cur.tab != 'Security') return;
      ref.read(pendingSelectionProvider.notifier).state = null;
      final match = trips
          .where((t) => t.reg.toUpperCase() == cur.reg.toUpperCase())
          .firstOrNull;
      if (match != null) {
        setState(() {
          _selectedTripId = match.tripId;
          _controller.text = match.reg;
          _query = match.reg;
        });
      }
    });
  }

  Future<void> _setStatus(
    String companyId,
    MineTrip trip,
    TripStatus status,
    String okMsg, {
    String? notifyRole,
    WorkflowEvent? event,
    String? notifyTitle,
    String? notifyBody,
    String? notifyTab,
  }) async {
    try {
      await ref
          .read(lifecycleServiceProvider)
          .setTripStatus(trip.tripId, status);
      ref.invalidateIfMounted(mineInboundTripsProvider(companyId));
      // The status change has already landed server-side; everything below is
      // local echo, and `ref` throws once the gate screen is gone.
      if (!mounted) return;
      if (notifyRole != null && event != null) {
        ref
            .read(workflowNotificationProvider.notifier)
            .push(
              targetRole: notifyRole,
              kind: event,
              title: notifyTitle ?? '',
              body: notifyBody ?? '',
              tabLabel: notifyTab ?? '',
              reg: trip.reg,
            );
      }
      if (mounted) _snack(okMsg);
    } catch (e) {
      if (mounted) _snack('Failed. ${friendlyError(e)}');
    }
  }

  void _markArrived(String companyId, MineTrip trip) => _setStatus(
    companyId,
    trip,
    TripStatus.arrivedAtMine,
    '${trip.reg} marked on-site. Load controller notified.',
    notifyRole: 'controller',
    event: WorkflowEvent.checkin,
    notifyTitle: 'Truck checked in',
    notifyBody: 'Security checked in ${trip.reg} for loading.',
    notifyTab: 'Controller',
  );

  Future<void> _markGone(String companyId, MineTrip trip) async {
    try {
      final lifecycle = ref.read(lifecycleServiceProvider);
      // §4 Security checkout: departure puts the truck on route to offload.
      //
      // ONE call. This was two — `leftMine` then `enRouteToOffload` — and a
      // failure between them left the truck stranded at `left_mine`: gone from
      // the gate, so unwatched here, and never announced to the offload point.
      // The guard saw a success either way, because the first call had
      // returned. S6-9 / S6-24.
      await lifecycle.securityCheckOut(trip.tripId);
      ref.invalidateIfMounted(mineInboundTripsProvider(companyId));
      // Check-out has already landed server-side; everything below is local
      // echo, and `ref` throws once the gate screen is gone.
      if (!mounted) return;
      ref
          .read(workflowNotificationProvider.notifier)
          .push(
            targetRole: 'mine',
            kind: WorkflowEvent.released,
            title: 'Truck departed',
            body: '${trip.reg} loaded & gone — en route to offload.',
            tabLabel: 'Overview',
            reg: trip.reg,
          );
      if (mounted) {
        _snack('${trip.reg} marked loaded & gone — en route to offload.');
      }
    } catch (e) {
      if (mounted) _snack('Failed. ${friendlyError(e)}');
    }
  }

  /// Arrival + departure gate sections in screen order: departures first in
  /// gate (check-out) mode, arrivals first otherwise.
  List<Widget> _orderedGateSections({
    required Widget arrivals,
    required Widget departures,
  }) => widget.focusDepartures
      ? [departures, const SizedBox(height: 14), arrivals]
      : [arrivals, const SizedBox(height: 14), departures];

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final async = ref.watch(mineInboundTripsProvider(companyId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
        subject: 'the gate queue',
        error: e,
        onRetry: () => ref.invalidate(mineInboundTripsProvider(companyId)),
      ),
      data: (trips) {
        _consumePending(trips);
        final semantic = MlSemantic.of(context);
        final q = _query.trim().toUpperCase();
        // Active (not yet departed) trucks are searchable.
        final searchable = trips
            .where((t) => t.status.step < TripStatus.leftMine.step)
            .toList();
        final matches = q.isEmpty
            ? const <MineTrip>[]
            : searchable.where((t) => t.reg.toUpperCase().contains(q)).toList();
        final selected = _selectedTripId == null
            ? null
            : trips.where((t) => t.tripId == _selectedTripId).firstOrNull;

        final inbound = trips.where((t) => t.isInbound).toList();
        final onSite = trips.where((t) => t.isOnSite).toList();
        final loadedReady = trips
            .where((t) => t.status == TripStatus.loaded)
            .toList();
        // `MlTime.now()`, NOT `DateTime.now()`. The trip side of this
        // comparison is already converted — `MlTime.sast(t.updatedAt)` — so
        // the boundary has to be on the same clock or the two halves disagree.
        //
        // On a guard's phone set to SAST this is right, which is exactly why
        // it survived: the emulator is Africa/Johannesburg and the count
        // looked correct. On a device in any other zone, "Departed Today"
        // counts against the DEVICE's today. Between midnight and 02:00 SAST
        // on a UTC device that is yesterday — night shift, at a gate whose
        // whole job is to say what happened today.
        final now = MlTime.now();
        final departedToday = trips.where((t) {
          if (t.status.step < TripStatus.leftMine.step) return false;
          final d = MlTime.sast(t.updatedAt);
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).length;
        final recent = [...trips]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Page header ----
                  //
                  // `MlPageHeader`, like the Load Controller's "Mine Control"
                  // next door. Until 2026-08-23 this was a hand-rolled
                  // 22px sans ExtraBold beside a gradient brand chip — the
                  // one portal title not in the display face, on the screen
                  // whose sibling already was (the class the console pass
                  // found on six screens, HANDOFF §3.25). The meta is the
                  // one fact a guard reads first.
                  TourTarget(
                    id: 'security.dashboard',
                    targetKey: MineDashboardTourKeys.dashboard,
                    child: MlPageHeader(
                      title: 'Security gate',
                      description: 'Gate control — arrivals & departures',
                      meta: '${onSite.length + loadedReady.length} on site · '
                          '${inbound.length} inbound',
                      padding: const EdgeInsets.only(bottom: 16),
                    ),
                  ),
                  TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) => setState(() {
                      _query = v;
                      _selectedTripId = null;
                    }),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search truck registration...',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _controller.clear();
                                _query = '';
                                _selectedTripId = null;
                              }),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ---- KPI chips ----
                  //
                  // `IntrinsicHeight` + `stretch` so the three cards are the
                  // same height once a label wraps. This is the one sanctioned
                  // use of `CrossAxisAlignment.stretch` — CLAUDE.md §10.4 bans
                  // it under an UNBOUNDED parent, and IntrinsicHeight is
                  // precisely what makes the height bounded.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.login_rounded,
                            value: '${inbound.length}',
                            // NOT "Incoming Today". `isInbound` is
                            // `scheduled || en_route_to_load` with no date
                            // filter at all, so this counts every truck heading
                            // here whenever it was dispatched — which is the
                            // right count for a guard, and the wrong label.
                            // "Departed Today" beside it really is scoped to
                            // the SAST day, so the two disagreed about what
                            // "Today" meant while sitting 10px apart. The load
                            // controller's equivalent already says "Inbound
                            // Trucks"; this is the same fact under the same
                            // vocabulary.
                            label: 'Incoming',
                            tone: MlTone.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.shield_outlined,
                            value: '${onSite.length + loadedReady.length}',
                            label: 'At mine',
                            tone: MlTone.atMine,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.check_circle_outline,
                            value: '$departedToday',
                            label: 'Departed today',
                            tone: MlTone.done,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (q.isNotEmpty && matches.isEmpty && selected == null)
                    MlCard(
                      child: MlEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No inbound truck matches "$_query".',
                      ),
                    ),
                  if (matches.isNotEmpty && selected == null)
                    MlCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          for (var i = 0; i < matches.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: semantic.divider),
                            ListTile(
                              leading: const MlIconWell(
                                icon: Icons.local_shipping_outlined,
                                size: 40,
                                radius: 11,
                              ),
                              title: Text(
                                matches[i].reg,
                                style: const TextStyle(
                                  fontFamily: MlTokens.fontMono,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              subtitle: Text(
                                '${matches[i].buyerLabel} · ${matches[i].transporterName ?? '—'}',
                              ),
                              trailing: MlStatusBadge.forStatus(
                                matches[i].status.label,
                              ),
                              onTap: () => setState(
                                () => _selectedTripId = matches[i].tripId,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (selected != null) ...[
                    _CheckinCard(
                      trip: selected,
                      onArrived: () => _markArrived(companyId, selected),
                      onGone: () => _markGone(companyId, selected),
                      onBack: () => setState(() => _selectedTripId = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (selected == null) ...[
                    // ---- Pending gate confirmations (phase-5 T6, additive:
                    // renders nothing when the queue is empty/unavailable) ----
                    _PendingGateConfirmations(
                      companyId: companyId,
                      trips: trips,
                    ),
                    // ---- Incoming Trucks — Mark Arrival + At Mine — Mark
                    // Departure (departures lead in gate mode) ----
                    ..._orderedGateSections(
                      arrivals: TourTarget(
                        id: 'security.checkin',
                        targetKey: MineDashboardTourKeys.checkin,
                        child: _GateSection(
                          icon: Icons.login_rounded,
                          title: 'Incoming trucks — mark arrival',
                          child: inbound.isEmpty
                              ? _EmptyLine(
                                  'No incoming trucks right now — new arrivals appear here.',
                                )
                              : Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i <
                                          (inbound.length > 3
                                              ? 3
                                              : inbound.length);
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 14),
                                      _GateTruck(
                                        trip: inbound[i],
                                        tone: MlTone.transit,
                                        action: MlButton.go(
                                          label: 'Mark arrived',
                                          icon: Icons.login_rounded,
                                          expand: true,
                                          onPressed: () =>
                                              _markArrived(companyId, inbound[i]),
                                        ),
                                      ),
                                    ],
                                    if (inbound.length > 3)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _EmptyLine(
                                          '+${inbound.length - 3} more — use search or the trucklist.',
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      departures: TourTarget(
                        id: 'security.checkout',
                        targetKey: MineDashboardTourKeys.checkout,
                        child: _GateSection(
                          icon: Icons.shield_outlined,
                          title: 'At mine — mark departure',
                          child: (onSite.isEmpty && loadedReady.isEmpty)
                              ? _EmptyLine('No trucks at the mine right now.')
                              : Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i <
                                          (loadedReady.length > 3
                                              ? 3
                                              : loadedReady.length);
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 14),
                                      _GateTruck(
                                        trip: loadedReady[i],
                                        tone: MlTone.atMine,
                                        badge: MlStatusBadge.forStatus(
                                          loadedReady[i].status.label,
                                        ),
                                        action: MlButton.leave(
                                          label: 'Mark left',
                                          icon: Icons.logout_rounded,
                                          expand: true,
                                          onPressed: () => _markGone(
                                            companyId,
                                            loadedReady[i],
                                          ),
                                        ),
                                      ),
                                    ],
                                    for (
                                      var i = 0;
                                      i < (onSite.length > 2 ? 2 : onSite.length);
                                      i++
                                    ) ...[
                                      if (i > 0 || loadedReady.isNotEmpty)
                                        const SizedBox(height: 14),
                                      _GateTruck(
                                        trip: onSite[i],
                                        tone: MlTone.atMine,
                                        badge: const MlStatusBadge(
                                          label: 'AT MINE',
                                          tone: MlTone.atMine,
                                        ),
                                        footnote:
                                            'Waiting for the load controller to weigh & seal before release.',
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ---- Recent activity ----
                    MlCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MlSectionTitle(
                            'Recent activity',
                            meta: mlCount(recent.length, 'trip'),
                            icon: Icons.history_rounded,
                            margin: const EdgeInsets.only(bottom: 8),
                          ),
                          if (recent.isEmpty)
                            _EmptyLine('No trips yet.')
                          else
                            for (final t in recent.take(5))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.reg,
                                            style: const TextStyle(
                                              fontFamily: MlTokens.fontMono,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              fontFeatures: [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${t.status.label} · ${t.buyerLabel}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.mlText.bodySmall
                                                .copyWith(
                                                  color: semantic.textMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      // Recent Activity spans days; a bare
                                      // clock cannot say which one. Same fault
                                      // and same fix as the load controller's
                                      // Recent Loads.
                                      MlTime.listStamp(t.updatedAt),
                                      style: context.mlText.code(
                                        color: semantic.textFaint,
                                        size: 13,
                                        weight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    MlButton.outline(
                      label: 'View trucklist',
                      icon: Icons.list_alt_outlined,
                      onPressed: () => _showTruckList(context, searchable),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTruckList(
    BuildContext context,
    List<MineTrip> trucks,
  ) async {
    final tripId = await showDialog<String>(
      context: context,
      builder: (_) => _TruckListDialog(trucks: trucks),
    );
    if (tripId != null && mounted) {
      final match = trucks.where((t) => t.tripId == tripId).firstOrNull;
      if (match != null) {
        setState(() {
          _controller.text = match.reg;
          _query = match.reg;
          _selectedTripId = tripId;
        });
      }
    }
  }
}

/// Two-party gate confirmations still waiting for security's sign-off
/// (phase-5 T6). Fed by `get_mine_pending_confirmations`; the guard's
/// Confirm button sets the security side (`securityConfirm`, stamping the
/// signed-in user). Strictly additive to the existing arrival/departure
/// lifecycle flow — confirmations never advance `TripStatus` — and the whole
/// section renders nothing while empty, loading, or unavailable.
class _PendingGateConfirmations extends ConsumerStatefulWidget {
  final String companyId;
  final List<MineTrip> trips;

  const _PendingGateConfirmations({
    required this.companyId,
    required this.trips,
  });

  @override
  ConsumerState<_PendingGateConfirmations> createState() =>
      _PendingGateConfirmationsState();
}

class _PendingGateConfirmationsState
    extends ConsumerState<_PendingGateConfirmations> {
  final Set<String> _busy = {};

  String _tripLabel(SecurityConfirmation c) {
    final match = widget.trips.where((t) => t.tripId == c.tripId).firstOrNull;
    if (match != null) return match.reg;
    final id = c.tripId;
    return id.length > 8 ? 'Trip ${id.substring(0, 8)}…' : 'Trip $id';
  }

  Future<void> _confirm(SecurityConfirmation c) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(c.id));
    try {
      // Current user id is stamped by the service (auth.currentUser).
      await ref
          .read(securityConfirmationServiceProvider)
          .securityConfirm(c.tripId, c.confirmationType);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${c.confirmationType.label} confirmed for ${_tripLabel(c)}.',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to confirm. ${friendlyError(e)}')),
        );
    }
    if (mounted) {
      setState(() => _busy.remove(c.id));
      ref.invalidateIfMounted(
        minePendingConfirmationsProvider(widget.companyId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final done = MlTone.done.colors(brightness);
    final pending = ref.watch(
      minePendingConfirmationsProvider(widget.companyId),
    );
    final rows = pending.valueOrNull ?? const <SecurityConfirmation>[];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MlCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MlSectionTitle(
              'Pending gate confirmations',
              meta: mlCount(rows.length, 'awaiting sign-off'),
              icon: Icons.verified_user_outlined,
              margin: const EdgeInsets.only(bottom: 4),
            ),
            Text(
              'Two-party sign-off: the driver confirms at the gate, then '
              'security confirms here.',
              style: context.mlText.bodySmall.copyWith(
                color: semantic.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            for (final c in rows)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    MlIconWell(
                      icon:
                          c.confirmationType == SecurityConfirmationType.arrival
                          ? Icons.login_rounded
                          : Icons.logout_rounded,
                      tone: c.driverConfirmed ? MlTone.done : MlTone.atMine,
                      size: 40,
                      radius: 11,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tripLabel(c),
                            style: const TextStyle(
                              fontFamily: MlTokens.fontMono,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                c.driverConfirmed
                                    ? Icons.check_circle
                                    : Icons.hourglass_top_rounded,
                                size: 13,
                                color: c.driverConfirmed
                                    ? done.fg
                                    : semantic.textFaint,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${c.confirmationType.label} · '
                                  '${c.driverConfirmed ? 'driver confirmed' : 'waiting for driver'}',
                                  // TWO lines. This says WHICH confirmation and
                                  // WHETHER the driver has agreed to it — at one
                                  // line, in 159px, "Gate arrival · driver
                                  // confirmed" lost the half that says the
                                  // driver confirmed, on the gate screen where
                                  // that is the question being asked.
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.mlText.bodySmall.copyWith(
                                    color: semantic.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _busy.contains(c.id)
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : MlButton.go(
                            label: 'Confirm',
                            icon: Icons.shield_outlined,
                            compact: true,
                            onPressed: () => _confirm(c),
                          ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact KPI chip for the mobile gate header (icon well, count, label).
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final MlTone tone;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlIconWell(icon: icon, tone: tone, size: 34, radius: 10),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.mlText.titleLarge.copyWith(
              color: semantic.textStrong,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          // Two lines, like `MlStatCard`'s label. At one line a 117px chip on a
          // 412px phone rendered "Incoming Tod…" and "Departed Tod…" — the
          // guard could not tell "Today" from "Total", on the count they act
          // on. The bespoke chip was the only stat label in the product still
          // capped at one line.
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.bodySmall.copyWith(
              color: semantic.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _GateSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _GateSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MlCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The section heading in the reference's vocabulary — Fraunces via
          // `MlSectionTitle`, as "Pending gate confirmations" and "Recent
          // activity" on this same screen already are. It was a 16px sans
          // ExtraBold row until 2026-08-23, so one screen headed its four
          // sections in two faces.
          MlSectionTitle(
            title,
            icon: icon,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          child,
        ],
      ),
    );
  }
}

/// One truck block inside a gate section: big identity well, plate, fields.
class _GateTruck extends StatelessWidget {
  final MineTrip trip;
  final MlTone tone;
  final Widget? badge;
  final Widget? action;
  final String? footnote;

  const _GateTruck({
    required this.trip,
    required this.tone,
    this.badge,
    this.action,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);

    Widget field(IconData icon, String label, String val) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MlTokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.mlText.labelSmall.copyWith(
                    color: semantic.textFaint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  val,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.titleSmall.copyWith(
                    color: semantic.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlIconWell(
              icon: Icons.local_shipping_outlined,
              tone: tone,
              size: 96,
              radius: 14,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MlPlatePill(trip.reg, fontSize: 15),
                      if (badge != null) badge!,
                    ],
                  ),
                  field(Icons.apartment_rounded, 'Client', trip.buyerLabel),
                  if (trip.transporterName != null)
                    field(
                      Icons.groups_rounded,
                      'Transporter',
                      trip.transporterName!,
                    ),
                  field(
                    Icons.category_outlined,
                    'Material',
                    trip.materialLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              footnote!,
              style: context.mlText.bodySmall.copyWith(
                color: MlSemantic.of(context).textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.mlText.bodyMedium.copyWith(
        color: MlSemantic.of(context).textMuted,
      ),
    );
  }
}

/// Searched-truck confirmation card, preserving the guard's Yes/No flow and
/// the "can't release before loading" rule.
class _CheckinCard extends StatelessWidget {
  final MineTrip trip;
  final VoidCallback onArrived;
  final VoidCallback onGone;
  final VoidCallback onBack;

  const _CheckinCard({
    required this.trip,
    required this.onArrived,
    required this.onGone,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: MlPlatePill(trip.reg, fontSize: 16)),
              MlStatusBadge.forStatus(trip.status.label),
            ],
          ),
          MlCard.heroTitleRule(),
          Text(
            '${trip.buyerLabel} · ${trip.materialLabel}',
            style: context.mlText.bodyMedium.copyWith(
              color: semantic.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (trip.isInbound)
            _Question(
              text: 'Is "${trip.reg}" on site?',
              onYes: onArrived,
              onNo: onBack,
            )
          else if (trip.isOnSite) ...[
            const _Banner(
              icon: Icons.verified_outlined,
              text: 'Checked in — on site, busy loading.',
            ),
            const SizedBox(height: 14),
            _Banner(
              icon: Icons.hourglass_top_outlined,
              text:
                  'Waiting for the load controller to weigh & seal ${trip.reg} '
                  'before it can be marked loaded & gone.',
            ),
          ] else if (trip.status == TripStatus.loaded) ...[
            const _Banner(
              icon: Icons.inventory_2_outlined,
              text: 'Loaded & sealed by the controller — ready to release.',
            ),
            const SizedBox(height: 14),
            _Question(
              text: 'Is "${trip.reg}" loaded and gone?',
              onYes: onGone,
              onNo: onBack,
              yesIsDeparture: true,
            ),
          ] else
            const _Banner(
              icon: Icons.check_circle_outline,
              text: 'Loaded & gone.',
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to search'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  final String text;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final bool yesIsDeparture;

  const _Question({
    required this.text,
    required this.onYes,
    required this.onNo,
    this.yesIsDeparture = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: yesIsDeparture
                  ? MlButton.leave(
                      label: 'Yes',
                      icon: Icons.logout_rounded,
                      expand: true,
                      onPressed: onYes,
                    )
                  : MlButton.go(
                      label: 'Yes',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: onYes,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MlButton.outline(
                label: 'No',
                icon: Icons.close_rounded,
                expand: true,
                onPressed: onNo,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MlTokens.accent.withValues(alpha: 0.10),
        borderRadius: MlShape.radiusMedium,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: MlTokens.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckListDialog extends StatefulWidget {
  final List<MineTrip> trucks;
  const _TruckListDialog({required this.trucks});

  @override
  State<_TruckListDialog> createState() => _TruckListDialogState();
}

class _TruckListDialogState extends State<_TruckListDialog> {
  String? _buyer;

  @override
  Widget build(BuildContext context) {
    final buyers = widget.trucks.map((t) => t.buyerLabel).toSet().toList()
      ..sort();
    final rows = _buyer == null
        ? widget.trucks
        : widget.trucks.where((t) => t.buyerLabel == _buyer).toList();
    return AlertDialog(
      title: const Text('Inbound trucks'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              // A DropdownButtonFormField lays its selected item out at its NATURAL
              // width and sizes to the WIDEST item in the list, so one long option
              // decides the control's width whatever is selected (CLAUDE.md §10.4).
              isExpanded: true,
              initialValue: _buyer,
              decoration: const InputDecoration(
                labelText: 'Filter by buyer',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All buyers'),
                ),
                for (final b in buyers)
                  DropdownMenuItem<String?>(value: b, child: Text(b)),
              ],
              onChanged: (v) => setState(() => _buyer = v),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No inbound trucks.'),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'Reg no',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Buyer',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      for (final t in rows)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(t.tripId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.reg,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Text(t.buyerLabel)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

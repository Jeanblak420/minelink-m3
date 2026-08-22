import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/models/mine_hazard.dart';
import 'package:flutter_application_1/features/portal/models/nav_route.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';
import 'package:flutter_application_1/features/portal/providers/hazard_provider.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/portal/providers/routing_provider.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/trip_waypoint_provider.dart';
import 'package:flutter_application_1/features/portal/services/navigation_voice.dart';
import 'package:flutter_application_1/features/portal/services/place_search_service.dart';
import 'package:flutter_application_1/features/portal/services/routing_service.dart';
import 'package:flutter_application_1/features/portal/utils/nav_math.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/hazard_report_sheet.dart';
import 'package:flutter_application_1/features/portal/widgets/map_fit.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/security_confirmation_dialog.dart';
import 'package:flutter_application_1/features/portal/widgets/waypoint_progress_bar.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

final _log = LoggerFactory.getLogger('DriverNavigation');

/// Fullscreen in-app turn-by-turn navigation for drivers (spec 2026-07-16 §4):
/// OSRM route + rotating follow camera + instruction banner + voice guidance
/// + auto-reroute + arrival actions. Degrades gracefully when GPS, the
/// destination, or the routing service is unavailable.
class DriverNavigationScreen extends ConsumerStatefulWidget {
  final String tripId;
  const DriverNavigationScreen({required this.tripId, super.key});

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen>
    with SingleTickerProviderStateMixin {
  // Approved design exception (CLAUDE.md plan): the cyan→navy hero pair.
  // Was `Color(0xFF0B2545)` declared here. That is byte-identical to
  // MlTokens.navy700, the portal's navy chrome, which the driver
  // navigation shell is a part of.
  static const _navy = MlTokens.navy700;

  final _mapController = MapController();
  final _voice = NavVoice();
  StreamSubscription<Position>? _posSub;

  // Smooth motion (2026-07-17): raw GPS fixes arrive in steps; the puck and
  // follow camera glide between them instead of jumping (Waze-style feel).
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..addListener(_onMotionTick);
  LatLng? _animFrom;
  LatLng? _animTo;
  double _headingFrom = 0;
  double _headingTo = 0;
  LatLng? _smoothPos; // what the puck/camera actually show
  double _smoothHeading = 0;

  // Telemetry sharing (2026-07-17): watchers mirror the driver's navigation.
  DateTime? _lastTelemetryAt;
  bool _sentRouteOnce = false;
  DateTime? _originalEta; // local copy of the session baseline for the HUD

  bool _loading = true;
  String? _fatal; // GPS/permission problem — blocks navigation entirely.

  NavDestination? _destination;
  String? _destinationError;
  bool _offloadLeg = false;

  NavRoute? _route;
  List<double> _stepStartM = const [];
  bool _fetchingRoute = false;
  bool _routeFailed = false;

  LatLng? _pos;
  double _heading = 0;
  double _speedKmh = 0;
  double _traveledM = 0;
  int _stepIx = 0;

  int _routeSplitIx = 0; // route segment the truck is on (traveled/ahead split)
  DateTime? _offRouteSince;
  DateTime? _lastRerouteAt;
  bool _rerouting = false;
  bool _arrived = false;
  bool _followCamera = true;

  /// True once `FlutterMap` has been laid out at least once.
  ///
  /// `MapController` throws if it is used before that, and the follow camera is
  /// driven from an animation tick that can start before the first frame — see
  /// `MapOptions.onMapReady`.
  bool _mapReady = false;
  bool _muted = false;

  // Phase-5 T7 hazard layer: active hazards near the driver, overlaid on the
  // map and voice-announced when approaching. Refreshes are throttled by
  // time AND distance so the RPC is never hit on every GPS fix.
  static const _hazardRadiusM = 5000;
  static const _hazardRefreshEvery = Duration(seconds: 60);
  static const _hazardRefreshMoveM = 500.0;
  static const _hazardAnnounceM = 500.0;
  List<MineHazard> _hazards = const [];
  DateTime? _hazardsAt;
  LatLng? _hazardsAround;
  bool _hazardsRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake for the whole navigation session (real driving).
    if (!kIsWeb) WakelockPlus.enable().catchError((_) {});
    _bootstrap();
  }

  @override
  void dispose() {
    if (!kIsWeb) WakelockPlus.disable().catchError((_) {});
    _motion.dispose();
    _posSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ---- Smooth motion ---------------------------------------------------------

  void _onMotionTick() {
    final from = _animFrom, to = _animTo;
    if (from == null || to == null) return;
    final t = Curves.easeOut.transform(_motion.value);
    _smoothPos = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    // Shortest-arc heading interpolation so 350°→10° doesn't spin the long way.
    var dh = (_headingTo - _headingFrom + 540) % 360 - 180;
    _smoothHeading = (_headingFrom + dh * t + 360) % 360;
    // `_mapReady` — see `MapOptions.onMapReady` below for why this guard is
    // load-bearing rather than defensive.
    if (_mapReady && _followCamera && _smoothPos != null) {
      _mapController.moveAndRotate(
        _smoothPos!,
        _zoomForSpeed(_speedKmh),
        -_smoothHeading,
      );
    }
    if (mounted) setState(() {});
  }

  void _glideTo(LatLng pos, double heading) {
    _animFrom = _smoothPos ?? pos;
    _animTo = pos;
    _headingFrom = _smoothHeading;
    _headingTo = heading;
    _smoothPos ??= pos;
    _motion.forward(from: 0);
  }

  Future<void> _bootstrap() async {
    // Location permission — same flow as the trip position reporter.
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _loading = false;
            _fatal = 'Turn on location services (GPS) on this device first.';
          });
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _loading = false;
            _fatal =
                'Location permission denied — allow location for MineLink '
                'in your device settings, then try again.';
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fatal = 'Could not access GPS. ${friendlyError(e)}';
        });
      }
      return;
    }

    await _loadDestination();

    // Phase-5 T5: mine-nav waypoints, strictly additive — fire-and-forget so
    // a waypoint problem can never delay or block navigation.
    unawaited(_ensureWaypoints());

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(_onPosition, onError: (Object e) => _log.w('position error: $e'));

    if (mounted) setState(() => _loading = false);
  }

  /// Destination resolution. The server reports what it knows; the ORDER is
  /// decided here, because geocoding needs a service the database cannot reach
  /// (`place_index` lives on the second Supabase project — CLAUDE.md §10.2).
  ///
  /// A `?q=lat,lng` link on the request always wins: it is an exact point
  /// somebody picked for this load. After that the two candidates are the
  /// place the request NAMES in words and the party company's primary saved
  /// pin, and **which of them to believe depends on the leg**:
  ///
  /// * **Load leg — the company pin first.** The party is the mine, and its
  ///   primary location IS its collection point; CLAUDE.md calls it "the
  ///   automatic driver-navigation fallback destination" and Iron Hills'
  ///   is seeded as exactly that. The words in the form are a loose reference
  ///   to the same site. Measured 2026-08-17: geocoding "Iron Hills Mine,
  ///   Mpumalanga" through the ladder returns **"The Courier Guy, Tonga St,
  ///   Tonga, Mpumalanga"** — a courier depot 460 km from the gate, offered
  ///   with no hint that it is a guess, because the `place_index` stage does
  ///   its own fuzzy matching and reports no relaxation.
  ///
  /// * **Offload leg — the named point first.** The party is the buyer, and a
  ///   buyer's primary location is its registered office, not where this order
  ///   is delivered: ports, sidings, yards and mills change per order. The
  ///   same measurement the other way: a load booked to "Durban Port" resolved
  ///   to the buyer's Rosebank office in Johannesburg, 570 km inland, with
  ///   `found: true` so nothing downstream ever questioned it.
  ///
  /// The asymmetry is not a hedge — it is in the data model. The load leg's
  /// party is the site the product is standing on; the offload leg's party is
  /// a company whose delivery point changes with the order.
  ///
  /// Whichever wins is recorded in `source` and named on screen, and a pin
  /// that is NOT the booked point says so in the warning tone.
  Future<void> _loadDestination() async {
    try {
      final companyId = resolvePortalCompanyId(ref);
      if (companyId != null) {
        final snap = await ref.read(
          logisticsSnapshotProvider(companyId).future,
        );
        for (final t in snap.trips) {
          if (t.id == widget.tripId) {
            _offloadLeg =
                TripStatus.parse(t.status).step >= TripStatus.loaded.step;
            break;
          }
        }
      }
    } catch (e) {
      _log.w('could not resolve trip leg: $e'); // default to the load leg
    }
    try {
      var dest = await ref
          .read(companyLocationServiceProvider)
          .tripNavDestination(widget.tripId, offloadLeg: _offloadLeg);

      if (dest.point == null) {
        dest = await _resolveByLeg(dest);
      }
      if (mounted) setState(() => _destination = dest);
    } catch (e) {
      _log.w('destination lookup failed: $e');
      if (mounted) setState(() => _destinationError = '$e');
    }
  }

  /// Make sure the trip's mine-nav waypoints exist (phase-5 T5): if the trip
  /// has none yet, `auto_generate_trip_waypoints` builds the MG→WB→LP→WB→MG→
  /// drop-off sequence from the mine's configured anchors (idempotent — it
  /// returns existing rows). Best-effort: unconfigured mines simply get no
  /// progress bar, and waypoint completion NEVER advances `TripStatus`.
  Future<void> _ensureWaypoints() async {
    try {
      final svc = ref.read(tripWaypointServiceProvider);
      final existing = await svc.forTrip(widget.tripId);
      if (existing.isEmpty) {
        await svc.autoGenerate(widget.tripId);
      }
      if (mounted) ref.invalidate(tripWaypointsProvider(widget.tripId));
    } catch (e) {
      _log.w('waypoints unavailable (navigation continues without them): $e');
    }
  }

  /// Geocodes the place the request named, through the SAME staged ladder the
  /// location picker uses — saved company places, then MineLink's own
  /// `place_index`, then Nominatim as typed, relaxed, then Photon.
  ///
  /// It used to be a single raw Nominatim call. That is the one provider
  /// documented in `place_search_service.dart` as unable to answer a South
  /// African address it has not got — "OSM has no Westway Road in Fourways" —
  /// and a driver's destination is exactly where that matters most.
  /// Picks between the named point and the company pin per the leg rule
  /// documented on [_loadDestination].
  Future<NavDestination> _resolveByLeg(NavDestination dest) async {
    final named = (dest.address ?? dest.pointName ?? '').trim();
    final companyPin = dest.fallbackPoint;

    NavDestination withCompanyPin() => dest.copyWith(
      found: true,
      point: companyPin,
      label: dest.fallbackLabel ?? dest.label,
      source: 'company_location',
    );

    NavDestination withHit(PlaceHit hit) => dest.copyWith(
      found: true,
      point: hit.point,
      source: 'geocoded',
      // A broadened match answered a different question than the one asked;
      // say which, rather than presenting it as the booked place.
      label: hit.matchedQuery == null
          ? hit.label
          : '${hit.label} (nearest match for "$named")',
    );

    if (!_offloadLeg && companyPin != null) {
      return withCompanyPin(); // the mine's own collection point
    }

    final hit = named.isEmpty ? null : await _geocode(named);
    if (hit != null) {
      if (hit.matchedQuery != null) {
        _log.w(
          'destination "$named" resolved only via "${hit.matchedQuery}" '
          '→ ${hit.label}',
        );
      }
      return withHit(hit);
    }
    if (companyPin != null) {
      _log.w(
        'no place matched "$named" — using the company primary location '
        'for trip ${widget.tripId}',
      );
      return withCompanyPin();
    }
    return dest; // nothing resolvable; build() renders the no-destination state
  }

  /// Returns the best hit, INCLUDING whether the ladder had to broaden the
  /// query to find it ([PlaceHit.matchedQuery]) — the caller needs that to
  /// decide whether the hit outranks the company's saved pin.
  Future<PlaceHit?> _geocode(String q) async {
    try {
      final hits = await PlaceSearchService().search(q);
      if (hits.isEmpty) {
        _log.w('no place matched "$q"');
        return null;
      }
      return hits.first;
    } catch (e) {
      _log.w('geocode failed: $e');
      return null;
    }
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    final pos = LatLng(p.latitude, p.longitude);
    final kmh = (p.speed.isFinite ? p.speed : 0) * 3.6;
    setState(() {
      _pos = pos;
      _speedKmh = kmh < 0 ? 0 : kmh;
      // Heading is noise when stationary — only trust it in motion.
      if (p.heading.isFinite && p.heading >= 0 && _speedKmh > 3) {
        _heading = p.heading;
      }
    });

    // Glide the puck + follow camera to the new fix instead of jumping.
    _glideTo(pos, _heading);

    // Phase-5 T7: hazard layer — refresh the nearby hazards (throttled) and
    // voice-announce one approaching within ~500 m ahead of the truck.
    unawaited(_maybeRefreshHazards(pos));
    _maybeAnnounceHazard(pos);

    final destPoint = _destination?.point;
    if (destPoint == null) return;

    if (_route == null && !_fetchingRoute && !_routeFailed) {
      _fetchRoute(pos, destPoint);
    }
    if (_route != null) {
      _updateProgress(pos, destPoint);
      _maybePublishTelemetry();
    }
  }

  // ---- Telemetry sharing -------------------------------------------------------

  ({DateTime eta, int timeLeftS, int distLeftM})? _liveEstimates() {
    final r = _route;
    if (r == null || r.distanceM <= 0) return null;
    final remainM = remainingMeters(r.distanceM, _traveledM);
    final remainS = r.durationS * (remainM / r.distanceM);
    return (
      // `MlTime.now()`, not `DateTime.now()`. This ETA is READ — it is the
      // clock time in the driver's HUD — and CLAUDE.md §7.1 makes every time a
      // user reads a South African one. A laptop or a handset left on another
      // zone printed an arrival hour that was simply not the hour.
      //
      // It is a WALL CLOCK, so it must be converted back at the wire:
      // `publishNavState` does `eta.toUtc()`, and a wall clock pushed through
      // that lands hours out. Both publish sites wrap it in `MlTime.toServer`.
      eta: MlTime.now().add(Duration(seconds: remainS.round())),
      timeLeftS: remainS.round(),
      distLeftM: remainM.round(),
    );
  }

  String? _currentInstructionText() {
    final r = _route;
    if (r == null || r.steps.isEmpty) return null;
    final step = _stepIx < r.steps.length ? r.steps[_stepIx] : r.steps.last;
    return step.instruction;
  }

  /// Pushes the nav state watchers mirror (throttled to ~10s). Route polyline
  /// and the original-ETA baseline are sent by [_publishRoute] instead.
  void _maybePublishTelemetry({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastTelemetryAt != null &&
        now.difference(_lastTelemetryAt!) < const Duration(seconds: 10)) {
      return;
    }
    final est = _liveEstimates();
    if (est == null) return;
    _lastTelemetryAt = now;
    ref
        .read(liveTrackingServiceProvider)
        .publishNavState(
          instruction: _arrived
              ? 'Arrived at destination'
              : _currentInstructionText(),
          eta: MlTime.toServer(est.eta),
          timeLeftS: est.timeLeftS,
          distanceLeftM: est.distLeftM,
          speedKmh: _speedKmh,
        );
  }

  /// Publishes the (re)fetched route so watchers draw exactly what the driver
  /// sees. The first route of the session also sets the original-ETA baseline.
  void _publishRoute(NavRoute route) {
    // Both callers reach here after an await (route fetch / reroute), and a
    // driver who leaves navigation mid-fetch would otherwise hit the
    // `StateError` from `ref` on a disposed screen.
    if (!mounted) return;
    final est = _liveEstimates();
    final newSession = !_sentRouteOnce;
    if (newSession) _originalEta = est?.eta;
    _sentRouteOnce = true;
    _lastTelemetryAt = DateTime.now();
    ref
        .read(liveTrackingServiceProvider)
        .publishNavState(
          instruction: _currentInstructionText(),
          eta: est == null ? null : MlTime.toServer(est.eta),
          timeLeftS: est?.timeLeftS,
          distanceLeftM: est?.distLeftM,
          speedKmh: _speedKmh,
          routePolyline: route.encoded,
          newSession: newSession,
        );
  }

  double _zoomForSpeed(double kmh) => kmh >= 80
      ? 14
      : kmh >= 40
      ? 15.5
      : 17;

  /// Critical-hazard avoid points along the from→to corridor (phase-5 §1):
  /// queried at the leg's midpoint with a radius covering the whole span
  /// (+20 km margin). Best-effort — `avoidZonesNear` never throws, so a
  /// hazard-fetch failure can never block routing.
  Future<List<LatLng>> _avoidZones(LatLng from, LatLng to) {
    final mid = LatLng(
      (from.latitude + to.latitude) / 2,
      (from.longitude + to.longitude) / 2,
    );
    final spanM = const Distance().as(LengthUnit.Meter, from, to);
    return ref
        .read(hazardServiceProvider)
        .avoidZonesNear(mid, radiusMeters: (spanM / 2).round() + 20000);
  }

  // ---- Hazard layer (phase-5 T7) ---------------------------------------------

  /// Refresh the hazard overlay around [pos] — at most once per
  /// [_hazardRefreshEvery], or sooner after [_hazardRefreshMoveM] metres of
  /// travel ([force] bypasses the throttle right after a report). Best-effort:
  /// a failure keeps the last markers and retries on the normal cadence.
  Future<void> _maybeRefreshHazards(LatLng pos, {bool force = false}) async {
    if (_hazardsRefreshing) return;
    final movedM = _hazardsAround == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _hazardsAround!, pos);
    final stale =
        _hazardsAt == null ||
        DateTime.now().difference(_hazardsAt!) > _hazardRefreshEvery;
    if (!force && !stale && movedM < _hazardRefreshMoveM) return;
    _hazardsRefreshing = true;
    try {
      final hazards = await ref
          .read(hazardServiceProvider)
          .nearby(pos.latitude, pos.longitude, radiusMeters: _hazardRadiusM);
      if (!mounted) return;
      setState(
        () => _hazards = [
          for (final h in hazards)
            if (h.isActive) h, // only non-expired hazards render/announce
        ],
      );
    } catch (e) {
      _log.w('hazard refresh failed (markers keep last data): $e');
    } finally {
      // Stamp even on failure so a broken endpoint is retried on the normal
      // cadence instead of on every GPS fix.
      _hazardsAt = DateTime.now();
      _hazardsAround = pos;
      _hazardsRefreshing = false;
    }
  }

  /// Voice-announce the nearest active hazard within ~[_hazardAnnounceM]
  /// AHEAD of the truck ("Caution: blasting zone ahead"). "Ahead" = within
  /// ±75° of the travel heading, so hazards behind or beside stay silent.
  /// [NavVoice.announceHazard] de-dupes by hazard id (never the same hazard
  /// twice in a row) and speaks through the same TTS pipeline as turn
  /// coaching, so turn-by-turn interrupt behaviour is unchanged.
  void _maybeAnnounceHazard(LatLng pos) {
    if (_speedKmh <= 3) return; // heading is noise when stationary
    const d = Distance();
    MineHazard? nearest;
    var nearestM = double.infinity;
    for (final h in _hazards) {
      if (!h.isActive) continue;
      final p = LatLng(h.latitude, h.longitude);
      final m = d.as(LengthUnit.Meter, pos, p);
      if (m > _hazardAnnounceM || m >= nearestM) continue;
      final dh = (_bearingDeg(pos, p) - _heading + 540) % 360 - 180;
      if (dh.abs() > 75) continue; // behind/beside — not "ahead"
      nearestM = m;
      nearest = h;
    }
    if (nearest != null) {
      _voice.announceHazard(
        hazardId: nearest.id,
        text: 'Caution: ${nearest.typeLabel.toLowerCase()} ahead',
      );
    }
  }

  /// Initial great-circle bearing a→b in degrees [0, 360).
  static double _bearingDeg(LatLng a, LatLng b) {
    final phi1 = a.latitudeInRad, phi2 = b.latitudeInRad;
    final dLon = b.longitudeInRad - a.longitudeInRad;
    final y = math.sin(dLon) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Severity → tone: critical→error, medium→warn, low→neutral (design §3.4).
  MlTone _hazardTone(MineHazard h) => h.isCritical
      ? MlTone.error
      : h.severity == 'medium'
      ? MlTone.warn
      : MlTone.neutral;

  /// "Report a hazard" action: bottom sheet → `HazardService.report` at the
  /// CURRENT position (plain lat/lng insert), then refresh the overlay.
  Future<void> _reportHazard() async {
    final messenger = ScaffoldMessenger.of(context);
    final pos = _pos;
    if (pos == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Waiting for a GPS fix — try again in a moment.'),
        ),
      );
      return;
    }
    final draft = await showHazardReportSheet(context);
    if (draft == null || !mounted) return;
    try {
      // A hazard belongs to a mine — that is what decides which drivers see
      // it (migration 20260816220000). Resolved from THIS trip on the server
      // rather than guessed here, so it cannot name a mine this driver is not
      // going to.
      final mineId = await ref
          .read(hazardServiceProvider)
          .mineForTrip(widget.tripId);
      if (mineId == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not tell which mine this trip is for, so '
              'the hazard was not sent.',
            ),
          ),
        );
        return;
      }
      await ref
          .read(hazardServiceProvider)
          .report(
            type: draft.type,
            mineCompanyId: mineId,
            severity: draft.severity,
            description: draft.description,
            lat: pos.latitude,
            lng: pos.longitude,
          );
      ref.invalidateIfMounted(nearbyHazardsProvider);
      if (mounted) unawaited(_maybeRefreshHazards(pos, force: true));
      messenger.showSnackBar(
        const SnackBar(content: Text('Hazard reported — thank you.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not report the hazard. ${friendlyError(e)}'),
        ),
      );
    }
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    setState(() {
      _fetchingRoute = true;
      _routeFailed = false;
    });
    final zones = await _avoidZones(from, to);
    final route = await ref
        .read(routingServiceProvider)
        .fetchRoute(from, to, avoidLocations: zones);
    if (!mounted) return;
    setState(() {
      _fetchingRoute = false;
      if (route == null || route.points.length < 2) {
        _routeFailed = true;
      } else {
        _route = route;
        _stepStartM = stepStartOffsets(route.points, route.steps);
        _voice.reset();
        // Seed the progress from where the truck IS, rather than parking on
        // step 0 until the next fix arrives.
        //
        // `_stepIx = 0` meant the banner read the DEPARTURE step with its
        // distance-to-manoeuvre measured to the start of the route — so between
        // the route landing and the next GPS fix it said **"In 0 m — Head out
        // onto Dwarsrivier Road"**. Photographed 2026-08-20, and it is not only
        // a render artefact: the position stream has a 3 m distance filter, so
        // a truck stationary at a boom gate genuinely sits in that state, and
        // the voice announces from the same figure.
        //
        // `_updateProgress` is what every later fix calls; calling it here
        // means the first frame after a route is the same shape as every frame
        // after it. Safe inside `setState` — it assigns fields and hands the
        // instruction to the voice engine, and does not call `setState` itself.
        _updateProgress(from, to);
      }
    });
    if (route != null && route.points.length >= 2) _publishRoute(route);
  }

  void _updateProgress(LatLng pos, LatLng destPoint) {
    final r = _route!;
    final proj = projectOnRoute(r.points, pos);
    _traveledM = proj.traveledM;
    _routeSplitIx = proj.segIndex;
    _stepIx = currentStepIndex(_stepStartM, _traveledM);
    if (_stepIx < r.steps.length && _stepStartM.isNotEmpty) {
      final mtm = (_stepStartM[_stepIx] - _traveledM)
          .clamp(0.0, double.infinity)
          .toDouble();
      _voice.onProgress(
        stepIndex: _stepIx,
        metersToManeuver: mtm,
        instruction: r.steps[_stepIx].instruction,
      );
    }

    if (isOffRoute(proj.offRouteM)) {
      _offRouteSince ??= DateTime.now();
      final offFor = DateTime.now().difference(_offRouteSince!);
      final cooledDown =
          _lastRerouteAt == null ||
          DateTime.now().difference(_lastRerouteAt!) >
              const Duration(seconds: 15);
      if (!_rerouting && offFor > const Duration(seconds: 5) && cooledDown) {
        _reroute(pos, destPoint);
      }
    } else {
      _offRouteSince = null;
    }

    if (!_arrived && hasArrived(pos, destPoint)) {
      _arrived = true;
      _voice.announceArrived();
      _maybePublishTelemetry(force: true);
    }
    setState(() {});
  }

  Future<void> _reroute(LatLng from, LatLng to) async {
    setState(() => _rerouting = true);
    _lastRerouteAt = DateTime.now();
    _voice.announceRerouting();
    final zones = await _avoidZones(from, to);
    final route = await RoutingService().fetchRoute(
      from,
      to,
      avoidLocations: zones,
    );
    if (!mounted) return;
    setState(() {
      _rerouting = false;
      _offRouteSince = null;
      if (route != null && route.points.length >= 2) {
        _route = route;
        _stepStartM = stepStartOffsets(route.points, route.steps);
        _stepIx = 0;
        _voice.reset();
      }
    });
    // Reroute keeps the session's original ETA — lateness stays vs the plan.
    if (route != null && route.points.length >= 2) _publishRoute(route);
  }

  Future<void> _openExternalMaps() async {
    final d = _destination;
    final target = d?.point != null
        ? '${d!.point!.latitude},${d.point!.longitude}'
        : (d?.address ?? '');
    if (target.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(target)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
    }
  }

  Future<void> _markArrivedAtMine() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(lifecycleServiceProvider)
          .setTripStatus(widget.tripId, TripStatus.arrivedAtMine);
      messenger.showSnackBar(
        const SnackBar(content: Text('Marked arrived at the mine.')),
      );
      router.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update the trip. ${friendlyError(e)}'),
        ),
      );
    }
  }

  /// "Confirm at gate" (phase-5 T6): the driver's side of the two-party
  /// security-gate confirmation — arrival while heading to load, exit once
  /// loaded and leaving. Strictly ADDITIVE bookkeeping over
  /// `security_confirmations`: it never advances `TripStatus` (the
  /// `set_trip_status` cascade stays authoritative) and any failure is
  /// swallowed after logging so navigation keeps working regardless.
  Future<void> _confirmAtGate() async {
    try {
      final type = _offloadLeg
          ? SecurityConfirmationType.exit
          : SecurityConfirmationType.arrival;
      final waypoints =
          ref.read(tripWaypointsProvider(widget.tripId)).valueOrNull ??
          const <TripWaypoint>[];
      final gate = waypoints
          .where((w) => w.locationType == WaypointType.mainGate)
          .firstOrNull;
      final gateName = (gate?.name ?? '').trim().isNotEmpty
          ? gate!.name
          : 'Main Gate';
      if (!mounted) return;
      await SecurityConfirmationDialog.show(
        context: context,
        tripId: widget.tripId,
        type: type,
        gateName: gateName,
      );
    } catch (e) {
      _log.w('gate confirmation unavailable (navigation continues): $e');
    }
  }

  String _fmtMeters(double m) => m < 1000
      ? 'In ${(m / 10).round() * 10} m'
      : 'In ${(m / 1000).toStringAsFixed(1)} km';

  String _fmtDistance(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  /// Puts the camera back on the truck and resumes following.
  ///
  /// Both halves matter and the old FAB only did the second reliably: without
  /// `_followCamera = true` the next GPS fix would not move the camera, so the
  /// map jumped to the truck once and then went stale again — which reads as
  /// the button not having worked.
  void _recenterOnMe() {
    final p = _smoothPos ?? _pos;
    if (p == null) return;
    setState(() => _followCamera = true);
    if (!_mapReady) return;
    _mapController.moveAndRotate(p, _zoomForSpeed(_speedKmh), -_smoothHeading);
  }

  /// Frames the whole journey — Google Maps' "route overview".
  ///
  /// Turns following OFF, because a camera that snaps back to the truck on the
  /// next fix would undo this within a second and look like a glitch. The
  /// my-location button then reads "not following", which is the truth and is
  /// how the driver gets back.
  void _overview() {
    if (!_mapReady) return;
    final pts = <LatLng>[
      if (_route != null && _route!.points.length >= 2) ..._route!.points,
      if (_pos != null) _pos!,
      if (_destination?.point != null) _destination!.point!,
    ];
    if (pts.isEmpty) return;
    setState(() => _followCamera = false);
    _mapController.rotate(0);
    _mapController.fitCamera(
      safeCoordinatesFit(
        pts,
        // Room for the instruction banner above and the HUD below, so the
        // route is not framed underneath either of them.
        padding: const EdgeInsets.fromLTRB(40, 150, 40, 190),
      ),
    );
  }

  /// Press and hold the map to drop a pin (jean, 2026-08-22).
  ///
  /// `onLongPress` was null on every map in this product, so holding a finger
  /// on one did nothing at all.
  void _droppedPin(LatLng point) {
    showMlDroppedPin(context, point: point, from: _smoothPos ?? _pos);
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_fatal != null) {
      return _messageScaffold(
        icon: Icons.gps_off_rounded,
        title: 'Navigation needs your location.',
        message: _fatal!,
        extra: MlButton.outline(
          label: 'Open settings',
          icon: Icons.settings_outlined,
          onPressed: () => Geolocator.openAppSettings(),
        ),
      );
    }

    final destPoint = _destination?.point;
    if (destPoint == null) {
      final hasAddress = (_destination?.address ?? '').trim().isNotEmpty;
      return _messageScaffold(
        icon: Icons.wrong_location_outlined,
        title: 'No destination set for this trip.',
        message: _destinationError != null
            ? 'Could not resolve the destination: $_destinationError'
            : hasAddress
            ? 'The location "${_destination!.address}" could not be placed '
                  'on the map. You can still open it in an external maps app.'
            : 'Ask the ${_offloadLeg ? 'buyer' : 'mine'} to set their '
                  'collection point under Locations on their company profile.',
        extra: hasAddress
            ? MlButton.outline(
                label: 'Open in external maps',
                icon: Icons.open_in_new_rounded,
                onPressed: _openExternalMaps,
              )
            : null,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _map(destPoint),
          // Top instruction banner (+ waypoint progress when the trip has a
          // mine-nav sequence — absent/empty renders nothing, phase-5 T5).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  _banner(destPoint),
                  _destinationBar(),
                  _waypointBar(),
                ],
              ),
            ),
          ),
          // The map controls (jean, 2026-08-22).
          //
          // This was a `FloatingActionButton.small` that existed ONLY while
          // `!_followCamera`, so the control a driver reaches for after swiping
          // the map away was invisible until the moment he had already swiped —
          // and there was nothing else: no zoom, no way back to north, no way to
          // see the whole route. `MlMapControls` is always here, and its
          // my-location button says which of the three states it is in rather
          // than appearing and disappearing.
          Positioned(
            right: 2,
            bottom: 128,
            child: MlMapControls(
              controller: _mapController,
              hasFix: _pos != null,
              following: _followCamera,
              recenterTooltip: 'Follow my truck again',
              onRecenter: _recenterOnMe,
              onOverview: _overview,
              overviewTooltip: 'See the whole route',
            ),
          ),
          // Arrival action.
          if (_arrived)
            Positioned(
              left: 12,
              right: 12,
              bottom: 118,
              child: MlCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const MlIconWell(
                      icon: Icons.sports_score_rounded,
                      tone: MlTone.done,
                      size: 40,
                      radius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have arrived.',
                        style: context.mlText.titleMedium.copyWith(
                          color: semantic.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _offloadLeg
                        ? MlButton.go(
                            label: 'Upload POD',
                            icon: Icons.fact_check_outlined,
                            compact: true,
                            onPressed: () => context.pop(),
                          )
                        : MlButton.go(
                            label: 'Arrived at mine',
                            icon: Icons.where_to_vote_outlined,
                            compact: true,
                            onPressed: _markArrivedAtMine,
                          ),
                  ],
                ),
              ),
            ),
          // Bottom stats bar.
          Positioned(left: 12, right: 12, bottom: 14, child: _bottomBar()),
        ],
      ),
    );
  }

  Widget _messageScaffold({
    required IconData icon,
    required String title,
    required String message,
    Widget? extra,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MlEmptyState(icon: icon, title: title, message: message),
              if (extra != null) ...[const SizedBox(height: 14), extra],
              const SizedBox(height: 10),
              MlButton.ghost(
                label: 'Close',
                icon: Icons.close_rounded,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _map(LatLng destPoint) {
    // Marker rotation: markers counter-rotate to stay screen-up (rotate:
    // true), so the truck arrow needs heading + camera rotation to point the
    // way the truck is travelling on screen.
    double camRot = 0;
    try {
      camRot = _mapController.camera.rotation;
    } catch (e) {
      // Thrown only before the map's first layout, when there is no camera yet;
      // 0 is the correct rotation at that moment. Logged rather than swallowed
      // (P0-11 / S1-7) so a *persistent* throw here is visible instead of
      // silently pinning the truck arrow to north for the whole trip.
      _log.d('camera rotation unavailable (pre-layout), using 0: $e');
    }
    final arrowRad = (_smoothHeading + camRot) * math.pi / 180;
    final puckPos = _smoothPos ?? _pos;

    // Split the route at the truck: the part already driven dims out so the
    // road ahead reads instantly (Waze/Google-Maps behaviour).
    List<LatLng> behind = const [], ahead = const [];
    final r = _route;
    if (r != null && r.points.length >= 2) {
      final cut = _routeSplitIx.clamp(0, r.points.length - 1);
      behind = r.points.sublist(0, cut + 1);
      ahead = [if (puckPos != null) puckPos, ...r.points.sublist(cut + 1)];
      if (ahead.length < 2) ahead = r.points;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _pos ?? destPoint,
        initialZoom: 15,
        // Not flutter_map's near-white default: see mlMapBackground. A driver
        // at a boom gate with no signal gets the ground the rest of the screen
        // is painted on, not a white sheet.
        backgroundColor: mlMapBackground(context),
        // The camera cannot be driven before this fires.
        //
        // `MapController.moveAndRotate` throws "You need to have the FlutterMap
        // widget rendered at least once before using the MapController", and
        // the follow camera in `_onMotionTick` called it on every animation
        // tick with no guard. That is a RACE, not a theoretical one: the
        // position stream is subscribed at the end of `_bootstrap`, BEFORE the
        // `setState` that flips `_loading` false — so on a phone with a warm
        // GPS fix the first position can arrive, start the glide animation and
        // tick it, all before the frame that first builds this map. The
        // exception then escapes an AnimationController listener, on the
        // driver's navigation screen, at the moment navigation starts.
        //
        // Found 2026-08-20 by rendering the screen for the first time — the
        // render harness delivers its first fix immediately, which is the same
        // shape as a warm fix and is why it reproduced every time.
        onMapReady: () {
          _mapReady = true;
          // Catch up: the fixes that arrived before the map existed left the
          // camera behind, and without this the puck sits still until the next
          // one — which on a truck stopped at a boom gate can be a long time.
          final p = _smoothPos ?? _pos;
          if (p != null && _followCamera) {
            _mapController.moveAndRotate(
              p,
              _zoomForSpeed(_speedKmh),
              -_smoothHeading,
            );
          }
        },
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && _followCamera) {
            setState(() => _followCamera = false);
          }
        },
        // Press and hold to ask where something is — see [_droppedPin].
        onLongPress: (tapPosition, point) => _droppedPin(point),
      ),
      children: [
        mlOsmTiles(context),
        if (_route != null)
          PolylineLayer(
            polylines: [
              // Driven part, dimmed.
              if (behind.length >= 2)
                Polyline(
                  points: behind,
                  strokeWidth: 7,
                  color: _navy.withValues(alpha: 0.30),
                ),
              // Road ahead — full contrast casing + accent.
              if (ahead.length >= 2) ...[
                Polyline(points: ahead, strokeWidth: 11, color: _navy),
                Polyline(points: ahead, strokeWidth: 7, color: MlTokens.accent),
              ],
            ],
          )
        else if (_pos != null)
          // Degraded mode: straight bearing line to the destination.
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_pos!, destPoint],
                strokeWidth: 4,
                color: MlTokens.accent,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // Phase-5 T7: active hazards near the driver, severity-toned
            // (critical→error, medium→warn, low→neutral).
            for (final h in _hazards)
              if (h.isActive)
                Marker(
                  point: LatLng(h.latitude, h.longitude),
                  width: 32,
                  height: 32,
                  child: _hazardMarker(h),
                ),
            Marker(
              point: destPoint,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: Icon(
                Icons.location_on_rounded,
                size: 40,
                color: MlTone.error.colors(Theme.of(context).brightness).fg,
              ),
            ),
            if (puckPos != null)
              Marker(
                point: puckPos,
                width: 46,
                height: 46,
                child: Transform.rotate(
                  angle: arrowRad,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: MlTokens.inkOnFill, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: MlTokens.navyShadowStrong,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      size: 26,
                      color: MlTokens.inkOnFill,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // SCALE. A map with no scale asks the driver to guess whether the gap
        // to the next turn is 200 m or 2 km. Lifted clear of the HUD card,
        // which is `Positioned(bottom: 14)` and about 100–160 tall.
        Padding(
          padding: const EdgeInsets.only(bottom: 170),
          child: mlMapScaleBar(context),
        ),
        // ATTRIBUTION — this map had none.
        //
        // Four of the product's five maps call `mlMapAttribution()`; this one,
        // the only fullscreen map and the one a driver stares at for an hour,
        // did not. OpenStreetMap's licence requires the credit, and the helper
        // exists precisely so the credit follows whichever host `MAP_TILE_URL`
        // is pointed at.
        //
        // Bottom-LEFT, and padded up: in the default bottom-right corner the
        // my-location disc paints over it (measured, x 350..352 of the credit's
        // 334..352 — see `mlMapAttribution`), and in the corner proper it
        // renders behind the HUD card.
        Padding(
          padding: const EdgeInsets.only(bottom: 118),
          child: mlMapAttribution(alignment: AttributionAlignment.bottomLeft),
        ),
      ],
    );
  }

  /// One severity-toned hazard marker (tooltip = type + description).
  Widget _hazardMarker(MineHazard h) {
    final c = _hazardTone(h).colors(Theme.of(context).brightness);
    return Tooltip(
      message: h.description.trim().isEmpty
          ? h.typeLabel
          : '${h.typeLabel} — ${h.description}',
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          shape: BoxShape.circle,
          border: Border.all(color: c.fg, width: 2),
        ),
        child: Icon(Icons.warning_amber_rounded, size: 17, color: c.fg),
      ),
    );
  }

  /// Where this navigation is actually taking the truck, in words, under the
  /// turn banner.
  ///
  /// The screen used to name no destination at all: a map, a route line and a
  /// pin, with nothing saying which place they meant. That is survivable while
  /// the pin is right and indefensible while it is not — the same screen
  /// silently routed a Durban Port load to the buyer's Johannesburg office for
  /// as long as this feature has existed. A driver who can read the
  /// destination can catch that in the yard instead of at the other end of a
  /// province.
  ///
  /// When the pin is a company address rather than the booked point, it says
  /// so out loud in the warning tone, and still shows the booked point.
  Widget _destinationBar() {
    final d = _destination;
    if (d == null) return const SizedBox.shrink();
    final booked = (d.pointName ?? '').trim();
    final semantic = MlSemantic.of(context);
    // Only the OFFLOAD leg warns when the pin is a company address: on the
    // load leg the mine's primary location IS the collection point, so saying
    // "check with your controller" there would cry wolf on every single trip.
    final fallback = d.isCompanyFallback && _offloadLeg;
    final tone = fallback ? MlTone.warn : MlTone.accent;
    final colors = tone.colors(Theme.of(context).brightness);

    final headline = booked.isNotEmpty ? booked : d.label;
    final detail = fallback
        ? 'No map pin for "$booked" — heading to the registered address on '
              'file, ${d.label}. Check with your controller before you offload.'
        : switch (d.source) {
            'request' => 'Exact pin from the booking.',
            'company_location' => d.label,
            'geocoded' => 'Address lookup — ${d.label}.',
            _ => d.label,
          };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MlCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              fallback ? Icons.warning_amber_rounded : Icons.place_outlined,
              size: 20,
              color: colors.fg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The leg on its own line, as a label.
                  //
                  // It used to be a prefix — "Offloading at  {place}" on ONE
                  // line with an ellipsis — so thirteen characters of preamble
                  // ate the front of the only field on this screen that says
                  // where the truck is going. Photographed 2026-08-20 at 412px:
                  // "Offloading at  Iron Hills Mining — collection po…".
                  //
                  // As a label it costs no horizontal room at all, and the place
                  // gets the whole width and two lines.
                  Text(
                    (_offloadLeg ? 'Offloading at' : 'Loading at')
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.overline.copyWith(
                      color: semantic.textFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleSmall.copyWith(
                      color: semantic.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // …and nothing underneath when the detail line would only
                  // repeat it. `detail` falls back to `d.label`, which for a
                  // booked pin IS the headline, so the bar printed the same
                  // place twice — the first copy truncated.
                  if (detail.trim().isNotEmpty &&
                      detail.trim() != headline.trim())
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(
                        color: fallback ? colors.fg : semantic.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Waypoint progress under the instruction banner — display-only (waypoint
  /// completion is independent of the `set_trip_status` lifecycle) and fully
  /// absent while loading, on error, or for trips without waypoints.
  Widget _waypointBar() {
    final waypoints =
        ref.watch(tripWaypointsProvider(widget.tripId)).valueOrNull ??
        const <TripWaypoint>[];
    if (waypoints.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MlCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: WaypointProgressBar(waypoints: waypoints),
      ),
    );
  }

  Widget _banner(LatLng destPoint) {
    final r = _route;
    String primary;
    String? secondary;
    IconData icon;

    if (_rerouting) {
      icon = Icons.alt_route_rounded;
      primary = 'Rerouting…';
    } else if (r == null) {
      if (_fetchingRoute) {
        icon = Icons.route_outlined;
        primary = 'Finding the best route…';
      } else if (_routeFailed) {
        icon = Icons.cloud_off_rounded;
        final p = _pos;
        final dist = p == null
            ? null
            : const Distance().as(LengthUnit.Meter, p, destPoint);
        primary = dist == null
            ? 'Navigation service unreachable.'
            : 'Head to the pin — ${_fmtDistance(dist)} away.';
        secondary = 'Turn-by-turn is unavailable right now.';
      } else {
        icon = Icons.gps_fixed_rounded;
        primary = 'Waiting for GPS…';
      }
    } else {
      final step = _stepIx < r.steps.length ? r.steps[_stepIx] : r.steps.last;
      icon = step.maneuver.icon;
      final mtm = _stepStartM.isEmpty
          ? 0.0
          : (_stepStartM[math.min(_stepIx, _stepStartM.length - 1)] -
                    _traveledM)
                .clamp(0.0, double.infinity)
                .toDouble();
      primary = '${_fmtMeters(mtm)} — ${step.instruction}';
      final nextIx = _stepIx + 1;
      if (nextIx < r.steps.length) {
        secondary = 'then ${r.steps[nextIx].instruction}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: MlShape.radiusLarge,
        boxShadow: const [
          BoxShadow(
            color: MlTokens.navyShadowSoft,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: MlTokens.inkOnFill),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: MlTokens.inkOnFill,
                  ),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  // Two lines, like the primary above it.
                  //
                  // At one line the degraded banner read "Turn-by-turn is
                  // unavailable righ…" on a 412px phone — the sentence that
                  // explains why there is no route line, cut before it says
                  // anything. It shares the row with two icon buttons in that
                  // state, which is exactly when there is least width for it.
                  Text(
                    secondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MlTokens.inkOnFill70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_routeFailed && !_fetchingRoute) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Retry route',
              onPressed: () {
                final p = _pos;
                if (p != null) _fetchRoute(p, destPoint);
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: MlTokens.inkOnFill,
              ),
            ),
            IconButton(
              tooltip: 'Open in external maps',
              onPressed: _openExternalMaps,
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: MlTokens.inkOnFill,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final semantic = MlSemantic.of(context);
    // ONE estimate, shared with the telemetry.
    //
    // This block used to recompute `remainM`, `remainS` and the ETA itself,
    // duplicating `_liveEstimates()` line for line — so the number in the
    // driver's HUD and the number published to every watcher could drift apart
    // the moment either was touched. And it was the copy that still said
    // `DateTime.now()`, so the HUD printed the DEVICE's clock while everything
    // else in the product had moved to South African time (CLAUDE.md §7.1).
    final est = _liveEstimates();
    String eta = '—', mins = '—', dist = '—';
    String plan = '—';
    Color? planColor;
    if (est != null) {
      final etaAt = est.eta;
      eta = DateFormat.Hm().format(etaAt);
      mins = '${(est.timeLeftS / 60).ceil()} min';
      dist = _fmtDistance(est.distLeftM.toDouble());
      // Late vs the session's original ETA (kept across reroutes).
      final base = _originalEta;
      if (base != null) {
        final overrunMin = etaAt.difference(base).inMinutes;
        final tones = Theme.of(context).brightness;
        if (overrunMin >= 2) {
          plan = '+$overrunMin min';
          planColor = MlTone.error.colors(tones).fg;
        } else if (overrunMin <= -2) {
          plan = '$overrunMin min';
          planColor = MlTone.done.colors(tones).fg;
        } else {
          plan = 'on time';
          planColor = MlTone.done.colors(tones).fg;
        }
      }
    }

    Widget cell(String value, String label, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.mlText.code(
              color: color ?? semantic.textStrong,
              size: 16,
              weight: FontWeight.w800,
            ),
          ),
          // The LABEL may take two lines, the value may not.
          //
          // "Time left" does not fit a 72px readout at text scale 1.3, and
          // wrapping it at its space keeps both words. A VALUE has no space
          // to wrap at — "6.1 km" broken across lines is unreadable at a
          // glance — so that one stays on one line and ellipsises as a last
          // resort.
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.mlText.labelSmall.copyWith(
              color: semantic.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    final readouts = <Widget>[
      cell(eta, 'ETA'),
      cell(mins, 'Time left'),
      cell(dist, 'Distance'),
      cell(plan, 'vs plan', color: planColor),
      cell('${_speedKmh.round()}', 'km/h'),
    ];

    final actions = <Widget>[
      IconButton(
        tooltip: 'Report a hazard',
        onPressed: _reportHazard,
        icon: const Icon(Icons.warning_amber_rounded),
      ),
      IconButton(
        tooltip: _offloadLeg
            ? 'Confirm at gate — exit'
            : 'Confirm at gate — arrival',
        onPressed: _confirmAtGate,
        icon: const Icon(Icons.shield_outlined),
      ),
      IconButton(
        tooltip: _muted ? 'Unmute voice' : 'Mute voice',
        onPressed: () => setState(() {
          _muted = !_muted;
          _voice.muted = _muted;
        }),
        icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
      ),
      MlButton.danger(
        label: 'End',
        compact: true,
        onPressed: () => context.pop(),
      ),
    ];

    // ── The readouts get their own row on a phone. ────────────────────────
    //
    // This was one `Row`: five `Expanded` readouts, three 48px icon buttons and
    // an End button. On a 412px phone the buttons take ~215px of it, leaving
    // roughly 30px per readout — so the HUD a driver GLANCES AT rendered
    // "Dista / nce", "on / tim / e" and "22: / 26", every label and half the
    // values broken across lines. Photographed 2026-08-20, the first time this
    // screen had ever been rendered anywhere.
    //
    // Five readouts across 412px is ~78px each, which fits every string at its
    // natural size, so the split costs one row of height and nothing else. The
    // threshold scales with the type, like `MlSectionTitle`'s: a fixed
    // breakpoint under a user-controlled text size is right at one setting only.
    //
    // `maxLines: 1` above is the backstop, not the fix — a HUD that ellipsises
    // "+120 min" is bad, and one that stacks it into three lines mid-word is
    // worse.
    return MlCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;

          // How much room one readout gets if all five share the row. 66 is what
          // the widest label — "Distance" — needs at scale 1; MEASURED, after a
          // first attempt guessed a whole-bar threshold and still wrapped
          // "Dista / nce" at 360px × 1.3, where five readouts get 62.4px each.
          final perCell = (c.maxWidth - 24) / 5;
          final readoutsFit = perCell >= 66 * scale;

          if (c.maxWidth >= 620 * scale && readoutsFit) {
            return Row(children: [...readouts, ...actions]);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (readoutsFit)
                Row(children: readouts)
              else ...[
                // Three and two. Uneven, and right: the three a driver reads
                // most while moving go on top, at 104px each, where every label
                // fits whole at any scale this console offers.
                Row(children: readouts.sublist(0, 3)),
                const SizedBox(height: 6),
                Row(children: readouts.sublist(3)),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions,
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// A trip inbound to a mine (the mine is the supplier party), with the display
/// fields the Security check-in and Load Controller screens need. Backed by the
/// list_mine_inbound_trips RPC.
class MineTrip {
  final String tripId;
  final TripStatus status;
  final String? vehicleId;
  final String? truckReg;
  final String? routeId;
  final bool sealRequired;

  /// How many seals this rig must carry — `public.expected_seal_count`, which
  /// reads `fleet_vehicles.seal_points`: a stated fact about the vehicle that
  /// the transporter owns and can correct.
  ///
  /// Read from the server rather than assumed, because the sheet used to
  /// hardcode four slots under a heading that said "4 total" whatever was
  /// hitched to the truck, and `record_truck_load` enforced only "not zero".
  /// Production held a sealed load recorded with 2 seals on a two-trailer
  /// interlink and another with 13 (measured 2026-08-17). The first fix
  /// inferred the count from the OPTIONAL trailer-registration fields, which
  /// meant a blank registration silently changed what the weighbridge demanded;
  /// migration 20260817320000 replaced that with stored data.
  ///
  /// Defaults to 4 when absent so a client running against an older server
  /// keeps today's behaviour rather than dropping to the floor.
  final int expectedSeals;

  final double? netTons;

  /// First weigh: the empty truck, captured on arrival before loading.
  ///
  /// Both weighs are kept, not just their difference, so the two readings that
  /// produced [netTons] can each be looked at (migration 20260817230000). A
  /// trip loaded before that migration has null here and a real [netTons].
  final double? tareTons;

  /// Second weigh: truck plus cargo, captured after loading.
  final double? grossTons;

  /// When the empty weigh was taken and the truck went to load. The gap to the
  /// load is how long it spent under the shovel.
  final DateTime? loadingAt;
  final String transactionId;
  final String? buyerCompanyId;
  final String? buyerName;
  final String? transporterName;
  final String? commodity;

  /// The transaction reference (`TRP-…`) — the single shared identifier used
  /// as the waybill NUMBER and the recon WAYBILL NUMBER column (§4).
  final String? reference;

  /// Offloading point from the route/transaction — auto-fills the waybill
  /// DESTINATION (§4).
  final String? offloadingPoint;

  /// Loading point (the source mine) from the route/transaction — auto-fills
  /// the waybill ORIGIN (§4).
  final String? loadingPoint;
  final DateTime updatedAt;

  const MineTrip({
    required this.tripId,
    required this.status,
    this.vehicleId,
    this.truckReg,
    this.routeId,
    required this.sealRequired,
    this.expectedSeals = 4,
    this.netTons,
    this.tareTons,
    this.grossTons,
    this.loadingAt,
    required this.transactionId,
    this.buyerCompanyId,
    this.buyerName,
    this.transporterName,
    this.commodity,
    this.reference,
    this.offloadingPoint,
    this.loadingPoint,
    required this.updatedAt,
  });

  String get reg => truckReg ?? 'Trip ${tripId.substring(0, 6)}…';
  /// Who this load is for, or an honest statement that nobody is yet.
  ///
  /// This used to fall back to the bare word `Buyer`, which renders on the Load
  /// Controller's queue and wayslip as though it were a company of that name —
  /// "CLIENT: Buyer". A mine may legitimately book a haul before it has sold
  /// the load (`stockpiles.buyer_label = 'No buyer linked yet'`,
  /// 20260817180000), and that is worth saying rather than disguising.
  String get buyerLabel => buyerName ?? 'No buyer linked yet';
  String get materialLabel => commodity ?? 'Mineral';

  /// On the way / scheduled, not yet checked in by security.
  bool get isInbound =>
      status == TripStatus.scheduled || status == TripStatus.enRouteToLoad;

  /// Checked in by security, on-site, not yet loaded.
  bool get isOnSite =>
      status == TripStatus.arrivedAtMine || status == TripStatus.loading;

  bool get isLoaded => status.step >= TripStatus.loaded.step;

  /// The empty weigh is done and the truck is away loading — the sheet asks
  /// for the gross weight next.
  bool get isTareCaptured => tareTons != null;

  factory MineTrip.fromJson(Map<String, dynamic> j) {
    return MineTrip(
      tripId: j['trip_id'] as String,
      status: TripStatus.parse(j['status'] as String?),
      vehicleId: j['vehicle_id'] as String?,
      truckReg: j['truck_reg'] as String?,
      routeId: j['route_id'] as String?,
      sealRequired: (j['seal_required'] as bool?) ?? false,
      expectedSeals: (j['expected_seals'] as num?)?.toInt() ?? 4,
      netTons: (j['net_tons'] as num?)?.toDouble(),
      tareTons: (j['tare_tons'] as num?)?.toDouble(),
      grossTons: (j['gross_tons'] as num?)?.toDouble(),
      loadingAt: j['loading_at'] == null
          ? null
          : MlTime.sastOrNull(DateTime.tryParse(j['loading_at'] as String)),
      transactionId: j['transaction_id'] as String,
      buyerCompanyId: j['buyer_company_id'] as String?,
      buyerName: j['buyer_name'] as String?,
      transporterName: j['transporter_name'] as String?,
      commodity: j['commodity'] as String?,
      reference: j['reference'] as String?,
      offloadingPoint: j['offloading_point'] as String?,
      loadingPoint: j['loading_point'] as String?,
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }
}

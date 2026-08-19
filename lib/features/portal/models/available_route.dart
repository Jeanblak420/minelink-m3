/// A learned route the super-admin assigned to this org (CLAUDE.md §4
/// "Available routes"): selectable on the Requests screen to auto-fill the
/// Request Route form. Backed by `list_my_available_routes`.
class AvailableRoute {
  final String routeId;
  final String routeNumber;
  final String? commodity;
  final String? loadingPoint;
  final String? offloadingPoint;
  final String? paymentTerms;
  final bool operatingHours24h;
  final String? operatingStart;
  final String? operatingEnd;
  final String? tons;
  final String? numTrucks;
  final String? routeNotes;
  final bool permanent;
  final DateTime assignedAt;

  const AvailableRoute({
    required this.routeId,
    required this.routeNumber,
    required this.permanent,
    required this.assignedAt,
    this.commodity,
    this.loadingPoint,
    this.offloadingPoint,
    this.paymentTerms,
    this.operatingHours24h = false,
    this.operatingStart,
    this.operatingEnd,
    this.tons,
    this.numTrucks,
    this.routeNotes,
  });

  String get routeLabel => '${loadingPoint ?? '—'} → ${offloadingPoint ?? '—'}';

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory AvailableRoute.fromJson(Map<String, dynamic> j) => AvailableRoute(
    routeId: j['route_id'] as String,
    routeNumber: (j['route_number'] as String?) ?? '—',
    commodity: _s(j['commodity']),
    loadingPoint: _s(j['loading_point']),
    offloadingPoint: _s(j['offloading_point']),
    paymentTerms: _s(j['payment_terms']),
    operatingHours24h: (j['operating_hours_24h'] as bool?) ?? false,
    operatingStart: _s(j['operating_start']),
    operatingEnd: _s(j['operating_end']),
    tons: _s(j['tons']),
    numTrucks: _s(j['num_trucks']),
    routeNotes: _s(j['route_notes']),
    permanent: (j['permanent'] as bool?) ?? false,
    assignedAt: DateTime.parse(j['assigned_at'] as String),
  );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogisticsSnapshot {
  final List<HaulRouteRecord> routes;
  final List<TripRecord> trips;
  final List<VehiclePositionRecord> positions;
  final List<ReconciliationRecord> reconciliations;
  final List<OperationTransaction> waybills;

  const LogisticsSnapshot({
    required this.routes,
    required this.trips,
    required this.positions,
    required this.reconciliations,
    required this.waybills,
  });

  static const empty = LogisticsSnapshot(
    routes: [],
    trips: [],
    positions: [],
    reconciliations: [],
    waybills: [],
  );
}

class LogisticsService {
  final SupabaseClient _client = SupabaseConfig.client;
  static final _logger = LoggerFactory.getLogger('LogisticsService');

  Future<LogisticsSnapshot> loadForCompany(String companyId) async {
    try {
      final routesFuture = _client
          .from('haul_routes')
          .select()
          .or('supplier_company_id.eq.$companyId,buyer_company_id.eq.$companyId')
          .order('updated_at', ascending: false);

      final reconFuture = _client
          .from('reconciliations')
          .select()
          .or('buyer_company_id.eq.$companyId,supplier_company_id.eq.$companyId,transporter_company_id.eq.$companyId')
          .order('updated_at', ascending: false);

      // ALL of this company's transactions — fully paginated, no cap. Tonnage
      // totals must be genuine all-time figures, so a fixed limit would silently
      // undercount as volume grows.
      final waybillsFuture = _fetchAllTransactions(companyId);

      final results = await Future.wait<Object>([
        routesFuture,
        reconFuture,
        waybillsFuture,
      ]);

      final routes =
          (results[0] as List).map((e) => HaulRouteRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final recon =
          (results[1] as List).map((e) => ReconciliationRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final waybillsRaw = results[2] as List<OperationTransaction>;

      // EVERY trip belonging to this company's transactions — scoped by
      // transaction id (trips carry no company column) and fully paginated, so
      // no trip's Net Mass is ever dropped by a global row cap.
      final trips =
          await _fetchTripsForTransactions(waybillsRaw.map((w) => w.id).toList());

      // Authoritative outbound tonnage is the weighbridge Net Mass persisted on
      // trips.net_tons (Gross − Tare), NOT transactions.quantity (the ordered
      // amount, frequently 0). Fold each transaction's trips' net_tons onto the
      // waybill so the overview/tons-out metrics report real shipped tons.
      final waybills = _attachNetTons(waybillsRaw, trips);

      List<VehiclePositionRecord> positions = const [];
      try {
        // RLS restricts rows (fleet owner, buyer via trips, etc.), so we do NOT
        // filter by company here — a buyer must see the transporter's trucks
        // carrying their load, and that visibility is expressed in the policy,
        // not in this query.
        //
        // What we must not do is bound the read by a ROW COUNT. `limit(500)`
        // took the newest 500 samples PLATFORM-WIDE before deduping, so once
        // total ping volume crossed that line a company's trucks fell out of
        // the window entirely and "Truck locations" rendered an empty map while
        // those trucks were actively reporting. Ordering by recorded_at means
        // the busiest fleet on the platform crowds out everyone else first.
        //
        // Bound by TIME and page the window out in full instead. Deduping to
        // the latest sample per vehicle keeps one marker per truck, which is
        // what "truck locations" means.
        positions = await _fetchLatestVehiclePositions();
      } catch (_) {
        // GPS is best-effort: a positions failure must not blank the whole
        // snapshot (routes/trips/waybills still load). The truck-locations
        // screens show an honest "no GPS yet" state for an empty list.
        positions = const [];
      }

      return LogisticsSnapshot(
        routes: routes,
        trips: trips,
        positions: positions,
        reconciliations: recon,
        waybills: waybills,
      );
    } on PostgrestException catch (e, st) {
      // Surface the failure so each screen's `.when(error: ...)` branch fires
      // (retry / error UI) instead of silently rendering an empty snapshot that
      // is indistinguishable from a company that genuinely has no data.
      _logger.e('Failed to load logistics snapshot for $companyId', e, st);
      rethrow;
    }
  }

  /// Rows PostgREST returns per request before an explicit range is needed.
  /// Supabase caps a single response at `db-max-rows` (1000 by default); paging
  /// in blocks of this size lets us read an unbounded result set.
  static const _pageSize = 1000;

  /// Max transaction ids per `in.(...)` filter, to keep the request URL bounded
  /// no matter how many transactions a company has.
  static const _idChunk = 200;

  /// How far back a GPS sample can be and still count as a truck's current
  /// position. Bounds the positions read by TIME rather than by row count, so
  /// no company's trucks can be crowded out of the window by a busier fleet.
  /// Generous on purpose: a truck parked over a long weekend still shows.
  static const _positionWindow = Duration(days: 30);

  /// The latest GPS sample per vehicle, over [_positionWindow], read in full.
  ///
  /// Row visibility is RLS's job — this deliberately does not filter by
  /// company, because a buyer is entitled to see the transporter's trucks on
  /// their load and the policy already expresses that.
  Future<List<VehiclePositionRecord>> _fetchLatestVehiclePositions() async {
    final since = DateTime.now().toUtc().subtract(_positionWindow);
    final seen = <String>{};
    final out = <VehiclePositionRecord>[];
    var from = 0;
    while (true) {
      final rows = await _client
          .from('vehicle_positions')
          .select()
          .gte('recorded_at', since.toIso8601String())
          .order('recorded_at', ascending: false)
          // `recorded_at` is not unique — a fleet pinging on a 30 s cadence
          // produces same-instant samples routinely, and `.range()` paging over
          // a non-unique sort has no defined order within a tie, so a row can
          // be repeated on one page and skipped on the next. `id` breaks the
          // tie and makes the sequence total. The dedup below still needs
          // recorded_at to lead, or "first sighting per vehicle" would stop
          // meaning "latest sample".
          .order('id', ascending: false)
          .range(from, from + _pageSize - 1);
      final list = rows as List;
      for (final e in list) {
        final record =
            VehiclePositionRecord.fromJson(Map<String, dynamic>.from(e as Map));
        // Rows arrive newest-first, so the first sighting of a vehicle is its
        // latest sample.
        if (seen.add(record.vehicleId)) out.add(record);
      }
      if (list.length < _pageSize) break;
      from += _pageSize;
    }
    return out;
  }

  /// Every transaction where the company is supplier, buyer, or transporter —
  /// read page by page until the source is exhausted. No cap.
  Future<List<OperationTransaction>> _fetchAllTransactions(
      String companyId) async {
    final out = <OperationTransaction>[];
    var from = 0;
    while (true) {
      final rows = await _client
          .from('transactions')
          .select()
          .or(
            'supplier_company_id.eq.$companyId,buyer_company_id.eq.$companyId,transporter_company_id.eq.$companyId',
          )
          .order('updated_at', ascending: false)
          .range(from, from + _pageSize - 1);
      final list = rows as List;
      out.addAll(list.map(
          (e) => OperationTransaction.fromJson(Map<String, dynamic>.from(e as Map))));
      if (list.length < _pageSize) break;
      from += _pageSize;
    }
    return out;
  }

  /// Every trip for the given transaction ids — chunked by id (bounded URL) and
  /// paged within each chunk (bounded response). No cap: a transaction with many
  /// loads and a company with many transactions are both read in full.
  Future<List<TripRecord>> _fetchTripsForTransactions(
      List<String> transactionIds) async {
    if (transactionIds.isEmpty) return const [];
    final out = <TripRecord>[];
    for (var i = 0; i < transactionIds.length; i += _idChunk) {
      final chunk = transactionIds.sublist(
          i, math.min(i + _idChunk, transactionIds.length));
      var from = 0;
      while (true) {
        final rows = await _client
            .from('trips')
            .select()
            .inFilter('transaction_id', chunk)
            .order('updated_at', ascending: false)
            .range(from, from + _pageSize - 1);
        final list = rows as List;
        out.addAll(list
            .map((e) => TripRecord.fromJson(Map<String, dynamic>.from(e as Map))));
        if (list.length < _pageSize) break;
        from += _pageSize;
      }
    }
    return out;
  }

  /// Folds each transaction's trips' weighbridge Net Mass (`trips.net_tons`)
  /// onto the waybill as [OperationTransaction.netTonsOut] — the authoritative
  /// shipped tonnage the tons-out metrics aggregate.
  List<OperationTransaction> _attachNetTons(
    List<OperationTransaction> waybills,
    List<TripRecord> trips,
  ) {
    final netByTxn = <String, double>{};
    for (final t in trips) {
      final n = t.netTons;
      if (n == null) continue;
      netByTxn[t.transactionId] = (netByTxn[t.transactionId] ?? 0) + n;
    }
    return [
      for (final w in waybills) w.copyWith(netTonsOut: netByTxn[w.id] ?? 0),
    ];
  }

  /// Edit a waybill's editable fields (§7.4) — Destination, Product, Order no.
  /// Persists onto the transaction's metadata (buyer manager only, per RLS).
  Future<void> updateWaybill(
    String transactionId,
    Map<String, dynamic> currentMetadata, {
    String? destination,
    String? product,
    String? orderNo,
  }) async {
    final merged = {
      ...currentMetadata,
      if (destination != null) 'offloading_point': destination,
      if (product != null) 'commodity': product,
      if (orderNo != null) 'order_no': orderNo,
    };
    await _client
        .from('transactions')
        .update({'metadata': merged}).eq('id', transactionId);
  }

  /// Every company this one has actually transacted with, filtered to one org
  /// type.
  ///
  /// Reads the transaction set in full. The previous `.limit(200)` silently
  /// dropped partners once a company passed 200 transactions — which meant the
  /// buyer's "Linked mines & suppliers", the mine's "Buyers" list and the
  /// buyer-name resolution feeding the tons-out table all quietly went
  /// incomplete, with nothing on screen to say so. The two sibling readers in
  /// this class already page exhaustively for exactly this reason.
  Future<List<CompanyPin>> listPartnerCompanies(String companyId, {required String orgFilter}) async {
    try {
      final ids = <String>{};
      var from = 0;
      while (true) {
        final rows = await _client
            .from('transactions')
            .select('supplier_company_id,buyer_company_id,transporter_company_id')
            .or(
              'supplier_company_id.eq.$companyId,buyer_company_id.eq.$companyId,transporter_company_id.eq.$companyId',
            )
            // Ordered by the primary key, not by `updated_at`: paging with
            // `.range()` over a non-unique sort can skip a row across a page
            // boundary, and a skipped row here is a partner company silently
            // missing from the buyer's linked mines or the mine's buyers —
            // exactly the class of quiet undercount the `.limit(200)` removal
            // was fixing. Nothing downstream cares about the order; the ids go
            // straight into a Set.
            .order('id', ascending: false)
            .range(from, from + _pageSize - 1);
        final list = rows as List;
        for (final row in list) {
          final m = Map<String, dynamic>.from(row as Map);
          for (final key in ['supplier_company_id', 'buyer_company_id', 'transporter_company_id']) {
            final v = m[key] as String?;
            if (v != null && v != companyId) ids.add(v);
          }
        }
        if (list.length < _pageSize) break;
        from += _pageSize;
      }

      if (ids.isEmpty) return const [];

      final companies =
          await _client.from('companies').select('id,company_name,org_type').inFilter('id', ids.toList());

      return (companies as List)
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return CompanyPin(
              id: m['id'] as String,
              name: m['company_name'] as String,
              orgType: m['org_type'] as String?,
            );
          })
          // companies.org_type is stored lowercase ('buyer'/'transporter'/
          // 'mineSupplier'); compare case-insensitively so callers passing
          // 'Buyer' still match.
          .where((c) =>
              orgFilter.isEmpty ||
              (c.orgType ?? '').toLowerCase() == orgFilter.toLowerCase())
          .toList();
    } on PostgrestException catch (e, st) {
      // Do not swallow. Returning [] here made an RLS denial or a network
      // failure indistinguishable from "this company has no partners", so the
      // screen rendered a confident, wrong empty state. Rethrow so the
      // caller's `.when(error: ...)` branch shows an error with a retry —
      // the same contract loadForCompany already honours.
      _logger.e('Failed to list partner companies for $companyId', e, st);
      rethrow;
    }
  }

  /// Ticks whenever a trip or transaction moves, so a screen reading
  /// [loadForCompany] can re-read instead of showing a figure from whenever it
  /// happened to mount.
  ///
  /// ## Why this exists
  ///
  /// `loadForCompany` is a SNAPSHOT, and the trip lifecycle is the one place
  /// in this product where the thing on your screen is moved by SOMEBODY ELSE.
  /// Driven end to end against production on 2026-08-22, on a real handset:
  ///
  /// | 04:33 | security marked the truck LEFT SITE — server went to `en_route_to_offload` |
  /// | 04:37 | the driver's Trip screen still read **EN ROUTE TO LOAD** |
  ///
  /// Four minutes, across a tab switch and a pull gesture. And it is not
  /// cosmetic: the driver's lifecycle buttons are gated on that status, so
  /// `Arrived at offloading` stayed dimmed and **the driver could not complete
  /// the load without killing the app.** The screen invalidates itself after
  /// the driver's OWN actions (that is why the earlier steps looked fine) and
  /// had nothing at all for anybody else's.
  ///
  /// The mine floor is the whole flow: security checks in, the load controller
  /// weighs, security checks out — three changes by three other people that the
  /// driver has to see.
  ///
  /// Shape copied from `LiveTrackingService.watchLivePositions`, which had
  /// already met each of these: a **debounce**, because a single
  /// `record_truck_load` writes the trip and its transaction together and that
  /// must be one re-read; a **periodic fallback**, because realtime is a
  /// best-effort transport and a dropped socket must not leave a driver stuck
  /// the way this fault did; and an **immediate first tick**, so the snapshot
  /// resolves on the first frame rather than after a round trip.
  ///
  /// Filtering is left to RLS. A postgres_changes filter can only test one
  /// column, and a trip is reachable through its vehicle's company OR its
  /// transaction's parties — so the honest choice is to listen for the table
  /// and let the re-read (which is party-scoped already) decide.
  Stream<int> watchLifecycle(String companyId) {
    RealtimeChannel? channel;
    Timer? debounce;
    Timer? fallback;
    var tick = 0;
    late final StreamController<int> controller;

    void bump() {
      if (controller.isClosed) return;
      controller.add(++tick);
    }

    void scheduleBump() {
      debounce ??= Timer(const Duration(milliseconds: 700), () {
        debounce = null;
        bump();
      });
    }

    controller = StreamController<int>(
      onListen: () {
        // Emit before subscribing so the FutureProvider that watches this
        // resolves immediately instead of waiting on the socket.
        bump();
        channel = _client
            .channel('logistics-lifecycle-$companyId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'trips',
              callback: (_) => scheduleBump(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'transactions',
              callback: (_) => scheduleBump(),
            )
            .subscribe();
        fallback = Timer.periodic(const Duration(seconds: 60), (_) => bump());
      },
      onCancel: () {
        debounce?.cancel();
        fallback?.cancel();
        final ch = channel;
        if (ch != null) _client.removeChannel(ch);
        controller.close();
      },
    );
    return controller.stream;
  }
}

class CompanyPin {
  final String id;
  final String name;
  final String? orgType;

  const CompanyPin({required this.id, required this.name, this.orgType});
}

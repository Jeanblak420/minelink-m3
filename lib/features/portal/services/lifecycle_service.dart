import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_doc.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_transaction.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/stockpile_ledger_provider.dart'
    show StockpileLedgerState;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// A captured seal: number + optional photo URL.
class SealCapture {
  final String number;
  final String? photoUrl;
  const SealCapture({required this.number, this.photoUrl});

  Map<String, dynamic> toJson() => {'number': number, 'photo_url': photoUrl};
}

/// Thin client over the Phase 2 cascade RPCs and the persistent stockpile
/// tables. All trip transitions and load/POD events go through here so the
/// server-side cascades (stockpile deduction, recon, status) stay authoritative.
class LifecycleService {
  final SupabaseClient _client = SupabaseConfig.client;
  static final _log = LoggerFactory.getLogger('LifecycleService');

  // ---- Trip lifecycle -------------------------------------------------------

  /// Advance a trip to [status] (gate/driver steps). Returns the new status.
  Future<TripStatus> setTripStatus(String tripId, TripStatus status) async {
    final res = await _client.rpc('set_trip_status', params: {
      'p_trip_id': tripId,
      'p_status': status.wire,
    });
    return _statusFromRpc(res, fallback: status);
  }

  /// The driver reporting "I am at the offload point".
  ///
  /// Bookkeeping only — it stamps `trips.metadata.arrived_at_offload_at` and
  /// notifies the buyer, and deliberately does NOT move `TripStatus`. The
  /// button behind this used to call `setTripStatus(offloaded)`, which claims
  /// the load is already off the truck; on the driver screen it was enabled
  /// from `loaded`, so a driver could report a delivery offloaded before the
  /// mine had even checked the truck out of its gate. `record_pod` remains the
  /// only thing that closes a delivery, because it is the only thing that
  /// captures the delivered tonnage and the mandatory photo with it.
  ///
  /// Idempotent: arriving twice is one arrival.
  Future<void> markArrivedAtOffload(String tripId) async {
    await _client.rpc('mark_trip_arrived_at_offload', params: {
      'p_trip_id': tripId,
    });
  }

  /// Mine-gate check-out: the truck is loaded, weighed and leaving.
  ///
  /// **One call, one transaction.** This replaced two sequential
  /// `setTripStatus` calls — `leftMine` then `enRouteToOffload` — and the gap
  /// between them was the defect (S6-9, S6-24). If the second failed, the trip
  /// stopped at `left_mine`: the truck is gone from the gate so nobody at the
  /// mine is watching it, and it never entered `en_route_to_offload` so nobody
  /// at the offload is expecting it. The guard could not tell, because from
  /// their side the button had worked.
  ///
  /// A security guard at a mine gate is exactly the user
  /// `friendly_error.dart` describes — *"Network first: it is by far the most
  /// common real cause on a haul road"* — so the two-call window was not
  /// theoretical.
  ///
  /// Idempotent: calling it on a trip already `en_route_to_offload` returns
  /// that trip rather than raising, so a retry after a dropped response is
  /// safe.
  Future<TripStatus> securityCheckOut(String tripId) async {
    final res = await _client.rpc('security_check_out', params: {
      'p_trip_id': tripId,
    });
    return _statusFromRpc(res, fallback: TripStatus.enRouteToOffload);
  }

  /// FIRST weigh: the empty truck, on arrival, before it goes to load.
  ///
  /// Moves the trip `arrived_at_mine -> loading` and stamps `loading_at`, so
  /// the two weighs are separately timed and separately evidenced. Jean asked
  /// for the recorded sequence to be the real one (2026-08-17): both weights
  /// used to be typed on one sheet at one moment, which cannot show that two
  /// weighs happened. Re-weighing is allowed until the load is recorded.
  Future<void> recordTruckTare({
    required String tripId,
    required double tareTons,
    String? tarePhotoPath,
  }) async {
    await _client.rpc('record_truck_tare', params: {
      'p_trip_id': tripId,
      'p_tare_tons': tareTons,
      'p_tare_photo_path': tarePhotoPath,
    });
  }

  /// SECOND weigh: truck plus cargo, after loading. Fires the load cascade and
  /// enforces seals server-side when the route requires them.
  ///
  /// Takes the GROSS weight — the net is derived on the server from the tare it
  /// already holds, so the subtraction lives with the two readings rather than
  /// arriving as a number this client worked out.
  Future<void> recordTruckLoad({
    required String tripId,
    required double grossTons,
    String? truckReg,
    List<SealCapture> seals = const [],
    Map<String, dynamic> waybill = const {},
  }) async {
    await _client.rpc('record_truck_load', params: {
      'p_trip_id': tripId,
      'p_gross_tons': grossTons,
      'p_truck_reg': truckReg,
      'p_seals': [for (final s in seals) s.toJson()],
      'p_waybill': waybill,
    });
  }

  /// Uploads the driver's POD photo to the private `pod_photos` bucket under
  /// the driver's company folder and returns the object path to store as
  /// `pod_uploads.photo_url` (same path convention as `request_docs`).
  Future<String> uploadPodPhoto({
    required String companyId,
    required String name,
    required Uint8List bytes,
  }) =>
      _uploadImage('pod_photos', companyId, name, bytes);

  /// Uploads a weighbridge scale / seal photo to the private `load_photos`
  /// bucket under the mine's company folder; returns the object path.
  Future<String> uploadLoadPhoto({
    required String companyId,
    required String name,
    required Uint8List bytes,
  }) =>
      _uploadImage('load_photos', companyId, name, bytes);

  Future<String> _uploadImage(
    String bucket,
    String companyId,
    String name,
    Uint8List bytes,
  ) async {
    final safeName = (name.isEmpty ? 'photo.jpg' : name)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$companyId/${const Uuid().v4()}_$safeName';
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.') + 1).toLowerCase()
        : 'jpg';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: switch (ext) {
              'png' => 'image/png',
              'webp' => 'image/webp',
              'heic' || 'heif' => 'image/heic',
              _ => 'image/jpeg',
            },
          ),
        );
    return path;
  }

  /// Best-effort delete of uploaded object paths from [bucket] — used to clean
  /// up photos that were uploaded just before a record RPC that then failed, so
  /// a failed save doesn't leave orphaned files behind.
  Future<void> deletePhotos(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove(paths);
    } catch (_) {
      // Cleanup is best-effort; never surface a delete failure to the user.
    }
  }

  /// Full waybill data for a trip (both dispatch and received blocks) via the
  /// `get_trip_waybill` RPC — used to regenerate the signed copy at offload.
  /// Returns null if the trip is not visible or has no waybill yet.
  Future<Map<String, dynamic>?> getTripWaybill(String tripId) async {
    final res = await _client
        .rpc('get_trip_waybill', params: {'p_trip_id': tripId});
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    return null;
  }

  /// Record proof of delivery (Driver). Finalises the trip + recon cascade.
  ///
  /// [photoUrl] is **required and non-nullable** (S3-9). It was `String?`,
  /// which let a caller record a delivery with no evidence behind it and find
  /// out only when Postgres refused — and `pod_photos` had never held a single
  /// file, so nothing had ever tested that path. The photo is the only thing
  /// standing between "the load arrived" and somebody's word for it.
  ///
  /// The emptiness check is at runtime because Dart cannot express "non-empty
  /// String" in a type, and an empty string was exactly the hole: it satisfies
  /// `String` and travels all the way to the database before anything objects.
  /// `record_pod` still refuses it server-side — this just fails closer to the
  /// mistake, with a message aimed at a developer rather than a driver.
  Future<void> recordPod({
    required String tripId,
    required double deliveredTons,
    required String photoUrl,
  }) async {
    if (photoUrl.trim().isEmpty) {
      throw ArgumentError.value(
        photoUrl,
        'photoUrl',
        'A proof-of-delivery photo path is required. Upload the offload photo '
            'first and pass the stored path.',
      );
    }
    await _client.rpc('record_pod', params: {
      'p_trip_id': tripId,
      'p_delivered_tons': deliveredTons,
      'p_photo_url': photoUrl,
    });
  }

  /// Trips inbound to a mine (the mine is the supplier party) for the Security
  /// check-in and Load Controller screens.
  Future<List<MineTrip>> listInboundTrips(String supplierCompanyId) async {
    final rows = await _client.rpc('list_mine_inbound_trips', params: {
      'p_supplier_company_id': supplierCompanyId,
    });
    return (rows as List)
        .map((e) => MineTrip.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ---- Persistent stockpiles ------------------------------------------------

  /// Stockpiles for a supplier (mine), newest balances. Buyer display name uses
  /// [StockpileEntry.buyer] (the stored label).
  Future<List<StockpileEntry>> listStockpiles(String supplierCompanyId) async {
    final rows = await _client
        .from('stockpiles')
        .select()
        .eq('supplier_company_id', supplierCompanyId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((e) => _stockpileFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Supervisor allocates a new stockpile to a buyer. Writes the stockpile and
  /// its allocation ledger entry. Returns the new stockpile id.
  Future<String> createStockpile({
    required String supplierCompanyId,
    String? buyerCompanyId,
    String? buyerLabel,
    required String name,
    required double tons,
    String? mineral,
    String? grade,
  }) async {
    final inserted = await _client
        .from('stockpiles')
        .insert({
          'supplier_company_id': supplierCompanyId,
          'buyer_company_id': buyerCompanyId,
          'buyer_label': buyerLabel,
          'name': name,
          'mineral': mineral,
          'grade': grade,
          'balance_tons': tons,
        })
        .select()
        .single();
    final id = inserted['id'] as String;
    await _client.from('stockpile_transactions').insert({
      'stockpile_id': id,
      'type': 'allocation',
      'delta_tons': tons,
      'balance_after': tons,
    });
    return id;
  }

  /// Full ledger (stockpiles + append-only transactions) for the audit trail.
  Future<StockpileLedgerState> loadLedger(String supplierCompanyId) async {
    final stockpiles = await listStockpiles(supplierCompanyId);
    final rows = await _client
        .from('stockpile_transactions')
        .select('*, stockpiles!inner(name, buyer_label, supplier_company_id)')
        .eq('stockpiles.supplier_company_id', supplierCompanyId)
        .order('at', ascending: false);
    final txns = (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final sp = Map<String, dynamic>.from(m['stockpiles'] as Map);
      return StockpileTransaction(
        stockpileId: m['stockpile_id'] as String,
        stockpileName: (sp['name'] as String?) ?? '',
        buyer: (sp['buyer_label'] as String?) ?? '',
        type: _txnType(m['type'] as String?),
        delta: ((m['delta_tons'] as num?) ?? 0).toDouble(),
        balanceAfter: ((m['balance_after'] as num?) ?? 0).toDouble(),
        truckReg: m['truck_reg'] as String?,
        at: DateTime.parse(m['at'] as String),
      );
    }).toList();
    return StockpileLedgerState(stockpiles: stockpiles, transactions: txns);
  }

  StockpileTxnType _txnType(String? raw) {
    switch (raw) {
      case 'addition':
        return StockpileTxnType.addition;
      case 'deduction':
        return StockpileTxnType.deduction;
      default:
        return StockpileTxnType.allocation;
    }
  }

  /// Documents (lab-result PDFs / pictures) attached to a stockpile, newest
  /// first. Party-scoped by RLS.
  Future<List<StockpileDoc>> listStockpileDocs(String stockpileId) async {
    final rows = await _client
        .from('stockpile_docs')
        .select()
        .eq('stockpile_id', stockpileId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => StockpileDoc.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Uploads stockpile documents of [kind] ('lab_result' | 'picture') for
  /// [stockpileId]. Files are stored in the private `request_docs` bucket under
  /// the supplier company's folder (`<supplierCompanyId>/stockpiles/<id>/…`) so
  /// the existing company-scoped storage RLS applies; a `stockpile_docs`
  /// metadata row is written per file. Returns the created docs.
  Future<List<StockpileDoc>> uploadStockpileDocs({
    required String supplierCompanyId,
    required String stockpileId,
    required String kind,
    required List<({String name, Uint8List bytes})> files,
  }) async {
    final storage =
        _client.storage.from(StorageAssetService.requestDocsBucket);
    final created = <StockpileDoc>[];
    for (final f in files) {
      final safeName = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$supplierCompanyId/stockpiles/$stockpileId/'
          '${const Uuid().v4()}_$safeName';
      await storage.uploadBinary(
        path,
        f.bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: _docContentType(safeName),
        ),
      );
      final row = await _client
          .from('stockpile_docs')
          .insert({
            'stockpile_id': stockpileId,
            'kind': kind,
            'storage_path': path,
            'file_name': f.name,
            'uploaded_by': _client.auth.currentUser?.id,
          })
          .select()
          .single();
      created.add(StockpileDoc.fromJson(Map<String, dynamic>.from(row)));
    }
    return created;
  }

  static String _docContentType(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  /// Supervisor adds tonnage to an order-linked stockpile. Goes through the
  /// `stockpile_add_tons` RPC which enforces the order's max cap, writes the
  /// balance + ledger row atomically, and fires the +30t "ready to collect"
  /// alerts to the buyer and transporter. Returns the new balance.
  ///
  /// Throws a [PostgrestException] whose message is safe to show the user when
  /// the addition would exceed the order cap.
  Future<double> addTons(String stockpileId, double tons) async {
    if (tons <= 0) return 0;
    final res = await _client.rpc('stockpile_add_tons', params: {
      'p_stockpile_id': stockpileId,
      'p_tons': tons,
    });
    return (res as num?)?.toDouble() ?? 0;
  }

  TripStatus _statusFromRpc(dynamic res, {required TripStatus fallback}) {
    try {
      if (res is Map && res['status'] is String) {
        return TripStatus.parse(res['status'] as String);
      }
      if (res is List && res.isNotEmpty && res.first is Map) {
        final m = res.first as Map;
        if (m['status'] is String) return TripStatus.parse(m['status'] as String);
      }
    } catch (e) {
      _log.w('could not parse trip status from RPC result, using fallback '
          '${fallback.wire}. ${friendlyError(e)}');
    }
    return fallback;
  }

  StockpileEntry _stockpileFromJson(Map<String, dynamic> m) {
    final label = (m['buyer_label'] as String?)?.trim();
    return StockpileEntry(
      id: m['id'] as String,
      name: m['name'] as String,
      buyer: (label == null || label.isEmpty) ? null : label,
      buyerCompanyId: m['buyer_company_id'] as String?,
      tons: ((m['balance_tons'] as num?) ?? 0).toDouble(),
      mineral: m['mineral'] as String?,
      grade: m['grade'] as String?,
      maxCapTons: (m['max_cap_tons'] as num?)?.toDouble(),
      requestId: m['request_id'] as String?,
      kind: (m['kind'] as String?) ?? 'order',
    );
  }
}

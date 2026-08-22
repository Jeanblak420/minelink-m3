import 'dart:typed_data';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/portal/models/available_route.dart';
import 'package:flutter_application_1/features/portal/models/request_tracking.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// The editable payload for a transportation request (shared by create + edit).
class RequestDraft {
  final String requestType;
  final String? paymentTerms;
  final String? diesel;
  final bool operatingHours24h;
  final String? operatingStart;
  final String? operatingEnd;
  final DateTime? startingDate;

  /// Single-request end date (CLAUDE.md §4 Request 1). Ongoing requests have
  /// a start date only — the end date is dropped when [isOngoing].
  final DateTime? endingDate;
  final bool isOngoing;
  final String? loadingPoint;
  final String? offloadingPoint;
  final String? commodity;
  final String? distance;
  final String? rate;
  final String? tonsAvailable;
  final String? contractDuration;
  final String? numSlots;
  final String? routeNotes;

  // Product / buyer request fields (§4).
  final double? pricePerTon;
  final String? transactionKind; // 'FOB' | 'FOT'
  final String? productSpecifications;

  /// Attachment object paths in the private `request_docs` bucket, uploaded
  /// before the row insert (see [RequestService.uploadRequestDocs]).
  final List<String> labResultPaths;
  final String? productImagePath;

  /// Every load on this route must carry sealed numbers and seal photos.
  ///
  /// Carried into `routes.seal_required` by `link_and_dispatch_request`, which
  /// is what the Load Controller's capture rule and `record_truck_load`'s
  /// server-side enforcement read. Until 2026-08-17 that column had no writer
  /// anywhere in the product, so the whole seal path was unreachable
  /// (migration `20260817170000`).
  final bool sealRequired;

  const RequestDraft({
    this.requestType = 'transportation',
    this.paymentTerms,
    this.diesel,
    this.operatingHours24h = false,
    this.operatingStart,
    this.operatingEnd,
    this.startingDate,
    this.endingDate,
    this.isOngoing = false,
    this.loadingPoint,
    this.offloadingPoint,
    this.commodity,
    this.distance,
    this.rate,
    this.tonsAvailable,
    this.contractDuration,
    this.numSlots,
    this.routeNotes,
    this.pricePerTon,
    this.transactionKind,
    this.productSpecifications,
    this.labResultPaths = const [],
    this.productImagePath,
    this.sealRequired = false,
  });

  Map<String, dynamic> toColumns() => {
        'request_type': requestType,
        'payment_terms': paymentTerms,
        'diesel': diesel,
        'operating_hours_24h': operatingHours24h,
        'operating_start': operatingHours24h ? null : operatingStart,
        'operating_end': operatingHours24h ? null : operatingEnd,
        // Ongoing and single requests BOTH carry a start date; only single
        // requests carry an end date (§4 Request 1 dropdown).
        'starting_date': startingDate?.toIso8601String().split('T').first,
        'ending_date':
            isOngoing ? null : endingDate?.toIso8601String().split('T').first,
        'is_ongoing': isOngoing,
        'loading_point': loadingPoint,
        'offloading_point': offloadingPoint,
        'commodity': commodity,
        'distance': distance,
        'rate': rate,
        'tons_available': tonsAvailable,
        'contract_duration': contractDuration,
        'num_slots': numSlots,
        'route_notes': routeNotes,
        'price_per_ton': pricePerTon,
        'transaction_kind': transactionKind,
        'product_specifications': productSpecifications,
        'lab_result_paths': labResultPaths,
        'product_image_path': productImagePath,
        'seal_required': sealRequired,
      };
}

/// CRUD + review/dispatch over transportation_requests (§7.5, §8).
class RequestService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Uploads request attachments (lab-result PDFs / product picture) to the
  /// private `request_docs` bucket under the requesting company's folder and
  /// returns the object paths to store on the request row. Called before
  /// [submit]/[resubmit]; storage RLS scopes the folder to company staff.
  Future<List<String>> uploadRequestDocs(
    String companyId,
    List<({String name, Uint8List bytes})> files,
  ) async {
    final storage =
        _client.storage.from(StorageAssetService.requestDocsBucket);
    final paths = <String>[];
    for (final f in files) {
      final safeName = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$companyId/${const Uuid().v4()}_$safeName';
      await storage.uploadBinary(
        path,
        f.bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: _requestDocContentType(safeName),
        ),
      );
      paths.add(path);
    }
    return paths;
  }

  static String _requestDocContentType(String fileName) {
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

  /// Requesting org submits a brand-new request (lifecycle entry: requested).
  Future<TransportationRequest> submit(
    String requesterCompanyId,
    RequestDraft draft,
  ) async {
    final row = await _client
        .from('transportation_requests')
        .insert({
          // Who asked. Its own column since 20260815118000 — this used to be
          // written into `buyer_company_id`, so a mine raising a request was
          // recorded as the BUYER of its own ore, and everything downstream
          // (routes.buyer_company_id, the order stockpile's buyer_label, the
          // "Order accepted & dispatched" notification) believed it.
          'requesting_company_id': requesterCompanyId,
          'created_by': _client.auth.currentUser?.id,
          'status': 'requested',
          ...draft.toColumns(),
        })
        .select()
        .single();
    return TransportationRequest.fromJson(Map<String, dynamic>.from(row));
  }

  /// Requester re-submits a sent-back request after editing
  /// (sent_back → resubmitted revision loop, CLAUDE.md §4).
  Future<TransportationRequest> resubmit(String id, RequestDraft draft) async {
    final row = await _client
        .from('transportation_requests')
        .update({'status': 'resubmitted', ...draft.toColumns()})
        .eq('id', id)
        .select()
        .single();
    return TransportationRequest.fromJson(Map<String, dynamic>.from(row));
  }

  /// Trucks the transporter allocated to fulfil a request — one per trip
  /// created at accept. Party-scoped server-side (§4 buyer visibility).
  Future<List<AllocatedTruck>> listAllocatedTrucks(String requestId) async {
    final rows = await _client.rpc(
      'list_request_allocated_trucks',
      params: {'p_request_id': requestId},
    );
    return (rows as List)
        .map((e) => AllocatedTruck.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// All requests one company has raised, whatever its org type (newest first).
  ///
  /// `buyer_company_id` is the **requester** column — see
  /// `companyRequestsProvider` for why that name has already cost one false
  /// release blocker. A mine filtering on it is reading its own requests
  /// correctly, not accidentally filtering itself out.
  ///
  /// Requests where this company is the *linked supplier* are a different
  /// query and deliberately not here: that row carries `price_per_ton`, `rate`
  /// and `admin_notes`, so the mine reads its linked orders through
  /// `list_request_tracking` (which returns facts, not the row) rather than
  /// through a widened RLS policy that would hand it the buyer's price and the
  /// admin's margin notes.
  Future<List<TransportationRequest>> listForRequester(
    String requesterCompanyId,
  ) async {
    final rows = await _client
        .from('transportation_requests')
        .select()
        .eq('requesting_company_id', requesterCompanyId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => TransportationRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Platform-admin review queue for a request type (newest first). Embeds
  /// the requesting company's org type so the transportation inbox can split
  /// into Mine/Supplier vs Buyer requests (§4).
  ///
  /// Returns EVERY request of that type, in every state — the inbox needs the
  /// closed ones to show history. Callers wanting the queue length must filter
  /// to [RequestStatus.awaitingReview] themselves, or use
  /// [countAwaitingReview]. Two dashboards did not, and reported every request
  /// ever raised — approved, linked and declined included — as "Pending
  /// requests" (P9-02).
  Future<List<TransportationRequest>> listForAdmin({
    String requestType = 'transportation',
  }) async {
    // Join through `requesting_company_id`, NOT `buyer_company_id`.
    //
    // The buyer FK is only ever filled when the requester is itself a buyer
    // (trigger `set_buyer_from_requester`). Joining through it meant every
    // mine/supplier-raised request came back with `requester_company = null`,
    // so `isFromMine` was false for all of them and they ALL fell into the
    // buyer bucket — `#/super-admin/requests/transportation-mine` read "0 new"
    // and could never receive anything, while the mine's request sat in the
    // buyer inbox with no "From <company>" line at all. Found 2026-08-17 by
    // raising a real request as Iron Hills Mining and looking at both inboxes.
    final rows = await _client
        .from('transportation_requests')
        .select('*, requester_company:companies!requesting_company_id('
            'id, company_name, org_type, whatsapp_number, ceo_first_name, '
            'ceo_last_name, support_contact_email, status, created_at)')
        .eq('request_type', requestType)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => TransportationRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// How many requests of [requestType] are genuinely **awaiting the platform
  /// admin** — `requested` or `resubmitted`, nothing else (P9-02).
  ///
  /// Named for what it counts. `listForAdmin(...).length` is not that number
  /// and reading it as one is what put every request ever raised behind a
  /// "Pending requests" label on two dashboards.
  Future<int> countAwaitingReview({String requestType = 'transportation'}) async {
    final rows = await listForAdmin(requestType: requestType);
    return rows.where((r) => r.status.awaitingReview).length;
  }

  /// Representative review action: sent_back | approved | declined.
  Future<void> review(String id, String action, {String? notes}) async {
    await _client.rpc('review_transportation_request', params: {
      'p_id': id,
      'p_action': action,
      'p_notes': notes,
    });
  }

  /// Link + dispatch in one atomic step (§4 pricing/margin gate): set the mine,
  /// record the admin's margin in the super-admin-only ledger, stamp the
  /// transporter's resulting price (agreed − margin) on each dispatch, and mark
  /// the request `linked`. The transporter only ever sees their resulting price.
  Future<void> linkAndDispatch(
    String id,
    String supplierCompanyId,
    double agreedPricePerTon,
    double adminMarginPerTon,
    List<String> transporterIds,
  ) async {
    await _client.rpc('link_and_dispatch_request', params: {
      'p_id': id,
      'p_supplier_company_id': supplierCompanyId,
      'p_agreed_price': agreedPricePerTon,
      'p_admin_margin': adminMarginPerTon,
      'p_transporter_ids': transporterIds,
    });
  }

  /// Every request the company is part of (requester / mine / transporter),
  /// tracked through completion. Null company = platform-wide (admin).
  Future<List<RequestTrackingRow>> listRequestTracking(
    String? companyId,
  ) async {
    final rows = await _client.rpc(
      'list_request_tracking',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => RequestTrackingRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Routes the super-admin assigned to this org — selectable to auto-fill
  /// the Request Route form (§4 "Available routes").
  Future<List<AvailableRoute>> listMyAvailableRoutes(String companyId) async {
    final rows = await _client.rpc(
      'list_my_available_routes',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => AvailableRoute.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Buyer + mineSupplier companies (for the admin's route-assignment picker).
  Future<List<({String id, String name, String orgType})>>
      listRequesterCompanies() async {
    final rows = await _client
        .from('companies')
        .select('id, company_name, org_type')
        .inFilter('org_type', ['buyer', 'mineSupplier'])
        .order('company_name', ascending: true);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      return (
        id: m['id'] as String,
        name: (m['company_name'] as String?) ?? '—',
        orgType: (m['org_type'] as String?) ?? '—',
      );
    }).toList();
  }

  /// All mineSupplier companies (for the representative's supplier picker).
  Future<List<({String id, String name})>> listMines() async {
    final rows = await _client
        .from('companies')
        .select('id, company_name, org_type')
        .eq('org_type', 'mineSupplier')
        .order('company_name', ascending: true);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      return (id: m['id'] as String, name: (m['company_name'] as String?) ?? '—');
    }).toList();
  }

  /// Transporter companies a request was actually dispatched to, as stored.
  ///
  /// The admin console's linked-request panel used to render the *local*
  /// selection state, which is cleared every time a row is opened — so a
  /// request that had been linked months ago still read "Mine: None selected /
  /// Transporter(s):" with the real answer sitting in the database. This reads
  /// the record instead. `request_dispatches_select` already admits
  /// `is_platform_admin()`, so no new grant is needed.
  Future<Set<String>> listDispatchedTransporterIds(String requestId) async {
    final rows = await _client
        .from('request_dispatches')
        .select('transporter_company_id')
        .eq('request_id', requestId);
    return (rows as List)
        .map((e) =>
            Map<String, dynamic>.from(e)['transporter_company_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  // ---- Transporter side (§5) -----------------------------------------------

  /// The columns of `transportation_requests` a TRANSPORTER may receive.
  ///
  /// Named one by one rather than `*`, because three of that table's columns
  /// are the requester's and the platform admin's alone:
  ///
  /// * `rate` — the figure the BUYER (or mine) typed on the request. The admin
  ///   sets the transporter's own price separately at linking, as
  ///   `request_dispatches.transporter_price_per_ton`. Ship both to the same
  ///   screen and the admin's margin is one subtraction: this route was
  ///   dispatched at R820.00/ton against a request whose `rate` said 950, and
  ///   the route sheet printed the two four rows apart. CLAUDE.md §4 — *"the
  ///   transporter only ever sees their resulting price, never the admin's
  ///   margin"* — and the admin's own due-diligence preview promises it in
  ///   those words.
  /// * `price_per_ton` — the product price on a Request Product. Same reason.
  /// * `admin_notes` — what the platform admin wrote back to the REQUESTER
  ///   when sending a request for revision. Addressed to them, not to a
  ///   haulier who was not in that conversation.
  ///
  /// A column added to the table is therefore absent here until somebody
  /// decides the transporter should have it. `dispatched_route_hides_requester_pricing_test.dart`
  /// asserts that every field the transporter's own surfaces read still
  /// arrives, so dropping one by accident fails rather than renders blank.
  static const _transporterRequestColumns =
      'id, requesting_company_id, buyer_company_id, supplier_company_id, '
      'request_type, status, payment_terms, diesel, operating_hours_24h, '
      'operating_start, operating_end, starting_date, ending_date, is_ongoing, '
      'loading_point, offloading_point, commodity, distance, tons_available, '
      'contract_duration, num_slots, route_notes, transaction_kind, '
      'product_specifications, seal_required, created_at, updated_at';

  /// Routes dispatched to a transporter (open marketplace + accepted), newest
  /// first. RLS lets a transporter read its own dispatches and — via the
  /// additive policy — the embedded request detail.
  ///
  /// That policy is wider than this screen needs: measured against production
  /// on 2026-08-22, a transporter's own JWT can select `rate` off the buyer's
  /// request row. The embedded select below is narrowed so the app neither
  /// fetches nor can draw it; tightening the policy itself belongs to the
  /// shipping app, since `supabase/` is frozen in this fork.
  Future<List<DispatchedRoute>> listTransporterDispatches(
    String transporterCompanyId,
  ) async {
    final rows = await _client
        .from('request_dispatches')
        .select(
          '*, transportation_requests!inner($_transporterRequestColumns), '
          // `seal_required` off the ROUTE, not the request: the mine
          // floor enforces the route's flag and the two can disagree.
          // See `DispatchedRoute.sealRequired`.
          'routes(route_number, seal_required)',
        )
        .eq('transporter_company_id', transporterCompanyId)
        .order('dispatched_at', ascending: false);
    return (rows as List)
        .map((e) => DispatchedRoute.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Transporter accepts a dispatched route on the chosen trucks (§5.3). The
  /// RPC creates one transaction + trip per truck and marks the dispatch
  /// accepted.
  Future<void> acceptDispatch(String dispatchId, List<String> vehicleIds) async {
    await _client.rpc('accept_request_dispatch', params: {
      'p_dispatch_id': dispatchId,
      'p_vehicle_ids': vehicleIds,
    });
  }

  /// Transporter declines a dispatched route.
  Future<void> declineDispatch(String dispatchId) async {
    await _client.rpc('decline_request_dispatch', params: {
      'p_dispatch_id': dispatchId,
    });
  }

  /// All transporter companies (for the admin's "send to transporter" picker).
  /// Visible to the platform admin via companies RLS. Returns (id, name) pairs.
  /// Buyer companies for the representative's buying-company picker.
  ///
  /// A "Requested buyers" enquiry is a mine asking to be introduced to buyers,
  /// and until 2026-08-17 there was no buyer picker anywhere in the console —
  /// approving one opened the transport dispatch flow with nothing to name.
  Future<List<({String id, String name})>> listBuyers() async {
    final rows = await _client
        .from('companies')
        .select('id, company_name, org_type')
        .eq('org_type', 'buyer')
        .order('company_name', ascending: true);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      return (id: m['id'] as String, name: (m['company_name'] as String?) ?? '—');
    }).toList();
  }

  /// Fill in the parties and route terms an enquiry does not carry, before
  /// linking. Platform admin only; enforced in `prepare_request_for_linking`.
  ///
  /// Every argument is optional and only a non-null one writes — the admin is
  /// filling blanks on a form, not resubmitting the whole row.
  Future<void> prepareForLinking(
    String id, {
    String? buyerCompanyId,
    String? loadingPoint,
    String? offloadingPoint,
    String? tons,
    String? numTrucks,
  }) async {
    await _client.rpc('prepare_request_for_linking', params: {
      'p_id': id,
      'p_buyer_company_id': buyerCompanyId,
      'p_loading_point': loadingPoint,
      'p_offloading_point': offloadingPoint,
      'p_tons': tons,
      'p_num_trucks': numTrucks,
    });
  }

  Future<List<({String id, String name})>> listTransporters() async {
    // companies.org_type stores 'transporter' (lowercase) — the previous
    // 'Transporter' filter matched nothing, leaving the dispatch picker empty.
    final rows = await _client
        .from('companies')
        .select('id, company_name, org_type')
        .eq('org_type', 'transporter')
        .order('company_name', ascending: true);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      return (id: m['id'] as String, name: (m['company_name'] as String?) ?? '—');
    }).toList();
  }
}

import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// Status of a request through the super-admin review lifecycle (CLAUDE.md §4):
/// `requested → sent_back → resubmitted → approved → linked`, plus the
/// terminal `declined`. The `sent_back ⇄ resubmitted` pair is the revision
/// loop and may repeat. Wire values match `transportation_requests.status`;
/// [parse] is tolerant of the legacy wires
/// (submitted/under_review/accepted/dispatched) still present in old rows.
enum RequestStatus {
  requested,
  sentBack,
  resubmitted,
  approved,
  linked,
  declined;

  String get wire {
    switch (this) {
      case RequestStatus.requested:
        return 'requested';
      case RequestStatus.sentBack:
        return 'sent_back';
      case RequestStatus.resubmitted:
        return 'resubmitted';
      case RequestStatus.approved:
        return 'approved';
      case RequestStatus.linked:
        return 'linked';
      case RequestStatus.declined:
        return 'declined';
    }
  }

  String get label {
    switch (this) {
      case RequestStatus.requested:
        return 'Requested';
      case RequestStatus.sentBack:
        return 'Sent back';
      case RequestStatus.resubmitted:
        return 'Resubmitted';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.linked:
        return 'Linked';
      case RequestStatus.declined:
        return 'Declined';
    }
  }

  /// Requester may edit + resubmit only when the request was sent back.
  bool get buyerCanEdit => this == RequestStatus.sentBack;

  /// Sitting in the admin inbox awaiting a first or renewed review.
  bool get awaitingReview =>
      this == RequestStatus.requested || this == RequestStatus.resubmitted;

  /// Legacy wire values written before the canonical lifecycle migration.
  static const _legacy = <String, RequestStatus>{
    'submitted': RequestStatus.requested,
    'under_review': RequestStatus.requested,
    'accepted': RequestStatus.approved,
    'dispatched': RequestStatus.linked,
  };

  static RequestStatus parse(String? raw) {
    return RequestStatus.values.firstWhere(
      (s) => s.wire == raw,
      orElse: () => _legacy[raw] ?? RequestStatus.requested,
    );
  }
}

/// Controlled option lists (exact values from the spec — §7.5).
abstract final class RequestOptions {
  static const paymentTerms = [
    '50/50',
    'Daily',
    '7 days',
    '14 days',
    '30 days',
    '60 days',
  ];
  static const diesel = ['On account', 'On transporter'];
}

/// A buyer transportation request (also backs the product/buyer request queues).
class TransportationRequest {
  final String id;

  /// The company that RAISED the request — a buyer or a mine/supplier.
  /// Every RLS policy keys off this (migration `20260815118000`).
  final String requestingCompanyId;

  /// Who receives the product, when that is known.
  ///
  /// **Null for a mine having its own product moved** — to a washplant, on
  /// somebody else's behalf, or product it is itself buying elsewhere. It used
  /// to be NOT NULL and doubled as the requester column, so a mine's own
  /// request recorded the mine as the buyer of its own ore, and every
  /// downstream consumer (`routes.buyer_company_id`, the order stockpile's
  /// `buyer_label`, the dispatch notification) believed it.
  final String? buyerCompanyId;
  final String requestType; // transportation | product | buyer
  final RequestStatus status;

  // Controlled inputs.
  final String? paymentTerms;
  final String? diesel;
  final bool operatingHours24h;
  final String? operatingStart; // 'HH:MM'
  final String? operatingEnd; // 'HH:MM'
  final DateTime? startingDate;

  /// Single-request end date; null for ongoing requests (§4 Request 1).
  final DateTime? endingDate;
  final bool isOngoing;

  // Free-text.
  final String? loadingPoint;
  final String? offloadingPoint;
  final String? commodity;
  final String? distance;
  final String? rate;
  final String? tonsAvailable;
  final String? contractDuration;
  final String? numSlots;
  final String? routeNotes;

  final double? pricePerTon;
  final String? transactionKind; // 'FOB' | 'FOT'
  final String? productSpecifications;

  /// Attachments (private `request_docs` bucket object paths): lab-result
  /// PDFs (multi) + one optional product picture. Resolve to signed URLs via
  /// StorageAssetService.resolveRequestDocUrl.
  final List<String> labResultPaths;
  final String? productImagePath;

  final String? adminNotes;
  final String? supplierCompanyId; // mine the representative selected (§8.4)

  /// Requester declared that every load on this route must be sealed. Carried
  /// into `routes.seal_required` at linking, which is what the Load
  /// Controller's capture rule and `record_truck_load` enforce against.
  final bool sealRequired;

  /// Requesting company's org type ('mineSupplier' | 'buyer' | …) when the
  /// query embeds it (admin queue) — splits the transportation inbox into
  /// Mine/Supplier vs Buyer requests (§4 Request 1).
  final String? requesterOrgType;

  /// Full requester company profile when embedded (admin queue): who
  /// made/sent the request, clickable through to their company profile.
  final RequestCompanyInfo? requesterCompany;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransportationRequest({
    required this.id,
    required this.requestingCompanyId,
    this.buyerCompanyId,
    required this.requestType,
    required this.status,
    this.supplierCompanyId,
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
    this.adminNotes,
    this.sealRequired = false,
    this.requesterOrgType,
    this.requesterCompany,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFromMine => requesterOrgType == 'mineSupplier';

  /// Convenience display route string ("Loading → Offloading").
  String get routeLabel => '${loadingPoint ?? '—'} → ${offloadingPoint ?? '—'}';

  factory TransportationRequest.fromJson(Map<String, dynamic> j) {
    DateTime? date(String? v) => v == null ? null : DateTime.tryParse(v);
    return TransportationRequest(
      id: j['id'] as String,
      requestingCompanyId: (j['requesting_company_id'] ??
          j['buyer_company_id']) as String,
      buyerCompanyId: j['buyer_company_id'] as String?,
      requestType: (j['request_type'] as String?) ?? 'transportation',
      status: RequestStatus.parse(j['status'] as String?),
      paymentTerms: j['payment_terms'] as String?,
      diesel: j['diesel'] as String?,
      operatingHours24h: (j['operating_hours_24h'] as bool?) ?? false,
      operatingStart: j['operating_start'] as String?,
      operatingEnd: j['operating_end'] as String?,
      startingDate: date(j['starting_date'] as String?),
      endingDate: date(j['ending_date'] as String?),
      isOngoing: (j['is_ongoing'] as bool?) ?? false,
      loadingPoint: j['loading_point'] as String?,
      offloadingPoint: j['offloading_point'] as String?,
      commodity: j['commodity'] as String?,
      distance: j['distance'] as String?,
      rate: j['rate'] as String?,
      tonsAvailable: j['tons_available'] as String?,
      contractDuration: j['contract_duration'] as String?,
      numSlots: j['num_slots'] as String?,
      routeNotes: j['route_notes'] as String?,
      pricePerTon: (j['price_per_ton'] as num?)?.toDouble(),
      transactionKind: j['transaction_kind'] as String?,
      productSpecifications: j['product_specifications'] as String?,
      labResultPaths: (j['lab_result_paths'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      productImagePath: j['product_image_path'] as String?,
      adminNotes: j['admin_notes'] as String?,
      sealRequired: (j['seal_required'] as bool?) ?? false,
      supplierCompanyId: j['supplier_company_id'] as String?,
      requesterOrgType: j['requester_company'] is Map
          ? (j['requester_company'] as Map)['org_type'] as String?
          : null,
      requesterCompany: j['requester_company'] is Map
          ? RequestCompanyInfo.fromJson(
              Map<String, dynamic>.from(j['requester_company'] as Map))
          : null,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }
}

/// The requesting company's profile as embedded on an admin-queue request
/// (§ requester visibility): every request carries who submitted it, and the
/// name opens the full company profile.
class RequestCompanyInfo {
  final String id;
  final String name;
  final String? orgType;
  final String? whatsappNumber;
  final String? ceoFirstName;
  final String? ceoLastName;
  final String? supportEmail;
  final String? status;
  final DateTime? memberSince;

  const RequestCompanyInfo({
    required this.id,
    required this.name,
    this.orgType,
    this.whatsappNumber,
    this.ceoFirstName,
    this.ceoLastName,
    this.supportEmail,
    this.status,
    this.memberSince,
  });

  String get ceoName {
    final n = [ceoFirstName, ceoLastName].whereType<String>().join(' ').trim();
    return n.isEmpty ? '—' : n;
  }

  /// `OrgType.labelFor` — the one spelling. This carried its own switch
  /// returning "Mine / Supplier" beside screens saying "Mine/Supplier"
  /// (2026-08-23, the fourth such site).
  String get orgTypeLabel => OrgType.labelFor(orgType);

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory RequestCompanyInfo.fromJson(Map<String, dynamic> j) =>
      RequestCompanyInfo(
        id: j['id'] as String,
        name: (j['company_name'] as String?) ?? '—',
        orgType: _s(j['org_type']),
        whatsappNumber: _s(j['whatsapp_number']),
        ceoFirstName: _s(j['ceo_first_name']),
        ceoLastName: _s(j['ceo_last_name']),
        supportEmail: _s(j['support_contact_email']),
        status: _s(j['status']),
        memberSince: j['created_at'] == null
            ? null
            : DateTime.tryParse(j['created_at'] as String),
      );
}

/// A truck a transporter allocated to fulfil a request (one per trip created
/// at accept), visible to the linked buyer/mine (§4). Backed by
/// `list_request_allocated_trucks`.
class AllocatedTruck {
  final String tripId;
  final String? truckReg;
  final String? transporterName;
  final String? drivers;
  final String? tripStatus;
  final DateTime createdAt;

  const AllocatedTruck({
    required this.tripId,
    required this.createdAt,
    this.truckReg,
    this.transporterName,
    this.drivers,
    this.tripStatus,
  });

  factory AllocatedTruck.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return AllocatedTruck(
      tripId: j['trip_id'] as String,
      truckReg: s(j['truck_reg']),
      transporterName: s(j['transporter_name']),
      drivers: s(j['drivers']),
      tripStatus: s(j['trip_status']),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

/// Status of a dispatch — a request the platform routed to a transporter (§5).
enum DispatchStatus {
  dispatched,
  accepted,
  declined;

  static DispatchStatus parse(String? raw) => DispatchStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => DispatchStatus.dispatched,
      );
}

/// A request dispatched to a transporter, with its embedded request detail.
/// Backs the transporter "Available routes" marketplace and accepted routes.
class DispatchedRoute {
  final String dispatchId;
  final String transporterCompanyId;
  final DispatchStatus status;
  final DateTime dispatchedAt;

  /// The transporter's price per ton (agreed − admin margin), set by the admin
  /// at linking. The transporter sees this; never the admin's margin. In ZAR.
  final double? transporterPricePerTon;

  /// The standalone Route ID minted at linking (CLAUDE.md §4) — the entity
  /// holding everything the transporter receives except the admin's pricing.
  final String? routeId;
  final String? routeNumber;

  /// `routes.seal_required` — the flag the MINE FLOOR enforces.
  ///
  /// Null only when the dispatch has no route row yet.
  final bool? routeSealRequired;
  final TransportationRequest request;

  const DispatchedRoute({
    required this.dispatchId,
    required this.transporterCompanyId,
    required this.status,
    required this.dispatchedAt,
    required this.request,
    this.transporterPricePerTon,
    this.routeId,
    this.routeNumber,
    this.routeSealRequired,
  });

  bool get isOpen => status == DispatchStatus.dispatched;
  bool get isAccepted => status == DispatchStatus.accepted;

  /// Whether this load needs seals — **the route's answer, not the request's**.
  ///
  /// The two are separate columns and they diverge in practice, because the
  /// platform admin sets the route's condition at linking while the request
  /// carries whatever the requester ticked. Measured on production,
  /// 2026-08-23, route `56a1209a` (RT-DDC02437):
  ///
  ///     transportation_requests.seal_required   false
  ///     routes.seal_required                    true
  ///
  /// `record_truck_load` reads the ROUTE, so the mine floor demanded four
  /// numbered and photographed seals — while the sheet the transporter had
  /// accepted from, reading the REQUEST, said "Seals — Not required". The
  /// admin had even written "Seals required on this route" into the notes.
  ///
  /// A transporter that believes the sheet sends a truck with no seals and
  /// their driver is refused at the weighbridge, 640 km from home. Whichever
  /// flag the load is judged by is the one the sheet has to show; the
  /// request's value is kept only as a fallback for a dispatch with no route
  /// row yet.
  bool get sealRequired => routeSealRequired ?? request.sealRequired;

  /// Columns of the embedded request that belong to the requester and the
  /// platform admin, and are dropped here before anything can render them.
  ///
  /// `listTransporterDispatches` already declines to fetch them, so on the
  /// live path this removes nothing. It is here because the leak it closes was
  /// invisible: the route sheet printed `Rate 950` four rows under `Your price
  /// / ton R 820.00`, which is the admin's margin stated twice over, on the
  /// one screen whose contract — this class's own doc, and the admin's
  /// due-diligence preview — is that the transporter never sees it. A `*`
  /// re-introduced upstream by somebody who does not know that would put it
  /// straight back. Here it cannot.
  static const _requesterOnlyColumns = ['rate', 'price_per_ton', 'admin_notes'];

  factory DispatchedRoute.fromJson(Map<String, dynamic> j) {
    final reqJson = Map<String, dynamic>.from(j['transportation_requests'] as Map);
    for (final column in _requesterOnlyColumns) {
      reqJson.remove(column);
    }
    final routeJson = j['routes'] is Map
        ? Map<String, dynamic>.from(j['routes'] as Map)
        : null;
    return DispatchedRoute(
      dispatchId: j['id'] as String,
      transporterCompanyId: j['transporter_company_id'] as String,
      status: DispatchStatus.parse(j['status'] as String?),
      dispatchedAt: DateTime.parse(j['dispatched_at'] as String),
      transporterPricePerTon: (j['transporter_price_per_ton'] as num?)?.toDouble(),
      routeId: j['route_id'] as String?,
      routeNumber: routeJson?['route_number'] as String?,
      routeSealRequired: routeJson?['seal_required'] as bool?,
      request: TransportationRequest.fromJson(reqJson),
    );
  }
}

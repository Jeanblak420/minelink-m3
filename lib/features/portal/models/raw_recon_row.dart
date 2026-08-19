import 'package:flutter_application_1/core/time/ml_time.dart';

/// One raw (Side A) reconciliation record — a trip exactly as captured, before
/// any reconciliation logic (CLAUDE.md §4 recon-table columns). Backed by
/// `list_raw_recon_rows`.
class RawReconRow {
  final String tripId;
  final DateTime tripDate;
  final DateTime? timeIn;
  final String? waybillNumber;
  final String? transporterName;
  final String? truckReg;
  final String? destination;
  final String? product;
  final String? sourceName;
  final String? customerName;
  final double? netMass;
  final double? deliveredTons;

  /// `net_mass - delivered_tons`, generated in Postgres (`trips.variance_tons`)
  /// rather than recomputed here — the same number Side B and the exports show.
  ///
  /// **Positive = mass that left the mine and did not arrive** (lost, stolen or
  /// swapped en route). `null` means the two weights are not comparable because
  /// one of them is missing, which is not a measured zero.
  final double? varianceTons;
  final DateTime? timeOut;
  final String? tripStatus;

  /// Object path of the driver's POD photo (private `pod_photos` bucket),
  /// when one was uploaded — openable by every party on the transaction.
  final String? podPhotoPath;

  const RawReconRow({
    required this.tripId,
    required this.tripDate,
    this.timeIn,
    this.waybillNumber,
    this.transporterName,
    this.truckReg,
    this.destination,
    this.product,
    this.sourceName,
    this.customerName,
    this.netMass,
    this.deliveredTons,
    this.varianceTons,
    this.timeOut,
    this.tripStatus,
    this.podPhotoPath,
  });

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Parsed onto the clock at the mine, deliberately.
  ///
  /// `list_raw_recon_rows` returns `trip_date` as a raw `timestamptz`
  /// (`coalesce(arrived_at, created_at)`) with no date truncation, so the day a
  /// load belongs to is decided entirely here. `DateTime.parse` on a `+00:00`
  /// string yields a **UTC** `DateTime`, whose `.year/.month/.day` are UTC
  /// fields — and the mine runs on SAST (UTC+2), with 24-hour operations.
  ///
  /// Leaving it UTC made the same rows group two different ways: the company
  /// recon table calls `.toLocal()` before formatting, while the super-admin
  /// mirror, dashboard and org-insights screens read `.day` / `.month` straight
  /// off the UTC value. Measured against live data, 3 of 42 trips fell on a
  /// different day depending on which screen you opened — and the mirror screen
  /// exists precisely to show what the company sees. Insights compounded it by
  /// comparing a UTC `tripDate.day` against `DateTime.now()`, which is local.
  ///
  /// Normalising here rather than at the 12 call sites means it cannot be
  /// forgotten at the next one. Sorting is untouched because the instant is
  /// preserved. This model is read-only — there is no `toJson` — so nothing is
  /// sent back to Postgres in the shifted form.
  ///
  /// 2026-08-17: this was `.toLocal()`, which is the device's opinion. A laptop
  /// left on UTC put a 22:30 SAST load on the previous day, and the fix for the
  /// original defect then only worked for people whose clock happened to be set
  /// correctly. [MlTime.sast] is the same answer for everybody, and it is the
  /// same day `ml_day()` now buckets on in Postgres.
  static DateTime? _dt(dynamic v) =>
      v == null ? null : MlTime.sastOrNull(DateTime.tryParse(v as String));

  factory RawReconRow.fromJson(Map<String, dynamic> j) => RawReconRow(
    tripId: j['trip_id'] as String,
    tripDate: MlTime.sast(DateTime.parse(j['trip_date'] as String)),
    timeIn: _dt(j['time_in']),
    waybillNumber: _s(j['waybill_number']),
    transporterName: _s(j['transporter_name']),
    truckReg: _s(j['truck_reg']),
    destination: _s(j['destination']),
    product: _s(j['product']),
    sourceName: _s(j['source_name']),
    customerName: _s(j['customer_name']),
    netMass: _d(j['net_mass']),
    deliveredTons: _d(j['delivered_tons']),
    varianceTons: _d(j['variance_tons']),
    timeOut: _dt(j['time_out']),
    tripStatus: _s(j['trip_status']),
    podPhotoPath: _s(j['pod_photo_path']),
  );
}

/// The two retained versions of an exported-then-edited reconciliation for one
/// (company, side): the ORIGINAL system snapshot (immutable) and the LATEST
/// edited upload (replaced on each new upload). CLAUDE.md §4 round-trip rule.
class ReconUploadPair {
  final String id;
  final String companyId;
  final String side; // 'A' | 'B'
  final String originalPath;
  final DateTime originalCreatedAt;
  final String? editedPath;
  final DateTime? editedUploadedAt;

  const ReconUploadPair({
    required this.id,
    required this.companyId,
    required this.side,
    required this.originalPath,
    required this.originalCreatedAt,
    this.editedPath,
    this.editedUploadedAt,
  });

  factory ReconUploadPair.fromJson(Map<String, dynamic> j) => ReconUploadPair(
    id: j['id'] as String,
    companyId: j['company_id'] as String,
    side: (j['side'] as String?) ?? 'A',
    originalPath: j['original_path'] as String,
    originalCreatedAt: DateTime.parse(j['original_created_at'] as String),
    editedPath: (j['edited_path'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['edited_path'] as String,
    editedUploadedAt: j['edited_uploaded_at'] == null
        ? null
        : DateTime.tryParse(j['edited_uploaded_at'] as String),
  );
}

import 'dart:typed_data';

/// Everything needed to render a Manual Waybill, mapped 1:1 to the fields in the
/// reference layout (see `waybill_reference.html` and the field-mapping table in
/// CLAUDE.md §4 "Weighbridge, Net Weight calculation & waybill").
///
/// The document is non-editable and print-ready — every value here is derived
/// from data the app already holds at the moment Net Weight is computed. The
/// received block (driver name/signature/time) is blank at dispatch and filled
/// on delivery.
class WaybillData {
  /// Header + SECTION — the Mine/Supplier (SOURCE) name. Dynamic, not a brand.
  final String sourceMine;

  /// NUMBER — the wayslip/waybill number entered by the Load Controller.
  final String waybillNumber;

  /// TRANSPORTER — transporter company name (from the trip / Route ID).
  final String transporter;

  /// FLEET/REGISTRATION NO. — the allocated truck's registration.
  final String fleetReg;

  /// DESTINATION — offloading point.
  final String destination;

  /// TRUCK SEAL SERIAL NO. 1–4 — seal numbers captured at loading (up to 4).
  final List<String> seals;

  /// PRODUCT — commodity.
  final String product;

  /// TONS — Net Weight (Gross − Tare), pre-formatted (e.g. "36.22").
  final String tons;

  /// DISPATCHED BY — the Load Controller generating/printing the waybill.
  final String dispatchedBy;

  /// Dispatch block DATE/TIME — generation timestamp.
  final DateTime dispatchedAt;

  /// RECEIVED BY — driver/receiver at offload (blank at dispatch).
  final String? receivedBy;

  /// Received block DATE/TIME — offload/receipt timestamp (blank at dispatch).
  final DateTime? receivedAt;

  /// Load Controller's transparent-PNG signature (dispatch block), if saved.
  final Uint8List? dispatchSignature;

  /// Driver's transparent-PNG signature (received block), if present.
  final Uint8List? receivedSignature;

  const WaybillData({
    required this.sourceMine,
    required this.waybillNumber,
    required this.transporter,
    required this.fleetReg,
    required this.destination,
    required this.seals,
    required this.product,
    required this.tons,
    required this.dispatchedBy,
    required this.dispatchedAt,
    this.receivedBy,
    this.receivedAt,
    this.dispatchSignature,
    this.receivedSignature,
  });

  /// Seal list padded/truncated to exactly four entries for the four ruled
  /// TRUCK SEAL SERIAL NO. lines.
  List<String> get fourSeals {
    final out = List<String>.filled(4, '');
    for (var i = 0; i < 4 && i < seals.length; i++) {
      out[i] = seals[i];
    }
    return out;
  }

  WaybillData copyWith({
    Uint8List? dispatchSignature,
    Uint8List? receivedSignature,
    String? receivedBy,
    DateTime? receivedAt,
  }) {
    return WaybillData(
      sourceMine: sourceMine,
      waybillNumber: waybillNumber,
      transporter: transporter,
      fleetReg: fleetReg,
      destination: destination,
      seals: seals,
      product: product,
      tons: tons,
      dispatchedBy: dispatchedBy,
      dispatchedAt: dispatchedAt,
      receivedBy: receivedBy ?? this.receivedBy,
      receivedAt: receivedAt ?? this.receivedAt,
      dispatchSignature: dispatchSignature ?? this.dispatchSignature,
      receivedSignature: receivedSignature ?? this.receivedSignature,
    );
  }
}

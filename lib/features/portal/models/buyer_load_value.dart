/// One delivered load's money picture for the buyer (backed by
/// `list_buyer_trip_values`): the agreed rate (R/ton the buyer agreed to pay —
/// the admin margin and the transporter's price are never returned), the
/// loaded / delivered / quality-adjusted payable Rand values, and the invoice
/// the buyer captured with its variance against the payable value.
class BuyerLoadValue {
  final String tripId;
  final String? reference;
  final String? truckReg;
  final String? commodity;
  final String? sourceName;
  final String? transporterName;
  final double? netTons;
  final double? deliveredTons;
  final double? ratePerTon;
  final String currency;
  final double? loadedValue;
  final double? deliveredValue;
  final double? payableTons;
  final double? gradeFactor;
  final double? payableValue;
  final String? invoiceId;
  final String? invoiceNumber;
  final double? invoicedTons;
  final double? invoicedAmount;
  final DateTime? invoiceDate;
  final double? invoiceVariance;
  final String? tripStatus;
  final DateTime updatedAt;

  const BuyerLoadValue({
    required this.tripId,
    required this.currency,
    required this.updatedAt,
    this.reference,
    this.truckReg,
    this.commodity,
    this.sourceName,
    this.transporterName,
    this.netTons,
    this.deliveredTons,
    this.ratePerTon,
    this.loadedValue,
    this.deliveredValue,
    this.payableTons,
    this.gradeFactor,
    this.payableValue,
    this.invoiceId,
    this.invoiceNumber,
    this.invoicedTons,
    this.invoicedAmount,
    this.invoiceDate,
    this.invoiceVariance,
    this.tripStatus,
  });

  bool get isPriced => ratePerTon != null;
  bool get hasInvoice => invoicedAmount != null;
  bool get isDelivered => deliveredTons != null;

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory BuyerLoadValue.fromJson(Map<String, dynamic> j) => BuyerLoadValue(
        tripId: j['trip_id'] as String,
        reference: _s(j['reference']),
        truckReg: _s(j['truck_reg']),
        commodity: _s(j['commodity']),
        sourceName: _s(j['source_name']),
        transporterName: _s(j['transporter_name']),
        netTons: _d(j['net_tons']),
        deliveredTons: _d(j['delivered_tons']),
        ratePerTon: _d(j['rate_per_ton']),
        currency: _s(j['currency']) ?? 'ZAR',
        loadedValue: _d(j['loaded_value']),
        deliveredValue: _d(j['delivered_value']),
        payableTons: _d(j['payable_tons']),
        gradeFactor: _d(j['grade_factor']),
        payableValue: _d(j['payable_value']),
        invoiceId: _s(j['invoice_id']),
        invoiceNumber: _s(j['invoice_number']),
        invoicedTons: _d(j['invoiced_tons']),
        invoicedAmount: _d(j['invoiced_amount']),
        invoiceDate: j['invoice_date'] == null
            ? null
            : DateTime.tryParse(j['invoice_date'] as String),
        invoiceVariance: _d(j['invoice_variance']),
        tripStatus: _s(j['trip_status']),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

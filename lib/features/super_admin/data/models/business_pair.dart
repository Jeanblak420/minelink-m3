/// A company pair implied by accepted business (request / dispatch / transaction),
/// with the date they were tied together and a human reason. Derived live — no
/// DB column stores this. `key` matches org_connections' low<high ordering so it
/// can be compared against existing connections.
class BusinessPair {
  final String companyIdA; // low
  final String companyIdB; // high
  final DateTime date;
  final String reason;

  const BusinessPair({
    required this.companyIdA,
    required this.companyIdB,
    required this.date,
    required this.reason,
  });

  String get key => '$companyIdA|$companyIdB';
}

DateTime _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String? _s(dynamic v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;

void _add(Map<String, BusinessPair> out, String? a, String? b, DateTime date,
    String reason) {
  if (a == null || b == null || a == b) return;
  final low = a.compareTo(b) < 0 ? a : b;
  final high = a.compareTo(b) < 0 ? b : a;
  final key = '$low|$high';
  final existing = out[key];
  if (existing == null || date.isAfter(existing.date)) {
    out[key] =
        BusinessPair(companyIdA: low, companyIdB: high, date: date, reason: reason);
  }
}

/// Pure derivation — most-recent source wins per pair.
List<BusinessPair> buildBusinessPairs(
  List<Map<String, dynamic>> requests,
  List<Map<String, dynamic>> dispatches,
  List<Map<String, dynamic>> transactions,
) {
  final out = <String, BusinessPair>{};

  for (final r in requests) {
    final status = _s(r['status']);
    // Canonical accepted request statuses are approved/linked
    // (RequestStatus lifecycle); accepted/dispatched kept for legacy rows.
    const acceptedStatuses = {'approved', 'linked', 'accepted', 'dispatched'};
    if (!acceptedStatuses.contains(status)) continue;
    final commodity = _s(r['commodity']) ?? 'product';
    final tons = _s(r['tons_available']) ?? _s(r['tons']);
    final reason = 'Accepted transport request — $commodity'
        '${tons != null ? ' ($tons t)' : ''}';
    _add(out, _s(r['buyer_company_id']), _s(r['supplier_company_id']),
        _parseDate(r['updated_at'] ?? r['created_at']), reason);
  }

  for (final d in dispatches) {
    final date = _parseDate(d['dispatched_at']);
    const reason = 'Route dispatch to transporter';
    _add(out, _s(d['transporter_company_id']), _s(d['request_buyer_company_id']),
        date, reason);
    _add(out, _s(d['transporter_company_id']),
        _s(d['request_supplier_company_id']), date, reason);
    _add(out, _s(d['request_buyer_company_id']),
        _s(d['request_supplier_company_id']), date, reason);
  }

  for (final t in transactions) {
    final date = _parseDate(t['created_at']);
    const reason = 'Active transaction between parties';
    final s = _s(t['supplier_company_id']);
    final b = _s(t['buyer_company_id']);
    final tr = _s(t['transporter_company_id']);
    _add(out, s, b, date, reason);
    _add(out, s, tr, date, reason);
    _add(out, b, tr, date, reason);
  }

  final list = out.values.toList()..sort((x, y) => y.date.compareTo(x.date));
  return list;
}

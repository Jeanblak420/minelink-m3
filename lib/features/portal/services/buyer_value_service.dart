import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';

/// Buyer money-layer data access: per-load Rand values (agreed rate × tons,
/// quality-adjusted payable) and the buyer's captured invoices, reconciled
/// server-side. The admin margin and transporter price are never returned.
class BuyerValueService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<BuyerLoadValue>> listTripValues(String companyId) async {
    final rows = await _client.rpc(
      'list_buyer_trip_values',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => BuyerLoadValue.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Record (or replace) the invoice the buyer received for one delivered
  /// load. RLS enforces the caller is the trip's buyer.
  Future<void> saveInvoice({
    required String tripId,
    required String buyerCompanyId,
    required String invoiceNumber,
    required double invoicedAmount,
    double? invoicedTons,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    await _client.from('load_invoices').upsert(
      {
        'trip_id': tripId,
        'buyer_company_id': buyerCompanyId,
        'invoice_number': invoiceNumber,
        'invoiced_amount': invoicedAmount,
        'invoiced_tons': invoicedTons,
        if (invoiceDate != null)
          'invoice_date': invoiceDate.toIso8601String().substring(0, 10),
        'notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'trip_id',
    );
  }

  /// Remove a captured invoice (buyer managers only, per RLS).
  Future<void> deleteInvoice(String invoiceId) async {
    await _client.from('load_invoices').delete().eq('id', invoiceId);
  }
}

final buyerValueServiceProvider =
    Provider<BuyerValueService>((ref) => BuyerValueService());

/// Per-load Rand values + invoice recon for a buyer, newest first.
final buyerTripValuesProvider =
    FutureProvider.family.autoDispose<List<BuyerLoadValue>, String>(
  (ref, companyId) =>
      ref.read(buyerValueServiceProvider).listTripValues(companyId),
);

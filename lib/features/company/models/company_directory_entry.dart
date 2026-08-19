import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// A company as it appears in a **picker** — its name, what kind of business it
/// is, and its logo. Nothing else.
///
/// ## Why this exists rather than reusing [Company] (P3-43)
///
/// Two screens need to list companies the signed-in user has no relationship
/// with: the onboarding employer picker (a pre-approval employee choosing where
/// they work) and the Operations Hub counterparty dropdowns. Both were reading
/// `from('companies').select()` — **every row, every column** — which is the
/// leak P3-43 closes: `seat_limit`, `seats_used`, `token_expires_at`,
/// `current_token_id`, `whatsapp_number`, `registration_number`, `vat_number`,
/// `physical_address`, CEO names and support email, readable by any driver or
/// security guard on the platform.
///
/// [Company] cannot be narrowed to fix this, because its constructor **requires**
/// `whatsappNumber` and `userId` — a contact number and the owner's auth id are
/// not optional in that model, so any query feeding it must return them. The
/// picker needs four fields; the model demands the commercial ones. Hence a
/// separate type: the columns a picker may see are a smaller set than the
/// columns a company profile is made of, and the type system should say so.
///
/// Fed by the `list_company_directory()` RPC, which is SECURITY DEFINER and
/// returns exactly these fields for every non-suspended company. That breadth is
/// deliberate and is not a hole: someone who has not yet been approved by any
/// employer must still be able to find their employer in a list. What they may
/// no longer see is anything commercial about it.
class CompanyDirectoryEntry {
  final String id;
  final String companyName;
  final OrgType orgType;
  final String? logoUrl;

  const CompanyDirectoryEntry({
    required this.id,
    required this.companyName,
    required this.orgType,
    this.logoUrl,
  });

  factory CompanyDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return CompanyDirectoryEntry(
      id: json['id'] as String,
      companyName: (json['company_name'] as String?) ?? '',
      // Tolerant parse, per the house rule for anything that crosses the wire:
      // an unrecognised org_type must not crash a picker.
      orgType: OrgType.values.firstWhere(
        (e) => e.name == json['org_type'],
        orElse: () => OrgType.mineSupplier,
      ),
      logoUrl: json['logo_url'] as String?,
    );
  }
}

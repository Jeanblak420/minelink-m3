import 'package:flutter_application_1/features/super_admin/data/models/organization_status.dart';

/// Builds and matches a lowercase search blob for super-admin organization list
/// filtering across company fields and related roster / fleet / token data.
class OrganizationSearch {
  OrganizationSearch._();

  static String digitsOnly(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  /// Precomputes a single lowercase blob used by [matches].
  static String buildSearchBlob({
    required Map<String, dynamic> org,
    Iterable<Map<String, dynamic>> employees = const [],
    Iterable<Map<String, dynamic>> fleetVehicles = const [],
    Iterable<Map<String, dynamic>> serialTokens = const [],
    Iterable<Map<String, dynamic>> organizationSeats = const [],
    Map<String, Map<String, dynamic>> employeeProfilesByUserId = const {},
  }) {
    final parts = <String>{};

    void add(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      parts.add(trimmed.toLowerCase());
      final digits = digitsOnly(trimmed);
      if (digits.length >= 4) parts.add(digits);
    }

    add(org['id'] as String?);
    add(org['company_name'] as String?);
    add(org['whatsapp_number'] as String?);
    add(org['ceo_first_name'] as String?);
    add(org['ceo_last_name'] as String?);
    add('${org['ceo_first_name'] ?? ''} ${org['ceo_last_name'] ?? ''}'.trim());

    final orgType = org['org_type'] as String?;
    add(orgType);
    add(_orgTypeSearchAliases(orgType));

    final status = OrganizationStatus.fromString(org['status'] as String?);
    add(status.name);
    add(status.displayName);

    final owner = org['owner_profile'];
    if (owner is Map) {
      final m = Map<String, dynamic>.from(owner);
      add(m['email'] as String?);
      add(m['display_name'] as String?);
      final email = (m['email'] as String?)?.trim();
      if (email != null && email.contains('@')) {
        add(email.split('@').first);
      }
    }

    for (final e in employees) {
      add(e['first_name'] as String?);
      add(e['last_name'] as String?);
      add('${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim());
      add(e['whatsapp_number'] as String?);
      add(e['role'] as String?);
      add(e['status'] as String?);
      add(e['id_number'] as String?);
      add(e['passport_or_workers_permit'] as String?);

      final uid = e['user_id'] as String?;
      if (uid != null) {
        final profile = employeeProfilesByUserId[uid];
        if (profile != null) {
          add(profile['email'] as String?);
          add(profile['display_name'] as String?);
        }
      }
    }

    for (final v in fleetVehicles) {
      add(v['vehicle_registration_number'] as String?);
      add(v['driver_first_name'] as String?);
      add(v['driver_last_name'] as String?);
      add('${v['driver_first_name'] ?? ''} ${v['driver_last_name'] ?? ''}'.trim());
      add(v['driver_id_number'] as String?);
      add(v['driver_passport_number'] as String?);
    }

    for (final t in serialTokens) {
      add(t['token_preview'] as String?);
      add(t['organization_name'] as String?);
    }

    for (final s in organizationSeats) {
      add(s['occupied_by_name'] as String?);
      add(s['occupied_by_email'] as String?);
      add(s['occupied_by_employee_role'] as String?);
    }

    return parts.join(' ');
  }

  /// Returns true when [query] matches any token in the org search blob.
  static bool matches(Map<String, dynamic> org, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final blob = org['_search_blob'] as String?;
    if (blob == null || blob.isEmpty) return false;
    if (blob.contains(q)) return true;

    final qDigits = digitsOnly(q);
    if (qDigits.length >= 3 && blob.contains(qDigits)) return true;

    return false;
  }

  static String? _orgTypeSearchAliases(String? orgType) {
    switch (orgType) {
      case 'mineSupplier':
        return 'mine supplier minesupplier';
      case 'buyer':
        return 'buyer';
      case 'transporter':
        return 'transporter';
      default:
        return null;
    }
  }
}

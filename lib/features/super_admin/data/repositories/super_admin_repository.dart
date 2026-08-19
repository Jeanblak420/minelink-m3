import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import '../models/models.dart';
import '../models/company_monthly_ops_stats.dart';
import '../../utils/organization_search.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Repository for all Super Admin platform operations
class SuperAdminRepository {
  final SupabaseClient _client;
  static final _log = LoggerFactory.getLogger('SuperAdminRepository');

  SuperAdminRepository(this._client);

  // ============ Dashboard Stats ============

  /// Get overview statistics for the super admin dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final companies = await _client.from('companies').select(
        'id, status, seat_limit, seats_used, token_expires_at, created_at');
    final employees = await _client.from('employees').select('id, created_at');
    final pendingRequests = await _client
        .from('token_requests')
        .select('id')
        .inFilter('status', ['pending', 'in_progress']);
    final allRequests =
        await _client.from('token_requests').select('id, created_at');

    final companyList = companies as List;
    final employeeList = employees as List;
    final requestList = allRequests as List;
    final totalCompanies = companyList.length;
    final activeCompanies = companyList.where((c) => c['status'] == 'active').length;
    final expiredCompanies = companyList.where((c) => c['status'] == 'expired').length;
    final suspendedCompanies = companyList.where((c) => c['status'] == 'suspended').length;

    // Tokens expiring within 7 days
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 7));
    final expiringSoon = companyList.where((c) {
      if (c['token_expires_at'] == null) return false;
      final expires = DateTime.parse(c['token_expires_at'] as String);
      return expires.isAfter(now) && expires.isBefore(soon);
    }).length;

    // ── 24h deltas (design's ▲N·24h badges), derived honestly from
    // created_at / token_expires_at. All comparisons in UTC. ──
    final nowUtc = DateTime.now().toUtc();
    final dayAgo = nowUtc.subtract(const Duration(hours: 24));
    bool createdIn24h(dynamic v) {
      if (v == null) return false;
      final t = DateTime.tryParse(v.toString());
      return t != null && t.toUtc().isAfter(dayAgo);
    }

    final newCompanies24h =
        companyList.where((c) => createdIn24h(c['created_at'])).length;
    final newUsers24h =
        employeeList.where((e) => createdIn24h(e['created_at'])).length;
    final newTokenRequests24h =
        requestList.where((r) => createdIn24h(r['created_at'])).length;
    // Companies whose token crossed into "expired" within the last 24h.
    final newExpired24h = companyList.where((c) {
      final v = c['token_expires_at'];
      if (v == null) return false;
      final t = DateTime.tryParse(v.toString())?.toUtc();
      return t != null && t.isBefore(nowUtc) && t.isAfter(dayAgo);
    }).length;

    // Platform-wide logistics totals (§8.1): active routes + tons managed.
    var activeRoutes = 0;
    var totalTonsManaged = 0.0;
    try {
      final logistics = await _client.rpc('platform_logistics_totals');
      if (logistics is List && logistics.isNotEmpty) {
        final row = Map<String, dynamic>.from(logistics.first as Map);
        activeRoutes = (row['active_routes'] as num?)?.toInt() ?? 0;
        totalTonsManaged =
            (row['total_tons_managed'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {
      // Tolerate absence of the RPC on older environments.
    }

    // Live extras: active users (last 5m) + tons in the last 24h. Tolerates the
    // migration not being applied yet (function absent → zeros).
    var activeUsersNow = 0;
    var tons24h = 0.0;
    try {
      final extras = await _client.rpc('platform_registry_extras');
      if (extras is List && extras.isNotEmpty) {
        final row = Map<String, dynamic>.from(extras.first as Map);
        activeUsersNow = (row['active_users_now'] as num?)?.toInt() ?? 0;
        tons24h = (row['tons_24h'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {
      // Tolerate absence of the RPC.
    }

    return {
      'totalCompanies': totalCompanies,
      'activeCompanies': activeCompanies,
      'expiredCompanies': expiredCompanies,
      'suspendedCompanies': suspendedCompanies,
      'totalUsers': employeeList.length,
      'openTokenRequests': (pendingRequests as List).length,
      'tokensExpiringSoon': expiringSoon,
      'activeRoutes': activeRoutes,
      'totalTonsManaged': totalTonsManaged,
      'newCompanies24h': newCompanies24h,
      'newUsers24h': newUsers24h,
      'newTokenRequests24h': newTokenRequests24h,
      'newExpired24h': newExpired24h,
      'activeUsersNow': activeUsersNow,
      'tons24h': tons24h,
    };
  }

  // ============ Organizations ============

  /// Get all organizations (with owner profile email/display_name for list UI).
  Future<List<Map<String, dynamic>>> getAllOrganizations() async {
    final response = await _client
        .from('companies')
        .select()
        .order('company_name');
    final list = List<Map<String, dynamic>>.from(
      (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final userIds = list
        .map((e) => e['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (userIds.isEmpty) return list;

    final profiles = await _client
        .from('profiles')
        .select('id, email, display_name')
        .inFilter('id', userIds);
    final byId = <String, Map<String, dynamic>>{};
    for (final p in profiles as List) {
      final m = Map<String, dynamic>.from(p as Map);
      final id = m['id'] as String?;
      if (id != null) byId[id] = m;
    }
    for (final row in list) {
      final uid = row['user_id'] as String?;
      if (uid != null) {
        final p = byId[uid];
        if (p != null) row['owner_profile'] = p;
      }
    }
    await _attachOrganizationSearchBlobs(list);
    return list;
  }

  /// Merges employees, fleet, tokens, seats, and profile emails into each org's
  /// `_search_blob` for cross-field filtering on the organizations screen.
  Future<void> _attachOrganizationSearchBlobs(
    List<Map<String, dynamic>> organizations,
  ) async {
    if (organizations.isEmpty) return;

    final employeesRaw = await _client.from('employees').select(
          'company_id, first_name, last_name, whatsapp_number, role, status, '
          'id_number, passport_or_workers_permit, user_id',
        );
    final employees = List<Map<String, dynamic>>.from(
      (employeesRaw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final employeeUserIds = employees
        .map((e) => e['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final employeeProfilesByUserId = <String, Map<String, dynamic>>{};
    if (employeeUserIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, email, display_name')
          .inFilter('id', employeeUserIds);
      for (final p in profiles as List) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = m['id'] as String?;
        if (id != null) employeeProfilesByUserId[id] = m;
      }
    }

    final employeesByCompany = <String, List<Map<String, dynamic>>>{};
    for (final e in employees) {
      final cid = e['company_id'] as String?;
      if (cid == null) continue;
      employeesByCompany.putIfAbsent(cid, () => []).add(e);
    }

    List<Map<String, dynamic>> fleetRows = [];
    try {
      final fleetRaw = await _client.from('fleet_vehicles').select(
            'company_id, vehicle_registration_number, driver_first_name, '
            'driver_last_name, driver_id_number, driver_passport_number',
          );
      fleetRows = List<Map<String, dynamic>>.from(
        (fleetRaw as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      // Fleet may be unavailable in some environments; search still works without it.
    }

    final fleetByCompany = <String, List<Map<String, dynamic>>>{};
    for (final v in fleetRows) {
      final cid = v['company_id'] as String?;
      if (cid == null) continue;
      fleetByCompany.putIfAbsent(cid, () => []).add(v);
    }

    List<Map<String, dynamic>> tokenRows = [];
    try {
      final tokensRaw = await _client
          .from('serial_tokens')
          .select('organization_id, token_preview, organization_name');
      tokenRows = List<Map<String, dynamic>>.from(
        (tokensRaw as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      _log.w('serial_tokens unavailable, continuing without token info: $e');
    }

    final tokensByOrg = <String, List<Map<String, dynamic>>>{};
    for (final t in tokenRows) {
      final oid = t['organization_id'] as String?;
      if (oid == null) continue;
      tokensByOrg.putIfAbsent(oid, () => []).add(t);
    }

    List<Map<String, dynamic>> seatRows = [];
    try {
      final seatsRaw = await _client.from('organization_seats').select(
            'organization_id, occupied_by_name, occupied_by_email, '
            'occupied_by_employee_role',
          );
      seatRows = List<Map<String, dynamic>>.from(
        (seatsRaw as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      _log.w('organization_seats unavailable, continuing without seat info: $e');
    }

    final seatsByOrg = <String, List<Map<String, dynamic>>>{};
    for (final s in seatRows) {
      final oid = s['organization_id'] as String?;
      if (oid == null) continue;
      seatsByOrg.putIfAbsent(oid, () => []).add(s);
    }

    for (final org in organizations) {
      final id = org['id'] as String?;
      if (id == null) continue;
      org['_search_blob'] = OrganizationSearch.buildSearchBlob(
        org: org,
        employees: employeesByCompany[id] ?? const [],
        fleetVehicles: fleetByCompany[id] ?? const [],
        serialTokens: tokensByOrg[id] ?? const [],
        organizationSeats: seatsByOrg[id] ?? const [],
        employeeProfilesByUserId: employeeProfilesByUserId,
      );
    }
  }

  /// Get organizations grouped by type
  Future<Map<String, List<Map<String, dynamic>>>> getOrganizationsGroupedByType() async {
    final orgs = await getAllOrganizations();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final org in orgs) {
      final type = org['org_type'] as String? ?? 'unknown';
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(org);
    }
    return grouped;
  }

  /// Watch organizations in real-time
  Stream<List<Map<String, dynamic>>> watchOrganizations() {
    return _client
        .from('companies')
        .stream(primaryKey: ['id'])
        .order('company_name');
  }

  /// Get a single organization by ID (includes linked owner profile: email + display_name).
  Future<Map<String, dynamic>?> getOrganizationById(String id) async {
    final response = await _client
        .from('companies')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    final map = Map<String, dynamic>.from(response);
    final uid = map['user_id'] as String?;
    if (uid != null) {
      final profile = await _client
          .from('profiles')
          .select('email, display_name')
          .eq('id', uid)
          .maybeSingle();
      if (profile != null) {
        map['owner_profile'] = profile;
      }
    }
    return map;
  }

  // ============ Users ============

  /// Roster across the **whole platform** — every `employees` row, with their
  /// owning company name (when present) and profile fields (email / display
  /// name / last_login_at) merged in for the dashboard "Total users" drilldown.
  ///
  /// Returned rows include the synthetic keys:
  /// * `company_name` — looked up from `companies.id == employees.company_id`
  /// * `org_type` — same lookup
  /// * `profiles` — `{ id, email, display_name, last_login_at }` map when found
  ///
  /// Done client-side over three small selects rather than via a server-side
  /// join so we don't depend on a new view / RPC; this trades one round trip
  /// for code locality with the rest of the super-admin queries above.
  Future<List<Map<String, dynamic>>> getAllPlatformUsers() async {
    final employees = await _client
        .from('employees')
        .select()
        .order('first_name', ascending: true)
        .order('last_name', ascending: true);

    final rows = List<Map<String, dynamic>>.from(
      (employees as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final companyIds = rows
        .map((e) => e['company_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final userIds = rows
        .map((e) => e['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final companiesById = <String, Map<String, dynamic>>{};
    if (companyIds.isNotEmpty) {
      final companies = await _client
          .from('companies')
          .select('id, company_name, org_type')
          .inFilter('id', companyIds);
      for (final c in companies as List) {
        final m = Map<String, dynamic>.from(c as Map);
        final id = m['id'] as String?;
        if (id != null) companiesById[id] = m;
      }
    }

    final profilesById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, email, display_name, last_login_at')
          .inFilter('id', userIds);
      for (final p in profiles as List) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = m['id'] as String?;
        if (id != null) profilesById[id] = m;
      }
    }

    for (final row in rows) {
      final cid = row['company_id'] as String?;
      if (cid != null) {
        final c = companiesById[cid];
        if (c != null) {
          row['company_name'] = c['company_name'];
          row['org_type'] = c['org_type'];
        }
      }
      final uid = row['user_id'] as String?;
      if (uid != null) {
        final p = profilesById[uid];
        if (p != null) row['profiles'] = p;
      }
    }

    return rows;
  }

  /// Same roster as company-side employee list: every `employees` row for the company,
  /// then profile fields merged when available (avoids losing rows vs embedded-only selects).
  Future<List<Map<String, dynamic>>> getCompanyUsers(String companyId) async {
    final employees = await _client
        .from('employees')
        .select()
        .eq('company_id', companyId)
        .order('first_name', ascending: true)
        .order('last_name', ascending: true);

    final rows = List<Map<String, dynamic>>.from(
      (employees as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final userIds = rows
        .map((e) => e['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (userIds.isEmpty) {
      return rows;
    }

    final profiles = await _client
        .from('profiles')
        .select('id, email, display_name, platform_role, last_login_at')
        .inFilter('id', userIds);

    final byId = <String, Map<String, dynamic>>{};
    for (final p in profiles as List) {
      final m = Map<String, dynamic>.from(p as Map);
      final id = m['id'] as String?;
      if (id != null) {
        byId[id] = m;
      }
    }

    for (final row in rows) {
      final uid = row['user_id'] as String?;
      if (uid != null) {
        final p = byId[uid];
        if (p != null) {
          row['profiles'] = p;
        }
      }
    }

    return rows;
  }

  static const _roleGroupOrder = [
    'management',
    'admin',
    'controllerWB',
    'security',
    'driver',
  ];

  /// Get users grouped by employee role (sorted groups and names, aligned with company roster).
  Future<Map<String, List<Map<String, dynamic>>>> getUsersGroupedByRole(String companyId) async {
    final users = await getCompanyUsers(companyId);
    int byName(Map<String, dynamic> a, Map<String, dynamic> b) {
      final an = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim().toLowerCase();
      final bn = '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'.trim().toLowerCase();
      return an.compareTo(bn);
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final user in users) {
      final role = user['role'] as String? ?? 'unknown';
      grouped.putIfAbsent(role, () => []);
      grouped[role]!.add(user);
    }
    for (final list in grouped.values) {
      list.sort(byName);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = _roleGroupOrder.indexOf(a);
        final bi = _roleGroupOrder.indexOf(b);
        if (ai == -1 && bi == -1) {
          return a.compareTo(b);
        }
        if (ai == -1) {
          return 1;
        }
        if (bi == -1) {
          return -1;
        }
        return ai.compareTo(bi);
      });

    return {for (final k in keys) k: grouped[k]!};
  }

  // ============ Serial Tokens ============

  /// Generate a new serial token for an organization
  Future<Map<String, dynamic>> generateSerialToken({
    required String organizationId,
    required int validDays,
    required int seatLimit,
  }) async {
    final response = await _client.rpc('create_serial_token', params: {
      'p_organization_id': organizationId,
      'p_valid_days': validDays,
      'p_seat_limit': seatLimit,
    });
    return response as Map<String, dynamic>;
  }

  /// Revoke a serial token
  Future<Map<String, dynamic>> revokeSerialToken({
    required String tokenId,
    String reason = 'Revoked by admin',
  }) async {
    final response = await _client.rpc('revoke_serial_token', params: {
      'p_token_id': tokenId,
      'p_reason': reason,
    });
    return response as Map<String, dynamic>;
  }

  /// Get all tokens for an organization
  Future<List<SerialToken>> getOrganizationTokens(String organizationId) async {
    final response = await _client
        .from('serial_tokens')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => SerialToken.fromJson(e)).toList();
  }

  /// Get the current active token for an organization
  Future<SerialToken?> getActiveToken(String organizationId) async {
    final response = await _client
        .from('serial_tokens')
        .select()
        .eq('organization_id', organizationId)
        .eq('status', 'active')
        .maybeSingle();
    if (response == null) return null;
    return SerialToken.fromJson(response);
  }

  // ============ Seats ============

  /// Seats for an organization, with the occupant's employee details.
  ///
  /// ⚠ This used to embed
  /// `employees!organization_seats_occupied_by_employee_id_fkey`, and
  /// **`organization_seats` has no `occupied_by_employee_id` column and no such
  /// foreign key** — the columns are `occupied_by_user_id / _name / _email /
  /// _employee_role`. So the embed threw on every call, for every organisation,
  /// and the `catch (_)` fell back to a bare `select()` that carries no
  /// employee fields at all. The seat panel's First name, Last name, Contact
  /// No., WhatsApp No., ID number and photo were therefore **always empty**,
  /// and the swallowed exception meant nothing ever said so.
  ///
  /// PostgREST cannot embed `employees` here because no FK joins the two
  /// tables, so the join is done in two queries and merged. The merged map is
  /// injected under the `employees` key the model already reads, so
  /// `OrganizationSeat.fromJson` is unchanged.
  Future<List<OrganizationSeat>> getOrganizationSeats(String organizationId) async {
    final seatRows = await _client
        .from('organization_seats')
        .select()
        .eq('organization_id', organizationId)
        .order('seat_number');

    final employeeRows = await _client
        .from('employees')
        .select(
          'user_id, first_name, last_name, whatsapp_number, id_number, profile_photo_url',
        )
        .eq('company_id', organizationId);

    final byUserId = <String, Map<String, dynamic>>{
      for (final e in (employeeRows as List))
        if ((e as Map)['user_id'] != null)
          e['user_id'] as String: Map<String, dynamic>.from(e),
    };

    return (seatRows as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final occupant = row['occupied_by_user_id'] as String?;
      if (occupant != null && byUserId.containsKey(occupant)) {
        row['employees'] = byUserId[occupant];
      }
      return OrganizationSeat.fromJson(row);
    }).toList();
  }

  /// Move a seat to another user.
  ///
  /// `reassign_seat` enforces the governance itself — platform admin or a
  /// manager of the seat's own company, the seat's `role_binding`, the role
  /// being valid for the org type, and **max 2 reassignments per company per
  /// 30 days**. It had no call site anywhere in the app until now, so none of
  /// that was reachable.
  ///
  /// Returns the RPC's own `{success, error}` object rather than throwing:
  /// "you have used your 2 moves this month" is a normal answer to give
  /// somebody, not an exception.
  Future<Map<String, dynamic>> reassignSeat({
    required String seatId,
    required String newUserId,
    required String newUserEmail,
    required String newUserName,
    required String newUserRole,
  }) async {
    final res = await _client.rpc('reassign_seat', params: {
      'p_seat_id': seatId,
      'p_new_user_id': newUserId,
      'p_new_user_email': newUserEmail,
      'p_new_user_name': newUserName,
      'p_new_user_role': newUserRole,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// How many of the 2 reassignments in the rolling 30 days remain.
  /// `{allowed, used, remaining, limit, period_days}`.
  Future<Map<String, dynamic>> seatReassignmentAllowance(
      String organizationId) async {
    final res = await _client.rpc('check_seat_reassignment_allowed',
        params: {'p_organization_id': organizationId});
    return Map<String, dynamic>.from(res as Map);
  }

  // ============ Token requests (company seat / token queue) ============

  /// Open token requests: pending or in-progress (claimed).
  Future<List<TokenRequest>> getOpenTokenRequests() async {
    final response = await _client
        .from('token_requests')
        .select()
        .inFilter('status', ['pending', 'in_progress'])
        .order('created_at', ascending: false);
    final rows = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final handlerIds = rows
        .map((e) => e['handling_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (handlerIds.isEmpty) {
      return rows.map(TokenRequest.fromJson).toList();
    }
    final profiles = await _client
        .from('profiles')
        .select('id, display_name, email')
        .inFilter('id', handlerIds);
    final byId = <String, Map<String, dynamic>>{};
    for (final p in profiles as List) {
      final m = Map<String, dynamic>.from(p as Map);
      final id = m['id'] as String?;
      if (id != null) byId[id] = m;
    }
    for (final row in rows) {
      final hid = row['handling_user_id'] as String?;
      if (hid != null) {
        final p = byId[hid];
        if (p != null) row['handler'] = p;
      }
    }
    return rows.map(TokenRequest.fromJson).toList();
  }

  /// History of token requests for one organization.
  Future<List<TokenRequest>> getOrganizationTokenRequests(String organizationId) async {
    final response = await _client
        .from('token_requests')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => TokenRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Map<String, dynamic>> claimTokenRequest(String requestId) async {
    final response = await _client.rpc('claim_token_request', params: {
      'p_request_id': requestId,
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> releaseTokenRequestClaim(String requestId) async {
    final response = await _client.rpc('release_token_request_claim', params: {
      'p_request_id': requestId,
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveTokenRequest({
    required String requestId,
    String? reviewNote,
    int? approvedNewSeatLimit,
    int? validDays,
  }) async {
    final response = await _client.rpc('approve_token_request', params: {
      'p_request_id': requestId,
      'p_review_note': reviewNote,
      'p_approved_new_seat_limit': approvedNewSeatLimit,
      'p_valid_days': validDays,
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectTokenRequest({
    required String requestId,
    String reviewNote = 'Request rejected',
  }) async {
    final response = await _client.rpc('reject_token_request', params: {
      'p_request_id': requestId,
      'p_review_note': reviewNote,
    });
    return response as Map<String, dynamic>;
  }

  /// Company manager: snapshot for building token request payloads.
  Future<Map<String, dynamic>> getCompanySeatSnapshotForRequests(String organizationId) async {
    final response = await _client
        .from('companies')
        .select('seat_limit, seats_used, current_token_id, token_expires_at, status')
        .eq('id', organizationId)
        .single();
    return Map<String, dynamic>.from(response as Map);
  }

  /// Company manager: submit seat expansion, token renewal, or new-token request.
  Future<Map<String, dynamic>> createCompanyTokenRequest({
    required String organizationId,
    required String requestKind,
    String reason = '',
    int? requestedExtraSeats,
    int? requestedNewTotal,
    int? requestedValidDays,
    String? currentTokenId,
  }) async {
    final response = await _client.rpc('create_company_token_request', params: {
      'p_organization_id': organizationId,
      'p_request_kind': requestKind,
      'p_reason': reason,
      'p_requested_extra_seats': requestedExtraSeats,
      'p_requested_new_total': requestedNewTotal,
      'p_requested_valid_days': requestedValidDays,
      'p_current_token_id': currentTokenId,
    });
    return response as Map<String, dynamic>;
  }

  // ============ Audit Logs ============

  /// Get audit logs with optional filters
  Future<List<AuditLog>> getAuditLogs({
    String? actorUserId,
    String? organizationId,
    String? organizationType,
    String? actionType,
    List<String>? actionTypes,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    var query = _client.from('audit_logs').select();

    if (actorUserId != null) {
      query = query.eq('actor_user_id', actorUserId);
    }
    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }
    if (organizationType != null) {
      query = query.eq('organization_type', organizationType);
    }
    if (actionType != null) {
      query = query.eq('action_type', actionType);
    } else if (actionTypes != null && actionTypes.isNotEmpty) {
      query = query.inFilter('action_type', actionTypes);
    }
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => AuditLog.fromJson(e)).toList();
  }

  /// Watch audit logs in real-time
  Stream<List<Map<String, dynamic>>> watchAuditLogs() {
    return _client
        .from('audit_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50);
  }

  // ============ Crash Reports ============

  /// Crash reports captured by `SupabaseReportingSink` (Task 2/3). Read-only:
  /// `crash_reports` has a SELECT policy gated to `is_platform_admin()` and no
  /// UPDATE/DELETE policy at all, so this method has no write counterpart.
  ///
  /// Filters are applied server-side so the "Fatal only" toggle and the
  /// platform/app_version facet chips on the console screen do not depend on
  /// pulling every row to filter client-side.
  Future<List<CrashReportRow>> getCrashReports({
    bool fatalOnly = false,
    String? platform,
    String? appVersion,
    int limit = 500,
  }) async {
    var query = _client.from('crash_reports').select();

    if (fatalOnly) {
      query = query.eq('fatal', true);
    }
    if (platform != null) {
      query = query.eq('platform', platform);
    }
    if (appVersion != null) {
      query = query.eq('app_version', appVersion);
    }

    final response = await query.order('at', ascending: false).limit(limit);
    return (response as List)
        .map((e) => CrashReportRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Distinct `platform` / `app_version` values across ALL crash reports —
  /// deliberately independent of the `fatalOnly`/`platform`/`appVersion`
  /// filters applied in [getCrashReports], so the console's facet chips
  /// always offer every option instead of shrinking to whatever the current
  /// filter's result happens to contain. Selects only these two narrow
  /// columns (not `error`/`stack`, which can be up to 4 kB/16 kB each per
  /// the table's CHECK constraints), so this stays cheap as the table grows
  /// past [getCrashReports]'s own row cap.
  Future<({Set<String> platforms, Set<String> appVersions})>
      getCrashReportFacets({int limit = 2000}) async {
    final response = await _client
        .from('crash_reports')
        .select('platform, app_version')
        .order('at', ascending: false)
        .limit(limit);

    final platforms = <String>{};
    final appVersions = <String>{};
    for (final row in (response as List)) {
      final p = row['platform'] as String?;
      final v = row['app_version'] as String?;
      if (p != null && p.isNotEmpty) platforms.add(p);
      if (v != null && v.isNotEmpty) appVersions.add(v);
    }
    return (platforms: platforms, appVersions: appVersions);
  }

  // ============ Account Deactivations ============

  /// Platform-admin console queue over `account_deactivation_requests`
  /// (Tasks 6-9). Pass [status] to ask the RPC for one status only; omit it
  /// (the default) to get every status back — the screen filters
  /// client-side, because the meaningful default view is "everything except
  /// the terminal states" (`deactivated`/`rejected`/`cancelled`), which the
  /// single-status RPC signature cannot express in one call. The queue is a
  /// small admin-facing list, not a high-volume table, so one full fetch is
  /// cheap.
  Future<List<AccountDeactivationRow>> getAccountDeactivationRequests({
    String? status,
  }) async {
    final response = await _client.rpc(
      'list_account_deactivation_requests',
      params: {'p_status': status},
    );
    return (response as List)
        .map((e) =>
            AccountDeactivationRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Approve or reject a pending request. `review_account_deactivation_
  /// request` itself refuses a reject with an empty [note] (SQLSTATE MLD02) —
  /// the screen mirrors that by disabling its own "Reject request" button
  /// first, so the refusal is never the user's first sign anything is wrong.
  Future<void> reviewAccountDeactivationRequest({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    await _client.rpc('review_account_deactivation_request', params: {
      'p_id': requestId,
      'p_approve': approve,
      'p_note': note,
    });
  }

  /// The exact inverse of `deactivate_account` — platform-admin only, takes
  /// the USER id (not the request id). This is the control that makes the
  /// whole design honest: without a reachable way back, "reversible" is a
  /// claim nobody can act on.
  Future<void> reactivateAccount(String userId) async {
    await _client.rpc('reactivate_account', params: {'p_user_id': userId});
  }

  // ============ Platform Admin Settings ============

  /// Get platform admin settings
  Future<PlatformAdminSettings?> getPlatformAdminSettings() async {
    final response = await _client
        .from('platform_admin_settings')
        .select()
        .eq('id', 'main')
        .maybeSingle();
    if (response == null) return null;
    return PlatformAdminSettings.fromJson(response);
  }

  // ============ Company Status Management ============

  /// Suspend a company
  Future<void> suspendCompany(String companyId) async {
    await _client.rpc('super_admin_set_company_status', params: {
      'p_company_id': companyId,
      'p_status': 'suspended',
    });
  }

  /// Reactivate a company (requires active token)
  Future<void> reactivateCompany(String companyId) async {
    await _client.rpc('super_admin_set_company_status', params: {
      'p_company_id': companyId,
      'p_status': 'active',
    });
  }

  // ============ User Quick Actions ============

  /// Suspend a user (set employees.status = 'suspended')
  Future<void> suspendUser({
    required String employeeId,
    String reason = 'Suspended by platform admin',
  }) async {
    await _client.rpc('super_admin_set_employee_status', params: {
      'p_employee_id': employeeId,
      'p_status': 'suspended',
      'p_reason': reason,
    });
  }

  /// Reactivate a suspended user
  Future<void> reactivateUser({required String employeeId}) async {
    await _client.rpc('super_admin_set_employee_status', params: {
      'p_employee_id': employeeId,
      'p_status': 'active',
      'p_reason': null,
    });
  }

  /// Remove a user from their assigned organization seat
  Future<void> removeUserFromSeat({
    required String userId,
    required String companyId,
  }) async {
    await _client.rpc('super_admin_release_organization_seat', params: {
      'p_organization_id': companyId,
      'p_user_id': userId,
    });
  }

  /// Change an employee's role within their organization
  Future<void> changeEmployeeRole({
    required String employeeId,
    required String newRole,
  }) async {
    await _client.rpc('super_admin_set_employee_role', params: {
      'p_employee_id': employeeId,
      'p_role': newRole,
    });
  }

  // ============ Org insights (monthly, platform admin reads) ============

  /// Preferred path: single DB RPC for companies + aggregate; falls back to Dart merge if RPC fails.
  ///
  /// [rangeStart] / [rangeEnd] default to the current calendar month, which is
  /// what every existing caller wants. The RPC has always taken a range — this
  /// only stops the repository from hardcoding one, so the leaderboard's period
  /// control can ask for a quarter or a year and get every column re-scoped by
  /// the same SQL rather than re-derived here. See [InsightsPeriod].
  Future<MonthlyInsightsBundle> getMonthlyInsightsBundle(
    String orgType, {
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final month = _currentMonthWindow();
    final window = (
      monthStart: rangeStart ?? month.monthStart,
      monthEnd: rangeEnd ?? month.monthEnd,
    );
    try {
      final raw = await _client.rpc(
        'super_admin_monthly_insights_bundle',
        params: {
          'p_org_type': orgType,
          // `serverParam`, not `toIso8601String`: a bare ISO string has no
          // offset, so Postgres read the month's edges in the session zone
          // (UTC) and the whole window sat two hours late.
          'p_range_start': MlTime.serverParam(window.monthStart),
          'p_range_end': MlTime.serverParam(window.monthEnd),
        },
      );
      if (raw != null) {
        final map = Map<String, dynamic>.from(raw as Map);
        final list = (map['companies'] as List?) ?? const [];
        final companies = list
            .map((e) => CompanyMonthlyOpsStats.fromRpcJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final aggMap = map['aggregate'];
        final aggregate = OrgTypeAggregateStats.fromRpcJson(
          Map<String, dynamic>.from(aggMap as Map? ?? {}),
        );
        return MonthlyInsightsBundle(
          companies: companies,
          aggregate: aggregate,
          rangeStartIso: map['range_start']?.toString(),
          rangeEndIso: map['range_end']?.toString(),
          fromDatabaseRpc: true,
        );
      }
    } catch (_) {
      // Fallback below (offline, older DB, etc.).
    }

    // The Dart fallback can only rebuild the CURRENT month. Handing that back
    // for a quarter or a year would put the wrong window behind a chip that
    // names a different one — a wrong number is worse than an error state, so
    // a windowed caller gets the failure instead.
    if (rangeStart != null || rangeEnd != null) {
      throw StateError(
        'Insights for ${window.monthStart.toIso8601String()} … '
        '${window.monthEnd.toIso8601String()} need the database; '
        'the offline fallback can only rebuild the current month.',
      );
    }

    final companies = await _dartFallbackCompanyMonthlyOpsStats(orgType);
    return MonthlyInsightsBundle(
      companies: companies,
      aggregate: _aggregateFromCompanyRows(orgType, companies),
      rangeStartIso: MlTime.serverParam(window.monthStart),
      rangeEndIso: MlTime.serverParam(window.monthEnd),
      fromDatabaseRpc: false,
    );
  }

  Future<void> logInsightsCsvExport({
    required String organizationId,
    required String companyName,
  }) async {
    await _client.rpc(
      'insert_audit_log',
      params: {
        'p_action_type': 'INSIGHTS_CSV_EXPORT',
        'p_target_type': 'company',
        'p_target_id': organizationId,
        'p_target_name': companyName,
        'p_organization_id': organizationId,
        'p_description': 'Super-admin exported monthly insights CSV (read-only)',
      },
    );
  }

  static String _partyColumnForOrgType(String orgType) {
    switch (orgType) {
      case 'transporter':
        return 'transporter_company_id';
      case 'buyer':
        return 'buyer_company_id';
      case 'mineSupplier':
      default:
        return 'supplier_company_id';
    }
  }

  /// Current calendar month window, on the South African clock.
  ({DateTime monthStart, DateTime monthEnd}) _currentMonthWindow() {
    final now = MlTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
    return (monthStart: monthStart, monthEnd: monthEnd);
  }

  OrgTypeAggregateStats _aggregateFromCompanyRows(String orgType, List<CompanyMonthlyOpsStats> rows) {
    if (rows.isEmpty) {
      return OrgTypeAggregateStats(
        orgType: orgType,
        companyCount: 0,
        activeTripsApprox: 0,
        fleetVehiclesTotal: 0,
        tonsMoved: 0,
        transactionsTotal: 0,
        completedWaybills: 0,
        pendingWaybills: 0,
      );
    }
    var trips = 0;
    var fleet = 0;
    var tons = 0.0;
    var loads = 0;
    var comp = 0;
    var pend = 0;
    for (final r in rows) {
      trips += r.trips;
      fleet += r.fleetVehicles;
      tons += r.tonsMoved;
      loads += r.loadsCount;
      comp += r.completedWaybills;
      pend += r.pendingWaybills;
    }
    return OrgTypeAggregateStats(
      orgType: orgType,
      companyCount: rows.length,
      activeTripsApprox: trips,
      fleetVehiclesTotal: fleet,
      tonsMoved: tons,
      transactionsTotal: loads,
      completedWaybills: comp,
      pendingWaybills: pend,
    );
  }

  Future<List<CompanyMonthlyOpsStats>> _dartFallbackCompanyMonthlyOpsStats(String orgType) async {
    final col = _partyColumnForOrgType(orgType);
    final window = _currentMonthWindow();
    final companies = await _client
        .from('companies')
        .select('id, company_name, org_type')
        .eq('org_type', orgType)
        .order('company_name');

    final companyRows = List<Map<String, dynamic>>.from(
      (companies as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    if (companyRows.isEmpty) {
      return const [];
    }

    final companyIds = companyRows.map((e) => e['id'] as String).toList();

    final txResp = await _client
        .from('transactions')
        .select('id, supplier_company_id, buyer_company_id, transporter_company_id, status, quantity, updated_at')
        .gte('updated_at', MlTime.serverParam(window.monthStart));

    final tripsResp = await _client
        .from('trips')
        .select('id, transaction_id, route_id, status, net_tons, updated_at')
        .gte('updated_at', MlTime.serverParam(window.monthStart));

    final employeesResp = await _client
        .from('employees')
        .select('company_id, role')
        .inFilter('company_id', companyIds);

    final fleetResp = await _client
        .from('fleet_vehicles')
        .select('company_id')
        .inFilter('company_id', companyIds);

    final txRows =
        List<Map<String, dynamic>>.from((txResp as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final tripRows =
        List<Map<String, dynamic>>.from((tripsResp as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final empRows =
        List<Map<String, dynamic>>.from((employeesResp as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final fleetRows =
        List<Map<String, dynamic>>.from((fleetResp as List).map((e) => Map<String, dynamic>.from(e as Map)));

    final txnById = <String, Map<String, dynamic>>{};
    for (final t in txRows) {
      txnById[t['id'] as String] = t;
    }

    final statsByCompany = <String, CompanyMonthlyOpsStats>{};

    for (final row in companyRows) {
      final id = row['id'] as String;
      final name = row['company_name'] as String? ?? 'Company';
      final ot = row['org_type'] as String? ?? orgType;

      statsByCompany[id] = CompanyMonthlyOpsStats(
        companyId: id,
        companyName: name,
        orgType: ot,
        fleetVehicles: 0,
        drivers: 0,
        employees: 0,
        routesDistinct: 0,
        trips: 0,
        loadsCount: 0,
        tonsMoved: 0,
        completedWaybills: 0,
        pendingWaybills: 0,
      );
    }

    for (final e in empRows) {
      final cid = e['company_id'] as String?;
      if (cid == null || !statsByCompany.containsKey(cid)) continue;
      final cur = statsByCompany[cid]!;
      statsByCompany[cid] = CompanyMonthlyOpsStats(
        companyId: cur.companyId,
        companyName: cur.companyName,
        orgType: cur.orgType,
        fleetVehicles: cur.fleetVehicles,
        drivers: cur.drivers + ((e['role'] as String?) == 'driver' ? 1 : 0),
        employees: cur.employees + 1,
        routesDistinct: cur.routesDistinct,
        trips: cur.trips,
        loadsCount: cur.loadsCount,
        tonsMoved: cur.tonsMoved,
        completedWaybills: cur.completedWaybills,
        pendingWaybills: cur.pendingWaybills,
      );
    }

    for (final f in fleetRows) {
      final cid = f['company_id'] as String?;
      if (cid == null || !statsByCompany.containsKey(cid)) continue;
      final cur = statsByCompany[cid]!;
      statsByCompany[cid] = CompanyMonthlyOpsStats(
        companyId: cur.companyId,
        companyName: cur.companyName,
        orgType: cur.orgType,
        fleetVehicles: cur.fleetVehicles + 1,
        drivers: cur.drivers,
        employees: cur.employees,
        routesDistinct: cur.routesDistinct,
        trips: cur.trips,
        loadsCount: cur.loadsCount,
        tonsMoved: cur.tonsMoved,
        completedWaybills: cur.completedWaybills,
        pendingWaybills: cur.pendingWaybills,
      );
    }

    // Loads / waybill counts come from transactions. Tons moved does NOT —
    // transactions.quantity is the ordered/agreed amount (often 0). The real
    // "tons that went out" is the weighbridge net mass on trips.net_tons,
    // summed in the trips loop below.
    void mergeTxn(Map<String, dynamic> txn, String companyId) {
      final cur = statsByCompany[companyId]!;
      final st = (txn['status'] as String?) ?? 'draft';
      final completed = st.toLowerCase() == 'completed';
      statsByCompany[companyId] = CompanyMonthlyOpsStats(
        companyId: cur.companyId,
        companyName: cur.companyName,
        orgType: cur.orgType,
        fleetVehicles: cur.fleetVehicles,
        drivers: cur.drivers,
        employees: cur.employees,
        routesDistinct: cur.routesDistinct,
        trips: cur.trips,
        loadsCount: cur.loadsCount + 1,
        tonsMoved: cur.tonsMoved,
        completedWaybills: cur.completedWaybills + (completed ? 1 : 0),
        pendingWaybills: cur.pendingWaybills + (completed ? 0 : 1),
      );
    }

    for (final txn in txRows) {
      final cid = txn[col] as String?;
      if (cid == null || !statsByCompany.containsKey(cid)) continue;
      mergeTxn(txn, cid);
    }

    final routeSets = <String, Set<String?>>{};
    for (final id in companyIds) {
      routeSets[id] = <String?>{};
    }

    for (final trip in tripRows) {
      final tid = trip['transaction_id'] as String?;
      if (tid == null) continue;
      final txn = txnById[tid];
      if (txn == null) continue;
      final cid = txn[col] as String?;
      if (cid == null || !statsByCompany.containsKey(cid)) continue;

      final cur = statsByCompany[cid]!;
      // Weighbridge net mass (Net = Gross − Tare); null until the trip loads.
      final netTons = ((trip['net_tons'] as num?) ?? 0).toDouble();
      statsByCompany[cid] = CompanyMonthlyOpsStats(
        companyId: cur.companyId,
        companyName: cur.companyName,
        orgType: cur.orgType,
        fleetVehicles: cur.fleetVehicles,
        drivers: cur.drivers,
        employees: cur.employees,
        routesDistinct: cur.routesDistinct,
        trips: cur.trips + 1,
        loadsCount: cur.loadsCount,
        tonsMoved: cur.tonsMoved + netTons,
        completedWaybills: cur.completedWaybills,
        pendingWaybills: cur.pendingWaybills,
      );
      routeSets[cid]!.add(trip['route_id'] as String?);
    }

    for (final id in companyIds) {
      final cur = statsByCompany[id]!;
      final distinctRoutes = routeSets[id]?.whereType<String>().length ?? 0;
      statsByCompany[id] = CompanyMonthlyOpsStats(
        companyId: cur.companyId,
        companyName: cur.companyName,
        orgType: cur.orgType,
        fleetVehicles: cur.fleetVehicles,
        drivers: cur.drivers,
        employees: cur.employees,
        routesDistinct: distinctRoutes,
        trips: cur.trips,
        loadsCount: cur.loadsCount,
        tonsMoved: cur.tonsMoved,
        completedWaybills: cur.completedWaybills,
        pendingWaybills: cur.pendingWaybills,
      );
    }

    return companyIds.map((id) => statsByCompany[id]!).toList();
  }

  Future<List<CompanyMonthlyOpsStats>> getCompanyMonthlyOpsStats(String orgType) async {
    final bundle = await getMonthlyInsightsBundle(orgType);
    return bundle.companies;
  }

  Future<OrgTypeAggregateStats> getOrgTypeAggregateStats(String orgType) async {
    final bundle = await getMonthlyInsightsBundle(orgType);
    return bundle.aggregate;
  }

  // ============ Chat-link recommendations ============

  /// Company pairs implied by accepted business, for the chat-link
  /// recommendations panel. Returns most-recent-wins pairs (see
  /// [buildBusinessPairs]). Chat links are manual-only — these are suggestions,
  /// never auto-applied.
  Future<List<BusinessPair>> getBusinessPairs() async {
    final requests = await _client
        .from('transportation_requests')
        .select(
            'id,status,buyer_company_id,supplier_company_id,commodity,tons_available,updated_at,created_at')
        // Canonical accepted statuses (RequestStatus lifecycle) + legacy names.
        .inFilter('status', ['approved', 'linked', 'accepted', 'dispatched']);

    // Dispatch rows joined to their request's buyer/supplier via a nested select.
    final dispatchRows = await _client.from('request_dispatches').select(
        'id,status,transporter_company_id,dispatched_at,'
        'transportation_requests(buyer_company_id,supplier_company_id)');
    final dispatches = [
      for (final d in (dispatchRows as List))
        {
          ...Map<String, dynamic>.from(d as Map),
          'request_buyer_company_id':
              (d['transportation_requests'] as Map?)?['buyer_company_id'],
          'request_supplier_company_id':
              (d['transportation_requests'] as Map?)?['supplier_company_id'],
        }
    ];

    List<Map<String, dynamic>> transactions = const [];
    try {
      final tx = await _client.from('transactions').select(
          'supplier_company_id,buyer_company_id,transporter_company_id,created_at');
      transactions = [
        for (final t in (tx as List)) Map<String, dynamic>.from(t as Map)
      ];
    } catch (e) {
      // transactions table/columns optional — recommendations still work without it.
      _log.d('getBusinessPairs: transactions unavailable ($e)');
    }

    return buildBusinessPairs(
      [
        for (final r in (requests as List)) Map<String, dynamic>.from(r as Map)
      ],
      dispatches,
      transactions,
    );
  }
}

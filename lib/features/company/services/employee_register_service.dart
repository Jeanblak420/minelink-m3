import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Data access for the Employee Register (P7-27).
///
/// The register used to talk to Supabase from inside the screen — 13 tables,
/// `db.from(...)` in a widget file, against CLAUDE.md §6. Everything it reads
/// now lives here, typed, so the screen renders models and nothing else.
///
/// Two rules this file exists to hold:
///
/// * **Presence comes from `list_company_member_presence`, never `profiles`.**
///   `profiles_select_own` restricts `profiles` to the caller's own row, so a
///   company manager reading it directly gets 1 row of N and every colleague
///   renders offline — a fabricated status (P7-30). The RPC returns exactly two
///   facts and raises `42501` when refused, so a denial surfaces as an error
///   instead of an empty register.
/// * **A KPI block that fails drops that KPI, not the register** — but it logs.
///   Silent `catch (_) {}` is what hid the presence fault for as long as it hid.
class EmployeeRegisterService {
  EmployeeRegisterService({SupabaseClient? client})
      : _db = client ?? SupabaseConfig.client;

  final SupabaseClient _db;
  static final _log = LoggerFactory.getLogger('EmployeeRegisterService');

  List<Map<String, dynamic>> _rows(dynamic result) => [
        for (final e in result as List) Map<String, dynamic>.from(e as Map),
      ];

  /// Every employee registered under [companyId], oldest first.
  ///
  /// RLS: `employees` is `is_company_manager(company_id)` — an owner, an active
  /// admin or an active management user of that company, or the platform admin.
  Future<List<Employee>> listEmployees(String companyId) async {
    final rows = await _db
        .from('employees')
        .select()
        .eq('company_id', companyId)
        .order('created_at');
    return [for (final r in _rows(rows)) Employee.fromJson(r)];
  }

  /// Presence + signature state for one company's members, keyed by user id.
  ///
  /// Deliberately **not** wrapped in a catch: a `42501` from the RPC means the
  /// caller is not a manager of this company, and the register must say so
  /// rather than render everybody offline.
  Future<Map<String, MemberPresence>> memberPresence(String companyId) async {
    final rows = _rows(
      await _db.rpc(
        'list_company_member_presence',
        params: {'p_company_id': companyId},
      ),
    );
    return {
      for (final r in rows)
        if (r['user_id'] != null)
          r['user_id'] as String: MemberPresence(
            userId: r['user_id'] as String,
            // An INSTANT, not a South African wall clock. Every reader
            // of this field measures an AGE with it (`MlPresence`,
            // `MlTime.ago`), and a wall clock's epoch value depends on the
            // reader's own device offset — see `core/presence/ml_presence.dart`.
            lastSeenAt: r['last_seen_at'] == null
                ? null
                : DateTime.parse(r['last_seen_at'] as String).toUtc(),
            hasSignature: r['has_signature'] == true,
          ),
    };
  }

  /// The register in one read: employees joined to their presence row.
  Future<List<RegisterMember>> listMembers(String companyId) async {
    final employees = await listEmployees(companyId);
    final presence = await memberPresence(companyId);
    return [
      for (final e in employees) RegisterMember(e, presence[e.userId]),
    ];
  }

  /// driver employee id → registration of the truck they are assigned to (the
  /// first assignment wins when a driver holds several). Best-effort: a failure
  /// costs the truck chip, not the register.
  Future<Map<String, String>> driverTruckRegistrations(String companyId) async {
    try {
      final assigns = _rows(
        await _db
            .from('driver_assignments')
            .select('driver_employee_id, vehicle_id')
            .eq('company_id', companyId),
      );
      final byDriver = <String, String>{};
      final vehicleIds = <String>{};
      for (final m in assigns) {
        final d = m['driver_employee_id'] as String?;
        final v = m['vehicle_id'] as String?;
        if (d == null || v == null) continue;
        byDriver.putIfAbsent(d, () => v);
        vehicleIds.add(v);
      }
      if (byDriver.isEmpty) return const {};
      final vehicles = _rows(
        await _db
            .from('fleet_vehicles')
            .select('id, vehicle_registration_number')
            .inFilter('id', vehicleIds.toList()),
      );
      final regById = {
        for (final v in vehicles)
          v['id'] as String: (v['vehicle_registration_number'] as String?) ?? '',
      };
      return {
        for (final e in byDriver.entries)
          if ((regById[e.value] ?? '').isNotEmpty) e.key: regById[e.value]!,
      };
    } catch (e) {
      _log.w('driver → truck resolution failed for $companyId: $e');
      return const {};
    }
  }

  /// Role-group KPIs + the compliance documents the section chips count.
  ///
  /// Every number maps to an action that already exists in the app:
  ///   Mine — Supervisors: stockpiles touched today (`stockpile_transactions`)
  ///        · Load Controllers: loads recorded vs arrivals (`trips.loaded_at`)
  ///        · Security: arrivals closed out (`trips.left_at`)
  ///        · Admins: recon disputes resolved (`recon_disputes`)
  ///   Buyer — Admins: requests linked to a hauler (`transportation_requests`)
  ///   Transporter — Admins: dispatches with a truck on them (`trips.vehicle_id`)
  ///        · Drivers: completed trips with a POD (`pod_uploads`)
  Future<RegisterKpiBundle> kpiBundle({
    required String companyId,
    required OrgType orgType,
  }) async {
    final byGroup = <String, RegisterKpi>{};
    // The start of TODAY AT THE MINE, as the instant a `timestamptz`
    // filter wants. It was the device's local midnight re-flagged as
    // UTC — so a register opened at 01:00 SAST counted from 23:00 the
    // previous day, and one opened in London counted from two hours
    // into the mine's morning (CLAUDE.md §7.1).
    final dayIso = MlTime.serverParam(MlTime.today());

    switch (orgType) {
      case OrgType.transporter:
        await _transporterKpis(companyId, byGroup);
      case OrgType.buyer:
        await _buyerKpis(companyId, byGroup);
      case OrgType.mineSupplier:
        await _mineKpis(companyId, byGroup, dayIso);
    }

    var docs = <RegisterComplianceDoc>[];
    try {
      docs = [
        for (final d in _rows(
          await _db
              .from('compliance_documents')
              .select('owner_type, owner_id, expires_at, doc_type')
              .eq('company_id', companyId),
        ))
          RegisterComplianceDoc(
            ownerType: d['owner_type'] as String?,
            ownerId: d['owner_id'] as String?,
            docType: d['doc_type'] as String?,
            expiresAt: DateTime.tryParse((d['expires_at'] as String?) ?? ''),
          ),
      ];
    } catch (e) {
      _log.w('compliance documents unavailable for $companyId: $e');
    }

    return RegisterKpiBundle(byGroup, docs);
  }

  Future<void> _transporterKpis(
    String companyId,
    Map<String, RegisterKpi> byGroup,
  ) async {
    List<Map<String, dynamic>> trips;
    try {
      final vehicles = _rows(
        await _db.from('fleet_vehicles').select('id').eq(
              'company_id',
              companyId,
            ),
      );
      final vids = [for (final v in vehicles) v['id'] as String];
      trips = vids.isEmpty
          ? <Map<String, dynamic>>[]
          : _rows(
              await _db
                  .from('trips')
                  .select('id, vehicle_id, dispatch_id, status')
                  .inFilter('vehicle_id', vids),
            );
    } catch (e) {
      _log.w('transporter fleet/trips read failed for $companyId: $e');
      return;
    }

    try {
      final dispatches = _rows(
        await _db
            .from('request_dispatches')
            .select('id')
            .eq('transporter_company_id', companyId),
      );
      final withTruck = {
        for (final t in trips)
          if (t['dispatch_id'] != null && t['vehicle_id'] != null)
            t['dispatch_id'] as String,
      };
      final total = dispatches.length;
      final assigned =
          dispatches.where((d) => withTruck.contains(d['id'])).length;
      byGroup[RegisterRoleGroups.admins] = RegisterKpi(
        'ROUTES ASSIGNED',
        registerPct(assigned, total),
        total == 0
            ? 'no dispatched routes yet'
            : '${registerPlural(total - assigned, 'route')} without a truck '
                'assigned',
      );
    } catch (e) {
      _log.w('dispatch-assignment KPI failed for $companyId: $e');
    }

    try {
      final completedIds = [
        for (final t in trips)
          if (t['status'] == 'completed') t['id'] as String,
      ];
      final podded = completedIds.isEmpty
          ? <String>{}
          : {
              for (final p in _rows(
                await _db
                    .from('pod_uploads')
                    .select('trip_id')
                    .inFilter('trip_id', completedIds),
              ))
                p['trip_id'] as String,
            };
      final missing = completedIds.where((id) => !podded.contains(id)).length;
      byGroup[RegisterRoleGroups.drivers] = RegisterKpi(
        'PODS UPLOADED',
        registerPct(completedIds.length - missing, completedIds.length),
        completedIds.isEmpty
            ? 'no completed trips yet'
            : '${registerPlural(missing, 'trip')} missing POD',
      );
    } catch (e) {
      _log.w('POD KPI failed for $companyId: $e');
    }
  }

  Future<void> _buyerKpis(
    String companyId,
    Map<String, RegisterKpi> byGroup,
  ) async {
    try {
      final requests = _rows(
        await _db
            .from('transportation_requests')
            .select('id, status')
            .eq('buyer_company_id', companyId),
      );
      final total = requests.length;
      final filled = requests.where((r) => r['status'] == 'linked').length;
      byGroup[RegisterRoleGroups.admins] = RegisterKpi(
        'REQUESTS FILLED',
        registerPct(filled, total),
        total == 0
            ? 'no transport requests yet'
            : '${registerPlural(total - filled, 'request')} not yet linked',
      );
    } catch (e) {
      _log.w('buyer request KPI failed for $companyId: $e');
    }
  }

  Future<void> _mineKpis(
    String companyId,
    Map<String, RegisterKpi> byGroup,
    String dayIso,
  ) async {
    try {
      final piles = _rows(
        await _db
            .from('stockpiles')
            .select('id, balance_tons')
            .eq('supplier_company_id', companyId),
      );
      final active = [
        for (final p in piles)
          if (((p['balance_tons'] as num?) ?? 0) > 0) p['id'] as String,
      ];
      if (active.isEmpty) {
        byGroup[RegisterRoleGroups.supervisors] = const RegisterKpi(
          'STOCKPILES UPDATED',
          null,
          'no stockpiles with product',
        );
      } else {
        final touched = {
          for (final t in _rows(
            await _db
                .from('stockpile_transactions')
                .select('stockpile_id')
                .inFilter('stockpile_id', active)
                .gte('at', dayIso),
          ))
            t['stockpile_id'] as String,
        };
        byGroup[RegisterRoleGroups.supervisors] = RegisterKpi(
          'STOCKPILES UPDATED',
          registerPct(touched.length, active.length),
          '${active.length - touched.length} of ${active.length} stockpiles '
              'untouched today',
        );
      }
    } catch (e) {
      _log.w('stockpile KPI failed for $companyId: $e');
    }

    try {
      final routeIds = [
        for (final r in _rows(
          await _db.from('routes').select('id').eq(
                'supplier_company_id',
                companyId,
              ),
        ))
          r['id'] as String,
      ];
      final trips = routeIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _rows(
              await _db
                  .from('trips')
                  .select('id, arrived_at, loaded_at, left_at')
                  .inFilter('route_id', routeIds),
            );

      final now = MlTime.now();
      final arrivedToday = trips.where((t) {
        final at = MlTime.sastOrNull(DateTime.tryParse((t['arrived_at'] as String?) ?? ''));
        return at != null &&
            at.year == now.year &&
            at.month == now.month &&
            at.day == now.day;
      }).toList();

      final loaded = arrivedToday.where((t) => t['loaded_at'] != null).length;
      byGroup[RegisterRoleGroups.loadControllers] = RegisterKpi(
        'LOADS RECORDED',
        registerPct(loaded, arrivedToday.length),
        arrivedToday.isEmpty
            ? 'no arrivals today'
            : '${registerPlural(arrivedToday.length - loaded, 'truck')} '
                'arrived, load not recorded',
      );

      final left = arrivedToday.where((t) => t['left_at'] != null).length;
      byGroup[RegisterRoleGroups.security] = RegisterKpi(
        'ARRIVALS CLOSED OUT',
        registerPct(left, arrivedToday.length),
        arrivedToday.isEmpty
            ? 'no arrivals today'
            : '${registerPlural(arrivedToday.length - left, 'truck')} arrived, '
                'not marked left',
      );

      try {
        final tripIds = [for (final t in trips) t['id'] as String];
        final disputes = tripIds.isEmpty
            ? <Map<String, dynamic>>[]
            : _rows(
                await _db
                    .from('recon_disputes')
                    .select('id, resolved_at')
                    .inFilter('trip_id', tripIds),
              );
        final open = disputes.where((d) => d['resolved_at'] == null).length;
        byGroup[RegisterRoleGroups.admins] = RegisterKpi(
          'RECONS CLOSED',
          disputes.isEmpty
              ? 100
              : registerPct(disputes.length - open, disputes.length),
          disputes.isEmpty
              ? 'no reconciliation disputes open'
              : '${registerPlural(open, 'reconciliation dispute')} open',
        );
      } catch (e) {
        _log.w('recon-dispute KPI failed for $companyId: $e');
      }
    } catch (e) {
      _log.w('mine trip KPIs failed for $companyId: $e');
    }
  }
}

/// The role-group titles the KPI map is keyed by. String keys shared between
/// the service and the screen's section list — named here so a rename cannot
/// silently detach a KPI from its section.
abstract final class RegisterRoleGroups {
  static const admins = 'Admins & Management';
  static const supervisors = 'Supervisors & Foremen';
  static const loadControllers = 'Load Controllers';
  static const security = 'Security';
  static const drivers = 'Drivers';
}

/// `null` when there is nothing to count — renders as a muted dash, never 0%.
int? registerPct(int done, int total) =>
    total == 0 ? null : ((done / total) * 100).round();

String registerPlural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// What `list_company_member_presence` returns for one member. The signature
/// URL itself is never exposed — only whether there is one (P7-35).
class MemberPresence {
  const MemberPresence({
    required this.userId,
    required this.lastSeenAt,
    required this.hasSignature,
  });

  final String userId;
  final DateTime? lastSeenAt;
  final bool hasSignature;
}

/// One register row: the employee plus their account's presence facts.
class RegisterMember {
  const RegisterMember(this.employee, this.presence);

  final Employee employee;
  final MemberPresence? presence;

  /// `profiles.last_seen_at` — the DB heartbeat, before the live channel is
  /// folded in.
  DateTime? get lastSeenAt => presence?.lastSeenAt;

  /// `null` when presence could not be resolved for this member at all, so the
  /// screen can render "unknown" rather than claiming a missing signature.
  bool? get hasSignature => presence?.hasSignature;
}

/// One role-group KPI: a completed-vs-outstanding ratio over a single record
/// type, counted from live rows — never derived or invented.
class RegisterKpi {
  const RegisterKpi(this.label, this.pct, this.detail);

  final String label; // e.g. 'PODS UPLOADED'
  final int? pct; // null = nothing to count yet
  final String detail; // e.g. '2 trips missing POD'
}

/// A compliance document, reduced to what the section chips count.
class RegisterComplianceDoc {
  const RegisterComplianceDoc({
    required this.ownerType,
    required this.ownerId,
    required this.docType,
    required this.expiresAt,
  });

  final String? ownerType;
  final String? ownerId;
  final String? docType;
  final DateTime? expiresAt;
}

class RegisterKpiBundle {
  const RegisterKpiBundle(this.byGroup, this.docs);

  final Map<String, RegisterKpi> byGroup;
  final List<RegisterComplianceDoc> docs;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final employeeRegisterServiceProvider = Provider<EmployeeRegisterService>(
  (ref) => EmployeeRegisterService(),
);

/// Employees + presence in one future, on purpose: a presence denial (`42501`)
/// must fail the register rather than leave a full list rendering offline.
final companyRegisterProvider = FutureProvider.autoDispose
    .family<List<RegisterMember>, String>(
  (ref, companyId) =>
      ref.watch(employeeRegisterServiceProvider).listMembers(companyId),
);

final companyDriverTrucksProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>(
  (ref, companyId) => ref
      .watch(employeeRegisterServiceProvider)
      .driverTruckRegistrations(companyId),
);

final companyRegisterKpisProvider = FutureProvider.autoDispose
    .family<RegisterKpiBundle, ({String id, OrgType org})>(
  (ref, key) => ref
      .watch(employeeRegisterServiceProvider)
      .kpiBundle(companyId: key.id, orgType: key.org),
);

/// Resolves a company row by id — the portal entry point has only an id, while
/// the console already holds the [Company] (P7-29).
final registerCompanyProvider = FutureProvider.autoDispose
    .family<Company, String>(
  (ref, companyId) =>
      ref.watch(companyServiceProvider).getCompanyById(companyId),
);

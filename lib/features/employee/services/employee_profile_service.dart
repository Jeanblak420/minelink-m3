/// Employee profile detail view — data access (CLAUDE.md §6: all DB access via
/// a service). Design ref: docs/superpowers/specs/2026-08-03-employee-profile-
/// view-design.md + minelink-new-design-v0.1 employee-register.jsx FullProfile.
///
/// Every number rendered on the profile is REAL (register rule: never
/// fabricated metrics). Each query block is best-effort: a failed source drops
/// that card/metric — never the screen.
library;

import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';
import 'package:flutter_application_1/features/portal/services/compliance_service.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/design/components/ml_meta.dart';

/// P0-11 / S1-7: this file held 32 of the tree's 38 empty `catch (_) {}`
/// blocks. Every one guards an OPTIONAL enrichment — one metric card, one
/// activity-feed section, one lookup — so rethrowing would take down a whole
/// profile screen because a single card's table was unreadable. They log at
/// debug instead: the section still drops, but it stops dropping silently.
final _log = LoggerFactory.getLogger('EmployeeProfileService');

// ---------------------------------------------------------------------------
// Presentation role key — maps the CODE roles onto the mock's per-role
// profile variants. `management` presents as Fleet Controller (transporter)
// and Procurement (buyer); everywhere else it presents like an admin.
// ---------------------------------------------------------------------------

enum ProfileRoleKey { admin, fleet, procure, driver, superv, load, security, other }

ProfileRoleKey profileRoleKey(OrgType org, UserRole? role) {
  switch (role) {
    case UserRole.driver:
      return ProfileRoleKey.driver;
    case UserRole.security:
      return ProfileRoleKey.security;
    case UserRole.controllerWB:
      return ProfileRoleKey.load;
    case UserRole.supervisorForeman:
      return ProfileRoleKey.superv;
    case UserRole.admin:
      return ProfileRoleKey.admin;
    case UserRole.management:
      switch (org) {
        case OrgType.transporter:
          return ProfileRoleKey.fleet;
        case OrgType.buyer:
          return ProfileRoleKey.procure;
        case OrgType.mineSupplier:
          return ProfileRoleKey.admin;
      }
    default:
      return ProfileRoleKey.other;
  }
}

/// Display label per the mocks (e.g. transporter management → Fleet
/// Controller). Falls back to the real role label.
String profileRoleLabel(OrgType org, UserRole? role) {
  if (role == UserRole.management && org == OrgType.transporter) {
    return 'Fleet Controller';
  }
  if (role == UserRole.management && org == OrgType.buyer) {
    return 'Procurement';
  }
  return role?.label ?? 'Member';
}

/// Mono employee code — same derivation as the register (`_empCode`):
/// role prefix + stable short tail of the real row id. Derived, not invented.
String profileEmpCode(Employee e) {
  final prefix = switch (e.role) {
    UserRole.supervisorForeman => 'SUP',
    UserRole.controllerWB => 'LC',
    UserRole.security => 'SG',
    UserRole.driver => 'DRV',
    UserRole.admin => 'ADM',
    UserRole.management => 'MGT',
    _ => 'EMP',
  };
  final tail = e.id.replaceAll('-', '').toUpperCase();
  return '$prefix-${tail.substring(0, tail.length < 4 ? tail.length : 4)}';
}

// ---------------------------------------------------------------------------
// Value models
// ---------------------------------------------------------------------------

enum ProfileTone { green, blue, amber, red, neutral }

class ProfilePerson {
  final Employee employee;
  final String? email; // real auth email (profiles.email)
  final bool whatsappOnly; // synthetic wa-… email → WhatsApp-only account
  final DateTime? lastSeenAt; // profiles.last_seen_at heartbeat
  final DateTime? lastLoginAt; // profiles.last_login_at
  const ProfilePerson({
    required this.employee,
    this.email,
    this.whatsappOnly = false,
    this.lastSeenAt,
    this.lastLoginAt,
  });
}

class ProfileCompany {
  final String id;
  final String name;
  final OrgType orgType;
  final int? seatsUsed;
  final int? seatLimit;
  final String? adminUserId; // companies.company_admin_user_id
  const ProfileCompany({
    required this.id,
    required this.name,
    required this.orgType,
    this.seatsUsed,
    this.seatLimit,
    this.adminUserId,
  });
}

class ProfileSupervisor {
  final String employeeId;
  final String userId;
  final String name;
  final String roleLabel;
  const ProfileSupervisor({
    required this.employeeId,
    required this.userId,
    required this.name,
    required this.roleLabel,
  });
}

/// Sibling register entry — powers the header's prev/next arrows with the
/// same people the register lists.
class ProfileSibling {
  final String employeeId;
  final String name;
  const ProfileSibling(this.employeeId, this.name);
}

class EmployeeProfileBundle {
  final ProfilePerson person;
  final ProfileCompany company;
  final ProfileSupervisor? supervisor;
  final List<ProfileSibling> register; // register order, incl. this employee
  const EmployeeProfileBundle({
    required this.person,
    required this.company,
    required this.supervisor,
    required this.register,
  });

  ProfileRoleKey get roleKey =>
      profileRoleKey(company.orgType, person.employee.role);
}

class ProfileMetric {
  final String label;
  final String value; // pre-formatted (real numbers only)
  final String unit;
  final String sub;
  final int? delta; // vs yesterday (null → no arrow)
  final bool deltaUp;
  /// Real daily counts, trailing 7 days — or **empty** when the metric is a
  /// snapshot with no daily history behind it (P8-28).
  ///
  /// Empty draws no chart. It used to draw one: five metrics passed either a
  /// flat `[0,0,0,0,0,0,0]` or `List.filled(7, currentValue)`, which renders as
  /// a perfectly level trend line — a graph asserting "no change all week" from
  /// data that says nothing at all about the week. Active vehicles, vehicles in
  /// service, floor headcount and seats used are counts of what is true *now*;
  /// there is no per-day series to draw, and inventing a level one is worse
  /// than leaving the space empty.
  final List<double> spark;
  final ProfileTone tone;
  const ProfileMetric({
    required this.label,
    required this.value,
    this.unit = '',
    required this.sub,
    this.delta,
    this.deltaUp = true,
    required this.spark,
    required this.tone,
  });
}

class ProfileActivityItem {
  final String bold; // "Gate check"
  final String rest; // " · truck HH-118 cleared"
  final DateTime at;
  final DateTime? until; // range events ("05:38 – 09:15")
  final bool isNow; // renders "now"
  final ProfileTone tone;
  final String? route; // portal deep link (go_router path)
  const ProfileActivityItem({
    required this.bold,
    required this.rest,
    required this.at,
    this.until,
    this.isNow = false,
    required this.tone,
    this.route,
  });
}

class ProfileDocItem {
  final String title;
  final String subtitle; // "renewed Jun 2025" / "uploaded Jan 2020"
  final String statusLabel; // Verified / Expires 14 mo / Expired
  final ProfileTone statusTone;
  final String? directUrl; // legacy slots — already a signed URL
  final String? compliancePath; // compliance_docs object path (sign on tap)
  const ProfileDocItem({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusTone,
    this.directUrl,
    this.compliancePath,
  });

  bool get openable =>
      (directUrl != null && directUrl!.isNotEmpty) ||
      (compliancePath != null && compliancePath!.isNotEmpty);
}

class ProfileFlag {
  final String title;
  final String body;
  final String metaLine; // "Opened by System · 3 days ago"
  final ProfileTone tone;
  const ProfileFlag({
    required this.title,
    required this.body,
    required this.metaLine,
    required this.tone,
  });
}

class ProfileDocsAndFlags {
  final List<ProfileDocItem> docs;
  final List<ProfileFlag> flags;
  const ProfileDocsAndFlags(this.docs, this.flags);
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _rows(dynamic r) => [
      for (final e in r as List) Map<String, dynamic>.from(e as Map),
    ];

DateTime? _ts(dynamic v) =>
    v == null ? null : MlTime.sastOrNull(DateTime.tryParse(v.toString()));

/// The raw moment, for anything that measures a DURATION rather than printing
/// a date. [_ts] returns a South African wall clock, which is right for a
/// column a reader reads and wrong for arithmetic.
DateTime? _instant(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

DateTime _dayStart([DateTime? of]) {
  // A day at the mine, whether `of` is a server instant or absent.
  final n = of == null ? MlTime.now() : MlTime.sast(of);
  return DateTime(n.year, n.month, n.day);
}

/// A South African wall clock as the instant Postgres should filter on.
/// `.toUtc()` here would have re-read the wall clock in the *device's*
/// zone, which is the thing this whole change removes.
String _iso(DateTime wallClock) => MlTime.serverParam(wallClock);

/// Real 7-day daily-count sparkline from event stamps (oldest → today).
List<double> _dailySpark(Iterable<DateTime?> stamps) {
  final counts = List<double>.filled(7, 0);
  final today = _dayStart();
  for (final s in stamps) {
    if (s == null) continue;
    final d = today.difference(_dayStart(s)).inDays;
    if (d >= 0 && d < 7) counts[6 - d] += 1;
  }
  return counts;
}

int? _sparkDelta(List<double> spark) {
  final today = spark[6].round(), yesterday = spark[5].round();
  if (today == 0 && yesterday == 0) return null;
  return today - yesterday;
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class EmployeeProfileService {
  EmployeeProfileService({SupabaseClient? client, StorageAssetService? assets})
      : _db = client ?? SupabaseConfig.client,
        _assets = assets ?? StorageAssetService();

  final SupabaseClient _db;
  final StorageAssetService _assets;

  // -- bundle ---------------------------------------------------------------

  Future<EmployeeProfileBundle> loadBundle(String employeeId) async {
    final raw = Map<String, dynamic>.from(
      await _db.from('employees').select().eq('id', employeeId).single(),
    );
    // Resolve profile photo + legacy document slots to signed URLs.
    Map<String, dynamic> resolved = raw;
    try {
      resolved = await _assets.resolveEmployeeRecord(raw);
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('employee asset URLs unavailable: $e');
    }
    final employee = Employee.fromJson(resolved);

    String? email;
    var whatsappOnly = false;
    DateTime? lastSeenAt, lastLoginAt;
    try {
      final p = await _db
          .from('profiles')
          .select('email, last_seen_at, last_login_at')
          .eq('id', employee.userId)
          .maybeSingle();
      if (p != null) {
        final m = Map<String, dynamic>.from(p);
        final e = (m['email'] as String?)?.trim();
        final synthetic = e != null &&
            (e == whatsappAuthEmail(employee.whatsappNumber) ||
                e.startsWith('wa-'));
        whatsappOnly = e == null || e.isEmpty || synthetic;
        email = whatsappOnly ? null : e;
        // INSTANTS, not wall clocks: both are rendered through
        // `MlTime.ago`, which measures a duration — see
        // `core/presence/ml_presence.dart` for what mixing the two cost.
        lastSeenAt = _instant(m['last_seen_at']);
        lastLoginAt = _instant(m['last_login_at']);
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('profile row (email / last seen) unavailable: $e');
    }

    final companyId = employee.companyId;
    ProfileCompany company = ProfileCompany(
      id: companyId ?? '',
      name: 'Company',
      orgType: OrgType.mineSupplier,
    );
    if (companyId != null) {
      try {
        final c = Map<String, dynamic>.from(
          await _db
              .from('companies')
              .select(
                  'id, company_name, org_type, seats_used, seat_limit, company_admin_user_id')
              .eq('id', companyId)
              .single(),
        );
        company = ProfileCompany(
          id: c['id'] as String,
          name: (c['company_name'] as String?) ?? 'Company',
          orgType: OrgType.tryParse(c['org_type'] as String?) ??
              OrgType.mineSupplier,
          seatsUsed: (c['seats_used'] as num?)?.toInt(),
          seatLimit: (c['seat_limit'] as num?)?.toInt(),
          adminUserId: c['company_admin_user_id'] as String?,
        );
      } catch (e) {
        // Best-effort section: a failed source drops this one card,
        // never the screen. Logged, never swallowed (P0-11 / S1-7).
        _log.d('company row unavailable: $e');
      }
    }

    // Register siblings, ordered like the register: per-org role order, then
    // name. Supervisor = first active supervisor (mine) / management / admin
    // that isn't this person; admins report to the Board instead.
    var register = <ProfileSibling>[ProfileSibling(employee.id, employee.fullName)];
    ProfileSupervisor? supervisor;
    if (companyId != null) {
      try {
        final all = _rows(await _db
            .from('employees')
            .select('id, user_id, first_name, last_name, role, status, is_dismissed')
            .eq('company_id', companyId));
        final members = [
          for (final m in all)
            if (m['is_dismissed'] != true) m,
        ];
        final order = UserRole.getRolesForOrgType(company.orgType);
        int rank(Map<String, dynamic> m) {
          final r = UserRole.tryParse(m['role'] as String?);
          final i = r == null ? -1 : order.indexOf(r);
          return i < 0 ? order.length : i;
        }

        String nameOf(Map<String, dynamic> m) =>
            '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
        members.sort((a, b) {
          final byRole = rank(a).compareTo(rank(b));
          return byRole != 0 ? byRole : nameOf(a).compareTo(nameOf(b));
        });
        if (members.isNotEmpty) {
          register = [
            for (final m in members)
              ProfileSibling(m['id'] as String, nameOf(m)),
          ];
          if (!register.any((s) => s.employeeId == employee.id)) {
            register.add(ProfileSibling(employee.id, employee.fullName));
          }
        }

        final isLeader = employee.role == UserRole.admin ||
            employee.role == UserRole.management;
        if (!isLeader) {
          final wanted = company.orgType == OrgType.mineSupplier
              ? const [
                  UserRole.supervisorForeman,
                  UserRole.management,
                  UserRole.admin
                ]
              : const [UserRole.management, UserRole.admin];
          for (final want in wanted) {
            final hit = members.where((m) =>
                m['id'] != employee.id &&
                UserRole.tryParse(m['role'] as String?) == want);
            if (hit.isNotEmpty) {
              final m = hit.first;
              supervisor = ProfileSupervisor(
                employeeId: m['id'] as String,
                userId: (m['user_id'] as String?) ?? '',
                name: nameOf(m),
                roleLabel: profileRoleLabel(company.orgType, want),
              );
              break;
            }
          }
        }
      } catch (e) {
        // Best-effort section: a failed source drops this one card,
        // never the screen. Logged, never swallowed (P0-11 / S1-7).
        _log.d('company admin contact unavailable: $e');
      }
    }

    return EmployeeProfileBundle(
      person: ProfilePerson(
        employee: employee,
        email: email,
        whatsappOnly: whatsappOnly,
        lastSeenAt: lastSeenAt,
        lastLoginAt: lastLoginAt,
      ),
      company: company,
      supervisor: supervisor,
      register: register,
    );
  }

  // -- productivity metrics -------------------------------------------------

  Future<List<ProfileMetric>> loadMetrics(EmployeeProfileBundle b) async {
    final e = b.person.employee;
    final uid = e.userId;
    final cid = b.company.id;
    final weekAgo = _iso(_dayStart().subtract(const Duration(days: 6)));
    final today = _iso(_dayStart());
    final now = MlTime.now();
    final monthStart = _iso(DateTime(now.year, now.month, 1));
    final out = <ProfileMetric>[];

    ProfileMetric counted({
      required String label,
      required List<DateTime?> stamps,
      required String sub,
      required ProfileTone tone,
      String? valueOverride,
      String unit = '',
    }) {
      final spark = _dailySpark(stamps);
      final delta = _sparkDelta(spark);
      return ProfileMetric(
        label: label,
        value: valueOverride ?? spark[6].round().toString(),
        unit: unit,
        sub: sub,
        delta: delta?.abs() == 0 ? null : delta?.abs(),
        deltaUp: (delta ?? 0) >= 0,
        spark: spark,
        tone: tone,
      );
    }

    switch (b.roleKey) {
      case ProfileRoleKey.driver:
        // Vehicles this driver holds (assignments + direct fleet linkage).
        final vids = <String>{};
        try {
          for (final a in _rows(await _db
              .from('driver_assignments')
              .select('vehicle_id')
              .eq('driver_employee_id', e.id))) {
            final v = a['vehicle_id'] as String?;
            if (v != null) vids.add(v);
          }
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('driver vehicle assignments unavailable: $e');
        }
        try {
          for (final v in _rows(await _db
              .from('fleet_vehicles')
              .select('id')
              .or('assigned_driver_employee_id.eq.${e.id},driver_user_id.eq.$uid'))) {
            vids.add(v['id'] as String);
          }
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('fleet vehicles for driver unavailable: $e');
        }

        var trips = <Map<String, dynamic>>[];
        if (vids.isNotEmpty) {
          try {
            trips = _rows(await _db
                .from('trips')
                .select('id, status, created_at, completed_at')
                .inFilter('vehicle_id', vids.toList())
                .gte('created_at', monthStart));
          } catch (e) {
            // Best-effort section: a failed source drops this one card,
            // never the screen. Logged, never swallowed (P0-11 / S1-7).
            _log.d('driver trips this month unavailable: $e');
          }
        }
        final monthTrips = trips.length;
        out.add(counted(
          label: 'TRIPS',
          stamps: [for (final t in trips) _ts(t['created_at'])],
          sub: 'this month',
          tone: ProfileTone.green,
          valueOverride: '$monthTrips',
        ));

        try {
          final completed = [
            for (final t in trips)
              if (t['status'] == 'completed') t['id'] as String,
          ];
          var podded = 0;
          var podStamps = <DateTime?>[];
          if (completed.isNotEmpty) {
            final pods = _rows(await _db
                .from('pod_uploads')
                .select('trip_id, uploaded_at')
                .inFilter('trip_id', completed));
            podded = {for (final p in pods) p['trip_id'] as String}.length;
            podStamps = [for (final p in pods) _ts(p['uploaded_at'])];
          }
          final pct = completed.isEmpty
              ? null
              : ((podded / completed.length) * 100).round();
          out.add(ProfileMetric(
            label: 'POD RATE',
            value: pct == null ? '—' : '$pct',
            unit: pct == null ? '' : '%',
            sub: completed.isEmpty
                ? 'no completed trips yet'
                : 'proof-of-delivery signed',
            spark: _dailySpark(podStamps),
            tone: ProfileTone.blue,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('POD-signed metric unavailable: $e');
        }

        try {
          var km = 0.0;
          if (vids.isNotEmpty) {
            final fixes = _rows(await _db
                .from('vehicle_positions')
                .select('vehicle_id, lat, lng, recorded_at')
                .inFilter('vehicle_id', vids.toList())
                .gte('recorded_at', today)
                .order('recorded_at', ascending: true)
                .limit(2000));
            final byVehicle = <String, List<Map<String, dynamic>>>{};
            for (final f in fixes) {
              byVehicle.putIfAbsent(f['vehicle_id'] as String, () => []).add(f);
            }
            for (final list in byVehicle.values) {
              for (var i = 1; i < list.length; i++) {
                final a = list[i - 1], c = list[i];
                final la = (a['lat'] as num?)?.toDouble(),
                    lo = (a['lng'] as num?)?.toDouble(),
                    lc = (c['lat'] as num?)?.toDouble(),
                    lz = (c['lng'] as num?)?.toDouble();
                if (la == null || lo == null || lc == null || lz == null) {
                  continue;
                }
                final d = _haversineKm(la, lo, lc, lz);
                if (d < 50) km += d; // drop GPS teleports
              }
            }
          }
          out.add(ProfileMetric(
            label: 'DISTANCE',
            value: km.round().toString(),
            unit: ' km',
            sub: 'covered today · live GPS',
            // No daily history for this snapshot count (P8-28).
            spark: const [],
            tone: ProfileTone.green,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('DISTANCE metric unavailable: $e');
        }

      case ProfileRoleKey.fleet:
        try {
          final fleet = _rows(await _db
              .from('fleet_vehicles')
              .select('id, is_active')
              .eq('company_id', cid));
          final active = fleet.where((v) => v['is_active'] != false).length;
          out.add(ProfileMetric(
            label: 'TRUCKS MANAGED',
            value: '$active',
            sub: 'in your fleet',
            // Snapshot count — no daily series exists (P8-28).
            spark: const [],
            tone: ProfileTone.blue,
          ));
          final vids = [for (final v in fleet) v['id'] as String];
          if (vids.isNotEmpty) {
            final trips = _rows(await _db
                .from('trips')
                .select('id, status, created_at, left_at, completed_at, offloaded_at')
                .inFilter('vehicle_id', vids)
                .gte('created_at', weekAgo));
            out.add(counted(
              label: 'DISPATCHED',
              stamps: [for (final t in trips) _ts(t['created_at'])],
              sub: 'trips today',
              tone: ProfileTone.green,
            ));
            final inService = trips
                .where((t) =>
                    t['status'] != 'completed' &&
                    t['status'] != 'cancelled' &&
                    t['left_at'] != null &&
                    t['offloaded_at'] == null)
                .length;
            out.add(ProfileMetric(
              label: 'IN SERVICE',
              value: '$inService',
              sub: 'on the road now',
              // Snapshot count — no daily series exists (P8-28).
              spark: const [],
              tone: ProfileTone.green,
            ));
          }
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('IN SERVICE metric unavailable: $e');
        }

      case ProfileRoleKey.procure:
        try {
          final reqs = _rows(await _db
              .from('transportation_requests')
              .select('id, status, created_at')
              .eq('buyer_company_id', cid)
              .gte('created_at', monthStart));
          out.add(ProfileMetric(
            label: 'REQUESTS',
            value: '${reqs.length}',
            sub: 'raised this month',
            delta: _sparkDelta(
                _dailySpark([for (final r in reqs) _ts(r['created_at'])])),
            spark: _dailySpark([for (final r in reqs) _ts(r['created_at'])]),
            tone: ProfileTone.green,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('REQUESTS metric unavailable: $e');
        }
        try {
          final recons = _rows(await _db
              .from('recon_disputes')
              .select('id, resolved_at, created_at')
              .eq('raised_by_company_id', cid));
          final closed =
              recons.where((r) => r['resolved_at'] != null).toList();
          final open = recons.length - closed.length;
          out.add(ProfileMetric(
            label: 'RECONS CLOSED',
            value: '${closed.length}',
            sub: 'all time',
            spark: _dailySpark([for (final r in closed) _ts(r['resolved_at'])]),
            tone: ProfileTone.blue,
          ));
          out.add(ProfileMetric(
            label: 'OPEN RECONS',
            value: '$open',
            sub: open > 0 ? 'awaiting match' : 'all cleared',
            spark: _dailySpark([
              for (final r in recons)
                if (r['resolved_at'] == null) _ts(r['created_at'])
            ]),
            tone: ProfileTone.amber,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('open-recon metric unavailable: $e');
        }

      case ProfileRoleKey.superv:
        try {
          final crew = _rows(await _db
              .from('employees')
              .select('id, role, is_dismissed')
              .eq('company_id', cid));
          final floor = crew
              .where((m) =>
                  m['is_dismissed'] != true &&
                  const {'security', 'controllerWB', 'supervisorForeman', 'driver'}
                      .contains(m['role']))
              .length;
          out.add(ProfileMetric(
            label: 'CREW ON SHIFT',
            value: '$floor',
            sub: 'floor crew registered',
            // Snapshot count — no daily series exists (P8-28).
            spark: const [],
            tone: ProfileTone.blue,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('CREW ON SHIFT metric unavailable: $e');
        }
        try {
          final tx = _rows(await _db
              .from('stockpile_transactions')
              .select('id, at')
              .eq('created_by', uid)
              .gte('at', weekAgo));
          out.add(counted(
            label: 'SIGN-OFFS',
            stamps: [for (final t in tx) _ts(t['at'])],
            sub: 'stockpile movements today',
            tone: ProfileTone.green,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('SIGN-OFFS metric unavailable: $e');
        }
        try {
          final inc = _rows(await _db
              .from('security_incidents')
              .select('id, occurred_at')
              .eq('company_id', cid)
              .gte('occurred_at', weekAgo));
          out.add(counted(
            label: 'INCIDENTS',
            stamps: [for (final i in inc) _ts(i['occurred_at'])],
            sub: '0 = clean shift',
            tone: ProfileTone.amber,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('INCIDENTS metric unavailable: $e');
        }

      case ProfileRoleKey.load:
        try {
          final recs = _rows(await _db
              .from('weighbridge_records')
              .select('id, net_weight, recorded_at')
              .eq('recorded_by', uid)
              .gte('recorded_at', weekAgo));
          final todayRecs = recs
              .where((r) =>
                  (_ts(r['recorded_at']) ?? DateTime(2000))
                      .isAfter(MlTime.toServer(_dayStart())))
              .toList();
          out.add(counted(
            label: 'LOADS LOGGED',
            stamps: [for (final r in recs) _ts(r['recorded_at'])],
            sub: 'weekly total ${recs.length}',
            tone: ProfileTone.green,
          ));
          final weights = [
            for (final r in todayRecs.isEmpty ? recs : todayRecs)
              (r['net_weight'] as num?)?.toDouble()
          ].whereType<double>().toList();
          final avg = weights.isEmpty
              ? null
              : weights.reduce((a, b) => a + b) / weights.length;
          out.add(ProfileMetric(
            label: 'AVG TONS / LOAD',
            value: avg == null ? '—' : avg.toStringAsFixed(1),
            unit: avg == null ? '' : ' t',
            sub: weights.isEmpty
                ? 'no weighs yet'
                : 'best ${weights.reduce(math.max).toStringAsFixed(1)}t',
            spark: _dailySpark([for (final r in recs) _ts(r['recorded_at'])]),
            tone: ProfileTone.blue,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('average-weigh metric unavailable: $e');
        }
        try {
          final rejects = _rows(await _db
              .from('gate_checks')
              .select('id, checked_at, gate_status')
              .eq('company_id', cid)
              .neq('gate_status', 'cleared')
              .gte('checked_at', weekAgo));
          out.add(counted(
            label: 'ERRORS / REJECTS',
            stamps: [for (final r in rejects) _ts(r['checked_at'])],
            sub: rejects.isEmpty ? 'clean streak' : 'gate rejects this week',
            tone: rejects.isEmpty ? ProfileTone.amber : ProfileTone.red,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('ERRORS / REJECTS metric unavailable: $e');
        }

      case ProfileRoleKey.security:
        try {
          final checks = _rows(await _db
              .from('gate_checks')
              .select('id, checked_at, gate_status, check_type')
              .eq('checked_by', uid)
              .gte('checked_at', weekAgo));
          out.add(counted(
            label: 'GATE CHECKS',
            stamps: [for (final c in checks) _ts(c['checked_at'])],
            sub: 'weekly total ${checks.length}',
            tone: ProfileTone.green,
          ));
          final cleared =
              checks.where((c) => c['gate_status'] == 'cleared').toList();
          out.add(counted(
            label: 'TRUCKS CLEARED',
            stamps: [for (final c in cleared) _ts(c['checked_at'])],
            sub: 'through gate today',
            tone: ProfileTone.blue,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('TRUCKS CLEARED metric unavailable: $e');
        }
        try {
          final flags = _rows(await _db
              .from('security_incidents')
              .select('id, occurred_at, status')
              .eq('reported_by', uid)
              .gte('occurred_at', weekAgo));
          out.add(counted(
            label: 'FLAGS RAISED',
            stamps: [for (final f in flags) _ts(f['occurred_at'])],
            sub: flags.any((f) => f['status'] != 'resolved')
                ? 'review pending'
                : 'none open',
            tone: flags.isEmpty ? ProfileTone.amber : ProfileTone.red,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('FLAGS RAISED metric unavailable: $e');
        }

      case ProfileRoleKey.admin:
      case ProfileRoleKey.other:
        try {
          final acts = _rows(await _db
              .from('notifications')
              .select('id, created_at')
              .eq('actioned_by_id', uid)
              .gte('created_at', weekAgo));
          out.add(counted(
            label: 'APPROVALS',
            stamps: [for (final a in acts) _ts(a['created_at'])],
            sub: 'actions this week · ${acts.length}',
            tone: ProfileTone.green,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('APPROVALS metric unavailable: $e');
        }
        if (b.company.seatsUsed != null) {
          out.add(ProfileMetric(
            label: 'SEATS MANAGED',
            value: '${b.company.seatsUsed}',
            sub: b.company.seatLimit != null
                ? 'of ${b.company.seatLimit} licensed seats'
                : 'active company seats',
            // Snapshot count — no daily series exists (P8-28).
            spark: const [],
            tone: ProfileTone.blue,
          ));
        }
        try {
          final ids = _rows(await _db
              .from('employees')
              .select('user_id')
              .eq('company_id', cid));
          final uids = [
            for (final m in ids)
              if (m['user_id'] != null) m['user_id'] as String
          ];
          var stamps = <DateTime?>[];
          if (uids.isNotEmpty) {
            final profs = _rows(await _db
                .from('profiles')
                .select('id, last_login_at')
                .inFilter('id', uids));
            stamps = [for (final p in profs) _ts(p['last_login_at'])];
          }
          final thirtyDays = DateTime.now().subtract(const Duration(days: 30));
          final signIns =
              stamps.whereType<DateTime>().where((s) => s.isAfter(thirtyDays));
          out.add(ProfileMetric(
            label: 'SIGN-INS',
            value: '${signIns.length}',
            sub: 'across org · 30-day',
            spark: _dailySpark(stamps),
            tone: ProfileTone.green,
          ));
        } catch (e) {
          // Best-effort section: a failed source drops this one card,
          // never the screen. Logged, never swallowed (P0-11 / S1-7).
          _log.d('SIGN-INS metric unavailable: $e');
        }
    }

    return out;
  }

  // -- last-24h activity ----------------------------------------------------

  Future<List<ProfileActivityItem>> loadActivity(
      EmployeeProfileBundle b) async {
    final e = b.person.employee;
    final uid = e.userId;
    final since = _iso(MlTime.now().subtract(const Duration(hours: 24)));
    final org = switch (b.company.orgType) {
      OrgType.mineSupplier => 'mine',
      OrgType.buyer => 'buyer',
      OrgType.transporter => 'transporter',
    };
    final items = <ProfileActivityItem>[];

    final login = b.person.lastLoginAt;
    if (login != null &&
        DateTime.now().difference(login) < const Duration(hours: 24)) {
      items.add(ProfileActivityItem(
        bold: 'Signed in',
        rest: b.person.whatsappOnly ? ' · WhatsApp number' : ' · web',
        at: login,
        tone: ProfileTone.green,
      ));
    }

    try {
      final checks = _rows(await _db
          .from('gate_checks')
          .select('checked_at, check_type, gate_status')
          .eq('checked_by', uid)
          .gte('checked_at', since)
          .order('checked_at', ascending: false)
          .limit(6));
      for (final c in checks) {
        final at = _ts(c['checked_at']);
        if (at == null) continue;
        final cleared = c['gate_status'] == 'cleared';
        items.add(ProfileActivityItem(
          bold: 'Gate check',
          rest:
              ' · ${c['check_type'] ?? 'entry'} · ${cleared ? 'cleared' : c['gate_status'] ?? 'flagged'}',
          at: at,
          tone: cleared ? ProfileTone.green : ProfileTone.red,
          route: '/portal/mine/security',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('gate-check activity unavailable: $e');
    }

    try {
      final recs = _rows(await _db
          .from('weighbridge_records')
          .select('recorded_at, net_weight, direction')
          .eq('recorded_by', uid)
          .gte('recorded_at', since)
          .order('recorded_at', ascending: false)
          .limit(6));
      for (final r in recs) {
        final at = _ts(r['recorded_at']);
        if (at == null) continue;
        final net = (r['net_weight'] as num?)?.toDouble();
        items.add(ProfileActivityItem(
          bold: 'Load logged',
          rest: net != null ? ' · ${net.toStringAsFixed(1)}t' : '',
          at: at,
          tone: ProfileTone.blue,
          route: '/portal/mine/weighbridge',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('load-logged activity unavailable: $e');
    }

    try {
      final tx = _rows(await _db
          .from('stockpile_transactions')
          .select('at, type, delta_tons, truck_reg')
          .eq('created_by', uid)
          .gte('at', since)
          .order('at', ascending: false)
          .limit(6));
      for (final t in tx) {
        final at = _ts(t['at']);
        if (at == null) continue;
        final delta = (t['delta_tons'] as num?)?.toDouble();
        items.add(ProfileActivityItem(
          bold: 'Stockpile ${t['type'] ?? 'movement'}',
          rest: [
            if (delta != null) ' · ${delta.toStringAsFixed(1)}t',
            if (t['truck_reg'] != null) ' · ${t['truck_reg']}',
          ].join(),
          at: at,
          tone: ProfileTone.blue,
          route: '/portal/mine/stockpiles',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('stockpile-movement activity unavailable: $e');
    }

    try {
      final pods = _rows(await _db
          .from('pod_uploads')
          .select('uploaded_at, delivered_tons')
          .eq('uploaded_by', uid)
          .gte('uploaded_at', since)
          .order('uploaded_at', ascending: false)
          .limit(4));
      for (final p in pods) {
        final at = _ts(p['uploaded_at']);
        if (at == null) continue;
        final tons = (p['delivered_tons'] as num?)?.toDouble();
        items.add(ProfileActivityItem(
          bold: 'POD uploaded',
          rest: tons != null ? ' · ${tons.toStringAsFixed(1)}t delivered' : '',
          at: at,
          tone: ProfileTone.green,
          route: '/portal/$org/trips',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('POD-uploaded activity unavailable: $e');
    }

    if (b.roleKey == ProfileRoleKey.driver) {
      try {
        final vids = <String>{};
        for (final a in _rows(await _db
            .from('driver_assignments')
            .select('vehicle_id')
            .eq('driver_employee_id', e.id))) {
          final v = a['vehicle_id'] as String?;
          if (v != null) vids.add(v);
        }
        if (vids.isNotEmpty) {
          final trips = _rows(await _db
              .from('trips')
              .select('arrived_at, loaded_at, left_at, offloaded_at, completed_at, status')
              .inFilter('vehicle_id', vids.toList())
              .gte('updated_at', since)
              .limit(6));
          for (final t in trips) {
            for (final (col, label, tone) in [
              ('arrived_at', 'Arrived at mine', ProfileTone.blue),
              ('loaded_at', 'Loaded', ProfileTone.blue),
              ('left_at', 'Departed mine', ProfileTone.green),
              ('offloaded_at', 'Offloaded', ProfileTone.green),
              ('completed_at', 'Trip completed', ProfileTone.green),
            ]) {
              final at = _ts(t[col]);
              if (at != null &&
                  DateTime.now().difference(at) < const Duration(hours: 24)) {
                items.add(ProfileActivityItem(
                  bold: label,
                  rest: '',
                  at: at,
                  tone: tone,
                  route: '/portal/transporter/trips',
                ));
              }
            }
          }
        }
      } catch (e) {
        // Best-effort section: a failed source drops this one card,
        // never the screen. Logged, never swallowed (P0-11 / S1-7).
        _log.d('trip activity unavailable: $e');
      }
    }

    try {
      final acts = _rows(await _db
          .from('notifications')
          .select('created_at, title')
          .eq('actioned_by_id', uid)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(4));
      for (final a in acts) {
        final at = _ts(a['created_at']);
        if (at == null) continue;
        items.add(ProfileActivityItem(
          bold: 'Actioned',
          rest: ' · ${a['title'] ?? 'notification'}',
          at: at,
          tone: ProfileTone.blue,
          route: '/portal/$org/notifications',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('notification activity unavailable: $e');
    }

    try {
      final reqs = _rows(await _db
          .from('transportation_requests')
          .select('created_at, commodity, status')
          .eq('created_by', uid)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(4));
      for (final r in reqs) {
        final at = _ts(r['created_at']);
        if (at == null) continue;
        items.add(ProfileActivityItem(
          bold: 'Request raised',
          rest: r['commodity'] != null ? ' · ${r['commodity']}' : '',
          at: at,
          tone: ProfileTone.blue,
          route: '/portal/buyer/requests',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('request-raised activity unavailable: $e');
    }

    try {
      final res = _rows(await _db
          .from('recon_disputes')
          .select('resolved_at, category')
          .eq('resolved_by_user_id', uid)
          .gte('resolved_at', since)
          .limit(4));
      for (final r in res) {
        final at = _ts(r['resolved_at']);
        if (at == null) continue;
        items.add(ProfileActivityItem(
          bold: 'Recon resolved',
          rest: r['category'] != null ? ' · ${r['category']}' : '',
          at: at,
          tone: ProfileTone.green,
          route: '/portal/$org/reconciliations',
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('recon-resolved activity unavailable: $e');
    }

    try {
      final msgs = _rows(await _db
          .from('chat_messages')
          .select('id')
          .eq('sender_id', uid)
          .gte('timestamp', since)
          .limit(200));
      if (msgs.isNotEmpty) {
        items.add(ProfileActivityItem(
          bold: '${msgs.length} message${msgs.length == 1 ? '' : 's'} sent',
          rest: ' · in-app chat',
          at: DateTime.now(),
          isNow: true,
          tone: ProfileTone.blue,
        ));
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('chat-message activity unavailable: $e');
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(12).toList();
  }

  // -- documents + flags ----------------------------------------------------

  Future<ProfileDocsAndFlags> loadDocsAndFlags(EmployeeProfileBundle b) async {
    final e = b.person.employee;
    final docs = <ProfileDocItem>[];
    final flags = <ProfileFlag>[];

    String fmtMonth(DateTime? d) => d == null
        ? ''
        : '${const [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ][d.month - 1]} ${d.year}';

    // Legacy fixed-slot documents (already signed URLs via the bundle).
    for (final (title, url) in [
      ('ID document', e.idDocumentUrl),
      ('Passport', e.passportDocumentUrl),
      ('Work visa', e.workVisaDocumentUrl),
      ("Driver's licence", e.licenseDocumentUrl),
    ]) {
      if (url == null || url.isEmpty) continue;
      docs.add(ProfileDocItem(
        title: title,
        subtitle: 'uploaded ${fmtMonth(e.createdAt)}',
        statusLabel: 'Verified',
        statusTone: ProfileTone.green,
        directUrl: url,
      ));
    }

    // Compliance documents (expiry-tracked).
    try {
      final all = await ComplianceService().list(b.company.id);
      for (final d in all) {
        if (d.ownerType != ComplianceOwnerType.employee || d.ownerId != e.id) {
          continue;
        }
        final days = d.daysToExpiry;
        String status;
        ProfileTone tone;
        switch (d.status) {
          case ComplianceStatus.expired:
            status = 'Expired';
            tone = ProfileTone.red;
          case ComplianceStatus.expiring:
            status = days != null ? 'Expires ${days}d' : 'Expiring soon';
            tone = ProfileTone.amber;
          case ComplianceStatus.valid:
            status = days != null && days > 60
                ? 'Expires ${(days / 30).round()} mo'
                : 'Valid';
            tone = days != null && days > 60
                ? ProfileTone.amber
                : ProfileTone.green;
          case ComplianceStatus.noExpiry:
            status = 'Verified';
            tone = ProfileTone.green;
        }
        docs.add(ProfileDocItem(
          title: d.displayTitle,
          subtitle: d.issuedAt != null
              ? 'renewed ${fmtMonth(d.issuedAt)}'
              : 'added ${fmtMonth(d.createdAt)}',
          statusLabel: status,
          statusTone: tone,
          compliancePath: d.filePath,
        ));

        // Live notes & flags from real expiry state.
        if (d.status == ComplianceStatus.expired) {
          flags.add(ProfileFlag(
            title: '${d.displayTitle} expired',
            body:
                '${e.firstName}\'s ${d.displayTitle.toLowerCase()} has expired'
                '${d.expiresAt != null ? ' on ${fmtMonth(d.expiresAt)}' : ''}. '
                'Upload a renewed copy in Documents before the next roster.',
            metaLine: 'Opened by System · live compliance check',
            tone: ProfileTone.red,
          ));
        } else if (d.status == ComplianceStatus.expiring) {
          flags.add(ProfileFlag(
            title: '${d.displayTitle} renewal window',
            body:
                '${d.displayTitle} expires in ${mlCountText(days ?? '—', 'day')}. Keep the '
                'renewed copy current in Documents before the window closes.',
            metaLine: 'Opened by System · live compliance check',
            tone: ProfileTone.amber,
          ));
        }
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('compliance document flags unavailable: $e');
    }

    // A dismissal flag used to lead this list. It went with the feature (client
    // ruling, 2026-08-11) — someone taken off a company is unlinked by
    // `remove_company_employee`, so there is no profile here to flag.
    if (e.status == 'pending_company' || e.status == 'pending_role') {
      flags.add(ProfileFlag(
        title: e.status == 'pending_company'
            ? 'Awaiting company approval'
            : 'Awaiting role assignment',
        body: e.status == 'pending_company'
            ? 'This person asked to join and is waiting to be accepted.'
            : 'Accepted, but locked out until a role is assigned.',
        metaLine: 'Live account state',
        tone: ProfileTone.amber,
      ));
    }

    return ProfileDocsAndFlags(docs, flags);
  }

  /// Signs a compliance-doc storage path on demand (view/download tap).
  Future<String?> resolveComplianceUrl(String path) =>
      ComplianceService().resolveFileUrl(path);

  // -- location -------------------------------------------------------------

  /// Real location context: mine → first active mine location (lat/lng);
  /// driver → latest GPS fix of an assigned vehicle. Falls back to nulls
  /// (the UI then shows the head-office label without coordinates).
  Future<({String? name, double? lat, double? lng, DateTime? at})>
      loadLocation(EmployeeProfileBundle b) async {
    final e = b.person.employee;
    try {
      if (b.roleKey == ProfileRoleKey.driver) {
        final vids = <String>[];
        for (final a in _rows(await _db
            .from('driver_assignments')
            .select('vehicle_id')
            .eq('driver_employee_id', e.id))) {
          final v = a['vehicle_id'] as String?;
          if (v != null) vids.add(v);
        }
        if (vids.isNotEmpty) {
          final fixes = _rows(await _db
              .from('vehicle_positions')
              .select('lat, lng, recorded_at')
              .inFilter('vehicle_id', vids)
              .order('recorded_at', ascending: false)
              .limit(1));
          if (fixes.isNotEmpty) {
            final f = fixes.first;
            return (
              name: 'On route',
              lat: (f['lat'] as num?)?.toDouble(),
              lng: (f['lng'] as num?)?.toDouble(),
              at: _ts(f['recorded_at']),
            );
          }
        }
      }
      if (b.company.orgType == OrgType.mineSupplier) {
        final locs = _rows(await _db
            .from('mine_locations')
            .select('name, latitude, longitude, is_active')
            .eq('mine_company_id', b.company.id)
            .eq('is_active', true)
            .limit(1));
        if (locs.isNotEmpty) {
          final l = locs.first;
          return (
            name: (l['name'] as String?) ?? 'Mine site',
            lat: (l['latitude'] as num?)?.toDouble(),
            lng: (l['longitude'] as num?)?.toDouble(),
            at: null,
          );
        }
      }
    } catch (e) {
      // Best-effort section: a failed source drops this one card,
      // never the screen. Logged, never swallowed (P0-11 / S1-7).
      _log.d('mine site location unavailable: $e');
    }
    return (name: null, lat: null, lng: null, at: null);
  }
}

import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';

/// Which set of targets is being looked at.
///
/// The same two tables carry all three, keyed by scope — see
/// `supabase/migrations/20260808120000_targets_and_cycles.sql`. The wire
/// strings are persistence keys; renaming one needs a migration.
enum TargetScopeKind {
  platform('platform'),
  orgType('org_type'),
  company('company');

  const TargetScopeKind(this.wire);

  final String wire;

  static TargetScopeKind parse(String? raw) => TargetScopeKind.values.firstWhere(
        (k) => k.wire == raw,
        orElse: () => TargetScopeKind.platform,
      );
}

/// A scope key. Value-equal so it can be a Riverpod family argument without
/// re-subscribing on every rebuild.
@immutable
class TargetScope {
  const TargetScope._(this.kind, this.orgType, this.companyId);

  /// The whole network, one set of targets.
  static const TargetScope platform =
      TargetScope._(TargetScopeKind.platform, null, null);

  /// One set per org type — `mineSupplier`, `buyer` or `transporter`.
  const TargetScope.orgType(String orgType)
      : this._(TargetScopeKind.orgType, orgType, null);

  /// One set for a single company.
  const TargetScope.company(String companyId)
      : this._(TargetScopeKind.company, null, companyId);

  final TargetScopeKind kind;
  final String? orgType;
  final String? companyId;

  bool get isPlatform => kind == TargetScopeKind.platform;
  bool get isOrgType => kind == TargetScopeKind.orgType;
  bool get isCompany => kind == TargetScopeKind.company;

  /// Arguments as the RPCs take them.
  Map<String, dynamic> get rpcArgs => <String, dynamic>{
        'p_scope': kind.wire,
        'p_org_type': orgType,
        'p_company_id': companyId,
      };

  @override
  bool operator ==(Object other) =>
      other is TargetScope &&
      other.kind == kind &&
      other.orgType == orgType &&
      other.companyId == companyId;

  @override
  int get hashCode => Object.hash(kind, orgType, companyId);

  @override
  String toString() => switch (kind) {
        TargetScopeKind.platform => 'platform',
        TargetScopeKind.orgType => 'org_type:$orgType',
        TargetScopeKind.company => 'company:$companyId',
      };
}

/// Turns the `get_targets_state` payload into the shape the screen wants.
///
/// Kept free of Flutter and Supabase so a test can hand it a literal map — see
/// `test/widgets/targets_payload_test.dart`.
class TargetsPayload {
  const TargetsPayload._();

  static MlTargetsData parse(Map<String, dynamic> json) => MlTargetsData(
        months: _months(json['months']),
        cycle: _cycle(json['cycle']),
        pastCycles: _pastCycles(json['past_cycles']),
        // The server's `current_date`, not the browser's clock. Elapsed cycle
        // days, every horizon checkpoint and the reopen date are all computed
        // from this, and the Postgres trigger computes its half from
        // `current_date` too — so a device with a wrong clock or a different
        // timezone cannot disagree with the guard about when a cycle reopens.
        asOf: _date(json['as_of']),
      );

  static List<MlMonthTarget> _months(Object? raw) {
    if (raw is! List) return const <MlMonthTarget>[];
    return raw.whereType<Map>().map((m) {
      return MlMonthTarget(
        year: _int(m['year']),
        month: _int(m['month']),
        daysInMonth: _int(m['days_in_month']),
        // One entry per elapsed calendar day, zeros included. An empty list is
        // what makes a month "planned" — do not filter the zeros out.
        daily: _doubles(m['daily']),
        target: _double(m['target']),
        trips: _int(m['trips']),
        waybillsDone: _int(m['waybills_done']),
        waybillsOpen: _int(m['waybills_open']),
      );
    }).toList(growable: false);
  }

  static MlCycle _cycle(Object? raw) {
    final m = raw is Map ? raw : const <String, dynamic>{};
    return MlCycle(
      // For a scope with no cycle row yet the server synthesises one rather
      // than minting it — reads do not write — and hands back a stable
      // `draft:<scope>` id so the widget tree still has something to key on.
      id: '${m['id'] ?? ''}',
      label: '${m['label'] ?? ''}',
      status: switch (m['status']) {
        'draft' => MlCycleStatus.draft,
        'closed' => MlCycleStatus.closed,
        // Anything unrecognised fails closed. Never hand the user an editable
        // dial over a committed cycle because a status string drifted.
        _ => MlCycleStatus.locked,
      },
      targets: _tonMap(m['targets']),
      draft: _tonMap(m['draft']),
      // Null until the cycle is locked. A draft has not started, so it shows
      // no elapsed days and every horizon reads pending.
      startedOn: _date(m['started_on']),
      lockedAt: _date(m['locked_at']),
    );
  }

  static List<MlArchivedCycle> _pastCycles(Object? raw) {
    if (raw is! List) return const <MlArchivedCycle>[];
    return raw
        .whereType<Map>()
        .map((c) => MlArchivedCycle(
              id: '${c['id'] ?? ''}',
              label: '${c['label'] ?? ''}',
              targets: _tonMap(c['targets']),
              actuals: _tonMap(c['actuals']),
            ))
        .toList(growable: false);
  }

  static Map<String, double> _tonMap(Object? raw) {
    if (raw is! Map) return const <String, double>{};
    final out = <String, double>{};
    raw.forEach((k, v) {
      final d = _nullableDouble(v);
      if (d != null) out['$k'] = d;
    });
    return out;
  }

  static List<double> _doubles(Object? raw) {
    if (raw is! List) return const <double>[];
    return raw.map(_double).toList(growable: false);
  }

  static int _int(Object? v) => switch (v) {
        int i => i,
        num n => n.round(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      };

  static double _double(Object? v) => _nullableDouble(v) ?? 0;

  static double? _nullableDouble(Object? v) => switch (v) {
        num n => n.toDouble(),
        // Postgres numeric arrives as a string through PostgREST once it is
        // wide enough to lose precision in a JS double.
        String s => double.tryParse(s),
        _ => null,
      };

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}

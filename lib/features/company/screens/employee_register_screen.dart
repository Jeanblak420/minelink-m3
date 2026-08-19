import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/theme/theme_mode_provider.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/chat/providers/chat_presence_provider.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/services/employee_register_service.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The register's palette, resolved from the design tokens (P7-28).
///
/// It used to be a hardcoded control-room navy, which was defensible while the
/// screen was super-admin-only — the console chrome is permanently dark. Now
/// that every company opens the same screen inside the portal it has to follow
/// the portal's light/dark themes, so every slot resolves through
/// [MlSemantic] / [MlTone]. The console keeps its navy by passing its own
/// palette in, not by the screen hardcoding one.
class _Pal {
  const _Pal(this._s, this._b);

  factory _Pal.of(
    BuildContext context, {
    MlSemantic? palette,
    Brightness? brightness,
  }) =>
      _Pal(
        palette ?? MlSemantic.of(context),
        brightness ?? Theme.of(context).brightness,
      );

  final MlSemantic _s;
  final Brightness _b;

  Color get pageBg => _s.surfaceApp;
  Color get surfaceCard => _s.surfaceCard;

  /// The tile sits *inside* a card, so it has to separate from it in both
  /// themes: raised above the card in dark, sunken into it in light. A single
  /// slot either way would be invisible in one of them.
  Color get surfaceTile =>
      _b == Brightness.dark ? _s.surfaceRaised : _s.surfaceSunken;

  Color get borderCard => _s.borderCard;
  Color get textStrong => _s.textStrong;
  Color get textMuted => _s.textMuted;

  Color get blue => tone(MlTone.transit);
  Color get green => tone(MlTone.done);
  Color get amber => tone(MlTone.atMine);
  Color get red => tone(MlTone.error);

  Color tone(MlTone t) => t.colors(_b).fg;

  double get rCard => MlTokens.rLg;
  double get rTile => MlTokens.rMd;
}

/// How recently someone must have been seen (while not in the live presence
/// set) to count as "Away" rather than "Offline".
const _awayWindow = Duration(minutes: 30);

enum _Presence { online, away, offline }

/// Role buckets, in display order. A member lands in the first bucket that
/// contains their role; unknown/absent roles fall through to "Other".
class _RoleGroup {
  final String title;
  final String description;
  final IconData icon;
  final MlTone tone;
  final Set<UserRole> roles;
  const _RoleGroup(
    this.title,
    this.description,
    this.icon,
    this.tone,
    this.roles,
  );
}

const _groups = <_RoleGroup>[
  _RoleGroup(
    RegisterRoleGroups.admins,
    'Full company administration — users, permissions and day-to-day '
        'operations.',
    Icons.business_center_outlined,
    MlTone.done,
    {UserRole.admin, UserRole.management},
  ),
  _RoleGroup(
    RegisterRoleGroups.supervisors,
    'Stockpile and production supervision on the mine floor.',
    Icons.engineering_outlined,
    MlTone.atMine,
    {UserRole.supervisorForeman},
  ),
  _RoleGroup(
    RegisterRoleGroups.loadControllers,
    'Weighbridge capture — tare and gross weighs, seals and waybill slips.',
    Icons.scale_outlined,
    MlTone.transit,
    {UserRole.controllerWB},
  ),
  _RoleGroup(
    RegisterRoleGroups.security,
    'Gate control — truck check-in and check-out.',
    Icons.shield_outlined,
    MlTone.transit,
    {UserRole.security},
  ),
  _RoleGroup(
    RegisterRoleGroups.drivers,
    'Trips, POD upload & routes (mobile). Sign in with WhatsApp number.',
    Icons.local_shipping_outlined,
    MlTone.done,
    {UserRole.driver},
  ),
];

const _otherGroup = _RoleGroup(
  'Other roles',
  'Registered under this company without a floor role.',
  Icons.badge_outlined,
  MlTone.neutral,
  {},
);

const _azGroup = _RoleGroup(
  'All staff · A–Z',
  'Every registered user under this company, alphabetically.',
  Icons.sort_by_alpha_rounded,
  MlTone.transit,
  {},
);

String _rolePrefix(UserRole? role) => switch (role) {
  UserRole.admin => 'ADM',
  UserRole.management => 'MGT',
  UserRole.controllerWB => 'LC',
  UserRole.supervisorForeman => 'SUP',
  UserRole.security => 'SEC',
  UserRole.driver => 'DRV',
  _ => 'EMP',
};

/// Live view of one company's registered users (P7-27).
///
/// Read-only, and the same screen for everybody: the super-admin console opens
/// it for any company it is mirroring, and each company opens it for itself at
/// `/portal/{org}/register`. Presence is genuinely live — the realtime
/// `online-users` channel drives Online, and the `profiles.last_seen_at`
/// heartbeat (via `list_company_member_presence`, never `profiles` directly)
/// separates Away from Offline.
class EmployeeRegisterScreen extends ConsumerStatefulWidget {
  const EmployeeRegisterScreen({
    super.key,
    required this.company,
    this.palette,
    this.brightness,
    this.embedded = false,
  });

  final Company company;

  /// Console override — the super-admin chrome is permanently dark navy, so it
  /// hands the screen its own palette rather than the screen assuming one.
  final MlSemantic? palette;
  final Brightness? brightness;

  /// `true` inside the portal shell, which supplies its own app bar, rail and
  /// scaffold: the screen then renders as a scroll body with no top bar.
  final bool embedded;

  @override
  ConsumerState<EmployeeRegisterScreen> createState() =>
      _EmployeeRegisterScreenState();
}

class _EmployeeRegisterScreenState
    extends ConsumerState<EmployeeRegisterScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _byRole = true; // false = A–Z flat list
  _Presence? _statusFilter; // null = all
  UserRole? _roleFilter; // null = all

  /// Presence counts when the screen first got data — drives the little
  /// session-delta arrows on the stat strip (▲2 = two more online than when
  /// you opened the register).
  Map<_Presence, int>? _baseline;
  DateTime? _loadedAt;
  Timer? _tick;

  /// Assigned once per build, before any of the section builders run.
  late _Pal _p;

  @override
  void initState() {
    super.initState();
    // Refresh the relative "Synced Xs ago" + last-seen labels.
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  _Presence _presenceOf(
    RegisterMember m,
    Set<String> online,
    DateTime? liveStamp,
  ) {
    if (online.contains(m.employee.userId)) return _Presence.online;
    final seen = _bestLastSeen(m, liveStamp);
    if (seen != null && DateTime.now().difference(seen) <= _awayWindow) {
      return _Presence.away;
    }
    return _Presence.offline;
  }

  DateTime? _bestLastSeen(RegisterMember m, DateTime? liveStamp) {
    final db = m.lastSeenAt;
    if (liveStamp == null) return db;
    if (db == null) return liveStamp;
    return liveStamp.isAfter(db) ? liveStamp : db;
  }

  String get _syncedLabel {
    final t = _loadedAt;
    if (t == null) return 'Live';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Live · Synced ${d.inSeconds}s ago';
    if (d.inMinutes < 60) return 'Live · Synced ${d.inMinutes}m ago';
    return 'Live · Synced ${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    _p = _Pal.of(
      context,
      palette: widget.palette,
      brightness: widget.brightness,
    );
    final company = widget.company;
    final membersAsync = ref.watch(companyRegisterProvider(company.id));
    final online = ref.watch(onlineUsersProvider);
    final liveStamps = ref.watch(presenceLastSeenProvider);
    final trucks =
        ref.watch(companyDriverTrucksProvider(company.id)).valueOrNull ??
            const <String, String>{};
    final kpis = ref
        .watch(
          companyRegisterKpisProvider((id: company.id, org: company.orgType)),
        )
        .valueOrNull;

    final body = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _searchFocus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MlEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load the employee register',
            // A denial from `list_company_member_presence` lands here rather
            // than rendering a full roster with everybody offline.
            message: friendlyError(e),
            action: MlButton.tonal(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(companyRegisterProvider(company.id)),
            ),
          ),
          data: (members) {
            _loadedAt ??= DateTime.now();
            final byPresence = <_Presence, int>{};
            for (final m in members) {
              final p = _presenceOf(m, online, liveStamps[m.employee.userId]);
              byPresence[p] = (byPresence[p] ?? 0) + 1;
            }
            _baseline ??= Map.of(byPresence);
            final roles = {
              for (final m in members)
                if (m.employee.role != null) m.employee.role,
            };

            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1080;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.embedded) ...[
                      _topBar(context),
                      const SizedBox(height: 26),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _hero(company)),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 460,
                            child: _statsCard(
                              members.length,
                              byPresence,
                              roles.length,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _hero(company),
                      const SizedBox(height: 16),
                      _statsCard(members.length, byPresence, roles.length),
                    ],
                    const SizedBox(height: 22),
                    _controls(members),
                    const SizedBox(height: 22),
                    ..._sections(
                      company,
                      members,
                      online,
                      liveStamps,
                      trucks,
                      kpis,
                      c.maxWidth,
                    ),
                  ],
                );

                if (widget.embedded) return MlPageBody(child: content);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: content,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(backgroundColor: _p.pageBg, body: body);
  }

  // ---- header chrome ----

  Widget _iconTile(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _p.surfaceCard,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(color: _p.borderCard),
          ),
          child: Icon(icon, size: 18, color: _p.textStrong),
        ),
      ),
    );
  }

  /// The console's own chrome: breadcrumb on the left, controls on the right.
  ///
  /// Laid out as two clusters that can drop onto separate lines rather than one
  /// `Row` of eight children. As a single row it overflowed by 183 px at 430 px
  /// — the trailing controls are ~310 px of fixed furniture, and a `Spacer`
  /// cannot take away what the breadcrumb has already claimed. Found by the
  /// width × text-scale sweep; it was there the whole time this screen was
  /// console-only, because nothing ever rendered it narrow.
  Widget _topBar(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    final breadcrumb = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _p.surfaceCard,
              borderRadius: BorderRadius.circular(MlTokens.rMd),
              border: Border.all(color: _p.borderCard),
            ),
            child: Icon(Icons.arrow_back, size: 19, color: _p.textStrong),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            'EMPLOYEES',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: _p.textMuted,
            ),
          ),
        ),
        Text('  /  ', style: TextStyle(fontSize: 12, color: _p.textMuted)),
        Flexible(
          child: Text(
            'EMPLOYEE REGISTER',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: _p.textStrong,
            ),
          ),
        ),
      ],
    );

    final controls = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _iconTile(
          themeMode == ThemeMode.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          'Toggle app theme',
          () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        _iconTile(
          Icons.notifications_none_rounded,
          'Notifications',
          () => context.push('/super-admin/notifications'),
        ),
        _syncPill(),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [breadcrumb, const SizedBox(height: 12), controls],
          );
        }
        return Row(
          children: [
            Expanded(child: breadcrumb),
            const SizedBox(width: 12),
            // Never an unflexed `Wrap` in a `Row` — it is laid out against
            // unbounded width and pushes the row over (CLAUDE.md §10.4).
            Flexible(child: controls),
          ],
        );
      },
    );
  }

  Widget _syncPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _p.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: Border.all(color: _p.green.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _p.green,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _syncedLabel,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _p.green,
              ),
            ),
          ],
        ),
      );

  Widget _hero(Company company) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 26, height: 2, color: _p.blue),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${company.companyName.toUpperCase()} · DIRECTORY',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 12.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: _p.blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: MlTokens.fontSerif,
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w500,
              color: _p.textStrong,
            ),
            children: [
              const TextSpan(text: 'Employee '),
              TextSpan(
                text: 'Register',
                style: TextStyle(fontStyle: FontStyle.italic, color: _p.blue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 13.5,
              height: 1.55,
              color: _p.textMuted,
            ),
            children: [
              const TextSpan(
                text: 'Live Employee Register · A read-only view of each '
                    'employee/user registered under ',
              ),
              TextSpan(
                text: company.companyName,
                style: TextStyle(fontWeight: FontWeight.w800, color: _p.blue),
              ),
              const TextSpan(
                text: '. Synced & updated automatically on every change and '
                    'last seen / online / away status for each member.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: _p.surfaceCard,
                borderRadius: BorderRadius.circular(MlTokens.rPill),
                border: Border.all(color: _p.borderCard),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: _p.textMuted),
                  const SizedBox(width: 7),
                  Text(
                    'Read-only',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Inside the portal the top bar is the shell's, so the freshness
            // stamp travels down here rather than being lost.
            if (widget.embedded) _syncPill(),
          ],
        ),
      ],
    );
  }

  // ---- presence stat strip ----

  Widget _statsCard(int total, Map<_Presence, int> byPresence, int roleCount) {
    final base = _baseline ?? byPresence;
    int delta(_Presence p) => (byPresence[p] ?? 0) - (base[p] ?? 0);

    Widget deltaChip(int d, {required bool goodWhenUp}) {
      if (d == 0) return const SizedBox.shrink();
      final up = d > 0;
      final good = up == goodWhenUp;
      final color = good ? _p.green : _p.red;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              size: 18,
              color: color,
            ),
            Text(
              '${d.abs()}',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    Widget cell(
      String label,
      String value, {
      Color? dotColor,
      String? sub,
      Widget? delta,
    }) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                      color: _p.textMuted,
                    ),
                  ),
                ),
                if (delta != null) delta,
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontFamily: MlTokens.fontSerif,
                fontSize: 38,
                fontWeight: FontWeight.w500,
                color: _p.textStrong,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    sub ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 11.5,
                      color: _p.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget divider() => Container(
          width: 1,
          height: 92,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: _p.borderCard,
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _p.surfaceCard,
        borderRadius: BorderRadius.circular(_p.rCard),
        border: Border.all(color: _p.borderCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(
            'Total staff',
            '$total',
            sub: 'Across $roleCount role${roleCount == 1 ? '' : 's'}',
          ),
          divider(),
          cell(
            'Online now',
            '${byPresence[_Presence.online] ?? 0}',
            dotColor: _p.green,
            sub: 'Online (active)',
            delta: deltaChip(delta(_Presence.online), goodWhenUp: true),
          ),
          divider(),
          cell(
            'Away',
            '${byPresence[_Presence.away] ?? 0}',
            dotColor: _p.amber,
            sub: 'Away (idle)',
            delta: deltaChip(delta(_Presence.away), goodWhenUp: false),
          ),
          divider(),
          cell(
            'Offline',
            '${byPresence[_Presence.offline] ?? 0}',
            dotColor: _p.red,
            sub: 'Offline',
          ),
        ],
      ),
    );
  }

  // ---- search / sort / filter controls ----

  Widget _controls(List<RegisterMember> members) {
    Widget segButton(String label, bool active, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:
                active ? _p.blue.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? _p.blue.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? _p.blue : _p.textMuted,
            ),
          ),
        ),
      );
    }

    final rolesPresent = <UserRole>{
      for (final m in members)
        if (m.employee.role != null) m.employee.role!,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _p.surfaceCard,
        borderRadius: BorderRadius.circular(_p.rCard),
        border: Border.all(color: _p.borderCard),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 13,
                color: _p.textStrong,
              ),
              cursorColor: _p.blue,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by name, role, or employee ID…',
                hintStyle: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 13,
                  color: _p.textMuted,
                ),
                prefixIcon: Icon(Icons.search, size: 18, color: _p.textMuted),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: _p.surfaceCard,
                      borderRadius: BorderRadius.circular(MlTokens.rXs),
                      border: Border.all(color: _p.borderCard),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Ctrl K',
                      style: TextStyle(
                        fontFamily: MlTokens.fontMono,
                        fontSize: 10,
                        color: _p.textMuted,
                      ),
                    ),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                filled: true,
                fillColor: _p.surfaceTile,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  borderSide: BorderSide(color: _p.borderCard),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  borderSide: BorderSide(
                    color: _p.blue.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _p.surfaceTile,
              borderRadius: BorderRadius.circular(MlTokens.rMd),
              border: Border.all(color: _p.borderCard),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                segButton(
                  'By role',
                  _byRole,
                  () => setState(() => _byRole = true),
                ),
                segButton(
                  'A–Z',
                  !_byRole,
                  () => setState(() => _byRole = false),
                ),
              ],
            ),
          ),
          PopupMenuButton<UserRole?>(
            tooltip: 'Filter by role',
            color: _p.surfaceCard,
            onSelected: (r) => setState(() => _roleFilter = r),
            itemBuilder: (context) => [
              const PopupMenuItem<UserRole?>(
                value: null,
                child: Text('All roles'),
              ),
              for (final r in rolesPresent)
                PopupMenuItem<UserRole?>(value: r, child: Text(r.label)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _p.surfaceTile,
                borderRadius: BorderRadius.circular(MlTokens.rMd),
                border: Border.all(
                  color: _roleFilter == null
                      ? _p.borderCard
                      : _p.blue.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 15,
                    color: _roleFilter == null ? _p.textMuted : _p.blue,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _roleFilter == null
                        ? 'Filter'
                        : 'Filter: ${_roleFilter!.label}',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _roleFilter == null ? _p.textMuted : _p.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _p.surfaceTile,
              borderRadius: BorderRadius.circular(MlTokens.rMd),
              border: Border.all(color: _p.borderCard),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_Presence?>(
                value: _statusFilter,
                dropdownColor: _p.surfaceCard,
                iconEnabledColor: _p.textMuted,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _p.textStrong,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Status: All')),
                  DropdownMenuItem(
                    value: _Presence.online,
                    child: Text('Status: Online'),
                  ),
                  DropdownMenuItem(
                    value: _Presence.away,
                    child: Text('Status: Away'),
                  ),
                  DropdownMenuItem(
                    value: _Presence.offline,
                    child: Text('Status: Offline'),
                  ),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- role sections ----

  List<Widget> _sections(
    Company company,
    List<RegisterMember> members,
    Set<String> online,
    Map<String, DateTime> liveStamps,
    Map<String, String> trucks,
    RegisterKpiBundle? kpis,
    double viewportWidth,
  ) {
    final q = _search.text.trim().toLowerCase();

    // Docs expiring within 30 days, attributed to a group: docs owned by one
    // of the group's members count there; docs not tied to any employee
    // (company-level papers) count under Admins & Management.
    final allMemberIds = <String>{
      for (final m in members) ...[m.employee.id, m.employee.userId],
    };
    final today = MlTime.now();
    final windowStart = DateTime(today.year, today.month, today.day);
    final windowEnd = windowStart.add(const Duration(days: 30));
    bool inWindow(RegisterComplianceDoc d) {
      final exp = d.expiresAt;
      return exp != null &&
          !exp.isBefore(windowStart) &&
          !exp.isAfter(windowEnd);
    }

    int docsFor(_RoleGroup g, List<RegisterMember> mine) {
      final docs = kpis?.docs ?? const <RegisterComplianceDoc>[];
      if (docs.isEmpty) return 0;
      if (identical(g, _azGroup)) return docs.where(inWindow).length;
      final ids = <String>{
        for (final m in mine) ...[m.employee.id, m.employee.userId],
      };
      var n = 0;
      for (final d in docs) {
        if (!inWindow(d)) continue;
        final owner = d.ownerId;
        final ownedHere = owner != null && ids.contains(owner);
        final companyLevel = g.title == RegisterRoleGroups.admins &&
            (owner == null || !allMemberIds.contains(owner));
        if (ownedHere || companyLevel) n++;
      }
      return n;
    }

    bool matches(RegisterMember m) {
      final e = m.employee;
      if (_statusFilter != null &&
          _presenceOf(m, online, liveStamps[e.userId]) != _statusFilter) {
        return false;
      }
      if (_roleFilter != null && e.role != _roleFilter) return false;
      if (q.isEmpty) return true;
      final id = '${_rolePrefix(e.role)}-${_shortId(e.id)}'.toLowerCase();
      return e.fullName.toLowerCase().contains(q) ||
          (e.role?.label.toLowerCase().contains(q) ?? false) ||
          id.contains(q) ||
          e.whatsappNumber.toLowerCase().contains(q);
    }

    Widget buildSection(_RoleGroup g, List<RegisterMember> visible) =>
        _RoleSection(
          p: _p,
          group: g,
          members: visible,
          company: company,
          trucks: trucks,
          kpi: identical(g, _azGroup) ? null : kpis?.byGroup[g.title],
          docsExpiring: docsFor(g, visible),
          viewportWidth: viewportWidth,
          presenceOf: (m) =>
              _presenceOf(m, online, liveStamps[m.employee.userId]),
          lastSeenOf: (m) => _bestLastSeen(m, liveStamps[m.employee.userId]),
        );

    final sections = <Widget>[];
    if (_byRole) {
      final assigned = <RegisterMember>{};
      for (final g in [..._groups, _otherGroup]) {
        final mine = members.where((m) {
          if (assigned.contains(m)) return false;
          final r = m.employee.role;
          return identical(g, _otherGroup)
              ? true
              : r != null && g.roles.contains(r);
        }).toList();
        assigned.addAll(mine);
        final visible = mine.where(matches).toList();
        if (visible.isEmpty) continue;
        sections
          ..add(buildSection(g, visible))
          ..add(const SizedBox(height: 20));
      }
    } else {
      final visible = members.where(matches).toList()
        ..sort(
          (a, b) => a.employee.fullName.toLowerCase().compareTo(
                b.employee.fullName.toLowerCase(),
              ),
        );
      if (visible.isNotEmpty) {
        sections
          ..add(buildSection(_azGroup, visible))
          ..add(const SizedBox(height: 20));
      }
    }

    if (sections.isEmpty) {
      sections.add(
        MlEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No employees match',
          message: q.isEmpty && _statusFilter == null && _roleFilter == null
              ? 'No users are registered under this company yet.'
              : 'Clear the search or filters to see the full register.',
        ),
      );
    }
    return sections;
  }

  static String _shortId(String id) =>
      id.replaceAll('-', '').substring(0, 4).toUpperCase();
}

// ---------------------------------------------------------------------------
// Section + member cards
// ---------------------------------------------------------------------------

class _RoleSection extends StatelessWidget {
  final _Pal p;
  final _RoleGroup group;
  final List<RegisterMember> members;
  final Company company;
  final Map<String, String> trucks;
  final RegisterKpi? kpi;
  final int docsExpiring;
  final double viewportWidth;
  final _Presence Function(RegisterMember) presenceOf;
  final DateTime? Function(RegisterMember) lastSeenOf;

  const _RoleSection({
    required this.p,
    required this.group,
    required this.members,
    required this.company,
    required this.trucks,
    required this.kpi,
    required this.docsExpiring,
    required this.viewportWidth,
    required this.presenceOf,
    required this.lastSeenOf,
  });

  @override
  Widget build(BuildContext context) {
    final pal = p;
    final groupColor = pal.tone(group.tone);
    final counts = <_Presence, int>{};
    for (final m in members) {
      final pr = presenceOf(m);
      counts[pr] = (counts[pr] ?? 0) + 1;
    }
    final total = members.length;

    Widget presencePill(String label, int n, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: pal.surfaceTile,
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: Border.all(color: pal.borderCard),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 7),
            Text(
              '$n $label',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: pal.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Compliance chip: amber when documents tied to this group expire within
    // 30 days, muted green "Docs valid" otherwise. Counted from
    // compliance_documents — same component every group.
    Widget docChip() {
      final expiring = docsExpiring > 0;
      final c = expiring ? pal.amber : pal.green;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: expiring ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: Border.all(color: c.withValues(alpha: expiring ? 0.4 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expiring ? Icons.schedule_rounded : Icons.verified_outlined,
              size: 12,
              color: c,
            ),
            const SizedBox(width: 6),
            Text(
              expiring ? '$docsExpiring expiring · 30d' : 'Docs valid',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: expiring ? c : pal.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Role KPI: completed-vs-outstanding over one record type. The label
    // prints its own noun, so no two groups read as a like-for-like ranking.
    Widget kpiCluster(RegisterKpi k) {
      final pct = k.pct;
      final color = pct == null
          ? pal.textMuted
          : pct >= 85
              ? pal.green
              : pct >= 60
                  ? pal.amber
                  : pal.red;
      return Tooltip(
        message: '${k.label} · ${k.detail} · counted live from records',
        waitDuration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  k.label,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: pal.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  pct == null ? '—' : '$pct%',
                  style: TextStyle(
                    fontFamily: MlTokens.fontSerif,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: pal.textStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              k.detail,
              style: TextStyle(
                fontFamily: MlTokens.fontMono,
                fontSize: 10,
                color:
                    pct == null ? pal.textMuted : color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }

    final statsCluster = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        presencePill('online', counts[_Presence.online] ?? 0, pal.green),
        presencePill('away', counts[_Presence.away] ?? 0, pal.amber),
        presencePill('offline', counts[_Presence.offline] ?? 0, pal.red),
        docChip(),
        if (kpi != null) kpiCluster(kpi!),
      ],
    );

    final twoUp = viewportWidth >= 900;
    // Narrow widths drop the stats cluster to its own line under the title
    // instead of squeezing it against the description.
    final statsInline = viewportWidth >= 1000;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pal.surfaceCard,
        borderRadius: BorderRadius.circular(pal.rCard),
        border: Border.all(color: pal.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pal.rTile),
                  color: groupColor.withValues(alpha: 0.12),
                  border: Border.all(color: groupColor.withValues(alpha: 0.4)),
                ),
                child: Icon(group.icon, size: 23, color: groupColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          group.title,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSerif,
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: pal.textStrong,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pal.surfaceTile,
                            borderRadius: BorderRadius.circular(MlTokens.rPill),
                            border: Border.all(color: pal.borderCard),
                          ),
                          child: Text(
                            '$total ${total == 1 ? 'person' : 'people'}',
                            style: TextStyle(
                              fontFamily: MlTokens.fontMono,
                              fontSize: 10.5,
                              color: pal.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description,
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 12.5,
                        color: pal.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (statsInline) ...[
                const SizedBox(width: 12),
                Flexible(child: statsCluster),
              ],
            ],
          ),
          if (!statsInline) ...[
            const SizedBox(height: 12),
            statsCluster,
          ],
          const SizedBox(height: 16),
          if (twoUp)
            Column(
              children: [
                for (var i = 0; i < members.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _card(members[i])),
                      const SizedBox(width: 12),
                      Expanded(
                        child: i + 1 < members.length
                            ? _card(members[i + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _card(members[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _card(RegisterMember m) => _MemberCard(
        p: p,
        member: m,
        group: group,
        company: company,
        truckReg: trucks[m.employee.id],
        presence: presenceOf(m),
        lastSeen: lastSeenOf(m),
      );
}

class _MemberCard extends ConsumerWidget {
  final _Pal p;
  final RegisterMember member;
  final _RoleGroup group;
  final Company company;
  final String? truckReg;
  final _Presence presence;
  final DateTime? lastSeen;

  const _MemberCard({
    required this.p,
    required this.member,
    required this.group,
    required this.company,
    required this.truckReg,
    required this.presence,
    required this.lastSeen,
  });

  Color get _presenceColor => switch (presence) {
        _Presence.online => p.green,
        _Presence.away => p.amber,
        _Presence.offline => p.red,
      };

  String get _presenceLabel {
    switch (presence) {
      case _Presence.online:
        return 'Online now';
      case _Presence.away:
        final ago = lastSeen == null ? null : _ago(lastSeen!);
        return ago == null ? 'Away' : 'Away · $ago';
      case _Presence.offline:
        final ago = lastSeen == null ? null : _ago(lastSeen!);
        return ago == null ? 'Offline' : 'Last seen $ago ago';
    }
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  static String _tenure(DateTime createdAt) {
    final d = DateTime.now().difference(createdAt);
    if (d.inDays >= 365) return '${d.inDays ~/ 365}y tenure';
    if (d.inDays >= 30) return '${d.inDays ~/ 30}mo tenure';
    return 'New this month';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = p;
    final groupColor = pal.tone(group.tone);
    final e = member.employee;
    final isOwner = e.userId == company.userId;
    final initials = [
      if (e.firstName.isNotEmpty) e.firstName[0],
      if (e.lastName.isNotEmpty) e.lastName[0],
    ].join().toUpperCase();
    final code =
        '${_rolePrefix(e.role)}-'
        '${e.id.replaceAll('-', '').substring(0, 4).toUpperCase()}';

    // P7-35: a user with no signature silently produces a BLANK waybill
    // signature line — 3 of 116 profiles have one. `null` means presence did
    // not resolve for this member, which is not the same as "missing", so it
    // renders nothing rather than a false accusation.
    final hasSignature = member.hasSignature;

    final setupChip = _setupChip(
      pal,
      ref.watch(employeeProfileSetupProvider(e.id)),
    );

    final chips = <Widget>[
      if (setupChip != null) setupChip,
      if (isOwner)
        _chip(pal, Icons.workspace_premium_outlined, 'System owner',
            color: pal.blue),
      _chip(pal, Icons.calendar_today_outlined, _tenure(e.createdAt)),
      if (truckReg != null)
        _chip(pal, Icons.local_shipping_outlined, truckReg!,
            color: pal.green, mono: true),
      if (hasSignature == true)
        _chip(pal, Icons.draw_outlined, 'Signature on file'),
      if (hasSignature == false)
        _chip(pal, Icons.gesture_outlined, 'No signature', color: pal.amber),
      if (e.role == UserRole.driver && e.licenseDocumentUrl != null)
        _chip(pal, Icons.badge_outlined, 'License on file', color: pal.blue),
      if ((e.status ?? '').isNotEmpty && e.status != 'active')
        _chip(pal, Icons.hourglass_top_rounded, e.status!, color: pal.amber),
      // The "Dismissed" and "Review dismissal" chips (P7-34) were removed with
      // the dismissal feature — client ruling, 2026-08-11. A staff member taken
      // off a company is unlinked by `remove_company_employee` and so is not on
      // this register at all; there is nothing left for a chip to report.
    ];

    return InkWell(
      // Opens the full live profile, read-only.
      borderRadius: BorderRadius.circular(pal.rTile),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeProfileScreen(
            employeeId: e.id,
            canManage: false,
            inPortal: false,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.surfaceTile,
          borderRadius: BorderRadius.circular(pal.rTile),
          border: Border.all(color: pal.borderCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                    color: groupColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: groupColor.withValues(alpha: 0.45),
                    ),
                    image: e.profilePhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(e.profilePhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: e.profilePhotoUrl == null
                      ? Text(
                          initials.isEmpty ? '?' : initials,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: groupColor,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  left: -3,
                  bottom: -3,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _presenceColor,
                      border: Border.all(color: pal.surfaceCard, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        e.fullName.trim().isEmpty ? 'Employee' : e.fullName,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: pal.textStrong,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pal.surfaceCard,
                          borderRadius: BorderRadius.circular(MlTokens.rXs),
                          border: Border.all(color: pal.borderCard),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontFamily: MlTokens.fontMono,
                            fontSize: 10.5,
                            color: pal.textMuted,
                          ),
                        ),
                      ),
                      if (isOwner)
                        Icon(Icons.verified_outlined, size: 15, color: pal.blue),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _presenceColor,
                        ),
                      ),
                      Text(
                        _presenceLabel,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: presence == _Presence.offline
                              ? pal.textMuted
                              : _presenceColor,
                        ),
                      ),
                      Text(
                        '·  ${e.role?.label ?? 'No role set'}'
                        '${e.whatsappNumber.trim().isEmpty ? '' : '  ·  ${e.whatsappNumber}'}',
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 12,
                          color: pal.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                const SizedBox(height: 6),
                Icon(Icons.chevron_right_rounded, size: 20, color: pal.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// This member's own account-setup completion, from `get_profile_setup` —
  /// the same figure the setup banner and the Employees screen already show,
  /// resolved per person rather than for whoever is looking.
  ///
  /// The RPC authorizes self / platform admin / company manager, and the
  /// register itself is manager-only (`employees` RLS is `is_company_manager`),
  /// so every viewer of this page is entitled to every row's real number.
  ///
  /// Returns `null` — no chip at all — while the read is in flight, if it is
  /// refused, or if the account has no setup to complete. A percentage nobody
  /// can stand behind is worse than a missing chip.
  Widget? _setupChip(_Pal p, AsyncValue<ProfileSetup> async) {
    final setup = async.valueOrNull;
    if (setup == null || !setup.isApplicable) return null;
    final s = setup.summary;
    // Expired beats missing: a lapsed document is a live compliance problem,
    // not an unfinished form.
    final color = s.expiredCount > 0
        ? p.red
        : (s.needsAttention ? p.amber : p.green);
    return _chip(
      p,
      s.needsAttention ? Icons.checklist_rounded : Icons.task_alt_rounded,
      'Setup ${s.completionPercent}%',
      color: color,
    );
  }

  Widget _chip(
    _Pal p,
    IconData icon,
    String label, {
    Color? color,
    bool mono = false,
    VoidCallback? onTap,
  }) {
    final c = color ?? p.textMuted;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color == null ? p.surfaceCard : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MlTokens.rSm),
        border: Border.all(
          color: color == null ? p.borderCard : c.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: mono ? MlTokens.fontMono : MlTokens.fontSans,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color == null ? p.textMuted : c,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MlTokens.rSm),
      child: chip,
    );
  }
}

// A `_SparkPainter` used to sit here, drawing a "trend line" beside each KPI
// and each employee row. It plotted nothing: the shape came from
// `seed.hashCode` bit-shifted into a fixed wiggle and sloped by a boolean, so
// two employees with adjacent ids got different "trends" and the same employee
// got the same one forever. Its own doc comment admitted it was decorative —
// but the tooltip beside it read "counted live from records", and a line beside
// a percentage reads as that percentage's history.
//
// There is no series to plot: `RegisterKpi` carries a label, a nullable `pct`
// and a detail string, and nothing anywhere keeps a per-KPI or per-employee
// time series. So it is removed rather than rewired, on the same principle the
// targets work settled on — draw nothing rather than something invented
// (CLAUDE.md §4: "a placeholder nobody chose that looks like a decision").
// The percentage and its colour already carry the state.

// ---------------------------------------------------------------------------
// Portal entry point
// ---------------------------------------------------------------------------

/// `/portal/{org}/register` — the signed-in user's OWN company register
/// (P7-29, P7-32).
///
/// The screen needs the whole [Company] (org type drives the KPI block, and
/// the owner's `user_id` marks the System-owner chip), so the id from
/// [resolvePortalCompanyId] is resolved to a row before rendering. Access is
/// enforced in Postgres — `employees` is `is_company_manager` and
/// `list_company_member_presence` raises `42501` — so a role that reaches this
/// URL without the rail entry still gets a denial, not a roster.
class PortalEmployeeRegisterScreen extends ConsumerWidget {
  const PortalEmployeeRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const MlEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Company not loaded',
        message: 'Your account is not linked to a company yet, so there is no '
            'register to show.',
      );
    }
    return ref.watch(registerCompanyProvider(companyId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MlEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load the company',
            message: friendlyError(e),
            action: MlButton.tonal(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(registerCompanyProvider(companyId)),
            ),
          ),
          data: (company) =>
              EmployeeRegisterScreen(company: company, embedded: true),
        );
  }
}

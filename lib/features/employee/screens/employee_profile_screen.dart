/// Full-screen live employee profile — opened by tapping a person in the
/// Employee Register (org portals + super-admin mirror).
///
/// Design ref: minelink-new-design-v0.1 `employee-register.jsx` → FullProfile
/// + the 9 approved per-role screenshots (2026-08-03 spec). Three-column grid:
/// identity/contact/documents · shift/productivity/location · activity/role
/// snapshot/notes. Every value is REAL (live queries + Supabase realtime +
/// presence); nothing is fabricated. All tiles are interactive: tap-to-copy
/// contact rows, signed-URL document view/download, deep-linked activity,
/// prev/next register navigation, live Message/WhatsApp/call actions and a
/// real PDF export.
library;

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/shell/workspace_canvas.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/chat/providers/chat_presence_provider.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/employee/providers/employee_profile_provider.dart';
import 'package:flutter_application_1/features/profile_setup/widgets/profile_setup_employer_card.dart';
import 'package:flutter_application_1/features/employee/services/employee_profile_pdf.dart';
import 'package:flutter_application_1/features/employee/services/employee_profile_service.dart';
import 'package:flutter_application_1/features/portal/screens/compliance_screen.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/presence/ml_presence.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// URL segment for an org's portal routes.
String portalOrgSegment(OrgType org) => switch (org) {
      OrgType.mineSupplier => 'mine',
      OrgType.buyer => 'buyer',
      OrgType.transporter => 'transporter',
    };

/// One rule, shared — see `core/presence/ml_presence.dart`.
typedef _Presence = MlPresence;


// Fixed status hues, identical in both themes (matches the mock's C.green &c).
const _green = MlTokens.green500;
const _blue = MlTokens.blue400;
const _amber = MlTokens.amber500;
const _red = MlTokens.red500;
const _cta = MlTokens.accent;

Color _toneColor(ProfileTone t, MlSemantic s) => switch (t) {
      ProfileTone.green => _green,
      ProfileTone.blue => _blue,
      ProfileTone.amber => _amber,
      ProfileTone.red => _red,
      ProfileTone.neutral => s.textFaint,
    };

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  final String employeeId;

  /// Managed (org admin) vs read-only (super-admin mirror) profile.
  final bool canManage;

  /// True when rendered inside a portal shell: activity deep links + the
  /// floating ChatDock are available. False on the super-admin push.
  final bool inPortal;

  const EmployeeProfileScreen({
    super.key,
    required this.employeeId,
    this.canManage = true,
    this.inPortal = true,
  });

  @override
  ConsumerState<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  late String _employeeId = widget.employeeId;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh relative stamps ("Synced 8s ago", last ping, shift progress).
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _ago(DateTime? t) => t == null ? '—' : MlTime.ago(t);

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  DateTime? _bestLastSeen(EmployeeProfileBundle b) => mlLastSeen(
        dbLastSeen: b.person.lastSeenAt,
        liveLastSeen:
            ref.read(presenceLastSeenProvider)[b.person.employee.userId],
      );

  _Presence _presenceOf(EmployeeProfileBundle b, Set<String> online) =>
      mlPresenceOf(
        online: online.contains(b.person.employee.userId),
        dbLastSeen: b.person.lastSeenAt,
        liveLastSeen:
            ref.read(presenceLastSeenProvider)[b.person.employee.userId],
      );

  void _close() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else if (widget.inPortal) {
      final b = ref.read(employeeProfileBundleProvider(_employeeId)).valueOrNull;
      final org = b == null ? 'mine' : portalOrgSegment(b.company.orgType);
      context.go('/portal/$org/employees');
    }
  }

  void _goSibling(EmployeeProfileBundle b, int delta) {
    final list = b.register;
    if (list.length < 2) return;
    final i = list.indexWhere((s) => s.employeeId == _employeeId);
    final n = (i + delta + list.length) % list.length;
    setState(() => _employeeId = list[n].employeeId);
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 220,
      ));
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open ${uri.toString()}')));
      }
    }
  }

  Future<void> _message(EmployeeProfileBundle b) async {
    try {
      final svc = ref.read(messagingServiceProvider);
      final me = svc.currentUserId;
      final e = b.person.employee;
      if (me == null || me == e.userId) return;
      final room = await svc.getOrCreateDm(
          otherUserId: e.userId, otherDisplayName: e.fullName);
      ref.invalidateIfMounted(chatConversationsProvider);
      if (!mounted) return;
      ref.read(activeRoomProvider.notifier).state = room;
      if (ChatDock.isMounted(context)) {
        // A floating dock is mounted over this shell (portal AND super-admin
        // console) — morph it open. Never push /messages here: that route is
        // portal-workspace-gated and hard-errors for the platform admin.
        ref.read(dockOpenRequestProvider.notifier).update((v) => v + 1);
      } else {
        // Completes only when /messages is popped — nothing here waits on it.
        unawaited(context.push('/messages'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open chat. ${friendlyError(e)}')));
      }
    }
  }

  void _radio() {
    // "Radio" = the org-wide People panel of chat (no telephony backend).
    // Same dock-presence rule as _message: /messages only when no dock exists.
    if (ChatDock.isMounted(context)) {
      ref.read(dockOpenRequestProvider.notifier).update((v) => v + 1);
    } else {
      context.push('/messages');
    }
  }

  Future<void> _openDoc(ProfileDocItem d) async {
    String? url = d.directUrl;
    if (url == null && d.compliancePath != null) {
      url = await ref
          .read(employeeProfileServiceProvider)
          .resolveComplianceUrl(d.compliancePath!);
    }
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file stored for this document')));
      }
      return;
    }
    await _launch(Uri.parse(url));
  }

  void _pushCompliance() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: mlWorkspaceGround(Theme.of(context).brightness),
        // shell-app-bar-exempt: a PUSHED page. It covers the shell's body with
        // a route nothing else names, so this bar is the only thing that says
        // what the page is and the only way back off it.
        appBar: AppBar(title: const Text('Compliance documents')),
        body: const ComplianceScreen(),
      ),
    ));
  }

  Future<void> _exportPdf(EmployeeProfileBundle b) async {
    try {
      final metrics =
          ref.read(employeeProfileMetricsProvider(_employeeId)).valueOrNull ??
              const <ProfileMetric>[];
      final activity =
          ref.read(employeeProfileActivityProvider(_employeeId)).valueOrNull ??
              const <ProfileActivityItem>[];
      final df = ref.read(employeeProfileDocsProvider(_employeeId)).valueOrNull;
      await exportEmployeeProfilePdf(
        bundle: b,
        metrics: metrics,
        activity: activity,
        docs: df?.docs ?? const [],
        flags: df?.flags ?? const [],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF export failed. ${friendlyError(e)}')));
      }
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    ref.watch(employeeProfileRealtimeProvider(_employeeId));
    final bundleAsync = ref.watch(employeeProfileBundleProvider(_employeeId));

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: bundleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // `MlLoadFailure`, not a hand-built copy of it.
          //
          // This was the 17th read failure in the product and the only one
          // still spelling itself out — a bare `Text`, a `friendlyError` and a
          // `TextButton` labelled "Retry" where every other screen says "Try
          // again". Being the odd one out had a second cost: the render
          // harness's failure-state report looks for `MlLoadFailure`, and it
          // could not see this one — the very card that motivated the report.
          error: (e, _) => Center(
            child: MlLoadFailure(
              subject: 'this profile',
              error: e,
              onRetry: () =>
                  ref.invalidate(employeeProfileBundleProvider(_employeeId)),
            ),
          ),
          data: (b) => _body(context, semantic, b),
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, MlSemantic semantic, EmployeeProfileBundle b) {
    final online = ref.watch(onlineUsersProvider);
    final presence = _presenceOf(b, online);
    final syncedAt = ref.watch(employeeProfileSyncedAtProvider(_employeeId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(semantic, b, syncedAt),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, c) {
                final left = _leftColumn(semantic, b, presence);
                final mid = _middleColumn(semantic, b, presence);
                final right = _rightColumn(semantic, b);
                if (c.maxWidth >= 1160) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 372, child: left),
                      const SizedBox(width: 20),
                      Expanded(child: mid),
                      const SizedBox(width: 20),
                      SizedBox(width: 384, child: right),
                    ],
                  );
                }
                if (c.maxWidth >= 760) {
                  return Column(children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 20),
                        Expanded(child: mid),
                      ],
                    ),
                    const SizedBox(height: 20),
                    right,
                  ]);
                }
                return Column(children: [
                  left,
                  const SizedBox(height: 20),
                  mid,
                  const SizedBox(height: 20),
                  right,
                ]);
              }),
              _footer(semantic, b, syncedAt),
            ],
          ),
        ),
      ),
    );
  }

  // ── header / footer ──────────────────────────────────────────────────────

  Widget _header(
      MlSemantic s, EmployeeProfileBundle b, DateTime syncedAt) {
    final e = b.person.employee;
    final org = portalOrgSegment(b.company.orgType);
    Widget crumb(String t, {bool strong = false}) => Text(
          t,
          // One line each, so an over-long SINGLE crumb ellipsises rather than
          // breaking a company name across two lines mid-word. Crumbs that do
          // not fit together move to the next line — that is the `Wrap`'s job
          // below, not this one's.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.mlText.overline.copyWith(
            color: strong ? MlTone.transit.colors(Theme.of(context).brightness).fg : s.textFaint,
          ),
        );
    // A breadcrumb, a live pill and SIX buttons. On a 412px phone that row
    // overflowed — the framework's hazard stripes were in the render and the
    // last button was clipped off the edge — and the two crumbs that fitted
    // read "FIXTURE HAULAG…" and "FIXTURE OPERAT…".
    //
    // Below 720px the breadcrumb takes a line of its own and the controls take
    // the next one, which is the only arrangement that fits six 36px targets
    // and a pill. Above it, the original single row.
    final narrow = MediaQuery.sizeOf(context).width < 720;
    // A `Wrap`, not a `Row` of two `Flexible`s.
    //
    // Two flex children share the free space EQUALLY whatever they hold, so
    // the longer of two names is cut to the shorter one's width even when the
    // row has room to spare. Moving the breadcrumb onto its own line (above)
    // fixed the OVERFLOW and left this: on the 412px phone render the leaf
    // crumb "FIXTURE OPERATOR" was drawn in full while the company beside it
    // was ellipsised at **143px** to "FIXTURE HAULAGE (P…".
    //
    // A company name is an identity, not a preview. Wrapped, both crumbs are
    // read in full on two lines, and nothing is lost at any width — on the
    // desktop path below they still sit on one.
    final crumbs = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        crumb(b.company.name.toUpperCase()),
        crumb('  /  '),
        if (!narrow) ...[
          crumb('EMPLOYEE REGISTER'),
          crumb('  /  '),
        ],
        crumb(e.fullName.toUpperCase(), strong: true),
      ],
    );
    final controls = [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.10),
          border: Border.all(color: _green.withValues(alpha: 0.35)),
          borderRadius: MlShape.pill,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration:
                  const BoxDecoration(color: _green, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text('Live · Synced ${_ago(syncedAt)}',
              style: context.mlText.bodySmall.copyWith(
                color: _green.withValues(alpha: 0.95),
              )),
        ]),
      ),
      const SizedBox(width: 10),
      _IconBtn(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous employee',
          onTap: () => _goSibling(b, -1)),
      const SizedBox(width: 8),
      _IconBtn(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next employee',
          onTap: () => _goSibling(b, 1)),
      if (widget.inPortal) ...[
        const SizedBox(width: 8),
        _IconBtn(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () => context.push('/portal/$org/notifications')),
      ],
      const SizedBox(width: 8),
      _MoreMenu(
        onCopyLink: () =>
            _copy('Profile link', '/portal/$org/employees/${e.id}'),
        onRefresh: () {
          ref.invalidate(employeeProfileBundleProvider(_employeeId));
          ref.invalidate(employeeProfileMetricsProvider(_employeeId));
          ref.invalidate(employeeProfileActivityProvider(_employeeId));
          ref.invalidate(employeeProfileDocsProvider(_employeeId));
        },
      ),
      const SizedBox(width: 8),
      _IconBtn(icon: Icons.close_rounded, tooltip: 'Close', onTap: _close),
    ];

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _IconBtn(
                icon: Icons.chevron_left_rounded, size: 36, onTap: _close),
            const SizedBox(width: 12),
            Expanded(child: crumbs),
          ]),
          const SizedBox(height: 10),
          // A Wrap, so the pill and the six buttons reflow instead of
          // overflowing at a large text scale.
          Wrap(
            spacing: 0,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          ),
        ],
      );
    }

    return Row(children: [
      _IconBtn(icon: Icons.chevron_left_rounded, size: 36, onTap: _close),
      const SizedBox(width: 14),
      // `Expanded` and NO `Spacer`. A `Spacer` IS an `Expanded(flex: 1)`, so
      // beside a `Flexible(flex: 1)` it split the free space EQUALLY — the
      // breadcrumb got 122px of a 1600px header and read
      // "FIXTURE HAULAG… / EMPLOYEE REGISTER / FIXTURE OPERAT…" while half the
      // row sat empty. The crumbs take the space and the controls sit at the
      // right edge because nothing else claims it.
      Expanded(
        child: Align(alignment: Alignment.centerLeft, child: crumbs),
      ),
      const SizedBox(width: 12),
      ...controls,
    ]);
  }

  Widget _footer(MlSemantic s, EmployeeProfileBundle b, DateTime syncedAt) {
    return Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.only(top: 18),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: s.borderCard))),
      // A Wrap, and the sentence claims the row.
      //
      // It was a Row with a `Flexible` sentence and a `Spacer` — an
      // `Expanded(flex: 1)` each, splitting the free space EQUALLY, so on a
      // desktop half the row sat empty while the sentence ellipsised. On a
      // phone even the full half is not enough beside a 190px "Export profile
      // PDF" button, so the button drops to its own line.
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 560 ? double.infinity : 420,
            child: Row(children: [
              const Icon(Icons.check_rounded, size: 15, color: _green),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Live profile · Auto-updates on any change · Synced ${_ago(syncedAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodySmall.copyWith(color: s.textFaint),
                ),
              ),
            ]),
          ),
        OutlinedButton.icon(
          onPressed: () => _exportPdf(b),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export profile PDF'),
          style: OutlinedButton.styleFrom(
            foregroundColor: s.textBody,
            side: BorderSide(color: s.borderStrong),
            textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: MlTokens.fontSans),
            shape:
                RoundedRectangleBorder(borderRadius: MlShape.radiusMedium),
          ),
        ),
        ],
      ),
    );
  }

  // ── left column ──────────────────────────────────────────────────────────

  Widget _leftColumn(
      MlSemantic s, EmployeeProfileBundle b, _Presence presence) {
    final e = b.person.employee;
    final brightness = Theme.of(context).brightness;
    final tone = switch (b.roleKey) {
      ProfileRoleKey.driver || ProfileRoleKey.admin => MlTone.done,
      ProfileRoleKey.superv => MlTone.atMine,
      ProfileRoleKey.load || ProfileRoleKey.security => MlTone.transit,
      ProfileRoleKey.fleet => MlTone.transit,
      ProfileRoleKey.procure => MlTone.atMine,
      _ => MlTone.neutral,
    };
    final tc = tone.colors(brightness);
    final presColor = switch (presence) {
      _Presence.online => _green,
      _Presence.away => _amber,
      _Presence.offline => s.textFaint,
    };
    final roleLabel = profileRoleLabel(b.company.orgType, e.role);
    final code = profileEmpCode(e);
    final initials = e.fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    final names = e.fullName.split(' ');
    final groupLabel = switch (b.roleKey) {
      ProfileRoleKey.admin => 'Admins & Management',
      ProfileRoleKey.fleet => 'Fleet Controllers',
      ProfileRoleKey.procure => 'Procurement',
      ProfileRoleKey.driver => 'Drivers',
      ProfileRoleKey.superv => 'Supervisors & Foremen',
      ProfileRoleKey.load => 'Load Controllers',
      ProfileRoleKey.security => 'Security Guards',
      ProfileRoleKey.other => 'Members',
    };
    final posting = _postingLabel(b);
    final seen = _bestLastSeen(b);

    return Column(children: [
      // Identity hero
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tc.bg, s.surfaceCard],
          ),
          border: Border.all(color: s.borderCard),
          borderRadius: MlShape.radiusLargeIncreased,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: tone.well(brightness),
                  borderRadius: MlShape.radiusLargeIncreased,
                  border: Border.all(color: s.borderCard),
                  image: e.profilePhotoUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(e.profilePhotoUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: e.profilePhotoUrl == null
                    ? Text(initials,
                        style: context.mlText.headlineMedium.copyWith(
                          color: tc.fg,
                        ))
                    : null,
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: presColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: s.surfaceCard, width: 3),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: names.first),
                        if (names.length > 1)
                          TextSpan(
                            text: ' ${names.skip(1).join(' ')}',
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600),
                          ),
                      ]),
                      style: context.mlText.figure(
                        color: s.textStrong,
                        size: 28,
                        height: 1.05,
                      ),
                    ),
                  ),
                  if (!b.person.whatsappOnly) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified_rounded, size: 18, color: _blue),
                  ],
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.surfaceSunken,
                      border: Border.all(color: tc.fg.withValues(alpha: 0.4)),
                      borderRadius: MlShape.pill,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: tc.fg, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(roleLabel.toUpperCase(),
                          style: context.mlText.labelSmall.copyWith(
                            color: tc.fg,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.surfaceSunken,
                      border: Border.all(color: s.borderCard),
                      borderRadius: MlShape.radiusSmall,
                    ),
                    child: Text(code,
                        style: context.mlText.code(
                          color: s.textFaint,
                          size: 11,
                          weight: FontWeight.w400,
                        )),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('${b.company.name} · $groupLabel',
                    style: context.mlText.bodyMedium.copyWith(
                      color: s.textMuted,
                    )),
                Text(posting,
                    style: context.mlText.bodyMedium.copyWith(
                      color: s.textFaint,
                    )),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: s.surfaceSunken,
              border: Border.all(color: s.borderCard),
              borderRadius: MlShape.pill,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.canManage ? Icons.manage_accounts_outlined : Icons.lock_outline,
                  size: 14, color: s.textFaint),
              const SizedBox(width: 7),
              Text(widget.canManage ? 'Managed profile' : 'Read-only profile',
                  style: context.mlText.labelMedium.copyWith(color: s.textMuted)),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: s.surfaceSunken,
              border: Border.all(color: s.divider),
              borderRadius: MlShape.radiusMedium,
            ),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: presColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  switch (presence) {
                    _Presence.online => 'Online now · On shift',
                    _Presence.away => 'Away · recently active',
                    _Presence.offline => 'Offline',
                  },
                  style: context.mlText.titleSmall.copyWith(color: presColor),
                ),
              ),
              Text(
                'last ping · ${presence == _Presence.online ? 'live' : _ago(seen)}',
                style: context.mlText.code(
                  color: s.textFaint,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => _message(b),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text('Message  ${e.firstName}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _cta,
                    foregroundColor: MlTokens.inkOnAccent,
                    textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: MlTokens.fontSans),
                    shape: RoundedRectangleBorder(
                        borderRadius: MlShape.radiusMedium),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _IconBtn(
                icon: Icons.call_outlined,
                size: 46,
                radius: 12,
                tooltip: 'Call ${e.whatsappNumber}',
                onTap: () => _launch(Uri.parse(
                    'tel:${e.whatsappNumber.replaceAll(' ', '')}'))),
            const SizedBox(width: 10),
            _IconBtn(
                icon: Icons.sms_outlined,
                size: 46,
                radius: 12,
                tooltip: 'WhatsApp',
                onTap: () => _launch(Uri.parse(
                    'https://wa.me/${e.whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '')}'))),
            const SizedBox(width: 10),
            _IconBtn(
                icon: Icons.sensors_rounded,
                size: 46,
                radius: 12,
                tooltip: 'Open team channel',
                onTap: _radio),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      _contactCard(s, b),
      const SizedBox(height: 20),
      _documentsCard(s, b),
      const SizedBox(height: 20),
      // Live account-setup completion (manager-authorized RPC): percent,
      // outstanding required items, and upcoming/lapsed expiries.
      ProfileSetupEmployerCard(employeeId: _employeeId),
    ]);
  }

  String _postingLabel(EmployeeProfileBundle b) {
    final loc =
        ref.watch(employeeProfileLocationProvider(_employeeId)).valueOrNull;
    final site = loc?.name;
    return switch (b.roleKey) {
      ProfileRoleKey.admin => 'Head office',
      ProfileRoleKey.fleet => 'Depot${site != null ? ' · $site' : ''}',
      ProfileRoleKey.procure => 'Contracts',
      ProfileRoleKey.driver => site ?? 'Long haul',
      _ => site ?? 'On site',
    };
  }

  Widget _contactCard(MlSemantic s, EmployeeProfileBundle b) {
    final e = b.person.employee;
    final rows = <(IconData, String, String, bool)>[
      (Icons.badge_outlined, 'Employee ID', profileEmpCode(e), true),
      (Icons.work_outline_rounded, 'Role',
          profileRoleLabel(b.company.orgType, e.role), false),
      if (b.person.email != null)
        (Icons.mail_outline_rounded, 'Email', b.person.email!, false),
      (Icons.chat_outlined, 'WhatsApp', e.whatsappNumber, true),
      if (e.idNumber?.isNotEmpty == true)
        (Icons.fingerprint_rounded, 'ID number', e.idNumber!, true)
      else if (e.passportOrWorkersPermit?.isNotEmpty == true)
        (Icons.fingerprint_rounded, 'Passport / permit',
            e.passportOrWorkersPermit!, true),
    ];
    return _PCard(
      title: 'CONTACT & IDENTITY',
      right: Text('Tap to copy',
          style: context.mlText.labelSmall.copyWith(
            color: s.textFaint,
            fontWeight: FontWeight.w400,
          )),
      child: Column(children: [
        for (final (icon, label, value, mono) in rows)
          InkWell(
            onTap: () => _copy(label, value),
            borderRadius: MlShape.radiusSmall,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              // The label hugs the left, the VALUE takes the rest and may
              // take two lines. An email is the longest thing this card holds
              // and the likeliest thing a person is here to read: at one line
              // it had 138px and showed "thandi.mokoena@f…", which "Tap to
              // copy" only half excuses — you cannot check what you are
              // copying.
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 16, color: s.textFaint),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: context.mlText.bodySmall.copyWith(color: s.textMuted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: mono ? MlTokens.fontMono : MlTokens.fontSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: s.textStrong,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        if (b.person.whatsappOnly)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
              borderRadius: MlShape.radiusMedium,
            ),
            child: Row(children: [
              const Icon(Icons.chat_outlined, size: 16, color: _green),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'WhatsApp-only account — signs in with their WhatsApp number.',
                  style: context.mlText.bodySmall.copyWith(
                    color: _green.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _documentsCard(MlSemantic s, EmployeeProfileBundle b) {
    final docsAsync = ref.watch(employeeProfileDocsProvider(_employeeId));
    return docsAsync.when(
      loading: () => _PCard(
          title: 'EMPLOYEE DOCUMENTS',
          child: const Center(
              child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))))),
      error: (_, __) => const SizedBox.shrink(),
      data: (df) {
        final docs = df.docs;
        final allGreen =
            docs.isNotEmpty && docs.every((d) => d.statusTone == ProfileTone.green);
        final expiring = docs
            .where((d) =>
                d.statusTone == ProfileTone.amber ||
                d.statusTone == ProfileTone.red)
            .length;
        return _PCard(
          title: 'EMPLOYEE DOCUMENTS · ${docs.length}',
          right: Text(
            allGreen
                ? 'All verified'
                : expiring > 0
                    ? '$expiring expiring'
                    : '',
            style: context.mlText.labelSmall.copyWith(
              color: allGreen ? _green : _amber,
            ),
          ),
          child: Column(children: [
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('No documents on file yet.',
                    style: context.mlText.bodyMedium.copyWith(
                      color: s.textMuted,
                    )),
              ),
            for (final d in docs) ...[
              _DocTile(doc: d, onOpen: () => _openDoc(d)),
              const SizedBox(height: 10),
            ],
            if (widget.canManage)
              InkWell(
                onTap: _pushCompliance,
                borderRadius: MlShape.radiusMedium,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: s.borderStrong),
                    borderRadius: MlShape.radiusMedium,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.upload_file_outlined,
                        size: 16, color: s.textMuted),
                    const SizedBox(width: 7),
                    Text('Upload document',
                        style: context.mlText.titleSmall.copyWith(
                          color: s.textMuted,
                        )),
                  ]),
                ),
              ),
          ]),
        );
      },
    );
  }

  // ── middle column ────────────────────────────────────────────────────────

  Widget _middleColumn(
      MlSemantic s, EmployeeProfileBundle b, _Presence presence) {
    return Column(children: [
      _shiftCard(s, b, presence),
      const SizedBox(height: 20),
      _productivityCard(s),
      const SizedBox(height: 20),
      _locationCard(s, b, presence),
    ]);
  }

  Widget _shiftCard(
      MlSemantic s, EmployeeProfileBundle b, _Presence presence) {
    // The shift runs 05:00-17:00 AT THE MINE, so the day and the hour are
    // South African ones (CLAUDE.md 7.1). Off the device's clock a night-shift
    // supervisor two zones away saw a progress bar for somebody else's day.
    final now = MlTime.now();
    final start = DateTime(now.year, now.month, now.day, 5);
    final end = DateTime(now.year, now.month, now.day, 17);
    final total = end.difference(start).inMinutes;
    final elapsed = now.difference(start).inMinutes.clamp(0, total);
    final pct = total == 0 ? 0.0 : elapsed / total;
    final eh = elapsed ~/ 60, em = elapsed % 60;
    final activity =
        ref.watch(employeeProfileActivityProvider(_employeeId)).valueOrNull;
    final lastAct = activity != null && activity.isNotEmpty
        ? activity.firstWhere((a) => !a.isNow, orElse: () => activity.first)
        : null;
    final seen = _bestLastSeen(b);

    Widget stat(String label, String value, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: context.mlText.overline.copyWith(color: s.textFaint)),
            const SizedBox(height: 5),
            Text(value,
                style: context.mlText.code(
                  color: color,
                  size: 14,
                  weight: FontWeight.w700,
                )),
          ],
        );

    return _PCard(
      title: "TODAY'S SHIFT",
      right: presence == _Presence.online
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: _green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('LIVE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _green)),
            ])
          : Text('OFF SHIFT',
              style: context.mlText.labelSmall.copyWith(
                color: s.textFaint,
                fontWeight: FontWeight.w700,
              )),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(_postingLabel(b),
                  style: context.mlText.editorialMedium.copyWith(
                    color: s.textStrong,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            Text('05:00 → 17:00',
                style: context.mlText.code(
                  color: s.textBody,
                  size: 13,
                  weight: FontWeight.w400,
                )),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 14,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                top: 3,
                left: 0,
                right: 0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.surfaceSunken,
                    border: Border.all(color: s.divider),
                    borderRadius: MlShape.pill,
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 0,
                child: Container(
                  height: 8,
                  width: w * pct,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_blue, _green]),
                    borderRadius: MlShape.pill,
                  ),
                ),
              ),
              Positioned(
                left: (w * pct - 7).clamp(0.0, w - 14),
                top: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: s.textStrong,
                    shape: BoxShape.circle,
                    border: Border.all(color: s.surfaceCard, width: 3),
                  ),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final t in const ['05:00', '08:00', '11:00', '14:00', '17:00'])
              Text(t,
                  style: context.mlText.code(
                    color: s.textFaint,
                    size: 11,
                    weight: FontWeight.w400,
                  )),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 26, runSpacing: 10, children: [
          stat('SHIFT PROGRESS',
              '${(pct * 100).round()}% · ${eh}h ${em.toString().padLeft(2, '0')}m', _green),
          stat(
              'LAST ACTIVITY',
              lastAct == null
                  ? '—'
                  : '${_hm(lastAct.at)} · ${lastAct.bold}',
              s.textStrong),
          stat(
              'LAST PING',
              presence == _Presence.online ? 'live · now' : _ago(seen),
              presence == _Presence.online ? _green : _amber),
        ]),
      ]),
    );
  }

  Widget _productivityCard(MlSemantic s) {
    final metricsAsync = ref.watch(employeeProfileMetricsProvider(_employeeId));
    return _PCard(
      title: "TODAY'S PRODUCTIVITY",
      right: Text('vs. weekly avg',
          style: context.mlText.labelSmall.copyWith(
            color: s.textFaint,
            fontWeight: FontWeight.w400,
          )),
      child: metricsAsync.when(
        loading: () => const SizedBox(
            height: 120, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text('Metrics unavailable',
            style: context.mlText.bodySmall.copyWith(color: s.textMuted)),
        data: (metrics) {
          if (metrics.isEmpty) {
            return Text('No recorded productivity yet — live counters appear '
                'as this person works in the app.',
                style: context.mlText.bodyMedium.copyWith(color: s.textMuted));
          }
          return LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 560;
            final tiles = [
              for (final m in metrics)
                _MetricTile(metric: m, semantic: s),
            ];
            if (narrow) {
              return Column(children: [
                for (final t in tiles)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12), child: t),
              ]);
            }
            // IntrinsicHeight: equal-height tiles under the unbounded height
            // this card gets from its scrollable column — bare stretch would
            // force infinite tile height and fail layout.
            return IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: tiles[i]),
                    ],
                  ]),
            );
          });
        },
      ),
    );
  }

  Widget _locationCard(
      MlSemantic s, EmployeeProfileBundle b, _Presence presence) {
    final brightness = Theme.of(context).brightness;
    final loc =
        ref.watch(employeeProfileLocationProvider(_employeeId)).valueOrNull;
    final locName = loc?.name ??
        switch (b.roleKey) {
          ProfileRoleKey.admin ||
          ProfileRoleKey.procure =>
            'Head office',
          ProfileRoleKey.fleet => 'Depot',
          ProfileRoleKey.driver => 'On route',
          _ => 'On site',
        };
    final sup = b.supervisor;
    final isLeader = b.person.employee.role == UserRole.admin ||
        b.person.employee.role == UserRole.management;
    final online = ref.watch(onlineUsersProvider);
    final supOnline = sup != null && online.contains(sup.userId);
    final tone = MlTone.done.colors(brightness);

    return _PCard(
      title: 'LOCATION & ASSIGNMENT',
      right: Text(
          loc?.at != null ? 'Auto-detected · ${_ago(loc!.at)}' : 'Live',
          style: context.mlText.labelSmall.copyWith(
            color: s.textFaint,
            fontWeight: FontWeight.w400,
          )),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: MlTone.done.well(brightness),
              border: Border.all(color: s.borderCard),
              borderRadius: MlShape.radiusMedium,
            ),
            child: Icon(Icons.location_on_outlined, size: 22, color: tone.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(locName,
                  style: context.mlText.titleMedium.copyWith(
                    color: s.textStrong,
                    fontWeight: FontWeight.w700,
                  )),
              Text('${b.company.name} · ${b.company.orgType.label}',
                  style: context.mlText.bodySmall.copyWith(color: s.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: (presence == _Presence.online ? _green : s.textFaint)
                  .withValues(alpha: 0.10),
              border: Border.all(
                  color: (presence == _Presence.online ? _green : s.textFaint)
                      .withValues(alpha: 0.35)),
              borderRadius: MlShape.pill,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color:
                          presence == _Presence.online ? _green : s.textFaint,
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(presence == _Presence.online ? 'ON-SITE' : 'OFF-SITE',
                  style: context.mlText.labelSmall.copyWith(
                    color: presence == _Presence.online ? _green : s.textFaint,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: MlShape.radiusLarge,
          child: Container(
            height: 168,
            decoration: BoxDecoration(
              color: s.surfaceSunken,
              border: Border.all(color: s.divider),
              borderRadius: MlShape.radiusLarge,
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 168),
              painter: _ZonePainter(
                line: s.borderStrong,
                path: _green,
                marker: _blue,
                labelColor: s.textBody,
                faint: s.textFaint,
                topLabel:
                    '${b.company.name.split(' ').first.toUpperCase()} · ZONE',
                bottomLabel: locName,
                coords: loc?.lat != null && loc?.lng != null
                    ? '${loc!.lat!.toStringAsFixed(4)}° · ${loc.lng!.toStringAsFixed(4)}°'
                    : 'coordinates pending',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: sup == null
              ? null
              : () => setState(() => _employeeId = sup.employeeId),
          borderRadius: MlShape.radiusMedium,
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: MlTone.transit.well(brightness),
                border: Border.all(color: s.borderCard),
                borderRadius: MlShape.radiusMedium,
              ),
              alignment: Alignment.center,
              child: Text(
                isLeader || sup == null
                    ? 'BD'
                    : sup.name
                        .split(' ')
                        .where((w) => w.isNotEmpty)
                        .take(2)
                        .map((w) => w.characters.first.toUpperCase())
                        .join(),
                style: context.mlText.titleSmall.copyWith(
                  color: MlTone.transit.colors(brightness).fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isLeader ? 'REPORTS TO' : 'REPORTING SUPERVISOR',
                    style: context.mlText.overline.copyWith(color: s.textFaint)),
                const SizedBox(height: 2),
                Text(
                  isLeader || sup == null
                      ? 'Board / Directors'
                      : '${sup.name} · ${sup.roleLabel}',
                  style: context.mlText.titleSmall.copyWith(
                    color: s.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
            if (!isLeader && sup != null)
              Row(children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: supOnline ? _green : s.textFaint,
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(supOnline ? 'Online' : 'Offline',
                    style: context.mlText.labelSmall.copyWith(
                      color: supOnline ? _green : s.textFaint,
                      fontWeight: FontWeight.w400,
                    )),
              ]),
          ]),
        ),
      ]),
    );
  }

  // ── right column ─────────────────────────────────────────────────────────

  Widget _rightColumn(MlSemantic s, EmployeeProfileBundle b) {
    return Column(children: [
      _activityCard(s, b),
      const SizedBox(height: 20),
      _roleSnapshotCard(s, b),
      const SizedBox(height: 20),
      _flagsCard(s, b),
    ]);
  }

  Widget _activityCard(MlSemantic s, EmployeeProfileBundle b) {
    final org = portalOrgSegment(b.company.orgType);
    final activityAsync =
        ref.watch(employeeProfileActivityProvider(_employeeId));
    return _PCard(
      title: 'ACTIVITY · LAST 24H',
      right: widget.inPortal
          ? InkWell(
              onTap: () => context.push('/portal/$org/notifications'),
              child: const Text('View full log →',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MlTokens.accent)),
            )
          : null,
      child: activityAsync.when(
        loading: () => const SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text('Activity unavailable',
            style: context.mlText.bodySmall.copyWith(color: s.textMuted)),
        data: (items) {
          if (items.isEmpty) {
            return Text('No recorded activity in the last 24 hours.',
                style: context.mlText.bodyMedium.copyWith(color: s.textMuted));
          }
          return Column(children: [
            for (var i = 0; i < items.length; i++)
              _TimelineRow(
                item: items[i],
                isLast: i == items.length - 1,
                semantic: s,
                timeLabel: items[i].isNow ? 'now' : _hm(items[i].at),
                onTap: widget.inPortal && items[i].route != null
                    ? () => context.push(items[i].route!)
                    : null,
              ),
          ]);
        },
      ),
    );
  }

  Widget _roleSnapshotCard(MlSemantic s, EmployeeProfileBundle b) {
    final e = b.person.employee;
    final months = MlTime.instant().difference(e.createdAt).inDays ~/ 30;
    final tenure = months < 12 ? '$months mo' : '${months ~/ 12}y';
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final since =
        'since ${monthNames[e.createdAt.month - 1]} ${e.createdAt.year}';
    final lastLogin = b.person.lastLoginAt;
    final isAdmin = e.role == UserRole.admin;
    final isOwner = b.company.adminUserId == e.userId;
    final perms = switch (b.roleKey) {
      ProfileRoleKey.admin => 'Full · R/W',
      ProfileRoleKey.load => 'Loads · R/W',
      ProfileRoleKey.security => 'Gate · R/W',
      _ => 'Scoped',
    };
    final metrics =
        ref.watch(employeeProfileMetricsProvider(_employeeId)).valueOrNull;
    final df = ref.watch(employeeProfileDocsProvider(_employeeId)).valueOrNull;

    final badges = <(String, ProfileTone)>[
      if (isOwner) ('System owner', ProfileTone.blue),
      if (isAdmin) ('All permissions', ProfileTone.blue),
      if (metrics != null && metrics.isNotEmpty)
        ('${metrics.first.value}${metrics.first.unit} ${metrics.first.label.toLowerCase()}',
            ProfileTone.green),
      if (df != null)
        for (final d in df.docs)
          if (d.compliancePath != null || d.directUrl != null)
            if (d.title.toLowerCase().contains('prdp'))
              ('PrDP', ProfileTone.blue)
            else if (d.title.toLowerCase().contains('induction'))
              ('Inducted', ProfileTone.green),
    ];

    Widget tile(String label, String value, [String? sub]) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: s.surfaceSunken,
            border: Border.all(color: s.divider),
            borderRadius: MlShape.radiusMedium,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: context.mlText.overline.copyWith(color: s.textFaint)),
            const SizedBox(height: 4),
            Text(value,
                // TWO lines. These tiles are half a phone wide, and the
                // LAST SIGN-IN value is a clock AND a relative age
                // ("03:30 · 6 h ago") — at one line the phone kept the clock
                // and dropped how long ago it was, which is the half that
                // says whether this person is still around.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.code(
                  color: s.textStrong,
                  size: 14,
                  weight: FontWeight.w700,
                )),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.labelSmall.copyWith(
                    color: s.textFaint,
                    fontWeight: FontWeight.w400,
                  )),
            ],
          ]),
        );

    final updatedBy = b.supervisor?.name ?? 'System';
    return _PCard(
      title: 'ROLE SNAPSHOT',
      right: Text('updated by ${updatedBy.split(' ').first}',
          style: context.mlText.labelSmall.copyWith(
            color: s.textFaint,
            fontWeight: FontWeight.w400,
          )),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // IntrinsicHeight: these rows stretch tiles to equal height, but the
        // parent Column gives them unbounded height — stretch alone would
        // force infinite tile height and fail layout.
        IntrinsicHeight(
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tile('TENURE', tenure, since)),
            const SizedBox(width: 10),
            Expanded(
                child: tile('POSTING', _postingLabel(b),
                    b.company.name.split(' ').first)),
          ]),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: tile(
                    'LAST SIGN-IN',
                    lastLogin == null
                        ? '—'
                        : '${_hm(lastLogin)} · ${_ago(lastLogin)}')),
            const SizedBox(width: 10),
            Expanded(child: tile('PERMISSIONS', perms)),
          ]),
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final (label, tone) in badges)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _toneColor(tone, s).withValues(alpha: 0.10),
                  border: Border.all(
                      color: _toneColor(tone, s).withValues(alpha: 0.4)),
                  borderRadius: MlShape.radiusSmall,
                ),
                child: Text(label,
                    style: context.mlText.code(
                      color: _toneColor(tone, s),
                      size: 11,
                      weight: FontWeight.w600,
                    )),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _flagsCard(MlSemantic s, EmployeeProfileBundle b) {
    final df = ref.watch(employeeProfileDocsProvider(_employeeId)).valueOrNull;
    final flags = df?.flags ?? const <ProfileFlag>[];
    return _PCard(
      title: 'NOTES & FLAGS',
      right: Text('${flags.length} open',
          style: context.mlText.labelSmall.copyWith(
            color: s.textFaint,
            fontWeight: FontWeight.w400,
          )),
      child: Column(children: [
        if (flags.isEmpty)
          _FlagTile(
            semantic: s,
            tone: ProfileTone.green,
            icon: Icons.check_circle_outline_rounded,
            title: 'No open flags',
            body:
                'This employee has no outstanding notes or compliance flags.',
            meta: 'Opened by System · today',
          )
        else
          for (final f in flags) ...[
            _FlagTile(
              semantic: s,
              tone: f.tone,
              icon: f.tone == ProfileTone.red
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              title: f.title,
              body: f.body,
              meta: f.metaLine,
            ),
            const SizedBox(height: 10),
          ],
        if (widget.canManage) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: _pushCompliance,
            borderRadius: MlShape.radiusMedium,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: s.surfaceSunken,
                border: Border.all(color: s.borderCard),
                borderRadius: MlShape.radiusMedium,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_rounded, size: 16, color: s.textBody),
                const SizedBox(width: 7),
                Text('Add note or flag',
                    style: context.mlText.titleSmall.copyWith(color: s.textBody)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared pieces
// ═══════════════════════════════════════════════════════════════════════════

/// Section card: accent dot + tracked-caps title header, hairline borders —
/// the JSX mock's PCard.
class _PCard extends StatelessWidget {
  final String title;
  final Widget? right;
  final Widget child;
  const _PCard({required this.title, this.right, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Container(
      decoration: BoxDecoration(
        color: s.surfaceCard,
        border: Border.all(color: s.borderCard),
        borderRadius: MlShape.radiusLargeIncreased,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: s.divider))),
          child: Row(children: [
            Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    color: MlTokens.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: context.mlText.overline.copyWith(color: s.textFaint)),
            ),
            if (right != null) right!,
          ]),
        ),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double radius;
  final String? tooltip;
  const _IconBtn({
    required this.icon,
    this.onTap,
    this.size = 34,
    this.radius = 9,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: s.surfaceSunken,
          border: Border.all(color: s.borderCard),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon, size: size * 0.46 + 3, color: s.textBody),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _MoreMenu extends StatelessWidget {
  final VoidCallback onCopyLink;
  final VoidCallback onRefresh;
  const _MoreMenu({required this.onCopyLink, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return PopupMenuButton<String>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      onSelected: (v) => v == 'copy' ? onCopyLink() : onRefresh(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'copy', child: Text('Copy profile link')),
        PopupMenuItem(value: 'refresh', child: Text('Refresh now')),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: s.surfaceSunken,
          border: Border.all(color: s.borderCard),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Icon(Icons.more_horiz_rounded, size: 18, color: s.textBody),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final ProfileDocItem doc;
  final VoidCallback onOpen;
  const _DocTile({required this.doc, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final statusColor = _toneColor(doc.statusTone, s);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.surfaceSunken,
        border: Border.all(color: s.divider),
        borderRadius: MlShape.radiusMedium,
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.12),
            border: Border.all(color: _red.withValues(alpha: 0.3)),
            borderRadius: MlShape.radiusMedium,
          ),
          child: const Icon(Icons.description_outlined, size: 18, color: _red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.title,
                // TWO lines: the document's NAME, beside an icon and two
                // action buttons on a phone. "Professional driving permit" is
                // the longest and the one whose expiry matters most.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleSmall.copyWith(
                  color: s.textStrong,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 3),
            Text(doc.subtitle,
                style: context.mlText.labelSmall.copyWith(
                  color: s.textFaint,
                  fontWeight: FontWeight.w400,
                )),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: doc.statusTone == ProfileTone.green
                    ? _green.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                borderRadius: MlShape.radiusSmall,
              ),
              child: Text(doc.statusLabel,
                  style: context.mlText.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        _IconBtn(
            icon: Icons.visibility_outlined,
            size: 30,
            tooltip: 'View',
            onTap: doc.openable ? onOpen : null),
        const SizedBox(width: 6),
        _IconBtn(
            icon: Icons.download_rounded,
            size: 30,
            tooltip: 'Download',
            onTap: doc.openable ? onOpen : null),
      ]),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final ProfileMetric metric;
  final MlSemantic semantic;
  const _MetricTile({required this.metric, required this.semantic});

  @override
  Widget build(BuildContext context) {
    final s = semantic;
    final m = metric;
    final color = _toneColor(m.tone, s);
    final deltaColor = m.deltaUp ? _green : _red;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        color: s.surfaceSunken,
        border: Border.all(color: s.divider),
        borderRadius: MlShape.radiusLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(m.label,
                  style: context.mlText.labelSmall.copyWith(
                    color: s.textFaint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  )),
            ),
            if (m.delta != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    m.deltaUp
                        ? Icons.arrow_drop_up_rounded
                        : Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: deltaColor),
                Text('${m.delta}',
                    style: context.mlText.code(
                      color: deltaColor,
                      size: 11,
                      weight: FontWeight.w400,
                    )),
              ]),
          ]),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: m.value),
              if (m.unit.isNotEmpty)
                TextSpan(
                    text: m.unit,
                    style: context.mlText.bodyLarge.copyWith(color: s.textMuted)),
            ]),
            style: context.mlText.figure(
              color: s.textStrong,
              size: 32,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(m.sub,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.labelSmall.copyWith(
                color: s.textFaint,
                fontWeight: FontWeight.w400,
              )),
          // An empty series is a metric with no daily history — a snapshot
          // count. It draws nothing rather than a level line, which would be a
          // chart asserting a week of stability that was never measured
          // (P8-28). The space collapses; the number and its label stay.
          if (m.spark.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: CustomPaint(painter: _AreaSparkPainter(m.spark, color)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Gradient-filled area sparkline (the JSX AreaSpark, as a painter).
class _AreaSparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  const _AreaSparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce(math.min), max = data.reduce(math.max);
    final rng = (max - min) == 0 ? 1.0 : (max - min);
    final pts = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(
          i / (data.length - 1) * size.width,
          size.height - ((data[i] - min) / rng) * (size.height - 8) - 4,
        ),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_AreaSparkPainter old) =>
      old.data != data || old.color != color;
}

/// Stylized zone canvas — dashed site ellipse, route path, live marker and
/// mono labels (the mock's inline SVG, with REAL coordinates when known).
class _ZonePainter extends CustomPainter {
  final Color line, path, marker, labelColor, faint;
  final String topLabel, bottomLabel, coords;
  const _ZonePainter({
    required this.line,
    required this.path,
    required this.marker,
    required this.labelColor,
    required this.faint,
    required this.topLabel,
    required this.bottomLabel,
    required this.coords,
  });

  void _dashed(Canvas canvas, Path p, Paint paint, List<double> pattern) {
    final metrics = p.computeMetrics();
    for (final m in metrics) {
      var dist = 0.0;
      var draw = true;
      var i = 0;
      while (dist < m.length) {
        final len = pattern[i % pattern.length];
        if (draw) {
          canvas.drawPath(m.extractPath(dist, dist + len), paint);
        }
        dist += len;
        draw = !draw;
        i++;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ellipse = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w * 0.51, h * 0.55),
          width: w * 0.75,
          height: h * 0.62));
    _dashed(
        canvas,
        ellipse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = line,
        const [5, 6]);

    final route = Path()
      ..moveTo(w * 0.15, h * 0.7)
      ..quadraticBezierTo(w * 0.42, h * 0.36, w * 0.8, h * 0.57);
    _dashed(
        canvas,
        route,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = path.withValues(alpha: 0.7),
        const [4, 5]);

    final center = Offset(w * 0.53, h * 0.52);
    canvas.drawCircle(center, 6, Paint()..color = marker);
    canvas.drawCircle(
        center,
        12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = marker.withValues(alpha: 0.5));

    // `MlType.code` rather than `context.mlText.code`: a CustomPainter has no
    // BuildContext, which is the same reason `MlSemantic.from(Brightness)`
    // exists beside `MlSemantic.of(context)`. It is the only kind of site in
    // this file that cannot reach the theme.
    //
    // The sizes were 9.5 and 10.5 — half-points, which the scale does not have.
    // They survived the `no-half-point-font-size` guard by hiding in a
    // PARAMETER DEFAULT (`{double fs = 9.5}`) and a named argument, so no
    // `fontSize:` literal ever carried the half. 11 and 10 now, which are the
    // labelLarge/labelSmall steps this map's captions belong on.
    void label(String text, Offset at, Color color,
        {double fs = 10, double ls = 0, TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: MlType.code(
                color: color,
                size: fs,
                weight: FontWeight.w400,
                letterSpacing: ls)),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: w - 28);
      tp.paint(canvas, at);
    }

    final topTp = TextPainter(
      text: TextSpan(
          text: topLabel,
          style: MlType.code(
            color: faint,
            size: 10,
            weight: FontWeight.w400,
            letterSpacing: 1.2,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    topTp.paint(canvas, Offset(w - topTp.width - 14, 12));

    label(bottomLabel, Offset(14, h - 36), labelColor, fs: 11);
    label(coords, Offset(14, h - 22), faint, fs: 10);
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.topLabel != topLabel ||
      old.bottomLabel != bottomLabel ||
      old.coords != coords ||
      old.line != line;
}

class _TimelineRow extends StatelessWidget {
  final ProfileActivityItem item;
  final bool isLast;
  final MlSemantic semantic;
  final String timeLabel;
  final VoidCallback? onTap;
  const _TimelineRow({
    required this.item,
    required this.isLast,
    required this.semantic,
    required this.timeLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = semantic;
    final dot = _toneColor(item.tone, s);
    return InkWell(
      onTap: onTap,
      borderRadius: MlShape.radiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              const SizedBox(height: 3),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: dot, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 2),
                        color: s.divider)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: item.bold,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: s.textStrong)),
                        TextSpan(text: item.rest),
                      ]),
                      style: context.mlText.bodyMedium.copyWith(
                        color: s.textBody,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(timeLabel,
                      style: context.mlText.code(
                        color: s.textFaint,
                        size: 11,
                        weight: FontWeight.w400,
                      )),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final MlSemantic semantic;
  final ProfileTone tone;
  final IconData icon;
  final String title;
  final String body;
  final String meta;
  const _FlagTile({
    required this.semantic,
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final s = semantic;
    final c = _toneColor(tone, s);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: s.surfaceSunken,
        border: Border.all(color: s.divider),
        borderRadius: MlShape.radiusMedium,
      ),
      foregroundDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: c, width: 3)),
        borderRadius: MlShape.radiusMedium,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: context.mlText.titleSmall.copyWith(
                  color: s.textStrong,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 5),
            Text(body,
                style: context.mlText.bodySmall.copyWith(
                  color: s.textMuted,
                  height: 1.5,
                )),
            const SizedBox(height: 8),
            Text(meta, style: context.mlText.labelSmall.copyWith(
              color: s.textFaint,
              fontWeight: FontWeight.w400,
            )),
          ]),
        ),
      ]),
    );
  }
}

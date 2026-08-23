import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// One learned route with its current assignments (`list_available_routes`).
class AdminAvailableRoute {
  final String routeId;
  final String routeNumber;
  final String? commodity;
  final String? loadingPoint;
  final String? offloadingPoint;
  final String? paymentTerms;
  final String? tons;
  final String? numTrucks;
  final String? supplierName;
  final String? buyerName;
  final DateTime createdAt;
  final String? assignedCompanies;

  /// Agreed gate-out-to-offload time for this route, in hours. Null means no
  /// expectation has been agreed, and every trip on the route is unjudgeable
  /// for on-time — see `routes.expected_transit_hours`.
  final double? expectedTransitHours;

  const AdminAvailableRoute({
    required this.routeId,
    required this.routeNumber,
    required this.createdAt,
    this.commodity,
    this.loadingPoint,
    this.offloadingPoint,
    this.paymentTerms,
    this.tons,
    this.numTrucks,
    this.supplierName,
    this.buyerName,
    this.assignedCompanies,
    this.expectedTransitHours,
  });

  String get routeLabel => '${loadingPoint ?? '—'} → ${offloadingPoint ?? '—'}';

  /// "18 h" / "1.5 h", or null when nothing has been agreed.
  String? get transitLabel {
    final h = expectedTransitHours;
    if (h == null) return null;
    final whole = h == h.roundToDouble();
    return '${whole ? h.toStringAsFixed(0) : h.toStringAsFixed(1)} h';
  }

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory AdminAvailableRoute.fromJson(Map<String, dynamic> j) =>
      AdminAvailableRoute(
        routeId: j['route_id'] as String,
        routeNumber: (j['route_number'] as String?) ?? '—',
        commodity: _s(j['commodity']),
        loadingPoint: _s(j['loading_point']),
        offloadingPoint: _s(j['offloading_point']),
        paymentTerms: _s(j['payment_terms']),
        tons: _s(j['tons']),
        numTrucks: _s(j['num_trucks']),
        supplierName: _s(j['supplier_name']),
        buyerName: _s(j['buyer_name']),
        createdAt: DateTime.parse(j['created_at'] as String),
        assignedCompanies: _s(j['assigned_companies']),
        expectedTransitHours: (j['expected_transit_hours'] as num?)?.toDouble(),
      );
}

final adminAvailableRoutesProvider =
    FutureProvider.autoDispose<List<AdminAvailableRoute>>((ref) async {
      final rows = await SupabaseConfig.client.rpc('list_available_routes');
      return (rows as List)
          .map(
            (e) => AdminAvailableRoute.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    });

/// Buyer + mine companies for the assignment picker.
final requesterCompaniesProvider =
    FutureProvider.autoDispose<
      List<({String id, String name, String orgType})>
    >((ref) async {
      return ref.watch(requestServiceProvider).listRequesterCompanies();
    });

/// Available routes — the learned, reusable routes (CLAUDE.md §4). The admin
/// assigns a route to a requesting org (optionally permanently); it then
/// appears on that org's Requests screen under "Available routes" and
/// auto-fills the Request Route form when selected.
class AvailableRoutesScreen extends ConsumerStatefulWidget {
  const AvailableRoutesScreen({super.key});

  @override
  ConsumerState<AvailableRoutesScreen> createState() =>
      _AvailableRoutesScreenState();
}

/// Dialog result meaning "withdraw the expectation". A sentinel rather than
/// null, because null is already how the dialog says "cancelled" — and sending
/// a withdrawal when the admin dismissed the dialog would silently unset a
/// route's yardstick.
const Object _clearExpectation = Object();

class _AvailableRoutesScreenState extends ConsumerState<AvailableRoutesScreen> {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  bool _busy = false;

  /// The ordered check the super global admin walks before an assignment is
  /// actually made. Three steps, deliberately: **re-check → tick → confirm.**
  ///
  /// It mirrors the dispatch due-diligence gate in `request_review_screen`
  /// (§4) because the stake is comparable. An assigned route is what the
  /// requesting org then **pre-fills a transportation request from**, so a
  /// wrong assignment does not stop at this screen — it walks into a real
  /// request under the wrong org's name, and until now it could not even be
  /// undone (see [_unassign]).
  ///
  /// Step 1 is a re-read of everything being assigned, not a bare "are you
  /// sure": a confirmation that shows nothing is one people learn to click
  /// through. Step 2 is the explicit green tick. Step 3 names the org.
  Future<bool> _assignDueDiligenceGate({
    required AdminAvailableRoute route,
    required String targetName,
    required bool permanent,
  }) async {
    final checked = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check this again before assigning'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Go through every line below once more and make sure it is '
                'correct. Once assigned, this org uses it to pre-fill a real '
                'transportation request.',
                style: context.mlText.bodyMedium.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _gateRow('Route', route.routeNumber),
              _gateRow('Route', route.routeLabel),
              _gateRow('Commodity', route.commodity),
              _gateRow('Mine', route.supplierName),
              _gateRow('Payment terms', route.paymentTerms),
              _gateRow('Tons', route.tons),
              _gateRow('Trucks', route.numTrucks),
              _gateRow('Assign to', targetName),
              _gateRow('Permanent', permanent ? 'Yes' : 'No'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I have checked everything'),
          ),
        ],
      ),
    );
    if (checked != true || !mounted) return false;

    if (await _assignTickDialog() != true || !mounted) return false;

    if (await _confirm(
              'Are you 100% sure all of the information is correct?',
            ) !=
            true ||
        !mounted) {
      return false;
    }

    if (await _confirm(
          'Are you sure you want to assign ${route.routeNumber} to '
          '"$targetName"?',
          confirmLabel: 'Assign',
        ) !=
        true) {
      return false;
    }
    return true;
  }

  /// One labelled line of the re-check step.
  Widget _gateRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.mlText.bodyMedium.copyWith(
                color: MlSemantic.of(context).textFaint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String question, {String confirmLabel = 'Yes'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// The green tick, same wording and colour as the dispatch gate.
  Future<bool?> _assignTickDialog() {
    var ticked = false;
    final green = MlTone.done.colors(Theme.of(context).brightness).fg;
    return showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: green,
            value: ticked,
            onChanged: (v) => setLocal(() => ticked = v ?? false),
            title: const Text(
              'Due diligence done correctly, accurately and accepted',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: ticked ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  /// Remove an org's assignment of this route.
  ///
  /// `unassign_route_from_company` has existed since available routes shipped
  /// and had **no call site anywhere in the app** — the admin could assign a
  /// route to an org and then had no way to take it back, including after
  /// assigning it to the wrong one. The RPC enforces platform-admin itself.
  ///
  /// The assignee list is read straight from `route_assignments` rather than
  /// from `list_available_routes`, which returns only a display string
  /// (`"Atlas Buyer Group (permanent), …"`) with no company ids to act on.
  /// `route_assignments_select` already admits the platform admin.
  Future<void> _unassign(AdminAvailableRoute route) async {
    setState(() => _busy = true);
    List<({String companyId, String name, bool permanent})> assigned;
    try {
      final rows = await SupabaseConfig.client
          .from('route_assignments')
          .select('company_id, permanent, companies!inner(company_name)')
          .eq('route_id', route.routeId);
      assigned = [
        for (final r in rows)
          (
            companyId: r['company_id'] as String,
            name: ((r['companies'] as Map?)?['company_name'] as String?) ?? '—',
            permanent: (r['permanent'] as bool?) ?? false,
          ),
      ];
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    if (assigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${route.routeNumber} is not assigned.')),
      );
      return;
    }

    final companyId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unassign ${route.routeNumber}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The org stops seeing this under "Available routes". Requests '
                'it has already submitted are not affected.',
                style: context.mlText.bodyMedium.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final a in assigned)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.name),
                  subtitle: a.permanent ? const Text('Permanent') : null,
                  trailing: const Icon(Icons.link_off_outlined),
                  onTap: () => Navigator.of(ctx).pop(a.companyId),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (companyId == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await SupabaseConfig.client.rpc(
        'unassign_route_from_company',
        params: {'p_route_id': route.routeId, 'p_company_id': companyId},
      );
      ref.invalidate(adminAvailableRoutesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${route.routeNumber} unassigned.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(AdminAvailableRoute route) async {
    final companies =
        ref.read(requesterCompaniesProvider).valueOrNull ?? const [];
    if (companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No buyer/mine companies loaded yet.')),
      );
      return;
    }

    String? companyId;
    var permanent = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
          title: Text('Assign ${route.routeNumber}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${route.routeLabel} · ${route.commodity ?? '—'}\n'
                  'The org will see this under "Available routes" and can use '
                  'it to pre-fill a transportation request.',
                  style: context.mlText.bodyMedium.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: companyId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign to (buyer or mine/supplier)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in companies)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.name} · ${c.orgType == 'mineSupplier' ? 'Mine' : 'Buyer'}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => companyId = v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Permanent assignment'),
                  value: permanent,
                  onChanged: (v) => setState(() => permanent = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: companyId == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || companyId == null) return;
    if (!mounted) return;

    final targetName = companies
        .firstWhere(
          (c) => c.id == companyId,
          orElse: () => (id: companyId!, name: companyId!, orgType: ''),
        )
        .name;

    // Assigning is what the requesting org then pre-fills its transportation
    // request from, so a wrong assignment propagates into a real request.
    // Same ordered gate as dispatch (§4), asked for by the client 2026-08-15.
    if (!await _assignDueDiligenceGate(
      route: route,
      targetName: targetName,
      permanent: permanent,
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      await SupabaseConfig.client.rpc(
        'assign_route_to_company',
        params: {
          'p_route_id': route.routeId,
          'p_company_id': companyId,
          'p_permanent': permanent,
        },
      );
      ref.invalidate(adminAvailableRoutesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${route.routeNumber} assigned.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Agree (or clear) the gate-out-to-offload time this route's trips are
  /// judged against. Only a platform admin may set it — the RPC enforces that;
  /// this dialog is the UX for it.
  Future<void> _setTransitExpectation(AdminAvailableRoute route) async {
    final controller = TextEditingController(
      text: route.expectedTransitHours == null
          ? ''
          : route.transitLabel!.replaceAll(' h', ''),
    );
    String? error;

    final hours = await showDialog<Object?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
          title: Text('Transit expectation · ${route.routeNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How long this haul should take from gate-out at '
                '${route.loadingPoint ?? 'the mine'} to offloading at '
                '${route.offloadingPoint ?? 'the destination'}.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'A trip counts as on time when it offloads within this many '
                'hours of leaving the mine. Waiting to load is not counted — '
                'that is the mine\'s queue, reported as turnaround.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Hours',
                  hintText: 'e.g. 18',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
              const SizedBox(height: 10),
              Text(
                route.expectedTransitHours == null
                    ? 'Not agreed yet — this route\'s trips show no on-time '
                          'measure until you set one.'
                    : 'Clear the field to withdraw the expectation; the '
                          'route\'s trips go back to showing no measure.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                // Empty means "withdraw", which is a real action, not an error.
                if (raw.isEmpty) {
                  Navigator.pop(dialogContext, _clearExpectation);
                  return;
                }
                final parsed = double.tryParse(raw);
                if (parsed == null || parsed <= 0 || parsed > 720) {
                  setDialogState(
                    () => error = 'Enter between 0 and 720 hours.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (hours == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await SupabaseConfig.client.rpc(
        'set_route_transit_expectation',
        params: {
          'p_route_id': route.routeId,
          'p_hours': hours == _clearExpectation ? null : hours,
        },
      );
      ref.invalidateIfMounted(adminAvailableRoutesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hours == _clearExpectation
                  ? '${route.routeNumber}: transit expectation withdrawn.'
                  : '${route.routeNumber}: on time means offloading within '
                        '$hours h of gate-out.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(adminAvailableRoutesProvider);
    // Warm the picker so the assign dialog opens instantly.
    ref.watch(requesterCompaniesProvider);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Available routes',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'learned route'),
            description:
                'Learned routes from every dispatch. Assign one to a '
                'buyer or mine — it appears on their Requests screen and '
                'pre-fills the Request Route form.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(adminAvailableRoutesProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load routes',
              message: friendlyError(e),
            ),
            data: (routes) {
              if (routes.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  decoration: BoxDecoration(
                    color: semantic.surfaceCard,
                    borderRadius: BorderRadius.circular(MlTokens.rXl),
                    border: Border.all(color: semantic.borderCard),
                  ),
                  child: const MlEmptyState(
                    icon: Icons.alt_route_outlined,
                    title: 'No learned routes yet',
                    message:
                        'Routes appear here automatically each time you link '
                        'and dispatch a request.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in routes) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: semantic.surfaceCard,
                        borderRadius: BorderRadius.circular(MlTokens.rXl),
                        border: Border.all(color: semantic.borderCard),
                      ),
                      child: Builder(builder: (context) {
                        // The reference places a card's actions on the right
                        // (docs/design-reference.md §4: notice bar, data rows).
                        // These rode inline after the title in one Wrap, and
                        // Unassign sat alone at the bottom left. Found
                        // 2026-08-23 in the Phase 3 pass. Title group left,
                        // actions right; under 820px the actions drop under
                        // the title — a Wrap, so they wrap rather than clip.
                        final titleGroup = Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              r.routeNumber,
                              style: TextStyle(
                                fontFamily: MlTokens.fontMono,
                                fontWeight: FontWeight.w700,
                                color: semantic.textStrong,
                              ),
                            ),
                            Text(
                              r.routeLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: semantic.textStrong,
                              ),
                            ),
                            if (r.commodity != null)
                              Text(
                                r.commodity!,
                                style: context.mlText.bodyMedium.copyWith(
                                  color: semantic.textFaint,
                                ),
                              ),
                            Text(
                              _dateFmt.format(MlTime.sast(r.createdAt)),
                              style: context.mlText.bodyMedium.copyWith(
                                color: semantic.textFaint,
                              ),
                            ),
                          ],
                        );
                        final actions = <Widget>[
                          MlButton.outline(
                            label: 'Assign to org',
                            icon: Icons.person_add_alt_outlined,
                            compact: true,
                            onPressed: _busy ? null : () => _assign(r),
                          ),
                          MlButton.outline(
                            label: r.expectedTransitHours == null
                                ? 'Set transit time'
                                : 'Transit ${r.transitLabel}',
                            icon: Icons.timer_outlined,
                            compact: true,
                            onPressed:
                                _busy ? null : () => _setTransitExpectation(r),
                          ),
                          // Only offered where there IS an assignment to
                          // remove — the RPC existed with no call site, so an
                          // admin who assigned to the wrong org had no way
                          // back.
                          if (r.assignedCompanies != null)
                            MlButton.outline(
                              label: 'Unassign',
                              icon: Icons.link_off_outlined,
                              compact: true,
                              onPressed: _busy ? null : () => _unassign(r),
                            ),
                        ];
                        final wide = MediaQuery.sizeOf(context).width >= 820;
                        final actionRow = Wrap(
                          alignment:
                              wide ? WrapAlignment.end : WrapAlignment.start,
                          spacing: 8,
                          runSpacing: 8,
                          children: actions,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: titleGroup),
                                  const SizedBox(width: 12),
                                  actionRow,
                                ],
                              )
                            else ...[
                              titleGroup,
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: actionRow),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (r.supplierName != null)
                                  'Mine: ${r.supplierName}',
                                if (r.buyerName != null)
                                  'Requester: ${r.buyerName}',
                                if (r.numTrucks != null)
                                  mlCountText(r.numTrucks, 'truck'),
                                if (r.tons != null) mlCountText(r.tons, 'ton'),
                                if (r.paymentTerms != null) r.paymentTerms!,
                              ].join(' · '),
                              style: context.mlText.bodyMedium.copyWith(
                                color: semantic.textFaint,
                              ),
                            ),
                            if (r.assignedCompanies != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Assigned to: ${r.assignedCompanies}',
                                style: context.mlText.titleSmall.copyWith(
                                  color: semantic.textBody,
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

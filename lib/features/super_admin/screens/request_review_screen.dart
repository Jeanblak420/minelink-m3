import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/request_attachment_chips.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Representative review queue (§8.3): list of buyer requests → full detail →
/// send back / decline / accept → due-diligence + transporter multi-select →
/// confirm dispatch. [requestType] = transportation | product | buyer.
class RequestReviewScreen extends ConsumerStatefulWidget {
  final String requestType;

  /// For the transportation queue only: 'mine' | 'buyer' splits the inbox by
  /// the requesting org's type (§4 Request 1); null shows both.
  final String? origin;

  const RequestReviewScreen({
    super.key,
    this.requestType = 'transportation',
    this.origin,
  });

  @override
  ConsumerState<RequestReviewScreen> createState() =>
      _RequestReviewScreenState();
}

class _RequestReviewScreenState extends ConsumerState<RequestReviewScreen> {
  String? _selectedId;
  String _filter =
      'all'; // routes queue status filter (design AdminRequests tabs)
  final Set<String> _selectedTransporters = {};
  String? _selectedSupplier;
  double? _agreedPrice; // ZAR per ton (admin input)
  double? _adminMargin; // ZAR per ton (admin input)
  bool _busy = false;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  String get _title {
    switch (widget.requestType) {
      case 'product':
        return 'Requested product';
      case 'buyer':
        return 'Requested buyers';
      default:
        return switch (widget.origin) {
          'mine' => 'Mine/Supplier transportation requests',
          'buyer' => 'Buyer transportation requests',
          _ => 'Requested routes',
        };
    }
  }

  String get _subtitle {
    switch (widget.requestType) {
      case 'product':
        return 'Buyers requesting new mineral products to purchase on the platform.';
      case 'buyer':
        return 'Mines asking MineLink to connect them with additional buyers for their minerals.';
      default:
        return switch (widget.origin) {
          'mine' =>
            'Transportation requests raised by mines/suppliers, awaiting review and dispatch.',
          'buyer' =>
            'Transportation requests raised by buyers, awaiting review and dispatch.',
          _ => 'Requests awaiting review and dispatch.',
        };
    }
  }

  IconData get _icon {
    switch (widget.requestType) {
      case 'product':
        return Icons.inventory_2_outlined;
      case 'buyer':
        return Icons.group_add_outlined;
      default:
        return Icons.alt_route_rounded;
    }
  }

  /// Request-type hue, on the SAME three tones as org types — which is not a
  /// coincidence: each request type is named for who raises it. A *product*
  /// request comes from a buyer (violet), a *buyer* request comes from a mine
  /// (amber), and a transportation request goes to a transporter (cyan). That
  /// is exactly how the reference dashboard colours its three request tiles.
  Color get _accent => _accentOf(context);

  Color _accentOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return switch (widget.requestType) {
      'product' => MlOrgTone.buyer.colors(brightness).fg,
      'buyer' => MlOrgTone.mineSupplier.colors(brightness).fg,
      _ => MlOrgTone.transporter.colors(brightness).fg,
    };
  }

  /// Per-type row icon (design uses local_shipping in the AdminRequests table).
  IconData get _rowIcon {
    switch (widget.requestType) {
      case 'product':
        return Icons.inventory_2_outlined;
      case 'buyer':
        return Icons.group_add_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  /// Only the routes queue gets the design's status filter tabs.
  bool get _isRoutes => widget.requestType == 'transportation';

  static String _statusKey(RequestStatus s) => s.wire;

  void _refresh() =>
      ref.invalidate(adminRequestQueueProvider(widget.requestType));

  Future<void> _act(Future<void> Function() op, String okMsg) async {
    setState(() => _busy = true);
    try {
      await op();
      _refresh();
      if (mounted) _snack(okMsg);
    } catch (e) {
      if (mounted) _snack('Failed. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminRequestQueueProvider(widget.requestType));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load queue',
        message: friendlyError(e),
      ),
      data: (allRequests) {
        // Split transportation inbox by requesting-org type (§4 Request 1).
        final requests = switch (widget.origin) {
          'mine' => allRequests.where((r) => r.isFromMine).toList(),
          'buyer' => allRequests.where((r) => !r.isFromMine).toList(),
          _ => allRequests,
        };
        final selected = _selectedId == null
            ? null
            : requests.where((r) => r.id == _selectedId).firstOrNull;
        final visible = (_isRoutes && _filter != 'all')
            ? requests.where((r) => _statusKey(r.status) == _filter).toList()
            : requests;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.10),
                      borderRadius: MlShape.radiusMedium,
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(_icon, size: 19, color: _accent),
                  ),
                  const SizedBox(width: 12),
                  // `Expanded`, and no `Spacer`.
                  //
                  // This was a bare `Text` — a NON-FLEX child of a `Row`, which
                  // Flutter lays out against UNBOUNDED width (CLAUDE.md §10.4,
                  // the first rule in the list). So the title took its natural
                  // width whatever the window was, and "Mine/Supplier transport
                  // requests" at the 20px editorial rung ran **157px** past a
                  // 412px phone. Measured 2026-08-20, the first time any of the
                  // four request inboxes was rendered.
                  //
                  // The `Spacer` that used to push the refresh button right is
                  // gone with it: two flex children would split the free space
                  // between them, which is the §10.4 sibling fault — the title
                  // would stop at half the row and the button would land in the
                  // middle. `Expanded` on the long child does both jobs.
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.editorialMedium.copyWith(
                        color: MlSemantic.of(context).textStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _NewBadge(
                    count: requests
                        .where((r) => r.status.awaitingReview)
                        .length,
                    color: _accent,
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle,
                style: context.mlText.bodyMedium.copyWith(
                  color: MlSemantic.of(context).textFaint,
                ),
              ),
              const SizedBox(height: 16),
              if (_isRoutes) _filterTabs(context, requests),
              _queueCard(context, visible),
              if (selected != null) ...[
                const SizedBox(height: 24),
                _DetailPanel(
                  request: selected,
                  dateFmt: _dateFmt,
                  selectedTransporters: _selectedTransporters,
                  selectedSupplier: _selectedSupplier,
                  busy: _busy,
                  onPricingChanged: (a, m) {
                    _agreedPrice = a;
                    _adminMargin = m;
                  },
                  onToggleTransporter: (id) => setState(() {
                    _selectedTransporters.contains(id)
                        ? _selectedTransporters.remove(id)
                        : _selectedTransporters.add(id);
                  }),
                  onSelectSupplier: (id) =>
                      setState(() => _selectedSupplier = id),
                  onSendBack: () async {
                    final notes = await _askNotes(context);
                    if (notes == null) return;
                    await _act(
                      () => ref
                          .read(requestServiceProvider)
                          .review(selected.id, 'sent_back', notes: notes),
                      'Sent back to the requester for revision.',
                    );
                  },
                  onDecline: () => _act(
                    () => ref
                        .read(requestServiceProvider)
                        .review(selected.id, 'declined'),
                    'Request declined.',
                  ),
                  onAccept: () => _act(
                    () => ref
                        .read(requestServiceProvider)
                        .review(selected.id, 'approved'),
                    'Approved — now link the parties.',
                  ),
                  onDispatch: () => _linkAndDispatch(selected),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Design AdminRequests status filter tabs (All / New / Under review /
  /// Sent back / Accepted) with live counts. Routes queue only.
  Widget _filterTabs(
    BuildContext context,
    List<TransportationRequest> requests,
  ) {
    int countOf(String key) => key == 'all'
        ? requests.length
        : requests.where((r) => _statusKey(r.status) == key).length;
    const tabs = <List<String>>[
      ['all', 'All'],
      ['requested', 'New'],
      ['resubmitted', 'Resubmitted'],
      ['sent_back', 'Sent back'],
      ['approved', 'Approved'],
      ['linked', 'Linked'],
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in tabs)
            _FilterTab(
              label: t[1],
              count: countOf(t[0]),
              selected: _filter == t[0],
              accent: _accent,
              onTap: () => setState(() => _filter = t[0]),
            ),
        ],
      ),
    );
  }

  /// Single card wrapping the queue — divider-separated rows (design's
  /// `Card padding={22}` with `borderBottom: divider` rows), or the empty state.
  Widget _queueCard(BuildContext context, List<TransportationRequest> visible) {
    final s = MlSemantic.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: s.borderCard),
        boxShadow: MlTokens.shadowSm,
      ),
      padding: visible.isEmpty
          ? const EdgeInsets.symmetric(vertical: 44, horizontal: 20)
          : const EdgeInsets.symmetric(horizontal: 22),
      child: visible.isEmpty
          ? const MlEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Queue is clear',
              message: 'No requests in this queue yet.',
            )
          : Column(
              children: [
                for (int i = 0; i < visible.length; i++)
                  _row(context, visible[i], last: i == visible.length - 1),
              ],
            ),
    );
  }

  Widget _row(
    BuildContext context,
    TransportationRequest r, {
    required bool last,
  }) {
    final s = MlSemantic.of(context);
    final selected = r.id == _selectedId;
    final summary = [
      // Say "requester unknown" rather than silently dropping the line. A card
      // with no "From …" is how every mine-raised request looked while the
      // admin queue joined the requester through the wrong foreign key, and
      // nothing on screen said anything was missing.
      'From ${r.requesterCompany?.name ?? 'an unidentified company'}',
      if (r.tonsAvailable != null) '${r.tonsAvailable} tons',
      if (!_isRoutes && r.offloadingPoint != null) '→ ${r.offloadingPoint}',
      if (r.numSlots != null) '${r.numSlots} trucks',
      if (r.distance != null) r.distance,
      if (r.rate != null) r.rate,
      if (r.paymentTerms != null) r.paymentTerms,
      if (_isRoutes && r.commodity != null) r.commodity,
    ].whereType<String>().join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _selectedId = selected ? null : r.id;
          _selectedTransporters.clear();
          // Start from what the record already knows. A mine that raised the
          // request IS the supplier, and an already-linked request has one on
          // file — the admin was previously shown an unsorted list of every
          // mine on the platform with nothing highlighted, and had to know
          // which of the thirteen had just written to them.
          _selectedSupplier = selected
              ? null
              : r.supplierCompanyId ??
                  (r.isFromMine ? r.requestingCompanyId : null);
          _agreedPrice = null;
          _adminMargin = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.06) : null,
            border: last ? null : Border(bottom: BorderSide(color: s.divider)),
          ),
          child: Row(
            children: [
              MlIconWell(
                icon: _rowIcon,
                tone: MlTone.accent,
                size: 42,
                radius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (widget.requestType) {
                        'product' => r.commodity ?? 'Product request',
                        'buyer' =>
                          r.commodity != null
                              ? '${r.commodity} · buyers'
                              : 'Buyer request',
                        _ =>
                          '${r.loadingPoint ?? '—'} → ${r.offloadingPoint ?? '—'}',
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.titleMedium.copyWith(
                        color: s.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary.isEmpty ? 'No details' : summary,
                      style: context.mlText.bodyMedium.copyWith(
                        color: s.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: r.status),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: s.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  /// The note that goes back to whoever raised the request.
  ///
  /// ⚠ Pop with `dialogContext`, never with the screen's `context`. The whole
  /// console is a GoRouter `ShellRoute` (`app_router.dart:1292`), so the screen
  /// sits under the shell's own `Navigator` while `showDialog` pushes onto the
  /// ROOT one. Popping with the screen's context therefore removed the *page* —
  /// the console went white, with no exception anywhere and the request left
  /// untouched. Both buttons did it, which is why "Cancel" blanked the app too.
  /// See `test/widgets/dialog_pops_the_dialog_test.dart`.
  Future<String?> _askNotes(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Named for the actual requester: mines and suppliers raise transport
        // and "requested buyers" requests too, and telling one of them the note
        // is going "to buyer" is simply wrong.
        title: Text('Send back to ${_requesterLabel()}'),
        content: ConstrainedBox(
          // Without a width the AlertDialog grows with the text — 289 px empty,
          // 1344 px of a 1424 px viewport once the admin has typed a sentence.
          constraints: const BoxConstraints(maxWidth: 460, minWidth: 380),
          child: TextField(
            controller: ctrl,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'What needs to change?',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              ctrl.text.trim().isEmpty ? ' ' : ctrl.text.trim(),
            ),
            child: const Text('Send back'),
          ),
        ],
      ),
    );
  }

  /// Who the current request came from, for copy that addresses them.
  String _requesterLabel() {
    final r = _selectedId == null
        ? null
        : ref
            .read(adminRequestQueueProvider(widget.requestType))
            .valueOrNull
            ?.where((x) => x.id == _selectedId)
            .firstOrNull;
    if (r == null) return 'the requester';
    return switch (r.requesterOrgType) {
      'mineSupplier' => 'the mine/supplier',
      'buyer' => 'the buyer',
      'transporter' => 'the transporter',
      _ => 'the requester',
    };
  }

  Future<void> _linkAndDispatch(TransportationRequest req) async {
    final supplier = _selectedSupplier;
    final transporters = _selectedTransporters.toList();
    final agreed = _agreedPrice;
    final margin = _adminMargin;
    if (supplier == null) {
      _snack('Select the supplying mine first.');
      return;
    }
    if (transporters.isEmpty) {
      _snack('Select at least one transporter.');
      return;
    }
    if (agreed == null || margin == null) {
      _snack('Enter the agreed price per ton and your margin.');
      return;
    }
    if (margin > agreed) {
      _snack('Your margin cannot exceed the agreed price.');
      return;
    }

    final all = ref.read(transporterCompaniesProvider(null)).value ?? const [];
    final names = all
        .where((t) => transporters.contains(t.id))
        .map((t) => t.name)
        .toList();
    final namesLabel = names.isEmpty
        ? mlCount(transporters.length, 'transporter')
        : names.join(', ');

    final allMines = ref.read(mineCompaniesProvider(null)).value ?? const [];
    final mineName = allMines
        .where((m) => m.id == supplier)
        .map((m) => m.name)
        .firstWhere((_) => true, orElse: () => supplier);

    final ok = await _runDueDiligenceGate(
      req: req,
      transporterPrice: agreed - margin,
      transporterNames: namesLabel,
      mineName: mineName,
    );
    if (ok != true) return;

    await _act(
      () => ref
          .read(requestServiceProvider)
          .linkAndDispatch(req.id, supplier, agreed, margin, transporters),
      'Linked & dispatched to $namesLabel.',
    );
  }

  /// The ordered due-diligence gate (§4): preview → correct? → tick due
  /// diligence → 100% sure? → final named send.
  Future<bool> _runDueDiligenceGate({
    required TransportationRequest req,
    required double transporterPrice,
    required String transporterNames,
    required String mineName,
  }) async {
    final hours = req.operatingHours24h
        ? '24 hours'
        : [
            req.operatingStart,
            req.operatingEnd,
          ].whereType<String>().join(' – ');

    final preview = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preview — what the transporter receives'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _previewRow('Commodity', req.commodity),
              _previewRow('Loading point', req.loadingPoint),
              _previewRow('Offloading point', req.offloadingPoint),
              _previewRow('Tons', req.tonsAvailable),
              _previewRow('Trucks required', req.numSlots),
              _previewRow('Payment terms', req.paymentTerms),
              _previewRow('Operational hours', hours.isEmpty ? null : hours),
              // An operating condition the transporter is agreeing to, so it
              // belongs in the thing they are shown before they agree.
              _previewRow(
                'Seals',
                req.sealRequired
                    ? 'Required — every load needs seal numbers and photos'
                    : 'Not required',
              ),
              _previewRow(
                'Price per ton',
                'R ${transporterPrice.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 10),
              Text(
                'The transporter never sees your margin — only this price.',
                style: context.mlText.bodySmall.copyWith(
                  color: MlSemantic.of(context).textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve and send'),
          ),
        ],
      ),
    );
    if (preview != true) return false;

    if (await _confirm(
          "Are you sure the information you're sending to the Transporter is correct?",
        ) !=
        true) {
      return false;
    }

    if (await _dueDiligenceTickDialog() != true) return false;

    if (await _confirm(
          'Are you 100% sure all of the information is correct?',
        ) !=
        true) {
      return false;
    }

    if (await _confirm(
          'Are you sure you want to send this to $transporterNames for mine "$mineName"?',
          confirmLabel: 'Send',
        ) !=
        true) {
      return false;
    }

    return true;
  }

  Future<bool?> _confirm(String question, {String confirmLabel = 'Yes'}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<bool?> _dueDiligenceTickDialog() {
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

  Widget _previewRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: MlSemantic.of(context).textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "N new" pill with a leading dot — the design's request-queue accent.
class _NewBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _NewBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: MlShape.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count new',
            style: context.mlText.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill filter tab with a live count chip (design AdminRequests tabs).
class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accent : s.surfaceCard,
            borderRadius: BorderRadius.circular(MlTokens.rPill),
            border: Border.all(color: selected ? accent : s.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.mlText.titleSmall.copyWith(
                  color: selected ? MlTokens.inkOnFill : s.textBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? MlTokens.overlayLight.withValues(alpha: 0.22)
                      : s.surfaceSunken,
                  borderRadius: MlShape.pill,
                ),
                child: Text(
                  '$count',
                  style: context.mlText.code(
                    color: selected ? MlTokens.inkOnFill : s.textMuted,
                    size: 12,
                    weight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  final TransportationRequest request;
  final DateFormat dateFmt;
  final Set<String> selectedTransporters;
  final String? selectedSupplier;
  final bool busy;
  final void Function(double? agreed, double? margin) onPricingChanged;
  final ValueChanged<String> onToggleTransporter;
  final ValueChanged<String> onSelectSupplier;
  final VoidCallback onSendBack;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final VoidCallback onDispatch;

  const _DetailPanel({
    required this.request,
    required this.dateFmt,
    required this.selectedTransporters,
    required this.selectedSupplier,
    required this.busy,
    required this.onPricingChanged,
    required this.onToggleTransporter,
    required this.onSelectSupplier,
    required this.onSendBack,
    required this.onDecline,
    required this.onAccept,
    required this.onDispatch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final r = request;
    final hours = r.operatingHours24h
        ? '24 hours'
        : [r.operatingStart, r.operatingEnd].whereType<String>().join(' – ');
    final start = r.isOngoing
        ? (r.startingDate != null
              ? 'Ongoing from ${dateFmt.format(r.startingDate!)}'
              : 'Ongoing')
        : (r.startingDate != null ? dateFmt.format(r.startingDate!) : '—');

    final approved = r.status == RequestStatus.approved;
    final linked = r.status == RequestStatus.linked;
    final canReview =
        r.status.awaitingReview || r.status == RequestStatus.sentBack;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (r.requestType) {
                    'product' => r.commodity ?? 'Product request',
                    'buyer' =>
                      r.commodity != null
                          ? '${r.commodity} · buyers'
                          : 'Buyer request',
                    _ =>
                      '${r.loadingPoint ?? '—'} → ${r.offloadingPoint ?? '—'}',
                  },
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(status: r.status),
            ],
          ),
          if (r.requesterCompany != null) ...[
            const SizedBox(height: 8),
            _RequesterLine(company: r.requesterCompany!),
          ],
          const SizedBox(height: 16),
          // Show the fields THIS request type actually has.
          //
          // Every type used to render the transportation grid, so a product
          // request came up with nine columns reading "—" for questions the
          // buyer was never asked (Distance, Rate, Transaction, Product specs,
          // Diesel, Operational hours, Contract duration, Trucks, Starting
          // date). CLAUDE.md §4 asks for "a clean, non-editable rendering of
          // exactly what was submitted", and two of those labels were not
          // merely noise but wrong: a buyer's *tons required* was captioned
          // "Tons available", which reads the trade backwards, and a product
          // request has no "Route notes".
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: switch (r.requestType) {
              'product' => [
                  _kv('Product', r.commodity),
                  _kv('Tons required', r.tonsAvailable),
                  _kv('Payment terms', r.paymentTerms),
                  _kv(
                    'Price / ton',
                    r.pricePerTon == null
                        ? null
                        : 'R ${r.pricePerTon!.toStringAsFixed(2)}',
                  ),
                  _kv('Preferred destination', r.offloadingPoint),
                ],
              'buyer' => [
                  _kv('Mineral supplied', r.commodity),
                  _kv('Tons available', r.tonsAvailable),
                  _kv('Product specs', r.productSpecifications),
                  _kv('Payment terms', r.paymentTerms),
                  _kv(
                    'Price / ton',
                    r.pricePerTon == null
                        ? null
                        : 'R ${r.pricePerTon!.toStringAsFixed(2)}',
                  ),
                  _kv('Transaction', r.transactionKind),
                  // The one field that says WHERE the ore is. It was captured
                  // by the map picker and then shown on no admin screen.
                  _ProductLocation(value: r.loadingPoint),
                ],
              _ => [
                  _kv('Commodity', r.commodity),
                  _kv('Distance', r.distance),
                  _kv('Rate', r.rate),
                  _kv(
                    'Price / ton',
                    r.pricePerTon == null
                        ? null
                        : 'R ${r.pricePerTon!.toStringAsFixed(2)}',
                  ),
                  _kv('Transaction', r.transactionKind),
                  _kv('Product specs', r.productSpecifications),
                  _kv('Payment terms', r.paymentTerms),
                  _kv('Diesel', r.diesel),
                  _kv('Operational hours', hours.isEmpty ? '—' : hours),
                  _kv('Tons available', r.tonsAvailable),
                  _kv('Contract duration', r.contractDuration),
                  _kv('Number of Trucks Required', r.numSlots),
                  _kv('Seals', r.sealRequired ? 'Required' : 'Not required'),
                  _kv('Starting date', start),
                  if (!r.isOngoing && r.endingDate != null)
                    _kv('End date', dateFmt.format(r.endingDate!)),
                ],
            },
          ),
          if (r.routeNotes != null && r.routeNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _kv(r.requestType == 'transportation' ? 'Route notes' : 'Notes',
                r.routeNotes),
          ],
          if (r.labResultPaths.isNotEmpty || r.productImagePath != null) ...[
            const SizedBox(height: 12),
            RequestAttachmentChips(request: r),
          ],
          const Divider(height: 28),

          if (linked) ...[
            Text(
              'This request has been linked — dispatched to the selected '
              'transporters.',
              style: const TextStyle(
                fontFamily: MlTokens.fontSans,
                color: MlTokens.accentHover,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            // A linked request is HISTORY, so this reads the stored record —
            // `r.supplierCompanyId` and the rows in `request_dispatches` — not
            // the local picker state. Those two fields are reset every time a
            // row is opened (they exist to drive an in-progress dispatch), so
            // rendering them here meant every linked request in the console
            // read "Mine: None selected" no matter who it had been linked to.
            Builder(builder: (context) {
              final dispatched =
                  ref.watch(requestDispatchedTransportersProvider(r.id));
              return _SelectedPartiesSummary(
                selectedSupplier: r.supplierCompanyId,
                selectedTransporters:
                    dispatched.valueOrNull ?? const <String>{},
                transportersPending: dispatched.isLoading,
                mines: ref.watch(mineCompaniesProvider(null)),
                transporters: ref.watch(transporterCompaniesProvider(null)),
              );
            }),
          ]
          else if (canReview)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MlButton.tonal(
                  label: 'Send back for revision',
                  icon: Icons.assignment_return_outlined,
                  compact: true,
                  onPressed: busy ? null : onSendBack,
                ),
                MlButton.danger(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  compact: true,
                  onPressed: busy ? null : onDecline,
                ),
                MlButton.go(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  compact: true,
                  onPressed: busy ? null : onAccept,
                ),
              ],
            )
          else if (approved)
            _DispatchStep(
              request: r,
              buyerPreference: r.loadingPoint,
              selectedTransporters: selectedTransporters,
              selectedSupplier: selectedSupplier,
              busy: busy,
              onPricingChanged: onPricingChanged,
              onToggleTransporter: onToggleTransporter,
              onSelectSupplier: onSelectSupplier,
              onDispatch: onDispatch,
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String? v) {
    return SizedBox(
      width: 200,
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                k,
                style: context.mlText.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (v == null || v.isEmpty) ? '—' : v,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The step that turns an ENQUIRY into an order that can actually be hauled.
///
/// A `product` request is a buyer saying what they want to buy; a `buyer`
/// request is a mine asking to be introduced to buyers. Neither carries a
/// loading point, an offloading point or a truck count, and a `buyer` request
/// has no buyer — which is the entire thing it was raised to obtain.
///
/// Until 2026-08-17 approving either one dropped the admin straight into
/// "1 · Supplying mine / 2 · Pricing / 3 · Dispatch", with no way to name a
/// buyer anywhere in the product and nothing to mint a route from. This is the
/// missing step, and `Review & send to transporter` stays disabled until it is
/// complete.
class _OrderTermsStep extends ConsumerStatefulWidget {
  final TransportationRequest request;
  const _OrderTermsStep({required this.request});

  @override
  ConsumerState<_OrderTermsStep> createState() => _OrderTermsStepState();
}

class _OrderTermsStepState extends ConsumerState<_OrderTermsStep> {
  late final TextEditingController _loading =
      TextEditingController(text: widget.request.loadingPoint ?? '');
  late final TextEditingController _offloading =
      TextEditingController(text: widget.request.offloadingPoint ?? '');
  late final TextEditingController _tons =
      TextEditingController(text: widget.request.tonsAvailable ?? '');
  late final TextEditingController _trucks =
      TextEditingController(text: widget.request.numSlots ?? '');
  String? _buyerId;
  bool _saving = false;
  String? _error;

  bool get _needsBuyer =>
      widget.request.requestType == 'buyer' &&
      widget.request.buyerCompanyId == null;

  @override
  void dispose() {
    for (final c in [_loading, _offloading, _tons, _trucks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_needsBuyer && _buyerId == null) {
      setState(() => _error = 'Name the buying company.');
      return;
    }
    if (_loading.text.trim().isEmpty ||
        _offloading.text.trim().isEmpty ||
        _tons.text.trim().isEmpty) {
      setState(() => _error =
          'A loading point, an offloading point and a tonnage are what make '
          'this haulable.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(requestServiceProvider).prepareForLinking(
            widget.request.id,
            buyerCompanyId: _buyerId,
            loadingPoint: _loading.text.trim(),
            offloadingPoint: _offloading.text.trim(),
            tons: _tons.text.trim(),
            numTrucks: _trucks.text.trim().isEmpty ? null : _trucks.text.trim(),
          );
      ref.invalidateIfMounted(
          adminRequestQueueProvider(widget.request.requestType));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Order details saved — now link the parties.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buyers = ref.watch(buyerCompaniesProvider(null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '0 · Complete the order',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _needsBuyer
              ? 'An enquiry is not a haul. Name the buyer this mine is being '
                  'introduced to, and where the load runs from and to.'
              : 'An enquiry is not a haul. Set where the load runs from and to '
                  'before dispatching it.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (_needsBuyer)
          buyers.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load buyers. ${friendlyError(e)}'),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _buyerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Buying company',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final b in list)
                  DropdownMenuItem(value: b.id, child: Text(b.name)),
              ],
              onChanged: (v) => setState(() => _buyerId = v),
            ),
          ),
        if (_needsBuyer) const SizedBox(height: 10),
        _field(_loading, 'Loading point'),
        const SizedBox(height: 10),
        _field(_offloading, 'Offloading point'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _field(_tons, 'Tons')),
            const SizedBox(width: 10),
            Expanded(child: _field(_trucks, 'Number of Trucks Required')),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: context.mlText.bodySmall.copyWith(
            color: cs.error,
          )),
        ],
        const SizedBox(height: 10),
        MlButton.primary(
          label: _saving ? 'Saving…' : 'Save order details',
          icon: Icons.save_outlined,
          compact: true,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
}

/// Where the ore is, on a "Requested buyers" request.
///
/// The mine picks this on a map and it is stored as the universal
/// `https://www.google.com/maps?q=lat,lng` link (or as plain text, which the
/// form also allows). It reached no admin screen at all until 2026-08-17, so
/// the one field that says *where the product stands* was invisible to the
/// person deciding what to do with the request. A pinned location opens; typed
/// text is shown as written.
class _ProductLocation extends StatelessWidget {
  final String? value;
  const _ProductLocation({required this.value});

  static final _coords = RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value?.trim();
    final m = v == null ? null : _coords.firstMatch(v);
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product location',
              style: context.mlText.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              )),
          const SizedBox(height: 2),
          if (v == null || v.isEmpty)
            const Text('—', style: TextStyle(fontWeight: FontWeight.w600))
          else if (m == null)
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600))
          else
            InkWell(
              onTap: () => launchUrl(Uri.parse(v),
                  mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 15, color: cs.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${m.group(1)}, ${m.group(2)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Requested by {company}" — the requesting company's name on every request,
/// clickable to open their full company profile (Close returns here).
class _RequesterLine extends StatelessWidget {
  final RequestCompanyInfo company;
  const _RequesterLine({required this.company});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.business_outlined, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Requested by ',
          style: context.mlText.bodyMedium.copyWith(color: cs.onSurfaceVariant),
        ),
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _CompanyProfileDialog(company: company),
          ),
          child: Text(
            company.name,
            style: context.mlText.titleSmall.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: cs.primary,
            ),
          ),
        ),
        Text(
          ' · ${company.orgTypeLabel}',
          style: context.mlText.bodyMedium.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The requesting company's profile, opened from a request. Close returns to
/// the request untouched.
class _CompanyProfileDialog extends StatelessWidget {
  final RequestCompanyInfo company;
  const _CompanyProfileDialog({required this.company});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: context.mlText.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.business_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(company.name)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            kv('Organisation type', company.orgTypeLabel),
            kv('CEO', company.ceoName),
            kv('WhatsApp', company.whatsappNumber ?? '—'),
            kv('Support email', company.supportEmail ?? '—'),
            kv('Status', company.status ?? '—'),
            kv(
              'Member since',
              company.memberSince == null
                  ? '—'
                  : DateFormat(
                      'dd MMM yyyy',
                    ).format(MlTime.sast(company.memberSince!)),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to request'),
        ),
      ],
    );
  }
}

class _DispatchStep extends ConsumerWidget {
  final TransportationRequest request;
  final String? buyerPreference;
  final Set<String> selectedTransporters;
  final String? selectedSupplier;
  final bool busy;
  final void Function(double? agreed, double? margin) onPricingChanged;
  final ValueChanged<String> onToggleTransporter;
  final ValueChanged<String> onSelectSupplier;
  final VoidCallback onDispatch;

  const _DispatchStep({
    required this.request,
    required this.buyerPreference,
    required this.selectedTransporters,
    required this.selectedSupplier,
    required this.busy,
    required this.onPricingChanged,
    required this.onToggleTransporter,
    required this.onSelectSupplier,
    required this.onDispatch,
  });

  /// A product or buyer enquiry is not a haul yet: it carries no loading point,
  /// no offloading point and no truck count, and a "Requested buyers" enquiry
  /// has no buyer either — the whole reason it was raised. Linking one without
  /// filling those in mints a route the driver cannot be sent on.
  bool get _needsPrep =>
      _missingTerms.isNotEmpty || (request.requestType == 'buyer' &&
          request.buyerCompanyId == null);

  List<String> get _missingTerms => [
        if ((request.loadingPoint ?? '').trim().isEmpty) 'a loading point',
        if ((request.offloadingPoint ?? '').trim().isEmpty)
          'an offloading point',
        if ((request.tonsAvailable ?? '').trim().isEmpty) 'a tonnage',
      ];

  TextStyle? _stepStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);

  /// Names that appear more than once in [names] — used to show an ID hint so
  /// the admin can tell same-named companies apart.
  Set<String> _duplicateNames(List<String> names) {
    final seen = <String>{};
    final dups = <String>{};
    for (final n in names) {
      if (!seen.add(n)) dups.add(n);
    }
    return dups;
  }

  String _shortId(String id) =>
      id.length <= 6 ? id : id.substring(id.length - 6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transporters = ref.watch(transporterCompaniesProvider(null));
    final mines = ref.watch(mineCompaniesProvider(null));
    // Pricing is validated inside the due-diligence gate; the button needs a
    // mine, a transporter, and — for an enquiry — the order terms a request of
    // that type does not carry.
    final canSend = selectedTransporters.isNotEmpty &&
        selectedSupplier != null &&
        !_needsPrep &&
        !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Link the parties', style: _stepStyle(context)),
        const SizedBox(height: 4),
        Text(
          switch (request.requestType) {
            'product' =>
              'This is a product enquiry, not a haul yet. Complete the order, '
                  'pick the supplying mine, set your pricing, then step through '
                  'the due-diligence gate to dispatch.',
            'buyer' =>
              'This mine asked to be introduced to buyers. Name the buyer and '
                  'complete the order, then price it and step through the '
                  'due-diligence gate to dispatch.',
            _ => 'Select the mine, set your pricing, then step through the '
                'due-diligence gate to dispatch.',
          },
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (_needsPrep) ...[
          const Divider(height: 28),
          _OrderTermsStep(request: request),
        ],
        const Divider(height: 28),
        Text('1 · Supplying mine', style: _stepStyle(context)),
        if (buyerPreference != null && buyerPreference!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Buyer asked for: "$buyerPreference"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        mines.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text('Could not load mines. ${friendlyError(e)}'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No mineSupplier companies registered yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            final dupNames = _duplicateNames([for (final m in list) m.name]);
            return Column(
              children: [
                for (final m in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      selectedSupplier == m.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selectedSupplier == m.id
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(m.name),
                    subtitle: dupNames.contains(m.name)
                        ? Text(
                            'ID …${_shortId(m.id)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          )
                        : null,
                    onTap: () => onSelectSupplier(m.id),
                  ),
              ],
            );
          },
        ),
        const Divider(height: 28),
        Text('2 · Pricing (ZAR per ton)', style: _stepStyle(context)),
        const SizedBox(height: 8),
        _PricingFields(onChanged: onPricingChanged),
        const Divider(height: 28),
        Text('3 · Dispatch to transporters', style: _stepStyle(context)),
        const SizedBox(height: 8),
        transporters.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text('Could not load transporters. ${friendlyError(e)}'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'No transporter companies registered yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            final dupNames = _duplicateNames([for (final t in list) t.name]);
            return Column(
              children: [
                for (final t in list)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selectedTransporters.contains(t.id),
                    onChanged: (_) => onToggleTransporter(t.id),
                    title: Text(t.name),
                    subtitle: dupNames.contains(t.name)
                        ? Text(
                            'ID …${_shortId(t.id)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (selectedSupplier != null || selectedTransporters.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SelectedPartiesSummary(
            selectedSupplier: selectedSupplier,
            selectedTransporters: selectedTransporters,
            mines: mines,
            transporters: transporters,
          ),
        ],
        const SizedBox(height: 12),
        MlButton.primary(
          label: busy ? 'Sending…' : 'Review & send to transporter',
          icon: Icons.verified_user_outlined,
          expand: true,
          onPressed: canSend ? onDispatch : null,
        ),
      ],
    );
  }
}

/// Pricing inputs (§4): the admin enters the agreed price per ton and their
/// margin in ZAR; the app derives the transporter's price (agreed − margin) and
/// the admin's cut live. Reports (agreed, margin) up on every edit.
class _SelectedPartiesSummary extends StatelessWidget {
  final String? selectedSupplier;
  final Set<String> selectedTransporters;
  final AsyncValue<List<dynamic>> mines;
  final AsyncValue<List<dynamic>> transporters;

  /// The dispatched-transporter rows are still being fetched.
  ///
  /// Without this an empty set reads as "None selected", so a linked request
  /// would flash the very wrong answer this panel was just fixed to stop
  /// giving, then correct itself a moment later.
  final bool transportersPending;

  const _SelectedPartiesSummary({
    required this.selectedSupplier,
    required this.selectedTransporters,
    required this.mines,
    required this.transporters,
    this.transportersPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final supplierText = selectedSupplier == null
        ? 'None selected'
        : mines.when(
            loading: () => 'Loading…',
            error: (_, __) => 'Unknown mine',
            data: (list) {
              final matches = list.where((m) => m.id == selectedSupplier);
              return matches.isEmpty ? 'Unknown mine' : matches.first.name;
            },
          );
    final transporterText = selectedTransporters.isEmpty
        ? (transportersPending ? 'Loading…' : 'None selected')
        : transporters.when(
            loading: () => 'Loading…',
            error: (_, __) => selectedTransporters.length == 1
                ? 'Unknown transporter'
                : 'Unknown transporters',
            data: (list) {
              final selected = list
                  .where((t) => selectedTransporters.contains(t.id))
                  .map((t) => t.name)
                  .toList();
              return selected.isEmpty
                  ? 'Unknown transporters'
                  : selected.join(', ');
            },
          );

    Widget buildRow(String label, String value) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: context.mlText.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected parties',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          buildRow('Mine', supplierText),
          const SizedBox(height: 8),
          buildRow('Transporters', transporterText),
        ],
      ),
    );
  }
}

class _PricingFields extends StatefulWidget {
  final void Function(double? agreed, double? margin) onChanged;
  const _PricingFields({required this.onChanged});

  @override
  State<_PricingFields> createState() => _PricingFieldsState();
}

class _PricingFieldsState extends State<_PricingFields> {
  final _agreed = TextEditingController();
  final _margin = TextEditingController();

  @override
  void dispose() {
    _agreed.dispose();
    _margin.dispose();
    super.dispose();
  }

  double? get _a => double.tryParse(_agreed.text.trim());
  double? get _m => double.tryParse(_margin.text.trim());

  void _emit() => widget.onChanged(_a, _m);

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final m = _m;
    final over = a != null && m != null && m > a;
    final transporterPrice = (a != null && m != null && !over) ? a - m : null;
    final semantic = MlSemantic.of(context);

    InputDecoration deco(String label) => InputDecoration(
      isDense: true,
      labelText: label,
      prefixText: 'R ',
      border: const OutlineInputBorder(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _agreed,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(_emit),
                decoration: deco('Agreed price / ton'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _margin,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(_emit),
                decoration: deco('Your margin / ton'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: semantic.surfaceSunken,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(color: semantic.borderCard),
          ),
          child: Row(
            children: [
              Expanded(
                child: _readout(
                  context,
                  'Your cut / ton',
                  m == null ? '—' : 'R ${m.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _readout(
                  context,
                  'Transporter price / ton',
                  transporterPrice == null
                      ? '—'
                      : 'R ${transporterPrice.toStringAsFixed(2)}',
                  strong: true,
                ),
              ),
            ],
          ),
        ),
        if (over) ...[
          const SizedBox(height: 6),
          Text(
            'Your margin cannot exceed the agreed price.',
            style: context.mlText.labelMedium.copyWith(
              color: MlTone.error.colors(Theme.of(context).brightness).fg,
            ),
          ),
        ],
      ],
    );
  }

  Widget _readout(
    BuildContext context,
    String label,
    String value, {
    bool strong = false,
  }) {
    final semantic = MlSemantic.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.mlText.bodySmall.copyWith(
          color: semantic.textMuted,
        )),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: MlTokens.fontMono,
            fontSize: strong ? 18 : 15,
            fontWeight: FontWeight.w800,
            color: strong ? MlTokens.accent : semantic.textStrong,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final RequestStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final MlTone tone;
    switch (status) {
      case RequestStatus.approved:
      case RequestStatus.linked:
        tone = MlTone.done;
        break;
      case RequestStatus.declined:
        tone = MlTone.error;
        break;
      case RequestStatus.sentBack:
        tone = MlTone.warn;
        break;
      case RequestStatus.resubmitted:
        tone = MlTone.atMine;
        break;
      case RequestStatus.requested:
        tone = MlTone.transit;
    }
    return MlStatusBadge(label: status.label, tone: tone);
  }
}

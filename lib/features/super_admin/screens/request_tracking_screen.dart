import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/portal/models/request_tracking.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Super-admin "Request's Tracking Logs": platform-wide request tracking with
/// stat cards, filter pills and a full-width table. Rows open a detail dialog
/// with every field in full; truncated cells reveal themselves on hover. All
/// hues come from [MlTokens]/[MlSemantic]/[MlTone].
class RequestTrackingScreen extends ConsumerStatefulWidget {
  const RequestTrackingScreen({super.key});

  @override
  ConsumerState<RequestTrackingScreen> createState() =>
      _RequestTrackingScreenState();
}

enum _TrackFilter { all, requested, linked, done }

enum _SortField { tons, updated }

class _RequestTrackingScreenState extends ConsumerState<RequestTrackingScreen> {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static const _pageSize = 25;

  /// Below this the table scrolls horizontally instead of squashing columns.
  static const _tableMinWidth = 1040.0;

  _TrackFilter _filter = _TrackFilter.all;
  _SortField _sortField = _SortField.updated;
  bool _sortDesc = true;
  int _page = 0;

  // ---- Data shaping -------------------------------------------------------

  bool _isRequested(RequestTrackingRow r) =>
      !r.isCompleted && r.status != 'linked' && r.status != 'approved';

  bool _isLinked(RequestTrackingRow r) =>
      !r.isCompleted && (r.status == 'linked' || r.status == 'approved');

  List<RequestTrackingRow> _visible(List<RequestTrackingRow> rows) {
    final filtered = switch (_filter) {
      _TrackFilter.all => rows.toList(),
      _TrackFilter.requested => rows.where(_isRequested).toList(),
      _TrackFilter.linked => rows.where(_isLinked).toList(),
      _TrackFilter.done => rows.where((r) => r.isCompleted).toList(),
    };
    filtered.sort((a, b) {
      final c = switch (_sortField) {
        _SortField.tons => a.tonsDelivered.compareTo(b.tonsDelivered),
        _SortField.updated => a.updatedAt.compareTo(b.updatedAt),
      };
      return _sortDesc ? -c : c;
    });
    return filtered;
  }

  void _setFilter(_TrackFilter f) => setState(() {
    _filter = f;
    _page = 0;
  });

  void _tapSort(_SortField field) => setState(() {
    if (_sortField == field) {
      _sortDesc = !_sortDesc;
    } else {
      _sortField = field;
      _sortDesc = true;
    }
    _page = 0;
  });

  Future<void> _export(List<RequestTrackingRow> rows) =>
      ReconExporter.pickFormatAndExport(
        context,
        title: "Request's Tracking Logs",
        filenameBase: 'requests_tracking_logs',
        headers: const [
          'Type',
          'Route / product',
          'Requested by',
          'Mine',
          'Transporters',
          'Trips completed',
          'Trips total',
          'Tons',
          'Status',
          'Updated',
        ],
        rows: [
          for (final r in rows)
            [
              r.typeLabel,
              r.routeLabel,
              r.requesterName ?? '—',
              r.supplierName ?? '—',
              r.transporterNames ?? '—',
              '${r.tripsCompleted}',
              '${r.tripsTotal}',
              r.tonsDelivered == 0 ? '' : r.tonsDelivered.toStringAsFixed(2),
              r.isCompleted ? 'Completed' : r.displayStatus,
              _dateFmt.format(MlTime.sast(r.updatedAt)),
            ],
        ],
        filters: {'View': _filter.name.toUpperCase()},
      );

  void _showDetails(RequestTrackingRow r) => showDialog<void>(
    context: context,
    builder: (_) => _RequestDetailsDialog(row: r),
  );

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requestTrackingProvider(null));
    final semantic = MlSemantic.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Header(activeCount: null),
                SizedBox(height: 48),
                Center(child: CircularProgressIndicator()),
                SizedBox(height: 48),
              ],
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Header(activeCount: null),
                const SizedBox(height: 24),
                Text(
                  'Could not load tracking. ${friendlyError(e)}',
                  style: TextStyle(color: semantic.textMuted),
                ),
              ],
            ),
            data: (rows) => _body(context, rows),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<RequestTrackingRow> rows) {
    final requested = rows.where(_isRequested).length;
    final linked = rows.where(_isLinked).length;
    final done = rows.where((r) => r.isCompleted).length;
    final visible = _visible(rows);

    final pageCount = (visible.length / _pageSize).ceil().clamp(1, 999);
    final page = _page.clamp(0, pageCount - 1);
    final pageRows = visible
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(activeCount: rows.length - done),
        const SizedBox(height: 20),
        _statRow(rows.length, requested, linked, done),
        const SizedBox(height: 20),
        _tableCard(
          context,
          all: rows.length,
          requested: requested,
          linked: linked,
          done: done,
          visible: visible,
          pageRows: pageRows,
          page: page,
          pageCount: pageCount,
        ),
      ],
    );
  }

  Widget _statRow(int total, int requested, int linked, int done) {
    final cards = [
      _OpsStatCard(
        icon: Icons.layers_outlined,
        tone: MlTone.neutral,
        label: 'TOTAL REQUESTS',
        value: '$total',
        subLabel: 'on platform',
        onTap: () => _setFilter(_TrackFilter.all),
      ),
      _OpsStatCard(
        icon: Icons.pending_actions_outlined,
        tone: MlTone.atMine,
        label: 'REQUESTED',
        value: '$requested',
        subLabel: 'awaiting linkage',
        onTap: () => _setFilter(_TrackFilter.requested),
      ),
      _OpsStatCard(
        icon: Icons.local_shipping_outlined,
        tone: MlTone.transit,
        label: 'IN PROGRESS',
        value: '$linked',
        subLabel: 'transporter assigned',
        onTap: () => _setFilter(_TrackFilter.linked),
      ),
      _OpsStatCard(
        icon: Icons.verified_outlined,
        tone: MlTone.done,
        label: 'COMPLETED',
        value: '$done',
        subLabel: 'all trips delivered',
        hero: true,
        onTap: () => _setFilter(_TrackFilter.done),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const gap = 14.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: w, child: c)],
        );
      },
    );
  }

  Widget _tableCard(
    BuildContext context, {
    required int all,
    required int requested,
    required int linked,
    required int done,
    required List<RequestTrackingRow> visible,
    required List<RequestTrackingRow> pageRows,
    required int page,
    required int pageCount,
  }) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 920;
                final title = Row(
                  children: [
                    MlIconWell(
                      icon: Icons.track_changes_outlined,
                      tone: MlTone.accent,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Request's Tracking Logs",
                            style: TextStyle(
                              fontSize: MlTokens.fsTitle,
                              fontWeight: FontWeight.w700,
                              color: semantic.textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Every request on the platform, followed to '
                            'completion.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: MlTokens.fsLabel,
                              color: semantic.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterGroup(
                      filter: _filter,
                      all: all,
                      requested: requested,
                      linked: linked,
                      done: done,
                      onChanged: _setFilter,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () =>
                          ref.invalidate(requestTrackingProvider(null)),
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      color: semantic.textMuted,
                    ),
                    const SizedBox(width: 4),
                    _ExportButton(onTap: () => _export(visible)),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actions,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              child: MlEmptyState(
                icon: Icons.track_changes_outlined,
                title: 'Nothing to track yet.',
                message:
                    'Requests appear here as soon as one is submitted — '
                    'as requester, mine or transporter.',
              ),
            )
          else ...[
            // The table fills the card; horizontal scroll only when the
            // viewport is genuinely too narrow for readable columns.
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _tableMinWidth) {
                  return _table(context, pageRows);
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _tableMinWidth,
                    child: _table(context, pageRows),
                  ),
                );
              },
            ),
            _footer(context, visible.length, page, pageCount),
          ],
        ],
      ),
    );
  }

  // ---- Table --------------------------------------------------------------

  static const _colType = 2;
  static const _colRoute = 5;
  static const _colParty = 3;
  static const _colTrips = 2;
  static const _colTons = 2;
  static const _statusWidth = 128.0;
  static const _colUpdated = 2;

  Widget _table(BuildContext context, List<RequestTrackingRow> rows) {
    final semantic = MlSemantic.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: semantic.surfaceSunken,
            border: Border(
              top: BorderSide(color: semantic.divider),
              bottom: BorderSide(color: semantic.divider),
            ),
          ),
          child: Row(
            children: [
              _headCell(context, 'TYPE', flex: _colType),
              _headCell(context, 'ROUTE / PRODUCT', flex: _colRoute),
              _headCell(context, 'REQUESTED BY', flex: _colParty),
              _headCell(context, 'MINE', flex: _colParty),
              _headCell(context, 'TRANSPORTERS', flex: _colParty),
              _headCell(
                context,
                'TRIPS',
                flex: _colTrips,
                align: TextAlign.right,
              ),
              _headCell(
                context,
                'TONS',
                flex: _colTons,
                align: TextAlign.right,
                sort: _SortField.tons,
              ),
              SizedBox(
                width: _statusWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _MicroLabel('STATUS', color: semantic.textFaint),
                ),
              ),
              _headCell(
                context,
                'UPDATED',
                flex: _colUpdated,
                sort: _SortField.updated,
              ),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: semantic.divider),
          _dataRow(context, rows[i]),
        ],
      ],
    );
  }

  Widget _headCell(
    BuildContext context,
    String label, {
    required int flex,
    TextAlign align = TextAlign.left,
    _SortField? sort,
  }) {
    final semantic = MlSemantic.of(context);
    final active = sort != null && _sortField == sort;
    final child = Row(
      mainAxisAlignment: align == TextAlign.right
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        _MicroLabel(
          label,
          color: active ? semantic.textStrong : semantic.textFaint,
        ),
        if (sort != null) ...[
          const SizedBox(width: 2),
          Icon(
            active
                ? (_sortDesc
                      ? Icons.arrow_drop_down_rounded
                      : Icons.arrow_drop_up_rounded)
                : Icons.unfold_more_rounded,
            size: active ? 16 : 12,
            color: active ? semantic.textStrong : semantic.textFaint,
          ),
        ],
      ],
    );
    return Expanded(
      flex: flex,
      child: sort == null
          ? child
          : Tooltip(
              message: 'Sort by ${label.toLowerCase()}',
              waitDuration: const Duration(milliseconds: 400),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tapSort(sort),
                  child: child,
                ),
              ),
            ),
    );
  }

  Widget _dataRow(BuildContext context, RequestTrackingRow r) {
    final semantic = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(r),
        hoverColor: semantic.surfaceSunken.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: _colType, child: _TypeCell(row: r)),
              Expanded(flex: _colRoute, child: _RouteCell(row: r)),
              Expanded(
                flex: _colParty,
                child: _PartyChip(name: r.requesterName),
              ),
              Expanded(
                flex: _colParty,
                child: _PartyChip(name: r.supplierName),
              ),
              Expanded(
                flex: _colParty,
                child: _PartyChip(name: r.transporterNames),
              ),
              Expanded(flex: _colTrips, child: _TripsCell(row: r)),
              Expanded(flex: _colTons, child: _TonsCell(tons: r.tonsDelivered)),
              SizedBox(
                width: _statusWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(row: r),
                  ),
                ),
              ),
              Expanded(
                flex: _colUpdated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateFmt.format(MlTime.sast(r.updatedAt)),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: semantic.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relative(r.updatedAt),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: MlTokens.fsMicro,
                        color: semantic.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, int total, int page, int pageCount) {
    final semantic = MlSemantic.of(context);
    final from = total == 0 ? 0 : page * _pageSize + 1;
    final to = ((page + 1) * _pageSize).clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: semantic.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Showing '),
                  TextSpan(
                    text: '$from–$to',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: semantic.textBody,
                    ),
                  ),
                  TextSpan(text: ' of $total'),
                ],
              ),
              style: TextStyle(
                fontSize: MlTokens.fsLabel,
                color: semantic.textMuted,
              ),
            ),
          ),
          _PagerButton(
            label: 'Prev',
            enabled: page > 0,
            onTap: () => setState(() => _page = page - 1),
          ),
          for (var p = 0; p < pageCount; p++) ...[
            const SizedBox(width: 6),
            _PagerButton(
              label: '${p + 1}',
              active: p == page,
              enabled: true,
              onTap: () => setState(() => _page = p),
            ),
          ],
          const SizedBox(width: 6),
          _PagerButton(
            label: 'Next',
            enabled: page < pageCount - 1,
            onTap: () => setState(() => _page = page + 1),
          ),
        ],
      ),
    );
  }
}

String _relative(DateTime t) {
  final d = DateTime.now().difference(MlTime.sast(t));
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) {
    return '${d.inMinutes} min${d.inMinutes == 1 ? '' : 's'} ago';
  }
  if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
  if (d.inDays < 30) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  final months = (d.inDays / 30).floor();
  return '$months month${months == 1 ? '' : 's'} ago';
}

// ---- Header ---------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.activeCount});

  final int? activeCount;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final accentColors = MlTone.accent.colors(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Request's ",
                      style: TextStyle(color: semantic.textStrong),
                    ),
                    TextSpan(
                      text: 'Tracking Logs',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: accentColors.fg,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: MlTokens.fontSerif,
                  fontSize: MlTokens.fsDisplay,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            if (activeCount != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColors.bg,
                  borderRadius: BorderRadius.circular(MlTokens.rPill),
                ),
                child: Text(
                  '$activeCount active',
                  style: TextStyle(
                    fontSize: MlTokens.fsLabel,
                    fontWeight: FontWeight.w700,
                    color: accentColors.fg,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Every request on the platform, from submission through to '
          'completion. A request completes when all of its trips are '
          'marked delivered.',
          style: TextStyle(
            fontSize: MlTokens.fsBodySm,
            color: semantic.textMuted,
          ),
        ),
      ],
    );
  }
}

// ---- Stat card ------------------------------------------------------------

class _OpsStatCard extends StatelessWidget {
  const _OpsStatCard({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    required this.subLabel,
    required this.onTap,
    this.hero = false,
  });

  final IconData icon;
  final MlTone tone;
  final String label;
  final String value;
  final String subLabel;
  final VoidCallback onTap;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      hero: hero,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          MlIconWell(icon: icon, tone: tone, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MicroLabel(label, color: semantic.textFaint),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: MlTokens.fontSerif,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: semantic.textStrong,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        subLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSerif,
                          fontStyle: FontStyle.italic,
                          fontSize: MlTokens.fsLabel,
                          color: semantic.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Small pieces ---------------------------------------------------------

/// Mono uppercase micro-label — the ops voice used for column headers and
/// stat-card labels.
class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: MlTokens.fontMono,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: color,
    ),
  );
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.filter,
    required this.all,
    required this.requested,
    required this.linked,
    required this.done,
    required this.onChanged,
  });

  final _TrackFilter filter;
  final int all;
  final int requested;
  final int linked;
  final int done;
  final ValueChanged<_TrackFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: semantic.surfaceSunken,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        border: Border.all(color: semantic.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(context, 'All', all, _TrackFilter.all),
          _pill(context, 'Requested', requested, _TrackFilter.requested),
          _pill(context, 'Linked', linked, _TrackFilter.linked),
          _pill(context, 'Completed', done, _TrackFilter.done),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, int count, _TrackFilter f) {
    final semantic = MlSemantic.of(context);
    final accentColors = MlTone.accent.colors(Theme.of(context).brightness);
    final active = filter == f;
    return Material(
      color: active ? accentColors.bg : Colors.transparent,
      borderRadius: BorderRadius.circular(MlTokens.rPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        onTap: () => onChanged(f),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MlTokens.rPill),
            border: Border.all(
              color: active
                  ? accentColors.fg.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: MlTokens.fsLabel,
                  fontWeight: FontWeight.w700,
                  color: active ? semantic.textStrong : semantic.textMuted,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: MlTokens.fontMono,
                  fontSize: MlTokens.fsMicro,
                  fontWeight: FontWeight.w700,
                  color: active ? accentColors.fg : semantic.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(MlTokens.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(color: semantic.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export',
                style: TextStyle(
                  fontSize: MlTokens.fsLabel,
                  fontWeight: FontWeight.w700,
                  color: semantic.textStrong,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.download_rounded,
                size: 14,
                color: semantic.textStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final accentColors = MlTone.accent.colors(Theme.of(context).brightness);
    return Material(
      color: active ? accentColors.bg : Colors.transparent,
      borderRadius: BorderRadius.circular(MlTokens.rSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rSm),
        onTap: enabled && !active ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MlTokens.rSm),
            border: Border.all(
              color: active
                  ? accentColors.fg.withValues(alpha: 0.45)
                  : semantic.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: MlTokens.fsLabel,
              fontWeight: FontWeight.w700,
              color: active
                  ? semantic.textStrong
                  : enabled
                  ? semantic.textMuted
                  : semantic.textFaint.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Cells ----------------------------------------------------------------

/// Deterministic tone for a company's initials avatar.
MlTone _avatarTone(String name) {
  const tones = [
    MlTone.accent,
    MlTone.transit,
    MlTone.atMine,
    MlTone.done,
    MlTone.warn,
  ];
  return tones[name.codeUnits.fold<int>(0, (a, c) => a + c) % tones.length];
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '·';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1);
  }
  return '${parts[0][0]}${parts[1][0]}';
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.name, this.size = 20});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = _avatarTone(name);
    final colors = tone.colors(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        _initials(name).toUpperCase(),
        style: TextStyle(
          fontFamily: MlTokens.fontMono,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: colors.fg,
          height: 1,
        ),
      ),
    );
  }
}

class _TypeCell extends StatelessWidget {
  const _TypeCell({required this.row});

  final RequestTrackingRow row;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final colors = MlTone.transit.colors(Theme.of(context).brightness);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(MlTokens.rSm),
          ),
          child: Icon(
            switch (row.requestType) {
              'product' => Icons.inventory_2_outlined,
              'buyer' => Icons.storefront_outlined,
              _ => Icons.local_shipping_outlined,
            },
            size: 14,
            color: colors.fg,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            row.typeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: semantic.textBody),
          ),
        ),
      ],
    );
  }
}

/// Status pill matching the reference: tonal bg, subtle border, leading dot,
/// mixed-case label. Tone mapping is the app-wide one.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.row});

  final RequestTrackingRow row;

  static MlTone toneFor(RequestTrackingRow r) => r.isCompleted
      ? MlTone.done
      : switch (r.status) {
          'linked' || 'approved' => MlTone.transit,
          'declined' => MlTone.error,
          'sent_back' => MlTone.warn,
          _ => MlTone.atMine,
        };

  static String labelFor(RequestTrackingRow r) {
    if (r.isCompleted) return 'Completed';
    final s = r.displayStatus.replaceAll('_', ' ');
    return s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = toneFor(row).colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        border: Border.all(color: colors.fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              labelFor(row),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MlTokens.fsLabel,
                fontWeight: FontWeight.w600,
                color: colors.fg,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Company avatar + name, or a faint dash when absent. Hover reveals the full
/// name when truncated.
class _PartyChip extends StatelessWidget {
  const _PartyChip({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final n = name;
    if (n == null || n.isEmpty) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12.5, color: semantic.textFaint),
      );
    }
    return Tooltip(
      message: n,
      waitDuration: const Duration(milliseconds: 350),
      child: Row(
        children: [
          _InitialsBadge(name: n),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              n,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: semantic.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading → offloading endpoint pills (transport), or the commodity pill.
/// Hover reveals the full endpoint names.
class _RouteCell extends StatelessWidget {
  const _RouteCell({required this.row});

  final RequestTrackingRow row;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    if (row.requestType != 'transportation') {
      return Align(
        alignment: Alignment.centerLeft,
        child: _endpointPill(context, row.commodity ?? '—'),
      );
    }
    return Row(
      children: [
        Flexible(child: _endpointPill(context, row.loadingPoint ?? '—')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_right_alt_rounded,
            size: 16,
            color: semantic.textFaint,
          ),
        ),
        Flexible(child: _endpointPill(context, row.offloadingPoint ?? '—')),
      ],
    );
  }

  Widget _endpointPill(BuildContext context, String label) {
    final semantic = MlSemantic.of(context);
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 350),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: semantic.surfaceSunken,
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: Border.all(color: semantic.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InitialsBadge(name: label, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: semantic.textStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Completed/total with a slim progress bar, right-aligned.
class _TripsCell extends StatelessWidget {
  const _TripsCell({required this.row});

  final RequestTrackingRow row;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    if (row.tripsTotal == 0) {
      return Text(
        '—',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12.5, color: semantic.textFaint),
      );
    }
    final fillColor = MlTone.transit.colors(Theme.of(context).brightness).fg;
    final frac = (row.tripsCompleted / row.tripsTotal).clamp(0.0, 1.0);
    return Tooltip(
      message: '${row.tripsCompleted} of ${row.tripsTotal} trips completed',
      waitDuration: const Duration(milliseconds: 350),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 30,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: semantic.surfaceSunken,
                borderRadius: MlShape.radiusExtraSmall,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: MlShape.radiusExtraSmall,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${row.tripsCompleted}',
                  style: TextStyle(
                    fontFamily: MlTokens.fontMono,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: semantic.textStrong,
                  ),
                ),
                TextSpan(
                  text: '/${row.tripsTotal}',
                  style: TextStyle(
                    fontFamily: MlTokens.fontMono,
                    fontSize: 12.5,
                    color: semantic.textFaint,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _TonsCell extends StatelessWidget {
  const _TonsCell({required this.tons});

  final double tons;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    if (tons == 0) {
      return Text(
        '—',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12.5, color: semantic.textFaint),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          tons.toStringAsFixed(2),
          maxLines: 1,
          style: TextStyle(
            fontFamily: MlTokens.fontMono,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: semantic.textStrong,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          't',
          style: TextStyle(
            fontFamily: MlTokens.fontMono,
            fontSize: 10.5,
            color: semantic.textFaint,
          ),
        ),
      ],
    );
  }
}

// ---- Details dialog -------------------------------------------------------

/// Full, untruncated view of one tracked request — opened by clicking a row.
class _RequestDetailsDialog extends StatelessWidget {
  const _RequestDetailsDialog({required this.row});

  final RequestTrackingRow row;

  static final _dateTimeFmt = DateFormat('dd MMM yyyy · HH:mm');

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: semantic.surfaceCard,
            borderRadius: BorderRadius.circular(MlTokens.rLg),
            border: Border.all(color: semantic.borderCard),
            boxShadow: MlTokens.shadowLg,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MlIconWell(
                      icon: switch (row.requestType) {
                        'product' => Icons.inventory_2_outlined,
                        'buyer' => Icons.storefront_outlined,
                        _ => Icons.local_shipping_outlined,
                      },
                      tone: _StatusPill.toneFor(row),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row.typeLabel} request',
                            style: TextStyle(
                              fontSize: MlTokens.fsTitle,
                              fontWeight: FontWeight.w700,
                              color: semantic.textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Updated ${_relative(row.updatedAt)}',
                            style: TextStyle(
                              fontSize: MlTokens.fsLabel,
                              color: semantic.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(row: row),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: semantic.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (row.requestType == 'transportation') ...[
                  _MicroLabel('ROUTE', color: semantic.textFaint),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _fullPill(context, row.loadingPoint ?? '—'),
                      Icon(
                        Icons.arrow_right_alt_rounded,
                        size: 16,
                        color: semantic.textFaint,
                      ),
                      _fullPill(context, row.offloadingPoint ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _detail(context, 'Requested by', row.requesterName),
                _detail(context, 'Mine / supplier', row.supplierName),
                _detail(context, 'Transporters', row.transporterNames),
                _detail(context, 'Commodity', row.commodity),
                _detail(
                  context,
                  'Trips',
                  row.tripsTotal == 0
                      ? null
                      : '${row.tripsCompleted} of ${row.tripsTotal} completed',
                ),
                _detail(
                  context,
                  'Tons delivered',
                  row.tonsDelivered == 0
                      ? null
                      : '${row.tonsDelivered.toStringAsFixed(2)} t',
                ),
                _detail(
                  context,
                  'Last updated',
                  _dateTimeFmt.format(MlTime.sast(row.updatedAt)),
                ),
                const SizedBox(height: 4),
                Divider(color: semantic.divider, height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MicroLabel('REQUEST ID', color: semantic.textFaint),
                          const SizedBox(height: 4),
                          SelectableText(
                            row.requestId,
                            style: TextStyle(
                              fontFamily: MlTokens.fontMono,
                              fontSize: MlTokens.fsLabel,
                              color: semantic.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy request ID',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: row.requestId),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Request ID copied.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      color: semantic.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullPill(BuildContext context, String label) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: semantic.surfaceSunken,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        border: Border.all(color: semantic.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InitialsBadge(name: label, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: semantic.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String? value) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _MicroLabel(
                label.toUpperCase(),
                color: semantic.textFaint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? '—' : value,
              style: TextStyle(
                fontSize: MlTokens.fsBodySm,
                color: (value == null || value.isEmpty)
                    ? semantic.textFaint
                    : semantic.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

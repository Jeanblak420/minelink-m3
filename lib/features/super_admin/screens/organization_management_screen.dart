import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/data/models/organization_status.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/utils/organization_search.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Organization-management screen — the design's paginated table: one card with
/// a search + org-type + status filter bar, a compact Company/Org-type/Seats/
/// Token-expiry table, and a pagination footer.
///
/// Accepts an optional `?status=<...>` query param so the dashboard's
/// Platform-registry cards can deep-link straight to a filtered view.
class OrganizationManagementScreen extends ConsumerStatefulWidget {
  final String? initialStatusFilter;
  const OrganizationManagementScreen({super.key, this.initialStatusFilter});

  @override
  ConsumerState<OrganizationManagementScreen> createState() =>
      _OrganizationManagementScreenState();
}

class _OrganizationManagementScreenState
    extends ConsumerState<OrganizationManagementScreen> {
  String _query = '';
  String _type = 'all'; // all | mineSupplier | buyer | transporter
  OrganizationStatus? _status;
  int _perPage = 10;
  int _page = 1;

  // Org-type hues come from MlOrgTone now — one palette, matching the design
  // reference's MINE amber / BUYER violet / TRANSPORTER cyan badges. This file
  // used to carry its own blue/purple/orange trio, duplicated verbatim in
  // request_review_screen, so a buyer was purple here and violet on the console.

  @override
  void initState() {
    super.initState();
    _status = _parseStatus(widget.initialStatusFilter);
  }

  @override
  void didUpdateWidget(covariant OrganizationManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatusFilter != widget.initialStatusFilter) {
      setState(() => _status = _parseStatus(widget.initialStatusFilter));
    }
  }

  static OrganizationStatus? _parseStatus(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = OrganizationStatus.fromString(raw);
    if (parsed == OrganizationStatus.pendingActivation &&
        raw != 'pendingActivation') {
      return null;
    }
    return parsed;
  }

  Color _typeColor(String? t, Brightness brightness) => switch (t) {
    'buyer' => MlOrgTone.buyer.colors(brightness).fg,
    'mineSupplier' => MlOrgTone.mineSupplier.colors(brightness).fg,
    _ => MlOrgTone.transporter.colors(brightness).fg,
  };

  IconData _typeIcon(String? t) => switch (t) {
    'mineSupplier' => Icons.terrain_rounded,
    'buyer' => Icons.shopping_bag_outlined,
    'transporter' => Icons.local_shipping_outlined,
    _ => Icons.business_rounded,
  };

  String _typeLabel(String? t) => switch (t) {
    'mineSupplier' => 'Mine',
    'buyer' => 'Buyer',
    'transporter' => 'Transporter',
    _ => t ?? '—',
  };

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final orgsAsync = ref.watch(organizationsProvider);
    final roleAsync = ref.watch(currentPlatformRoleProvider);

    // Every super global admin has full rights, including registering companies.
    final canRegister = roleAsync.maybeWhen(
      data: (role) => role.isSuperAdmin,
      orElse: () => false,
    );

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Organizations',
            meta: orgsAsync.valueOrNull == null
                ? null
                : mlCount(orgsAsync.value!.length, 'company', 'companies'),
            actions: [
              // Was a hand-styled `FilledButton.icon` re-specifying the
              // accent, the ink and a 10px radius — the system's own solid
              // cyan primary, written out again slightly differently.
              if (canRegister)
                MlButton.primary(
                  label: 'Register company',
                  icon: Icons.add_rounded,
                  compact: true,
                  onPressed: () =>
                      context.go('/super-admin/register-company'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: s.surfaceCard,
              borderRadius: BorderRadius.circular(MlTokens.rXl),
              border: Border.all(color: s.borderCard),
              boxShadow: MlTokens.shadowSm,
            ),
            padding: const EdgeInsets.all(22),
            child: orgsAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => MlEmptyState(
                icon: Icons.error_outline,
                title: 'Could not load organizations',
                message: friendlyError(e),
                action: MlButton.primary(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(organizationsProvider),
                ),
              ),
              data: (orgs) => _content(context, s, orgs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    MlSemantic s,
    List<Map<String, dynamic>> orgs,
  ) {
    // Filter.
    var filtered = orgs.where((o) {
      if (_type != 'all' && o['org_type'] != _type) return false;
      if (_status != null && (o['status'] as String?) != _status!.name) {
        return false;
      }
      if (_query.isNotEmpty && !OrganizationSearch.matches(o, _query)) {
        return false;
      }
      return true;
    }).toList();
    // Most-recent first.
    filtered.sort((a, b) {
      final ax = (a['updated_at'] ?? a['created_at'] ?? '') as String;
      final bx = (b['updated_at'] ?? b['created_at'] ?? '') as String;
      return bx.compareTo(ax);
    });

    final total = filtered.length;
    final pages = (total / _perPage).ceil().clamp(1, 9999);
    final page = _page.clamp(1, pages);
    final start = (page - 1) * _perPage;
    final shown = filtered.skip(start).take(_perPage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter bar ──
        //
        // A Row until it genuinely does not fit, then stacked.
        //
        // It was an unconditional Row whose two dropdowns were UNFLEXED, so
        // they took their widest item's natural width from an unbounded
        // constraint (CLAUDE.md §10.4) while the search field held an
        // Expanded. At text scale 2.0 on a 600px window that is 16px more
        // than exists, and the bar overflowed. The console's own text-scale
        // slider reaches 1.3, and the shells compose it with the platform's
        // up to kMaxEffectiveTextScale, so 2.0 is a size a real admin can be
        // sitting at -- not a hypothetical.
        LayoutBuilder(
          builder: (context, c) {
            // The dropdowns size to their widest label ("All org types",
            // "All statuses") at 13.5px semibold; ~170dp covers both with the
            // chevron and padding, and scales with the text. This is an
            // estimate, and it is checked rather than trusted: the console
            // sweep renders this screen at 8 widths x 6 text scales.
            final scale = MediaQuery.textScalerOf(context).scale(13.5) / 13.5;
            final filtersNeed = 2 * 170 * scale + 20;
            // Below this the search box stops being a search box.
            final stacked = c.maxWidth - filtersNeed < 220;

            final search = SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (v) => setState(() {
                    _query = v.trim().toLowerCase();
                    _page = 1;
                  }),
                  style: context.mlText.bodyMedium.copyWith(color: s.textBody),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search name, owner, email, serial…',
                    hintStyle: context.mlText.bodyMedium.copyWith(
                      color: s.textFaint,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: s.textMuted,
                    ),
                    filled: true,
                    fillColor: s.surfaceSunken,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: MlShape.radiusMedium,
                      borderSide: BorderSide(color: s.borderCard),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MlShape.radiusMedium,
                      borderSide: BorderSide(color: s.borderCard),
                    ),
                  ),
                ),
              );

            final typeFilter = _dropdown<String>(
              context: context,
              value: _type,
              onChanged: (v) => setState(() {
                _type = v ?? 'all';
                _page = 1;
              }),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All org types')),
                DropdownMenuItem(value: 'mineSupplier', child: Text('Mine')),
                DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                DropdownMenuItem(
                  value: 'transporter',
                  child: Text('Transporter'),
                ),
              ],
            );

            final statusFilter = _dropdown<OrganizationStatus?>(
              context: context,
              value: _status,
              onChanged: (v) => setState(() {
                _status = v;
                _page = 1;
              }),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All statuses'),
                ),
                for (final st in const [
                  OrganizationStatus.active,
                  OrganizationStatus.expired,
                  OrganizationStatus.suspended,
                  OrganizationStatus.pendingActivation,
                ])
                  DropdownMenuItem(value: st, child: Text(st.displayName)),
              ],
            );

            if (!stacked) {
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  typeFilter,
                  const SizedBox(width: 10),
                  statusFilter,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                // Wrap, so the two filters sit side by side when they fit and
                // stack when they do not -- one more step down, without
                // another threshold to get wrong.
                Wrap(spacing: 10, runSpacing: 10, children: [
                  typeFilter,
                  statusFilter,
                ]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // ── Table ──
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No organizations match these filters.',
                style: context.mlText.bodyMedium.copyWith(color: s.textFaint),
              ),
            ),
          )
        else
          // The registry SCROLLS below 620px rather than compressing.
          //
          // Its four columns are all `Expanded`, so on a 412px phone they got
          // roughly 70px each and every one of them truncated: the company
          // names read "Iron …", "Atlas …", "Cons…", the org-type pills read
          // "MI…", "BU…", "TR…" and the token expiry read "10…", "1D…", "Ex…".
          // A registry where no column can be read is not a narrow registry, it
          // is a blank one. Photographed 2026-08-20, the first time this screen
          // was rendered at phone width.
          //
          // 620 is what the CONTENT needs: a company name wants ~180px at
          // flex 16, the "TRANSPORTER" pill ~100px at flex 10, and the expiry
          // ~110px at flex 13 — the widest of those puts the table at 584 plus
          // the 44px chevron column. It therefore never scrolls on a laptop and
          // always scrolls on a phone, which is the right way round.
          //
          // Header and rows go inside ONE `MlWideTable` so they scroll
          // together; two would drift apart the moment anyone touched it.
          MlWideTable(
            minWidth: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerRow(s),
                for (final o in shown) _dataRow(context, s, o),
              ],
            ),
          ),
        // ── Pagination footer ──
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: s.divider)),
          ),
          // Wrap, not Row. Every child here is unflexed -- a range label, a
          // rows-per-page dropdown and the pager buttons -- so on a phone, or
          // at a large text scale, their combined natural width exceeds the
          // footer and it overflowed. Wrapping needs no threshold and keeps
          // every control reachable rather than clipping the pager.
          child: Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                total == 0
                    ? '0'
                    : '${start + 1}–${(start + _perPage).clamp(0, total)} of $total',
                style: context.mlText.bodyMedium.copyWith(color: s.textMuted),
              ),
              _dropdown<int>(
                context: context,
                value: _perPage,
                dense: true,
                onChanged: (v) => setState(() {
                  _perPage = v ?? 10;
                  _page = 1;
                }),
                items: [
                  for (final n in const [5, 10, 25, 50])
                    DropdownMenuItem(value: n, child: Text('$n / page')),
                ],
              ),
              // NO `Spacer` HERE. A `Spacer` is an `Expanded`, and a `Wrap`
              // cannot accept `FlexParentData` — it throws "Incorrect use of
              // ParentDataWidget" on every build of this screen, in debug,
              // which is every build a developer ever sees.
              //
              // The comment above this Wrap said "every child here is
              // unflexed", and that was the claim the Spacer falsified. It was
              // presumably left behind when the footer changed from a `Row`.
              //
              // Nothing replaces it: a Wrap has no free space to distribute, so
              // the Spacer could never have pushed the pager right even if it
              // had been legal. The pager sits after the rows-per-page control
              // and wraps under it when the footer is narrow, which is what the
              // Wrap is for.
              _pageBtn(
                s,
                Icons.chevron_left_rounded,
                enabled: page > 1,
                onTap: () => setState(() => _page = page - 1),
              ),
              for (var p = 1; p <= pages; p++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _pageNum(
                    s,
                    p,
                    selected: p == page,
                    onTap: () => setState(() => _page = p),
                  ),
                ),
              _pageBtn(
                s,
                Icons.chevron_right_rounded,
                enabled: page < pages,
                onTap: () => setState(() => _page = page + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── table ─────────────────────────
  Widget _headerRow(MlSemantic s) {
    final st = context.mlText.labelSmall.copyWith(
      color: s.textFaint,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 16, child: Text('COMPANY', style: st)),
          Expanded(flex: 10, child: Text('ORG TYPE', style: st)),
          Expanded(
            flex: 9,
            child: Text('SEATS', textAlign: TextAlign.center, style: st),
          ),
          Expanded(flex: 13, child: Text('TOKEN EXPIRY', style: st)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, MlSemantic s, Map<String, dynamic> o) {
    final name = (o['company_name'] as String?)?.trim().isNotEmpty == true
        ? o['company_name'] as String
        : 'Unnamed';
    final type = o['org_type'] as String?;
    final seatLimit = (o['seat_limit'] as num?)?.toInt() ?? 0;
    final seatsUsed = (o['seats_used'] as num?)?.toInt() ?? 0;
    final over = seatLimit > 0 && seatsUsed > seatLimit;
    final exp = _expiry(o['token_expires_at'] as String?);
    final tc = _typeColor(type, Theme.of(context).brightness);

    String subline = '';
    final op = o['owner_profile'];
    if (op is Map) {
      subline = (op['email'] as String?)?.trim() ?? '';
    }

    void open() => context.go('/super-admin/organization/${o['id']}');

    return InkWell(
      onTap: open,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: s.divider)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Company
            Expanded(
              flex: 16,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tc.withValues(alpha: 0.10),
                      borderRadius: MlShape.radiusMedium,
                      border: Border.all(color: tc.withValues(alpha: 0.28)),
                    ),
                    child: Icon(_typeIcon(type), size: 17, color: tc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          // THREE lines. This is the company's NAME, in the
                          // register of companies — the one column of this row
                          // that identifies which company it is. The longest
                          // real name on the platform is 49 characters (333px)
                          // and this cell is 146px on a phone, which two lines
                          // still could not hold.
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.titleSmall.copyWith(
                            color: s.textStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subline.isNotEmpty)
                          Text(
                            subline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.code(
                              color: s.textFaint,
                              size: 12,
                              weight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Org type pill
            Expanded(
              flex: 10,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: s.surfaceSunken,
                    borderRadius: MlShape.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: tc,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Flexible, so the label can ellipsize inside the pill.
                      // A Row gives an unflexed child unbounded width, so
                      // `overflow` never engages and the pill simply runs past
                      // its column (CLAUDE.md §10.4). "MINE / SUPPLIER" at a
                      // 2.0 text scale overflowed the 1024px layout by 14px.
                      // The only flexible child here, so flex: 1 is right: it
                      // takes whatever the 6px dot and 6px gap leave.
                      Flexible(
                        child: Text(
                          _typeLabel(type).toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: context.mlText.labelSmall.copyWith(
                            color: tc,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Seats
            Expanded(
              flex: 9,
              child: Text(
                '$seatsUsed/$seatLimit',
                textAlign: TextAlign.center,
                style: context.mlText.code(
                  color: over ? MlTokens.orange600 : s.textBody,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            // Token expiry
            Expanded(
              flex: 13,
              // A Wrap, so the date drops BELOW the countdown rather than
              // competing with it for a 66px cell.
              //
              // Both were `Flexible` in a Row, which shares the space evenly —
              // fine on a desktop, and on a 412px phone it left the countdown
              // 66px for "107d 22h left" (95px) and "Expired · 01 Aug". The
              // expiry column is the one a platform admin scans this register
              // for; neither half of it can be the half that gets cut.
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              exp.dot.colors(Theme.of(context).brightness).fg,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          exp.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.code(
                            // The SAME tone call the dot eight lines above
                            // makes. It was a fixed `MlTokens.red600` - the
                            // light half of `MlTone.error` - so the dot
                            // resolved per brightness and the label beside it
                            // did not, one line apart in one widget:
                            // "Expired - 01 Aug" measured 3.02:1 on the dark
                            // console.
                            color: exp.expired
                                ? exp.dot
                                    .colors(Theme.of(context).brightness)
                                    .fg
                                : s.textBody,
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (exp.date != null)
                    Text(
                      exp.date!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(
                        color: s.textFaint,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: s.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── controls ─────────────────────────
  Widget _dropdown<T>({
    required BuildContext context,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool dense = false,
  }) {
    final s = MlSemantic.of(context);
    return Container(
      // minHeight, not height. A fixed height counts Border.all as padding ON
      // TOP of `padding` (CLAUDE.md §10.4), and at text scale 2.0 a 13.5px
      // label is 27px inside a 40px box -- it fits by less than the border.
      //
      // maxWidth, because `DropdownButton` lays its SELECTED item out at that
      // item's natural width unless told otherwise -- the same trap §10.4
      // records for DropdownButtonFormField. Both call sites now sit in a
      // Wrap, which hands children unbounded width, so at text scale 2.0
      // "All statuses" was simply wider than the phone. 260 is comfortable at
      // every scale the console offers and narrower than a 360px viewport's
      // content box, so the chip can always be laid out somewhere.
      constraints: const BoxConstraints(minHeight: 40, maxWidth: 260),
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12),
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: s.borderCard),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          // With the cap above, this is what makes the label ellipsize inside
          // the box instead of pushing past it.
          isExpanded: true,
          borderRadius: MlShape.radiusMedium,
          icon: Icon(Icons.expand_more, size: 18, color: s.textMuted),
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: dense ? 13 : 13.5,
            fontWeight: FontWeight.w600,
            color: s.textBody,
          ),
          dropdownColor: s.surfaceCard,
        ),
      ),
    );
  }

  Widget _pageBtn(
    MlSemantic s,
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: s.surfaceCard,
        borderRadius: MlShape.radiusMedium,
        child: InkWell(
          borderRadius: MlShape.radiusMedium,
          onTap: enabled ? onTap : null,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: MlShape.radiusMedium,
              border: Border.all(color: s.borderCard),
            ),
            child: Icon(icon, size: 18, color: s.textBody),
          ),
        ),
      ),
    );
  }

  Widget _pageNum(
    MlSemantic s,
    int p, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    const accent = MlTokens.accent;
    return Material(
      color: selected ? accent : s.surfaceCard,
      borderRadius: MlShape.radiusMedium,
      child: InkWell(
        borderRadius: MlShape.radiusMedium,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: MlShape.radiusMedium,
            border: Border.all(color: selected ? accent : s.borderCard),
          ),
          // `Align(widthFactor: 1)`, NOT `Container(alignment:)`.
          //
          // A Container given an alignment lays its child out inside an
          // `Align`, and an `Align` with no `widthFactor` takes the largest
          // size its constraints allow. This one sits in a `Wrap`, which hands
          // every child the WHOLE footer as its maximum — so the selected page
          // button was drawn as a 1,200px cyan bar across the register with a
          // "1" in the middle of it, and the two chevrons wrapped onto lines of
          // their own above and below it.
          //
          // Photographed 2026-08-21 on `screen-organizations-desktop-light`.
          // It was in the dark render too, at every width, for as long as the
          // pager has existed — a picture nobody had read.
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              '$p',
              style: context.mlText.titleSmall.copyWith(
                color: selected ? MlTokens.inkOnAccent : s.textBody,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Token state for the org list.
  ///
  /// **A company with no token used to render a GREEN dot labelled "No token"**
  /// — the same green as a token with a year left on it, so the one state that
  /// stops an organisation working read as the healthiest thing on the row. It
  /// is now `error`, alongside expired, because the consequence is the same:
  /// `is_company_active` is false and the company can do nothing.
  ///
  /// An unparseable expiry was green too. It is `neutral` — unknown is not
  /// well, and it is not a failure either.
  ///
  /// Returns a tone rather than a `Color` so the caller resolves it against the
  /// active brightness. The three raw `Color(0xFF…)` literals this replaces
  /// were fixed hues that did not move between light and dark (S5-19).
  _ExpiryInfo _expiry(String? iso) {
    if (iso == null) {
      return const _ExpiryInfo('No token', true, MlTone.error, null);
    }
    final exp = DateTime.tryParse(iso);
    if (exp == null) return const _ExpiryInfo('—', false, MlTone.neutral, null);
    // `MlTime.instant()`, not `DateTime.now()`. This countdown is bucketed by
    // day (`diff.inDays`, and `< 7` decides whether the dot goes amber), which
    // CLAUDE.md §7.1 puts squarely under the one-clock rule. It also has to be
    // reproducible: read off the device clock, the registry's golden said
    // `102d 09h left` when it was written and `102d 08h left` an hour later,
    // and the whole render suite failed for the next person to run it.
    //
    // `instant()` and not `now()` — `now()` is a WALL CLOCK flagged non-UTC,
    // so subtracting it from a server timestamp is off by the reader's own
    // offset everywhere except South Africa.
    final now = MlTime.instant();
    final date = DateFormat("d MMM ''yy").format(MlTime.sast(exp));
    final diff = exp.difference(now);
    if (diff.isNegative) {
      return _ExpiryInfo(
        // The product's one relative-time vocabulary, not a tenth dialect.
        'Expired · ${MlTime.ago(exp)}',
        true,
        MlTone.error,
        date,
      );
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    return _ExpiryInfo(
      '${days}d ${hours.toString().padLeft(2, '0')}h left',
      false,
      days < 7 ? MlTone.warn : MlTone.done,
      date,
    );
  }
}

class _ExpiryInfo {
  final String label;
  final bool expired;

  /// Semantic tone, resolved against brightness at the render site.
  final MlTone dot;
  final String? date;
  const _ExpiryInfo(this.label, this.expired, this.dot, this.date);
}

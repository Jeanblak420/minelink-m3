import 'package:flutter/material.dart';

// `mlCount` — the shared meta-line count formatter (S5-22). Re-exported so it
// is in scope wherever a section header is.
export 'package:flutter_application_1/core/design/components/ml_meta.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// Section heading for the portal, in the reference's vocabulary.
///
/// The super-admin console — designated the design reference on 2026-08-14 by
/// client instruction — heads every section with a **Fraunces title, an
/// optional subtitle, a right-aligned meta line and a `View →` link**
/// (`MlSectionHead`, `docs/design-reference.md` §4). The portal's version was
/// PlusJakartaSans ExtraBold with an icon and a trailing action, and had
/// nowhere to put a meta line at all — so S5-22 ("every migrated screen
/// carries a section header with a meta line, and where applicable a View →,
/// filter row and export") could not be satisfied without changing this
/// widget. Two vocabularies for one job is what S5-13 exists to merge.
///
/// Deliberately **not** replaced by the console's `MlSectionHead`: that one
/// takes its `MlGlass` as a constructor argument and carries no icon or
/// trailing action, both of which the portal uses at most of its 32 sites.
/// This keeps the portal's shape and adopts the reference's treatment.
///
/// [icon] and [action] are unchanged, so every existing call site keeps
/// working and picks up the new type treatment without being touched.
///
/// Pinned by `test/widgets/portal_section_header_test.dart`.
class MlSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry margin;

  /// One calm line under the title, describing what the section is.
  final String? subtitle;

  /// Right-aligned context — `Last 24h · +2 companies`, `Updated 2 min ago`.
  /// The reference's section headers carry this on the right of every one.
  final String? meta;

  /// A `View →` affordance. The arrow is appended by this widget rather than
  /// by the caller, so no screen can ship the label without the tell.
  final String? link;
  final VoidCallback? onLink;

  const MlSectionTitle(
    this.title, {
    super.key,
    this.icon,
    this.action,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.subtitle,
    this.meta,
    this.link,
    this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final glass = MlGlass.of(context);
    final hasTrailing = meta != null || link != null;

    return Padding(
      padding: margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          // ── When half a row is not enough for either half ──────────────
          //
          // The trailing block is capped at 50% of the row (see _row), and
          // that was the right fix for the 44px overflow it was written for.
          // A cap cannot help once BOTH halves need more than half: at 360px
          // and text scale 1.6 the title's longest word and the meta's
          // longest word each want more than 180px, and the row overflowed
          // by 16px whatever the cap said. The `action` slot is unflexed on
          // top of that -- its own comment predicted this exact failure and
          // sent the fix here.
          //
          // Below this floor the trailing block goes underneath. Same
          // reasoning as MlSectionHead: a header laid out side by side is a
          // desktop shape, and on a phone at an accessibility text size
          // there is no width left to divide.
          final scale = MediaQuery.textScalerOf(context).scale(11.5) / 11.5;
          final stacked = (hasTrailing || action != null) &&
              maxWidth.isFinite &&
              maxWidth < 400 * scale;

          if (!stacked) {
            return _row(
              context,
              semantic,
              glass,
              hasTrailing: hasTrailing,
              maxWidth: maxWidth,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The title alone, with the whole width to itself.
              _row(context, semantic, glass,
                  hasTrailing: false, maxWidth: maxWidth, withAction: false),
              const SizedBox(height: 8),
              if (hasTrailing)
                _trailing(context, glass,
                    cap: maxWidth, alignEnd: false),
              if (action != null) ...[
                if (hasTrailing) const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: action!),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    MlSemantic semantic,
    MlGlass glass, {
    required bool hasTrailing,
    required double maxWidth,
    bool withAction = true,
  }) {
    // Half the row, and never more. See the note on the trailing block below
    // for why this is a cap rather than a flex.
    final trailingCap = maxWidth.isFinite ? maxWidth * 0.5 : double.infinity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: MlTokens.accent),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                // TWO lines, not one.
                //
                // A section heading is the thing that says what the list under
                // it is, and at one line the Load Controller's weighbridge read
                // "Trucks at Mine — Ready for Lo…" on a 412px phone. Fraunces
                // at the editorial-medium rung is 20px; almost no real heading
                // in this product fits 338px on one line of it, so the phone
                // was ellipsising headings as a matter of course.
                //
                // Nothing that already fits moves: a one-line title lays out
                // identically under `maxLines: 2`. Only the headings that were
                // losing words gain a line, and every one of them is inside a
                // scrolling page.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // Fraunces, matching MlSectionHead on the reference screens.
                // The weight drops from w800 to w400 with it: the serif's
                // stroke contrast carries the emphasis that the sans needed
                // extra weight for, and a heavy Fraunces at this size reads as
                // a different design language rather than the same one.
                //
                // 18px until 2026-08-20, when the editorial rungs were pitched
                // at 24/20/16 and this became the 20. Fraunces registers only
                // w500 and w600, so the w400 asked for here has always rendered
                // as Medium — it is kept as written because it is the *intent*
                // that matters, and the day a w400 lands in pubspec this should
                // get lighter rather than stay where a rename left it.
                style: context.mlText.editorialMedium.copyWith(
                  color: semantic.textStrong,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: context.mlText.bodySmall.copyWith(color: glass.inkMid),
                ),
              ],
            ],
          ),
        ),
        if (hasTrailing) ...[
          const SizedBox(width: 14),
          // ── Capped, not flexed. Both halves of that matter. ───────────
          //
          // **Not `Flexible`**: it defaults to `flex: 1`, so it competed
          // with the title's `Expanded` for the free space and took half
          // the row. In a 1000px header that put the meta at x=507, nowhere
          // near the right edge §4 puts it at. CLAUDE.md §10.4's "wrap the
          // cell in Flexible" rule is about the long child that needs to
          // ellipsise — here that is the title, which has the `Expanded`.
          //
          // **But not unflexed either**, which is what it was until
          // 2026-08-16. A non-flex child of a `Row` is laid out with an
          // UNBOUNDED main axis, so the meta could neither wrap nor
          // ellipsise: it just ran off the edge. "The meta is short by
          // contract" turned out not to be a contract anything enforced —
          // `mine_production_screen.dart` passes
          // `'120.00 t mined · 35.00 t dispatched'`, and at text scale 1.6
          // on a 360px phone that overflowed the row by 44px.
          //
          // A `ConstrainedBox` is both: still a non-flex child, so it takes
          // no share of the free space and the `Expanded` title still
          // pushes it to the right edge — but bounded, so when the content
          // genuinely does not fit it wraps instead of overflowing. Below
          // the cap it is content-sized and nothing about the old
          // right-alignment changes.
          //
          // The meta is deliberately allowed to WRAP rather than ellipsise:
          // it carries figures, and '120.00 t mined · 35.0…' is a truncated
          // number, which is worse than a second line.
          _trailing(context, glass, cap: trailingCap, alignEnd: true),
        ],
        // `action` is left unflexed on purpose: it is a caller-supplied
        // widget, usually a button, and clamping an arbitrary child's width
        // truncates its hit target rather than its text. No call site
        // currently overflows through it; if one ever does, the fix belongs
        // at that call site, where what may be dropped is known.
        if (action != null && withAction) ...[
          const SizedBox(width: 10),
          action!,
        ],
      ],
    );
  }

  /// The meta / link block.
  ///
  /// Right-aligned and capped when it sits beside the title; left-aligned and
  /// full width when [build] has moved it underneath.
  Widget _trailing(
    BuildContext context,
    MlGlass glass, {
    required double cap,
    required bool alignEnd,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cap),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (meta != null)
            Text(
              meta!,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: context.mlText.labelSmall.copyWith(
                color: glass.inkLo,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (link != null) ...[
            if (meta != null) const SizedBox(height: 3),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onLink,
                child: Text(
                  '$link →',
                  style: context.mlText.labelMedium.copyWith(
                    color: glass.accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

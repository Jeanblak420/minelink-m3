import 'package:flutter/material.dart';

// `mlCount` — the shared meta-line count formatter (S5-22). Re-exported so it
// is in scope wherever a section header is.
export 'package:flutter_application_1/core/design/components/ml_meta.dart';
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
        builder: (context, constraints) => _row(
          context,
          semantic,
          glass,
          hasTrailing: hasTrailing,
          maxWidth: constraints.maxWidth,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    MlSemantic semantic,
    MlGlass glass, {
    required bool hasTrailing,
    required double maxWidth,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Fraunces, matching MlSectionHead on the reference screens.
                // The weight drops from w800 to w400 with it: the serif's
                // stroke contrast carries the emphasis that the sans needed
                // extra weight for, and w800 Fraunces at 18px reads as a
                // different design language rather than the same one.
                style: TextStyle(
                  fontFamily: MlGlass.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                  color: semantic.textStrong,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 11.5,
                    height: 1.4,
                    color: glass.inkMid,
                  ),
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
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: trailingCap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (meta != null)
                  Text(
                    meta!,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontFamily: MlGlass.sans,
                      fontSize: 11,
                      color: glass.inkLo,
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
                        style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: glass.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        // `action` is left unflexed on purpose: it is a caller-supplied
        // widget, usually a button, and clamping an arbitrary child's width
        // truncates its hit target rather than its text. No call site
        // currently overflows through it; if one ever does, the fix belongs
        // at that call site, where what may be dropped is known.
        if (action != null) ...[const SizedBox(width: 10), action!],
      ],
    );
  }
}

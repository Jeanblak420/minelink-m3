import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_charts.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_workspace.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// The page shape all three targets screens share: a band, then a workspace
/// filling what is left.
///
/// The **cap** is the reason this is a widget rather than three copies of
/// `Column(children: [band, Expanded(body)])`.
///
/// An unflexed child of a `Column` does not shrink — it takes its natural
/// height and, if that is more than the Column has, it overflows. At text scale
/// 2.0 on a 700px console the org-type band is taller than the viewport on its
/// own: a paragraph of subtitle, a three-pill selector and a four-figure stats
/// row. Measured overflow, 60px, and the workspace below it pushed off the
/// screen entirely.
///
/// Half the viewport, scrolled internally. Every ordinary text size is
/// unaffected — the band is nowhere near half a screen at 1.0 — and the extreme
/// one degrades into a scroll rather than into content clipped below a fold
/// with nothing to say it is there.
///
/// The platform and company screens do not overflow today (neither carries the
/// org-type selector) and use this anyway: the shape is the fault, not the one
/// screen that happened to cross the line first.
class TargetsPage extends StatelessWidget {
  const TargetsPage({super.key, required this.band, required this.body});

  final Widget band;
  final Widget body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    box.hasBoundedHeight ? box.maxHeight / 2 : double.infinity,
              ),
              child: SingleChildScrollView(child: band),
            ),
            Expanded(child: body),
          ],
        ),
      );
}

/// The band above each targets screen: what you are looking at on the left,
/// how it is going on the right.
///
/// The three scopes differ in what they put in [selector] — nothing, a
/// three-way org-type switch, or a company picker — which is the whole reason
/// they are separate screens rather than one screen with a dropdown.
class TargetsBand extends StatelessWidget {
  const TargetsBand({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.scopeLabel,
    this.headline,
    this.selector,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Short uppercase tag — 'PLATFORM-WIDE', 'BY ORG TYPE', 'BY COMPANY'.
  final String scopeLabel;

  /// Live month-to-date figures. Null while the data is still loading, which
  /// keeps the band from flashing zeros before the first read lands.
  final TargetsHeadline? headline;

  final Widget? selector;

  @override
  Widget build(BuildContext context) {
    final t = MlGlass.of(context);

    return Container(
      color: t.bg0,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: MlPanel(
        tokens: t,
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final identity = _identity(context, t);
                final stats = _stats(context, t);
                if (box.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 16), stats],
                  );
                }
                // Both sides flex. Left unflexed, the stats Wrap is laid out
                // against unbounded width, lays itself out on one line however
                // wide that comes to, and pushes the row over — which is what
                // it did at 860px with the text-size slider at 1.3. Bounded,
                // it wraps onto a second line instead.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: identity),
                    const SizedBox(width: 18),
                    Flexible(flex: 4, child: stats),
                  ],
                );
              },
            ),
            if (selector != null) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: t.line2),
              const SizedBox(height: 14),
              selector!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, MlGlass t) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlWell(icon: icon, color: t.accent2, size: 38, iconSize: 18, radius: 10),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.editorialMedium.copyWith(
                          color: t.inkHi,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _tag(t, scopeLabel, t.accent2),
                    if (headline?.cycleLocked ?? false) ...[
                      const SizedBox(width: 6),
                      _tag(t, 'CYCLE LOCKED', t.inkLo),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: context.mlText.bodySmall.copyWith(
                    color: t.inkMid,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _stats(BuildContext context, MlGlass t) {
    final h = headline;
    if (h == null) {
      return SizedBox(
        height: 44,
        child: Center(
          child: Text(
            'reading…',
            style: context.mlText.labelSmall.copyWith(
              color: t.inkLo,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    final band = mlOutcomeColor(t, h.outcome);
    return Wrap(
      spacing: 22,
      runSpacing: 12,
      children: [
        _stat(context, t, h.periodLabel.toUpperCase(), '${mlTons(h.actual)} t',
            'moved so far', t.inkHi),
        _stat(
          context,
          t,
          'TARGET',
          h.target > 0 ? '${mlTons(h.target, decimals: 0)} t' : 'not set',
          h.target > 0 ? 'this month' : 'nothing to measure against',
          h.target > 0 ? t.inkHi : t.inkLo,
        ),
        _stat(
          context,
          t,
          'ATTAINMENT',
          h.target > 0 ? '${(h.attainment * 100).round()}%' : '—',
          h.outcome.label.toLowerCase(),
          band,
        ),
        _stat(context, t, 'CYCLE', '${h.elapsedDays}/365', h.cycleLabel,
            t.accent2),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    MlGlass t,
    String label,
    String value,
    String sub,
    Color color,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: MlGlass.sans,
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: t.inkLo,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: MlGlass.mono,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: context.mlText.labelSmall.copyWith(
              color: t.inkXlo,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );

  static Widget _tag(MlGlass t, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          borderRadius: MlShape.radiusSmall,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MlGlass.sans,
            fontSize: 9,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

/// A pill in a scope selector — used by the org-type switch and the company
/// picker so the two read as the same control.
class TargetsScopePill extends StatelessWidget {
  const TargetsScopePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MlGlass.of(context);
    return MlHoverLift(
      lift: 0,
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.15)
              : t.inkHi.withValues(alpha: hovered ? 0.05 : 0.02),
          border: Border.all(
            color: selected ? t.accent.withValues(alpha: 0.45) : t.line,
          ),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14, color: selected ? t.accent2 : t.inkMid),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.mlText.labelMedium.copyWith(
                    color: selected ? t.accent2 : t.inkMid,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: TextStyle(
                      fontFamily: MlGlass.sans,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: t.inkXlo,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

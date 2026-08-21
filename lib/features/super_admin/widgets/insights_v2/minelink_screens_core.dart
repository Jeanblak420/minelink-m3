// ============================================================================
// MineLink Technologies — Screens Core
// ----------------------------------------------------------------------------
// Design tokens + data models for the two ported screens:
//   • Super Admin Dashboard      (design-system palette, light + dark)
//   • Transporters Overview V3   (the "Glass" palette, dark-native)
//
// Zero package dependencies: Flutter SDK + Material icons only.
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_console_palettes.dart';


// ===========================================================================
// SECTION 3 — Data models
// ===========================================================================

/// A tinted chip / well colour pair. `tint` backs the well, `line` its border,
/// `fg` the glyph.
@immutable
class MlChipTone {
  const MlChipTone(this.base, this.fg);

  final Color base;
  final Color fg;

  Color get tint => base.withValues(alpha: 0.10);
  Color get line => base.withValues(alpha: 0.28);

  // The six hues come from `MlConsolePalettes.chipRamp` (S5-19). They stay a
  // ramp there rather than six loose tokens because their job is to be
  // distinguishable from one another, which is a property of the set.
  static const MlChipTone blue = MlChipTone(
      MlConsolePalettes.chipBlueBase, MlConsolePalettes.chipBlueFg);
  static const MlChipTone cyan = MlChipTone(
      MlConsolePalettes.chipCyanBase, MlConsolePalettes.chipCyanFg);
  static const MlChipTone green = MlChipTone(
      MlConsolePalettes.chipGreenBase, MlConsolePalettes.chipGreenFg);
  static const MlChipTone amber = MlChipTone(
      MlConsolePalettes.chipAmberBase, MlConsolePalettes.chipAmberFg);
  static const MlChipTone red = MlChipTone(
      MlConsolePalettes.chipRedBase, MlConsolePalettes.chipRedFg);
  static const MlChipTone violet = MlChipTone(
      MlConsolePalettes.chipVioletBase, MlConsolePalettes.chipVioletFg);
}

enum MlDelta { up, warn, good, live, flat, none }

/// Org-type rollup card on the dashboard.
@immutable
class MlOrgAggregate {
  const MlOrgAggregate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.metrics,
    required this.spark,
    required this.sparkColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final MlChipTone tone;

  /// Ordered label → value pairs shown along the card foot.
  final List<MapEntry<String, String>> metrics;
  final List<double> spark;
  final Color sparkColor;
}

/// A registry stat tile.
@immutable
class MlRegistryStat {
  const MlRegistryStat({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.sub,
    this.unit,
    this.delta,
    this.deltaTone = MlDelta.none,
  });

  final String id;
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final MlChipTone tone;
  final String sub;
  final String? delta;
  final MlDelta deltaTone;
}

/// A pending-request card.
@immutable
class MlPendingRequest {
  const MlPendingRequest({
    required this.id,
    required this.label,
    required this.icon,
    required this.count,
    required this.sub,
    required this.tone,
  });

  final String id;
  final String label;
  final IconData icon;
  final int count;
  final String sub;
  final MlChipTone tone;
}

enum MlExpiry { ok, warn, expired }

/// A row in "Recently active organizations".
@immutable
class MlRecentOrg {
  const MlRecentOrg({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.location,
    required this.users,
    required this.seatsUsed,
    required this.seats,
    required this.expiry,
    required this.date,
    required this.expiryState,
    required this.avatarColors,
  });

  final String id;
  final String name;
  final String type;
  final String status;
  final String location;
  final int users;
  final int seatsUsed;
  final int seats;
  final String expiry;
  final String date;
  final MlExpiry expiryState;
  final List<Color> avatarColors;

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join()
      .toUpperCase();
}

/// A transporter company on the overview screen.
@immutable
class MlTransporter {
  const MlTransporter({
    this.id = '',
    required this.code,
    required this.name,
    required this.badges,
    required this.employees,
    required this.drivers,
    required this.fleet,
    required this.routes,
    required this.trips,
    required this.tons,
    required this.waybillsDone,
    required this.waybillsOpen,
    required this.utilization,
    required this.waybillsClosedPct,
    required this.activity,
    required this.tempo,
  });

  /// Company id, used to open that transporter's workspace. Empty means the
  /// caller has no id to route with, and the card hides its open action
  /// rather than offering a button that goes nowhere.
  final String id;

  final String code;
  final String name;

  /// Status pills — `(text, kind)` where kind is one of c/g/w/b.
  final List<MapEntry<String, String>> badges;

  final int employees;
  final int drivers;
  final int fleet;
  final int routes;
  final int trips;
  final String tons;
  final int waybillsDone;
  final int waybillsOpen;
  final int utilization;
  final int waybillsClosedPct;
  final String activity;
  final List<double> tempo;
}

@immutable
class MlDonutSegment {
  const MlDonutSegment(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

@immutable
class MlAlert {
  const MlAlert({
    required this.kind,
    required this.icon,
    required this.title,
    required this.detail,
    required this.age,
  });

  /// g = good, w = warn, b = bad.
  final String kind;
  final IconData icon;
  final String title;
  final String detail;
  final String age;
}

@immutable
class MlBoardRow {
  const MlBoardRow(this.rank, this.name, this.value, {this.idle = false});

  final String rank;
  final String name;
  final String value;
  final bool idle;
}


// ===========================================================================
// SECTION 5 — Shared surface + text primitives
// ---------------------------------------------------------------------------
// Both screens are built from these four. Keeping them here rather than
// private to one file is what makes the console read as one product instead
// of two screens that happen to share a palette.
// ===========================================================================

/// Flat surface with a single hairline. The console's only container.
class MlPanel extends StatelessWidget {
  const MlPanel({
    super.key,
    required this.tokens,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 14,
    this.inset = false,
  });

  final MlGlass tokens;
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// Slightly recessed — for cards nested inside another panel.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: inset ? t.bg1 : t.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.line2),
      ),
      child: child,
    );
  }
}

/// Letterspaced uppercase caption.
class MlCap extends StatelessWidget {
  const MlCap(this.text, {super.key, required this.tokens, this.size = 11});

  final String text;
  final MlGlass tokens;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        // These captions sit beside a pill in fixed-width cards, and the
        // console lets an admin scale text to 130% (Settings → User
        // Preferences), so the caption has to give way rather than overflow.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          fontFamily: MlGlass.sans,
          fontSize: size,
          letterSpacing: size * 0.16,
          fontWeight: FontWeight.w600,
          color: tokens.inkMid,
        ),
      );
}

/// Status pill. [kind] is one of n (neutral), c (cyan), g (good), w (warn),
/// b (bad), v (violet).
class MlPill extends StatelessWidget {
  const MlPill(this.text, {super.key, required this.tokens, this.kind = 'n'});

  final String text;
  final MlGlass tokens;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    late final Color fg;
    switch (kind) {
      case 'g':
        fg = t.good;
        break;
      case 'c':
        fg = t.accent2;
        break;
      case 'w':
        fg = t.warn;
        break;
      case 'b':
        fg = t.bad;
        break;
      case 'v':
        fg = t.violet;
        break;
      default:
        fg = t.ink;
    }
    final neutral = kind == 'n';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: neutral ? t.inkHi.withValues(alpha: 0.05) : fg.withValues(alpha: 0.12),
        border:
            Border.all(color: neutral ? t.lineStrong : fg.withValues(alpha: 0.3)),
        borderRadius: MlShape.pill,
      ),
      // A pill given a bounded width had nothing to do but overflow: no
      // maxLines, no overflow behaviour. That is fine while every caller keeps
      // it unflexed and lets it size itself, and it is exactly what stops a
      // caller from putting it in a `Flexible` when the row runs out of room —
      // which is the one thing that would let a long org type ("MINESUPPLIER")
      // yield space instead of pushing the seat count off a 360px phone.
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: context.mlText.labelSmall.copyWith(color: fg),
      ),
    );
  }
}

/// Caption above, mono figure below — the unit that repeats everywhere.
class MlStat extends StatelessWidget {
  const MlStat({
    super.key,
    required this.tokens,
    required this.label,
    required this.value,
    this.unit,
    this.suffix,
    this.suffixColor,
    this.valueColor,
    this.valueSize = 15,
    this.leadingDot,
  });

  final MlGlass tokens;
  final String label;
  final String value;
  final String? unit;
  final String? suffix;
  final Color? suffixColor;
  final Color? valueColor;
  final double valueSize;

  /// Small status dot before the suffix — used for the live-users figure.
  final Color? leadingDot;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: context.mlText.labelSmall.copyWith(
            color: t.inkMid,
            letterSpacing: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: MlGlass.mono,
                  fontSize: valueSize,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? t.inkHi,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (unit != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(unit!,
                    style: context.mlText.code(
                      color: t.inkLo,
                      size: 10,
                      weight: FontWeight.w400,
                    )),
              ),
            if (leadingDot != null) ...[
              const SizedBox(width: 7),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: leadingDot, shape: BoxShape.circle),
              ),
            ],
            if (suffix != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(suffix!,
                    style: context.mlText.labelSmall.copyWith(
                      color: suffixColor ?? t.inkLo,
                      fontWeight: FontWeight.w400,
                    )),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tinted icon well.
class MlWell extends StatelessWidget {
  const MlWell({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.iconSize = 18,
    this.radius = 11,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon, size: iconSize, color: color),
      );
}

/// Section heading in the display face, with optional meta and action link.
class MlSectionHead extends StatelessWidget {
  const MlSectionHead({
    super.key,
    required this.tokens,
    required this.title,
    this.subtitle,
    this.meta,
    this.link,
    this.onLink,
    this.badge,
    this.size = 19,
  });

  final MlGlass tokens;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? link;
  final VoidCallback? onLink;
  final Widget? badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return LayoutBuilder(builder: (context, c) {
      // The trailing meta/link column is unflexed -- deliberately, because a
      // short right-aligned block given flex: 1 lands mid-row instead of at
      // the edge (CLAUDE.md 10.4). Unflexed means unbounded, though, so when
      // it genuinely cannot fit beside the title it overflows rather than
      // shrinking. Below this floor it goes underneath instead, which is the
      // only honest option: it is a real sentence and a real action, so
      // neither ellipsis nor omission would do.
      //
      // WHEN TO STACK IS MEASURED, NOT GUESSED.
      //
      // This was `c.maxWidth < 420 * scale`, and 420 is a number somebody
      // chose. It is wrong for any title longer than that constant assumed:
      // driven in a browser at a ~500px viewport on 2026-08-21, the console's
      // first band read **"Live operations by organization ty…"**. 500 minus
      // the page gutters is 468 of content, 468 is not below 420, so the
      // header did not stack — and the trailing block is unflexed, so the
      // title's `Flexible` gave way and ellipsised a heading.
      //
      // At 412 it was fine, which is the tell: the fault lives in a BAND
      // (roughly 420 to 560 of content) rather than at the small end, so
      // sweeping narrower and narrower never reaches it.
      //
      // A `TextPainter` answers the actual question — does the title fit
      // beside the trailing block? — and answers it for every title, at every
      // text scale, instead of for one imagined title at 420. The scale comes
      // in through the painter's own `textScaler`, so the separate `scale`
      // fudge is gone with the constant.
      final scaler = MediaQuery.textScalerOf(context);
      double widthOf(String s, TextStyle style) {
        final tp = TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        return tp.width;
      }

      final titleStyle = TextStyle(
        fontFamily: MlGlass.display,
        fontFamilyFallback: MlGlass.displayFallback,
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: t.inkHi,
      );
      final metaStyle = context.mlText.labelSmall.copyWith(
        color: t.inkLo,
        fontWeight: FontWeight.w400,
      );
      final linkStyle = context.mlText.labelMedium.copyWith(color: t.accent2);

      // The trailing column is as wide as its widest line.
      final trailingWidth = [
        if (meta != null) widthOf(meta!, metaStyle),
        if (link != null) widthOf('$link →', linkStyle),
      ].fold<double>(0, (a, b) => a > b ? a : b);

      // A badge cannot be measured — it is an arbitrary widget — so it is
      // allowed for generously. Over-estimating stacks the header slightly
      // early, which costs a line; under-estimating cuts a heading, which is
      // the fault being fixed.
      const badgeAllowance = 72.0;
      final needed = widthOf(title, titleStyle) +
          (badge != null ? badgeAllowance : 0) +
          16 +
          trailingWidth;

      final stacked =
          (meta != null || link != null) && needed > c.maxWidth;

      final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    // THE SAME style object the measurement above used. Two
                    // copies of a TextStyle is how a measurement stops
                    // describing the thing it measured.
                    child: Text(
                      title,
                      // TWO lines, explicitly.
                      //
                      // It was inheriting a single line, so once the header
                      // had stacked and given the title the whole row, a
                      // title still too long for one line was ellipsised
                      // anyway: "Live operations by organization type" on a
                      // 412px phone at text scale 1.3. Stacking buys the
                      // width; this is what lets the title use it.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 9),
                    badge!,
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: context.mlText.bodySmall.copyWith(color: t.inkMid),
                ),
              ],
            ],
          );

      final trailing = Column(
            crossAxisAlignment:
                stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (meta != null)
                Text(meta!, style: metaStyle),
              if (link != null) ...[
                if (meta != null) const SizedBox(height: 3),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onLink,
                    child: Text('$link →', style: linkStyle),
                  ),
                ),
              ],
            ],
          );

      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleBlock,
            const SizedBox(height: 8),
            trailing,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: titleBlock),
          if (meta != null || link != null) ...[
            const SizedBox(width: 14),
            trailing,
          ],
        ],
      );
    });
  }
}

// ===========================================================================
// SECTION 6 — Small shared helpers
// ===========================================================================

/// Honours the platform "reduce motion" setting.
/// 1234567 -> "1,234,567". Used wherever the screens print a count or tonnage.
String mlThousands(int value) {
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}$b';
}

/// Inverse of [mlThousands] for the pre-formatted tonnage carried on
/// [MlTransporter.tons]. Returns 0 when the string holds no digits.
double mlParseTons(String formatted) =>
    double.tryParse(formatted.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

/// The duration implicit animations collapse to when the platform asks for
/// reduced motion.
///
/// Deliberately 1ms rather than [Duration.zero]. A zero duration makes
/// [AnimationController] skip the ticker entirely: it assigns the target value
/// and calls `notifyListeners()` synchronously. An [AnimatedSize] listening to
/// that controller then calls `markNeedsLayout()` from inside its own
/// `performLayout`, which asserts with "A RenderAnimatedSize was mutated in its
/// own performLayout implementation". 1ms keeps the controller on the ticker
/// and still lands inside the first frame, so it is visually instant.
const Duration mlReducedMotion = Duration(milliseconds: 1);

Duration mlScreenMotion(BuildContext context, Duration full) {
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return reduce ? mlReducedMotion : full;
}

/// A hover-elevating wrapper. Both screens lift their cards on pointer enter;
/// this keeps that in one place instead of three copies of the same
/// MouseRegion + AnimatedContainer.
class MlHoverLift extends StatefulWidget {
  const MlHoverLift({
    super.key,
    required this.builder,
    this.onTap,
    this.lift = 3,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final double lift;

  @override
  State<MlHoverLift> createState() => _MlHoverLiftState();
}

class _MlHoverLiftState extends State<MlHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: mlScreenMotion(context, const Duration(milliseconds: 180)),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
              0, _hovered && widget.onTap != null ? -widget.lift : 0, 0),
          child: widget.builder(context, _hovered),
        ),
      ),
    );
  }
}

/// Lays children out in a fixed-column grid with equal gaps. Simpler and more
/// predictable here than GridView, which wants a scrollable parent.
class MlGrid extends StatelessWidget {
  const MlGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = 14,
    this.runGap,
  });

  final int columns;
  final List<Widget> children;
  final double gap;
  final double? runGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = columns.clamp(1, 8);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: runGap ?? gap,
          children: children
              .map((child) => SizedBox(width: w > 0 ? w : c.maxWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
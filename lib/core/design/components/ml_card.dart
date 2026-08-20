import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The card. **320 of the 515 hand-rolled `BoxDecoration`s** in `lib/features`
/// are this shape — a rounded surface with a hairline border — drawn thirteen
/// different ways.
///
/// Surface, ink and border come from [MlSemantic], which is a derived view
/// onto the single `ColorScheme` (see its doc for the one place the mapping is
/// deliberately not one-to-one). Shape comes from [MlShape]. Motion comes from
/// [MlMotion].
///
/// ## What changed in the M3 rebuild
///
/// **The hover lift ignored reduce-motion.** It animated on
/// `MlTokens.durFast` + `Curves.easeOut` — a bare duration and a bare curve,
/// neither of which consults `MediaQuery.disableAnimations`. A user who has
/// asked the operating system to stop moving things still got a card that
/// slid 1px under the pointer, and so did every one of the ~40 screens that
/// puts a grid of these on the page. It now goes through [MlMotion.of] and
/// [MlMotion.curveOf], which collapse to 1ms and linear when the setting is
/// on. (1ms, never `Duration.zero` — `CLAUDE.md` §10.4 records why: a zero
/// controller notifies listeners *synchronously*, and `AnimatedSize` then
/// calls `markNeedsLayout()` from inside its own `performLayout`.)
///
/// **The radii were off-scale.** 16 and 20 (`rLg`/`rXl`) are not steps of the
/// M3 shape scale, which runs 4 / 8 / 12 / 16 / 20 / 28. 16 happens to be
/// [MlShape.large] and 20 [MlShape.largeIncreased], so the *values* survive
/// unchanged — but they are now named as scale steps rather than as two of the
/// thirteen ad-hoc radii this component exists to replace.
///
/// **A tappable card was not announced as tappable.** The `InkWell` gave it a
/// gesture and a ripple but no semantics, so a screen reader read the card's
/// contents as loose text with no indication it could be activated. It is now
/// a button in the semantics tree when [onTap] is set.
class MlCard extends StatefulWidget {
  final Widget child;

  /// The raised treatment: a cyan-tinted gradient wash, accent border and a
  /// deeper shadow, at one shape step up. For the one card on a page that is
  /// the page's subject.
  final bool hero;

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hoverLift;

  /// What a screen reader announces for the card as a whole. Only meaningful
  /// with [onTap] — an untapped card is a container, and labelling it would
  /// hide the real content behind a summary.
  final String? semanticLabel;

  const MlCard({
    super.key,
    required this.child,
    this.hero = false,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.hoverLift = false,
    this.semanticLabel,
  });

  /// The short 44×3 accent rule shown under hero-tile titles.
  static Widget heroTitleRule() => Container(
        width: 44,
        height: 3,
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        decoration: BoxDecoration(
          color: MlTokens.accent,
          borderRadius: MlShape.radiusExtraSmall,
        ),
      );

  @override
  State<MlCard> createState() => _MlCardState();
}

class _MlCardState extends State<MlCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius =
        widget.hero ? MlShape.radiusLargeIncreased : MlShape.radiusLarge;

    final decoration = BoxDecoration(
      color: widget.hero ? null : semantic.surfaceCard,
      gradient: widget.hero
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      MlPortalSurfaces.cardDarkTop,
                      MlPortalSurfaces.cardDarkBottom,
                    ]
                  : [
                      MlPortalSurfaces.cardLightTop,
                      MlPortalSurfaces.cardLightBottom,
                    ],
            )
          : null,
      borderRadius: radius,
      border: Border.all(
        color: widget.hero ? semantic.borderAccent : semantic.borderCard,
      ),
      boxShadow: widget.hero ? MlTokens.shadowHero : MlTokens.shadowSm,
    );

    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          child: content,
        ),
      );
    }

    final lift = (widget.hoverLift || widget.onTap != null) && _hovered;
    Widget card = AnimatedContainer(
      duration: MlMotion.of(context, MlMotion.stateChange),
      curve: MlMotion.curveOf(context, MlMotion.standard),
      transform: Matrix4.translationValues(0, lift ? -1 : 0, 0),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (widget.onTap != null) {
      card = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: card,
      );
    }

    if (widget.onTap == null && !widget.hoverLift) return card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: card,
    );
  }
}

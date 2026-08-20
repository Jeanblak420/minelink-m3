import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// MineLink surface card. White (dark: raised navy), 16px radius
/// (hero: 20px + cyan-tinted gradient wash, accent border and hero shadow),
/// hairline border, soft slate shadow. Hovering lifts the card 1px.
class MlCard extends StatefulWidget {
  final Widget child;
  final bool hero;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hoverLift;

  const MlCard({
    super.key,
    required this.child,
    this.hero = false,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.hoverLift = false,
  });

  /// The short 44×3 accent rule shown under hero-tile titles.
  static Widget heroTitleRule() => Container(
        width: 44,
        height: 3,
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        decoration: BoxDecoration(
          color: MlTokens.accent,
          borderRadius: BorderRadius.circular(2),
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
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final radius = BorderRadius.circular(
      widget.hero ? MlTokens.rXl : MlTokens.rLg,
    );

    final decoration = BoxDecoration(
      color: widget.hero ? null : semantic.surfaceCard,
      gradient: widget.hero
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [MlPortalSurfaces.cardDarkTop, MlPortalSurfaces.cardDarkBottom]
                  : [MlPortalSurfaces.cardLightTop, MlPortalSurfaces.cardLightBottom],
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
    final card = AnimatedContainer(
      duration: MlTokens.durFast,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, lift ? -1 : 0, 0),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (widget.onTap == null && !widget.hoverLift) return card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: card,
    );
  }
}

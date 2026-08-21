import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

enum _MlButtonKind { primary, go, leave, tonal, outline, ghost, danger }

/// MineLink buttons — 12px radius, w700, ≥48px tall (compact: 40),
/// hover lifts 1px. Variants:
/// * [MlButton.primary] — solid cyan with a soft cyan shadow
/// * [MlButton.go] — green gradient (confirm load / mark arrived)
/// * [MlButton.leave] — orange gradient (mark departed / mark left)
/// * [MlButton.tonal] — white pill on tinted cards
/// * [MlButton.outline] — accent border/text ("Open →")
/// * [MlButton.ghost] — borderless muted
/// * [MlButton.danger] — red
class MlButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool compact;
  final bool expand;
  final _MlButtonKind _kind;

  const MlButton._({
    super.key,
    required this.label,
    required this.onPressed,
    required _MlButtonKind kind,
    this.icon,
    this.trailingIcon,
    this.compact = false,
    this.expand = false,
  }) : _kind = kind;

  factory MlButton.primary(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          IconData? trailingIcon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.primary,
          icon: icon,
          trailingIcon: trailingIcon,
          compact: compact,
          expand: expand);

  factory MlButton.go(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.go,
          icon: icon,
          compact: compact,
          expand: expand);

  factory MlButton.leave(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.leave,
          icon: icon,
          compact: compact,
          expand: expand);

  factory MlButton.tonal(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          IconData? trailingIcon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.tonal,
          icon: icon,
          trailingIcon: trailingIcon,
          compact: compact,
          expand: expand);

  factory MlButton.outline(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          IconData? trailingIcon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.outline,
          icon: icon,
          trailingIcon: trailingIcon,
          compact: compact,
          expand: expand);

  factory MlButton.ghost(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          IconData? trailingIcon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.ghost,
          icon: icon,
          trailingIcon: trailingIcon,
          compact: compact,
          expand: expand);

  factory MlButton.danger(
          {Key? key,
          required String label,
          VoidCallback? onPressed,
          IconData? icon,
          bool compact = false,
          bool expand = false}) =>
      MlButton._(
          key: key,
          label: label,
          onPressed: onPressed,
          kind: _MlButtonKind.danger,
          icon: icon,
          compact: compact,
          expand: expand);

  @override
  State<MlButton> createState() => _MlButtonState();
}

class _MlButtonState extends State<MlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final enabled = widget.onPressed != null;
    final height = widget.compact ? 40.0 : 48.0;

    Gradient? gradient;
    Color? bg;
    Color fg;
    BorderSide side = BorderSide.none;
    List<BoxShadow> shadow = const [];

    switch (widget._kind) {
      case _MlButtonKind.primary:
        bg = MlTokens.accent;
        // Dark ink on the accent, NOT white. Measured, not guessed:
        //   white     on #22D3EE →  1.81:1   fails (WCAG wants 4.5:1)
        //   navy ink  on #22D3EE → 10.43:1   passes comfortably
        // This was already failing before the accent moved (white on the old
        // #00B5D8 was 2.44:1 — also a fail); S5-5 made it worse and this is
        // where it gets fixed. The accent is a LIGHT cyan; light text on it was
        // never going to work.
        fg = MlTokens.navy950;
        shadow = const [
          // Was Color(0x5900B5D8) — the OLD accent hex, hardcoded, so the glow
          // stayed the previous colour after S5-5 changed the button beneath it.
          BoxShadow(
              color: MlTokens.glowAccent, offset: Offset(0, 6), blurRadius: 16),
        ];
      case _MlButtonKind.go:
        gradient = const LinearGradient(
            colors: [MlTokens.green600, MlTokens.green700]);
        fg = MlTokens.inkOnFill;
        shadow = const [
          BoxShadow(
              color: MlTokens.glowSuccess, offset: Offset(0, 6), blurRadius: 14),
        ];
      case _MlButtonKind.leave:
        gradient = const LinearGradient(
            colors: [MlTokens.orange500, MlTokens.orange600]);
        fg = MlTokens.inkOnFill;
        shadow = const [
          BoxShadow(
              color: MlTokens.glowWarn, offset: Offset(0, 6), blurRadius: 14),
        ];
      case _MlButtonKind.tonal:
        // Brightness-aware so the label stays legible in dark mode (the app
        // default). Previously hard-coded navy800, which rendered dark-on-dark
        // and made the pill nearly invisible.
        bg = semantic.surfaceCard;
        fg = semantic.textStrong;
        side = BorderSide(color: semantic.borderCard);
        shadow = MlTokens.shadowXs;
      case _MlButtonKind.outline:
        bg = Colors.transparent;
        fg = MlTokens.accentHover;
        side = const BorderSide(color: MlTokens.accent);
      case _MlButtonKind.ghost:
        bg = Colors.transparent;
        fg = semantic.textMuted;
      case _MlButtonKind.danger:
        bg = MlTokens.red600;
        fg = MlTokens.inkOnFill;
    }
    if (!enabled) {
      bg = semantic.surfaceSunken;
      gradient = null;
      fg = semantic.textFaint;
      shadow = const [];
    }

    final radius = BorderRadius.circular(MlTokens.rMd);
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.compact ? 17 : 19, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            // TWO lines on a FULL-WIDTH button, one on a compact one.
            //
            // A compact button's label is a word or two and one line is right.
            // An `expand: true` button is the page's primary action and its
            // label is often a sentence — the weighbridge's reads "Save empty
            // weight — truck goes to load", and at 412px it rendered as "Save
            // empty weight — truck goes t…". A control that will not say what
            // it does is worse than a taller control. Photographed 2026-08-21.
            maxLines: widget.expand ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: widget.compact ? 13.5 : 15,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: widget.compact ? 16 : 18, color: fg),
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        // Through MlMotion, so the hover lift stops when the user has asked
        // the system to stop moving things. A bare Duration + Curves pair
        // never consults MediaQuery.disableAnimations.
        duration: MlMotion.of(context, MlMotion.stateChange),
        curve: MlMotion.curveOf(context, MlMotion.standard),
        transform: Matrix4.translationValues(
            0, _hovered && enabled ? -1 : 0, 0),
        decoration: BoxDecoration(
          color: gradient == null ? bg : null,
          gradient: gradient,
          borderRadius: radius,
          border: side == BorderSide.none ? null : Border.fromBorderSide(side),
          boxShadow: shadow,
        ),
        // A MINIMUM, not a fixed height — CLAUDE.md §10.4. A two-line label
        // on a full-width button needs about 42px of text in a 48px box, and
        // a fixed height clips it rather than growing.
        constraints: BoxConstraints(minHeight: height),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 14 : 18, vertical: 6),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

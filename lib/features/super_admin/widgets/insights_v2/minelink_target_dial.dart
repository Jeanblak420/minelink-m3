// ============================================================================
// MineLink — Target Dial
// ----------------------------------------------------------------------------
// One widget, used for every target on the screen: each open month in the
// short-term tab, and each of the six horizons in the long-term tab.
//
// It carries three things at once — the ring is attainment, the figure is the
// target, the caption is the actual — and offers four ways to change it:
// typing, Enter/blur commit, arrow-key nudge, and the +/- buttons.
//
// When [editable] is false it renders no input at all. A disabled field can
// still be focused and puzzled over; an absent one cannot.
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'minelink_screens_core.dart';
import 'minelink_targets_core.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

class MlTargetDial extends StatefulWidget {
  const MlTargetDial({
    super.key,
    required this.tokens,
    required this.label,
    required this.target,
    required this.onChanged,
    this.sublabel,
    this.actual,
    this.editable = true,
    this.highlighted = false,
    this.note,
    this.lockedNote = 'Locked',
    this.errorText,
  });

  final MlGlass tokens;

  final String label;
  final String? sublabel;

  /// Tons targeted. Zero renders as "Not set" rather than as a real zero.
  final double target;

  /// Tons achieved, or null when the checkpoint has not been reached. Null
  /// suppresses the ring — an unreached horizon must not read as 0%.
  final double? actual;

  final ValueChanged<double> onChanged;

  final bool editable;
  final bool highlighted;

  /// Small caption under the actual, e.g. 'checkpoint in 13 days'.
  final String? note;

  /// Shown in place of the controls when [editable] is false.
  final String lockedNote;

  /// Why the last write was refused, e.g. 'Target for 2026-07 is closed'.
  ///
  /// When set, the typed value STAYS in the field — the point is to let the
  /// person correct what they wrote, and clearing it would make them retype a
  /// figure the server has already told them is wrong.
  final String? errorText;

  @override
  State<MlTargetDial> createState() => _MlTargetDialState();
}

class _MlTargetDialState extends State<MlTargetDial> {
  late final TextEditingController _c =
      TextEditingController(text: _display(widget.target));
  final FocusNode _focus = FocusNode();

  static String _display(double v) => v > 0 ? mlTons(v, decimals: 0) : '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant MlTargetDial old) {
    super.didUpdateWidget(old);
    // Only rewrite the field when the value changed underneath us and the user
    // is not mid-edit, or we'd yank the caret out from under them.
    //
    // Also never while an error is showing. A refused write is followed by a
    // re-read of the server's truth, which lands here as a changed target —
    // rewriting then would wipe the figure the person is in the middle of
    // correcting, and the message telling them to correct it would still be on
    // screen underneath.
    if (old.target != widget.target &&
        !_focus.hasFocus &&
        widget.errorText == null) {
      _c.text = _display(widget.target);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (!widget.editable) return;
    final v = mlParseTargetTons(_c.text);
    widget.onChanged(v == null ? 0 : v.roundToDouble());
  }

  void _nudge(int dir, {bool large = false}) {
    if (!widget.editable) return;
    final cur = mlParseTargetTons(_c.text) ?? widget.target;
    final step = (cur >= 1000 ? 100.0 : 10.0) * (large ? 10 : 1);
    final next = math.max(0, cur + dir * step).roundToDouble();
    _c.text = _display(next);
    _c.selection = TextSelection(baseOffset: 0, extentOffset: _c.text.length);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final pending = widget.actual == null;
    final att =
        (widget.target > 0 && !pending) ? widget.actual! / widget.target : 0.0;

    final ringColor = widget.target <= 0
        ? t.inkXlo
        : pending
            ? t.inkLo
            : att >= MlTargetBands.surpassed
                ? t.good
                : att >= MlTargetBands.close
                    ? t.accent
                    : t.warn;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      decoration: BoxDecoration(
        color: widget.highlighted
            ? t.accent.withValues(alpha: 0.06)
            : t.inkHi.withValues(alpha: 0.015),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(
          color: widget.highlighted
              ? t.accent.withValues(alpha: 0.38)
              : t.line,
          style: widget.editable ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      foregroundDecoration: widget.editable
          ? null
          : BoxDecoration(
              borderRadius: MlShape.radiusMedium,
              border: Border.all(color: t.line),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(t),
          const SizedBox(height: 13),
          _body(t, ringColor, att, pending),
          const SizedBox(height: 12),
          widget.editable ? _controls(t) : _lockedChip(t),
          if (widget.editable && widget.errorText != null) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 12, color: t.bad),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: context.mlText.labelSmall.copyWith(
                      color: t.bad,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(MlGlass t) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: context.mlText.overline.copyWith(color: t.inkHi),
                ),
                if (widget.sublabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.sublabel!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: MlGlass.sans,
                      fontSize: 9,
                      letterSpacing: 0.7,
                      color: t.inkLo,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.editable)
            Icon(Icons.lock_outline_rounded, size: 12, color: t.inkXlo),
        ],
      );

  Widget _body(MlGlass t, Color ringColor, double att, bool pending) {
    // The ring grows with the text inside it.
    //
    // It was a fixed 70x70 holding a percentage and a caption, so at an
    // accessibility text size the two together were taller than the circle and
    // the column overflowed. Clipping a dial's own reading is the wrong trade:
    // the figure IS the control, and 70px was a proportion of that figure
    // rather than a hard constraint.
    //
    // Capped at 1.5x because the dial sits beside a label column in a
    // fixed-width card; past that the ring starts crowding the words it
    // explains, and the caption is what should give instead.
    final textScale =
        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.5);
    final ring = 70.0 * textScale;

    return Row(
        children: [
          SizedBox(
            width: ring,
            height: ring,
            child: CustomPaint(
              painter: _DialRingPainter(
                value: (widget.target > 0 && !pending)
                    ? att.clamp(0.0, 1.0)
                    : 0,
                track: t.inkHi.withValues(alpha: 0.12),
                fill: ringColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (widget.target > 0 && !pending)
                          ? '${(att * 100).round()}%'
                          : '—',
                      style: TextStyle(
                        fontFamily: MlGlass.mono,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: (widget.target > 0 && !pending)
                            ? t.inkHi
                            : t.inkLo,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'OF TARGET',
                      style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 7,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w600,
                        color: t.inkMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        widget.target > 0
                            ? mlTons(widget.target, decimals: 0)
                            : 'Not set',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MlGlass.mono,
                          fontSize: widget.target > 0 ? 16 : 12,
                          fontWeight: FontWeight.w600,
                          color: widget.target > 0 ? t.inkHi : t.inkLo,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (widget.target > 0)
                      Text(' t',
                          style: context.mlText.code(
                            color: t.inkLo,
                            size: 10,
                            weight: FontWeight.w400,
                          )),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pending
                      ? 'not reached yet'
                      : 'actual ${mlTons(widget.actual!)} t',
                  style: context.mlText.labelSmall.copyWith(
                    color: t.inkLo,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (widget.note != null)
                  Text(
                    widget.note!,
                    style: context.mlText.labelSmall.copyWith(
                      color: t.inkXlo,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
  }

  Widget _controls(MlGlass t) {
    Widget btn(IconData icon, VoidCallback onTap, String tip) => Tooltip(
          message: tip,
          child: MlHoverLift(
            lift: 0,
            onTap: onTap,
            builder: (context, hovered) => Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: hovered
                    ? t.accent.withValues(alpha: 0.16)
                    : t.inkHi.withValues(alpha: 0.04),
                border: Border.all(color: t.line2),
                borderRadius: MlShape.radiusSmall,
              ),
              child: Icon(icon, size: 15, color: t.accent2),
            ),
          ),
        );

    return Row(
      children: [
        btn(Icons.remove_rounded, () => _nudge(-1), 'Decrease'),
        const SizedBox(width: 7),
        Expanded(
          child: SizedBox(
            height: 26,
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.arrowUp): _NudgeIntent(1),
                SingleActivator(LogicalKeyboardKey.arrowDown): _NudgeIntent(-1),
                SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
                    _NudgeIntent(1, large: true),
                SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
                    _NudgeIntent(-1, large: true),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _NudgeIntent: CallbackAction<_NudgeIntent>(
                    onInvoke: (i) {
                      _nudge(i.direction, large: i.large);
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: _c,
                  focusNode: _focus,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _commit(),
                  style: context.mlText.code(
                    color: t.inkHi,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Set target',
                    hintStyle: context.mlText.code(
                      color: t.inkLo,
                      size: 11,
                      weight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    filled: true,
                    fillColor: t.inkHi.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: MlShape.radiusSmall,
                      borderSide: BorderSide(color: t.line2),
                    ),
                    // Red while the server is refusing this value, so the
                    // field itself carries the state and not just the note
                    // beneath it.
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MlShape.radiusSmall,
                      borderSide: BorderSide(
                          color: widget.errorText != null ? t.bad : t.line2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MlShape.radiusSmall,
                      borderSide: BorderSide(
                        color: widget.errorText != null
                            ? t.bad
                            : t.accent.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        btn(Icons.add_rounded, () => _nudge(1), 'Increase'),
        const SizedBox(width: 6),
        Text('t',
            style: context.mlText.code(
              color: t.inkLo,
              size: 10,
              weight: FontWeight.w400,
            )),
      ],
    );
  }

  Widget _lockedChip(MlGlass t) => Container(
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: t.line),
          borderRadius: MlShape.radiusSmall,
        ),
        // Flexible, because a Row hands a non-flex child UNBOUNDED width
        // (CLAUDE.md 10.4) and its own ellipsis then never engages. Only
        // visible above text scale 1.3, which is where these sweeps used to
        // stop -- the shells compose the in-app slider with the platform's
        // and cap at kMaxEffectiveTextScale = 2.0, so everything between the
        // two was a size a real user could reach and nothing had rendered.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 11, color: t.inkXlo),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.lockedNote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.labelSmall.copyWith(color: t.inkLo),
              ),
            ),
          ],
        ),
      );
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.direction, {this.large = false});

  final int direction;
  final bool large;
}

class _DialRingPainter extends CustomPainter {
  const _DialRingPainter({
    required this.value,
    required this.track,
    required this.fill,
  });

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const thickness = 7.0;
    final r = (size.width - thickness) / 2;
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: r);

    canvas.drawCircle(
      rect.center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = track,
    );

    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      value.clamp(0.0, 1.0) * math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DialRingPainter old) =>
      old.value != value || old.fill != fill;
}

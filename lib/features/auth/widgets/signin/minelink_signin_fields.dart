// ============================================================================
// MineLink — Sign-in fields
// ----------------------------------------------------------------------------
//   MlIdentityField  one field for email OR WhatsApp number, which tells you
//                    which one it thinks you are typing
//   MlPasswordField  reveal toggle and a Caps Lock warning
//   MlOtpRow         six boxes: auto-advance, backspace, arrows, paste
//
// Every field keeps a rejected value on screen. Clearing it makes someone
// retype a figure the server has already told them is wrong.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'minelink_signin_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// What the identity field believes it is holding.
enum MlIdentityKind { unknown, email, phone }

// ===========================================================================
// Shared field chrome
// ===========================================================================

class _FieldShell extends StatefulWidget {
  const _FieldShell({
    required this.child,
    required this.focused,
    required this.hasError,
    required this.isValid,
    this.leading,
    this.trailing,
  });

  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final bool focused;
  final bool hasError;
  final bool isValid;

  @override
  State<_FieldShell> createState() => _FieldShellState();
}

class _FieldShellState extends State<_FieldShell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final focused = widget.focused;
    final hasError = widget.hasError;
    final isValid = widget.isValid;

    // Precedence measured off the reference rather than guessed at: `.err` and
    // `.ok` are set on the field, and `.field.ok .inputWrap` outranks
    // `.inputWrap:focus-within`, so a VALID field keeps its green border while
    // focused — focus contributes only the ring and the tint. Verified in the
    // browser: border stayed rgba(52,211,153,.45) while bg/box-shadow went cyan.
    final Color border = hasError
        ? MlAuth.bad.withValues(alpha: 0.7)
        : isValid
            ? MlAuth.good.withValues(alpha: 0.45)
            : focused
                ? MlAuth.accent.withValues(alpha: 0.65)
                : _hover
                    // `.inputWrap:hover{border-color:var(--lineS)}` — the drop
                    // had no hover state at all, so the field did not
                    // acknowledge the pointer before you clicked it.
                    ? MlAuth.lineStrong
                    : MlAuth.line2;

    final Color fill = hasError
        ? MlAuth.bad.withValues(alpha: 0.06)
        : focused
            ? MlAuth.accent.withValues(alpha: 0.05)
            : MlTokens.overlayLight.withValues(alpha: 0.028);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
      duration: mlDuration(context, const Duration(milliseconds: 180)),
      // The shell needs a floor, and `MlAuth.fieldHeight` was declared for it
      // but never used. Without it the box hugged a dense single line, so
      // Material floated the label to y=0 — i.e. straight onto this border,
      // which is not what the design does: there the label sits INSIDE the box
      // on its own line with the input beneath it. minHeight, not height, so
      // text scale 1.3 grows the box instead of overflowing it.
      constraints: const BoxConstraints(minHeight: MlAuth.fieldHeight),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(MlAuth.fieldRadius),
        border: Border.all(color: border),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: (hasError ? MlAuth.bad : MlAuth.accent)
                      .withValues(alpha: hasError ? 0.13 : 0.12),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 46, child: Center(child: widget.leading)),
          Expanded(child: widget.child),
          if (widget.trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: widget.trailing,
            ),
        ],
      ),
      ),
    );
  }
}

/// One-line helper under a field. Occupies its slot whether or not it has
/// something to say, so the form never jumps as messages come and go.
class MlFieldHint extends StatelessWidget {
  const MlFieldHint({super.key, this.text, this.tone = MlHintTone.neutral});

  final String? text;
  final MlHintTone tone;

  @override
  Widget build(BuildContext context) {
    final show = text != null && text!.isNotEmpty;
    final color = switch (tone) {
      MlHintTone.bad => MlAuth.bad,
      MlHintTone.good => MlAuth.good,
      MlHintTone.warn => MlAuth.warn,
      MlHintTone.neutral => MlAuth.inkLo,
    };

    // The reference slides it down into place as it fades in
    // (`transform:translateY(-3px)` → none, .18s), so the line reads as arriving
    // rather than blinking on.
    return AnimatedSlide(
      offset: show ? Offset.zero : const Offset(0, -0.2),
      duration: mlDuration(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
      opacity: show ? 1 : 0,
      duration: mlDuration(context, const Duration(milliseconds: 180)),
      child: Padding(
        padding: const EdgeInsets.only(top: 7),
        // minHeight, not a fixed height: the slot must still be reserved so
        // the form does not jump as messages come and go, but an 11px line at
        // text scale 1.3 measures ~18px and a `SizedBox(height: 15)` would
        // overflow it. Same fault as the fixed badge column in the targets
        // ladder (CLAUDE.md §10.4).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 15),
          child: Row(
            children: [
              if (show && tone != MlHintTone.neutral) ...[
                Icon(
                  tone == MlHintTone.good
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  text ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MlAuth.sans,
                    fontSize: 11,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

enum MlHintTone { neutral, good, bad, warn }

// ===========================================================================
// Identity
// ===========================================================================

class MlIdentityField extends StatefulWidget {
  const MlIdentityField({
    super.key,
    required this.controller,
    required this.onKindChanged,
    this.focusNode,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Fires whenever the field's read of its own contents changes, so the
  /// screen can enable or disable submit without duplicating the rules.
  final ValueChanged<MlIdentityKind> onKindChanged;

  final FocusNode? focusNode;
  final String? errorText;
  final VoidCallback? onSubmitted;

  /// The single authority on what counts as a usable identity. The screen and
  /// the WhatsApp path both ask this rather than re-implementing it.
  static MlIdentityKind read(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return MlIdentityKind.unknown;
    if (v.contains('@')) {
      final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(v);
      return ok ? MlIdentityKind.email : MlIdentityKind.unknown;
    }
    if (RegExp(r'[\d+]').hasMatch(v)) {
      final digits = v.replaceAll(RegExp(r'[^\d]'), '');
      // Local SA shapes: `082…`, `27…`, `+27…`.
      final saShaped = RegExp(r'^(\+?27|0)').hasMatch(v);
      // Any other country, but ONLY written in explicit E.164 (`+CC…`). The
      // drop accepted SA numbers alone; the form this replaces accepted any
      // 6+ digits of anything and handed it to `whatsappToE164`, so limiting
      // to SA would have removed a capability. Requiring the `+` keeps the
      // rule tight enough that the helper line still means something — a bare
      // run of digits is still refused rather than guessed at. 15 is the E.164
      // maximum.
      final international = v.startsWith('+');
      final ok = (saShaped && digits.length >= 9 && digits.length <= 12) ||
          (international && digits.length >= 9 && digits.length <= 15);
      return ok ? MlIdentityKind.phone : MlIdentityKind.unknown;
    }
    return MlIdentityKind.unknown;
  }

  @override
  State<MlIdentityField> createState() => _MlIdentityFieldState();
}

class _MlIdentityFieldState extends State<MlIdentityField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _touched = false;

  MlIdentityKind get _kind => MlIdentityField.read(widget.controller.text);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _focus.addListener(_onFocus);
  }

  /// Named so `dispose` can remove it. The screen owns both focus nodes and
  /// outlives this field — switching to the code view disposes the field while
  /// `_identityFocus` lives on, so an anonymous closure left attached would
  /// call `setState` on a defunct State the next time focus moved.
  void _onFocus() {
    if (!mounted) return;
    setState(() {
      if (!_focus.hasFocus) _touched = true;
    });
  }

  void _onChange() {
    widget.onKindChanged(_kind);
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.controller.text.trim();
    final kind = _kind;
    final looksEmail = raw.contains('@');
    final looksPhone = !looksEmail && RegExp(r'[\d+]').hasMatch(raw);

    // The field says what it understood, rather than waiting until submit to
    // disagree with you.
    String? hint;
    MlHintTone tone = MlHintTone.neutral;
    if (widget.errorText != null) {
      hint = widget.errorText;
      tone = MlHintTone.bad;
    } else if (kind == MlIdentityKind.email) {
      hint = 'Signing in with email';
      tone = MlHintTone.good;
    } else if (kind == MlIdentityKind.phone) {
      hint = 'Signing in with WhatsApp number';
      tone = MlHintTone.good;
    } else if (looksEmail && raw.length > 3) {
      hint = 'That email address looks incomplete';
      tone = _touched ? MlHintTone.bad : MlHintTone.neutral;
    } else if (looksPhone) {
      hint = 'Enter a full number, e.g. 082 123 4567';
      tone = MlHintTone.neutral;
    }

    final icon = looksEmail
        ? Icons.alternate_email_rounded
        : looksPhone
            ? Icons.chat_bubble_outline_rounded
            : Icons.person_outline_rounded;

    final showError =
        widget.errorText != null || (_touched && raw.isNotEmpty && kind == MlIdentityKind.unknown);
    // The same condition Material uses to float the label, computed here so the
    // label text and colour can follow it.
    final floated = _focus.hasFocus || raw.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldShell(
          focused: _focus.hasFocus,
          hasError: showError,
          isValid: kind != MlIdentityKind.unknown,
          leading: Icon(
            icon,
            size: 17,
            color: showError
                ? MlAuth.bad
                : _focus.hasFocus
                    ? MlAuth.accent2
                    : MlAuth.inkLo,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            style: const TextStyle(
              fontFamily: MlAuth.sans,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MlAuth.inkHi,
            ),
            cursorColor: MlAuth.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              // The reference uppercases the label only once it has floated
              // (`text-transform:uppercase` on the floated rule), which one
              // `labelText` string cannot express — so the text is chosen here
              // from the same condition Material floats on. Both inputs that
              // decide it already rebuild this: the focus listener and the
              // controller listener.
              label: Text(
                floated ? 'EMAIL OR WHATSAPP NUMBER' : 'Email or WhatsApp number',
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              // Top padding is what gives the floated label somewhere to land
              // inside the box. With the drop's symmetric 6 it had nowhere to
              // go but the border.
              contentPadding: EdgeInsets.only(top: 19, bottom: 5, right: 12),
              labelStyle: const TextStyle(
                fontFamily: MlAuth.sans,
                fontSize: 14,
                color: MlAuth.inkLo,
                fontWeight: FontWeight.w500,
              ),
              // 10px / 0.7 letter-spacing / w700 / inkMid, read off the
              // reference's computed style after letting its .17s transition
              // settle. inkMid, NOT cyan: the floated rule's colour outranks
              // `:focus-within`'s there, so the caption stays quiet and the
              // focus is carried by the ring and tint instead. Red on refusal.
              floatingLabelStyle: TextStyle(
                fontFamily: MlAuth.sans,
                fontSize: 10,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: showError ? MlAuth.bad : MlAuth.inkMid,
              ),
            ),
          ),
        ),
        MlFieldHint(text: hint, tone: tone),
      ],
    );
  }
}

// ===========================================================================
// Password
// ===========================================================================

class MlPasswordField extends StatefulWidget {
  const MlPasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? errorText;
  final VoidCallback? onSubmitted;

  @override
  State<MlPasswordField> createState() => _MlPasswordFieldState();
}

class _MlPasswordFieldState extends State<MlPasswordField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _shown = false;
  bool _caps = false;

  @override
  void initState() {
    super.initState();
    // Named, and removed in dispose — see the note on `_onFocus` above.
    _focus.addListener(_onFocus);
    widget.controller.addListener(_rebuild);
    // A global handler rather than a KeyboardListener: the latter only fires
    // while its own node is in the focus chain, and building a FocusNode
    // inside build() would leak one per rebuild.
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (!mounted) return;
    // The warning is only true while this field has focus, so drop it on blur.
    setState(() {
      if (!_focus.hasFocus) _caps = false;
    });
  }

  bool _onKey(KeyEvent e) {
    final on = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
    if (on != _caps && mounted) setState(() => _caps = on);
    return false; // never consumes the event
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.controller.removeListener(_rebuild);
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final floated = _focus.hasFocus || widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldShell(
            focused: _focus.hasFocus,
            hasError: hasError,
            isValid: false,
            leading: Icon(
              Icons.lock_outline_rounded,
              size: 17,
              color: hasError
                  ? MlAuth.bad
                  : _focus.hasFocus
                      ? MlAuth.accent2
                      : MlAuth.inkLo,
            ),
            trailing: IconButton(
              onPressed: () {
                setState(() => _shown = !_shown);
                _focus.requestFocus();
              },
              icon: Icon(
                _shown
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 17,
              ),
              color: MlAuth.inkLo,
              hoverColor: MlTokens.overlayLight.withValues(alpha: 0.06),
              splashRadius: 18,
              tooltip: _shown ? 'Hide password' : 'Show password',
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: !_shown,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => widget.onSubmitted?.call(),
              style: const TextStyle(
                fontFamily: MlAuth.sans,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MlAuth.inkHi,
              ),
              cursorColor: MlAuth.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                // Uppercase once floated, sentence case at rest — see the
                // identity field.
                label: Text(floated ? 'PASSWORD' : 'Password'),
                // See the identity field: the floated label needs room inside.
                contentPadding:
                    const EdgeInsets.only(top: 19, bottom: 5, right: 4),
                labelStyle: const TextStyle(
                  fontFamily: MlAuth.sans,
                  fontSize: 14,
                  color: MlAuth.inkLo,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelStyle: TextStyle(
                  fontFamily: MlAuth.sans,
                  fontSize: 10,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: hasError ? MlAuth.bad : MlAuth.inkMid,
                ),
              ),
            ),
          ),
        if (_caps && _focus.hasFocus)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              children: [
                const Icon(Icons.keyboard_capslock_rounded,
                    size: 12, color: MlAuth.warn),
                const SizedBox(width: 6),
                Text(
                  'Caps Lock is on',
                  style: TextStyle(
                    fontFamily: MlAuth.sans,
                    fontSize: 11,
                    color: MlAuth.warn,
                  ),
                ),
              ],
            ),
          ),
        MlFieldHint(
          text: widget.errorText,
          tone: MlHintTone.bad,
        ),
      ],
    );
  }
}

// ===========================================================================
// OTP
// ===========================================================================

class MlOtpRow extends StatefulWidget {
  const MlOtpRow({
    super.key,
    required this.length,
    required this.onChanged,
    required this.onCompleted,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  State<MlOtpRow> createState() => MlOtpRowState();
}

class MlOtpRowState extends State<MlOtpRow> {
  late final List<TextEditingController> _c =
      List.generate(widget.length, (_) => TextEditingController());
  late final List<FocusNode> _f =
      List.generate(widget.length, (_) => FocusNode());

  /// Held rather than built in `build()` — a FocusNode created per rebuild is
  /// a leak, and these only exist to catch backspace and the arrow keys.
  late final List<FocusNode> _kb = List.generate(
      widget.length,
      (_) => FocusNode(skipTraversal: true, canRequestFocus: false));

  String get value => _c.map((e) => e.text).join();

  /// Called by the screen after a refusal.
  void clear() {
    for (final c in _c) {
      c.clear();
    }
    setState(() {});
    widget.onChanged('');
    _f.first.requestFocus();
  }

  void focusFirst() => _f.first.requestFocus();

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    for (final f in _f) {
      f.dispose();
    }
    for (final f in _kb) {
      f.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final v = value;
    widget.onChanged(v);
    if (v.length == widget.length) widget.onCompleted(v);
  }

  /// A pasted code should fill the row, not land entirely in box one.
  void _spread(String text, int from) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (var i = 0; i < digits.length && from + i < widget.length; i++) {
      _c[from + i].text = digits[i];
    }
    final next = (from + digits.length).clamp(0, widget.length - 1);
    _f[next].requestFocus();
    setState(() {});
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        final filled = _c[i].text.isNotEmpty;
        final focused = _f[i].hasFocus;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : 9),
            child: AspectRatio(
              aspectRatio: 1 / 1.18,
              child: KeyboardListener(
                focusNode: _kb[i],
                onKeyEvent: (e) {
                  if (e is! KeyDownEvent) return;
                  if (e.logicalKey == LogicalKeyboardKey.backspace &&
                      _c[i].text.isEmpty &&
                      i > 0) {
                    _c[i - 1].clear();
                    _f[i - 1].requestFocus();
                    setState(() {});
                    _emit();
                  }
                  if (e.logicalKey == LogicalKeyboardKey.arrowLeft && i > 0) {
                    _f[i - 1].requestFocus();
                  }
                  if (e.logicalKey == LogicalKeyboardKey.arrowRight &&
                      i < widget.length - 1) {
                    _f[i + 1].requestFocus();
                  }
                },
                child: AnimatedContainer(
                  duration:
                      mlDuration(context, const Duration(milliseconds: 160)),
                  transform: Matrix4.translationValues(0, focused ? -2 : 0, 0),
                  decoration: BoxDecoration(
                    color: focused
                        ? MlAuth.accent.withValues(alpha: 0.06)
                        : filled
                            ? MlAuth.good.withValues(alpha: 0.06)
                            : MlTokens.overlayLight.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: focused
                          ? MlAuth.accent.withValues(alpha: 0.7)
                          : filled
                              ? MlAuth.good.withValues(alpha: 0.5)
                              : MlAuth.line2,
                    ),
                    boxShadow: focused
                        ? [
                            BoxShadow(
                              color: MlAuth.accent.withValues(alpha: 0.12),
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _c[i],
                    focusNode: _f[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    // NO `maxLength: 1`, deliberately. It appends a
                    // LengthLimitingTextInputFormatter, and formatters run
                    // BEFORE `onChanged` — so a pasted `123456` arrived here
                    // already truncated to `1`, `v.length > 1` was never true,
                    // and `_spread` could never fire. The drop advertised
                    // paste-across-six and silently kept only the first digit.
                    // One digit per box is enforced by `_spread` instead, which
                    // is where the behaviour actually belongs.
                    showCursor: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontFamily: MlAuth.mono,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: MlAuth.inkHi,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      if (v.length > 1) {
                        _spread(v, i);
                        return;
                      }
                      if (v.isNotEmpty && i < widget.length - 1) {
                        _f[i + 1].requestFocus();
                      }
                      setState(() {});
                      _emit();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

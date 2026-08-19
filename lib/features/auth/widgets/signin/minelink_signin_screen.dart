// ============================================================================
// MineLink — Sign-in screen
// ----------------------------------------------------------------------------
//   >= 1040px   brand panel 46% | form 54%
//   <  1040px   slim brand header, form full width
//
// The screen owns presentation only. Every credential leaves through a
// callback and the result comes back as a message — it holds no Supabase
// client, no session, and no opinion about what a valid account is.
//
// Callbacks return `Future<String?>`: null means signed in, a string is the
// refusal shown to the person. Passing the server's own wording through beats
// inventing a generic failure line — "Cycle Aug 2026 is locked until 01 Aug
// 2027" reads better than "Request failed".
// ============================================================================

import 'dart:async';

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/legal/legal_documents.dart';

import 'minelink_signin_theme.dart';
import 'minelink_signin_brand.dart';
import 'minelink_signin_fields.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class MineLinkSignInScreen extends StatefulWidget {
  const MineLinkSignInScreen({
    super.key,
    required this.onPasswordSignIn,
    this.onRequestWhatsAppCode,
    this.onVerifyWhatsAppCode,
    this.onForgotPassword,
    this.onSignedIn,
    this.resendSeconds = 30,
    this.showRemember = false,
  });

  /// `(identity, password, rememberMe)` → null on success, else the message.
  final Future<String?> Function(String identity, String password, bool remember)
      onPasswordSignIn;

  /// Null hides the WhatsApp path entirely.
  final Future<String?> Function(String identity)? onRequestWhatsAppCode;

  final Future<String?> Function(String identity, String code)?
      onVerifyWhatsAppCode;

  final VoidCallback? onForgotPassword;

  /// Fired after the success overlay has been seen. Navigate from here.
  final VoidCallback? onSignedIn;

  final int resendSeconds;

  /// Whether to show the "Keep me signed in" toggle.
  ///
  /// Off, because MineLink has nothing for it to control. Supabase persists the
  /// session in local storage unconditionally and neither `AuthService`,
  /// `AuthStateNotifier` nor `SessionManager` has any notion of a session that
  /// should not outlive the tab — so a person who UNCHECKED this box would stay
  /// signed in anyway. A control that reports a choice nobody can actually make
  /// is the same fault as a target dial defaulting to a number nobody set
  /// (CLAUDE.md, targets). `remember` is still handed to [onPasswordSignIn], so
  /// the day session lifetime becomes real this is one flag, not a rebuild.
  final bool showRemember;

  @override
  State<MineLinkSignInScreen> createState() => _MineLinkSignInScreenState();
}

enum _View { password, code }

class _MineLinkSignInScreenState extends State<MineLinkSignInScreen> {
  final _identity = TextEditingController();
  final _password = TextEditingController();
  final _identityFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _otpKey = GlobalKey<MlOtpRowState>();

  _View _view = _View.password;
  bool _remember = true;
  bool _busy = false;
  bool _done = false;

  String? _banner;
  MlBannerKind _bannerKind = MlBannerKind.error;
  String? _identityError;
  String? _passwordError;
  int _shake = 0;

  MlIdentityKind _kind = MlIdentityKind.unknown;

  /// "Play anyway" — a per-visit override of the platform's reduce-motion
  /// request. Never persisted and never written back to the system setting.
  bool _forceMotion = false;
  bool _noticeDismissed = false;

  String _code = '';
  int _resendLeft = 0;
  Timer? _resendTimer;

  bool get _canSubmit =>
      !_busy && _kind != MlIdentityKind.unknown && _password.text.length >= 6;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _identityFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identity.dispose();
    _password.dispose();
    _identityFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _fail(String message, {MlBannerKind kind = MlBannerKind.error}) {
    setState(() {
      _banner = message;
      _bannerKind = kind;
      if (kind == MlBannerKind.error) _shake++;
    });
  }

  void _clearErrors() => setState(() {
        _banner = null;
        _identityError = null;
        _passwordError = null;
      });

  // -- password path -------------------------------------------------------

  Future<void> _signIn() async {
    if (!_canSubmit) return;
    _clearErrors();
    setState(() => _busy = true);

    final message = await widget.onPasswordSignIn(
      _identity.text.trim(),
      _password.text,
      _remember,
    );

    if (!mounted) return;
    if (message == null) {
      setState(() {
        _busy = false;
        _done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) widget.onSignedIn?.call();
      return;
    }

    setState(() => _busy = false);

    // The banner carries the real reason and is the ONLY thing that speaks
    // here. This used to also mark the password field red with "Check your
    // password and try again" — on every failure, whatever it was.
    //
    // Caught by signing in while the auth service was unreachable: the banner
    // read *"Signing in is taking longer than expected … your password has NOT
    // been rejected"* while the field directly beneath it was outlined red and
    // said the opposite, and the red field is the more actionable-looking of
    // the two. That sends somebody off resetting a password that works, in the
    // exact situation — no signal — where they can least afford the detour.
    //
    // It was a guess even in the case it was written for: a rejected
    // credential is just as likely to be the email, which is why the server's
    // own wording is "Check your email and password".
    //
    // Focus returns to the password because that is the field you would retry
    // from. The text is NOT selected: on a genuine mistype select-all saves a
    // moment, and on a network failure it leaves a correct password one
    // keystroke from being destroyed.
    _fail(message);
    _passwordFocus.requestFocus();
  }

  // -- WhatsApp path -------------------------------------------------------

  Future<void> _requestCode() async {
    final kind = MlIdentityField.read(_identity.text);
    // Must be a phone, not merely "not unknown" — the drop refused only
    // `unknown`, which let a perfectly valid EMAIL address be sent to the
    // WhatsApp code endpoint. There is nowhere to deliver a code to an inbox
    // on this path, and Supabase would refuse it with wording written for a
    // developer.
    if (kind != MlIdentityKind.phone) {
      setState(() => _identityError =
          'Enter your WhatsApp number first so we know where to send the code');
      _identityFocus.requestFocus();
      _shake++;
      return;
    }
    _clearErrors();
    setState(() => _busy = true);

    final message =
        await widget.onRequestWhatsAppCode!(_identity.text.trim());

    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      _fail(message);
      return;
    }
    setState(() {
      _view = _View.code;
      _code = '';
    });
    _startResend();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpKey.currentState?.focusFirst();
    });
  }

  /// A real cancellable timer rather than a loop of awaited delays. The loop in
  /// the drop left a 1-second delay in flight after the screen was gone — the
  /// `mounted` check ends the loop on the next tick but cannot un-schedule the
  /// tick itself, which the test binding rightly calls a pending timer. Same
  /// shape as the cooldown in `whatsapp_otp_screen.dart`.
  void _startResend() {
    _resendTimer?.cancel();
    setState(() => _resendLeft = widget.resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendLeft--;
        if (_resendLeft <= 0) {
          _resendLeft = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6 || _busy) return;
    _clearErrors();
    setState(() => _busy = true);

    final message =
        await widget.onVerifyWhatsAppCode!(_identity.text.trim(), _code);

    if (!mounted) return;
    if (message == null) {
      setState(() {
        _busy = false;
        _done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) widget.onSignedIn?.call();
      return;
    }
    setState(() => _busy = false);
    _fail(message);
    _otpKey.currentState?.clear();
  }

  void _backToPassword() {
    _clearErrors();
    _resendTimer?.cancel();
    setState(() {
      _view = _View.password;
      _code = '';
      _resendLeft = 0;
    });
  }

  // -- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= MlAuth.splitBreakpoint;

    // This screen draws its own field chrome (`_FieldShell`), so it has to opt
    // OUT of the ambient InputDecorationTheme — otherwise every TextField here
    // renders a second set of it inside the first.
    //
    // `InputDecoration.border` alone is not enough and that is the trap: it is
    // only the fallback, so the app theme's `enabledBorder` / `focusedBorder`
    // still win. MineLink's dark theme sets `filled: true`, a sunken fill and a
    // 2px cyan focused outline, which showed up as a filled rounded rect and a
    // second cyan border nested inside the shell, with the floating label
    // notching it. Every state is cleared here, once, rather than six overrides
    // on each of the three fields — and this way the OTP boxes are covered too.
    final bare = Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
    );

    // The notice is offered on the platform's request, not on the effective
    // state — once "Play anyway" is pressed, motion is on and there is nothing
    // left to explain, so it goes away on its own.
    final offerMotion = mlReduceMotionRequested(context) &&
        !_forceMotion &&
        !_noticeDismissed;

    return Theme(
      data: bare,
      child: MlMotionScope(
        forceMotion: _forceMotion,
        // Builder so everything below is built against a context that can see
        // the scope — without it `mlMotionEnabled` would read the ambient
        // MediaQuery only and the override would do nothing.
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: MlAuth.bg,
            body: Stack(
              children: [
                Positioned.fill(
                  child: wide
                      ? Row(
                          children: [
                            const Expanded(flex: 46, child: MlBrandPanel()),
                            Expanded(flex: 54, child: _authSide(context)),
                          ],
                        )
                      : Column(
                          children: [
                            _compactHeader(),
                            Expanded(child: _authSide(context)),
                          ],
                        ),
                ),
                if (offerMotion)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: MlMotionNotice(
                      onPlayAnyway: () => setState(() => _forceMotion = true),
                      onDismiss: () =>
                          setState(() => _noticeDismissed = true),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactHeader() => Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MlAuth.backdropTop, MlAuth.backdropMid],
          ),
          border: Border(bottom: BorderSide(color: MlAuth.line2)),
        ),
        child: Row(
          children: [
            Image.asset(MlAuth.iconAsset,
                height: 34,
                errorBuilder: (_, __, ___) => const SizedBox(width: 34)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('MineLink Technologies',
                      style: TextStyle(
                        fontFamily: MlAuth.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MlAuth.inkHi,
                      )),
                  SizedBox(height: 2),
                  Text('Mineral logistics, connected',
                      style: TextStyle(
                        fontFamily: MlAuth.sans,
                        fontSize: 11,
                        color: MlAuth.inkMid,
                      )),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _authSide(BuildContext context) {
    return Stack(
      children: [
        // Glow behind the card, so the form side is not the only still thing.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.16),
                  radius: 0.85,
                  colors: [
                    MlAuth.accent.withValues(alpha: 0.09),
                    MlAuth.accent.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.68],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: MlAuth.cardMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MlShake(
                    trigger: _shake,
                    child: Stack(
                      children: [
                        _card(context),
                        if (_done)
                          Positioned.fill(child: _successOverlay(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _legal(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context) => Container(
        // The reference tightens the card below 520px
        // (`@media (max-width:520px){.cardInner{padding:28px 22px 26px}}`); the
        // drop kept 38px throughout, which is most of why a 380px phone was so
        // cramped that the footnote overran its row.
        padding: MediaQuery.sizeOf(context).width < 520
            ? const EdgeInsets.fromLTRB(22, 28, 22, 26)
            : const EdgeInsets.fromLTRB(38, 38, 38, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MlAuth.cardTop,
              MlAuth.cardBottom,
            ],
          ),
          borderRadius: BorderRadius.circular(MlAuth.cardRadius),
          border: Border.all(color: MlAuth.line2),
          boxShadow: [
            BoxShadow(
              color: MlTokens.overlayDark.withValues(alpha: 0.55),
              blurRadius: 90,
              offset: const Offset(0, 40),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: mlDuration(context, const Duration(milliseconds: 260)),
          curve: Curves.easeOutCubic,
          child: _view == _View.password
              ? _passwordView(context)
              : _codeView(context),
        ),
      );

  // -- views ---------------------------------------------------------------

  Widget _cardMark() => Container(
        width: 66,
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MlAuth.gold.withValues(alpha: 0.10),
              MlTokens.overlayLight.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MlAuth.line2),
        ),
        child: Image.asset(MlAuth.iconAsset,
            width: 38,
            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      );

  Widget _title(String plain, String accent) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: plain),
            TextSpan(
              text: accent,
              style: const TextStyle(
                fontFamily: MlAuth.serif,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: MlAuth.gold2,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: MlAuth.sans,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.75,
          color: MlAuth.inkHi,
        ),
      );

  Widget _subtitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 26),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: MlAuth.sans,
            fontSize: 12.5,
            height: 1.6,
            color: MlAuth.inkMid,
          ),
        ),
      );

  Widget _passwordView(BuildContext context) => Column(
        key: const ValueKey('pw'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _cardMark()),
          const SizedBox(height: 20),
          _title('Welcome ', 'back'),
          _subtitle('Sign in to manage your company, employees, fleet '
              'and operations.'),
          if (_banner != null) MlBanner(message: _banner!, kind: _bannerKind),
          MlIdentityField(
            controller: _identity,
            focusNode: _identityFocus,
            errorText: _identityError,
            onKindChanged: (k) => setState(() => _kind = k),
            onSubmitted: () => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 14),
          MlPasswordField(
            controller: _password,
            focusNode: _passwordFocus,
            errorText: _passwordError,
            onSubmitted: _signIn,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: widget.showRemember
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            children: [
              // Flexible: both labels are long enough to overrun a 376px card
              // interior at text scale 1.3, and a non-flex child in a Row gets
              // unbounded width, so its ellipsis would never engage.
              if (widget.showRemember) Flexible(child: _rememberToggle()),
              if (widget.onForgotPassword != null)
                Flexible(
                    child: _textLink(
                        'Forgot password?', widget.onForgotPassword!)),
            ],
          ),
          const SizedBox(height: 22),
          MlPrimaryButton(
            label: 'Sign in',
            busyLabel: 'Signing in…',
            busy: _busy,
            onPressed: _canSubmit ? _signIn : null,
          ),
          if (widget.onRequestWhatsAppCode != null) ...[
            _divider(),
            MlGhostButton(
              label: 'Sign in with WhatsApp code',
              icon: const Icon(Icons.chat_bubble_rounded,
                  size: 17, color: MlAuth.whatsapp),
              onPressed: _busy ? null : _requestCode,
            ),
          ],
          _footNote('Encrypted in transit and at rest'),
        ],
      );

  Widget _codeView(BuildContext context) => Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _cardMark()),
          const SizedBox(height: 20),
          _title('Enter your ', 'code'),
          _subtitle('We sent a 6-digit code on WhatsApp to '
              '${_maskedIdentity()}'),
          if (_banner != null) MlBanner(message: _banner!, kind: _bannerKind),
          MlOtpRow(
            key: _otpKey,
            length: 6,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (_) => _verify(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible for the same reason as the password view's row: two
              // long labels in a Row at text scale 1.3.
              Flexible(
                child: TextButton.icon(
                onPressed: _busy ? null : _backToPassword,
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('Use password instead',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                style: TextButton.styleFrom(
                  foregroundColor: MlAuth.inkMid,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontFamily: MlAuth.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: _resendLeft > 0 || _busy ? null : _requestCode,
                  style: TextButton.styleFrom(
                    foregroundColor: MlAuth.accent2,
                    disabledForegroundColor: MlAuth.inkXlo,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontFamily: MlAuth.sans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    _resendLeft > 0
                        ? 'Resend in ${_resendLeft}s'
                        : 'Resend code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          MlPrimaryButton(
            label: 'Verify & sign in',
            busyLabel: 'Verifying…',
            busy: _busy,
            onPressed: _code.length == 6 ? _verify : null,
          ),
          _footNote('Codes expire after 5 minutes'),
        ],
      );

  String _maskedIdentity() {
    final v = _identity.text.trim();
    if (MlIdentityField.read(v) == MlIdentityKind.email) return v;
    final d = v.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length < 4) return '•••• ••• ••••';
    return '•••• ••• ${d.substring(d.length - 4)}';
  }

  // -- small parts ---------------------------------------------------------

  Widget _rememberToggle() => InkWell(
        onTap: () => setState(() => _remember = !_remember),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration:
                    mlDuration(context, const Duration(milliseconds: 160)),
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _remember
                      ? const LinearGradient(
                          colors: [MlAuth.accent2, MlAuth.accent])
                      : null,
                  color: _remember
                      ? null
                      : MlTokens.overlayLight.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _remember ? Colors.transparent : MlAuth.lineStrong,
                  ),
                ),
                child: _remember
                    ? const Icon(Icons.check_rounded,
                        size: 11, color: MlAuth.onAccent)
                    : null,
              ),
              const SizedBox(width: 9),
              const Flexible(
                child: Text(
                  'Keep me signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MlAuth.sans,
                    fontSize: 12.5,
                    color: MlAuth.inkMid,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _textLink(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: MlAuth.accent2,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: MlAuth.sans,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _divider() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 18),
        child: Row(
          children: [
            const Expanded(child: Divider(color: MlAuth.line2, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR',
                style: TextStyle(
                  fontFamily: MlAuth.sans,
                  fontSize: 10.5,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: MlAuth.inkXlo,
                ),
              ),
            ),
            const Expanded(child: Divider(color: MlAuth.line2, height: 1)),
          ],
        ),
      );

  Widget _footNote(String text) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            const Divider(color: MlAuth.line, height: 1),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 13, color: MlAuth.good),
                const SizedBox(width: 8),
                // Flexible, and allowed to wrap. The old wording overran this
                // Row by 30px at 380px wide even at text scale 1.0 — the card
                // keeps its 38px side padding on a phone, leaving ~240px of
                // interior. A reassurance line is the wrong thing to
                // ellipsize, so it takes a second line.
                //
                // 2026-08-16: the wording itself was the bigger problem. It
                // read "Protected by end-to-end encrypted sessions", and this
                // product is not end-to-end encrypted — Supabase terminates
                // TLS and can read every row, which is precisely what makes
                // the RLS work in this repo meaningful. A false security
                // claim on a sign-in screen is the same category of problem
                // as the placeholder legal text S10-9 guards against, and it
                // is one a customer could reasonably rely on.
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: MlAuth.sans,
                      fontSize: 11,
                      color: MlAuth.inkLo,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// "By signing in you agree to the Terms of Use and Privacy Policy."
  ///
  /// Both names are links now. They were plain text until 2026-08-17, and the
  /// documents were not bundled at all, so this sentence asserted agreement to
  /// two things nobody could open — a missing document turned into a false
  /// representation, which is exactly what the `unreplaced-legal-placeholder`
  /// guard's rationale warns about. Jean's ruling: point them at the drafts,
  /// which say plainly on their own first line that they are drafts.
  Widget _legal(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'By signing in you agree to the '),
            _legalLink(context, 'Terms of Use', LegalDocument.terms),
            const TextSpan(text: ' and '),
            _legalLink(context, 'Privacy Policy', LegalDocument.privacy),
            const TextSpan(
                text: '.\nTrouble signing in? Contact your administrator.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: MlAuth.sans,
          fontSize: 11,
          height: 1.7,
          color: MlAuth.inkXlo,
        ),
      );

  /// One tappable document name. Underlined and in the accent colour, because
  /// at 11 px on a dark panel an unstyled tap target is not one.
  TextSpan _legalLink(BuildContext context, String label, LegalDocument doc) =>
      TextSpan(
        text: label,
        style: const TextStyle(
          color: MlAuth.accent,
          decoration: TextDecoration.underline,
          decorationColor: MlAuth.accent,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => showLegalDocument(context, doc),
      );

  Widget _successOverlay(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(MlAuth.cardRadius),
        child: Container(
          color: MlAuth.sheetBase,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration:
                    mlDuration(context, const Duration(milliseconds: 500)),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Transform.scale(
                  scale: 0.85 + 0.15 * v,
                  child: Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MlAuth.good.withValues(alpha: 0.12),
                      border: Border.all(
                        color: MlAuth.good.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Opacity(
                      opacity: v,
                      child: const Icon(Icons.check_rounded,
                          size: 32, color: MlAuth.good),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Signed in',
                style: TextStyle(
                  fontFamily: MlAuth.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MlAuth.inkHi,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Taking you to your console…',
                style: TextStyle(
                  fontFamily: MlAuth.sans,
                  fontSize: 12,
                  color: MlAuth.inkMid,
                ),
              ),
            ],
          ),
        ),
      );
}

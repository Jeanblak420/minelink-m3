import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// One-time-code entry for WhatsApp OTP login / re-verification.
///
/// [whatsappNumber] is the number to verify. When null (the re-verification
/// case, where a session already exists) it falls back to the signed-in user's
/// phone and auto-sends a fresh code on open.
class WhatsAppOtpScreen extends ConsumerStatefulWidget {
  final String? whatsappNumber;
  const WhatsAppOtpScreen({super.key, this.whatsappNumber});

  @override
  ConsumerState<WhatsAppOtpScreen> createState() => _WhatsAppOtpScreenState();
}

class _WhatsAppOtpScreenState extends ConsumerState<WhatsAppOtpScreen> {
  final _codeController = TextEditingController();
  late final String _number;

  // Resend cooldown state.
  static const _kCooldownSeconds = 45;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _number = widget.whatsappNumber ??
        SupabaseConfig.client.auth.currentUser?.phone ??
        '';
    if (widget.whatsappNumber == null && _number.isNotEmpty) {
      // Re-verification: send a fresh code automatically.
      Future.microtask(_resend);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _kCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resend() async {
    _startCooldown();
    try {
      await ref.read(authStateProvider.notifier).sendWhatsappOtp(_number);
    } catch (_) {
      // Error is surfaced via auth state.
    }
  }

  Future<void> _verify() async {
    final ok = await ref.read(authStateProvider.notifier).verifyWhatsappOtp(
          whatsappNumber: _number,
          token: _codeController.text,
        );
    if (ok && mounted) {
      context.go('/home');
    }
  }

  Future<void> _usePasswordInstead() async {
    if (SupabaseConfig.client.auth.currentUser != null) {
      await ref.read(authStateProvider.notifier).signOut();
    }
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final semantic = MlSemantic.of(context);
    final errTone = MlTone.error.colors(Theme.of(context).brightness);
    final resendEnabled = !state.isLoading && _resendCooldown == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp verification')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: MlIconWell(
                    icon: Icons.sms_outlined,
                    tone: MlTone.done,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the code we sent on WhatsApp',
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: MlTokens.fsH3,
                    fontWeight: FontWeight.w800,
                    color: semantic.textStrong,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_number.isNotEmpty)
                  Text('to $_number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        color: semantic.textMuted,
                      )),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontFamily: MlTokens.fontMono,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    labelText: ' 6-digit code ',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
                if (state.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: errTone.bg,
                      borderRadius: BorderRadius.circular(MlTokens.rMd),
                      border: Border.all(
                        color: errTone.fg.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(state.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 13,
                          color: errTone.fg,
                        )),
                  ),
                MlButton.primary(
                  label: state.isLoading ? 'Verifying…' : 'Verify & continue',
                  expand: true,
                  onPressed: state.isLoading ? null : _verify,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: resendEnabled ? _resend : null,
                  child: Text(_resendCooldown > 0
                      ? 'Resend code (${_resendCooldown}s)'
                      : 'Resend code'),
                ),
                TextButton(
                  onPressed: state.isLoading ? null : _usePasswordInstead,
                  child: const Text('Use password instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

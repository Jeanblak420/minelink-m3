import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/profile/services/signature_service.dart';
import 'package:flutter_application_1/features/profile/widgets/signature_pad.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Profile section letting the current user draw and save their signature. The
/// saved transparent PNG is reused wherever a signature is required — waybills,
/// PODs, approvals (CLAUDE.md §4). Applies to every user and org type.
class ProfileSignatureCard extends ConsumerWidget {
  const ProfileSignatureCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(mySignatureUrlProvider);
    final hasSignature = async.valueOrNull != null;

    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlSectionTitle('Signature',
              icon: Icons.draw_rounded,
              // Not a count. Whether a signature exists is the fact this
              // card turns on, and S8-10 records that only 3 of 116
              // profiles have one — so "Not set" is the state most users
              // are in and the one worth surfacing in the header.
              meta: async.isLoading ? null : (hasSignature ? 'Saved' : 'Not set'),
              margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          Text(
            'Draw your signature once. It is applied automatically wherever a '
            'signature is needed — waybills, proof-of-delivery, and approvals.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _SignaturePreviewFrame(
              child: Center(
                child: Text('Could not load signature. ${friendlyError(e)}',
                    style: TextStyle(color: semantic.textFaint)),
              ),
            ),
            data: (url) => _SignaturePreviewFrame(
              child: url == null
                  ? Center(
                      child: Text(
                        'No signature yet.',
                        style: TextStyle(
                            color: semantic.textFaint,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text('Signature unavailable',
                              style: TextStyle(color: semantic.textFaint)),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: MlButton.primary(
              label: hasSignature ? 'Update signature' : 'Add signature',
              icon: Icons.gesture_rounded,
              onPressed: () => _openCapture(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCapture(BuildContext context, WidgetRef ref) async {
    final saved = await showSignatureCaptureDialog(context);
    if (saved == true && context.mounted) {
      ref.invalidateIfMounted(mySignatureUrlProvider);
      // The signature is an account-setup checklist item — refresh it too.
      ref.invalidateIfMounted(myProfileSetupProvider);
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Signature saved')));
    }
  }
}

/// A signature-height frame on a light "paper" surface so a transparent-PNG
/// signature reads clearly regardless of theme brightness.
class _SignaturePreviewFrame extends StatelessWidget {
  const _SignaturePreviewFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      height: 96,
      width: double.infinity,
      decoration: BoxDecoration(
        color: MlTokens.waybillPaper,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: semantic.borderCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Opens the draw-your-signature dialog. Resolves to `true` when a new
/// signature was captured and saved.
Future<bool?> showSignatureCaptureDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SignatureCaptureDialog(),
  );
}

class _SignatureCaptureDialog extends ConsumerStatefulWidget {
  const _SignatureCaptureDialog();

  @override
  ConsumerState<_SignatureCaptureDialog> createState() =>
      _SignatureCaptureDialogState();
}

class _SignatureCaptureDialogState
    extends ConsumerState<_SignatureCaptureDialog> {
  final _controller = SignaturePadController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_controller.hasContent) {
      setState(() => _error = 'Please draw your signature first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = await _controller.exportPng();
      if (bytes == null) {
        throw StateError('Nothing to save.');
      }
      await ref.read(signatureServiceProvider).saveMySignature(bytes);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save signature. ${friendlyError(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return AlertDialog(
      title: const Text('Add your signature'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign inside the box below using your mouse or finger.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: semantic.textMuted),
            ),
            const SizedBox(height: 12),
            SignaturePad(controller: _controller),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        _controller.clear();
                        setState(() => _error = null);
                      },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(
                  color: MlTone.error.colors(Theme.of(context).brightness).fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save signature'),
        ),
      ],
    );
  }
}

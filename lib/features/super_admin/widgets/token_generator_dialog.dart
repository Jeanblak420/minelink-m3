import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/utils/edge_function_errors.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class TokenGeneratorDialog extends ConsumerStatefulWidget {
  final String organizationId;
  final String organizationName;
  final int currentSeatLimit;

  const TokenGeneratorDialog({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.currentSeatLimit,
  });

  @override
  ConsumerState<TokenGeneratorDialog> createState() => _TokenGeneratorDialogState();
}

class _TokenGeneratorDialogState extends ConsumerState<TokenGeneratorDialog> {
  final _validDaysController = TextEditingController(text: '365');
  final _seatLimitController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seatLimitController.text = '${widget.currentSeatLimit > 0 ? widget.currentSeatLimit : 10}';
  }

  @override
  void dispose() {
    _validDaysController.dispose();
    _seatLimitController.dispose();
    super.dispose();
  }

  // Whether we are in the pre-confirm review step (before actual generation)
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    if (_generatedToken != null) {
      return _tokenResultDialog(context);
    }
    if (_confirming) {
      return _confirmationDialog(context);
    }

    return AlertDialog(
      // Measured 2026-08-18: none of this dialog's three states scrolled, so at
      // a large text size on a 320px phone the content overflowed the viewport
      // by 133px — clipped, with the fields and buttons below the fold simply
      // unreachable. `scrollable` is Material's own answer; the adaptive
      // padding gives back the ~64px Material spends on chrome, which on a
      // 320px phone is a fifth of the screen.
      scrollable: true,
      insetPadding: DialogUtils.adaptiveInsetPadding(context),
      contentPadding: DialogUtils.adaptiveContentPadding(context),
      title: const Text('Generate Serial Token'),
      content: SizedBox(
        width: DialogUtils.contentMaxWidth(context, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organization: ${widget.organizationName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: _validDaysController,
              decoration: const InputDecoration(
                labelText: 'Valid Days',
                hintText: 'e.g. 365',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _seatLimitController,
              decoration: const InputDecoration(
                labelText: 'Seat Limit',
                hintText: 'e.g. 10',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_seat),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _reviewValues,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Review'),
        ),
      ],
    );
  }

  /// Step 2: Confirmation/Review dialog — Cancel | Edit | Confirm
  Widget _confirmationDialog(BuildContext context) {
    final days = _validDaysController.text;
    final seats = _seatLimitController.text;
    return AlertDialog(
      // Measured 2026-08-18: none of this dialog's three states scrolled, so at
      // a large text size on a 320px phone the content overflowed the viewport
      // by 133px — clipped, with the fields and buttons below the fold simply
      // unreachable. `scrollable` is Material's own answer; the adaptive
      // padding gives back the ~64px Material spends on chrome, which on a
      // 320px phone is a fifth of the screen.
      scrollable: true,
      insetPadding: DialogUtils.adaptiveInsetPadding(context),
      contentPadding: DialogUtils.adaptiveContentPadding(context),
      title: const Row(children: [Icon(Icons.info_outline_rounded, color: MlTokens.blue600), SizedBox(width: 8), Text('Review & Confirm')]),
      content: SizedBox(
        width: DialogUtils.contentMaxWidth(context, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to generate a serial token for:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            _ReviewRow(label: 'Organization', value: widget.organizationName),
            _ReviewRow(label: 'Valid Days', value: '$days days'),
            _ReviewRow(label: 'Seat Limit', value: '$seats seats'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MlTokens.orange500.withValues(alpha: 0.08),
                borderRadius: MlShape.radiusSmall,
                border: Border.all(color: MlTokens.orange500.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: MlTokens.orange500, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Any existing active token will remain until explicitly revoked.', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        OutlinedButton.icon(
          onPressed: () => setState(() => _confirming = false),
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('Edit'),
        ),
        FilledButton.icon(
          onPressed: _isGenerating ? null : _generateToken,
          icon: _isGenerating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.vpn_key),
          label: Text(_isGenerating ? 'Generating...' : 'Confirm'),
        ),
      ],
    );
  }

  void _reviewValues() {
    final validDays = int.tryParse(_validDaysController.text);
    final seatLimit = int.tryParse(_seatLimitController.text);
    if (validDays == null || validDays <= 0) {
      setState(() => _error = 'Please enter a valid number of days');
      return;
    }
    if (seatLimit == null || seatLimit <= 0) {
      setState(() => _error = 'Please enter a valid seat limit');
      return;
    }
    setState(() {
      _error = null;
      _confirming = true;
    });
  }

  Widget _tokenResultDialog(BuildContext context) {
    return AlertDialog(
      // Measured 2026-08-18: none of this dialog's three states scrolled, so at
      // a large text size on a 320px phone the content overflowed the viewport
      // by 133px — clipped, with the fields and buttons below the fold simply
      // unreachable. `scrollable` is Material's own answer; the adaptive
      // padding gives back the ~64px Material spends on chrome, which on a
      // 320px phone is a fifth of the screen.
      scrollable: true,
      insetPadding: DialogUtils.adaptiveInsetPadding(context),
      contentPadding: DialogUtils.adaptiveContentPadding(context),
      title: const Row(children: [Icon(Icons.check_circle, color: MlTokens.green600), SizedBox(width: 8), Text('Token Generated')]),
      content: SizedBox(
        width: DialogUtils.contentMaxWidth(context, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ This token will only be shown once!', style: TextStyle(fontWeight: FontWeight.bold, color: MlTokens.orange500)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: MlShape.radiusSmall,
              ),
              child: SelectableText(_generatedToken!,
                  style: context.mlText.code(size: 16)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedToken!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied to clipboard')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Token'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            ref.invalidate(organizationTokensProvider(widget.organizationId));
            ref.invalidate(organizationDetailProvider(widget.organizationId));
            ref.invalidate(dashboardStatsProvider);
            Navigator.pop(context);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _generateToken() async {
    final validDays = int.tryParse(_validDaysController.text);
    final seatLimit = int.tryParse(_seatLimitController.text);
    // Values already validated by _reviewValues, but guard anyway
    if (validDays == null || seatLimit == null) return;

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final result = await ref.read(superAdminRepositoryProvider).generateSerialToken(
        organizationId: widget.organizationId,
        validDays: validDays,
        seatLimit: seatLimit,
      );
      if (mounted) {
        setState(() {
          _generatedToken = result['raw_token'] as String?;
          _isGenerating = false;
          _confirming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = supabaseErrorMessage(e);
          _isGenerating = false;
          _confirming = false; // go back to form to show error
        });
      }
    }
  }
}

/// Simple label-value row for review dialog
class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}


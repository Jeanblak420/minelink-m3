import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/components/ml_meta.dart';

/// Units available when capturing a stockpile mineral. Only "Ton" for now;
/// more will be added later.
const stockpileUnits = ['Ton'];

/// A single stockpile card: tonnage + per-pile actions. Shared by the
/// stockpile detail screen and the supervisor view.
class StockpileCard extends StatelessWidget {
  final StockpileEntry pile;
  final VoidCallback onAddTons;
  final VoidCallback onUploadResults;
  final VoidCallback onUploadPicture;

  /// When true (e.g. opened from a notification), the card is briefly ringed to
  /// draw the supervisor's eye to the stockpile the alert was about.
  final bool highlight;

  const StockpileCard({
    super.key,
    required this.pile,
    required this.onAddTons,
    required this.onUploadResults,
    required this.onUploadPicture,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final card = _buildTile(context, scheme, textTheme);
    if (!highlight) return card;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: MlShape.radiusLargeIncreased,
        border: Border.all(color: PortalColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: PortalColors.accent.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: card,
    );
  }

  Widget _buildTile(
      BuildContext context, ColorScheme scheme, TextTheme textTheme) {
    return OverviewHeroTile(
      title: pile.name,
      icon: Icons.layers_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pile.buyer != null)
            Text(
              'Allocated to ${pile.buyer}',
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 4),
          AnimatedTons(
            value: pile.tons,
            // ` t` in both branches. A capped pile read "45 / 120 t" and an
            // uncapped one beside it read "60 tons" — the same quantity, the
            // same screen, the same row of cards, two units. Photographed on
            // the mine's Supervisor screen against live data, 2026-08-21.
            //
            // `t` is what the rest of the product prints beside a figure —
            // every stat card, every recon total, the waybill. "tons" is the
            // word, and it belongs in prose, which is where "Add tons" below
            // keeps it.
            suffix: pile.maxCapTons != null
                ? ' / ${pile.maxCapTons!.toStringAsFixed(0)} t'
                : ' t',
            style: MlType.figure(
                color: scheme.onSurface, size: MlTokens.fsH1),
          ),
          if (pile.mineral != null) ...[
            const SizedBox(height: 4),
            Text(
              '${pile.mineral}${pile.grade != null ? ' · ${pile.grade}' : ''}',
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (pile.maxCapTons != null) ...[
            const SizedBox(height: 10),
            _StockpileFillBar(pile: pile),
          ],
          const SizedBox(height: 16),
          StockpileActionButton(
              icon: Icons.add_rounded,
              label: (pile.remainingToCap ?? 1) <= 0
                  ? 'Order cap reached'
                  : 'Add tons',
              onTap: (pile.remainingToCap ?? 1) <= 0 ? null : onAddTons),
          const SizedBox(height: 8),
          StockpileActionButton(
              icon: Icons.upload_file_outlined,
              label: 'Upload results',
              onTap: onUploadResults),
          const SizedBox(height: 8),
          StockpileActionButton(
              icon: Icons.add_a_photo_outlined,
              label: 'Upload picture',
              onTap: onUploadPicture),
        ],
      ),
    );
  }
}

/// Fill progress for an order-linked stockpile: a bar of balance vs the order
/// cap plus a "N full load(s) ready" line so the mine, buyer and transporter
/// all read the same collect-readiness at a glance.
class _StockpileFillBar extends StatelessWidget {
  final StockpileEntry pile;
  const _StockpileFillBar({required this.pile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cap = pile.maxCapTons ?? 0;
    final frac = cap <= 0 ? 0.0 : (pile.tons / cap).clamp(0.0, 1.0);
    final loads = pile.loadsReady;
    final full = pile.remainingToCap != null && pile.remainingToCap! <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: MlShape.radiusSmall,
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: MlSemantic.of(context).borderCard,
            valueColor: AlwaysStoppedAnimation(
                full ? MlTokens.green600 : PortalColors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          full
              ? 'Order complete · ${cap.toStringAsFixed(0)} t · '
                  '${mlCount(loads, 'load')} ready'
              : '${(frac * 100).round()}% of order · '
                  '${(pile.remainingToCap ?? 0).toStringAsFixed(0)} t to go · '
                  '${mlCount(loads, 'load')} ready',
          style: textTheme.bodySmall?.copyWith(
            color: full ? MlTokens.green600 : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class StockpileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const StockpileActionButton(
      {super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: MlSemantic.of(context).surfaceCard,
          foregroundColor: MlTokens.accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: MlSemantic.of(context).borderCard),
        ),
        icon: Icon(icon, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// "Add Tons" form: captures the tonnage to add to an existing stockpile.
/// Returns the tonnage (> 0) to add, or null if cancelled.
Future<double?> showAddTonsDialog(BuildContext context, StockpileEntry pile) {
  return showDialog<double>(
    context: context,
    builder: (_) => _AddTonsDialog(pile: pile),
  );
}

class _AddTonsDialog extends StatefulWidget {
  final StockpileEntry pile;
  const _AddTonsDialog({required this.pile});

  @override
  State<_AddTonsDialog> createState() => _AddTonsDialogState();
}

class _AddTonsDialogState extends State<_AddTonsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tons = TextEditingController();

  @override
  void dispose() {
    _tons.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
      title: Text('Add tons · ${widget.pile.name}'),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pile.maxCapTons != null
                    ? 'Current balance: ${widget.pile.tons.toStringAsFixed(2)} t '
                        'of ${widget.pile.maxCapTons!.toStringAsFixed(0)} t ordered. '
                        'You can add up to ${(widget.pile.remainingToCap ?? 0).toStringAsFixed(2)} t more.'
                    : 'Current balance: ${widget.pile.tons.toStringAsFixed(2)} t. '
                        'Enter the tonnage you have physically added.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tons,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tons to add',
                  border: OutlineInputBorder(),
                  suffixText: 't',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a valid tonnage';
                  final remaining = widget.pile.remainingToCap;
                  if (remaining != null && n > remaining) {
                    return 'Only ${remaining.toStringAsFixed(2)} t left before the order cap';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(double.parse(_tons.text.trim()));
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: MlTokens.accent,
            foregroundColor: MlTokens.navy950,
          ),
          child: const Text('Add tons'),
        ),
      ],
    );
  }
}

/// "Add Stockpile" form: captures a new stockpile (name, buyer, tonnage +
/// mineral details). Returns the new [StockpileEntry] when saved.
///
/// [buyerOptions] are the mine's real partner-buyer names. When empty (no
/// buyers connected yet) the buyer is entered as free text so the supervisor
/// is never blocked by an empty dropdown.
Future<StockpileEntry?> showAddStockpileDialog(
  BuildContext context, {
  List<String> buyerOptions = const [],
}) {
  return showDialog<StockpileEntry>(
    context: context,
    builder: (_) => _AddStockpileDialog(buyerOptions: buyerOptions),
  );
}

class _AddStockpileDialog extends StatefulWidget {
  final List<String> buyerOptions;
  const _AddStockpileDialog({required this.buyerOptions});

  @override
  State<_AddStockpileDialog> createState() => _AddStockpileDialogState();
}

class _AddStockpileDialogState extends State<_AddStockpileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stockpileName = TextEditingController();
  final _tons = TextEditingController();
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _description = TextEditingController();
  String _unit = stockpileUnits.first;
  String? _buyer;
  final _buyerText = TextEditingController();

  @override
  void dispose() {
    _stockpileName.dispose();
    _tons.dispose();
    _name.dispose();
    _grade.dispose();
    _description.dispose();
    _buyerText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add stockpile'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _stockpileName,
                  decoration: const InputDecoration(
                    labelText: 'Stockpile name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (widget.buyerOptions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    // A DropdownButtonFormField lays its selected item out at its NATURAL
                    // width and sizes to the WIDEST item in the list, so one long option
                    // decides the control's width whatever is selected (CLAUDE.md §10.4).
                    isExpanded: true,
                    initialValue: _buyer,
                    decoration: const InputDecoration(
                      labelText: 'For buyer',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final b in widget.buyerOptions)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => _buyer = v),
                    validator: (v) => v == null ? 'Select a buyer' : null,
                  )
                else
                  TextFormField(
                    controller: _buyerText,
                    decoration: const InputDecoration(
                      labelText: 'For buyer',
                      helperText: 'No connected buyers yet — enter the buyer name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a buyer' : null,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tons,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tons',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid tonnage';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _MineralFields(
                  name: _name,
                  grade: _grade,
                  description: _description,
                  unit: _unit,
                  onUnitChanged: (v) => setState(() => _unit = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(
                StockpileEntry(
                  name: _stockpileName.text.trim(),
                  buyer: widget.buyerOptions.isNotEmpty
                      ? _buyer
                      : _buyerText.text.trim(),
                  tons: double.parse(_tons.text),
                  mineral: _name.text.trim().isEmpty ? null : _name.text.trim(),
                  grade: _grade.text.trim().isEmpty ? null : _grade.text.trim(),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: MlTokens.accent,
            foregroundColor: MlTokens.navy950,
          ),
          child: const Text('Save stockpile'),
        ),
      ],
    );
  }
}

class _MineralFields extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController grade;
  final TextEditingController description;
  final String unit;
  final ValueChanged<String> onUnitChanged;

  const _MineralFields({
    required this.name,
    required this.grade,
    required this.description,
    required this.unit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Mineral name',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: grade,
          decoration: const InputDecoration(
            labelText: 'Grade',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // A DropdownButtonFormField lays its selected item out at its NATURAL
          // width and sizes to the WIDEST item in the list, so one long option
          // decides the control's width whatever is selected (CLAUDE.md §10.4).
          isExpanded: true,
          initialValue: unit,
          decoration: const InputDecoration(
            labelText: 'Unit of measure',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final u in stockpileUnits)
              DropdownMenuItem(value: u, child: Text(u)),
          ],
          onChanged: (v) => onUnitChanged(v ?? stockpileUnits.first),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

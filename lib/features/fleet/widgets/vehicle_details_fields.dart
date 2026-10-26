import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/components/ml_field_pair.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// One seal-point choice: the count, and what kind of rig carries it.
///
/// 1 and 3 are honestly labelled unusual rather than given a made-up rig
/// description — a transporter reading the list should be steered to 2 or 4
/// and only pick an odd count deliberately.
class _SealPointOption {
  final int count;
  final String label;
  final String description;

  const _SealPointOption(this.count, this.label, this.description);
}

const _sealPointOptions = <_SealPointOption>[
  _SealPointOption(1, '1 seal', 'Unusual — a single sealed point'),
  _SealPointOption(2, '2 seals', 'Rigid truck, or one trailer'),
  _SealPointOption(3, '3 seals', 'Unusual — three sealed points'),
  _SealPointOption(4, '4 seals', 'Interlink — two trailers'),
];

/// Shared registration + vehicle identity fields for add/edit fleet dialogs.
class VehicleDetailsFields extends StatelessWidget {
  final TextEditingController registrationController;
  final TextEditingController makeController;
  final TextEditingController typeController;
  final TextEditingController yearController;
  final TextEditingController odometerController;
  final TextEditingController firstTrailerController;
  final TextEditingController secondTrailerController;

  /// Seal points on the rig — how many seals a sealed load must carry.
  ///
  /// Asked outright because it used to be guessed from whether the two
  /// OPTIONAL registration fields above had been filled in, which is a
  /// different question and got it wrong whenever a transporter had not typed
  /// a trailer number. Null hides the control, for callers that do not manage
  /// it.
  final int? sealPoints;
  final ValueChanged<int>? onSealPointsChanged;
  final DateTime? expiryDate;
  final VoidCallback onPickExpiryDate;
  final bool registrationRequired;

  const VehicleDetailsFields({
    super.key,
    required this.registrationController,
    required this.makeController,
    required this.typeController,
    required this.yearController,
    required this.odometerController,
    required this.firstTrailerController,
    required this.secondTrailerController,
    this.sealPoints,
    this.onSealPointsChanged,
    required this.expiryDate,
    required this.onPickExpiryDate,
    this.registrationRequired = true,
  });

  static String? validateYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final year = int.tryParse(value.trim());
    if (year == null) return 'Enter a valid year';
    final now = MlTime.now().year;
    if (year < 1950 || year > now + 2) {
      return 'Year must be between 1950 and ${now + 2}';
    }
    return null;
  }

  static String? validateOdometer(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final km = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    if (km == null) return 'Enter kilometres as a number';
    if (km < 0) return 'Odometer cannot be negative';
    if (km > 9999999) return 'Odometer value is too large';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Two columns halve the width available to each field's label, so whether
    // two columns fit depends on two things the old `MediaQuery.sizeOf(context)
    // .width < 480` knew neither of:
    //
    //  * How large the text is. At the largest scale the shell will install, a
    //    1024px desktop still put "Year model" and "Odometer (km)" side by
    //    side and ellipsised both labels.
    //  * How wide THIS widget is, rather than the screen. Both dialogs cap
    //    their content at 520px, so past that a wider screen gives these
    //    fields nothing — and below it, a 480px screen carries only 432px of
    //    content, which is why "Odometer (km)" was cut at 480px one notch
    //    above the default text size while the screen-width test said the
    //    breakpoint had been cleared.
    //
    // LayoutBuilder answers both: compare the width actually handed to these
    // fields against a threshold in the same scaled units the text grows in.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFields =
            constraints.maxWidth <
            480 * MediaQuery.textScalerOf(context).scale(1);
        return _build(context, scheme, stackFields);
      },
    );
  }

  Widget _build(BuildContext context, ColorScheme scheme, bool stackFields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.confirmation_number_outlined,
          title: 'Registration',
          color: scheme.primary,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: registrationController,
          decoration: const InputDecoration(
            labelText: 'Registration *',
            hintText: 'e.g. TJ-157-MP',
            helperText: 'The truck itself — trailers below',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          validator: registrationRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Registration number is required';
                  }
                  return null;
                }
              : null,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onPickExpiryDate,
          borderRadius: MlShape.radiusExtraSmall,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Licence disk expiry',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              expiryDate == null
                  ? 'Select date (optional)'
                  : '${expiryDate!.day.toString().padLeft(2, '0')}/'
                        '${expiryDate!.month.toString().padLeft(2, '0')}/'
                        '${expiryDate!.year}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Short labels, with the detail in helper text.
        //
        // A floating [InputDecoration] label is always one line and always
        // ellipsises, so a long one is simply unreadable on a narrow phone:
        // "2nd trailer registration" was cut on a 320px screen at the
        // SMALLEST text size the app offers. Helper text wraps, so moving the
        // words there means they survive every size instead of being the
        // first thing lost.
        TextFormField(
          controller: firstTrailerController,
          decoration: const InputDecoration(
            labelText: 'Trailer 1',
            hintText: 'e.g. TJ-158-MP',
            helperText: 'Registration — optional',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: secondTrailerController,
          decoration: const InputDecoration(
            labelText: 'Trailer 2',
            hintText: 'e.g. TJ-159-MP',
            helperText: 'Registration — optional',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        if (sealPoints != null && onSealPointsChanged != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // Without this the selected item is laid out at its natural width,
            // so "4 seals — interlink, two trailers" pushed the add-vehicle
            // dialog 357px past a narrow phone. Caught by
            // mobile_parity_verification_test.
            isExpanded: true,
            // Each option is two lines, and they are not the same length, so a
            // fixed row height would clip the description off the taller ones.
            itemHeight: null,
            initialValue: sealPoints!.clamp(1, 4),
            decoration: const InputDecoration(
              labelText: 'Seal points *',
              helperText:
                  'How many seals a sealed load must carry. The '
                  'weighbridge accepts exactly this many — no more, no fewer.',
              // Enough lines for this sentence to survive a phone at the
              // largest text size the shell will install; helper text that
              // ellipsises loses the end of the sentence, which is the half
              // that says the count is exact.
              helperMaxLines: 8,
              border: OutlineInputBorder(),
            ),
            // The closed field shows only the count.
            //
            // The description belongs in the MENU, where the operator is
            // choosing; in the closed field it is a restatement they have
            // already read. Cramming both into one line is what made every
            // option unreadable on a phone: measured on a 320px screen at
            // ordinary text size, the open menu gave the label 132px of a
            // 238px string and ellipsised the rest, so "4 seals — interlink,
            // two trailers" and "2 seals — rigid or one trailer" both arrived
            // as a number followed by a cut-off word. The gloss exists for an
            // operator who does not already know how many seal points their
            // rig has, which is the one person it was failing.
            selectedItemBuilder: (context) => [
              for (final option in _sealPointOptions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            items: [
              for (final option in _sealPointOptions)
                DropdownMenuItem(
                  value: option.count,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label),
                        const SizedBox(height: 2),
                        // Wraps rather than ellipsising — the description is
                        // the whole reason the menu is wider than the field.
                        Text(
                          option.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onSealPointsChanged!(v);
            },
          ),
        ],
        const SizedBox(height: 24),
        _SectionHeader(
          icon: Icons.local_shipping_outlined,
          title: 'Vehicle / truck details',
          color: scheme.tertiary,
        ),
        const SizedBox(height: 8),
        Text(
          'Helps identify the unit in fleet lists, operations, and compliance checks.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (stackFields) ...[
          TextFormField(
            controller: makeController,
            decoration: const InputDecoration(
              labelText: 'Make',
              hintText: 'e.g. Opel',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: typeController,
            decoration: const InputDecoration(
              labelText: 'Type / model',
              hintText: 'e.g. Astra J',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: yearController,
            decoration: const InputDecoration(
              labelText: 'Year model',
              hintText: 'e.g. 2018',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            validator: validateYear,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: odometerController,
            decoration: const InputDecoration(
              labelText: 'Odometer',
              hintText: 'e.g. 250120',
              helperText: 'Kilometres',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: validateOdometer,
          ),
        ] else ...[
          MlFieldPair(
            first: TextFormField(
              controller: makeController,
              decoration: const InputDecoration(
                labelText: 'Make',
                hintText: 'e.g. Opel',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            second: TextFormField(
              controller: typeController,
              decoration: const InputDecoration(
                labelText: 'Type / model',
                hintText: 'e.g. Astra J',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),
          MlFieldPair(
            first: TextFormField(
              controller: yearController,
              decoration: const InputDecoration(
                labelText: 'Year model',
                hintText: 'e.g. 2018',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              validator: validateYear,
            ),
            second: TextFormField(
              controller: odometerController,
              decoration: const InputDecoration(
                labelText: 'Odometer',
                hintText: 'e.g. 250120',
                helperText: 'Kilometres',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: validateOdometer,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: MlShape.radiusMedium,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Parses optional form values for RPC payloads.
class VehicleDetailsInput {
  final String? make;
  final String? type;
  final int? yearModel;
  final int? odometerKm;

  const VehicleDetailsInput({
    this.make,
    this.type,
    this.yearModel,
    this.odometerKm,
  });

  static VehicleDetailsInput fromControllers({
    required TextEditingController makeController,
    required TextEditingController typeController,
    required TextEditingController yearController,
    required TextEditingController odometerController,
  }) {
    final make = makeController.text.trim();
    final type = typeController.text.trim();
    final yearRaw = yearController.text.trim();
    final odoRaw = odometerController.text.replaceAll(RegExp(r'[^0-9]'), '');

    return VehicleDetailsInput(
      make: make.isEmpty ? null : make,
      type: type.isEmpty ? null : type,
      yearModel: yearRaw.isEmpty ? null : int.tryParse(yearRaw),
      odometerKm: odoRaw.isEmpty ? null : int.tryParse(odoRaw),
    );
  }
}

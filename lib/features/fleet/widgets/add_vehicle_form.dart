import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/widgets/vehicle_details_fields.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

class AddVehicleForm extends ConsumerStatefulWidget {
  final String companyId;

  const AddVehicleForm({super.key, required this.companyId});

  @override
  ConsumerState<AddVehicleForm> createState() => _AddVehicleFormState();
}

class _AddVehicleFormState extends ConsumerState<AddVehicleForm> {
  final _formKey = GlobalKey<FormState>();
  final _registrationController = TextEditingController();
  final _makeController = TextEditingController();
  final _typeController = TextEditingController();
  final _yearController = TextEditingController();
  final _odometerController = TextEditingController();
  final _firstTrailerController = TextEditingController();
  final _secondTrailerController = TextEditingController();

  /// A new truck-and-trailer rig is the common case here, and 4 is what the
  /// whole existing fleet carries. The operator changes it for anything else.
  int _sealPoints = 4;

  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _registrationController.dispose();
    _makeController.dispose();
    _typeController.dispose();
    _yearController.dispose();
    _odometerController.dispose();
    _firstTrailerController.dispose();
    _secondTrailerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: DialogUtils.adaptiveInsetPadding(context),
      contentPadding: DialogUtils.adaptiveContentPadding(context),
      title: const Text('Add fleet vehicle'),
      content: SizedBox(
        width: DialogUtils.contentMaxWidth(context),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: VehicleDetailsFields(
              registrationController: _registrationController,
              makeController: _makeController,
              typeController: _typeController,
              yearController: _yearController,
              odometerController: _odometerController,
              firstTrailerController: _firstTrailerController,
              secondTrailerController: _secondTrailerController,
              sealPoints: _sealPoints,
              onSealPointsChanged: (v) => setState(() => _sealPoints = v),
              expiryDate: _expiryDate,
              onPickExpiryDate: _selectExpiryDate,
            ),
          ),
        ),
      ),
      actions: DialogUtils.adaptiveDialogActions(
        context: context,
        onCancel: () => Navigator.of(context).pop(),
        primary: FilledButton(
          onPressed: _isSubmitting ? null : _submitForm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add vehicle'),
        ),
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? MlTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: MlTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null && picked != _expiryDate) {
      if (mounted) setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final details = VehicleDetailsInput.fromControllers(
        makeController: _makeController,
        typeController: _typeController,
        yearController: _yearController,
        odometerController: _odometerController,
      );

      await ref.read(fleetProvider(widget.companyId).notifier).addFleetVehicle(
            vehicleRegistrationNumber: _registrationController.text.trim(),
            vehicleRegistrationExpiryDate: _expiryDate,
            firstTrailerRegs: _firstTrailerController.text.trim().isEmpty
                ? null
                : _firstTrailerController.text.trim(),
            secondTrailerRegs: _secondTrailerController.text.trim().isEmpty
                ? null
                : _secondTrailerController.text.trim(),
            vehicleMake: details.make,
            vehicleType: details.type,
            vehicleYearModel: details.yearModel,
            vehicleOdometerKm: details.odometerKm,
            sealPoints: _sealPoints,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully'),
            backgroundColor: MlTokens.green600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add vehicle. ${friendlyError(e)}'),
            backgroundColor: MlTokens.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/widgets/vehicle_details_fields.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

class EditVehicleDialog extends ConsumerStatefulWidget {
  final String companyId;
  final FleetVehicle vehicle;

  const EditVehicleDialog({
    super.key,
    required this.companyId,
    required this.vehicle,
  });

  @override
  ConsumerState<EditVehicleDialog> createState() => _EditVehicleDialogState();
}

class _EditVehicleDialogState extends ConsumerState<EditVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _registrationController;
  late final TextEditingController _makeController;
  late final TextEditingController _typeController;
  late final TextEditingController _yearController;
  late final TextEditingController _odometerController;
  late final TextEditingController _firstTrailerController;
  late final TextEditingController _secondTrailerController;
  late int _sealPoints;

  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _registrationController = TextEditingController(text: v.vehicleRegistrationNumber);
    _makeController = TextEditingController(text: v.vehicleMake ?? '');
    _typeController = TextEditingController(text: v.vehicleType ?? '');
    _yearController = TextEditingController(
      text: v.vehicleYearModel?.toString() ?? '',
    );
    _odometerController = TextEditingController(
      text: v.vehicleOdometerKm?.toString() ?? '',
    );
    _firstTrailerController = TextEditingController(text: v.firstTrailerRegs ?? '');
    _secondTrailerController = TextEditingController(text: v.secondTrailerRegs ?? '');
    _sealPoints = v.sealPoints;
    _expiryDate = v.vehicleRegistrationExpiryDate;
  }

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
      title: Text('Edit ${widget.vehicle.vehicleRegistrationNumber}'),
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
              onSealPointsChanged: (val) => setState(() => _sealPoints = val),
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
              : const Text('Save changes'),
        ),
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? MlTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: MlTime.now().add(const Duration(days: 365 * 15)),
    );

    if (picked != null) {
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

      await ref.read(fleetProvider(widget.companyId).notifier).updateFleetVehicle(
            id: widget.vehicle.id,
            vehicleRegistrationNumber: _registrationController.text.trim(),
            vehicleRegistrationExpiryDate: _expiryDate,
            firstTrailerRegs: _firstTrailerController.text.trim(),
            secondTrailerRegs: _secondTrailerController.text.trim(),
            sealPoints: _sealPoints,
            vehicleMake: details.make,
            vehicleType: details.type,
            vehicleYearModel: details.yearModel,
            vehicleOdometerKm: details.odometerKm,
            clearVehicleMake: details.make == null,
            clearVehicleType: details.type == null,
            clearVehicleYearModel: details.yearModel == null,
            clearVehicleOdometerKm: details.odometerKm == null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle updated'),
            backgroundColor: MlTokens.green600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update vehicle. ${friendlyError(e)}'),
            backgroundColor: MlTokens.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

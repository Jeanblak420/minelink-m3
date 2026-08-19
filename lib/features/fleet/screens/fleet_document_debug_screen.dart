import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/widgets/m3_dropdown_field.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/core/widgets/loading_indicator.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class FleetDocumentDebugScreen extends ConsumerStatefulWidget {
  final String companyId;

  const FleetDocumentDebugScreen({super.key, required this.companyId});

  @override
  FleetDocumentDebugScreenState createState() =>
      FleetDocumentDebugScreenState();
}

class FleetDocumentDebugScreenState
    extends ConsumerState<FleetDocumentDebugScreen> {
  String? _selectedVehicleId;
  Map<String, dynamic>? _verificationResult;
  bool _isVerifying = false;
  bool _isFixing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final fleetState = ref.watch(fleetProvider(widget.companyId));
    final vehicles = fleetState.vehicles;
    final isLoading = fleetState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Fleet Document Debug')),
      body: isLoading
          ? const Center(child: LoadingIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a vehicle to verify document URLs:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildVehicleDropdown(vehicles),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _selectedVehicleId != null && !_isVerifying
                            ? _verifyDocumentUrls
                            : null,
                        child: Text(
                          _isVerifying
                              ? 'Verifying...'
                              : 'Verify Document URLs',
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonal(
                        onPressed:
                            _selectedVehicleId != null &&
                                !_isFixing &&
                                _verificationResult != null
                            ? _fixDocumentUrls
                            : null,
                        child: Text(
                          _isFixing ? 'Fixing...' : 'Fix Document URLs',
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: MlTokens.red600),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: _verificationResult != null
                        ? _buildVerificationResult()
                        : const Center(
                            child: Text(
                              'Select a vehicle and click "Verify Document URLs"',
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVehicleDropdown(List<FleetVehicle> vehicles) {
    return M3DropdownField<String>(
      initialValue: _selectedVehicleId,
      label: 'Vehicle',
      enableSearch: true,
      enableFilter: true,
      entries: vehicles.map((vehicle) {
        final hasDriver = vehicle.assignedDriverId != null;
        final driverInfo = hasDriver
            ? ' (Driver: ${vehicle.driverFullName})'
            : ' (No driver)';
        return DropdownMenuEntry<String>(
          value: vehicle.id,
          label: '${vehicle.vehicleRegistrationNumber}$driverInfo',
        );
      }).toList(),
      onSelected: (value) {
        setState(() {
          _selectedVehicleId = value;
          _verificationResult = null;
          _errorMessage = null;
        });
      },
    );
  }

  Widget _buildVerificationResult() {
    if (_verificationResult == null) {
      return const SizedBox.shrink();
    }

    final status = _verificationResult!['status'] as String;

    if (status == 'error') {
      return Center(
        child: Text(
          'Error: ${_verificationResult!['message']}',
          style: const TextStyle(color: MlTokens.red600),
        ),
      );
    }

    if (status == 'no_driver') {
      return const Center(child: Text('No driver assigned to this vehicle'));
    }

    if (status == 'driver_not_found') {
      return Center(
        child: Text(
          'Driver not found: ${_verificationResult!['driver_id']}',
          style: const TextStyle(color: MlTokens.red600),
        ),
      );
    }

    // Success case
    final documentStatus =
        _verificationResult!['document_status'] as Map<String, dynamic>;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle: ${_verificationResult!['vehicle_id']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Driver: ${_verificationResult!['driver_name']}'),
          const SizedBox(height: 16),
          const Text(
            'Document Status:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildDocumentStatusCard(
            'ID Document',
            documentStatus['id_document'] as Map<String, dynamic>,
          ),
          _buildDocumentStatusCard(
            'Passport',
            documentStatus['passport_document'] as Map<String, dynamic>,
          ),
          _buildDocumentStatusCard(
            'Work Visa',
            documentStatus['work_visa_document'] as Map<String, dynamic>,
          ),
          _buildDocumentStatusCard(
            'License',
            documentStatus['license_document'] as Map<String, dynamic>,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatusCard(
    String documentName,
    Map<String, dynamic> status,
  ) {
    final driverHasUrl = status['driver_has_url'] as bool;
    final vehicleHasUrl = status['vehicle_has_url'] as bool;
    final match = status['match'] as bool;

    Color cardColor;
    String statusText;

    if (!driverHasUrl) {
      cardColor = MlTokens.slate200;
      statusText = 'Driver has no document URL';
    } else if (!vehicleHasUrl) {
      cardColor = MlTokens.orange50;
      statusText = 'Vehicle missing document URL';
    } else if (!match) {
      cardColor = MlTokens.red50;
      statusText = 'URLs do not match';
    } else {
      cardColor = MlTokens.green50;
      statusText = 'OK';
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  documentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: !driverHasUrl
                        ? MlTokens.slate700
                        : !vehicleHasUrl || !match
                        ? MlTokens.red600
                        : MlTokens.green700,
                  ),
                ),
              ],
            ),
            if (driverHasUrl) ...[
              const SizedBox(height: 8),
              const Text(
                'Driver URL:',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(
                status['driver_url'] as String? ?? 'null',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (vehicleHasUrl) ...[
              const SizedBox(height: 8),
              const Text(
                'Vehicle URL:',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(
                status['vehicle_url'] as String? ?? 'null',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _verifyDocumentUrls() async {
    if (_selectedVehicleId == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(fleetProvider(widget.companyId).notifier)
          .verifyVehicleDocumentUrls(_selectedVehicleId!);

      if (mounted) {
        setState(() {
          _verificationResult = result;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _fixDocumentUrls() async {
    if (_selectedVehicleId == null) return;

    setState(() {
      _isFixing = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(fleetProvider(widget.companyId).notifier)
          .fixVehicleDocumentUrls(_selectedVehicleId!);

      // Re-verify after fixing
      final result = await ref
          .read(fleetProvider(widget.companyId).notifier)
          .verifyVehicleDocumentUrls(_selectedVehicleId!);

      if (mounted) {
        setState(() {
          _verificationResult = result;
          _isFixing = false;
        });
      }

      // Check if the widget is still mounted before showing the snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document URLs fixed successfully'),
            backgroundColor: MlTokens.green600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isFixing = false;
        });
      }
    }
  }
}

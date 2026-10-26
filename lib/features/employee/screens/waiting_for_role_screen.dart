import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_status_provider.dart';
import 'package:flutter_application_1/features/employee/widgets/employee_status_timeline.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/core/widgets/back_button_handler.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class WaitingForRoleScreen extends ConsumerStatefulWidget {
  const WaitingForRoleScreen({super.key});

  @override
  ConsumerState<WaitingForRoleScreen> createState() =>
      _WaitingForRoleScreenState();
}

class _WaitingForRoleScreenState extends ConsumerState<WaitingForRoleScreen> {
  bool _showStatusDetails = false;

  @override
  void initState() {
    super.initState();
    // Load status history when the screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatusHistory();
    });
  }

  void _loadStatusHistory() {
    final employeeState = ref.read(employeeProvider);
    if (employeeState.employee != null) {
      ref
          .read(employeeStatusProvider.notifier)
          .loadEmployeeStatusHistory(employeeState.employee!.id);
    }
  }

  void _toggleStatusDetails() {
    setState(() {
      _showStatusDetails = !_showStatusDetails;
    });

    // Refresh status data when expanding
    if (_showStatusDetails) {
      _loadStatusHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeState = ref.watch(employeeProvider);
    final employee = employeeState.employee;
    final company = employeeState.company;

    return BackButtonHandler(
      title: 'Sign out',
      message: 'Going back will sign you out. Are you sure?',
      onBackConfirmed: () {
        if (context.mounted) {
          // Show logout confirmation dialog
          LogoutService.logoutWithConfirmation(context, ref);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting for Approval'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                // Show logout confirmation dialog
                LogoutService.logoutWithConfirmation(context, ref);
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MlIconWell(
                  icon: Icons.hourglass_top_rounded,
                  tone: MlTone.atMine,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'Waiting for Role Assignment',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your request to be added as an employee under ${company?.companyName ?? 'the company'} has been submitted to management for verification.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Once your employment is confirmed, an appropriate role will be assigned to you, granting access to the application features associated with your assigned role.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'These features will become available instantly upon role assignment. We encourage you to check back periodically for updates on your role.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                MlCard(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Information:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Name', employee?.fullName ?? ''),
                        _buildInfoRow('Email', 'Contact HR to update'),
                        _buildInfoRow(
                          'WhatsApp',
                          employee?.whatsappNumber ?? '',
                        ),
                        _buildInfoRow('Company', company?.companyName ?? ''),
                        if (employee?.idNumber != null &&
                            employee!.idNumber!.isNotEmpty)
                          _buildInfoRow('ID number', employee.idNumber!),
                        if (employee?.passportOrWorkersPermit != null &&
                            employee!.passportOrWorkersPermit!.isNotEmpty)
                          _buildInfoRow(
                            'Passport/Permit',
                            employee.passportOrWorkersPermit!,
                          ),
                        if (employee?.licenseDocument != null &&
                            employee!.licenseDocument!.isNotEmpty)
                          _buildInfoRow('License', employee.licenseDocument!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'If you have any questions, please contact your company administrator.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MlTokens.slate600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _toggleStatusDetails,
                  icon: Icon(
                    _showStatusDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  label: Text(
                    _showStatusDetails ? 'Hide Status Details' : 'Check Status',
                  ),
                ),

                // Expandable status details section
                if (_showStatusDetails) ...[
                  const SizedBox(height: 24),
                  MlCard(
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Status Timeline',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildStatusTimeline(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context) {
    final statusState = ref.watch(employeeStatusProvider);
    final employeeState = ref.watch(employeeProvider);

    if (statusState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (statusState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: MlTokens.red600, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading status: ${statusState.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: MlTokens.red600),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadStatusHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (statusState.statusHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No status updates available yet. Your request is being processed.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Use the EmployeeStatusTimeline widget to display the status history
    return EmployeeStatusTimeline(
      statusHistory: statusState.statusHistory,
      employee: employeeState.employee,
      company: employeeState.company,
    );
  }
}

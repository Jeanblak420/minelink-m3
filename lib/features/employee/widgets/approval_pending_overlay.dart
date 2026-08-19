import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_status_provider.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/employee/widgets/employee_status_timeline.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/core/widgets/back_button_handler.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

class ApprovalPendingOverlay extends ConsumerStatefulWidget {
  const ApprovalPendingOverlay({super.key});

  @override
  ConsumerState<ApprovalPendingOverlay> createState() =>
      _ApprovalPendingOverlayState();
}

class _ApprovalPendingOverlayState
    extends ConsumerState<ApprovalPendingOverlay> {
  bool _showStatus = false;

  @override
  void initState() {
    super.initState();
    // Load status history when the overlay is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final employeeState = ref.read(employeeProvider);
        if (employeeState.employee != null) {
          ref
              .read(employeeStatusProvider.notifier)
              .loadEmployeeStatusHistory(employeeState.employee!.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use try-catch to handle potential "ref after dispose" errors
    late final dynamic employeeState;
    late final dynamic company;

    try {
      employeeState = ref.watch(employeeProvider);
      company = employeeState.company;
    } catch (e) {
      // If we get an error (like ref after dispose), use fallback values
      debugPrint('Error in ApprovalPendingOverlay: $e');
      return const Center(child: CircularProgressIndicator());
    }

    return BackButtonHandler(
      // Prevent back button from dismissing the overlay without confirmation
      enabled: true,
      title: 'Confirm Logout',
      message:
          'Are you sure you want to exit? This will log you out of the application.',
      onBackConfirmed: () {
        // Use a try-catch block to handle potential errors
        try {
          if (context.mounted) {
            // Show logout confirmation dialog
            LogoutService.logoutWithConfirmation(context, ref);
          }
        } catch (e) {
          debugPrint(
            'Error in approval pending overlay back button handler. ${friendlyError(e)}',
          );
        }
      },
      child: Container(
        color: MlTokens.overlayDark.withAlpha(179),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24.0),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 64,
                    color: Theme.of(context).primaryColor,
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MlTone.transit.colors(Theme.of(context).brightness).bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MlTone.transit
                            .colors(Theme.of(context).brightness)
                            .fg
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: MlTone.transit
                                .colors(Theme.of(context).brightness)
                                .fg),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your request has been accepted, but you need a role assignment to use the app.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: MlTone.transit
                                  .colors(Theme.of(context).brightness)
                                  .fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your request to be added as an employee under ${company?.companyName ?? 'the selected company'} has been approved. Management now needs to assign you an appropriate role, which will grant you access to the application features associated with that role.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'These features will become available instantly upon role assignment. We encourage you to check back periodically for updates on your role.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'While waiting, you can only access your Profile or Sign Out.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_showStatus) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MlSemantic.of(context).surfaceSunken,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: MlSemantic.of(context).borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: MlTokens.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Status',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // New timeline status widget
                          Consumer(
                            builder: (context, ref, child) {
                              try {
                                final statusState = ref.watch(
                                  employeeStatusProvider,
                                );
                                final employeeState = ref.watch(
                                  employeeProvider,
                                );

                                // If status history is loading, show a loading indicator
                                if (statusState.isLoading) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                // Pass the status history to the timeline
                                return EmployeeStatusTimeline(
                                  statusHistory: statusState.statusHistory,
                                  employee: employeeState.employee,
                                  company: employeeState.company,
                                );
                              } catch (e) {
                                // Handle any errors that might occur when using ref after dispose
                                debugPrint(
                                  'Error in status timeline Consumer. ${friendlyError(e)}',
                                );
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'Status information is currently unavailable. Please try again later.',
                                    style: TextStyle(
                                      color: MlTokens.red600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          try {
                            // Refresh employee data to check if role has been assigned
                            final authState = ref.read(authStateProvider);
                            if (authState.user != null) {
                              ref
                                  .read(employeeProvider.notifier)
                                  .loadEmployeeProfile(authState.user!.id);

                              // Also refresh the status history
                              final employeeState = ref.read(employeeProvider);
                              if (employeeState.employee != null) {
                                ref
                                    .read(employeeStatusProvider.notifier)
                                    .loadEmployeeStatusHistory(
                                      employeeState.employee!.id,
                                    );
                              }
                            }
                          } catch (e) {
                            debugPrint('Error refreshing employee data: $e');
                            // Show a snackbar with the error
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not refresh status. Please try again.',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }

                          // Toggle status section
                          setState(() {
                            _showStatus = !_showStatus;
                          });
                        },
                        icon: Icon(
                          _showStatus ? Icons.visibility_off : Icons.visibility,
                        ),
                        label: Text(
                          _showStatus ? 'Hide Status' : 'Check Status',
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          context.go('/profile');
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      // Show logout confirmation dialog
                      LogoutService.logoutWithConfirmation(context, ref);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: TextButton.styleFrom(foregroundColor: MlTokens.red600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

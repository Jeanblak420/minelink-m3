import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:go_router/go_router.dart';

class RequestDeclinedScreen extends ConsumerWidget {
  final AppNotification notification;

  const RequestDeclinedScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyName = notification.metadata?['company_name'] ?? 'the company';

    return PopScope(
      // Prevent back button from dismissing the screen
      canPop: false,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: MlCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MlIconWell(
                        icon: Icons.error_outline,
                        tone: MlTone.error,
                        size: 64),
                    const SizedBox(height: 24),
                    Text(
                      'Request Declined',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oops! $companyName has declined your request to join their company.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'If this was an error, please contact management or re-select the company you are employed with.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        // Load available companies and navigate to company selection screen
                        ref
                            .read(employeeProvider.notifier)
                            .loadAvailableCompanies();
                        context.go('/home');
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Select Another Company'),
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

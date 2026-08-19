import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

class WelcomeNotification extends ConsumerStatefulWidget {
  const WelcomeNotification({super.key});

  @override
  ConsumerState<WelcomeNotification> createState() =>
      _WelcomeNotificationState();
}

class _WelcomeNotificationState extends ConsumerState<WelcomeNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_dismissed) {
        _dismissNotification();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissNotification() {
    setState(() {
      _dismissed = true;
    });
    _controller.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeeState = ref.watch(employeeProvider);
    // We don't need to find the specific notification anymore
    // as we're getting the role information directly from the employee state

    // Get the role name and company name
    final roleName = employeeState.employee?.role?.label ?? 'new';
    final companyName = employeeState.company?.companyName ?? 'your company';

    return PopScope(
      // Prevent back button from dismissing the dialog
      canPop: false,
      child: FadeTransition(
        opacity: _animation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.celebration,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text('Welcome!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                employeeState.employee?.role != null
                    ? 'Congratulations! You have been assigned the $roleName role at $companyName.'
                    : 'Your role assignment has been Processed.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'You now have full access to all features associated with your role.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please explore the app to discover all the features available to you.',
                style: TextStyle(fontSize: 14, color: MlTokens.slate500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _dismissNotification,
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// What a portal screen shows when [resolvePortalCompanyId] returns null
/// (P4-02).
///
/// It replaces **31** copies of a bare centred "Company not loaded." label —
/// four in the router and twenty-seven more across the portal screens — which
/// stated a fault, offered no way out of it, and did not say whether the
/// company was still loading, had failed to load, or genuinely does not
/// exist. `test/router_structure_test.dart` fails the build if one returns.
///
/// The retry is real, not decorative. Company context is populated by an auth
/// state change; if that fired before the profile row was readable, nothing
/// ever re-runs it and the screen stays dead until a full restart. This calls
/// the same two loaders that listener calls, for the signed-in user.
class PortalCompanyRequired extends ConsumerStatefulWidget {
  const PortalCompanyRequired({super.key, this.subject});

  /// What the caller was trying to show, e.g. `'your trips'`. Used to say what
  /// is unavailable rather than only that something is.
  final String? subject;

  @override
  ConsumerState<PortalCompanyRequired> createState() =>
      _PortalCompanyRequiredState();
}

class _PortalCompanyRequiredState extends ConsumerState<PortalCompanyRequired> {
  bool _busy = false;
  String? _error;

  Future<void> _retry() async {
    final userId = ref.read(authStateProvider).user?.id;
    if (userId == null) {
      setState(() => _error = 'You are signed out. Sign in again to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Both paths, because either can be the one that resolves a company: an
      // owner account carries it on `companies`, an employee through their
      // `employees` row.
      await ref.read(companyProvider.notifier).loadCompanyProfile(userId);
      await ref.read(employeeProvider.notifier).loadEmployeeProfile(userId);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    return MlEmptyState(
      icon: Icons.domain_disabled_outlined,
      title: 'Company not loaded',
      message: _error ??
          'Your account is not linked to a company yet, or the link could not '
              'be read.${subject == null ? '' : ' Until it resolves there is '
                  'no $subject to show.'}',
      action: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : MlButton.tonal(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: _retry,
            ),
    );
  }
}

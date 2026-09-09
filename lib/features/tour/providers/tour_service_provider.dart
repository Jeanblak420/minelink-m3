import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/tour/models/tour_step.dart';
import 'package:flutter_application_1/features/tour/services/tour_service.dart';

// -- Tour Service -----------------------------------------------------------

final tourServiceProvider = Provider<TourService>((ref) {
  return const TourService();
});

// -- Tour Steps --------------------------------------------------------------

/// The coach-mark tour steps for the signed-in operator, derived from their org
/// type (company owner or employee's company) and employee role.
final tourStepsProvider = Provider.autoDispose<List<TourStep>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.user == null) return const [];

  final companyState = ref.watch(companyProvider);
  final employeeState = ref.watch(employeeProvider);

  final orgType = authState.userType?.isCompany == true
      ? companyState.company?.orgType
      : employeeState.company?.orgType;
  final role = employeeState.employee?.role?.name;

  final service = ref.watch(tourServiceProvider);
  return service.getTourForUser(orgType, role);
});

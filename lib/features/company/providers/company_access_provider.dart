import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';

class CompanyAccessContext {
  final Company? company;
  final List<Employee> visibleEmployees;
  final Employee? currentEmployee;
  final bool isCompanyAccount;
  final bool canManageEmployees;

  const CompanyAccessContext({
    required this.company,
    required this.visibleEmployees,
    required this.currentEmployee,
    required this.isCompanyAccount,
    required this.canManageEmployees,
  });
}

bool _isManagerEmployee(Employee? employee) {
  return employee?.companyId != null &&
      employee?.status == 'active' &&
      (employee?.role == UserRole.admin ||
          employee?.role == UserRole.management);
}

final companyAccessProvider = Provider<CompanyAccessContext>((ref) {
  final authState = ref.watch(authStateProvider);
  final companyState = ref.watch(companyProvider);
  final employeeState = ref.watch(employeeProvider);
  final currentEmployee = employeeState.employee;
  final isCompanyAccount = authState.userType?.isCompany == true;
  final company = isCompanyAccount
      ? companyState.company
      : companyState.company ?? employeeState.company;

  final visibleEmployees = companyState.employees.isNotEmpty
      ? companyState.employees
      : [
          if (currentEmployee != null &&
              currentEmployee.companyId != null &&
              (company == null || currentEmployee.companyId == company.id))
            currentEmployee,
        ];

  return CompanyAccessContext(
    company: company,
    visibleEmployees: visibleEmployees,
    currentEmployee: currentEmployee,
    isCompanyAccount: isCompanyAccount,
    canManageEmployees:
        isCompanyAccount ||
        companyState.canManageEmployees ||
        _isManagerEmployee(currentEmployee),
  );
});

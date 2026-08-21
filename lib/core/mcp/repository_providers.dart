import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/mcp/repositories/company_repository.dart';
import 'package:flutter_application_1/core/mcp/repositories/employee_repository.dart';

/// The repository seams, in ONE place.
///
/// Both of these existed TWICE. `main.dart` declared a
/// `companyRepositoryProvider` and an `employeeRepositoryProvider`, and
/// `company_list_screen.dart` and `employee_grid_screen.dart` each declared
/// their own of the same name and the same type. Riverpod keys a provider by
/// its OBJECT identity, not its name, so those were four distinct providers:
/// overriding one had no effect whatsoever on the other, and the two names
/// resolving differently depending on which file you happened to import from
/// is exactly the shape that cannot be seen by reading either file.
///
/// It was not theoretical. `portal_tons_out_screen.dart` imported
/// `package:flutter_application_1/main.dart` for the company repository — a
/// feature screen importing the app's ENTRY POINT — while the fixtures
/// overrode the copy in `company_list_screen.dart`. So the tons-out register
/// reached the live database from a render test and photographed whatever the
/// network happened to answer, and no override could reach it.
///
/// One declaration each, in `core`, where a repository seam belongs.
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository();
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository();
});

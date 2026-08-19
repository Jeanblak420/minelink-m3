import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/portal/providers/mirror_company_context_provider.dart';

/// Resolves the active company id for portal screens (normal session vs super-admin mirror).
String? resolvePortalCompanyId(WidgetRef ref) {
  final mirror = ref.watch(mirrorCompanyIdProvider);
  if (mirror != null && mirror.isNotEmpty) {
    return mirror;
  }
  final c = ref.watch(companyProvider).company?.id;
  if (c != null) {
    return c;
  }
  return ref.watch(employeeProvider).employee?.companyId;
}

bool portalMirrorActive(WidgetRef ref) {
  final id = ref.watch(mirrorCompanyIdProvider);
  return id != null && id.isNotEmpty;
}

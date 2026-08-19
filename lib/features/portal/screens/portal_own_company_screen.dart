import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/company/screens/company_list_screen.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';

// Extracted from `app_router.dart` (P4-01…P4-07). It was declared inside
// the router itself, which is why it had no screen file and no test.
/// Glue for `/portal/{org}/company` (phase-2 nav merge, T2): shows the
/// signed-in user's OWN company via the existing [CompanyDetailsLoaderScreen],
/// resolving the active company id from the same providers the portal shell
/// uses (company owner, employee linkage, or super-admin mirror).
class PortalOwnCompanyScreen extends ConsumerWidget {
  const PortalOwnCompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired(subject: 'company profile');
    }
    return CompanyDetailsLoaderScreen(companyId: companyId);
  }
}

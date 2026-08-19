import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/company_access.dart';
import 'package:flutter_application_1/features/portal/providers/mirror_company_context_provider.dart';
import 'package:flutter_application_1/features/portal/services/company_access_service.dart';

/// Whether the current company may act, and why not when it may not.
///
/// Watches [mirrorCompanyIdProvider] so a platform admin mirroring a company
/// gets that company's answer rather than their own — an admin belongs to no
/// company, and "everything is fine" would be a misleading thing to show
/// somebody looking at an expired customer.
final companyAccessProvider = FutureProvider<CompanyAccess>((ref) async {
  final mirrored = ref.watch(mirrorCompanyIdProvider);
  return ref.watch(companyAccessServiceProvider).myAccess(companyId: mirrored);
});

/// The synchronous read every widget should use.
///
/// Resolves to [CompanyAccess.unrestricted] while loading or on error, on
/// purpose: RLS is the real boundary, so a brief optimistic render is harmless,
/// whereas flashing "your token has expired" at a paying customer during a
/// slow request is not.
CompanyAccess companyAccessOf(WidgetRef ref) =>
    ref.watch(companyAccessProvider).valueOrNull ?? CompanyAccess.unrestricted;

/// Same, for a `Ref` rather than a `WidgetRef`.
CompanyAccess companyAccessOfRef(Ref ref) =>
    ref.watch(companyAccessProvider).valueOrNull ?? CompanyAccess.unrestricted;

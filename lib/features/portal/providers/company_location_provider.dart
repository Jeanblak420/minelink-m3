import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/services/company_location_service.dart';

final companyLocationServiceProvider =
    Provider<CompanyLocationService>((ref) => CompanyLocationService());

/// The company's saved locations, primary first.
final companyLocationsProvider = FutureProvider.autoDispose
    .family<List<CompanyLocation>, String>((ref, companyId) {
  return ref.watch(companyLocationServiceProvider).list(companyId);
});

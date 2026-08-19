import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';

final logisticsServiceProvider = Provider<LogisticsService>((ref) => LogisticsService());

final logisticsSnapshotProvider =
    FutureProvider.autoDispose.family<LogisticsSnapshot, String>((ref, companyId) async {
  final svc = ref.watch(logisticsServiceProvider);
  return svc.loadForCompany(companyId);
});

final partnerCompaniesProvider = FutureProvider.autoDispose
    .family<List<CompanyPin>, ({String companyId, String orgFilter})>((ref, args) async {
  final svc = ref.watch(logisticsServiceProvider);
  return svc.listPartnerCompanies(args.companyId, orgFilter: args.orgFilter);
});

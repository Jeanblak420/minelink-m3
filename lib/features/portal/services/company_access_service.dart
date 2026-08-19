import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/company_access.dart';

/// Reads whether the caller's company may still act, via `get_my_company_access`.
///
/// Scoping is server-side and deliberately so: the RPC only answers about a
/// company the caller may already see, so this cannot be used to probe another
/// company's licence state by id.
class CompanyAccessService {
  final SupabaseClient _client = SupabaseConfig.client;
  final _log = LoggerFactory.getLogger('CompanyAccessService');

  /// [companyId] is for the platform admin's company-mirror observer mode — an
  /// admin belongs to no company, so the server cannot infer which one they are
  /// looking at. Everyone else passes null and gets their own.
  Future<CompanyAccess> myAccess({String? companyId}) async {
    try {
      final rows = await _client.rpc(
        'get_my_company_access',
        params: {'p_company_id': companyId},
      );
      final list = (rows as List?) ?? const [];
      if (list.isEmpty) return CompanyAccess.unrestricted;
      return CompanyAccess.fromJson(Map<String, dynamic>.from(list.first));
    } catch (e) {
      // Deliberately permissive. A UI that wrongly believes it is blocked is
      // worse than one that lets the database refuse the write — RLS is the
      // real boundary and it holds regardless of what this returns.
      _log.w('Could not read company access; assuming unrestricted. $e');
      return CompanyAccess.unrestricted;
    }
  }
}

final companyAccessServiceProvider =
    Provider<CompanyAccessService>((ref) => CompanyAccessService());

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_application_1/features/employee/models/employee_status_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmployeeStatusService {
  final _supabase = SupabaseConfig.client;

  Future<List<EmployeeStatusHistory>> getEmployeeStatusHistory(
    String employeeId,
  ) async {
    try {
      final results = await _supabase
          .from('employee_status_history')
          .select()
          .eq('employee_id', employeeId)
          .order('timestamp', ascending: true);

      return results
          .map<EmployeeStatusHistory>(
            (json) => EmployeeStatusHistory.fromJson(json),
          )
          .toList();
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }
}

final employeeStatusServiceProvider = Provider<EmployeeStatusService>(
  (ref) => EmployeeStatusService(),
);

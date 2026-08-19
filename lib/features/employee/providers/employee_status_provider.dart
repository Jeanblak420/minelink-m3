import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/employee/models/employee_status_model.dart';
import 'package:flutter_application_1/features/employee/services/employee_status_service.dart';

class EmployeeStatusState {
  final List<EmployeeStatusHistory> statusHistory;
  final bool isLoading;
  final String? error;

  EmployeeStatusState({
    this.statusHistory = const [],
    this.isLoading = false,
    this.error,
  });

  EmployeeStatusState copyWith({
    List<EmployeeStatusHistory>? statusHistory,
    bool? isLoading,
    String? error,
  }) {
    return EmployeeStatusState(
      statusHistory: statusHistory ?? this.statusHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EmployeeStatusNotifier extends StateNotifier<EmployeeStatusState> {
  final EmployeeStatusService _statusService;
  RealtimeChannel? _statusChannel;
  String? _employeeId;

  EmployeeStatusNotifier(this._statusService) : super(EmployeeStatusState());

  /// Load status history for an employee
  Future<void> loadEmployeeStatusHistory(String employeeId) async {
    try {
      await _refreshStatusHistory(employeeId, showLoading: true);
      _subscribeToRealtimeUpdates(employeeId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Subscribe to realtime updates for employee status history
  void _subscribeToRealtimeUpdates(String employeeId) {
    if (_employeeId == employeeId && _statusChannel != null) {
      return;
    }

    _statusChannel?.unsubscribe();
    _employeeId = employeeId;
    _statusChannel =
        SupabaseConfig.client.channel('employee-status-history-$employeeId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'employee_status_history',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'employee_id',
              value: employeeId,
            ),
            callback: (_) async {
              if (!mounted) {
                return;
              }

              await _refreshStatusHistory(employeeId);
            },
          )
          ..subscribe();
  }

  Future<void> _refreshStatusHistory(
    String employeeId, {
    bool showLoading = false,
  }) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }

    final statusHistory = await _statusService.getEmployeeStatusHistory(
      employeeId,
    );
    state = state.copyWith(
      statusHistory: statusHistory,
      isLoading: false,
      error: null,
    );
  }

  @override
  void dispose() {
    _statusChannel?.unsubscribe();
    super.dispose();
  }
}

final employeeStatusProvider =
    StateNotifierProvider<EmployeeStatusNotifier, EmployeeStatusState>((ref) {
      final statusService = ref.watch(employeeStatusServiceProvider);
      return EmployeeStatusNotifier(statusService);
    });

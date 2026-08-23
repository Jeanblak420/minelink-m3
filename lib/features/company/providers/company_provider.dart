import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/services/company_database_service.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';

const _companyStateUnset = Object();

class CompanyState {
  final Company? company;
  final List<Employee> employees;
  final bool isLoading;
  final String? error;
  final bool canManageEmployees;

  CompanyState({
    this.company,
    this.employees = const [],
    this.isLoading = false,
    this.error,
    this.canManageEmployees = false,
  });

  CompanyState copyWith({
    Object? company = _companyStateUnset,
    List<Employee>? employees,
    bool? isLoading,
    Object? error = _companyStateUnset,
    bool? canManageEmployees,
  }) {
    return CompanyState(
      company: identical(company, _companyStateUnset)
          ? this.company
          : company as Company?,
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _companyStateUnset)
          ? this.error
          : error as String?,
      canManageEmployees: canManageEmployees ?? this.canManageEmployees,
    );
  }
}

class CompanyNotifier extends StateNotifier<CompanyState> {
  final CompanyService _companyService;
  final CompanyDatabaseService _companyDatabaseService;
  final NotificationService _notificationService;
  final AuthStateNotifier _authStateNotifier;
  late final void Function() _removeAuthListener;

  RealtimeChannel? _companyChannel;
  RealtimeChannel? _employeeChannel;
  String? _lastSyncedCompanyUserId;

  /// The user the last AuthState emission was for, company user or employee.
  /// An employee's managed context is cleared only when this CHANGES — see
  /// `_handleAuthStateChanged`.
  String? _lastSeenUserId;

  CompanyNotifier(
    this._companyService,
    this._companyDatabaseService,
    this._notificationService,
    this._authStateNotifier,
  ) : super(CompanyState()) {
    _removeAuthListener = _authStateNotifier.addListener((authState) {
      unawaited(_handleAuthStateChanged(authState));
    }, fireImmediately: true);
  }

  void _setupRealtimeSubscriptions(String companyId) {
    _companyChannel?.unsubscribe();
    _employeeChannel?.unsubscribe();

    _companyChannel = SupabaseConfig.client.channel('company-$companyId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'companies',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: companyId,
        ),
        callback: (_) async => _refreshCompanyData(companyId),
      )
      ..subscribe();

    _employeeChannel =
        SupabaseConfig.client.channel('company-employees-$companyId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'employees',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: companyId,
            ),
            callback: (_) async => _refreshCompanyData(companyId),
          )
          ..subscribe();
  }

  Future<void> _refreshCompanyData(String companyId) async {
    try {
      final company = await _companyDatabaseService
          .getCompanyWithRealTimeUpdates(companyId);
      final employees = await _companyDatabaseService
          .getCompanyEmployeesWithRealTimeUpdates(companyId);

      state = state.copyWith(company: company, employees: employees);
    } catch (e) {
      debugPrint('Error refreshing company data: $e');
    }
  }

  @override
  void dispose() {
    _removeAuthListener();
    _companyChannel?.unsubscribe();
    _employeeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _handleAuthStateChanged(AuthState authState) async {
    final user = authState.user;
    final isCompanyUser = authState.userType?.isCompany == true;

    if (user == null) {
      _lastSyncedCompanyUserId = null;
      _lastSeenUserId = null;
      clearContext();
      return;
    }

    if (!isCompanyUser) {
      // An EMPLOYEE. The context this notifier holds for them is the managed
      // company an admin or manager works in, loaded by the portal shell
      // through `loadManagedCompanyContext` — not by this listener. It used
      // to be wiped here on EVERY AuthState emission, and AuthState re-emits
      // far more often than a sign-in: the auth notifier re-syncs on every
      // change to the user's own `profiles` row, and the chat presence
      // heartbeat writes `last_seen_at` there every 45 s. So every 45 s an
      // admin's company context went to null, `portalWorkspaceProvider` left
      // `ready`, the whole portal body was torn down and rebuilt, and the
      // shell loaded the context again — the dashboard re-read its feeds, the
      // chat dock closed, and any scroll or form state in the body was lost.
      // Owners never saw it: they are company users and take the other path.
      //
      // Driven on 2026-08-23 as ironhills.admin: semantics node count
      // 142 → 6 → 31 → 129 at 05:26:47, 05:27:32 and 05:28:16, each one
      // paired with a "Synced auth state" line in the console and a
      // `profiles.last_seen_at` 45 s heartbeat. Clear only when the USER
      // changed — a different employee, or somebody signing in over them.
      if (_lastSeenUserId != null && _lastSeenUserId != user.id) {
        clearContext();
      }
      _lastSeenUserId = user.id;
      _lastSyncedCompanyUserId = null;
      return;
    }
    _lastSeenUserId = user.id;

    final alreadyLoadedForUser = state.company?.userId == user.id;
    if (state.isLoading ||
        (alreadyLoadedForUser && _lastSyncedCompanyUserId == user.id)) {
      return;
    }

    _lastSyncedCompanyUserId = user.id;
    await loadCompanyProfile(user.id);
  }

  void clearContext() {
    _companyChannel?.unsubscribe();
    _employeeChannel?.unsubscribe();
    _companyChannel = null;
    _employeeChannel = null;
    state = CompanyState();
  }

  Future<void> loadCompanyProfile(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final company = await _companyDatabaseService.getCompanyByUserId(userId);
      final employees = await _companyDatabaseService.getCompanyEmployees(
        company.id,
      );
      state = state.copyWith(
        company: company,
        employees: employees,
        isLoading: false,
        canManageEmployees: true,
      );
      _setupRealtimeSubscriptions(company.id);
    } catch (e) {
      state = state.copyWith(
        company: null,
        employees: const [],
        isLoading: false,
        error: e.toString(),
        canManageEmployees: false,
      );
    }
  }

  Future<void> loadManagedCompanyContext(String companyId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final company = await _companyDatabaseService.getCompanyById(companyId);
      final employees = await _companyDatabaseService.getCompanyEmployees(
        companyId,
      );

      state = state.copyWith(
        company: company,
        employees: employees,
        isLoading: false,
        canManageEmployees: true,
      );
      _setupRealtimeSubscriptions(companyId);
    } catch (e) {
      state = state.copyWith(
        company: null,
        employees: const [],
        isLoading: false,
        error: e.toString(),
        canManageEmployees: false,
      );
    }
  }

  Future<void> loadCompanyEmployees(String companyId) async {
    if (!state.canManageEmployees) {
      state = state.copyWith(
        isLoading: false,
        error:
            'Only company owners, admins, and management can manage company users.',
      );
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      final employees = await _companyDatabaseService.getCompanyEmployees(
        companyId,
      );
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> acceptEmployeeRequest(String employeeId) async {
    if (!state.canManageEmployees) {
      throw Exception(
        'Only company owners, admins, and management can approve employee requests.',
      );
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedEmployee = await _companyDatabaseService
          .approveEmployeeRequest(employeeId);
      await _clearCompanyEmployeesCache();

      final updatedEmployees = state.employees.map((employee) {
        return employee.id == employeeId ? updatedEmployee : employee;
      }).toList();

      state = state.copyWith(employees: updatedEmployees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> assignRoleToEmployee(String employeeId, UserRole role) async {
    if (!state.canManageEmployees) {
      throw Exception(
        'Only company owners, admins, and management can assign employee roles.',
      );
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedEmployee = await _companyDatabaseService
          .assignRoleToEmployee(employeeId, role);
      await _clearCompanyEmployeesCache();

      final updatedEmployees = state.employees.map((employee) {
        return employee.id == employeeId ? updatedEmployee : employee;
      }).toList();

      state = state.copyWith(employees: updatedEmployees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> declineEmployeeRequest(String employeeId) async {
    if (!state.canManageEmployees) {
      throw Exception(
        'Only company owners, admins, and management can decline employee requests.',
      );
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      await _companyDatabaseService.declineEmployeeRequest(employeeId);
      await _clearCompanyEmployeesCache();

      final updatedEmployees = state.employees
          .where((employee) => employee.id != employeeId)
          .toList();

      state = state.copyWith(employees: updatedEmployees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateCompanyProfile(Map<String, dynamic> data) async {
    if (state.company == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      await _companyDatabaseService.updateCompanyProfile(
        state.company!.id,
        data,
      );

      final updatedCompany = state.company!.copyWith(
        companyName: data['company_name'] ?? state.company!.companyName,
        whatsappNumber:
            data['whatsapp_number'] ?? state.company!.whatsappNumber,
        orgType: data['org_type'] != null
            ? OrgType.values.firstWhere(
                (orgType) => orgType.name == data['org_type'],
                orElse: () => state.company!.orgType,
              )
            : state.company!.orgType,
        logoUrl: data['logo_url'] ?? state.company!.logoUrl,
        ceoFirstName: data['ceo_first_name'] ?? state.company!.ceoFirstName,
        ceoLastName: data['ceo_last_name'] ?? state.company!.ceoLastName,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(company: updatedCompany, isLoading: false);

      if (_authStateNotifier.state.user != null) {
        await _notificationService.createProfileUpdateNotification(
          updatedUserId: state.company!.userId,
          updaterUserId: _authStateNotifier.state.user!.id,
          updaterName: _authStateNotifier.state.user?.email ?? 'Company Admin',
          updatedUserName: state.company!.companyName,
          fieldUpdated: 'company profile',
        );
      }
    } catch (e) {
      debugPrint('Error in company provider updateCompanyProfile: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String> uploadCompanyLogo(List<int> fileBytes, String fileName) async {
    if (state.company == null) {
      throw Exception('Company profile is not loaded');
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final logoUrl = await _companyService.uploadCompanyLogo(
        state.company!.id,
        Uint8List.fromList(fileBytes),
        fileName,
      );

      final updatedCompany = state.company!.copyWith(
        logoUrl: logoUrl,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(company: updatedCompany, isLoading: false);

      if (_authStateNotifier.state.user != null) {
        await _notificationService.createProfileUpdateNotification(
          updatedUserId: state.company!.userId,
          updaterUserId: _authStateNotifier.state.user!.id,
          updaterName: _authStateNotifier.state.user?.email ?? 'Company Admin',
          updatedUserName: state.company!.companyName,
          fieldUpdated: 'company logo',
        );
      }

      return logoUrl;
    } catch (e) {
      debugPrint('Error in company provider uploadCompanyLogo: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> loadEmployees() async {
    if (state.company == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final employees = await _companyDatabaseService.getCompanyEmployees(
        state.company!.id,
      );
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (e) {
      debugPrint('Error loading employees: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createManagedEmployee({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String whatsappNumber,
    required UserRole role,
  }) async {
    if (!state.canManageEmployees) {
      throw Exception(
        'Only company owners, admins, and management can add company users.',
      );
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final newEmployee = await _companyDatabaseService.createManagedEmployee(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        whatsappNumber: whatsappNumber,
        role: role,
      );
      await _clearCompanyEmployeesCache();

      state = state.copyWith(
        employees: [...state.employees, newEmployee],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateEmployeeDetails({
    required Employee employee,
    required String firstName,
    required String lastName,
    required String whatsappNumber,
    required UserRole role,
  }) async {
    if (!state.canManageEmployees) {
      throw Exception(
        'Only company owners, admins, and management can update company users.',
      );
    }

    final trimmedFirstName = firstName.trim();
    final trimmedLastName = lastName.trim();
    final trimmedWhatsappNumber = whatsappNumber.trim();
    final detailsChanged =
        trimmedFirstName != employee.firstName ||
        trimmedLastName != employee.lastName ||
        trimmedWhatsappNumber != employee.whatsappNumber;
    final roleChanged = employee.role != role;

    if (!detailsChanged && !roleChanged) {
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      Employee updatedEmployee = employee;

      if (detailsChanged) {
        updatedEmployee = await _companyDatabaseService.updateCompanyEmployee(
          employeeId: employee.id,
          firstName: trimmedFirstName,
          lastName: trimmedLastName,
          whatsappNumber: trimmedWhatsappNumber,
        );
      }

      if (roleChanged) {
        updatedEmployee = await _companyDatabaseService.assignRoleToEmployee(
          employee.id,
          role,
        );
      }

      await _clearCompanyEmployeesCache();

      final updatedEmployees = state.employees.map((currentEmployee) {
        return currentEmployee.id == employee.id
            ? updatedEmployee
            : currentEmployee;
      }).toList();

      state = state.copyWith(employees: updatedEmployees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> removeEmployee(String employeeId) async {
    if (!state.canManageEmployees) {
      throw Exception(
        'Only company owners, admins, and management can remove company users.',
      );
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      await _companyDatabaseService.removeCompanyEmployee(employeeId);
      await _clearCompanyEmployeesCache();

      final updatedEmployees = state.employees
          .where((employee) => employee.id != employeeId)
          .toList();

      state = state.copyWith(employees: updatedEmployees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> _clearCompanyEmployeesCache() async {
    final companyId = state.company?.id;
    await CacheService.clearCompanyEmployeesCache(companyId: companyId);
  }
}

final companyProvider = StateNotifierProvider<CompanyNotifier, CompanyState>((
  ref,
) {
  return CompanyNotifier(
    ref.watch(companyServiceProvider),
    ref.watch(companyDatabaseServiceProvider),
    ref.watch(notificationServiceProvider),
    ref.watch(authStateProvider.notifier),
  );
});

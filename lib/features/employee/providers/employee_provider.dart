import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/services/employee_service.dart';

const _employeeStateUnset = Object();

class EmployeeState {
  final Employee? employee;
  final Company? company;
  final List<CompanyDirectoryEntry> availableCompanies;
  final bool isLoading;
  final String? error;
  final bool roleJustAssigned;
  final bool areDocumentsValid;
  final Map<String, String>? documentErrors;

  EmployeeState({
    this.employee,
    this.company,
    this.availableCompanies = const [],
    this.isLoading = false,
    this.error,
    this.roleJustAssigned = false,
    this.areDocumentsValid = true,
    this.documentErrors,
  });

  EmployeeState copyWith({
    Object? employee = _employeeStateUnset,
    Object? company = _employeeStateUnset,
    List<CompanyDirectoryEntry>? availableCompanies,
    bool? isLoading,
    Object? error = _employeeStateUnset,
    bool? roleJustAssigned,
    bool? areDocumentsValid,
    Object? documentErrors = _employeeStateUnset,
  }) {
    return EmployeeState(
      employee: identical(employee, _employeeStateUnset)
          ? this.employee
          : employee as Employee?,
      company: identical(company, _employeeStateUnset)
          ? this.company
          : company as Company?,
      availableCompanies: availableCompanies ?? this.availableCompanies,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _employeeStateUnset)
          ? this.error
          : error as String?,
      roleJustAssigned: roleJustAssigned ?? this.roleJustAssigned,
      areDocumentsValid: areDocumentsValid ?? this.areDocumentsValid,
      documentErrors: identical(documentErrors, _employeeStateUnset)
          ? this.documentErrors
          : documentErrors as Map<String, String>?,
    );
  }

  bool get isLinkedToCompany => employee?.companyId != null;
}

class EmployeeNotifier extends StateNotifier<EmployeeState> {
  final EmployeeService _employeeService;
  final CompanyService _companyService;
  final AuthStateNotifier _authStateNotifier;
  late final void Function() _removeAuthListener;

  RealtimeChannel? _employeeChannel;
  bool _roleAssignmentNotificationShown = false;
  String? _lastSyncedEmployeeUserId;

  EmployeeNotifier(
    this._employeeService,
    this._companyService,
    this._authStateNotifier,
  ) : super(EmployeeState()) {
    _removeAuthListener = _authStateNotifier.addListener((authState) {
      unawaited(_handleAuthStateChanged(authState));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _removeAuthListener();
    _employeeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _handleAuthStateChanged(AuthState authState) async {
    final user = authState.user;
    final isEmployeeUser = authState.userType?.isEmployee == true;

    if (user == null || !isEmployeeUser) {
      _lastSyncedEmployeeUserId = null;
      await _employeeChannel?.unsubscribe();
      _employeeChannel = null;
      _roleAssignmentNotificationShown = false;
      state = EmployeeState();
      return;
    }

    final alreadyLoadedForUser = state.employee?.userId == user.id;
    if (state.isLoading ||
        (alreadyLoadedForUser && _lastSyncedEmployeeUserId == user.id)) {
      return;
    }

    _lastSyncedEmployeeUserId = user.id;
    await loadEmployeeProfile(user.id);
    _setupRealtimeSubscription(user.id);
  }

  void _setupRealtimeSubscription(String userId) {
    _employeeChannel?.unsubscribe();

    _employeeChannel = SupabaseConfig.client.channel('employee-$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'employees',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) async => _refreshEmployeeData(userId),
      )
      ..subscribe();
  }

  Future<void> _refreshEmployeeData(String userId) async {
    try {
      final previousEmployee = state.employee;
      final employee = await _employeeService.getEmployeeByUserId(userId);

      Company? company;
      if (employee.companyId != null) {
        company = await _companyService.getCompanyById(employee.companyId!);
      }

      final roleJustAssigned =
          previousEmployee != null &&
          previousEmployee.role == null &&
          employee.role != null &&
          !_roleAssignmentNotificationShown;

      if (roleJustAssigned) {
        _roleAssignmentNotificationShown = true;
      }

      state = state.copyWith(
        employee: employee,
        company: company,
        roleJustAssigned: roleJustAssigned,
      );
    } catch (e) {
      debugPrint('Error refreshing employee data: $e');
    }
  }

  Future<void> loadEmployeeProfile(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final employee = await _employeeService.getEmployeeByUserId(userId);

      Company? company;
      if (employee.companyId != null) {
        company = await _companyService.getCompanyById(employee.companyId!);
      }

      state = state.copyWith(
        employee: employee,
        company: company,
        isLoading: false,
        roleJustAssigned: false,
      );

      if (employee.role != null) {
        _roleAssignmentNotificationShown = true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAvailableCompanies() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final companies = await _companyService.listCompanyDirectory();
      state = state.copyWith(availableCompanies: companies, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool isValidUuid(String input) {
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(input);
  }

  Future<bool> validateCompanyId(String companyId) async {
    if (!isValidUuid(companyId)) {
      state = state.copyWith(
        error: 'Invalid company ID format: must be a valid UUID',
      );
      return false;
    }

    try {
      // P3-43 — this MUST go through the directory RPC, not getCompanyById.
      //
      // This runs BEFORE the employee is linked to anything, so under the
      // scoped `companies` SELECT policy (own company + counterparties +
      // platform admin) a direct read returns zero rows and this reported
      // "Company not found" for every company on the platform — breaking
      // onboarding at exactly the step it is meant to guard. The read after
      // linking is fine and is left alone: current_company_id() resolves off
      // employees.company_id and does not require a role, so a just-linked
      // employee with no role yet can still read their own company.
      final directory = await _companyService.listCompanyDirectory();
      if (directory.any((c) => c.id == companyId)) return true;
      state = state.copyWith(error: 'Company not found: $companyId');
      return false;
    } catch (_) {
      state = state.copyWith(error: 'Company not found: $companyId');
      return false;
    }
  }

  Future<void> linkToCompany(String companyId) async {
    if (state.employee == null) {
      state = state.copyWith(
        error: 'Cannot link to company: Employee profile not loaded',
      );
      return;
    }

    if (state.employee!.companyId != null) {
      state = state.copyWith(
        error:
            'You are already linked to a company. Please contact support if you need to change companies.',
      );
      return;
    }

    final isValid = await validateCompanyId(companyId);
    if (!isValid) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedEmployee = await _employeeService.linkEmployeeToCompany(
        state.employee!.id,
        companyId,
      );
      final company = await _companyService.getCompanyById(companyId);

      state = state.copyWith(
        employee: updatedEmployee,
        company: company,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateEmployeeProfile(Map<String, dynamic> data) async {
    if (state.employee == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final updatedEmployee = await _employeeService.updateEmployeeProfile(
        state.employee!.id,
        data,
      );

      state = state.copyWith(employee: updatedEmployee, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> uploadProfilePhoto(
    List<int> fileBytes,
    String fileName,
  ) async {
    if (state.employee == null) return null;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final photoUrl = await _employeeService.uploadProfilePhoto(
        state.employee!.id,
        Uint8List.fromList(fileBytes),
        fileName,
      );

      state = state.copyWith(
        employee: state.employee!.copyWith(
          profilePhotoUrl: photoUrl,
          updatedAt: DateTime.now(),
        ),
        isLoading: false,
      );

      return photoUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<String?> uploadIdDocument(List<int> fileBytes, String fileName) async {
    if (state.employee == null) return null;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final documentUrl = await _employeeService.uploadIdDocument(
        state.employee!.id,
        Uint8List.fromList(fileBytes),
        fileName,
      );

      state = state.copyWith(
        employee: state.employee!.copyWith(
          idDocumentUrl: documentUrl,
          updatedAt: DateTime.now(),
        ),
        isLoading: false,
      );

      return documentUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<String?> uploadPassportDocument(
    List<int> fileBytes,
    String fileName,
  ) async {
    if (state.employee == null) return null;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final documentUrl = await _employeeService.uploadPassportDocument(
        state.employee!.id,
        Uint8List.fromList(fileBytes),
        fileName,
      );

      state = state.copyWith(
        employee: state.employee!.copyWith(
          passportDocumentUrl: documentUrl,
          updatedAt: DateTime.now(),
        ),
        isLoading: false,
      );

      return documentUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<String?> uploadWorkVisaDocument(
    List<int> fileBytes,
    String fileName,
  ) async {
    if (state.employee == null) return null;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final documentUrl = await _employeeService.uploadWorkVisaDocument(
        state.employee!.id,
        Uint8List.fromList(fileBytes),
        fileName,
      );

      state = state.copyWith(
        employee: state.employee!.copyWith(
          workVisaDocumentUrl: documentUrl,
          updatedAt: DateTime.now(),
        ),
        isLoading: false,
      );

      return documentUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<String?> uploadLicenseDocument(
    List<int> fileBytes,
    String fileName,
  ) async {
    if (state.employee == null) return null;

    try {
      state = state.copyWith(isLoading: true, error: null);
      final documentUrl = await _employeeService.uploadLicenseDocument(
        state.employee!.id,
        Uint8List.fromList(fileBytes),
        fileName,
      );

      state = state.copyWith(
        employee: state.employee!.copyWith(
          licenseDocumentUrl: documentUrl,
          updatedAt: DateTime.now(),
        ),
        isLoading: false,
      );

      return documentUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> validateDocuments() async {
    if (state.employee == null) return false;

    final documentErrors = <String, String>{};
    var areDocumentsValid = true;

    if (state.employee!.isSouthAfricanCitizen) {
      if (state.employee!.idDocumentUrl == null ||
          state.employee!.idDocumentUrl!.isEmpty) {
        documentErrors['idDocument'] =
            'South African citizens must upload an ID document';
        areDocumentsValid = false;
      }
    } else {
      if (state.employee!.passportDocumentUrl == null ||
          state.employee!.passportDocumentUrl!.isEmpty) {
        documentErrors['passportDocument'] =
            'Non-South African citizens must upload a passport';
        areDocumentsValid = false;
      }

      if (state.employee!.workVisaDocumentUrl == null ||
          state.employee!.workVisaDocumentUrl!.isEmpty) {
        documentErrors['workVisaDocument'] =
            'Non-South African citizens must upload a work visa or permit';
        areDocumentsValid = false;
      }
    }

    if (state.employee!.role?.name == 'driver' &&
        (state.employee!.licenseDocumentUrl == null ||
            state.employee!.licenseDocumentUrl!.isEmpty)) {
      documentErrors['licenseDocument'] =
          'Drivers must upload a valid driver\'s license';
      areDocumentsValid = false;
    }

    state = state.copyWith(
      areDocumentsValid: areDocumentsValid,
      documentErrors: documentErrors.isEmpty ? null : documentErrors,
    );

    return areDocumentsValid;
  }
}

final employeeProvider = StateNotifierProvider<EmployeeNotifier, EmployeeState>(
  (ref) {
    return EmployeeNotifier(
      ref.watch(employeeServiceProvider),
      ref.watch(companyServiceProvider),
      ref.watch(authStateProvider.notifier),
    );
  },
);

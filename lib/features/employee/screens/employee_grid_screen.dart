import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/mcp/models/employee_model.dart';
import 'package:flutter_application_1/core/mcp/repositories/employee_repository.dart';
import 'package:flutter_application_1/core/widgets/infinite_grid.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for the employee repository
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository();
});

/// Provider for the list of employees by company ID
final employeesByCompanyProvider =
    FutureProvider.family<List<EmployeeMCP>, String>((ref, companyId) async {
      final repository = ref.watch(employeeRepositoryProvider);
      return repository.getByCompanyId(companyId);
    });

/// A screen that displays a grid of employees for a company
class EmployeeGridScreen extends ConsumerWidget {
  final String companyId;
  final String companyName;

  const EmployeeGridScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('$companyName Employees')),
      body: _buildEmployeeGrid(context, ref),
    );
  }

  Widget _buildEmployeeGrid(BuildContext context, WidgetRef ref) {
    return InfiniteGrid<EmployeeMCP>(
      fetchItems: (pageKey, pageSize) async {
        final repository = ref.read(employeeRepositoryProvider);
        return repository.getByCompanyId(
          companyId,
          orderBy: 'first_name',
          ascending: true,
          limit: pageSize,
          offset: pageKey * pageSize,
        );
      },
      itemBuilder: (context, employee, index) {
        return _buildEmployeeItem(context, employee);
      },
      emptyWidget: const MlEmptyState(
        icon: Icons.people_outline,
        title: 'No employees found',
        message: 'No employees are registered for this company yet.',
      ),
      crossAxisCount: 2,
      childAspectRatio: 0.8,
      padding: const EdgeInsets.all(16),
    );
  }

  Widget _buildEmployeeItem(BuildContext context, EmployeeMCP employee) {
    final semantic = MlSemantic.of(context);
    final roleTone = _roleTone(employee.role);
    final roleLabel = _getRoleLabel(employee.role);
    final placeholderBg = MlTone.accent.well(Theme.of(context).brightness);

    return MlCard(
      padding: EdgeInsets.zero,
      onTap: () {
        // companyId on the model is nullable; the grid screen already has
        // the non-null companyId in scope, so prefer that.
        final companyIdForRoute = employee.companyId ?? companyId;
        context.push(
          '/employees/$companyIdForRoute/${employee.id}/details',
          extra: employee,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Employee photo
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo or placeholder
                employee.profilePhotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: employee.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: placeholderBg,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: placeholderBg,
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: MlTokens.accent,
                          ),
                        ),
                      )
                    : Container(
                        color: placeholderBg,
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: MlTokens.accent,
                        ),
                      ),

                // Role badge
                if (employee.role != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: MlStatusBadge(label: roleLabel, tone: roleTone),
                  ),
              ],
            ),
          ),

          // Employee info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: context.mlText.titleMedium.copyWith(
                      color: semantic.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.whatsappNumber,
                    style: context.mlText.code(
                      color: semantic.textMuted,
                      size: 13,
                      weight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  MlTone _roleTone(UserRole? role) {
    if (role == null) return MlTone.neutral;

    switch (role) {
      case UserRole.admin:
        return MlTone.accent;
      case UserRole.management:
        return MlTone.transit;
      case UserRole.security:
        return MlTone.error;
      case UserRole.controllerWB:
        return MlTone.warn;
      case UserRole.supervisorForeman:
        return MlTone.accent;
      case UserRole.driver:
        return MlTone.done;
      default:
        return MlTone.neutral;
    }
  }

  String _getRoleLabel(UserRole? role) {
    return role?.label ?? 'No Role';
  }
}

/// A screen that displays the details of an employee
class EmployeeDetailsScreen extends StatelessWidget {
  final EmployeeMCP employee;

  const EmployeeDetailsScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(employee.fullName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee photo
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: MlTone.accent.well(
                  Theme.of(context).brightness,
                ),
                backgroundImage: employee.profilePhotoUrl != null
                    ? CachedNetworkImageProvider(employee.profilePhotoUrl!)
                    : null,
                child: employee.profilePhotoUrl == null
                    ? const Icon(Icons.person, size: 60, color: MlTokens.accent)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // Employee information
            MlSectionTitle(
              'Employee Information',
              icon: Icons.badge_outlined,
              // Status, not a count. Whether this employee is active is what
              // decides if they hold a seat and can sign in at all (S4), and
              // it is the one field the rows below do not spell out.
              meta: employee.status,
            ),
            _buildInfoItem(context, 'Name', employee.fullName),
            _buildInfoItem(context, 'WhatsApp Number', employee.whatsappNumber),
            if (employee.role != null)
              _buildInfoItem(context, 'Role', _getRoleLabel(employee.role!)),
            _buildInfoItem(
              context,
              'Created At',
              _formatDate(employee.createdAt),
            ),
            if (employee.updatedAt != null)
              _buildInfoItem(
                context,
                'Last Updated',
                _formatDate(employee.updatedAt!),
              ),

            // Documents section
            if (_hasDocuments(employee))
              _buildDocumentsSection(context, employee),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.mlText.titleSmall.copyWith(
                color: semantic.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.mlText.titleMedium.copyWith(
                color: semantic.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(BuildContext context, EmployeeMCP employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        MlSectionTitle('Documents',
            icon: Icons.folder_outlined,
            meta: mlCount(
              [
                employee.idDocumentUrl,
                employee.passportDocumentUrl,
                employee.workVisaDocumentUrl,
                employee.licenseDocumentUrl,
              ].whereType<String>().length,
              'file',
            )),
        if (employee.idDocumentUrl != null)
          _buildDocumentItem(context, 'ID Document', employee.idDocumentUrl!),
        if (employee.passportDocumentUrl != null)
          _buildDocumentItem(
            context,
            'Passport',
            employee.passportDocumentUrl!,
          ),
        if (employee.workVisaDocumentUrl != null)
          _buildDocumentItem(
            context,
            'Work Visa',
            employee.workVisaDocumentUrl!,
          ),
        if (employee.licenseDocumentUrl != null)
          _buildDocumentItem(
            context,
            'Driver\'s License',
            employee.licenseDocumentUrl!,
          ),
      ],
    );
  }

  Widget _buildDocumentItem(BuildContext context, String label, String url) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.mlText.titleSmall.copyWith(
                color: semantic.textMuted,
              ),
            ),
          ),
          MlButton.tonal(
            label: 'View Document',
            icon: Icons.visibility_outlined,
            compact: true,
            onPressed: () {
              // Open document viewer
            },
          ),
        ],
      ),
    );
  }

  bool _hasDocuments(EmployeeMCP employee) {
    return employee.idDocumentUrl != null ||
        employee.passportDocumentUrl != null ||
        employee.workVisaDocumentUrl != null ||
        employee.licenseDocumentUrl != null;
  }

  String _getRoleLabel(UserRole role) {
    return role.label;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Loader screen used when the employee details route is opened via a deep
/// link (no `extra`). Fetches the employee by id, then renders
/// [EmployeeDetailsScreen]. Shown briefly during navigation; tapping from the
/// grid passes the model directly and skips the fetch.
class EmployeeDetailsLoaderScreen extends ConsumerWidget {
  final String employeeId;

  const EmployeeDetailsLoaderScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(employeeRepositoryProvider);
    return FutureBuilder<EmployeeMCP>(
      future: repository.getById(employeeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Employee')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? 'Failed to load employee:\n${snapshot.error}'
                      : 'Employee not found',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return EmployeeDetailsScreen(employee: snapshot.data!);
      },
    );
  }
}

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:async';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/company/widgets/company_employee_form_dialog.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/company/widgets/seat_limit_dialog.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:go_router/go_router.dart';

class CompanyEmployeesScreen extends ConsumerStatefulWidget {
  const CompanyEmployeesScreen({super.key});

  @override
  ConsumerState<CompanyEmployeesScreen> createState() =>
      _CompanyEmployeesScreenState();
}

class _CompanyEmployeesScreenState
    extends ConsumerState<CompanyEmployeesScreen> {
  /// Resolved the same way `build` resolves it, so the seat-request dialog
  /// asks on behalf of the company actually on screen.
  String? get _companyId =>
      ref.read(companyProvider).company?.id ??
      ref.read(companyAccessProvider).company?.id;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companyProvider);
    final access = ref.watch(companyAccessProvider);
    final company = state.company ?? access.company;

    if (access.canManageEmployees &&
        (state.company == null || state.company?.id != company?.id)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (company == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // NO `Scaffold(appBar:)` — this screen is a leaf of the portal
    // `ShellRoute`, whose top bar already carries the section name, so its own
    // bar put "Company Employees" on screen twice.
    if (!access.canManageEmployees) {
      return _buildRestrictedState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: MlPageHeader(
            title: 'Company employees',
            description: 'Everyone with a login under this company.',
            meta: mlCount(state.employees.length, 'user'),
            actions: [
              MlButton.primary(
                label: 'Add user',
                icon: Icons.person_add_alt_1,
                compact: true,
                onPressed: () =>
                    _showCreateUserDialog(context, company.orgType),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: MlTokens.accent,
                    size: 50,
                  ),
                )
              : state.employees.isEmpty
                  ? _buildEmptyState(context, company.orgType)
                  : _buildEmployeeList(state.employees, company.orgType),
        ),
      ],
    );
  }

  Widget _buildRestrictedState(BuildContext context) {
    return const MlEmptyState(
      icon: Icons.lock_outline,
      title: 'Management access required',
      message:
          'Only company owners, admins, and management can add, edit, or remove company users.',
    );
  }

  Future<T> _runWithLoadingDialog<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    late BuildContext dialogContext;

    // Never awaited: this future completes only when the barrier is popped in
    // the `finally` below, so awaiting it here would deadlock the action.
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (innerContext) {
        dialogContext = innerContext;
        return const Center(child: CircularProgressIndicator());
      },
    ));

    try {
      return await action();
    } finally {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    }
  }

  /// A confirmation or failure notice.
  ///
  /// [tone] is a semantic tone, not a colour: `MlTone.done` for a completed
  /// action, `MlTone.error` for one the server refused, and nothing at all for
  /// a plain statement of fact. It was `required Color backgroundColor` and
  /// every caller passed `Colors.green`, `Colors.red` or `Colors.blueGrey` —
  /// three Material colours that do not move between themes and are not in the
  /// design system (docs/design-reference.md §5).
  void _showSnackBar(
    BuildContext context,
    String message, {
    MlTone? tone,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: tone?.colors(Theme.of(context).brightness).fg,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showCreateUserDialog(
    BuildContext context,
    OrgType orgType,
  ) async {
    final result = await showDialog<CompanyEmployeeFormResult>(
      context: context,
      builder: (dialogContext) => CompanyEmployeeFormDialog(orgType: orgType),
    );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await _runWithLoadingDialog(context, () async {
        await ref
            .read(companyProvider.notifier)
            .createManagedEmployee(
              email: result.email,
              password: result.password,
              firstName: result.firstName,
              lastName: result.lastName,
              whatsappNumber: result.whatsappNumber,
              role: result.role,
            );
      });

      if (context.mounted) {
        _showSnackBar(
          context,
          '${result.firstName} ${result.lastName} was added as ${result.role.label}.',
          tone: MlTone.done,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      // The seat gate is a dead end without a way forward — offer the
      // seat request instead of a snackbar (client ruling 2026-08-15).
      if (await handleSeatLimitError(
        context,
        ref,
        error,
        companyId: _companyId,
      )) {
        return;
      }
      if (context.mounted) {
        _showSnackBar(
          context,
          friendlyError(error),
          tone: MlTone.error,
        );
      }
    }
  }

  Future<void> _showEditUserDialog(
    BuildContext context,
    Employee employee,
    OrgType orgType,
  ) async {
    final result = await showDialog<CompanyEmployeeFormResult>(
      context: context,
      builder: (dialogContext) =>
          CompanyEmployeeFormDialog(orgType: orgType, employee: employee),
    );

    if (result == null || !context.mounted) {
      return;
    }

    final hasChanges =
        result.firstName != employee.firstName ||
        result.lastName != employee.lastName ||
        result.whatsappNumber != employee.whatsappNumber ||
        result.role != employee.role;

    if (!hasChanges) {
      _showSnackBar(
        context,
        'No changes to save.',
      );
      return;
    }

    try {
      await _runWithLoadingDialog(context, () async {
        await ref
            .read(companyProvider.notifier)
            .updateEmployeeDetails(
              employee: employee,
              firstName: result.firstName,
              lastName: result.lastName,
              whatsappNumber: result.whatsappNumber,
              role: result.role,
            );
      });

      if (context.mounted) {
        _showSnackBar(
          context,
          '${employee.fullName} was updated successfully.',
          tone: MlTone.done,
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showSnackBar(
          context,
          friendlyError(error),
          tone: MlTone.error,
        );
      }
    }
  }

  void _showRemoveConfirmationDialog(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove user'),
        content: Text(
          'Remove ${employee.fullName} from this company? This will remove their role and company access, but it will not delete their auth account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  MlTone.error.colors(Theme.of(context).brightness).fg,
              foregroundColor: MlTokens.inkOnFill,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              try {
                await _runWithLoadingDialog(context, () async {
                  await ref
                      .read(companyProvider.notifier)
                      .removeEmployee(employee.id);
                });

                if (context.mounted) {
                  _showSnackBar(
                    context,
                    '${employee.fullName} was removed from the company.',
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    friendlyError(error),
                    tone: MlTone.error,
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _employeeStatusLabel(Employee employee) {
    if (employee.status == 'pending_company') {
      return 'Pending approval';
    } else if (employee.status == 'pending_role' && employee.role == null) {
      return 'Accepted · no role';
    } else if (employee.status == 'rejected') {
      return 'Request declined';
    } else if (employee.role != null) {
      return employee.role!.label;
    }

    return 'Unknown';
  }

  MlTone _employeeStatusTone(Employee employee) {
    if (employee.status == 'pending_company') {
      return MlTone.warn;
    } else if (employee.status == 'pending_role' && employee.role == null) {
      return MlTone.transit;
    } else if (employee.status == 'rejected') {
      return MlTone.error;
    } else if (employee.role != null) {
      return MlTone.done;
    }

    return MlTone.neutral;
  }

  Widget _buildEmptyState(BuildContext context, OrgType orgType) {
    return MlEmptyState(
      icon: Icons.people_outline,
      title: 'No employees found',
      message: "Your company doesn't have any employees yet.",
      action: MlButton.primary(
        label: 'Add user',
        icon: Icons.person_add_alt_1,
        onPressed: () => _showCreateUserDialog(context, orgType),
      ),
    );
  }

  void _showAcceptConfirmationDialog(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept employee request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do you want to accept ${employee.fullName} as an employee?'),
            const SizedBox(height: 16),
            Text(
              'The employee will be accepted without a role. You will need to assign a role separately.',
              style: context.mlText.bodyMedium.copyWith(
                color: MlSemantic.of(context).textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The employee cannot use the app until a role is assigned.',
              style: context.mlText.titleSmall.copyWith(
                color: MlTone.warn.colors(Theme.of(context).brightness).fg,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  MlTone.done.colors(Theme.of(context).brightness).fg,
              foregroundColor: MlTokens.inkOnFill,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              try {
                await _runWithLoadingDialog(context, () async {
                  await ref
                      .read(companyProvider.notifier)
                      .acceptEmployeeRequest(employee.id);
                });

                if (context.mounted) {
                  _showSnackBar(
                    context,
                    '${employee.fullName}\'s request has been accepted. Please assign a role.',
                    tone: MlTone.done,
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    friendlyError(error),
                    tone: MlTone.error,
                  );
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRoleChangeConfirmationDialog(
    BuildContext context,
    Employee employee,
    UserRole? currentRole,
    UserRole newRole,
  ) {
    final currentRoleText = currentRole != null ? currentRole.label : 'None';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm role change'),
        content: Text(
          'Change ${employee.fullName}\'s role from $currentRoleText to ${newRole.label}. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              try {
                await _runWithLoadingDialog(context, () async {
                  await ref
                      .read(companyProvider.notifier)
                      .assignRoleToEmployee(employee.id, newRole);
                });

                if (context.mounted) {
                  _showSnackBar(
                    context,
                    '${employee.fullName}\'s role has been updated to ${newRole.label}.',
                    tone: MlTone.done,
                  );
                }
              } catch (error) {
                if (!context.mounted) return;
                // Activating a pending_role employee takes a seat, so this
                // path hits the same gate as adding one outright.
                if (await handleSeatLimitError(
                  context,
                  ref,
                  error,
                  companyId: _companyId,
                )) {
                  return;
                }
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    friendlyError(error),
                    tone: MlTone.error,
                  );
                }
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showDeclineConfirmationDialog(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline request'),
        content: Text(
          'Are you sure you want to decline ${employee.fullName}\'s request to join your company? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  MlTone.error.colors(Theme.of(context).brightness).fg,
              foregroundColor: MlTokens.inkOnFill,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              try {
                await _runWithLoadingDialog(context, () async {
                  await ref
                      .read(companyProvider.notifier)
                      .declineEmployeeRequest(employee.id);
                });

                if (context.mounted) {
                  _showSnackBar(
                    context,
                    '${employee.fullName}\'s request has been declined.',
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    friendlyError(error),
                    tone: MlTone.error,
                  );
                }
              }
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  // "Dismiss Employee" and its dialog were removed with the dismissal feature
  // (client ruling, 2026-08-11). "Remove User" below is the supported way to
  // take someone off a company — it unassigns their fleet vehicles, unlinks
  // them and notifies both sides, via `remove_company_employee`.
  Widget _buildManagementButtons(
    BuildContext context,
    Employee employee,
    OrgType orgType,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MlButton.tonal(
          label: 'Edit user',
          icon: Icons.edit_outlined,
          compact: true,
          onPressed: () => _showEditUserDialog(context, employee, orgType),
        ),
        MlButton.outline(
          label: 'Remove user',
          icon: Icons.person_remove_alt_1_outlined,
          compact: true,
          onPressed: () => _showRemoveConfirmationDialog(context, employee),
        ),
      ],
    );
  }

  Widget _buildRoleChip(
    BuildContext context, {
    required UserRole role,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    final semantic = MlSemantic.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(MlTokens.rPill),
      onTap: () => onSelected(!isSelected),
      child: Container(
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? MlTokens.accent : semantic.surfaceCard,
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: Border.all(
            color: isSelected ? MlTokens.accent : semantic.borderStrong,
          ),
        ),
        child: Text(
          role.label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: context.mlText.titleSmall.copyWith(
            color: isSelected ? MlTokens.inkOnAccent : semantic.textBody,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeActionSection(
    BuildContext context,
    Employee employee,
    OrgType orgType,
  ) {
    final isPending = employee.status == 'pending_company';
    final isAcceptedNoRole =
        employee.status == 'pending_role' && employee.role == null;
    final hasRole = employee.role != null;

    if (isPending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Pending request',
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: MlTokens.orange700,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MlButton.go(
                    label: 'Accept',
                    icon: Icons.check,
                    compact: true,
                    onPressed: () =>
                        _showAcceptConfirmationDialog(context, employee),
                  ),
                  MlButton.danger(
                    label: 'Decline',
                    icon: Icons.close,
                    compact: true,
                    onPressed: () =>
                        _showDeclineConfirmationDialog(context, employee),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    } else if (isAcceptedNoRole) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accepted - Assign Role',
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: MlTokens.blue600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This employee has been accepted but cannot use the app until assigned a role.',
            style: context.mlText.bodyMedium.copyWith(
              color: MlSemantic.of(context).textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _buildManagementButtons(context, employee, orgType),
          const SizedBox(height: 12),
          Text(
            'Select role:',
            style: context.mlText.titleSmall.copyWith(
              color: MlSemantic.of(context).textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRole.getRolesForOrgType(orgType).map((role) {
              return _buildRoleChip(
                context,
                role: role,
                isSelected: false,
                onSelected: (selected) {
                  if (selected) {
                    _showRoleChangeConfirmationDialog(
                      context,
                      employee,
                      null,
                      role,
                    );
                  }
                },
              );
            }).toList(),
          ),
        ],
      );
    } else if (hasRole) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage user and role',
            style: context.mlText.titleMedium.copyWith(
              color: MlSemantic.of(context).textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildManagementButtons(context, employee, orgType),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRole.getRolesForOrgType(orgType).map((role) {
              final isSelected = employee.role == role;
              return _buildRoleChip(
                context,
                role: role,
                isSelected: isSelected,
                onSelected: (selected) {
                  if (selected && employee.role != role) {
                    _showRoleChangeConfirmationDialog(
                      context,
                      employee,
                      employee.role,
                      role,
                    );
                  }
                },
              );
            }).toList(),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unknown employee status'),
          const SizedBox(height: 12),
          _buildManagementButtons(context, employee, orgType),
        ],
      );
    }
  }

  // ===== Employee Register (design ref: minelink-design-system
  // ui_kits/shared/employee-register.jsx, requested 2026-07-15) =====
  //
  // Role-grouped editorial directory populated with REAL data only: tenure is
  // derived from the join date, badges from real documents/citizenship, and
  // the presence dot from the employee's actual account status — never
  // fabricated metrics. Tapping a row expands the full, unchanged management
  // section (accept/decline, role chips, edit/remove), so nothing is lost.

  static const _roleGroupOrder = <UserRole, (IconData, String)>{
    UserRole.supervisorForeman: (
      Icons.groups_outlined,
      'Full operational access — stockpiles and loading oversight.',
    ),
    UserRole.controllerWB: (
      Icons.tune_rounded,
      'Load control only — tare/gross weighs, seals & waybill slips.',
    ),
    UserRole.security: (
      Icons.shield_outlined,
      'Gate checks only — mark trucks arrived & departed.',
    ),
    UserRole.driver: (
      Icons.badge_outlined,
      'Trips, navigation & POD upload (mobile).',
    ),
    UserRole.admin: (
      Icons.calendar_month_outlined,
      'Full company administration — billing, roster and permissions.',
    ),
    UserRole.management: (
      Icons.workspace_premium_outlined,
      'Company management — oversight and approvals.',
    ),
  };

  String _tenureLabel(Employee e) {
    final months = DateTime.now().difference(e.createdAt).inDays ~/ 30;
    if (months < 1) return 'New this month';
    if (months < 12) return '$months mo tenure';
    final y = months ~/ 12, m = months % 12;
    return m == 0 ? '${y}y tenure' : '${y}y ${m}mo tenure';
  }

  int _docCount(Employee e) => [
        e.idDocumentUrl,
        e.passportDocumentUrl,
        e.workVisaDocumentUrl,
        e.licenseDocumentUrl,
      ].where((d) => d != null && d.isNotEmpty).length;

  /// Reference-style mono employee id: role prefix + a stable short tail of
  /// the real row id (e.g. `SUP-4F2A`). Derived, not invented.
  String _empCode(Employee e) {
    final prefix = switch (e.role) {
      UserRole.supervisorForeman => 'SUP',
      UserRole.controllerWB => 'LC',
      UserRole.security => 'SG',
      UserRole.driver => 'DRV',
      UserRole.admin => 'ADM',
      UserRole.management => 'MGT',
      _ => 'EMP',
    };
    final tail = e.id.replaceAll('-', '').toUpperCase();
    return '$prefix-${tail.substring(0, tail.length < 4 ? tail.length : 4)}';
  }

  MlTone _groupTone(UserRole role) => switch (role) {
        UserRole.supervisorForeman => MlTone.transit,
        UserRole.controllerWB => MlTone.accent,
        UserRole.security => MlTone.atMine,
        UserRole.driver => MlTone.done,
        UserRole.admin => MlTone.done,
        UserRole.management => MlTone.transit,
        _ => MlTone.neutral,
      };

  Widget _buildEmployeeList(List<Employee> employees, OrgType orgType) {
    final semantic = MlSemantic.of(context);
    // The dismissed group and its `!e.isDismissed` guards went with the
    // dismissal feature (client ruling, 2026-08-11). `is_dismissed` survives as
    // a permanently-false column — 19 functions and the `chat_directory` view
    // read it — but nothing can set it any more, so grouping on it would only
    // ever produce an empty section.
    final active =
        employees.where((e) => e.role != null).toList(growable: false);
    final pending = employees
        .where((e) => e.status == 'pending_company')
        .toList(growable: false);
    final awaitingRole = employees
        .where((e) => e.status == 'pending_role' && e.role == null)
        .toList(growable: false);
    // "Other" also catches an ACTIVE employee whose role is not one this
    // org type has. The role groups below iterate `getRolesForOrgType`, so
    // a weighbridge controller at a transporter matched no group — and
    // `other` only caught `role == null` — so he was counted in "3 PEOPLE ·
    // 3 ACTIVE" and drawn nowhere. An employee who silently vanishes from
    // the register is the worst outcome a register can have; an unusual
    // state is what this group is for. Phase 3 mine pass, 2026-08-23.
    final orgRoles = UserRole.getRolesForOrgType(orgType).toSet();
    final other = employees
        .where((e) =>
            (e.role == null &&
                e.status != 'pending_company' &&
                !(e.status == 'pending_role')) ||
            (e.role != null && !orgRoles.contains(e.role)))
        .toList(growable: false);

    final sections = <Widget>[
      // Editorial header — "Company · Directory" kicker + live counts.
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          'DIRECTORY',
          style: context.mlText.code(
            color: semantic.textFaint,
            size: 11,
            weight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
      ),
      Text(
        'Employee register',
        style: context.mlText.editorialLarge.copyWith(
          color: semantic.textStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        MlStatusBadge(label: '${employees.length} PEOPLE', tone: MlTone.neutral),
        MlStatusBadge(label: '${active.length} ACTIVE', tone: MlTone.done),
        if (pending.isNotEmpty)
          MlStatusBadge(
              label: '${pending.length} PENDING', tone: MlTone.atMine),
        if (awaitingRole.isNotEmpty)
          MlStatusBadge(
              label: '${awaitingRole.length} AWAITING ROLE',
              tone: MlTone.transit),
      ]),
      const SizedBox(height: 18),
    ];

    void addGroup({
      required IconData icon,
      required String label,
      required String desc,
      required MlTone tone,
      required List<Employee> people,
      bool startExpanded = false,
    }) {
      if (people.isEmpty) return;
      sections
        ..add(_RegisterGroup(
          icon: icon,
          label: label,
          desc: desc,
          tone: tone,
          people: people,
          orgType: orgType,
          startExpanded: startExpanded,
          tenureLabel: _tenureLabel,
          docCount: _docCount,
          empCode: _empCode,
          statusLabel: _employeeStatusLabel,
          statusTone: _employeeStatusTone,
          actionSection: (e) => _buildEmployeeActionSection(context, e, orgType),
        ))
        ..add(const SizedBox(height: 14));
    }

    // Action-needed groups first — expanded so approvals stay one tap away.
    addGroup(
      icon: Icons.mark_email_unread_outlined,
      label: 'Pending requests',
      desc: 'People asking to join — accept or decline.',
      tone: MlTone.atMine,
      people: pending,
      startExpanded: true,
    );
    addGroup(
      icon: Icons.assignment_ind_outlined,
      label: 'Awaiting role',
      desc: 'Accepted, but locked out until a role is assigned.',
      tone: MlTone.transit,
      people: awaitingRole,
      startExpanded: true,
    );

    for (final role in UserRole.getRolesForOrgType(orgType)) {
      final meta = _roleGroupOrder[role];
      addGroup(
        icon: meta?.$1 ?? Icons.person_outline,
        label: '${role.label}s',
        desc: meta?.$2 ?? '',
        tone: _groupTone(role),
        people: active.where((e) => e.role == role).toList(growable: false),
      );
    }
    addGroup(
      icon: Icons.person_outline,
      label: 'Other',
      desc: 'Accounts in an unusual state.',
      tone: MlTone.neutral,
      people: other,
    );

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: sections,
    );
  }
}

/// One role group of the register: header (icon well, label · count,
/// permission description) + editorial person rows. Rows expand in place to
/// the full management section.
class _RegisterGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final MlTone tone;
  final List<Employee> people;
  final OrgType orgType;
  final bool startExpanded;
  final String Function(Employee) tenureLabel;
  final int Function(Employee) docCount;
  final String Function(Employee) empCode;
  final String Function(Employee) statusLabel;
  final MlTone Function(Employee) statusTone;
  final Widget Function(Employee) actionSection;

  const _RegisterGroup({
    required this.icon,
    required this.label,
    required this.desc,
    required this.tone,
    required this.people,
    required this.orgType,
    required this.startExpanded,
    required this.tenureLabel,
    required this.docCount,
    required this.empCode,
    required this.statusLabel,
    required this.statusTone,
    required this.actionSection,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            MlIconWell(icon: icon, tone: tone, size: 36, radius: 10),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.titleMedium.copyWith(
                          color: semantic.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${people.length}',
                      style: context.mlText.code(
                        color: semantic.textFaint,
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ]),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(
                        color: semantic.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          for (var i = 0; i < people.length; i++) ...[
            if (i > 0) Divider(height: 1, color: semantic.divider),
            _RegisterRow(
              employee: people[i],
              tone: tone,
              orgType: orgType,
              startExpanded: startExpanded,
              tenure: tenureLabel(people[i]),
              docs: docCount(people[i]),
              code: empCode(people[i]),
              statusLabel: statusLabel(people[i]),
              statusTone: statusTone(people[i]),
              actionSection: actionSection,
            ),
          ],
        ],
      ),
    );
  }
}

class _RegisterRow extends StatefulWidget {
  final Employee employee;
  final MlTone tone;
  final OrgType orgType;
  final bool startExpanded;
  final String tenure;
  final int docs;
  final String code;
  final String statusLabel;
  final MlTone statusTone;
  final Widget Function(Employee) actionSection;

  const _RegisterRow({
    required this.employee,
    required this.tone,
    required this.orgType,
    required this.startExpanded,
    required this.tenure,
    required this.docs,
    required this.code,
    required this.statusLabel,
    required this.statusTone,
    required this.actionSection,
  });

  @override
  State<_RegisterRow> createState() => _RegisterRowState();
}

class _RegisterRowState extends State<_RegisterRow> {
  late bool _open = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final e = widget.employee;
    final toneColors = widget.tone.colors(brightness);
    final initials = e.fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    // Presence-style dot from the REAL account state (never fabricated):
    // green = active with a role, amber = pending a role.
    final dotColor = e.role != null
        ? MlTone.done.colors(brightness).fg
        : MlTone.atMine.colors(brightness).fg;

    final avatar = Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.tone.well(brightness),
          borderRadius: MlShape.radiusMedium,
          image: e.profilePhotoUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(e.profilePhotoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: e.profilePhotoUrl == null
            ? Text(
                initials,
                style: context.mlText.titleSmall.copyWith(
                  color: toneColors.fg,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
      Positioned(
        left: -2,
        bottom: -2,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: semantic.surfaceCard, width: 2.5),
          ),
        ),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          // Row tap → the full live profile; the trailing chevron still
          // expands the in-place management section (accept/role/remove).
          onTap: () => context.push(
            '/portal/${portalOrgSegment(widget.orgType)}/employees/${e.id}',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          e.fullName,
                          style: context.mlText.titleMedium.copyWith(
                            color: semantic.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: semantic.surfaceApp,
                            border: Border.all(color: semantic.divider),
                            borderRadius: MlShape.radiusSmall,
                          ),
                          child: Text(
                            widget.code,
                            style: context.mlText.code(
                              color: semantic.textFaint,
                              size: 11,
                              weight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        MlStatusBadge(
                            label: widget.statusLabel, tone: widget.statusTone),
                        _SetupProgressChip(employeeId: e.id),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (e.role != null) e.role!.label,
                        e.whatsappNumber,
                        widget.tenure,
                        if (widget.docs > 0)
                          '${widget.docs} doc${widget.docs == 1 ? '' : 's'}',
                        if (e.idNumber != null && e.idNumber!.isNotEmpty)
                          'ID on file'
                        else if (e.passportOrWorkersPermit != null &&
                            e.passportOrWorkersPermit!.isNotEmpty)
                          'Passport/permit on file',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.code(
                        color: semantic.textMuted,
                        size: 11,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _open ? 'Hide management' : 'Manage user & role',
                child: InkWell(
                  borderRadius: MlShape.radiusSmall,
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: semantic.textFaint,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: MlTokens.durBase,
          firstCurve: MlTokens.easeOutCubic,
          secondCurve: MlTokens.easeOutCubic,
          sizeCurve: MlTokens.easeOutCubic,
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
            child: widget.actionSection(e),
          ),
        ),
      ],
    );
  }
}

/// Small register-row chip flagging an employee whose account setup still has
/// required items missing or expired documents. Renders nothing while loading,
/// on error, or when the profile is in good standing.
class _SetupProgressChip extends ConsumerWidget {
  const _SetupProgressChip({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup =
        ref.watch(employeeProfileSetupProvider(employeeId)).valueOrNull;
    if (setup == null || !setup.isApplicable) return const SizedBox.shrink();
    final s = setup.summary;
    if (!s.hasOutstandingRequired && s.expiringCount == 0) {
      return const SizedBox.shrink();
    }
    return MlStatusBadge(
      label: s.hasOutstandingRequired
          ? 'Setup ${s.completionPercent}%'
          : 'Renewals due',
      tone: s.expiredCount > 0 ? MlTone.error : MlTone.warn,
    );
  }
}

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/widgets/m3_dropdown_field.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/operations/providers/operations_provider.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The hub's one-line description, naming only the tabs this session sees:
/// a guard's page used to promise "minerals, transactions, the weighbridge,
/// loads" above two tabs.
@visibleForTesting
String operationsHubDescription(List<OperationsTab> tabs) {
  final names = [for (final t in tabs) t.label.toLowerCase()];
  if (names.isEmpty) return 'The live working day.';
  final list = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return 'The live working day — $list.';
}

class OperationsHubScreen extends ConsumerWidget {
  final String? initialTabId;
  /// When set (super-admin mirror), loads operations for this company read-only.
  final Company? observedCompany;

  const OperationsHubScreen({
    super.key,
    this.initialTabId,
    this.observedCompany,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final companyState = ref.watch(companyProvider);
    final employeeState = ref.watch(employeeProvider);
    final access = observedCompany != null && authState.user != null
        ? _OperationsAccess.superAdminObserver(
            userId: authState.user!.id,
            company: observedCompany!,
          )
        : _OperationsAccess.fromState(
            authStateUserId: authState.user?.id,
            userType: authState.userType,
            company: companyState.company,
            employeeCompany: employeeState.company,
            employee: employeeState.employee,
          );

    if (authState.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // NO `Scaffold(appBar:)` — `/operations` is a leaf of the portal
    // `ShellRoute`, whose top bar already carries the section name, so its own
    // bar printed "Operations Hub" a second time directly underneath.
    if (access == null) {
      return const _OperationsEmptyState(
        icon: Icons.factory_outlined,
        title: 'Operations are not available yet',
        message:
            'Link to a company or finish loading your company profile to unlock the live operations workspace.',
      );
    }

    final visibleTabs = access.visibleTabs;
    final initialIndex = _initialIndexForTab(visibleTabs, initialTabId);
    final operationsState = ref.watch(
      operationsProvider(
        OperationsScope(
          companyId: access.company.id,
          userId: access.userId,
          orgType: access.company.orgType,
        ),
      ),
    );
    final operationsNotifier = ref.read(
      operationsProvider(
        OperationsScope(
          companyId: access.company.id,
          userId: access.userId,
          orgType: access.company.orgType,
        ),
      ).notifier,
    );

    return DefaultTabController(
      length: visibleTabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        primary: observedCompany == null,
        backgroundColor: Colors.transparent,
        body: Column(
          // See the same note on the communications hub: a Column centres its
          // children and sizes each to its own content, so this hero card
          // floated mid-page while the tabs and the list below ran full width.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: MlPageHeader(
                title: operationsHubTitle(
                  orgType: access.company.orgType,
                  role: access.isCompanyAccount ? null : access.role,
                ),
                description: operationsHubDescription(visibleTabs),
                actions: [
                  MlButton.ghost(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    compact: true,
                    onPressed: operationsState.isLoading
                        ? null
                        : () => operationsNotifier.refresh(),
                  ),
                ],
              ),
            ),
            _OperationsSummaryHeader(access: access, state: operationsState),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar.secondary(
                  isScrollable: true,
                  tabs: visibleTabs
                      .map((tab) => Tab(text: tab.label, icon: Icon(tab.icon)))
                      .toList(),
                ),
              ),
            ),
            if (operationsState.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: MlShape.radiusLargeIncreased,
                  child: ListTile(
                    leading: Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    title: Text(
                      'Live operations data hit an error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      operationsState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: visibleTabs.map((tab) {
                  return _OperationsTabView(
                    tab: tab,
                    access: access,
                    state: operationsState,
                    onRefresh: () =>
                        operationsNotifier.refresh(withLoading: false),
                    onCreatePressed: () => _openCreateDialog(
                      context,
                      ref,
                      tab,
                      access,
                      operationsState,
                      operationsNotifier,
                    ),
                    onEditRequested: (record) => _openEditDialog(
                      context,
                      ref,
                      tab,
                      access,
                      operationsState,
                      operationsNotifier,
                      record,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _initialIndexForTab(List<OperationsTab> tabs, String? tabId) {
    final requestedTab = OperationsTabX.fromId(tabId);
    final index = tabs.indexOf(requestedTab);
    return index >= 0 ? index : 0;
  }
}

class _OperationsAccess {
  final String userId;
  final Company company;
  final Employee? employee;
  final bool isCompanyAccount;
  final bool canEditAll;
  final bool readOnlyObserver;

  const _OperationsAccess({
    required this.userId,
    required this.company,
    required this.employee,
    required this.isCompanyAccount,
    required this.canEditAll,
    this.readOnlyObserver = false,
  });

  factory _OperationsAccess.superAdminObserver({
    required String userId,
    required Company company,
  }) {
    return _OperationsAccess(
      userId: userId,
      company: company,
      employee: null,
      isCompanyAccount: false,
      canEditAll: false,
      readOnlyObserver: true,
    );
  }

  static _OperationsAccess? fromState({
    required String? authStateUserId,
    required UserType? userType,
    required Company? company,
    required Company? employeeCompany,
    required Employee? employee,
  }) {
    if (authStateUserId == null) {
      return null;
    }

    if (userType?.isCompany == true && company != null) {
      return _OperationsAccess(
        userId: authStateUserId,
        company: company,
        employee: null,
        isCompanyAccount: true,
        canEditAll: true,
        readOnlyObserver: false,
      );
    }

    if (userType?.isEmployee == true &&
        employeeCompany != null &&
        employee != null &&
        employee.status == 'active') {
      final isManagerRole =
          employee.role == UserRole.admin ||
          employee.role == UserRole.management;
      return _OperationsAccess(
        userId: authStateUserId,
        company: employeeCompany,
        employee: employee,
        isCompanyAccount: false,
        canEditAll: isManagerRole,
        readOnlyObserver: false,
      );
    }

    return null;
  }

  UserRole? get role => employee?.role;

  String get operatorName {
    if (isCompanyAccount) {
      final ceoName = [
        company.ceoFirstName,
        company.ceoLastName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      return ceoName.isEmpty ? company.companyName : ceoName;
    }
    return employee?.fullName ?? company.companyName;
  }

  List<OperationsTab> get visibleTabs {
    if (readOnlyObserver) {
      return OperationsTab.values;
    }
    return OperationsAccessPolicy.visibleTabs(
      canEditAll: canEditAll,
      orgType: company.orgType,
      role: role,
    );
  }

  bool canCreateFor(OperationsTab tab) {
    if (readOnlyObserver) {
      return false;
    }
    return OperationsAccessPolicy.canCreate(
      canEditAll: canEditAll,
      tab: tab,
      orgType: company.orgType,
      role: role,
    );
  }
}

class _OperationsSummaryHeader extends StatelessWidget {
  final _OperationsAccess access;
  final OperationsState state;

  const _OperationsSummaryHeader({required this.access, required this.state});

  @override
  Widget build(BuildContext context) {
    // The company card, in the portal's card vocabulary. Until 2026-08-23 it
    // was a stock `Card` headed by a 24px sans ExtraBold company name, and —
    // inside a `CrossAxisAlignment.start` column — it sized to its content,
    // so it ended at x≈1040 on a 1600px canvas while every card under it
    // spanned the column. Fraunces via `MlSectionTitle`, full width via the
    // `SizedBox`. Phase 3 mine-portal pass.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: MlCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlSectionTitle(
                    access.company.companyName,
                    subtitle:
                        "Today's records and entry forms, updated live.",
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(
                        label: 'Minerals',
                        value: state.minerals.length.toString(),
                        icon: Icons.diamond_outlined,
                      ),
                      _MetricChip(
                        label: 'Transactions',
                        value: state.transactions.length.toString(),
                        icon: Icons.receipt_long_outlined,
                      ),
                      _MetricChip(
                        label: 'Incidents',
                        value: state.securityIncidents.length.toString(),
                        icon: Icons.security_outlined,
                      ),
                      _MetricChip(
                        label: 'Gate checks',
                        value: state.gateChecks.length.toString(),
                        icon: Icons.sensor_door_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OperationsTabView extends StatelessWidget {
  final OperationsTab tab;
  final _OperationsAccess access;
  final OperationsState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreatePressed;
  final ValueChanged<Object> onEditRequested;

  const _OperationsTabView({
    required this.tab,
    required this.access,
    required this.state,
    required this.onRefresh,
    required this.onCreatePressed,
    required this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final config = _OperationsTabConfig.forTab(tab);
    final canCreate = access.canCreateFor(tab);
    final items = _itemsForTab();
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // The tab's heading: Fraunces section title with its icon, the
          // description as the subtitle, and the create action RIGHT-ALIGNED
          // in the heading's action slot — not a 20px sans ExtraBold row with
          // the button stacked under it (HANDOFF §3.25 classes 1 and 2).
          MlCard(
            padding: const EdgeInsets.all(20),
            child: MlSectionTitle(
              config.title,
              icon: config.icon,
              subtitle: config.description,
              margin: EdgeInsets.zero,
              action: MlButton.primary(
                label: config.createLabel,
                icon: Icons.add_circle_outline,
                compact: true,
                onPressed: canCreate ? onCreatePressed : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _OperationsEmptyState(
              icon: config.icon,
              title: config.emptyTitle,
              message: config.emptyMessage,
            )
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    onTap: item.onTap,
                    leading: Icon(item.icon, color: theme.colorScheme.primary),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
                    trailing: item.trailing == null
                        ? null
                        : Text(
                            item.trailing!,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  List<_OperationItem> _itemsForTab() {
    switch (tab) {
      case OperationsTab.minerals:
        return state.minerals.map((record) {
          final summary = [
            if ((record.grade ?? '').trim().isNotEmpty) 'Grade ${record.grade}',
            'Unit ${record.unitOfMeasure}',
          ].join(' • ');
          return _OperationItem(
            title: record.name,
            subtitle: summary,
            trailing: _formatDate(record.updatedAt),
            icon: OperationsTab.minerals.icon,
            onTap: access.canCreateFor(tab)
                ? () => onEditRequested(record)
                : null,
          );
        }).toList();
      case OperationsTab.transactions:
        return state.transactions.map((record) {
          return _OperationItem(
            title: record.referenceNumber,
            subtitle:
                '${record.status.toUpperCase()} • ${record.quantity.toStringAsFixed(2)} units',
            trailing: _formatDate(record.updatedAt),
            icon: OperationsTab.transactions.icon,
            onTap: access.canCreateFor(tab)
                ? () => onEditRequested(record)
                : null,
          );
        }).toList();
      case OperationsTab.weighbridge:
        return state.weighbridgeRecords.map((record) {
          return _OperationItem(
            title: '${record.direction.toUpperCase()} weighbridge entry',
            subtitle:
                'Gross ${_formatOptionalNumber(record.grossWeight)} • Tare ${_formatOptionalNumber(record.tareWeight)} • Net ${_formatOptionalNumber(record.netWeight)}',
            trailing: _formatDate(record.recordedAt),
            icon: OperationsTab.weighbridge.icon,
            onTap: access.canCreateFor(tab)
                ? () => onEditRequested(record)
                : null,
          );
        }).toList();
      case OperationsTab.loads:
        return state.mineralLoads.map((record) {
          return _OperationItem(
            title: 'Load ${record.id.substring(0, 8).toUpperCase()}',
            subtitle: record.notes?.trim().isNotEmpty == true
                ? record.notes!
                : 'Vehicle-linked load activity',
            trailing: _formatDate(record.loadedAt),
            icon: OperationsTab.loads.icon,
            onTap: access.canCreateFor(tab)
                ? () => onEditRequested(record)
                : null,
          );
        }).toList();
      case OperationsTab.security:
        return state.securityIncidents.map((record) {
          return _OperationItem(
            title: record.title,
            subtitle: '${record.severity.toUpperCase()} • ${record.status}',
            trailing: _formatDate(record.occurredAt),
            icon: OperationsTab.security.icon,
            onTap: access.canCreateFor(tab)
                ? () => onEditRequested(record)
                : null,
          );
        }).toList();
      case OperationsTab.gate:
        return state.gateChecks.map((record) {
          return _OperationItem(
            title: '${record.checkType.toUpperCase()} check',
            subtitle: '${record.gateStatus} • ${record.notes ?? 'No notes'}',
            trailing: _formatDate(record.checkedAt),
            icon: OperationsTab.gate.icon,
            onTap: access.canCreateFor(tab)
                ? () => onEditRequested(record)
                : null,
          );
        }).toList();
    }
  }

  String _formatDate(DateTime value) => MlTime.stamp(value);

  String _formatOptionalNumber(double? value) {
    return value == null ? '--' : value.toStringAsFixed(2);
  }
}

class _OperationItem {
  final String title;
  final String subtitle;
  final String? trailing;
  final IconData icon;
  final VoidCallback? onTap;

  const _OperationItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });
}

class _OperationsTabConfig {
  final String title;
  final String description;
  final String createLabel;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;

  const _OperationsTabConfig({
    required this.title,
    required this.description,
    required this.createLabel,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
  });

  factory _OperationsTabConfig.forTab(OperationsTab tab) {
    switch (tab) {
      case OperationsTab.minerals:
        return const _OperationsTabConfig(
          title: 'Mineral catalogue',
          description:
              'Maintain live mineral definitions, grades, and measurement units for operational use.',
          createLabel: 'Add mineral',
          emptyTitle: 'No minerals yet',
          emptyMessage:
              'Create your first mineral record to support live transactions and loads.',
          icon: Icons.diamond_outlined,
        );
      case OperationsTab.transactions:
        return const _OperationsTabConfig(
          title: 'Transactions',
          description:
              'Capture live transaction references, parties, quantities, and operational status.',
          createLabel: 'Add transaction',
          emptyTitle: 'No transactions yet',
          emptyMessage:
              'Start capturing live operational work by creating the first transaction.',
          icon: Icons.receipt_long_outlined,
        );
      case OperationsTab.weighbridge:
        return const _OperationsTabConfig(
          title: 'Weighbridge',
          description:
              'Record inbound and outbound weights with timestamps, vehicles, and linked transactions.',
          createLabel: 'Record weighbridge',
          emptyTitle: 'No weighbridge records yet',
          emptyMessage:
              'Live weighbridge entries will appear here as soon as they are captured.',
          icon: Icons.scale_outlined,
        );
      case OperationsTab.loads:
        return const _OperationsTabConfig(
          title: 'Mineral loads',
          description:
              'Track loading activity against vehicles, minerals, and transaction records in real time.',
          createLabel: 'Record load',
          emptyTitle: 'No load records yet',
          emptyMessage: 'Create a live load entry once loading begins on site.',
          icon: Icons.inventory_2_outlined,
        );
      case OperationsTab.security:
        return const _OperationsTabConfig(
          title: 'Security incidents',
          description:
              'Log real incidents, severity, and status so the security workflow stays current for the team.',
          createLabel: 'Report incident',
          emptyTitle: 'No security incidents yet',
          emptyMessage:
              'The live incident queue will appear here once security begins reporting events.',
          icon: Icons.security_outlined,
        );
      case OperationsTab.gate:
        return const _OperationsTabConfig(
          title: 'Gate checks',
          description:
              'Track entry and exit checks with responsible staff, vehicle context, and gate status.',
          createLabel: 'Record gate check',
          emptyTitle: 'No gate checks yet',
          emptyMessage:
              'Gate activity will appear here as soon as your team begins recording checks.',
          icon: Icons.sensor_door_outlined,
        );
    }
  }
}

class _OperationsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _OperationsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    // The shared empty state, framed in the portal card. It was a stock
    // `Card` with a 48px accent icon and a 22px sans ExtraBold title — the
    // hub's own empty-state vocabulary beside the one every other portal
    // screen uses. Phase 3 mine-portal pass, 2026-08-23.
    return MlCard(
      padding: EdgeInsets.zero,
      child: MlEmptyState(icon: icon, title: title, message: message),
    );
  }
}

Future<void> _openCreateDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsTab tab,
  _OperationsAccess access,
  OperationsState state,
  OperationsNotifier notifier,
) {
  return _openEditDialog(context, ref, tab, access, state, notifier, null);
}

Future<void> _openEditDialog(
  BuildContext context,
  WidgetRef ref,
  OperationsTab tab,
  _OperationsAccess access,
  OperationsState state,
  OperationsNotifier notifier,
  Object? record,
) async {
  switch (tab) {
    case OperationsTab.minerals:
      await _showMineralDialog(
        context,
        notifier,
        existing: record as MineralRecord?,
      );
      break;
    case OperationsTab.transactions:
      await _showTransactionDialog(
        context,
        state,
        notifier,
        access,
        existing: record as OperationTransaction?,
      );
      break;
    case OperationsTab.weighbridge:
      await _showWeighbridgeDialog(
        context,
        state,
        notifier,
        existing: record as WeighbridgeRecord?,
      );
      break;
    case OperationsTab.loads:
      await _showLoadDialog(
        context,
        state,
        notifier,
        existing: record as MineralLoadRecord?,
      );
      break;
    case OperationsTab.security:
      await _showSecurityDialog(
        context,
        state,
        notifier,
        existing: record as SecurityIncidentRecord?,
      );
      break;
    case OperationsTab.gate:
      await _showGateDialog(
        context,
        state,
        notifier,
        existing: record as GateCheckRecord?,
      );
      break;
  }
}

Future<void> _showMineralDialog(
  BuildContext context,
  OperationsNotifier notifier, {
  MineralRecord? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: existing?.name ?? '');
  final gradeController = TextEditingController(text: existing?.grade ?? '');
  final unitController = TextEditingController(
    text: existing?.unitOfMeasure ?? 'ton',
  );
  final descriptionController = TextEditingController(
    text: existing?.description ?? '',
  );

  final didSubmit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? 'Add mineral' : 'Edit mineral'),
        content: Form(
          key: formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Mineral name',
                    ),
                    validator: (value) => _requiredText(value, 'Mineral name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: gradeController,
                    decoration: const InputDecoration(labelText: 'Grade'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit of measure',
                    ),
                    validator: (value) =>
                        _requiredText(value, 'Unit of measure'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 3,
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              Navigator.pop(dialogContext, true);
            },
            child: Text(existing == null ? 'Save mineral' : 'Save changes'),
          ),
        ],
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  await _runMutation(
    context,
    successMessage: existing == null
        ? 'Mineral created successfully'
        : 'Mineral updated successfully',
    action: () {
      return notifier.saveMineral(
        id: existing?.id,
        name: nameController.text,
        grade: gradeController.text,
        description: descriptionController.text,
        unitOfMeasure: unitController.text,
      );
    },
  );
}

Future<void> _showTransactionDialog(
  BuildContext context,
  OperationsState state,
  OperationsNotifier notifier,
  _OperationsAccess access, {
  OperationTransaction? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final referenceController = TextEditingController(
    text: existing?.referenceNumber ?? '',
  );
  final quantityController = TextEditingController(
    text: existing?.quantity.toString() ?? '',
  );
  String status = existing?.status ?? 'draft';
  String? mineralId = existing?.mineralId;
  String? supplierCompanyId = existing?.supplierCompanyId ?? access.company.id;
  String? buyerCompanyId = existing?.buyerCompanyId;
  String? transporterCompanyId = existing?.transporterCompanyId;

  final didSubmit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Add transaction' : 'Edit transaction',
            ),
            content: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Reference number',
                        ),
                        validator: (value) =>
                            _requiredText(value, 'Reference number'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        validator: _decimalValidator,
                      ),
                      const SizedBox(height: 12),
                      M3DropdownField<String>(
                        initialValue: status,
                        label: 'Status',
                        entries: const [
                          DropdownMenuEntry(value: 'draft', label: 'Draft'),
                          DropdownMenuEntry(
                            value: 'scheduled',
                            label: 'Scheduled',
                          ),
                          DropdownMenuEntry(
                            value: 'in_progress',
                            label: 'In progress',
                          ),
                          DropdownMenuEntry(
                            value: 'completed',
                            label: 'Completed',
                          ),
                          DropdownMenuEntry(
                            value: 'cancelled',
                            label: 'Cancelled',
                          ),
                        ],
                        onSelected: (value) =>
                            setState(() => status = value ?? status),
                      ),
                      const SizedBox(height: 12),
                      M3DropdownField<String?>(
                        initialValue: mineralId,
                        label: 'Mineral',
                        enableSearch: true,
                        enableFilter: true,
                        entries: [
                          const DropdownMenuEntry<String?>(
                            value: null,
                            label: 'Unassigned',
                          ),
                          ...state.minerals.map(
                            (mineral) => DropdownMenuEntry<String?>(
                              value: mineral.id,
                              label: mineral.name,
                            ),
                          ),
                        ],
                        onSelected: (value) =>
                            setState(() => mineralId = value),
                      ),
                      const SizedBox(height: 12),
                      _companyDropdown(
                        label: 'Supplier company',
                        value: supplierCompanyId,
                        companies: state.companies,
                        onChanged: (value) =>
                            setState(() => supplierCompanyId = value),
                      ),
                      const SizedBox(height: 12),
                      _companyDropdown(
                        label: 'Buyer company',
                        value: buyerCompanyId,
                        companies: state.companies,
                        onChanged: (value) =>
                            setState(() => buyerCompanyId = value),
                      ),
                      const SizedBox(height: 12),
                      _companyDropdown(
                        label: 'Transporter company',
                        value: transporterCompanyId,
                        companies: state.companies,
                        onChanged: (value) =>
                            setState(() => transporterCompanyId = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: Text(
                  existing == null ? 'Save transaction' : 'Save changes',
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  await _runMutation(
    context,
    successMessage: existing == null
        ? 'Transaction created successfully'
        : 'Transaction updated successfully',
    action: () {
      return notifier.saveTransaction(
        id: existing?.id,
        mineralId: mineralId,
        supplierCompanyId: supplierCompanyId,
        buyerCompanyId: buyerCompanyId,
        transporterCompanyId: transporterCompanyId,
        referenceNumber: referenceController.text,
        status: status,
        quantity: double.parse(quantityController.text),
      );
    },
  );
}

Future<void> _showWeighbridgeDialog(
  BuildContext context,
  OperationsState state,
  OperationsNotifier notifier, {
  WeighbridgeRecord? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final grossController = TextEditingController(
    text: existing?.grossWeight?.toString() ?? '',
  );
  final tareController = TextEditingController(
    text: existing?.tareWeight?.toString() ?? '',
  );
  final netController = TextEditingController(
    text: existing?.netWeight?.toString() ?? '',
  );
  String direction = existing?.direction ?? 'inbound';
  String? transactionId = existing?.transactionId;
  String? vehicleId = existing?.vehicleId;
  DateTime recordedAt = existing?.recordedAt ?? DateTime.now();

  final didSubmit = await _showStatefulDialog(
    context,
    title: existing == null
        ? 'Record weighbridge entry'
        : 'Edit weighbridge entry',
    builder: (dialogContext, setState) {
      return Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3DropdownField<String>(
              initialValue: direction,
              label: 'Direction',
              entries: const [
                DropdownMenuEntry(value: 'inbound', label: 'Inbound'),
                DropdownMenuEntry(value: 'outbound', label: 'Outbound'),
              ],
              onSelected: (value) =>
                  setState(() => direction = value ?? direction),
            ),
            const SizedBox(height: 12),
            _transactionDropdown(
              value: transactionId,
              transactions: state.transactions,
              onChanged: (value) => setState(() => transactionId = value),
            ),
            const SizedBox(height: 12),
            _vehicleDropdown(
              value: vehicleId,
              vehicles: state.vehicles,
              onChanged: (value) => setState(() => vehicleId = value),
            ),
            const SizedBox(height: 12),
            _weightField(controller: grossController, label: 'Gross weight'),
            const SizedBox(height: 12),
            _weightField(controller: tareController, label: 'Tare weight'),
            const SizedBox(height: 12),
            _weightField(controller: netController, label: 'Net weight'),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Recorded at',
              value: recordedAt,
              onChanged: (value) => setState(() => recordedAt = value),
            ),
          ],
        ),
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  await _runMutation(
    context,
    successMessage: existing == null
        ? 'Weighbridge record created successfully'
        : 'Weighbridge record updated successfully',
    action: () {
      return notifier.saveWeighbridgeRecord(
        id: existing?.id,
        transactionId: transactionId,
        vehicleId: vehicleId,
        direction: direction,
        grossWeight: _parseOptionalDouble(grossController.text),
        tareWeight: _parseOptionalDouble(tareController.text),
        netWeight: _parseOptionalDouble(netController.text),
        recordedAt: recordedAt,
      );
    },
  );
}

Future<void> _showLoadDialog(
  BuildContext context,
  OperationsState state,
  OperationsNotifier notifier, {
  MineralLoadRecord? existing,
}) async {
  final notesController = TextEditingController(text: existing?.notes ?? '');
  String? transactionId = existing?.transactionId;
  String? vehicleId = existing?.vehicleId;
  String? mineralId = existing?.mineralId;
  String? loaderEmployeeId = existing?.loaderEmployeeId;
  DateTime loadedAt = existing?.loadedAt ?? DateTime.now();

  final didSubmit = await _showStatefulDialog(
    context,
    title: existing == null ? 'Record mineral load' : 'Edit mineral load',
    builder: (dialogContext, setState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _transactionDropdown(
            value: transactionId,
            transactions: state.transactions,
            onChanged: (value) => setState(() => transactionId = value),
          ),
          const SizedBox(height: 12),
          _vehicleDropdown(
            value: vehicleId,
            vehicles: state.vehicles,
            onChanged: (value) => setState(() => vehicleId = value),
          ),
          const SizedBox(height: 12),
          M3DropdownField<String?>(
            initialValue: mineralId,
            label: 'Mineral',
            enableSearch: true,
            enableFilter: true,
            entries: [
              const DropdownMenuEntry<String?>(
                value: null,
                label: 'Unassigned',
              ),
              ...state.minerals.map(
                (mineral) => DropdownMenuEntry<String?>(
                  value: mineral.id,
                  label: mineral.name,
                ),
              ),
            ],
            onSelected: (value) => setState(() => mineralId = value),
          ),
          const SizedBox(height: 12),
          _employeeDropdown(
            label: 'Loader',
            value: loaderEmployeeId,
            employees: state.employees,
            onChanged: (value) => setState(() => loaderEmployeeId = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          _DateTimeField(
            label: 'Loaded at',
            value: loadedAt,
            onChanged: (value) => setState(() => loadedAt = value),
          ),
        ],
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  await _runMutation(
    context,
    successMessage: existing == null
        ? 'Load recorded successfully'
        : 'Load updated successfully',
    action: () {
      return notifier.saveMineralLoad(
        id: existing?.id,
        transactionId: transactionId,
        vehicleId: vehicleId,
        mineralId: mineralId,
        loaderEmployeeId: loaderEmployeeId,
        notes: notesController.text,
        loadedAt: loadedAt,
      );
    },
  );
}

Future<void> _showSecurityDialog(
  BuildContext context,
  OperationsState state,
  OperationsNotifier notifier, {
  SecurityIncidentRecord? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(text: existing?.title ?? '');
  final descriptionController = TextEditingController(
    text: existing?.description ?? '',
  );
  String severity = existing?.severity ?? 'low';
  String status = existing?.status ?? 'open';
  String? employeeId = existing?.employeeId;
  String? vehicleId = existing?.vehicleId;
  DateTime occurredAt = existing?.occurredAt ?? DateTime.now();

  final didSubmit = await _showStatefulDialog(
    context,
    title: existing == null
        ? 'Report security incident'
        : 'Edit security incident',
    builder: (dialogContext, setState) {
      return Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Incident title'),
              validator: (value) => _requiredText(value, 'Incident title'),
            ),
            const SizedBox(height: 12),
            M3DropdownField<String>(
              initialValue: severity,
              label: 'Severity',
              entries: const [
                DropdownMenuEntry(value: 'low', label: 'Low'),
                DropdownMenuEntry(value: 'medium', label: 'Medium'),
                DropdownMenuEntry(value: 'high', label: 'High'),
                DropdownMenuEntry(value: 'critical', label: 'Critical'),
              ],
              onSelected: (value) =>
                  setState(() => severity = value ?? severity),
            ),
            const SizedBox(height: 12),
            M3DropdownField<String>(
              initialValue: status,
              label: 'Status',
              entries: const [
                DropdownMenuEntry(value: 'open', label: 'Open'),
                DropdownMenuEntry(
                  value: 'investigating',
                  label: 'Investigating',
                ),
                DropdownMenuEntry(value: 'resolved', label: 'Resolved'),
                DropdownMenuEntry(value: 'closed', label: 'Closed'),
              ],
              onSelected: (value) => setState(() => status = value ?? status),
            ),
            const SizedBox(height: 12),
            _employeeDropdown(
              label: 'Employee',
              value: employeeId,
              employees: state.employees,
              onChanged: (value) => setState(() => employeeId = value),
            ),
            const SizedBox(height: 12),
            _vehicleDropdown(
              value: vehicleId,
              vehicles: state.vehicles,
              onChanged: (value) => setState(() => vehicleId = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Occurred at',
              value: occurredAt,
              onChanged: (value) => setState(() => occurredAt = value),
            ),
          ],
        ),
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  await _runMutation(
    context,
    successMessage: existing == null
        ? 'Security incident created successfully'
        : 'Security incident updated successfully',
    action: () {
      return notifier.saveSecurityIncident(
        id: existing?.id,
        employeeId: employeeId,
        vehicleId: vehicleId,
        severity: severity,
        title: titleController.text,
        description: descriptionController.text,
        status: status,
        occurredAt: occurredAt,
      );
    },
  );
}

Future<void> _showGateDialog(
  BuildContext context,
  OperationsState state,
  OperationsNotifier notifier, {
  GateCheckRecord? existing,
}) async {
  final notesController = TextEditingController(text: existing?.notes ?? '');
  String checkType = existing?.checkType ?? 'entry';
  String gateStatus = existing?.gateStatus ?? 'pending';
  String? employeeId = existing?.employeeId;
  String? vehicleId = existing?.vehicleId;
  DateTime checkedAt = existing?.checkedAt ?? DateTime.now();

  final didSubmit = await _showStatefulDialog(
    context,
    title: existing == null ? 'Record gate check' : 'Edit gate check',
    builder: (dialogContext, setState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          M3DropdownField<String>(
            initialValue: checkType,
            label: 'Check type',
            entries: const [
              DropdownMenuEntry(value: 'entry', label: 'Entry'),
              DropdownMenuEntry(value: 'exit', label: 'Exit'),
            ],
            onSelected: (value) =>
                setState(() => checkType = value ?? checkType),
          ),
          const SizedBox(height: 12),
          M3DropdownField<String>(
            initialValue: gateStatus,
            label: 'Gate status',
            entries: const [
              DropdownMenuEntry(value: 'pending', label: 'Pending'),
              DropdownMenuEntry(value: 'cleared', label: 'Cleared'),
              DropdownMenuEntry(value: 'blocked', label: 'Blocked'),
            ],
            onSelected: (value) =>
                setState(() => gateStatus = value ?? gateStatus),
          ),
          const SizedBox(height: 12),
          _employeeDropdown(
            label: 'Employee',
            value: employeeId,
            employees: state.employees,
            onChanged: (value) => setState(() => employeeId = value),
          ),
          const SizedBox(height: 12),
          _vehicleDropdown(
            value: vehicleId,
            vehicles: state.vehicles,
            onChanged: (value) => setState(() => vehicleId = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          _DateTimeField(
            label: 'Checked at',
            value: checkedAt,
            onChanged: (value) => setState(() => checkedAt = value),
          ),
        ],
      );
    },
  );

  if (didSubmit != true || !context.mounted) {
    return;
  }

  await _runMutation(
    context,
    successMessage: existing == null
        ? 'Gate check created successfully'
        : 'Gate check updated successfully',
    action: () {
      return notifier.saveGateCheck(
        id: existing?.id,
        employeeId: employeeId,
        vehicleId: vehicleId,
        checkType: checkType,
        gateStatus: gateStatus,
        notes: notesController.text,
        checkedAt: checkedAt,
      );
    },
  );
}

Future<bool?> _showStatefulDialog(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) builder,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: builder(dialogContext, setState),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _runMutation(
  BuildContext context, {
  required String successMessage,
  required Future<void> Function() action,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    if (!(messenger?.mounted ?? false)) {
      return;
    }
    messenger!
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(successMessage)));
  } catch (error) {
    if (!(messenger?.mounted ?? false)) {
      return;
    }
    messenger!
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Could not save live data. ${friendlyError(error)}')),
      );
  }
}

Widget _companyDropdown({
  required String label,
  required String? value,
  required List<CompanyDirectoryEntry> companies,
  required ValueChanged<String?> onChanged,
}) {
  return M3DropdownField<String?>(
    initialValue: value,
    label: label,
    enableSearch: true,
    enableFilter: true,
    entries: [
      const DropdownMenuEntry<String?>(value: null, label: 'Unassigned'),
      ...companies.map(
        (company) => DropdownMenuEntry<String?>(
          value: company.id,
          label: company.companyName,
        ),
      ),
    ],
    onSelected: onChanged,
  );
}

Widget _employeeDropdown({
  required String label,
  required String? value,
  required List<Employee> employees,
  required ValueChanged<String?> onChanged,
}) {
  return M3DropdownField<String?>(
    initialValue: value,
    label: label,
    enableSearch: true,
    enableFilter: true,
    entries: [
      const DropdownMenuEntry<String?>(value: null, label: 'Unassigned'),
      ...employees.map(
        (employee) => DropdownMenuEntry<String?>(
          value: employee.id,
          label: employee.fullName,
        ),
      ),
    ],
    onSelected: onChanged,
  );
}

Widget _vehicleDropdown({
  required String? value,
  required List<FleetVehicle> vehicles,
  required ValueChanged<String?> onChanged,
}) {
  return M3DropdownField<String?>(
    initialValue: value,
    label: 'Vehicle',
    enableSearch: true,
    enableFilter: true,
    entries: [
      const DropdownMenuEntry<String?>(value: null, label: 'Unassigned'),
      ...vehicles.map(
        (vehicle) => DropdownMenuEntry<String?>(
          value: vehicle.id,
          label: vehicle.vehicleRegistrationNumber,
        ),
      ),
    ],
    onSelected: onChanged,
  );
}

Widget _transactionDropdown({
  required String? value,
  required List<OperationTransaction> transactions,
  required ValueChanged<String?> onChanged,
}) {
  return M3DropdownField<String?>(
    initialValue: value,
    label: 'Transaction',
    enableSearch: true,
    enableFilter: true,
    entries: [
      const DropdownMenuEntry<String?>(value: null, label: 'Unassigned'),
      ...transactions.map(
        (transaction) => DropdownMenuEntry<String?>(
          value: transaction.id,
          label: transaction.referenceNumber,
        ),
      ),
    ],
    onSelected: onChanged,
  );
}

TextFormField _weightField({
  required TextEditingController controller,
  required String label,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if ((value ?? '').trim().isEmpty) {
        return null;
      }
      return _decimalValidator(value);
    },
  );
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: MlShape.radiusLargeIncreased,
      onTap: () async {
        final picked = await _pickDateTime(context, value);
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(MlTime.stamp(value)),
      ),
    );
  }
}

Future<DateTime?> _pickDateTime(
  BuildContext context,
  DateTime initialValue,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialValue,
    firstDate: DateTime(2024),
    lastDate: DateTime(2100),
  );

  if (date == null || !context.mounted) {
    return null;
  }

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialValue),
  );

  if (time == null) {
    return DateTime(date.year, date.month, date.day);
  }

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String? _requiredText(String? value, String label) {
  if ((value ?? '').trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? _decimalValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return 'A value is required';
  }
  return double.tryParse(text) == null ? 'Enter a valid number' : null;
}

double? _parseOptionalDouble(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(text);
}

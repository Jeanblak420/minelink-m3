import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/employee/models/employee_status_model.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// A timeline widget that displays the employee's approval process stages
class EmployeeStatusTimeline extends ConsumerWidget {
  final List<EmployeeStatusHistory> statusHistory;
  final Employee? employee;
  final Company? company;

  const EmployeeStatusTimeline({
    super.key,
    required this.statusHistory,
    this.employee,
    this.company,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (employee == null) {
      return const Center(child: Text('Employee information not available'));
    }

    final hasBeenApproved = employee?.role != null;
    final companyRequestedStatus = _firstWhereOrNull(
      statusHistory,
      (status) => status.isCompanyRequested,
    );
    final requestApprovedStatus = _firstWhereOrNull(
      statusHistory,
      (status) => status.isRequestApproved,
    );
    final roleAssignedStatus = _firstWhereOrNull(
      statusHistory,
      (status) => status.isRoleAssigned,
    );
    final requestDeclinedStatus = _firstWhereOrNull(
      statusHistory,
      (status) => status.isRequestDeclined,
    );

    final companyRequestedTime =
        companyRequestedStatus?.timestamp ?? employee!.createdAt;
    final requestApprovedTime = requestApprovedStatus?.timestamp;
    final roleAssignedTime = roleAssignedStatus?.timestamp;
    final requestDeclinedTime = requestDeclinedStatus?.timestamp;

    final companyRequestedBy = companyRequestedStatus?.actionedByName;
    final requestApprovedBy = requestApprovedStatus?.actionedByName;
    final roleAssignedBy = roleAssignedStatus?.actionedByName;
    final requestDeclinedBy = requestDeclinedStatus?.actionedByName;

    final isDeclined = requestDeclinedStatus != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Company request submitted
        _buildTimelineItem(
          context: context,
          title: 'Company request submitted',
          dateTime: companyRequestedTime,
          icon: Icons.arrow_upward,
          iconColor: MlTone.accent.colors(Theme.of(context).brightness).fg,
          isCompleted: true,
          actionedBy: companyRequestedBy,
        ),

        // Request approved
        _buildTimelineItem(
          context: context,
          title: 'Request approved',
          dateTime: requestApprovedTime,
          icon: Icons.verified,
          iconColor: MlTone.transit.colors(Theme.of(context).brightness).fg,
          isCompleted: requestApprovedTime != null || hasBeenApproved,
          actionedBy: requestApprovedBy,
        ),

        // Show either approved or declined based on status
        if (isDeclined)
          // Request declined
          _buildTimelineItem(
            context: context,
            title: 'Request declined',
            dateTime: requestDeclinedTime,
            icon: Icons.cancel,
            iconColor: MlTone.error.colors(Theme.of(context).brightness).fg,
            isCompleted: true,
            actionedBy: requestDeclinedBy,
            isLast: true,
          )
        else ...[
          // Role assigned
          _buildTimelineItem(
            context: context,
            title: 'Role assigned',
            dateTime: roleAssignedTime,
            icon: Icons.check_circle,
            iconColor: MlTone.done.colors(Theme.of(context).brightness).fg,
            isCompleted: roleAssignedTime != null || hasBeenApproved,
            actionedBy: roleAssignedBy,
          ),

          // App ready for use
          _buildTimelineItem(
            context: context,
            title: 'App ready for use',
            dateTime: roleAssignedTime,
            icon: Icons.check_circle,
            iconColor: MlTone.done.colors(Theme.of(context).brightness).fg,
            isCompleted: roleAssignedTime != null || hasBeenApproved,
            actionedBy: roleAssignedBy,
            isLast: true,
          ),
        ],
      ],
    );
  }

  EmployeeStatusHistory? _firstWhereOrNull(
    List<EmployeeStatusHistory> items,
    bool Function(EmployeeStatusHistory item) test,
  ) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required String title,
    required DateTime? dateTime,
    required IconData icon,
    required Color iconColor,
    required bool isCompleted,
    required String? actionedBy,
    bool isLast = false,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line and icon
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? iconColor : MlSemantic.of(context).borderStrong,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: MlTokens.inkOnFill, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isCompleted ? iconColor : MlSemantic.of(context).borderStrong,
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (dateTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: MlSemantic.of(context).textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(dateTime),
                      style: textTheme.bodySmall?.copyWith(
                        color: MlSemantic.of(context).textMuted,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  'Pending',
                  style: textTheme.bodySmall?.copyWith(
                    color: MlSemantic.of(context).textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (actionedBy != null && isCompleted) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person,
                        size: 14, color: MlSemantic.of(context).textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Actioned by $actionedBy',
                      style: textTheme.bodySmall?.copyWith(
                        color: MlSemantic.of(context).textMuted,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

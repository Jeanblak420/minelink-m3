import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/mcp/models/employee_model.dart';
import 'package:flutter_application_1/core/mcp/repository_providers.dart';
import 'package:flutter_application_1/core/widgets/infinite_grid.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    // NO `Scaffold(appBar:)` — `/employees/:companyId` is a leaf of the portal
    // `ShellRoute`, whose top bar already names the company.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: MlPageHeader(
            title: '$companyName Employees',
            description: 'Everyone registered under this company.',
          ),
        ),
        Expanded(child: _buildEmployeeGrid(context, ref)),
      ],
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
      // A TILE SIZE, not a column count. `crossAxisCount: 2` gave a desktop
      // the phone's two columns, so each person's name and phone number sat in
      // a 630x790px card. 260 keeps the card the size it was drawn for at
      // every width — two columns on a phone, five or six on a monitor.
      maxCrossAxisExtent: 260,
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
          // Employee photo — the FLEXIBLE half.
          //
          // It was `flex: 3` against the name block's `flex: 2`, which fixes
          // the text's share of the tile at 40% whatever the text needs. A
          // two-line surname at 412px overflowed it by 7.3px, and any reader
          // who has nudged the console's text scale overflows it further. The
          // photo is the only part of this card that can absorb slack, so it
          // takes what is left rather than claiming a fixed proportion.
          Expanded(
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

                // Role badge — ALWAYS, including when there is no role.
                //
                // It was behind `if (employee.role != null)`, which made
                // `_getRoleLabel`'s own "No Role" branch unreachable: someone
                // with no role rendered a card with nothing in the corner, and
                // a reader could not tell that from a badge that failed to
                // draw. Role is what decides whether a person can do anything
                // in this product at all, so its absence is the state most
                // worth naming.
                Positioned(
                  top: 8,
                  right: 8,
                  child: MlStatusBadge(label: roleLabel, tone: roleTone),
                ),
              ],
            ),
          ),

          // Employee info — sized by its CONTENT.
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: context.mlText.titleMedium.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                  // TWO lines. South African surnames are long — "Annelize
                  // van der Merwe-Botha" ellipsised to "Annelize van der ..."
                  // in a 185px tile, which is a card that does not say who it
                  // is about.
                  maxLines: 2,
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

// `EmployeeDetailsScreen` and `EmployeeDetailsLoaderScreen` used to live here
// and were DELETED on 2026-08-21. Nothing referenced them: the router sends
// `/employees/:companyId/:employeeId/details` to `EmployeeProfileScreen`, and
// no other file named either class. Two unreachable screens are not free — the
// pair carried a hand-rolled `d/M/yyyy H:mm` (an eighth spelling of a moment
// in time, on the RAW instant with an unpadded hour, so 09:05 SAST printed as
// "7:5"), a flat 130px label column that does not ride the text scale, and an
// `AppBar` of the kind the shell now draws for every one of its leaves. Kept
// as a note rather than as code, so nobody restores them by accident.

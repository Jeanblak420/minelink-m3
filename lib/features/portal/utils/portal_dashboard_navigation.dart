import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:go_router/go_router.dart';

/// The route behind a sidebar label for this session, or null when this
/// session's tree has no such destination.
String? portalNavRouteForLabel(WidgetRef ref, String label) {
  final isCompanyAccount = ref.read(authStateProvider).userType?.isCompany;
  final orgType = isCompanyAccount == true
      ? ref.read(companyProvider).company?.orgType
      : ref.read(employeeProvider).company?.orgType;
  if (orgType == null) return null;

  final tree = portalNavTree(
    orgType: orgType,
    role: isCompanyAccount == true
        ? null
        : ref.read(employeeProvider).employee?.role,
  );
  final target = mlTabMenuNames[label] ?? label;
  for (final leaf in tree.expand((n) => n.leaves)) {
    if (leaf.label == target) return leaf.route;
  }
  return null;
}

/// Opens a portal destination by its sidebar label.
///
/// Navigates to the destination's **route** now that every one has an address
/// (P7-02). The old contract set a tab index and pushed `/home`, which left
/// the rail highlighting the dashboard while the body showed something else —
/// and gave the destination no URL to link, bookmark or refresh.
///
/// Falls back to the index behaviour for a label the tree does not carry, so a
/// caller naming a destination this role cannot reach degrades to what it did
/// before rather than silently doing nothing.
void openPortalTabByLabel(WidgetRef ref, BuildContext context, String label) {
  if (portalMirrorActive(ref)) return;

  final route = portalNavRouteForLabel(ref, label);
  if (route != null) {
    context.go(route);
    return;
  }

  final tabs = ref.read(portalWorkspaceProvider).tabs;
  if (tabs == null) return;
  final index = tabs.indexWhere((t) => t.label == label);
  if (index < 0) return;
  ref.read(portalTabIndexProvider.notifier).state = index;
  context.go('/home');
}

/// Opens a top-level route (fleet, operations, notifications, etc.).
void openPortalRoute(WidgetRef ref, BuildContext context, String path) {
  if (portalMirrorActive(ref)) return;
  context.go(path);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/features/employee/screens/company_selection_screen.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';

/// The workspace-phase gate, for screens that render **outside** the portal
/// shell — S7-8 / P4-12.
///
/// ## Why this exists
///
/// `PortalShellLayout` opens with a three-way switch on
/// [PortalWorkspacePhase]: `selectingCompany` sends the user to pick a
/// company, `ready` renders the page, and **every other phase renders a status
/// scaffold instead of the page**. That switch is the reason a portal screen
/// never draws against a half-resolved session.
///
/// `/portal/driver/navigate/:tripId` is deliberately outside the shell — it is
/// fullscreen turn-by-turn navigation and the sidebar and app bar would eat
/// the map (spec 2026-07-16 §4). Outside the shell it also lost the switch. A
/// driver whose company had not resolved yet, or who had not chosen one, got
/// the navigation screen itself: no chrome, no explanation, and a map with no
/// destination, which is indistinguishable from the app being broken.
///
/// The router's own guards were never the missing piece and still are not.
/// `redirect` is global, so the `/portal/driver/*` prefix guard and the
/// no-role gate (S2-7) both already apply to this route. What was missing is
/// the *asynchronous* half — the phases that exist precisely because the
/// company and employee rows arrive after the first frame.
///
/// ## What it deliberately does NOT gate
///
/// The licence-expiry notice. `MlExpiryNotice` renders on every shell screen,
/// and this one is a driver mid-drive: interrupting a live navigation with a
/// commercial banner is worse than showing it at the next stop. Navigation is
/// a read, and the client's ruling on S2-10 preserves reads for an expired
/// company, so nothing here needs blocking — only nothing here should shout.
class PortalPhaseGate extends ConsumerWidget {
  const PortalPhaseGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(portalWorkspaceProvider);
    switch (vm.phase) {
      case PortalWorkspacePhase.selectingCompany:
        return const CompanySelectionScreen();
      case PortalWorkspacePhase.ready:
        return child;
      case PortalWorkspacePhase.platformAdminObserver:
        return _PortalPhaseStatus(vm: vm, showConsoleLink: true);
      default:
        return _PortalPhaseStatus(vm: vm);
    }
  }
}

/// The status screen for a not-yet-ready workspace.
///
/// Deliberately its own widget rather than the shell's private
/// `_statusScaffold`: the shell's version carries a retry button wired to the
/// shell's own providers, and lifting it would have meant refactoring the
/// shell to close a gate about a screen that is not in it. Same three states —
/// working, failed, and the phase's own words — without the coupling.
class _PortalPhaseStatus extends ConsumerWidget {
  const _PortalPhaseStatus({required this.vm, this.showConsoleLink = false});

  final PortalWorkspaceModel vm;

  /// Platform admins get a way out. Without it this screen is a cul-de-sac —
  /// no company workspace to load and no navigation, because the portal chrome
  /// only renders once the phase is `ready`.
  final bool showConsoleLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final failed = vm.retryAction != PortalRetryAction.none ||
        vm.phase.endsInSignOut;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showConsoleLink)
                  Icon(Icons.admin_panel_settings_outlined,
                      size: 48, color: theme.colorScheme.primary)
                else if (failed)
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error)
                else
                  const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  vm.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (vm.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    vm.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (showConsoleLink) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/super-admin'),
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    label: const Text('Open the admin console'),
                  ),
                ],
                // A failed load has no chrome here either, so without this the
                // only way off the screen was to clear the app's data.
                if (failed && !showConsoleLink) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () =>
                        LogoutService.logoutWithConfirmation(context, ref),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_rail_blocks.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/core/layout/text_scale.dart';
import 'package:flutter_application_1/core/navigation/app_sidebar_prefs.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/app_navigation_back_button.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/animated_notification_bell.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

/// The super-admin console's shell.
///
/// ## What happened to the other 1,800 lines
///
/// This file was 2,031 lines, and almost none of it was console-specific. It
/// hand-built a navigation rail in which **every destination appeared twice** —
/// once for the expanded state, once for the collapsed one — then repeated the
/// exercise for a `Drawer` at narrow widths, then offered three interchangeable
/// "skins" that each did the whole thing again in their own files (a further
/// 4,571 lines). Roughly 6,600 lines rendering one list of thirty
/// destinations.
///
/// The navigation is now data ([consoleNavTree]) and the chrome is now shared
/// ([MlAppShell]). What is left here is the part that is genuinely about *this*
/// audience: which tree to show, who is signed in, what the top bar carries,
/// and the back-navigation contract. That is what a feature shell should be.
///
/// The portal shell delegates to the same widget, which is what makes "every
/// role gets the console's UX" true rather than aspirational — they are not two
/// implementations kept in agreement, they are one.
class SuperAdminShellLayout extends ConsumerStatefulWidget {
  const SuperAdminShellLayout({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SuperAdminShellLayout> createState() =>
      _SuperAdminShellLayoutState();
}

class _SuperAdminShellLayoutState extends ConsumerState<SuperAdminShellLayout> {
  /// Collapsed until the stored preference says otherwise — see
  /// [AppSidebarPrefs], and the note there on why this must match its default.
  bool _railExpanded = false;

  @override
  void initState() {
    super.initState();
    AppSidebarPrefs.readSuperAdminExpanded().then((v) {
      if (mounted) setState(() => _railExpanded = v);
    });
  }

  void _setExpanded(bool value) {
    setState(() => _railExpanded = value);
    AppSidebarPrefs.writeSuperAdminExpanded(value);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(uiPrefsProvider);
    final media = MediaQuery.of(context);

    // Per-user accessibility (Settings → User Preferences). Both COMPOSE with
    // the platform rather than replacing it: an admin who set 200% at the OS
    // level used to get 130%, because the in-app slider they had never touched
    // defaults to 1.0 and was substituted for the platform's value.
    return MediaQuery(
      data: media.copyWith(
        textScaler: mlTextScaler(media.textScaler, prefs.textScale),
        boldText: media.boldText || prefs.boldText,
      ),
      child: Theme(
        // The accent and high-contrast preferences now flow through the
        // ColorScheme itself, so they reach every Material widget rather than
        // the handful this shell used to patch by hand.
        data: AppTheme.build(
          prefs.darkMode ? Brightness.dark : Brightness.light,
          accent: prefs.accent.color,
          highContrast: prefs.highContrast,
        ),
        child: Builder(builder: _buildShell),
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    final prefs = ref.watch(uiPrefsProvider);
    final goState = GoRouterState.of(context);
    final location = goState.uri.path;
    final tree = consoleNavTree();
    final titles = mlRouteTitle(goState.uri);

    final navLocation = NavLocation(
      path: location,
      query: goState.uri.queryParameters,
    );

    final unread = ref.watch(notificationProvider).unreadCount;

    final shell = MlAppShell(
      tree: tree,
      // The raw location. The rail resolves it to the destination that owns it
      // (longest match), so a detail page keeps its parent lit.
      selectedRoute: location,
      onNavigate: (route) => context.go(route),
      badgeCounts: {MlNavBadge.unreadNotifications: unread},
      title: titles.title,
      subtitle: titles.subtitle,
      expanded: _railExpanded,
      onExpandedChanged: _setExpanded,
      showCanvasTexture: prefs.canvasTexture,
      leading: const AppNavigationBackButton(),
      railHeader: MlRailBrand(
        expanded: _railExpanded,
        subtitle: 'GLOBAL ADMIN',
        onTap: () => context.go('/super-admin'),
      ),
      railFooter: _identity(context),
      actions: [
        const AnimatedNotificationBell(),
        _overflow(context),
      ],
      // The semantics boundary that used to be here is now inside MlAppShell,
      // so the portal gets it too — it never had one, which left every company
      // user's rail invisible to assistive tech.
      child: NavHistoryRecorder(
        key: ValueKey(navLocation.fullLocation),
        location: navLocation,
        isRoot: location == '/super-admin',
        child: widget.child,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ref.read(navHistoryProvider.notifier).canGoBack) {
          navigateBack(context, ref);
        }
      },
      child: ChatDock(child: shell),
    );
  }

  Widget _identity(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final email = user?.email ?? '';
    final metaName = user?.userMetadata?['full_name'] as String?;
    final name = (metaName != null && metaName.trim().isNotEmpty)
        ? metaName.trim()
        : (email.contains('@') ? email.split('@').first : 'Super Admin');

    return MlRailIdentity(
      expanded: _railExpanded,
      identity: UserIdentity(
        name: name,
        email: email,
        roleLabel: 'Super Admin',
      ),
      onOpenProfile: () => context.go('/super-admin/account-security'),
      actions: [
        UserIdentityAction(
          icon: Icons.shield_outlined,
          label: 'Profile & account security',
          onTap: () => context.go('/super-admin/account-security'),
        ),
        UserIdentityAction(
          icon: Icons.tune_rounded,
          label: 'User preferences',
          onTap: () => context.go('/super-admin/preferences'),
        ),
        UserIdentityAction(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          onTap: () => LogoutService.logoutWithConfirmation(context, ref),
          danger: true,
        ),
      ],
    );
  }

  /// Top-bar overflow.
  ///
  /// "About" lives here now. It was a rail tile that called `showAboutDialog` —
  /// an action sitting in a list of destinations, with no address, nothing able
  /// to link to it and no way for the back button to return from it. The nav
  /// model requires every leaf to resolve to a route, which is what keeps dead
  /// entries out of navigation; an action belongs with the other actions.
  Widget _overflow(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'notifications':
            context.go(NotificationsInboxRoute.superAdminPath);
          case 'about':
            showAboutDialog(
              context: context,
              applicationName: 'MineLink',
              applicationVersion: 'Super Admin Console',
            );
          case 'signout':
            LogoutService.logoutWithConfirmation(context, ref);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'notifications', child: Text('Notifications')),
        PopupMenuItem(value: 'about', child: Text('About MineLink')),
        PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
    );
  }
}

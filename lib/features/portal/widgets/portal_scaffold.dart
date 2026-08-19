import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_rail_blocks.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/tokens/ml_mine_premium_theme.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';

/// The company portal's chrome — now a thin delegate to [MlAppShell].
///
/// ## What this file used to be
///
/// 1,239 lines: its own navigation rail, its own collapsed rail, its own
/// drawer, its own brand block, its own user chip, its own workspace surface.
/// All of it a second implementation of what the super-admin console already
/// had, which is why the console and the portal never looked like the same
/// product — a mine supervisor and a platform admin were not looking at two
/// styles of one shell, they were looking at two shells.
///
/// The client's instruction for the M3 redesign was that every surface should
/// follow the super-admin console's UI/UX. The way to make that true rather
/// than aspirational is not to restyle this to match; it is to delete it and
/// render the console's shell with the portal's tree. Then the two cannot
/// drift, because there is nothing to keep in agreement.
///
/// The public API is unchanged apart from the app bar: callers used to hand in
/// a fully-built `PreferredSizeWidget`, which is how the two top bars came to
/// carry different things in different places. It now takes [title], [subtitle]
/// and [actions], and the shell builds the bar — so the portal's title block
/// sits exactly where the console's does.
class PortalScaffold extends StatelessWidget {
  const PortalScaffold({
    super.key,
    required this.nav,
    required this.selectedRoute,
    required this.onNavigate,
    required this.body,
    required this.navLocked,
    required this.sidebarExpanded,
    required this.onSidebarExpandedChanged,
    this.badgeCounts = const <PortalNavBadge, int>{},
    this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.sidebarBrandTitle,
    this.scaffoldKey,
    this.userName,
    this.userMeta,
    this.userEmail,
    this.userAvatarUrl,
    this.onLogout,
    this.onNotifications,
    this.notificationsBadge = false,
    this.onProfile,
    this.onToggleTheme,
    this.onAppearance,
    this.premiumPalette,
    this.floatingAction,
    this.bottomNav,
    this.onBrandTap,
  });

  /// Kept for the handful of screens that still read it.
  ///
  /// The shell no longer switches on it — [MlWindowClass] does, on M3's
  /// window size classes. See the note in `ml_window_class.dart` on why three
  /// independently-invented breakpoints (900 / 800 / 600) produced an 850px
  /// window with a phone's navigation around a desktop's page.
  static const double sidebarBreakpoint = 600;

  final List<PortalNavNode> nav;
  final String selectedRoute;
  final void Function(String route) onNavigate;
  final Map<PortalNavBadge, int> badgeCounts;

  final Widget body;

  /// Page title and its second line. Falls back to the selected leaf's label.
  final String? title;
  final String? subtitle;

  /// Top-bar trailing actions.
  final List<Widget> actions;

  /// Top-bar leading (a back button). The menu button is added by the shell at
  /// compact width and must not be passed here.
  final Widget? leading;

  /// True while an employee is waiting for a role: the rail renders but is
  /// inert. See [MlAppShell.navEnabled] for why it renders at all.
  final bool navLocked;

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool sidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;

  final String? sidebarBrandTitle;
  final VoidCallback? onBrandTap;

  final String? userName;
  final String? userMeta;
  final String? userEmail;
  final String? userAvatarUrl;

  final VoidCallback? onLogout;
  final VoidCallback? onNotifications;
  final bool notificationsBadge;
  final VoidCallback? onProfile;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onAppearance;

  /// The mine's premium appearance choice.
  ///
  /// Still accepted, and still applied by the caller as a `Theme` +
  /// `MlSemanticScope` over the whole portal. It no longer skins the rail:
  /// the rail's colours come from `MlChrome`, a `ThemeExtension`, and
  /// `MinePremiumPalette` does not carry one yet. Reconciling the premium
  /// directions into `MlChrome` variants is Phase 2 — until then a mine on a
  /// premium direction gets its own workspace colours with the standard navy
  /// rail, which is coherent rather than broken.
  final MinePremiumPalette? premiumPalette;

  final Widget? floatingAction;

  /// The driver's phone bar. See [MlAppShell.bottomNavOverride].
  final Widget? bottomNav;

  @override
  Widget build(BuildContext context) {
    return MlAppShell(
      key: scaffoldKey == null ? null : ValueKey(scaffoldKey),
      tree: nav,
      selectedRoute: selectedRoute,
      onNavigate: onNavigate,
      badgeCounts: badgeCounts,
      title: title,
      subtitle: subtitle,
      actions: actions,
      leading: leading,
      expanded: sidebarExpanded,
      onExpandedChanged: onSidebarExpandedChanged,
      navEnabled: !navLocked,
      floatingActionButton: floatingAction,
      bottomNavOverride: bottomNav,
      railHeader: MlRailBrand(
        expanded: sidebarExpanded,
        subtitle: sidebarBrandTitle?.toUpperCase(),
        onTap: onBrandTap ?? onProfile ?? () {},
      ),
      railFooter: userName == null
          ? null
          : MlRailIdentity(
              expanded: sidebarExpanded,
              identity: UserIdentity(
                name: userName!,
                email: userEmail ?? '',
                roleLabel: userMeta,
                avatarUrl: userAvatarUrl,
              ),
              onOpenProfile: onProfile ?? () {},
              actions: [
                if (onProfile != null)
                  UserIdentityAction(
                    icon: Icons.person_outline,
                    label: 'My profile',
                    onTap: onProfile!,
                  ),
                if (onNotifications != null)
                  UserIdentityAction(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: onNotifications!,
                  ),
                if (onAppearance != null)
                  UserIdentityAction(
                    icon: Icons.palette_outlined,
                    label: 'Appearance',
                    onTap: onAppearance!,
                  ),
                if (onToggleTheme != null)
                  UserIdentityAction(
                    icon: Icons.brightness_6_outlined,
                    label: 'Switch theme',
                    onTap: onToggleTheme!,
                  ),
                if (onLogout != null)
                  UserIdentityAction(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    onTap: onLogout!,
                    danger: true,
                  ),
              ],
            ),
      child: body,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/navigation/app_sidebar_prefs.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/theme_mode_provider.dart';
import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/profile_setup/widgets/profile_setup_banner.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_status_provider.dart';
import 'package:flutter_application_1/features/employee/screens/company_selection_screen.dart';
import 'package:flutter_application_1/features/employee/widgets/approval_pending_overlay.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/animated_notification_bell.dart';
import 'package:flutter_application_1/features/notifications/widgets/welcome_notification.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav_badges.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/features/portal/providers/mine_appearance_provider.dart';
import 'package:flutter_application_1/core/design/tokens/ml_mine_premium_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_scaffold.dart';
import 'package:flutter_application_1/features/portal/widgets/workflow_notification_bell.dart';
import 'package:flutter_application_1/core/widgets/app_navigation_back_button.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
import 'package:flutter_application_1/core/widgets/system_back_handler.dart';
import 'package:flutter_application_1/features/tour/providers/tour_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_seen_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_service_provider.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_overlay.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/generic_dashboard_keys.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/core/design/components/ml_expiry_notice.dart';
import 'package:flutter_application_1/features/portal/providers/company_access_provider.dart';
import 'package:flutter_application_1/core/layout/text_scale.dart';

/// Whether the floating chat launcher belongs over [location].
///
/// It does not belong over a surface that IS the conversation. `/communications`
/// has been excluded since the dock was introduced, for the plain reason that a
/// floating button offering to open chat, on the chat hub, offers nothing.
///
/// `/chat/:chatRoomId` — the full-page thread — was not excluded, and there the
/// redundancy is the smaller half of it: **the launcher lands on the composer's
/// send button.** Measured in a browser as `roadhaul.admin` on 2026-08-22, in a
/// 1689×1277 window, with the thread open at
/// `#/chat/24f1bef3-c3be-41c7-973c-6625e4fa3913`:
///
///     send button   x 1633..1677   y 1220..1264   (44×44)
///     dock launcher x 1601..1667   y 1189..1255   (66×66)
///     overlap       x 1633..1667   y 1220..1255   = 34×35 px
///
/// That is **61% of the send button**, and the launcher is painted above it, so
/// a real thumb aimed at Send opens the dock instead. It is the same fault
/// `chat_dock_keeps_off_the_bottom_bar_test.dart` was written for — the dock
/// wraps the whole shell and knows nothing about the bottom-anchored chrome
/// underneath it — one surface further on. The bar got a reserve; the composer
/// got nothing, because no page but this one has a composer at the bottom of
/// the window.
///
/// Suppressing the dock here costs no capability: you are already in a
/// conversation, and the way to another one is the hub, exactly as it is from
/// `/communications`.
bool portalShowsChatDock({
  required String location,
  required bool isEmployeeWithoutRole,
}) {
  if (isEmployeeWithoutRole) return false;
  // `/communications` and `/communications/anything`.
  if (location.startsWith('/communications')) return false;
  // `/chat/:chatRoomId`. Matched with the trailing slash so a future
  // `/chatter`-shaped route is not silently swept in with it.
  if (location == '/chat' || location.startsWith('/chat/')) return false;
  return true;
}

/// The portal top bar's actions.
///
/// On a phone, chat opens from here (the dock is opted in; see
/// [ChatDock.launcherInAppBarOnPhone]) instead of from a disc floating over
/// the page, as in the admin console (Jean's go-ahead, 2026-10-24). That is a
/// fifth icon, and `MlAppShell` gives the title what the icons leave: at
/// 360dp five would push every page title onto its own row. So on a phone
/// "Take a tour" moves into More, keeping its unseen dot there, and the bar
/// stays at four icons. Wider windows keep the bar as it was; the chat button
/// draws nothing there.
///
/// [onMenu] receives `theme`, `profile`, `signout` and, on a phone, `tour`.
List<Widget> portalShellActions({
  required bool phone,
  required bool waitingForRole,
  required bool tourSeen,
  required bool darkTheme,
  required VoidCallback onTour,
  required ValueChanged<String> onMenu,
}) {
  const help = Icon(Icons.help_outline_rounded);
  const more = Icon(Icons.more_vert_rounded);
  return [
    if (phone) const ChatDockAppBarButton(),
    if (!phone)
      IconButton(
        tooltip: 'Take a tour',
        onPressed: onTour,
        icon: tourSeen ? help : Badge(smallSize: 8, child: help),
      ),
    if (!waitingForRole) const WorkflowNotificationBell(),
    if (!waitingForRole) const AnimatedNotificationBell(),
    PopupMenuButton<String>(
      tooltip: 'More',
      icon: phone && !tourSeen ? Badge(smallSize: 8, child: more) : more,
      onSelected: (value) => value == 'tour' ? onTour() : onMenu(value),
      itemBuilder: (_) => [
        if (phone)
          const PopupMenuItem(value: 'tour', child: Text('Take a tour')),
        PopupMenuItem(
          value: 'theme',
          child: Text(
            darkTheme ? 'Switch to light theme' : 'Switch to dark theme',
          ),
        ),
        const PopupMenuItem(value: 'profile', child: Text('Profile')),
        const PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
    ),
  ];
}

/// The rail for a session with no operational surface: an employee whose role
/// has not been assigned yet, or a workspace whose org type has not resolved.
///
/// Never an empty list. An empty rail reads as a broken app rather than a
/// pending one, and leaves no route to the user's own record — which is the
/// one thing the waiting overlay promises they can still reach.
const List<PortalNavNode> _waitingNav = [
  PortalNavNode.leaf(
    label: 'My profile',
    icon: Icons.person_outline_rounded,
    route: '/profile',
  ),
];

/// The section prefixes and the segment split moved to
/// `core/routing/ml_route_title.dart` with the title table they feed (S5-12).
/// Aliased here so the sidebar-selection code below reads unchanged.
String? _portalAliasSegment(String path) => mlPortalAliasSegment(path);

/// Whether [path] routes to the driver's OWN self-chromed 3-tab app, and so
/// must be rendered WITHOUT the portal's rail, top bar and banners.
///
/// `DriverAppScreen` is a complete shell: it draws its own scaffold, its own
/// Dashboard · Trip · Profile bottom bar and its own `ProfileSetupBanner`.
/// Wrapping it in the portal's chrome gives the driver two of each.
///
/// This was an exact-match set of three paths, and
/// `/portal/driver/trip/:id/waybill` — which renders that same
/// `DriverAppScreen`, on the Trip tab, with the signed waybill over it — was
/// not one of them. Driven in a browser as the real driver on 2026-08-22,
/// straight after recording a POD: the page came back with the account-setup
/// banner drawn **twice**, one above the other, the portal rail on the left
/// AND the driver's bottom bar underneath. Photographed.
///
/// So the rule is "this path is the driver app", not "this path is one of
/// three strings", and anything under `/portal/driver/trip/` qualifies because
/// that is where the driver app's own deep links live.
///
/// `/portal/driver/notifications` deliberately does NOT: it routes to
/// `NotificationScreen`, which is an ordinary page and needs the shell's
/// chrome to have a top bar and a way back at all.
@visibleForTesting
bool driverAppOwnsChrome(String path) =>
    path == '/portal/driver/home' ||
    path == '/portal/driver/profile' ||
    path == '/portal/driver/trip' ||
    path.startsWith('/portal/driver/trip/');

/// Sidebar tab label hosting the equivalent screen for a `/portal/{org}/...`
/// alias, or null when the alias has no sidebar tab (ops-hub tabs, employees,
/// company, notifications, locations). Labels not present in an org's tab
/// set simply resolve to no selection via `indexWhere` (-1).
String? _portalAliasTabLabel(String segment) {
  switch (segment) {
    case 'security':
    case 'gate':
      return 'Security';
    case 'weighbridge':
      return 'Controller';
    case 'stockpiles':
      return 'Supervisor';
    case 'reconciliations':
    case 'tons-out':
      return 'Reconciliations';
    case 'requests':
    case 'orders':
      return 'Requests';
    case 'live-map':
      return 'Live map';
    case 'waybills':
      return 'Waybills';
    case 'fleet':
      return 'Fleet / routes';
    case 'trucks-on-route':
      return 'Trucks On Route';
    case 'maintenance':
      return 'Maintenance';
    case 'drivers':
      return 'Driver';
    case 'profile':
      return 'Profile';
    default:
      return null;
  }
}

/// Sidebar selected index for the current location: the active tab on
/// `/home`, the hosting tab for a `/portal/{org}` alias (phase-2 T3), and -1
/// (no highlight) for every other routed page — matching prior behavior.
int portalShellSelectedIndex(
  String path,
  List<PortalTabItem> tabs,
  int homeTabIndex,
) {
  if (path == '/home') return homeTabIndex.clamp(0, tabs.length - 1);
  final segment = _portalAliasSegment(path);
  if (segment == null) return -1;
  if (segment.isEmpty) {
    // Section dashboard → the org's Overview (mine/transporter) or
    // Dashboard (buyer / employee shells) tab.
    final overview = tabs.indexWhere((t) => t.label == 'Overview');
    if (overview >= 0) return overview;
    return tabs.indexWhere((t) => t.label == 'Dashboard');
  }
  final label = _portalAliasTabLabel(segment);
  if (label == null) return -1;
  return tabs.indexWhere((t) => t.label == label);
}

/// The portal shell's page title.
///
/// A thin adapter now: the table itself lives in
/// `core/routing/ml_route_title.dart`, shared with the console (S5-12). This
/// maps the portal's own `PortalTabItem`s down to the labels the resolver
/// needs, which is the one piece of per-session state a title depends on.
String portalShellSectionTitle(
  Uri uri,
  List<PortalTabItem> tabs,
  int homeTabIndex,
) {
  return mlRouteTitle(
    uri,
    tabs: MlPortalTabs([for (final t in tabs) t.label], homeTabIndex),
  ).title;
}

/// Shell chrome around authenticated logistics workspace routes.
class PortalShellLayout extends ConsumerStatefulWidget {
  final Widget child;

  const PortalShellLayout({super.key, required this.child});

  @override
  ConsumerState<PortalShellLayout> createState() => _PortalShellLayoutState();
}

class _PortalShellLayoutState extends ConsumerState<PortalShellLayout> {
  bool _dialogOpen = false;
  final GlobalKey<ScaffoldState> _portalKey = GlobalKey<ScaffoldState>();

  /// Collapsed until the stored preference says otherwise (jean, 2026-08-22).
  ///
  /// This is the value for the frames BEFORE `readPortalExpanded` resolves,
  /// and it has to agree with that read's own default — otherwise the rail
  /// opens at 280px and snaps shut a frame later, which is a flash of the
  /// wrong layout on every single app start.
  bool _portalSidebarExpanded = false;

  @override
  void initState() {
    super.initState();
    AppSidebarPrefs.readPortalExpanded().then((v) {
      if (mounted) setState(() => _portalSidebarExpanded = v);
    });
  }

  Future<void> _syncManagedContext() async {
    final employee = ref.read(employeeProvider).employee;
    final companyNotifier = ref.read(companyProvider.notifier);

    final canManage =
        employee != null &&
        employee.companyId != null &&
        employee.status == 'active' &&
        (employee.role == UserRole.admin ||
            employee.role == UserRole.management);

    if (canManage) {
      await companyNotifier.loadManagedCompanyContext(employee.companyId!);
      return;
    }

    companyNotifier.clearContext();
  }

  void _scheduleManagedSync() {
    final authState = ref.read(authStateProvider);
    final employeeState = ref.read(employeeProvider);
    final companyState = ref.read(companyProvider);
    if (!portalNeedsManagedSync(authState, employeeState, companyState)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncManagedContext();
      }
    });
  }

  void _maybeShowRoleDialog(AuthState authState, EmployeeState employeeState) {
    if (_dialogOpen ||
        authState.userType?.isEmployee != true ||
        !employeeState.roleJustAssigned ||
        employeeState.employee?.role == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogOpen) {
        return;
      }

      _dialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const WelcomeNotification(),
      ).then((_) {
        _dialogOpen = false;
        final userId = authState.user?.id;
        if (!mounted || userId == null) {
          return;
        }
        ref.read(employeeProvider.notifier).loadEmployeeProfile(userId);
        ref.read(notificationProvider.notifier).loadNotifications(userId);
      });
    });
  }

  Widget _statusScaffold(PortalWorkspaceModel vm) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A platform admin is not a workspace that failed to load —
                // they simply have no company of their own. Same reasoning as
                // PortalWorkspacePhase.platformAdminObserver.
                if (vm.phase == PortalWorkspacePhase.platformAdminObserver)
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else if (vm.retryAction == PortalRetryAction.none &&
                    !vm.phase.endsInSignOut)
                  const CircularProgressIndicator()
                else
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                const SizedBox(height: 24),
                Text(
                  vm.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  vm.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (vm.retryAction != PortalRetryAction.none) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      final auth = ref.read(authStateProvider).user;
                      if (auth == null) {
                        return;
                      }
                      if (vm.retryAction == PortalRetryAction.companyProfile) {
                        ref
                            .read(companyProvider.notifier)
                            .loadCompanyProfile(auth.id);
                      } else {
                        ref
                            .read(employeeProvider.notifier)
                            .loadEmployeeProfile(auth.id);
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  // Retry cannot help a session whose account has no profile
                  // or employee row any more — on 2026-10-22 the emulator was
                  // still signed in as a fixture account removed by the
                  // September data reset, and this screen was a dead end: no
                  // chrome, no drawer, nothing but a Retry that always fails.
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        LogoutService.logoutWithConfirmation(context, ref),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                ],
                if (vm.phase.endsInSignOut) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        LogoutService.logoutWithConfirmation(context, ref),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                ],
                if (vm.phase == PortalWorkspacePhase.platformAdminObserver) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/super-admin'),
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    label: const Text('Open the admin console'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // S5-3 (P5-06): the org portals now honour the SAME per-user accessibility
    // settings the console has had — text scale and bold text — applied here,
    // once, so every portal screen inherits them the way every console screen
    // already did. Before this, a mine supervisor who needed larger text
    // simply had no way to get it: the setting existed, but only super admins
    // were behind a shell that read it.
    final uiPrefs = ref.watch(uiPrefsProvider);
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        // Multiplied onto the platform's scaler, not substituted for it — the
        // same rule the bold-text line below already followed. Substituting
        // meant a driver who had set 200% at the OS level got 100%, because
        // the in-app slider they had never opened defaults to 1.0.
        // See lib/core/layout/text_scale.dart.
        textScaler: mlTextScaler(media.textScaler, uiPrefs.textScale),
        // OR, not override: a user who set bold text at the OS level keeps it
        // even if the in-app toggle is off.
        boldText: media.boldText || uiPrefs.boldText,
      ),
      child: _buildShell(context),
    );
  }

  /// The driver app is self-chromed and bypasses the shell below, so it needs
  /// its own Back handling. Its Dashboard/Trip/Profile tabs are the driver's
  /// landing screens; only the in-app navigation screen under
  /// `/portal/driver/trip/...` steps back to them.
  Widget _driverBack(String shellPath, Widget child) {
    final isRoot = !shellPath.startsWith('/portal/driver/trip/');
    return NavHistoryRecorder(
      location: NavLocation(path: shellPath),
      isRoot: isRoot,
      child: SystemBackHandler(
        isRoot: isRoot,
        goToRoot: () => context.go('/portal/driver/home'),
        child: child,
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    final vm = ref.watch(portalWorkspaceProvider);
    final authState = ref.watch(authStateProvider);
    final employeeState = ref.watch(employeeProvider);
    final homeTabIndex = ref.watch(portalTabIndexProvider);

    _scheduleManagedSync();

    switch (vm.phase) {
      case PortalWorkspacePhase.selectingCompany:
        return const CompanySelectionScreen();
      case PortalWorkspacePhase.ready:
        break;
      default:
        return _statusScaffold(vm);
    }

    // Drivers get the mobile-first 3-tab shell (Dashboard · Trip · Profile,
    // spec 2026-07-16 §5) instead of the sidebar chrome — on /home only, so
    // pushed routes (/profile, /notifications, /chat/...) keep normal chrome.
    final shellPath = GoRouterState.of(context).uri.path;
    final isDriverEmployee =
        authState.userType?.isEmployee == true &&
        employeeState.employee?.role == UserRole.driver;
    if (shellPath == '/home' && isDriverEmployee) {
      // Wrapped in the dock, because this `return` is BEFORE the one at the
      // end of this method that wraps every other role's shell — so until
      // 2026-08-22 a driver had no chat at all.
      //
      // Not "no chat FAB": no chat. `/home` IS the driver's app, the 3-tab
      // shell replaces the sidebar so there is no rail entry to fall back on,
      // and `DriverAppScreen` has no messages affordance of its own. A driver
      // is a party to every load — load control, the transporter's admin, the
      // mine's security — and could not be messaged back.
      //
      // It was invisible in every test and every render because the harness
      // builds `MlAppShell` directly and never mounts this layout at all. It
      // showed up the first time the app was opened on a real handset, signed
      // in as a real driver, which is the whole argument for doing that.
      //
      // The disc keeps off the driver's own bottom nav for the same reason it
      // keeps off the portal's: the dock reserves `kMlBottomNavHeight` by
      // WINDOW CLASS rather than by asking whether a bar happens to be there
      // (`chat_dock.dart`), and the driver shell is only ever narrow.
      return _driverBack(shellPath, const ChatDock(child: DriverAppScreen()));
    }
    // Phase-2 nav merge (T2): /portal/driver/{home,trip,profile} deep-link
    // the same self-chromed driver app — render the routed child without the
    // sidebar chrome, so it isn't doubled around the driver shell's own
    // scaffold. **With the dock, though**, for the reason above.
    //
    // These three are where a driver actually lives: `portalLandingRoute`
    // returns the first leaf of the role's tree, and the driver tree's first
    // leaf is `/portal/driver/home` — so signing in redirects `/home` here
    // immediately, and the `/home` branch above is only ever a single frame.
    // Fixing that one alone left the disc still missing on the handset, which
    // is how this second `return` was found.
    if (isDriverEmployee && driverAppOwnsChrome(shellPath)) {
      return _driverBack(shellPath, ChatDock(child: widget.child));
    }

    final tabs = vm.tabs!;
    final uri = GoRouterState.of(context).uri;
    final location = uri.path;
    final navIndex = portalShellSelectedIndex(location, tabs, homeTabIndex);
    final onHome = location == '/home';
    final navLocation = NavLocation(
      path: location,
      query: uri.queryParameters,
      homeTabIndex: onHome ? navIndex : null,
    );
    final isRootScreen = onHome && navIndex == 0;

    // The sectioned destination tree for this session (P7-01). An employee
    // still waiting for a role assignment gets no org tree at all — handing
    // that user one was the privilege escalation closed in `f9add87` — so
    // they get their own record and nothing else, which is exactly what the
    // waiting overlay promises them.
    final isCompanyAccount = authState.userType?.isCompany == true;
    final orgType = isCompanyAccount
        ? ref.watch(companyProvider).company?.orgType
        : employeeState.company?.orgType;
    final navTree = (vm.isEmployeeWithoutRole || orgType == null)
        ? _waitingNav
        : portalNavTree(
            orgType: orgType,
            role: isCompanyAccount ? null : employeeState.employee?.role,
          );
    // `/home` is the post-login landing and renders the org's dashboard, so it
    // selects the same leaf the dashboard route does. Phase 12 removes the
    // route; until then the two are the same page under two addresses and the
    // rail must not look unselected on one of them.
    final dashboardRoute = navTree.isEmpty
        ? location
        : navTree.first.isGroup
            ? navTree.first.leaves.isEmpty
                ? location
                : navTree.first.leaves.first.route!
            : navTree.first.route!;
    final selectedRoute = onHome ? dashboardRoute : location;
    // The bar names a page as the menu does (see [portalNavLabelFor]); the
    // path table is the fallback for pages the menu has no entry for.
    final sectionTitle = portalNavLabelFor(navTree, location) ??
        portalShellSectionTitle(uri, tabs, navIndex);

    // Live queue counts for the badges this tree names, and only those
    // (P7-05). Resolved against the company whose workspace is on screen —
    // which under the platform admin's company-mirror is the observed company,
    // not the admin's own.
    final badgeCompanyId = resolvePortalCompanyId(ref);
    final badgeCounts = (orgType == null || badgeCompanyId == null)
        ? const <PortalNavBadge, int>{}
        : ref.watch(
            portalNavBadgeCountsProvider((
              orgType: orgType,
              role: isCompanyAccount ? null : employeeState.employee?.role,
              companyId: badgeCompanyId,
            )),
          );

    _maybeShowRoleDialog(authState, employeeState);

    ref.listen(portalWorkspaceProvider, (prev, next) {
      if (prev?.tabs?.length != next.tabs?.length && next.tabs != null) {
        final i = ref.read(portalTabIndexProvider);
        if (i >= next.tabs!.length) {
          ref.read(portalTabIndexProvider.notifier).state = 0;
        }
      }
    });

    if (vm.isEmployeeWithoutRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final employee = employeeState.employee;
        if (!mounted || employee == null) {
          return;
        }
        ref
            .read(employeeStatusProvider.notifier)
            .loadEmployeeStatusHistory(employee.id);
      });
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final narrowNav = screenW < PortalScaffold.sidebarBreakpoint;

    // The hand-built AppBar, the compact overflow menu and the home chip that
    // used to be constructed here are gone: MlAppShell builds the top bar from
    // `title` / `subtitle` / `actions` / `leading`, and the brand chip is the
    // rail header. Roughly 180 lines, all of it a second copy of chrome the
    // console already had.

    // Mine premium theme (mine/supplier only): when a Glass/Industrial
    // direction is chosen on the Appearance page, skin the whole mine portal.
    // Non-mine workspaces get null and keep the default look untouched.
    final appearance = ref.watch(mineAppearanceProvider);
    final minePalette = vm.isMineSupplier
        ? MinePremiumPalette.forDirection(appearance.direction)
        : null;
    final themeMode = ref.watch(themeModeProvider);

    final showChatFab = portalShowsChatDock(
      location: location,
      isEmployeeWithoutRole: vm.isEmployeeWithoutRole,
    );

    // Driver mobile: a phone-style Dashboard / Trip / Profile bottom bar (the
    // drawer still holds Live map / Truck locations / positions / Driver, so no
    // feature is lost). Only on the narrow (mobile) layout.
    Widget? driverBottomNav;
    if (narrowNav &&
        employeeState.employee?.role == UserRole.driver &&
        !vm.isEmployeeWithoutRole) {
      const targets = [
        '/portal/driver/home',
        '/portal/driver/trip',
        '/portal/driver/profile',
      ];
      final sel = targets.indexOf(selectedRoute);
      driverBottomNav = NavigationBar(
        selectedIndex: sel < 0 ? 0 : sel,
        onDestinationSelected: (i) => context.go(targets[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Trip',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      );
    }

    final shellBody = TourTarget(
      id: 'generic.navigation',
      targetKey: GenericDashboardTourKeys.navigation,
      child: PortalScaffold(
        scaffoldKey: _portalKey,
        nav: navTree,
        selectedRoute: selectedRoute,
        badgeCounts: badgeCounts,
        navLocked: vm.isEmployeeWithoutRole,
      // The top bar's content, rather than a hand-built AppBar.
      //
      // This is where the portal and the console had most visibly diverged:
      // the console carried a back button, a home chip, the title block, one
      // bell and an overflow; the portal carried a menu, a back button, a home
      // chip, the title block, a tour button, a theme toggle, TWO bells, a
      // profile button and a sign-out button — nine controls, six of them
      // actions that belong in a menu. They now share one bar, and the four
      // that are per-user actions moved into the identity flyout at the foot
      // of the rail, which is where the console has always kept them.
      title: sectionTitle,
      subtitle: portalShellSubtitle(
        workspaceName: vm.workspaceName,
        operatorName: vm.operatorName,
        roleLabel: vm.roleLabel,
      ),
      leading: const AppNavigationBackButton(),
      onBrandTap: () {
        ref.read(portalTabIndexProvider.notifier).state = 0;
        context.go('/home');
      },
      actions: portalShellActions(
        phone: MlWindowClass.of(context).usesBottomNav,
        waitingForRole: vm.isEmployeeWithoutRole,
        tourSeen: ref.watch(tourSeenProvider),
        darkTheme: themeMode == ThemeMode.dark,
        onTour: () {
          final steps = ref.read(tourStepsProvider);
          if (steps.isNotEmpty) {
            ref.read(tourProvider.notifier).startTour(steps);
          } else {
            // Show feedback when tour can't start
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tour not available. Please make sure you are signed in and your profile is complete.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        onMenu: (value) {
          switch (value) {
            case 'theme':
              ref.read(themeModeProvider.notifier).toggle();
            case 'profile':
              context.go('/profile');
            case 'signout':
              LogoutService.logoutWithConfirmation(context, ref);
          }
        },
      ),
      sidebarBrandTitle: vm.workspaceName,
      userName: vm.operatorName,
      userMeta: vm.roleLabel,
      // Read straight off the session rather than added to
      // PortalWorkspaceModel: the address is auth's, not the workspace's, and
      // the shell already watches authState above.
      userEmail: authState.user?.email,
      userAvatarUrl: vm.avatarUrl,
      premiumPalette: minePalette,
      onLogout: () => LogoutService.logoutWithConfirmation(context, ref),
      onNotifications: vm.isEmployeeWithoutRole
          ? null
          : () => context.go('/notifications'),
      notificationsBadge: ref.watch(notificationProvider).unreadCount > 0,
      onProfile: () => context.go('/profile'),
      onToggleTheme: () => ref.read(themeModeProvider.notifier).toggle(),
      onAppearance: () => context.go('/appearance'),
      // The floating chat launcher is provided by the draggable [ChatDock]
      // overlay (below) rather than a fixed FAB, so it can be repositioned.
      floatingAction: null,
      bottomNav: driverBottomNav,
      sidebarExpanded: _portalSidebarExpanded,
      onSidebarExpandedChanged: (expanded) {
        setState(() => _portalSidebarExpanded = expanded);
        AppSidebarPrefs.writePortalExpanded(expanded);
      },
      body: Column(
        // Stretch. This is the SHELL, so a centred banner here is a centred
        // banner on every portal screen that shows one: the account-setup nag
        // and the licence notice would each size to their own text while the
        // workspace below them ran the full width. A Column centres by default.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account-setup nag: renders nothing once setup is complete, and is
          // suppressed on the setup screen itself.
          if (!navLocation.fullLocation.startsWith('/account-setup'))
            const ProfileSetupBanner(),
          // Licence state, on EVERY portal screen rather than one notices page.
          // Token expiry is enforced in the database (migration 20260815094000),
          // so without this the block is silent: a write is refused by RLS and
          // nothing says a lapsed token caused it or that renewing fixes it.
          // It renders nothing while the company is active, and is suppressed on
          // /profile — the one screen whose whole job is the renewal request the
          // notice points at, where repeating it would be noise.
          if (!navLocation.fullLocation.startsWith('/profile'))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MlExpiryNotice(
                access: companyAccessOf(ref),
                onRequestRenewal: () => context.go('/profile'),
                onMessageMineLink: () => context.go('/messages'),
                onExplain: () => context.go('/expired-access'),
                compact: MediaQuery.of(context).size.width < 720,
              ),
            ),
          Expanded(
            child: TourTarget(
              id: 'generic.dashboard',
              targetKey: GenericDashboardTourKeys.dashboard,
              child: NavHistoryRecorder(
                // DELIBERATELY UNKEYED. A key that changes with the route
                // REMOUNTS this on every navigation, and go_router keys its shell
                // navigator with GlobalObjectKey(navigatorKey.hashCode) — so the
                // remount reparented that global key out of a parent which never
                // updated, which is a framework error and truncates the tree.
                // It also made didUpdateWidget below unreachable, which is the one
                // path this widget exists for.
                location: navLocation,
                isRoot: isRootScreen,
                // Its own semantics boundary. The routed child is a nested
                // Navigator whose route carries `BlockSemantics`, which drops
                // everything painted before it in the same container — and
                // the setup banner and licence notice above paint first. On
                // the S25 (2026-10-25) a screen reader could not see either,
                // nor reach "Complete now". MlAppShell's boundary is around
                // this whole Column, so it does not help them.
                child: Semantics(container: true, child: widget.child),
              ),
            ),
          ),
        ],
      ),
      onNavigate: (route) => context.go(route),
      ),
    );

    // The waiting-for-role overlay promises "you can only access your Profile"
    // — so leave /profile usable, and /account-setup with it: employees are
    // asked (banner + daily reminder deep-link) to complete their profile,
    // documents and signature while they wait for a role.
    // `/home` joins them at S2-7. It renders `WaitingForRoleScreen` for this
    // user — `resolvePortalTabs` gives a no-role employee exactly that one tab
    // — and the overlay is a near-duplicate of it: same status history, same
    // message. Stacking them put the waiting screen behind a 70% scrim showing
    // a second copy of itself. Now that the router sends every other path
    // here, that doubling would be the primary experience rather than an edge.
    final overlayExempt =
        location == '/home' ||
        location == '/profile' ||
        location == '/account-setup';
    Widget content = vm.isEmployeeWithoutRole && !overlayExempt
        ? Stack(children: [shellBody, const ApprovalPendingOverlay()])
        : shellBody;

    if (showChatFab) {
      // On a phone the launcher is the chat button in the top bar
      // ([portalShellActions]) and the window opens full screen.
      content = ChatDock(launcherInAppBarOnPhone: true, child: content);
    }

    // Guided coach-mark tour overlay — renders nothing until launched from the
    // help button (or the compact overflow menu), so it never blocks normal
    // app use. Mounted here so it covers the whole shell and still sits
    // inside the mine premium theme/semantic scope when one is installed.
    content = Stack(children: [content, const TourOverlay()]);

    // The phone's Back button / gesture. A PopScope here was never reached by
    // a system back — see SystemBackHandler for why.
    content = SystemBackHandler(
      isRoot: isRootScreen,
      goToRoot: () {
        ref.read(portalTabIndexProvider.notifier).state = 0;
        context.go('/home');
      },
      child: content,
    );

    // Install the premium Material theme + semantic scope over the entire mine
    // portal so every page, dialog and control adopts the chosen direction.
    if (minePalette != null) {
      content = Theme(
        data: minePalette.themeData,
        child: MlSemanticScope(semantic: minePalette.semantic, child: content),
      );
    }

    return content;
  }
}

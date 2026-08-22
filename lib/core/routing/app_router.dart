import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/routing/route_not_found_screen.dart';
import 'package:flutter_application_1/core/routing/portal_gate_staleness.dart';
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_application_1/features/auth/utils/reverification_policy.dart';
import 'package:flutter_application_1/features/auth/screens/login_screen.dart';
import 'package:flutter_application_1/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter_application_1/features/auth/screens/reset_password_screen.dart';
import 'package:flutter_application_1/features/home/screens/home_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_shell_layout.dart';
import 'package:flutter_application_1/features/profile/screens/profile_screen.dart';
import 'package:flutter_application_1/features/profile_setup/screens/profile_setup_screen.dart';
import 'package:flutter_application_1/features/profile/screens/account_security_screen.dart';
import 'package:flutter_application_1/core/mcp/models/company_model.dart';
import 'package:flutter_application_1/features/company/screens/company_employees_screen.dart';
import 'package:flutter_application_1/features/company/screens/company_list_screen.dart';
import 'package:flutter_application_1/features/company/screens/employee_register_screen.dart';
import 'package:flutter_application_1/features/employee/screens/company_selection_screen.dart';
import 'package:flutter_application_1/features/employee/screens/employee_grid_screen.dart';
import 'package:flutter_application_1/features/notifications/screens/notification_screen.dart';
import 'package:flutter_application_1/features/fleet/screens/fleet_management_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_own_company_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_search_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trip_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_route_focus_route.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trip_waybill_route.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trips_screen.dart';
import 'package:flutter_application_1/features/portal/screens/appearance_theme_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_navigation_screen.dart';
import 'package:flutter_application_1/features/portal/screens/drop_off_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/live_trip_map_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_routes_mines_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';
import 'package:flutter_application_1/features/portal/screens/compliance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/earnings_screen.dart';
import 'package:flutter_application_1/features/portal/screens/fuel_costs_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_buyers_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_request_tracking_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_drivers_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_maintenance_screen.dart';
import 'package:flutter_application_1/core/routing/initial_location.dart';
import 'package:flutter_application_1/core/routing/return_to.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';
import 'package:flutter_application_1/features/chat/screens/chat_room_route.dart';
import 'package:flutter_application_1/features/chat/screens/chat_screen.dart';
import 'package:flutter_application_1/features/chat/screens/communications_hub_screen.dart';
import 'package:flutter_application_1/features/chat/screens/messages_screen.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_dashboard_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_org_insights_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporters_overview_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporter_leaderboard_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_platform_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_org_type_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_company_mirror_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_shell_layout.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_management_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_detail_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/audit_logs_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/crash_reports_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/account_deactivations_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_review_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/available_routes_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/driver_limit_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/recon_tables_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/dispute_inbox_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/live_map_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_tracking_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/route_marketplace_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/chat_connections_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/margin_ledger_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_history_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/expired_access_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_admin_settings_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/user_preferences_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_users_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/register_company_screen.dart';
import 'package:flutter_application_1/features/auth/screens/mandatory_password_change_screen.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/core/routing/notifications_manage_route.dart';
import 'package:flutter_application_1/features/notifications/screens/notification_management_screen.dart';
import 'package:flutter_application_1/features/auth/screens/whatsapp_otp_screen.dart';
import 'package:flutter_application_1/core/routing/app_access_gates.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_phase_gate.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// The `:type` values `/super-admin/requests/:type` will actually serve.
///
/// `transportation` is the combined inbox; the two `transportation-*` values
/// split it by requesting-org type (CLAUDE.md §4 Request 1); `product` and
/// `buyer` are the other two request entities.
const kSuperAdminRequestQueues = <String>{
  'transportation',
  'transportation-mine',
  'transportation-buyer',
  'product',
  'buyer',
};

/// Where `/super-admin/requests/[type]` should really go — null to stay put.
///
/// A work queue must never say it is empty when it is not.
///
/// That path parameter matches ANY string, and an unrecognised one fell
/// through `RequestReviewScreen`'s `default` branch to the generic "Requested
/// routes / Requests awaiting review and dispatch" heading, then queried
/// `request_type = '<the typo>'` and rendered "Queue is clear. No requests in
/// this queue yet." The app bar meanwhile resolves its title by
/// `path.contains`, so it read "Requested buyers" over the top of it.
///
/// So a stale bookmark or a mistyped link showed a platform admin a plausible,
/// correctly-chromed, EMPTY review queue while real requests waited in it.
/// Measured 2026-08-17 on `/super-admin/requests/buyer-requests`: "0 new",
/// "Queue is clear", with two buyer requests pending.
///
/// Unknown types go to the canonical inbox rather than to a dead end: whoever
/// followed the link wanted a queue, and an empty-looking one is the worst
/// possible answer to give them.
///
/// A pure function, and public, so it can be tested without standing up the
/// whole router — and so the sidebar's destinations can be checked against the
/// same set that serves them.
///
/// The two ML deep-link aliases are resolved HERE as well as by their own
/// literal `GoRoute`s. Those are declared first and so win the match today,
/// but that is an ordering assumption, and an ordering assumption that silently
/// sends `buyer-transport` to the combined inbox instead of the buyer one is
/// exactly the kind of quiet wrong answer this function exists to stop.
/// Handled in both places, the behaviour is the same either way.
String? superAdminRequestsRedirect(String? type) {
  if (kSuperAdminRequestQueues.contains(type)) return null;
  const aliases = <String, String>{
    'mine-transport': 'transportation-mine',
    'buyer-transport': 'transportation-buyer',
  };
  return '/super-admin/requests/${aliases[type] ?? 'transportation'}';
}

class AppRouter {
  static final _logger = LoggerFactory.getLogger('AppRouter');
  static final _refreshListenable = _GoRouterRefreshStream(
    SupabaseConfig.client.auth.onAuthStateChange,
  );
  static final _deviceVerificationStore = DeviceVerificationStore();
  static const _publicPaths = <String>{
    '/login',
    '/forgot-password',
    '/reset-password',
    '/whatsapp-otp',
  };

  /// Cached profile fields for routing (role, user type, password gate).
  static String? _cachedPlatformRole;
  static String? _cachedUserType;
  static bool _cachedMustChangePassword = false;
  static String? _cachedProfileUserId;

  /// Cached org/role fields for the `/portal/{mine,buyer,transporter,driver}`
  /// prefix guards (phase-2 nav merge §4.2). Resolved LAZILY on the first
  /// `/portal/*` navigation only — never per-navigation — mirroring the
  /// `needsProfileGate` lazy pattern above.
  static String? _cachedOrgType;
  static String? _cachedEmployeeRole;

  /// G1 (S2-7). True when the signed-in user is an employee, linked to a
  /// company, and has **no role assigned yet**. Distinct from
  /// `_cachedEmployeeRole == null`, which is also true for every company
  /// owner — conflating the two would redirect owners to `/profile`.
  static bool _cachedIsEmployeeWithoutRole = false;
  static bool _portalGateFieldsLoaded = false;

  /// When the portal gate fields were last read, and for whom (S7-7).
  ///
  /// `_portalGateFieldsLoaded` used to be a **one-shot**: nothing but
  /// `clearProfileGateCache()` reset it, so a role or org change made while the
  /// user was signed in stayed invisible to the guard until they signed out —
  /// blocking a promoted user from routes they now own, and letting a demoted
  /// or dismissed one keep the old role for the life of the session.
  /// `shouldRefreshPortalGate` decides staleness; see
  /// `core/routing/portal_gate_staleness.dart`.
  static DateTime? _portalGateFetchedAt;
  static String? _portalGateUserId;

  /// When a gate read last failed or timed out, so the router does not pay the
  /// timeout again on the very next navigation. See `portalGateFailureBackoff`.
  static DateTime? _portalGateFailedAt;

  /// Call after the user clears the mandatory password flag so the next redirect re-fetches profile.
  static void clearProfileGateCache() {
    _cachedPlatformRole = null;
    _cachedUserType = null;
    _cachedMustChangePassword = false;
    _cachedProfileUserId = null;
    _cachedOrgType = null;
    _cachedEmployeeRole = null;
    _cachedIsEmployeeWithoutRole = false;
    _portalGateFieldsLoaded = false;
    _portalGateFetchedAt = null;
    _portalGateUserId = null;
    _portalGateFailedAt = null;
  }

  /// How long a gate read may take before the router gives up on it.
  ///
  /// **Every one of these `await`s sits inside `redirect`, so go_router shows
  /// NOTHING until they return.** A request that hangs rather than failing
  /// therefore leaves the app on a blank white page — no message, no spinner,
  /// no retry — and neither of the two `try`/`catch` blocks below can see it.
  ///
  /// Observed live on 2026-08-16 while the project was degraded: the boot
  /// preflight timed out and handed over correctly, then these two `profiles`
  /// selects sat `pending`, the redirect never returned, and the page rendered
  /// an empty semantics tree. It looked exactly like a crash.
  ///
  /// Both methods below already say what should happen when they cannot
  /// answer — *"Failure leaves the fields null so the guard falls back to
  /// `/home` non-fatally and retries next time"*. This makes a hang one of
  /// those failures instead of an indefinite wait. `shouldRefreshPortalGate`'s
  /// 2-minute TTL bounds how often the cost can be paid.
  static const _gateReadTimeout = Duration(seconds: 6);

  static Future<void> _refreshProfileGateFields(String userId) async {
    try {
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('platform_role, user_type, must_change_password')
          .eq('id', userId)
          .maybeSingle()
          .timeout(_gateReadTimeout);
      _cachedProfileUserId = userId;
      // Tolerant legacy mapping: the flattened child super-admin role string
      // (removed — both admins are equal, full-rights) still resolves to the
      // single main role so any lingering stored value never locks an admin out.
      final rawPlatformRole = profile?['platform_role'] as String?;
      _cachedPlatformRole = rawPlatformRole == 'superGlobalSerialAdminMainChild'
          ? 'superGlobalSerialAdminMain'
          : rawPlatformRole;
      _cachedUserType = profile?['user_type'] as String?;
      _cachedMustChangePassword =
          profile?['must_change_password'] as bool? ?? false;
    } catch (e) {
      _logger.w('Failed to refresh profile gate fields: $e');
    }
  }

  /// Resolves the signed-in user's company org type + employee role for the
  /// `/portal/*` prefix guards. Company owners resolve via their own
  /// `companies` row; employees via their `employees` linkage (same lookup
  /// the portal workspace providers use). Failure leaves the fields null so
  /// the guard falls back to `/home` non-fatally and retries next time.
  static Future<void> _refreshPortalGateFields(String userId) async {
    try {
      if ((_cachedUserType ?? '') == 'company') {
        final company = await SupabaseConfig.client
            .from('companies')
            .select('org_type')
            .eq('user_id', userId)
            .maybeSingle()
            .timeout(_gateReadTimeout);
        _cachedOrgType = company?['org_type'] as String?;
        _cachedEmployeeRole = null;
        _cachedIsEmployeeWithoutRole = false;
      } else {
        final employee = await SupabaseConfig.client
            .from('employees')
            .select('role, company_id')
            .eq('user_id', userId)
            .maybeSingle()
            .timeout(_gateReadTimeout);
        _cachedEmployeeRole = employee?['role'] as String?;
        final companyId = employee?['company_id'] as String?;
        // G1: an employee LINKED to a company but not yet given a role. The
        // company_id test matters — a self-signup that has not chosen a
        // company yet is a different state with its own screen.
        _cachedIsEmployeeWithoutRole =
            employee != null &&
            companyId != null &&
            _cachedEmployeeRole == null;
        if (companyId == null) {
          _cachedOrgType = null;
        } else {
          final company = await SupabaseConfig.client
              .from('companies')
              .select('org_type')
              .eq('id', companyId)
              .maybeSingle()
              .timeout(_gateReadTimeout);
          _cachedOrgType = company?['org_type'] as String?;
        }
      }
      _portalGateFieldsLoaded = true;
      _portalGateFetchedAt = DateTime.now();
      _portalGateUserId = userId;
      _portalGateFailedAt = null;
    } catch (e) {
      // Stamped so the next navigation does not pay the timeout again. The
      // fields stay null, so the guard still falls back to `/home` as its own
      // doc says — it just stops doing so six seconds at a time.
      _portalGateFailedAt = DateTime.now();
      _portalGateUserId = userId;
      _logger.w('Failed to refresh portal gate fields: $e');
    }
  }

  /// True when [path] is [prefix] itself or a deeper path under it
  /// (`/portal/mine` matches `/portal/mine/live-map` but not
  /// `/portal/minerals`).
  static bool _pathInPortalSection(String path, String prefix) =>
      path == prefix || path.startsWith('$prefix/');

  static final router = GoRouter(
    // The deep link the browser was opened at, if there was one. `/login` is
    // the fallback for an ordinary open, and the redirect below still runs on
    // whichever of the two this is — an already-signed-in user opening `/login`
    // is sent on, and a signed-out user opening a deep link is bounced to
    // `/login?from=…` and returned here after signing in.
    initialLocation: capturedInitialLocation ?? '/login',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _refreshListenable,
    redirect: (context, state) async {
      final currentUser = SupabaseConfig.client.auth.currentUser;
      final isLoggedIn = currentUser != null;
      final currentPath = state.uri.path;
      final isPublicRoute = _publicPaths.contains(currentPath);
      final isSuperAdminRoute = currentPath.startsWith('/super-admin');

      if (!isLoggedIn) {
        clearProfileGateCache();
        if (!isPublicRoute) {
          // Carry where they were going. On the web this branch runs on EVERY
          // cold load of a deep link — the browser hands go_router the real
          // URL, but `Supabase.auth` restores the persisted session
          // asynchronously, so the first redirect pass always sees a signed-out
          // user. Without this the destination was thrown away and, once the
          // session arrived, the `/login` branch below sent everyone to `/home`
          // regardless of what they had opened.
          //
          // Reproduced against the release build: opening
          // `#/portal/mine/production` in a fresh tab landed on the mine
          // dashboard. Every bookmark, every shared link and every deep link
          // out of an email behaved the same way — S7-6.
          final target = state.uri.toString();
          _logger.d('Redirecting anonymous user to /login from $currentPath');
          return Uri(
            path: '/login',
            queryParameters: {kReturnToKey: target},
          ).toString();
        }
        return null;
      }

      if (isLoggedIn && _cachedProfileUserId != currentUser.id) {
        clearProfileGateCache();
      }

      final needsProfileGate =
          (_cachedPlatformRole == null ||
          isSuperAdminRoute ||
          currentPath == '/mandatory-password-change' ||
          currentPath == '/login' ||
          currentPath == '/forgot-password');
      if (isLoggedIn && needsProfileGate) {
        await _refreshProfileGateFields(currentUser.id);
      }

      if (isLoggedIn &&
          (currentPath == '/login' || currentPath == '/forgot-password')) {
        final isAdmin = _cachedPlatformRole == 'superGlobalSerialAdminMain';

        // G3 (S2-9) FIRST, and deliberately ahead of the deep link: a
        // mandatory password change must not be bypassable by arriving with a
        // `?from=`. (Every user, not only company accounts — see
        // `app_access_gates.dart` for why the old `userType == 'company'`
        // clause was the smaller half of this gate. Platform admins are
        // exempt, as they already were.)
        if (!isAdmin && _cachedMustChangePassword) {
          return '/mandatory-password-change';
        }

        // Then honour the deep link that was interrupted, if there was one and
        // it is a safe in-app path. Every guard below still applies to it — an
        // employee who deep-links a route their role does not own is bounced
        // by the role guard exactly as if they had typed it while signed in.
        final returnTo = safeReturnTo(state.uri.queryParameters[kReturnToKey]);
        if (returnTo != null) {
          _logger.d('Resuming interrupted deep link to $returnTo');
          return returnTo;
        }

        if (isAdmin) {
          _logger.d(
            'Redirecting super admin to /super-admin from $currentPath',
          );
          return '/super-admin';
        }
        _logger.d('Redirecting authenticated user to /home from $currentPath');
        return '/home';
      }

      if (isLoggedIn && currentPath == '/mandatory-password-change') {
        final isPlatformAdmin =
            _cachedPlatformRole == 'superGlobalSerialAdminMain';
        final needsMandatory = _cachedMustChangePassword;
        if (isPlatformAdmin || !needsMandatory) {
          return isPlatformAdmin ? '/super-admin' : '/home';
        }
      }

      if (isLoggedIn && !isSuperAdminRoute) {
        // G3 (S2-9). Was company-accounts-only, and skipped every public
        // path — which meant `/whatsapp-otp` and `/reset-password` sat
        // outside it. `mandatoryPasswordRedirect` keeps sign-out and password
        // recovery reachable by name rather than by "it happens to be public".
        final pwd = mandatoryPasswordRedirect(
          path: currentPath,
          mustChangePassword: _cachedMustChangePassword,
          isPlatformAdmin: _cachedPlatformRole == 'superGlobalSerialAdminMain',
        );
        if (pwd != null && currentPath != '/login') return pwd;
      }

      if (isLoggedIn && currentPath == '/home') {
        if (_cachedPlatformRole == 'superGlobalSerialAdminMain') {
          _logger.d('Redirecting super admin away from /home to /super-admin');
          return '/super-admin';
        }

        // `/home` is a landing ADDRESS, not a destination, and it was the only
        // one that never went anywhere. The super admin above has been sent on
        // to their console since this guard was written; everybody else was
        // left on it — and `/home` renders `EmployeeDashboardTab`, four
        // identity cards (Role · Company · Status · Alerts) and two chips.
        //
        // Measured, not assumed: NO role's tree in `portal_nav.dart` names
        // `/home`. Every tree's first leaf is a real screen. So the first thing
        // every company user saw after signing in was a screen that is not a
        // navigation destination, with the rail beside it highlighting
        // "Dashboard" and the real dashboard — the tons-out trend, the
        // stockpile ring, the action queue — one address away and unvisited.
        //
        // `portalLandingRoute` reads the same tree the rail renders, so the
        // landing cannot drift from the navigation, and each role lands where
        // they work: the gate for a guard, the weighbridge for a controller.
        if (shouldRefreshPortalGate(
          loaded: _portalGateFieldsLoaded,
          fetchedAt: _portalGateFetchedAt,
          cachedUserId: _portalGateUserId,
          currentUserId: currentUser.id,
          now: DateTime.now(),
          failedAt: _portalGateFailedAt,
        )) {
          await _refreshPortalGateFields(currentUser.id);
        }
        final landingOrg = OrgType.tryParse(_cachedOrgType);
        // An employee with no role assigned is handled by `noRoleRedirect`
        // above and must not be given a tree — that was the escalation closed
        // in `f9add87`. A company account carries no employee role by design
        // and gets its org's full tree, which is why the role is passed
        // through as-is rather than being required non-null.
        if (landingOrg != null && !_cachedIsEmployeeWithoutRole) {
          final landing = portalLandingRoute(
            orgType: landingOrg,
            role: UserRole.tryParse(_cachedEmployeeRole),
          );
          _logger.d('Landing ${landingOrg.name} session on $landing');
          return landing;
        }
        // Org type unknown — a cold cache, or a user not linked to a company.
        // Falling through leaves them on `/home`, which still renders the
        // workspace shell and its "link to a company" state. That is the right
        // outcome for an unlinked user and a harmless one frame for the rest.
      }

      if (isLoggedIn && isSuperAdminRoute) {
        if (_cachedPlatformRole != 'superGlobalSerialAdminMain') {
          _logger.w('Non-admin user tried to access super admin route');
          return '/home';
        }
      }

      final isPlatformAdmin =
          _cachedPlatformRole == 'superGlobalSerialAdminMain';
      if (isLoggedIn && isPlatformAdmin) {
        if (currentPath == NotificationsInboxRoute.portalPath) {
          return NotificationsInboxRoute.superAdminPath;
        }
        if (currentPath == NotificationsManageRoute.portalPath) {
          final query = state.uri.query;
          return query.isEmpty
              ? NotificationsManageRoute.superAdminPath
              : '${NotificationsManageRoute.superAdminPath}?$query';
        }
      }

      // WhatsApp OTP re-verification gate. Applies only to phone-based users
      // (admin-created WhatsApp users); email-only owners/super admins skip it.
      final phone = currentUser.phone;
      final isOtpUser = phone != null && phone.isNotEmpty && !isPlatformAdmin;
      if (isLoggedIn &&
          isOtpUser &&
          !isPublicRoute &&
          currentPath != '/mandatory-password-change') {
        final lastVerified = await _deviceVerificationStore.lastVerifiedAt();
        if (requiresReverification(lastVerified, DateTime.now())) {
          _logger.d(
            'WhatsApp re-verification required; redirecting to /whatsapp-otp',
          );
          return '/whatsapp-otp';
        }
      }

      // G1 (S2-7) — an employee with no role assigned reaches /profile and
      // nothing else. This needs the portal gate fields on EVERY route, not
      // just `/portal/*`, so the refresh below is hoisted out of that block.
      // `shouldRefreshPortalGate` bounds the cost to one read per 2 minutes.
      if (isLoggedIn &&
          !isPublicRoute &&
          !isPlatformAdmin &&
          (_cachedUserType ?? '') != 'company') {
        if (shouldRefreshPortalGate(
          loaded: _portalGateFieldsLoaded,
          fetchedAt: _portalGateFetchedAt,
          cachedUserId: _portalGateUserId,
          currentUserId: currentUser.id,
          now: DateTime.now(),
          failedAt: _portalGateFailedAt,
        )) {
          await _refreshPortalGateFields(currentUser.id);
        }
        final noRole = noRoleRedirect(
          path: currentPath,
          isEmployeeWithoutRole: _cachedIsEmployeeWithoutRole,
          isPlatformAdmin: isPlatformAdmin,
        );
        if (noRole != null) {
          _logger.w(
            'Blocked $currentPath: employee has no role assigned; '
            'falling back to $noRole',
          );
          return noRole;
        }
      }

      // Per-org `/portal/*` prefix guards (phase-2 nav merge §4.2).
      // Platform admins bypass every guard (company-mirror observer mode);
      // everyone else must match the section's org type — or the driver role
      // for `/portal/driver/*`. Unauthorized → `/home` (WT's always-safe
      // role-tab hub), never a hard error.
      if (isLoggedIn &&
          currentPath.startsWith('/portal/') &&
          !isPlatformAdmin) {
        if (shouldRefreshPortalGate(
          loaded: _portalGateFieldsLoaded,
          fetchedAt: _portalGateFetchedAt,
          cachedUserId: _portalGateUserId,
          currentUserId: currentUser.id,
          now: DateTime.now(),
          failedAt: _portalGateFailedAt,
        )) {
          await _refreshPortalGateFields(currentUser.id);
        }
        final String? requiredOrgType =
            _pathInPortalSection(currentPath, '/portal/mine')
            ? OrgType.mineSupplier.name
            : _pathInPortalSection(currentPath, '/portal/buyer')
            ? OrgType.buyer.name
            : _pathInPortalSection(currentPath, '/portal/transporter')
            ? OrgType.transporter.name
            : null;
        if (requiredOrgType != null && _cachedOrgType != requiredOrgType) {
          _logger.w(
            'Blocked $currentPath: org type ${_cachedOrgType ?? 'none'} '
            'does not match required $requiredOrgType; falling back to /home',
          );
          return '/home';
        }
        if (_pathInPortalSection(currentPath, '/portal/driver') &&
            _cachedEmployeeRole != UserRole.driver.name) {
          _logger.w(
            'Blocked $currentPath: user is not a driver; falling back to /home',
          );
          return '/home';
        }

        // G2 / P4-09 — the intra-org role guard. Matching org type was the
        // only check, so any employee could deep-link any route in their org's
        // section: a security guard whose sidebar is two entries could type
        // their way into `/portal/mine/weighbridge`, `/tons-out`,
        // `/reconciliations` or `/employees`.
        //
        // The rule reads the SAME tree the rail renders (P7-07), so the
        // sidebar and the guard cannot disagree about the role model — today
        // they do. Company accounts carry no employee role and keep the full
        // tree; platform admins already bypassed everything above.
        final employeeRole = UserRole.tryParse(_cachedEmployeeRole);
        final orgType = OrgType.tryParse(_cachedOrgType);
        if (requiredOrgType != null &&
            orgType != null &&
            employeeRole != null &&
            (_cachedUserType ?? '') != 'company' &&
            !portalRouteAllowedForRole(
              orgType: orgType,
              role: employeeRole,
              path: currentPath,
            )) {
          _logger.w(
            'Blocked $currentPath: ${employeeRole.name} at '
            '${orgType.name} has no such destination; falling back to /home',
          );
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/whatsapp-otp',
        builder: (context, state) => WhatsAppOtpScreen(
          whatsappNumber: state.uri.queryParameters['number'],
        ),
      ),
      GoRoute(
        path: '/mandatory-password-change',
        builder: (context, state) => const MandatoryPasswordChangeScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          final code = state.uri.queryParameters['code'];
          final resetToken = token ?? code;

          if (resetToken == null || resetToken.isEmpty) {
            _logger.w(
              'No reset token found in URL. Query parameters: ${state.uri.queryParameters}',
            );
            return const ForgotPasswordScreen();
          }

          _logger.i('Reset token found: $resetToken');
          return ResetPasswordScreen(resetToken: resetToken);
        },
      ),
      GoRoute(
        path: '/company-selection',
        builder: (context, state) => const CompanySelectionScreen(),
      ),
      // Fullscreen driver turn-by-turn navigation (spec 2026-07-16 §4) —
      // deliberately outside the portal shell: no sidebar/app-bar chrome.
      //
      // S7-8 / P4-12: outside the shell it also lost the shell's opening
      // switch on `PortalWorkspacePhase`, so a driver whose company had not
      // resolved yet got the navigation screen itself — no chrome, no
      // explanation, and a map with no destination. `PortalPhaseGate` is that
      // switch, without the chrome. The router's prefix and no-role guards
      // already applied here; what was missing was the asynchronous half.
      GoRoute(
        path: '/portal/driver/navigate/:tripId',
        builder: (context, state) => PortalPhaseGate(
          child: DriverNavigationScreen(
            tripId: state.pathParameters['tripId'] ?? '',
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => PortalShellLayout(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeTabBodyScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/account-setup',
            builder: (context, state) => const ProfileSetupScreen(),
          ),
          GoRoute(
            path: '/company-employees',
            builder: (context, state) => const CompanyEmployeesScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: NotificationsManageRoute.path,
            builder: (context, state) {
              final args = NotificationsManageRoute.parse(state);
              return NotificationManagementScreen(
                title: args.title,
                filterRole: args.filterRole,
                isFromAdminTab: args.isFromAdminTab,
              );
            },
          ),
          GoRoute(
            path: '/fleet-management',
            builder: (context, state) => const FleetManagementScreen(),
          ),
          GoRoute(
            path: '/appearance',
            builder: (context, state) => const AppearanceThemeScreen(),
          ),
          // P7-02 (Settings ▾ → Account & security). The screen has existed
          // for a long time but was routed ONLY at
          // `/super-admin/account-security`, so password and session controls
          // were reachable by the two platform admins and by nobody else —
          // not by any of the 116 org users the release is actually for.
          GoRoute(
            path: '/account-security',
            builder: (context, state) => const AccountSecurityScreen(),
          ),
          GoRoute(
            path: '/operations',
            builder: (context, state) => OperationsHubScreen(
              initialTabId: state.uri.queryParameters['tab'],
            ),
          ),
          GoRoute(
            path: '/communications',
            // P4-18. `/communications` and `/messages` both built
            // `MessagesScreen`, so `CommunicationsHubScreen` — 920 lines
            // carrying the whole company **announcements** feature plus room
            // creation — was never instantiated by anything. Direct messaging
            // is unaffected: it keeps `/messages` and the chat dock.
            builder: (context, state) => const CommunicationsHubScreen(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          // Employee dismissal was removed from the product (client ruling,
          // 2026-08-11). `/employee-dismissed` and
          // `/dismissal-management/:employeeId` are gone with it; taking someone
          // off a company is `remove_company_employee`, which resolves them to
          // the same workspace phase as any unlinked user.
          GoRoute(
            path: '/companies/:orgType',
            builder: (context, state) {
              final orgTypeStr =
                  state.pathParameters['orgType'] ?? 'mineSupplier';
              final orgType = OrgType.values.firstWhere(
                (e) => e.name == orgTypeStr,
                orElse: () => OrgType.mineSupplier,
              );
              final title = _getOrgTypeTitle(orgType);
              return CompanyListScreen(orgType: orgType, title: title);
            },
          ),
          GoRoute(
            path: '/companies/:orgType/:companyId/details',
            builder: (context, state) {
              final company = state.extra is CompanyMCP
                  ? state.extra as CompanyMCP
                  : null;
              if (company != null) {
                return CompanyDetailsScreen(company: company);
              }
              final companyId = state.pathParameters['companyId'] ?? '';
              return CompanyDetailsLoaderScreen(companyId: companyId);
            },
          ),
          GoRoute(
            path: '/employees/:companyId',
            builder: (context, state) {
              final companyId = state.pathParameters['companyId'] ?? '';
              final companyName =
                  state.uri.queryParameters['companyName'] ?? 'Company';
              return EmployeeGridScreen(
                companyId: companyId,
                companyName: companyName,
              );
            },
          ),
          GoRoute(
            path: '/employees/:companyId/:employeeId/details',
            // Upgraded (2026-08-03): the legacy details page now opens the
            // full live profile. `extra` (EmployeeMCP) is no longer needed —
            // the profile loads everything live by id.
            builder: (context, state) => EmployeeProfileScreen(
              employeeId: state.pathParameters['employeeId'] ?? '',
              inPortal: false,
            ),
          ),
          GoRoute(
            path: '/chat/:chatRoomId',
            builder: (context, state) {
              final chatArgs = state.extra as ChatScreenArgs?;

              // NOT the dashboard. This used to `return const
              // HomeTabBodyScreen()` when `extra` was absent — so every arrival
              // that did not come from the one tap in the Communications hub
              // (a refresh, a bookmark, a pasted link, a notification deep
              // link) silently got the WORKSPACE under a top bar reading
              // "Chat", and `:chatRoomId` was parsed and thrown away.
              // Photographed in a browser as `roadhaul.admin`, 2026-08-22.
              //
              // `ChatRoomRoute` resolves the room from the id through the same
              // provider the hub reads, so the URL is a real address.
              if (chatArgs == null) {
                return ChatRoomRoute(
                  chatRoomId: state.pathParameters['chatRoomId'] ?? '',
                );
              }

              return ChatScreen(
                chatRoom: chatArgs.chatRoom,
                currentUserId: chatArgs.currentUserId,
                currentUserName: chatArgs.currentUserName,
                currentUserAvatarUrl: chatArgs.currentUserAvatarUrl,
                participants: chatArgs.participants,
              );
            },
          ),
          GoRoute(
            path: '/expired-access',
            builder: (context, state) {
              final args = state.extra as Map<String, String?>?;
              return ExpiredAccessScreen(
                companyName: args?['companyName'],
                reason: args?['reason'],
              );
            },
          ),

          // ── Phase-2 nav merge (design §5, task T2): per-org deep-link
          // aliases onto EXISTING WT screens, guarded by the /portal/* prefix
          // guards in the redirect above. Additive only — every alias renders
          // inside the same portal shell chrome as the /home tabs.

          // Mine / supplier (`/portal/mine/*`)
          GoRoute(
            path: '/portal/mine',
            builder: (context, state) =>
                const MineSupplierPortalDashboardScreen(),
          ),
          GoRoute(
            path: '/portal/mine/live-map',
            builder: (context, state) => const LiveTripMapScreen(),
          ),
          GoRoute(
            path: '/portal/mine/employees',
            builder: (context, state) => const CompanyEmployeesScreen(),
          ),
          GoRoute(
            path: '/portal/mine/employees/:employeeId',
            builder: (context, state) => EmployeeProfileScreen(
              employeeId: state.pathParameters['employeeId'] ?? '',
            ),
          ),
          // P7-32: the shared Employee Register, the company's own copy of
          // the screen the super-admin console opens for it.
          GoRoute(
            path: '/portal/mine/register',
            builder: (context, state) => const PortalEmployeeRegisterScreen(),
          ),
          GoRoute(
            path: '/portal/mine/company',
            builder: (context, state) => const PortalOwnCompanyScreen(),
          ),
          GoRoute(
            path: '/portal/mine/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: '/portal/mine/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          // Phase-2 T4: mine operational glue routes — deep links onto the
          // SAME screens the /home tabs and Operations Hub already render.
          GoRoute(
            path: '/portal/mine/security',
            builder: (context, state) => const SecurityCheckinScreen(),
          ),
          // Gate = the same security screen with the check-out (departure)
          // section leading.
          GoRoute(
            path: '/portal/mine/gate',
            builder: (context, state) =>
                const SecurityCheckinScreen(focusDepartures: true),
          ),
          GoRoute(
            path: '/portal/mine/weighbridge',
            builder: (context, state) => const LoadControllerScreen(),
          ),
          GoRoute(
            path: '/portal/mine/stockpiles',
            builder: (context, state) => const SupervisorViewScreen(),
          ),
          // WT's stockpile drill-down covers the whole mine (order-capped
          // model); the :id segment is accepted for ML-link compatibility but
          // the screen lists every pile.
          GoRoute(
            path: '/portal/mine/stockpiles/:id',
            builder: (context, state) => const StockpileDetailScreen(),
          ),
          GoRoute(
            path: '/portal/mine/minerals',
            builder: (context, state) =>
                const OperationsHubScreen(initialTabId: 'minerals'),
          ),
          GoRoute(
            path: '/portal/mine/loads',
            builder: (context, state) =>
                const OperationsHubScreen(initialTabId: 'loads'),
          ),
          GoRoute(
            path: '/portal/mine/transactions',
            builder: (context, state) =>
                const OperationsHubScreen(initialTabId: 'transactions'),
          ),
          // P7-02: destinations the mine nav tree names that previously had no
          // URL of their own. They were reachable ONLY as an index into the
          // flat tab list at `/home`, which is why 55 of the 64 `/portal/*`
          // routes were unreachable and why nothing in the portal deep-linked,
          // bookmarked or survived a browser refresh. Every one of these
          // renders the same screen the tab did — no new UI here, only an
          // address for UI that already existed.
          GoRoute(
            path: '/portal/mine/production',
            builder: (context, state) => const MineProductionScreen(),
          ),
          GoRoute(
            path: '/portal/mine/quality',
            builder: (context, state) => const MineQualityScreen(),
          ),
          GoRoute(
            path: '/portal/mine/buyers',
            builder: (context, state) => const MineSupplierBuyersDetailScreen(),
          ),
          GoRoute(
            path: '/portal/mine/truck-locations',
            builder: (context, state) =>
                const MineSupplierTruckLocationsScreen(),
          ),
          GoRoute(
            path: '/portal/mine/compliance',
            builder: (context, state) => const ComplianceScreen(),
          ),
          // The Operations Hub landing tab. `minerals`, `loads` and
          // `transactions` above deep-link straight to one of its six tabs;
          // this opens it on its own default. P7-18 gives `security` and
          // `controllerWB` an entry here — they are the only roles authorised
          // to write gate checks, security incidents and weighbridge records,
          // and today they cannot reach the screen at all.
          GoRoute(
            path: '/portal/mine/operations',
            builder: (context, state) => const OperationsHubScreen(),
          ),
          // The searchable/sortable view of the same loads. A separate path
          // rather than `/tons-out/search`, which the `:transporterId` route
          // directly below would otherwise swallow.
          GoRoute(
            path: '/portal/mine/tons-out-search',
            builder: (context, state) => const PortalTonsOutSearchScreen(),
          ),
          GoRoute(
            path: '/portal/mine/tons-out',
            builder: (context, state) => const PortalTonsOutScreen(),
          ),
          GoRoute(
            path: '/portal/mine/tons-out/:transporterId',
            builder: (context, state) => PortalTonsOutScreen(
              transporterId: state.pathParameters['transporterId'],
            ),
          ),
          GoRoute(
            path: '/portal/mine/reconciliations',
            builder: (context, state) => const MineReconciliationsScreen(),
          ),
          GoRoute(
            path: '/portal/mine/requests',
            builder: (context, state) =>
                const BuyerRequestsScreen(isMine: true),
          ),
          GoRoute(
            path: '/portal/mine/locations',
            // Phase-5 T4: combined screen — mine anchor points
            // (mine_locations) + the existing CompanyLocationsSection
            // (company_locations, feeds get_trip_nav_destination).
            builder: (context, state) => const MineLocationsScreen(),
          ),
          // Phase-2 T5/T6: trips list + detail + waybill, WIRED to existing
          // WT data (logisticsSnapshotProvider — the same snapshot the org
          // dashboards render) and the existing waybill flow
          // (showWaybillModal → get_trip_waybill). No ML screens ported.
          GoRoute(
            path: '/portal/mine/trips',
            builder: (context, state) =>
                const PortalTripsScreen(basePath: '/portal/mine/trips'),
          ),
          GoRoute(
            path: '/portal/mine/trips/:id',
            builder: (context, state) => PortalTripDetailScreen(
              tripId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/portal/mine/trips/:id/waybill',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PortalTripWaybillRoute(
                tripId: id,
                child: PortalTripDetailScreen(tripId: id),
              );
            },
          ),

          // Buyer (`/portal/buyer/*`)
          GoRoute(
            path: '/portal/buyer',
            builder: (context, state) => const BuyerPortalDashboardScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/live-map',
            builder: (context, state) => const LiveTripMapScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/employees',
            builder: (context, state) => const CompanyEmployeesScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/employees/:employeeId',
            builder: (context, state) => EmployeeProfileScreen(
              employeeId: state.pathParameters['employeeId'] ?? '',
            ),
          ),
          // P7-32: the shared Employee Register, the company's own copy of
          // the screen the super-admin console opens for it.
          GoRoute(
            path: '/portal/buyer/register',
            builder: (context, state) => const PortalEmployeeRegisterScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/company',
            builder: (context, state) => const PortalOwnCompanyScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          // Phase-2 T4: buyer operational glue routes.
          GoRoute(
            path: '/portal/buyer/requests',
            builder: (context, state) => const BuyerRequestsScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/waybills',
            builder: (context, state) => const BuyerWaybillsScreen(),
          ),
          // Orders fold into the requests screen — WT renders the live order
          // fill (OrderFillLine / orderStockpileProvider) on the buyer's own
          // request cards (design §3 "orders → KEEP-WT (repurpose)").
          GoRoute(
            path: '/portal/buyer/orders',
            builder: (context, state) => const BuyerRequestsScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/transactions',
            builder: (context, state) =>
                const OperationsHubScreen(initialTabId: 'transactions'),
          ),
          // P7-02: buyer destinations that previously had no URL. Same note as
          // the mine block above — an address for screens that already exist.
          GoRoute(
            path: '/portal/buyer/routes',
            builder: (context, state) => const BuyerRoutesMinesScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/loads-value',
            builder: (context, state) => const BuyerLoadsValueScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/truck-locations',
            builder: (context, state) => const BuyerTruckLocationsScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/compliance',
            builder: (context, state) => const ComplianceScreen(),
          ),
          // The searchable/sortable view of the same loads. A separate path
          // rather than `/tons-out/search`, which the `:transporterId` route
          // directly below would otherwise swallow.
          GoRoute(
            path: '/portal/buyer/tons-out-search',
            builder: (context, state) => const PortalTonsOutSearchScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/tons-out',
            builder: (context, state) => const PortalTonsOutScreen(),
          ),
          GoRoute(
            path: '/portal/buyer/reconciliations',
            builder: (context, state) => const BuyerReconciliationsScreen(),
          ),
          // Phase-2 T5/T6: buyer trips + waybill — same wiring as mine (the
          // logistics snapshot is party-scoped; buyer sees its own trips).
          GoRoute(
            path: '/portal/buyer/trips',
            builder: (context, state) =>
                const PortalTripsScreen(basePath: '/portal/buyer/trips'),
          ),
          GoRoute(
            path: '/portal/buyer/trips/:id',
            builder: (context, state) => PortalTripDetailScreen(
              tripId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/portal/buyer/trips/:id/waybill',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PortalTripWaybillRoute(
                tripId: id,
                child: PortalTripDetailScreen(tripId: id),
              );
            },
          ),

          // Transporter (`/portal/transporter/*`)
          GoRoute(
            path: '/portal/transporter',
            builder: (context, state) =>
                const TransporterPortalDashboardScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/live-map',
            builder: (context, state) => const LiveTripMapScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/employees',
            builder: (context, state) => const CompanyEmployeesScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/employees/:employeeId',
            builder: (context, state) => EmployeeProfileScreen(
              employeeId: state.pathParameters['employeeId'] ?? '',
            ),
          ),
          // P7-32: the shared Employee Register, the company's own copy of
          // the screen the super-admin console opens for it.
          GoRoute(
            path: '/portal/transporter/register',
            builder: (context, state) => const PortalEmployeeRegisterScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/company',
            builder: (context, state) => const PortalOwnCompanyScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          // Phase-2 T4: transporter operational glue routes.
          GoRoute(
            path: '/portal/transporter/fleet',
            builder: (context, state) => const FleetManagementScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/trucks-on-route',
            builder: (context, state) => const TrucksOnRouteScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/maintenance',
            builder: (context, state) => const TransporterMaintenanceScreen(),
          ),
          GoRoute(
            // Fleet → Drivers is the transporter's DRIVER ROSTER. It used to
            // build DriverTabScreen — the signed-in user's own personal driver
            // workspace — so a transporter admin opening it saw "Assignment:
            // None" for themselves instead of their three drivers.
            // TransporterDriversScreen still hands a driver their own
            // workspace, so nothing is lost for them.
            path: '/portal/transporter/drivers',
            builder: (context, state) => const TransporterDriversScreen(),
          ),
          // P7-02: transporter destinations that previously had no URL. Same
          // note as the mine block above.
          GoRoute(
            path: '/portal/transporter/routes',
            builder: (context, state) => const TransporterRoutesScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/fuel-costs',
            builder: (context, state) => const FuelCostsScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/truck-locations',
            builder: (context, state) =>
                const TransporterTruckLocationsScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/request-tracking',
            builder: (context, state) =>
                const TransporterRequestTrackingScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/compliance',
            builder: (context, state) => const ComplianceScreen(),
          ),
          // The searchable/sortable view of the same loads. A separate path
          // rather than `/tons-out/search`, which the `:transporterId` route
          // directly below would otherwise swallow.
          GoRoute(
            path: '/portal/transporter/tons-out-search',
            builder: (context, state) => const PortalTonsOutSearchScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/tons-out',
            builder: (context, state) => const PortalTonsOutScreen(),
          ),
          GoRoute(
            path: '/portal/transporter/reconciliations',
            builder: (context, state) =>
                const TransporterReconciliationsScreen(),
          ),
          // Phase-2 T7 (fleet detail): WT exposes per-vehicle detail/edit via
          // FleetManagementScreen's own edit dialog (VehicleDetailsFields) —
          // no standalone vehicle screen. The :id segment is accepted for
          // ML-link compatibility; the screen lists the whole fleet.
          GoRoute(
            path: '/portal/transporter/fleet/:id',
            builder: (context, state) => const FleetManagementScreen(),
          ),
          // Phase-2 T5/T6: transporter trips + waybill — same wiring as mine.
          GoRoute(
            path: '/portal/transporter/trips',
            builder: (context, state) =>
                const PortalTripsScreen(basePath: '/portal/transporter/trips'),
          ),
          GoRoute(
            path: '/portal/transporter/trips/:id',
            builder: (context, state) => PortalTripDetailScreen(
              tripId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/portal/transporter/trips/:id/waybill',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PortalTripWaybillRoute(
                tripId: id,
                child: PortalTripDetailScreen(tripId: id),
              );
            },
          ),
          // Phase-2 T7 (accept / allocate deep-links): WT's route-acceptance
          // flow lives on the transporter dashboard — the "Available routes"
          // marketplace opens showDispatchedRouteDetailSheet, whose
          // "Accept & assign trucks" step selects available trucks
          // (_AssignTrucksDialog) and calls accept_request_dispatch. Neither
          // surface takes a route id parameter (dispatches are listed live
          // from transporterDispatchesProvider), so the ML :routeId segment
          // is accepted for link compatibility and dropped gracefully — the
          // user lands on the marketplace with the pending route visible.
          // NOTE: TransporterRoutesScreen shows only already-accepted routes;
          // the dashboard is the real accept surface, hence the target here.
          GoRoute(
            path: '/portal/transporter/accept-route/:routeId',
            builder: (context, state) => PortalRouteFocusRoute(
              routeId: state.pathParameters['routeId'] ?? '',
              child: const TransporterPortalDashboardScreen(),
            ),
          ),
          // Truck allocation is inseparable from acceptance (same sheet, see
          // above); the post-accept allocation step — assigning drivers to
          // each allocated truck (max 2, or up to 5 via approved
          // driver_limit_requests) — happens per vehicle on
          // FleetManagementScreen via DriverAssignmentDialog
          // (add_vehicle_driver). :routeId is likewise accepted and dropped
          // (the fleet screen lists the whole fleet, not one route).
          GoRoute(
            path: '/portal/transporter/allocate-fleet/:routeId',
            builder: (context, state) => PortalRouteFocusRoute(
              routeId: state.pathParameters['routeId'] ?? '',
              child: const FleetManagementScreen(),
            ),
          ),
          // Phase-5 T8: the transporter sets/moves the trip's final drop-off
          // waypoint (waypoint 6 of the mine-nav sequence) via the
          // set_drop_off_waypoint RPC. Additive bookkeeping only — it never
          // drives TripStatus.
          GoRoute(
            path: '/portal/transporter/drop-off/:tripId',
            builder: (context, state) =>
                DropOffScreen(tripId: state.pathParameters['tripId'] ?? ''),
          ),

          // Driver (`/portal/driver/*`) — the 3-tab driver app shell
          // (Dashboard · Trip · Profile), deep-linked per tab. For driver
          // employees PortalShellLayout renders these bare (the driver app is
          // self-chromed); /portal/driver/navigate/:tripId stays outside the
          // shell entirely (fullscreen nav, defined above).
          GoRoute(
            path: '/portal/driver/home',
            builder: (context, state) => const DriverAppScreen(),
          ),
          GoRoute(
            path: '/portal/driver/trip',
            builder: (context, state) => const DriverAppScreen(initialTab: 1),
          ),
          GoRoute(
            path: '/portal/driver/profile',
            builder: (context, state) => const DriverAppScreen(initialTab: 2),
          ),
          GoRoute(
            path: '/portal/driver/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          // Phase-2 T6: driver waybill — the signed copy via the existing
          // showWaybillModal (get_trip_waybill regenerates it party-scoped on
          // the driver's device), opened over the driver Trip tab.
          GoRoute(
            path: '/portal/driver/trip/:id/waybill',
            builder: (context, state) => PortalTripWaybillRoute(
              tripId: state.pathParameters['id'] ?? '',
              child: const DriverAppScreen(initialTab: 1),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => SuperAdminShellLayout(child: child),
        routes: [
          // The v3 layout from the 2026-08-08 design drop, fed from live data.
          // PROMOTED to the landing route 2026-08-14 by client ruling: it is
          // the design reference (docs/design-reference.md), and until now it
          // sat at /super-admin/dashboard-v2 with NO nav entry pointing at it —
          // reachable only by typing the URL, while every admin landed on the
          // old screen. A reference nobody navigates to is not a reference.
          GoRoute(
            path: '/super-admin',
            builder: (context, state) => const SuperAdminDashboardV2Screen(),
          ),
          // Kept as a redirect, not a second mount: the old path is in browser
          // history and may be bookmarked, and two routes building one screen
          // is exactly the orphan S7-5 forbids.
          GoRoute(
            path: '/super-admin/dashboard-v2',
            redirect: (context, state) => '/super-admin',
          ),
          GoRoute(
            path: '/super-admin/insights/:orgType',
            builder: (context, state) {
              final orgType = state.pathParameters['orgType'] ?? 'transporter';
              // Transporters moved to the v2 overview (2026-08-09
              // "Replacing old views and screens" drop). Buyer and
              // mine/supplier keep the previous layout until their own
              // versions land.
              if (orgType == 'transporter') {
                return const TransportersOverviewV2Screen();
              }
              return SuperAdminOrgInsightsScreen(orgType: orgType);
            },
          ),
          GoRoute(
            path: '/super-admin/insights/:orgType/company/:companyId',
            builder: (context, state) {
              final companyId = state.pathParameters['companyId'] ?? '';
              return SuperAdminCompanyMirrorScreen(companyId: companyId);
            },
          ),
          // Targets — short-term monthly goals and the long-term 12-month
          // cycle, at three scopes. Each scope is its own screen because the
          // chrome differs (nothing to pick, an org type to pick, a company to
          // pick); they share the workspace underneath.
          // The full transporter league, opened from the accent card on the
          // transporters overview. A real route rather than an in-place swap:
          // the console's back button, deep links and the sidebar's active-row
          // matching all key off the path.
          GoRoute(
            path: '/super-admin/insights/transporter/leaderboard',
            builder: (context, state) => const TransporterLeaderboardScreen(),
          ),
          GoRoute(
            path: '/super-admin/targets',
            builder: (context, state) => const TargetsPlatformScreen(),
          ),
          GoRoute(
            path: '/super-admin/targets/org-type',
            redirect: (context, state) =>
                '/super-admin/targets/org-type/transporter',
          ),
          GoRoute(
            path: '/super-admin/targets/org-type/:orgType',
            builder: (context, state) => TargetsOrgTypeScreen(
              orgType: TargetOrgType.parse(state.pathParameters['orgType']),
            ),
          ),
          GoRoute(
            path: '/super-admin/targets/company',
            builder: (context, state) => const TargetsCompanyScreen(),
          ),
          GoRoute(
            path: '/super-admin/targets/company/:companyId',
            builder: (context, state) => TargetsCompanyScreen(
              companyId: state.pathParameters['companyId'],
            ),
          ),
          GoRoute(
            path: '/super-admin/organizations',
            builder: (context, state) {
              // Optional `?status=` deep-link from the dashboard registry cards
              // (`/super-admin/organizations?status=active|expired|suspended`).
              // The screen handles invalid / missing values gracefully.
              final status = state.uri.queryParameters['status'];
              return OrganizationManagementScreen(
                key: ValueKey('orgs:${status ?? 'all'}'),
                initialStatusFilter: status,
              );
            },
          ),
          GoRoute(
            path: '/super-admin/users',
            builder: (context, state) => const PlatformUsersScreen(),
          ),
          GoRoute(
            path: '/super-admin/register-company',
            builder: (context, state) => const RegisterCompanyScreen(),
          ),
          GoRoute(
            path: '/super-admin/organization/:orgId',
            builder: (context, state) {
              final orgId = state.pathParameters['orgId'] ?? '';
              return OrganizationDetailScreen(organizationId: orgId);
            },
          ),
          GoRoute(
            path: '/super-admin/audit-logs',
            builder: (context, state) => const AuditLogsScreen(),
          ),
          GoRoute(
            path: '/super-admin/crash-reports',
            builder: (context, state) => const CrashReportsScreen(),
          ),
          GoRoute(
            path: '/super-admin/account-deactivations',
            builder: (context, state) => const AccountDeactivationsScreen(),
          ),
          GoRoute(
            path: '/super-admin/token-requests',
            builder: (context, state) => const TokenRequestsScreen(),
          ),
          GoRoute(
            path: '/super-admin/token-history',
            builder: (context, state) => const TokenHistoryScreen(),
          ),
          // ML-style deep-link aliases (phase-2 nav merge T8): pure redirects
          // to WT's real super-admin screens. Declared BEFORE the
          // parameterized `/super-admin/requests/:type` route so the literal
          // segments win the match.
          GoRoute(
            path: '/super-admin/requests/mine-transport',
            redirect: (context, state) =>
                '/super-admin/requests/transportation-mine',
          ),
          GoRoute(
            path: '/super-admin/requests/buyer-transport',
            redirect: (context, state) =>
                '/super-admin/requests/transportation-buyer',
          ),
          GoRoute(
            path: '/super-admin/requests/:type',
            // A work queue must never say it is empty when it is not.
            //
            // This parameter matches ANY string, and an unrecognised one fell
            // through `RequestReviewScreen`'s `default` branch to the generic
            // "Requested routes / Requests awaiting review and dispatch"
            // heading, then queried `request_type = '<the typo>'` and rendered
            // "Queue is clear. No requests in this queue yet." Meanwhile the
            // app bar, which resolves titles by `path.contains`, cheerfully
            // read "Requested buyers".
            //
            // So a stale bookmark or a mistyped link showed a platform admin a
            // plausible, correctly-chromed, EMPTY review queue while real
            // requests waited in it. Measured 2026-08-17 with
            // `/super-admin/requests/buyer-requests`: "0 new", "Queue is
            // clear", with two buyer requests pending.
            //
            // Unknown types go to the canonical inbox rather than a dead end:
            // whoever followed the link wanted a queue, and an empty-looking
            // one is the single worst answer to give them.
            redirect: (context, state) =>
                superAdminRequestsRedirect(state.pathParameters['type']),
            builder: (context, state) {
              final type = state.pathParameters['type'] ?? 'transportation';
              // 'transportation-mine' / 'transportation-buyer' split the
              // transportation inbox by requesting-org type (§4 Request 1).
              final origin = switch (type) {
                'transportation-mine' => 'mine',
                'transportation-buyer' => 'buyer',
                _ => null,
              };
              return RequestReviewScreen(
                key: ValueKey('req:$type'),
                requestType: origin == null ? type : 'transportation',
                origin: origin,
              );
            },
          ),
          GoRoute(
            path: '/super-admin/margin-ledger',
            builder: (context, state) => const MarginLedgerScreen(),
          ),
          GoRoute(
            path: '/super-admin/driver-limits',
            builder: (context, state) => const DriverLimitRequestsScreen(),
          ),
          GoRoute(
            path: '/super-admin/recon-tables',
            builder: (context, state) => const ReconTablesScreen(),
          ),
          GoRoute(
            path: '/super-admin/disputes',
            builder: (context, state) => const DisputeInboxScreen(),
          ),
          // ML alias: `/super-admin/tons-out` → the combined recon tables.
          GoRoute(
            path: '/super-admin/tons-out',
            redirect: (context, state) => '/super-admin/recon-tables',
          ),
          GoRoute(
            path: '/super-admin/available-routes',
            builder: (context, state) => const AvailableRoutesScreen(),
          ),
          GoRoute(
            path: '/super-admin/route-marketplace',
            builder: (context, state) => const RouteMarketplaceScreen(),
          ),
          GoRoute(
            path: '/super-admin/chat-links',
            builder: (context, state) => const ChatConnectionsScreen(),
          ),
          GoRoute(
            path: '/super-admin/request-tracking',
            builder: (context, state) => const RequestTrackingScreen(),
          ),
          GoRoute(
            path: '/super-admin/live-map',
            builder: (context, state) => const LiveMapScreen(),
          ),
          GoRoute(
            path: '/super-admin/seat-requests',
            redirect: (context, state) => '/super-admin/token-requests',
          ),
          GoRoute(
            path: '/super-admin/account-security',
            builder: (context, state) => const AccountSecurityScreen(),
          ),
          GoRoute(
            path: '/super-admin/preferences',
            builder: (context, state) => const UserPreferencesScreen(),
          ),
          GoRoute(
            path: '/super-admin/settings',
            builder: (context, state) => const PlatformAdminSettingsScreen(),
          ),
          GoRoute(
            path: '/super-admin/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: '/super-admin/notifications/manage',
            builder: (context, state) {
              final args = NotificationsManageRoute.parse(state);
              return NotificationManagementScreen(
                title: args.title,
                filterRole: args.filterRole,
                isFromAdminTab: args.isFromAdminTab,
              );
            },
          ),
        ],
      ),
    ],
    // Given no errorBuilder, go_router supplies its own — a bare app bar, the
    // raw text "GoException: no routes for location: /...", and a plain "Home"
    // link. That was the app's not-found page until 2026-08-22, and it was the
    // only surface in the product with no design system on it at all.
    //
    // The `no-raw-exception-in-ui` guard could never have caught it: the
    // exception is interpolated inside the go_router package, not inside
    // `lib/`, and the guard greps this repo's own source.
    errorBuilder: (context, state) => RouteNotFoundScreen(
      location: state.uri.toString(),
      onGoBack: () => context.go(notFoundLandingRoute()),
    ),
  );

  /// Where the not-found screen's one action goes.
  ///
  /// A signed-in user's home is NOT `/` — every role has its own landing
  /// route, resolved from the same nav tree the rail renders, and go_router's
  /// default page sent a weighbridge controller to a second dead end. Reads
  /// the redirect's own cached org type and role, so it cannot disagree with
  /// where sign-in would have put them.
  ///
  /// Falls back to `/login` when there is no session, which is correct: a
  /// signed-out user following a stale deep link has nowhere else to be.
  static String notFoundLandingRoute() {
    if (SupabaseConfig.client.auth.currentUser == null) return '/login';
    final org = OrgType.tryParse(_cachedOrgType);
    if (org == null || _cachedIsEmployeeWithoutRole) return '/home';
    return portalLandingRoute(
      orgType: org,
      role: UserRole.tryParse(_cachedEmployeeRole),
    );
  }

  // Helper method to get a user-friendly title for org types
  static String _getOrgTypeTitle(OrgType orgType) {
    switch (orgType) {
      case OrgType.mineSupplier:
        return 'Mines & Suppliers';
      case OrgType.buyer:
        return 'Buyers';
      case OrgType.transporter:
        return 'Transporters';
    }
  }
}

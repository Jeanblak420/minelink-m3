// ============================================================================
// MineLink Technologies — Sidebar Core
// ----------------------------------------------------------------------------
// Shared model + primitives for the alternate sidebar skins (Haul,
// Weighbridge). Zero package dependencies: Flutter SDK + Material icons only.
//
// Vendored from the design drop (`INTEGRATION.md`, 2026-08-07) with two
// deliberate deviations, both required by this repo:
//   1. The drop's token class was called `MlTokens`, which collides with the
//      app-wide design tokens in `lib/core/design/tokens/ml_tokens.dart`. It is
//      `MlSidebarTokens` here. Nothing else was renamed.
//   2. `MlBrand` defaults point at the brand PNGs this repo already ships
//      (`assets/branding/minelink_*`), so no new artwork had to be copied in.
//   3. `MlSidebarUser` carries the profile destination and the quick actions
//      for its hover card. The drop's footer chip was decorative — no tap
//      target and no way to reach the signed-in account from it. Adding the
//      fields to the model the three skins already receive means the glue
//      stays in `console_sidebar_bridge.dart`, which is the only file that
//      knows about routes, exactly as the drop intended.
//
// Which skin renders is a per-user preference — see `ConsoleSidebarSkin` in
// `console_prefs_provider.dart` and the router glue in
// `console_sidebar_bridge.dart`.
// ============================================================================

import 'package:flutter/material.dart';

// The one app import in this file. The footer chip's hover card is shared with
// the portal rail, so it cannot live inside a console-only skin.
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';

// MlSidebarTokens moved to the design-token layer at S5-19 (it is a token
// contract, and the palettes filling it are token tables). Re-exported so
// every existing `import 'minelink_sidebar_core.dart'` keeps resolving it.
export 'package:flutter_application_1/core/design/tokens/ml_sidebar_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_sidebar_tokens.dart';

// ---------------------------------------------------------------------------
// Navigation model
// ---------------------------------------------------------------------------

/// A single destination or expandable group in the sidebar.
///
/// [id] is what comes back through `onSelect` — wire it to your router.
/// Keep ids stable; they're also the keys used by the skins' `badges` maps.
@immutable
class MlNavItem {
  const MlNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.children = const <MlNavItem>[],
    this.section,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<MlNavItem> children;

  /// Optional group heading rendered *above* this item. Skins that don't use
  /// section eyebrows simply ignore it.
  final String? section;

  final bool enabled;

  bool get hasChildren => children.isNotEmpty;

  /// True if this item, or any descendant, matches [query].
  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (label.toLowerCase().contains(q)) return true;
    return children.any((c) => c.matches(q));
  }

  /// A copy containing only descendants matching [query]. Returns null when
  /// nothing in this branch matches.
  MlNavItem? filtered(String query) {
    if (query.trim().isEmpty) return this;
    final q = query.toLowerCase().trim();
    final selfMatch = label.toLowerCase().contains(q);
    final kept = children.where((c) => c.matches(q)).toList();
    if (selfMatch) return this;
    if (kept.isEmpty) return null;
    return MlNavItem(
      id: id,
      label: label,
      icon: icon,
      children: kept,
      section: section,
      enabled: enabled,
    );
  }
}

/// The signed-in user shown in the sidebar footer.
@immutable
class MlSidebarUser {
  const MlSidebarUser({
    required this.name,
    required this.email,
    this.avatarAsset,
    this.online = true,
    this.roleLabel,
    this.onOpenProfile,
    this.actions = const <UserIdentityAction>[],
  });

  final String name;
  final String email;

  /// Optional avatar image. Falls back to the initial letter when null.
  final String? avatarAsset;
  final bool online;

  /// Shown as a pill on the hover card. Null prints no pill rather than an
  /// empty one.
  final String? roleLabel;

  /// Where a click on the footer chip goes. Null leaves the chip inert, which
  /// is what a skin preview or a test fixture wants.
  final VoidCallback? onOpenProfile;

  /// Rows on the hover card. Empty means the card is identity-only.
  final List<UserIdentityAction> actions;

  String get initial =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();

  /// The same person, in the shape the shared flyout speaks.
  UserIdentity get identity => UserIdentity(
        name: name,
        email: email,
        roleLabel: roleLabel,
        avatarUrl: avatarAsset,
        online: online,
      );
}

/// Wraps a skin's footer chip so hovering it shows the identity card and
/// clicking it opens the profile. A no-op passthrough when the bridge gave us
/// no destination and no actions, so the drop's own previews still build.
class MlSidebarUserChip extends StatelessWidget {
  const MlSidebarUserChip({
    super.key,
    required this.user,
    required this.accent,
    required this.child,
  });

  final MlSidebarUser user;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (user.onOpenProfile == null && user.actions.isEmpty) return child;
    return UserIdentityFlyout(
      user: user.identity,
      accent: accent,
      onOpenProfile: user.onOpenProfile,
      actions: user.actions,
      child: child,
    );
  }
}

/// Paths to the four brand PNGs.
///
/// Defaults resolve to the artwork this repo already ships in
/// `assets/branding/` (declared in `pubspec.yaml`); see
/// `lib/core/widgets/minelink_logo.dart` for the same files used by the rest
/// of the app.
@immutable
class MlBrand {
  const MlBrand({
    this.iconOnLight = 'assets/branding/minelink_mark.png',
    this.iconOnDark = 'assets/branding/minelink_mark_white.png',
    this.logoOnLight = 'assets/branding/minelink_logo.png',
    this.logoOnDark = 'assets/branding/minelink_logo_white.png',
    this.consoleLabel = 'SUPER ADMIN CONSOLE',
    this.consoleLabelAccentWords = 1,
    this.logoHeight = classicLogoHeight,
    this.iconSize = classicIconSize,
  });

  /// Brand sizes the classic console rail uses (`_SidebarHeader` in
  /// `super_admin_shell_layout.dart`: `MineLinkLogo(height: 92)` expanded,
  /// `MineLinkMark(size: 38)` collapsed). Every skin renders the lockup at
  /// these by default so the brand reads identically whichever rail is on —
  /// same artwork, same size, same centred placement.
  static const double classicLogoHeight = 92;
  static const double classicIconSize = 38;

  /// Black artwork — for use on *light* surfaces.
  final String iconOnLight;
  final String logoOnLight;

  /// White artwork — for use on *dark* surfaces.
  final String iconOnDark;
  final String logoOnDark;

  /// Strapline under the logo. Set to '' to hide.
  final String consoleLabel;

  /// How many leading words of [consoleLabel] render in the accent colour.
  final int consoleLabelAccentWords;

  /// Height of the expanded lockup and the side of the collapsed mark.
  final double logoHeight;
  final double iconSize;

  /// Chooses artwork by the *sidebar surface* brightness, not the app theme —
  /// a skin can stay dark-panelled inside a light app and still look right.
  String icon({required bool onDarkSurface}) =>
      onDarkSurface ? iconOnDark : iconOnLight;

  String logo({required bool onDarkSurface}) =>
      onDarkSurface ? logoOnDark : logoOnLight;
}

// ---------------------------------------------------------------------------
// The MineLink navigation tree
// ---------------------------------------------------------------------------

/// Every destination currently in the console, in the original order.
/// Section labels group them without moving anything.
///
/// Ids are mapped to real routes in `console_sidebar_bridge.dart`; the test
/// `test/widgets/console_sidebar_nav_map_test.dart` fails if one loses its
/// route, so a renamed destination can't silently dead-end.
class MlNav {
  const MlNav._();

  static const MlNavItem dashboard = MlNavItem(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.grid_view_rounded,
  );

  static const List<MlNavItem> main = <MlNavItem>[
    MlNavItem(
      id: 'insights',
      label: 'Insights',
      icon: Icons.insights_rounded,
      section: 'Control',
      children: <MlNavItem>[
        MlNavItem(
          id: 'insights.transporters',
          label: 'Transporters',
          icon: Icons.local_shipping_outlined,
        ),
        MlNavItem(
          id: 'insights.buyers',
          label: 'Buyers',
          icon: Icons.work_outline_rounded,
        ),
        MlNavItem(
          id: 'insights.mines',
          label: 'Mines / Suppliers',
          icon: Icons.terrain_rounded,
        ),
        MlNavItem(
          id: 'insights.targets',
          label: 'Targets — platform',
          icon: Icons.track_changes_rounded,
        ),
        MlNavItem(
          id: 'insights.targets-org-type',
          label: 'Targets — by org type',
          icon: Icons.donut_small_rounded,
        ),
        MlNavItem(
          id: 'insights.targets-company',
          label: 'Targets — by company',
          icon: Icons.apartment_rounded,
        ),
      ],
    ),
    MlNavItem(
      id: 'tokens',
      label: 'Tokens & Seats',
      icon: Icons.vpn_key_outlined,
      children: <MlNavItem>[
        MlNavItem(
          id: 'tokens.organizations',
          label: 'Organizations',
          icon: Icons.apartment_rounded,
        ),
        MlNavItem(
          id: 'tokens.requests',
          label: 'Token requests',
          icon: Icons.key_outlined,
        ),
        MlNavItem(
          id: 'tokens.history',
          label: 'Token history',
          icon: Icons.timeline_rounded,
        ),
        MlNavItem(
          id: 'tokens.audit',
          label: 'Audit logs',
          icon: Icons.history_rounded,
        ),
        MlNavItem(
          id: 'platform.crashReports',
          label: 'Crash reports',
          icon: Icons.bug_report_outlined,
        ),
        MlNavItem(
          id: 'platform.accountDeactivations',
          label: 'Account deactivations',
          icon: Icons.person_off_outlined,
        ),
      ],
    ),
    MlNavItem(
      id: 'requests',
      label: 'Requests',
      icon: Icons.assignment_outlined,
      children: <MlNavItem>[
        MlNavItem(
          id: 'requests.mine-transport',
          label: 'Mine/Supplier transport',
          icon: Icons.calendar_month_outlined,
        ),
        MlNavItem(
          id: 'requests.buyer-transport',
          label: 'Buyer transport',
          icon: Icons.alt_route_rounded,
        ),
        MlNavItem(
          id: 'requests.product',
          label: 'Requested product',
          icon: Icons.inventory_2_outlined,
        ),
        MlNavItem(
          id: 'requests.buyers',
          label: 'Requested buyers',
          icon: Icons.person_add_alt_1_outlined,
        ),
        MlNavItem(
          id: 'requests.tracking-logs',
          label: "Request's Tracking Logs",
          icon: Icons.track_changes_rounded,
        ),
        MlNavItem(
          id: 'requests.driver-limits',
          label: 'Transporter Driver limits',
          icon: Icons.groups_outlined,
        ),
      ],
    ),
    MlNavItem(
      id: 'margin-ledger',
      label: 'Margin ledger History',
      icon: Icons.menu_book_outlined,
      section: 'Ledgers',
    ),
    MlNavItem(
      id: 'recon-tables',
      label: 'Recon tables',
      icon: Icons.table_rows_outlined,
    ),
    MlNavItem(
      id: 'disputes',
      label: 'Disputes',
      icon: Icons.gavel_rounded,
    ),
    MlNavItem(
      id: 'routes-available',
      label: 'Available routes',
      icon: Icons.fork_right_rounded,
      section: 'Network',
    ),
    MlNavItem(
      id: 'route-marketplace',
      label: 'Route marketplace',
      icon: Icons.storefront_outlined,
    ),
    MlNavItem(
      id: 'chat-links',
      label: 'Chat links',
      icon: Icons.hub_outlined,
    ),
    MlNavItem(
      id: 'live-map',
      label: 'Live map',
      icon: Icons.my_location_rounded,
    ),
  ];

  static const List<MlNavItem> footer = <MlNavItem>[
    MlNavItem(
      id: 'notifications',
      label: 'Notifications',
      icon: Icons.notifications_none_rounded,
    ),
    MlNavItem(
      id: 'about',
      label: 'About',
      icon: Icons.info_outline_rounded,
    ),
    MlNavItem(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      children: <MlNavItem>[
        MlNavItem(
          id: 'settings.security',
          label: 'Account security',
          icon: Icons.lock_outline_rounded,
        ),
        MlNavItem(
          id: 'settings.preferences',
          label: 'User Preferences',
          icon: Icons.palette_outlined,
        ),
        MlNavItem(
          id: 'settings.platform',
          label: 'Platform settings',
          icon: Icons.tune_rounded,
        ),
      ],
    ),
  ];

  /// Flat list of every id in the tree — handy for route guards and tests.
  static List<String> allIds() {
    final out = <String>[dashboard.id];
    void walk(List<MlNavItem> items) {
      for (final i in items) {
        out.add(i.id);
        walk(i.children);
      }
    }

    walk(main);
    walk(footer);
    return out;
  }
}

// ---------------------------------------------------------------------------
// Token contract
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Shared primitives
// ---------------------------------------------------------------------------

/// Anchors a floating panel to a widget. Used by every skin to show submenus
/// and labels while the sidebar is collapsed to a rail.
///
/// Hand-rolled on [Overlay] + [LayerLink] so it works on older Flutter
/// versions without `OverlayPortal` or `MenuAnchor`.
class MlFlyout extends StatefulWidget {
  const MlFlyout({
    super.key,
    required this.child,
    required this.panelBuilder,
    this.enabled = true,
    this.horizontalGap = 10,
    this.openDelay = const Duration(milliseconds: 90),
    this.closeDelay = const Duration(milliseconds: 140),
  });

  final Widget child;
  final WidgetBuilder panelBuilder;
  final bool enabled;
  final double horizontalGap;
  final Duration openDelay;
  final Duration closeDelay;

  @override
  State<MlFlyout> createState() => MlFlyoutState();
}

class MlFlyoutState extends State<MlFlyout> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _pointerInPanel = false;
  bool _pointerInAnchor = false;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _open() {
    if (!widget.enabled || _entry != null || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.centerRight,
            followerAnchor: Alignment.centerLeft,
            offset: Offset(widget.horizontalGap, 0),
            child: MouseRegion(
              onEnter: (_) => _pointerInPanel = true,
              onExit: (_) {
                _pointerInPanel = false;
                _scheduleClose();
              },
              child: Material(
                type: MaterialType.transparency,
                child: widget.panelBuilder(ctx),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }

  void close() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _scheduleOpen() async {
    await Future<void>.delayed(widget.openDelay);
    if (!mounted) return;
    if (_pointerInAnchor) _open();
  }

  Future<void> _scheduleClose() async {
    await Future<void>.delayed(widget.closeDelay);
    if (!mounted) return;
    if (!_pointerInAnchor && !_pointerInPanel) close();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) {
          _pointerInAnchor = true;
          _scheduleOpen();
        },
        onExit: (_) {
          _pointerInAnchor = false;
          _scheduleClose();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Touch devices get no hover, so long-press toggles the panel.
          onLongPress: () => _entry == null ? _open() : close(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Count pill. Renders tabular figures so 6 and 26 don't jiggle the row.
class MlBadge extends StatelessWidget {
  const MlBadge({
    super.key,
    required this.count,
    required this.tokens,
    this.compact = false,
    this.background,
    this.foreground,
  });

  final int count;
  final MlSidebarTokens tokens;

  /// Rail mode: a dot instead of a number.
  final bool compact;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? tokens.badgeBg;
    final fg = foreground ?? tokens.badgeFg;

    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontFamily: tokens.mono,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontSize: 11.5,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: fg,
        ),
      ),
    );
  }
}

/// Keyboard/pointer wrapper giving every row a visible focus ring and a
/// hover callback, without repeating InkWell boilerplate in each skin.
class MlRowShell extends StatefulWidget {
  const MlRowShell({
    super.key,
    required this.onTap,
    required this.builder,
    required this.tokens,
    this.semanticLabel,
    this.borderRadius,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool hovered, bool focused)
      builder;
  final MlSidebarTokens tokens;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  State<MlRowShell> createState() => _MlRowShellState();
}

class _MlRowShellState extends State<MlRowShell> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.tokens.radius);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: ClipRRect(
            borderRadius: radius,
            child: widget.builder(context, _hovered, _focused),
          ),
        ),
      ),
    );
  }
}

/// Motion helper. Honours the platform "reduce motion" setting so the
/// collapse animation doesn't fight accessibility preferences.
///
/// Collapses to 1ms, never [Duration.zero]: a zero duration makes
/// [AnimationController] bypass the ticker and notify its listeners
/// synchronously, so the nav-group [AnimatedSize] re-dirties itself during its
/// own layout ("A RenderAnimatedSize was mutated in its own performLayout
/// implementation"). 1ms finishes inside the first frame — still instant.
Duration mlMotion(BuildContext context, Duration full) {
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return reduce ? const Duration(milliseconds: 1) : full;
}

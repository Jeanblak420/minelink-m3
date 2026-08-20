import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/shell/workspace_canvas.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

/// **One shell, every audience, every platform.**
///
/// The shipping app had two: `SuperAdminShellLayout` (2,031 lines) and
/// `PortalShellLayout` (763), plus three interchangeable sidebar skins (4,571).
/// Roughly 7,400 lines implementing one idea five times. That is why the
/// console and the portal look like two products — not because anyone chose two
/// looks, but because nothing forced them to be one.
///
/// This widget is deliberately **presentational**. It takes a navigation tree,
/// a selected route, some counts and a child, and it draws chrome. It knows
/// nothing about auth, workspace phases, company mirrors, driver shells or
/// Supabase. Those decisions stay where they were; the two feature shells keep
/// their logic and hand their chrome here. That split is what makes it possible
/// to replace 7,400 lines without touching a single guard.
///
/// ## What "follow the super-admin console's UX" means concretely
///
/// The console's layout is the reference, and every role now gets it:
///
/// - **≥ 840px** — navy rail with labels on the left, top bar across the
///   workspace, content on the dotted canvas capped to a readable width.
/// - **600–839px** — the same rail, collapsed to icons with tooltips and
///   flyout groups. Nothing is removed, only narrowed.
/// - **< 600px** — the rail becomes a modal `NavigationDrawer` behind the menu
///   button, and the tree's top destinations become an M3 `NavigationBar` at
///   the bottom. The driver's Dashboard · Trip · Profile bar was the only
///   place this pattern existed; it is now what every role gets on a phone.
///
/// Because all three read the same tree, a destination cannot exist on one
/// form factor and be missing on another — which it could, and did, when the
/// expanded rail and the collapsed rail were two hand-maintained lists.
class MlAppShell extends StatefulWidget {
  const MlAppShell({
    super.key,
    required this.tree,
    required this.selectedRoute,
    required this.onNavigate,
    required this.child,
    this.title,
    this.subtitle,
    this.badgeCounts = const <MlNavBadge, int>{},
    this.actions = const <Widget>[],
    this.leading,
    this.railHeader,
    this.railFooter,
    this.drawerHeader,
    this.expanded = true,
    this.onExpandedChanged,
    this.floatingActionButton,
    this.overlay,
    this.showCanvasTexture = true,
    this.constrainContent = false,
    this.navEnabled = true,
    this.bottomNavOverride,
  });

  /// The destination tree for this session.
  final List<MlNavNode> tree;

  /// The route on screen.
  final String? selectedRoute;

  final ValueChanged<String> onNavigate;

  /// The routed page.
  final Widget child;

  /// Page title in the top bar. Falls back to the selected leaf's label.
  final String? title;
  final String? subtitle;

  final Map<MlNavBadge, int> badgeCounts;

  /// Top bar trailing actions — notification bell, chat, user chip.
  final List<Widget> actions;

  /// Top bar leading widget (a back button, a home chip). The menu button is
  /// added automatically at compact width and must not be included here.
  final Widget? leading;

  final Widget? railHeader;
  final Widget? railFooter;

  /// Header for the modal drawer. Falls back to [railHeader].
  final Widget? drawerHeader;

  /// Whether the rail shows labels. Ignored below 840px, where the class
  /// decides.
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;

  final Widget? floatingActionButton;

  /// Painted over everything — a tutorial coach-mark layer, a chat dock.
  final Widget? overlay;

  final bool showCanvasTexture;

  /// Whether the SHELL caps and pads the content. **Off by default.**
  ///
  /// `MlPageBody` already does this — a responsive gutter (28 at tablet and
  /// above, 16 below, because 28 on a 360px phone spends 16% of the viewport on
  /// margin) and a 1280 cap — and 46 screens use it. Having the shell do it too
  /// gave every one of those pages a 56dp gutter and capped it twice.
  ///
  /// So the page owns its gutter and the shell owns the canvas. Set this true
  /// only for a page that does not use `MlPageBody` and wants the treatment
  /// anyway.
  final bool constrainContent;

  /// Navigation is inert and visibly dimmed when false.
  ///
  /// This is a real product state, not a styling option: an employee whose role
  /// has not been assigned yet is shown their own record and nothing else, and
  /// handing that user a working destination tree was a privilege escalation
  /// (closed in `f9add87`). Rendering the rail but refusing it is honest — the
  /// user can see that the app has more in it and that they do not have it yet
  /// — where an empty rail reads as a broken app.
  final bool navEnabled;

  /// Replaces the tree-derived bottom bar at compact width.
  ///
  /// A migration seam, and the only divergence left between the two shells. The
  /// driver's phone bar (Dashboard · Trip · Profile) points at
  /// `/portal/driver/{home,trip,profile}`, and the driver's nav tree names the
  /// middle one "My routes" rather than "Trip" and carries Live map and
  /// Compliance between them. Deriving the bar from the tree today would
  /// silently relabel and reorder the driver's primary navigation, which is not
  /// a change to make as a side effect of a shell rewrite. Remove this once the
  /// driver tree is reconciled with the bar (Phase 2).
  final Widget? bottomNavOverride;

  @override
  State<MlAppShell> createState() => _MlAppShellState();
}

class _MlAppShellState extends State<MlAppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _countFor(MlNavNode node) {
    if (node.isGroup) {
      var total = 0;
      for (final leaf in node.leaves) {
        total += _countFor(leaf);
      }
      return total;
    }
    final badge = node.badge;
    if (badge == null) return 0;
    return widget.badgeCounts[badge] ?? 0;
  }

  /// The destinations the bottom bar shows on a phone.
  ///
  /// M3 caps a `NavigationBar` at five; beyond that the labels stop fitting and
  /// the targets stop being reliably tappable. So this takes the first four
  /// top-level destinations and always appends **More**, which opens the full
  /// tree in the drawer. Nothing becomes unreachable — the drawer holds
  /// everything, exactly as the rail does.
  /// The top-level nodes the bottom bar stands for.
  ///
  /// **The node, not its first leaf.** A group keeps its own short label and
  /// icon — "Requests" — and navigates to its first child. Lifting the child
  /// out instead put its full label in the bar, and "Mine/Supplier transport"
  /// wrapped to three lines at 412px, overlapping both neighbours and clipping
  /// at the bottom of the bar. `NavigationBar` does not ellipsize.
  List<MlNavNode> get _bottomDestinations =>
      widget.tree.take(4).toList(growable: false);

  /// Where a bottom destination goes: itself, or its first child.
  String? _bottomRoute(MlNavNode node) =>
      node.isGroup ? node.leaves.first.route : node.route;

  /// A group stays lit while the user is anywhere inside it.
  bool _bottomSelected(MlNavNode node) => node.contains(
        widget.tree.resolveSelected(widget.selectedRoute),
      );

  String get _resolvedTitle =>
      widget.title ?? widget.tree.leafFor(widget.selectedRoute)?.label ?? '';

  @override
  Widget build(BuildContext context) {
    final windowClass = MlWindowClass.of(context);
    final chrome = MlChrome.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final workspace = _Workspace(
      windowClass: windowClass,
      dark: isDark,
      texture: widget.showCanvasTexture,
      constrain: widget.constrainContent,
      // A semantics boundary around the body, and it is not optional.
      //
      // The routed child hosts a nested (ShellRoute) Navigator whose ModalRoute
      // carries `BlockSemantics`, which drops the semantics of everything
      // painted *before* it — and the rail and the top bar paint first, in
      // Row/Column order. Without this boundary the blocking escapes the body
      // and a screen reader cannot see the navigation at all: not one
      // destination, not the menu button, nothing.
      //
      // The console shell had this. The portal shell did not, so every company
      // user — a mine supervisor, a load controller, a driver — had an
      // unreachable rail. It moved here so that fixing it once fixes it for
      // every caller, which is the whole argument for one shell.
      child: Semantics(container: true, child: widget.child),
    );

    final scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: chrome.canvasBase,
      appBar: _buildTopBar(context, windowClass, chrome),
      drawer: windowClass.usesBottomNav ? _buildDrawer(chrome) : null,
      bottomNavigationBar: windowClass.usesBottomNav
          ? (widget.bottomNavOverride ?? _buildBottomBar(context))
          : null,
      floatingActionButton: widget.floatingActionButton,
      body: windowClass.usesRail
          ? Row(
              // STRETCH, not the default centre.
              //
              // `Expanded` expands along the MAIN axis — horizontally here.
              // The cross axis is governed by `crossAxisAlignment`, which
              // defaults to `center`, so the workspace was handed a LOOSE
              // vertical constraint, shrink-wrapped to its content, and was
              // then centred in the leftover space.
              //
              // Measured 2026-08-20 on a 1900px window: the Row was 1828 tall
              // and the workspace inside it 1493, sitting at y=239 with 168px
              // of nothing above it and the same below. Every dashboard floated
              // in the middle of the page, and the taller the monitor the worse
              // it got. Screens whose content already filled the height — the
              // fleet register — looked correct, which is why it survived.
              //
              // The rail always filled, so nothing about the chrome gave it
              // away.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _maybeLock(
                  MlNavRail(
                    tree: widget.tree,
                    selectedRoute: widget.selectedRoute,
                    onNavigate: widget.onNavigate,
                    expanded: windowClass.usesExpandedRail && widget.expanded,
                    badgeCounts: widget.badgeCounts,
                    header: widget.railHeader,
                    footer: widget.railFooter,
                    showSearch: widget.tree.allLeaves.length > 8,
                    onToggleExpanded: windowClass.usesExpandedRail &&
                            widget.onExpandedChanged != null
                        ? () => widget.onExpandedChanged!(!widget.expanded)
                        : null,
                  ),
                ),
                Expanded(child: workspace),
              ],
            )
          : workspace,
    );

    if (widget.overlay == null) return scaffold;
    return Stack(children: [scaffold, widget.overlay!]);
  }

  /// Dims and disables [child] when navigation is locked.
  ///
  /// `AbsorbPointer` rather than `IgnorePointer`: the taps must stop here, not
  /// fall through to whatever is painted behind the rail.
  Widget _maybeLock(Widget child) => widget.navEnabled
      ? child
      : Opacity(
          opacity: 0.45,
          child: AbsorbPointer(child: child),
        );

  PreferredSizeWidget _buildTopBar(
    BuildContext context,
    MlWindowClass windowClass,
    MlChrome chrome,
  ) {
    final text = Theme.of(context).textTheme;
    final subtitle = widget.subtitle;
    final compact = windowClass.usesBottomNav;

    // The menu button has to be built explicitly.
    //
    // `AppBar` only inserts the drawer button when `leading` is null — and at
    // compact width this shell always has a leading (the back button). So
    // passing one silently removed the only app-bar affordance for opening
    // navigation. The bottom bar's "More" tab still reached the drawer, so
    // nothing was strictly unreachable, which is exactly why this would have
    // survived a walkthrough: the hamburger is simply absent on a phone and
    // the drawer looks like it was never wired.
    final Widget? leading = compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // `DrawerButton`, not a hand-rolled `IconButton(tooltip: …)`.
              //
              // A tooltip is not a semantics label. Measured on Flutter 3.44.8:
              // an `IconButton` whose only text is its `tooltip` produces a
              // semantics node a screen reader cannot address by that name —
              // `find.bySemanticsLabel` finds nothing, for a bare one in a
              // plain `Scaffold` app bar as much as for this one. So the
              // control that opens navigation on every phone screen announced
              // itself as an unlabelled button. `DrawerButton` is Flutter's
              // widget for this and carries the localised label properly.
              const DrawerButton(),
              if (widget.leading != null) widget.leading!,
            ],
          )
        : widget.leading;

    return AppBar(
      backgroundColor: chrome.topBarSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // The hairline is what separates the bar from the canvas once the theme
      // stops using elevation to do it. M3 drops shadows from the app bar;
      // without a border the bar and the workspace merge on scroll.
      shape: Border(bottom: BorderSide(color: chrome.topBarBorder)),
      titleSpacing: leading == null ? 20 : 8,
      leading: leading,
      // Two icons need room; one leaves the default alone. 112, not 96: the
      // icon-button theme sets a 44dp minimum touch target, so two of them plus
      // their padding is 98 and a 96dp box overflows by 2 — which paints the
      // yellow-and-black bars across the top-left corner of every phone screen.
      leadingWidth: compact && widget.leading != null ? 112 : null,
      automaticallyImplyLeading: leading == null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _resolvedTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: windowClass == MlWindowClass.compact
                ? text.titleMedium
                : text.titleLarge,
          ),
          if (subtitle != null && windowClass != MlWindowClass.compact)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [...widget.actions, const SizedBox(width: 8)],
    );
  }

  Widget _buildDrawer(MlChrome chrome) {
    // Deliberately the rail itself rather than a `NavigationDrawer`. M3's
    // drawer takes a flat destination list and cannot express a group, so
    // using it would mean maintaining a second, flattened copy of the tree —
    // the exact duplication this shell exists to delete. The drawer theme in
    // AppTheme still styles a real NavigationDrawer for anywhere one is used
    // directly.
    return Drawer(
      backgroundColor: chrome.railBottom,
      width: MlNavRail.expandedWidth,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(MlShape.extraLarge),
          bottomRight: Radius.circular(MlShape.extraLarge),
        ),
      ),
      child: _maybeLock(
        MlNavRail(
          tree: widget.tree,
          selectedRoute: widget.selectedRoute,
          badgeCounts: widget.badgeCounts,
          header: widget.drawerHeader ?? widget.railHeader,
          footer: widget.railFooter,
          showSearch: widget.tree.allLeaves.length > 8,
          onNavigate: (route) {
            Navigator.of(context).pop();
            widget.onNavigate(route);
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final destinations = _bottomDestinations;
    final selectedIndex = () {
      for (var i = 0; i < destinations.length; i++) {
        if (_bottomSelected(destinations[i])) return i;
      }
      // Nothing in the bar matches — the user is somewhere reached through
      // "More". Selecting index 0 would lie about where they are, so the
      // More tab carries the selection instead.
      return destinations.length;
    }();

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        if (i == destinations.length) {
          _scaffoldKey.currentState?.openDrawer();
          return;
        }
        final route = _bottomRoute(destinations[i]);
        if (route != null) widget.onNavigate(route);
      },
      destinations: [
        for (final node in destinations)
          NavigationDestination(
            icon: _maybeBadge(node, Icon(node.icon)),
            selectedIcon: Icon(node.selectedIcon ?? node.icon),
            label: node.compactLabel,
            // The full label stays available on long-press, so shortening for
            // the bar never costs the destination its name.
            tooltip: node.label,
          ),
        NavigationDestination(
          icon: _maybeBadgeTotal(const Icon(Icons.menu_rounded)),
          selectedIcon: const Icon(Icons.menu_open_rounded),
          label: 'More',
          tooltip: 'All destinations',
        ),
      ],
    );
  }

  Widget _maybeBadge(MlNavNode node, Widget icon) {
    final count = _countFor(node);
    return count > 0 ? Badge.count(count: count, child: icon) : icon;
  }

  /// The More tab carries the badge for everything the bar cannot show, so a
  /// queue hidden behind it is still visible from the phone's home screen.
  Widget _maybeBadgeTotal(Widget icon) {
    // Everything the bar does not stand for. A bottom destination stands for
    // its whole group, so subtract by group rather than by route — counting
    // routes would re-count every sibling of a shown group's first child as
    // "hidden" and inflate the More badge.
    final shownRoutes = <String>{
      for (final node in _bottomDestinations)
        for (final leaf in node.leaves)
          if (leaf.route != null) leaf.route!,
    };
    var hidden = 0;
    for (final leaf in widget.tree.allLeaves) {
      if (shownRoutes.contains(leaf.route)) continue;
      hidden += _countFor(leaf);
    }
    return hidden > 0 ? Badge.count(count: hidden, child: icon) : icon;
  }
}

/// The canvas plus the content sitting on it.
class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.windowClass,
    required this.dark,
    required this.texture,
    required this.constrain,
    required this.child,
  });

  final MlWindowClass windowClass;
  final bool dark;
  final bool texture;
  final bool constrain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = constrain
        // `Align(topCenter)`, not `Center`. The centring wanted here is
        // HORIZONTAL — cap the content at a readable measure and put it in the
        // middle of the workspace — and `Center` does both axes. See the
        // `layoutBuilder` below, which had the same fault and was the one
        // actually pushing the dashboards down the page.
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: windowClass.contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.all(windowClass.contentPadding),
                child: child,
              ),
            ),
          )
        : child;

    return CustomPaint(
      painter: MlWorkspaceCanvasPainter(dark: dark, texture: texture),
      child: AnimatedSwitcher(
        duration: MlMotion.of(context, MlMotion.enter),
        switchInCurve: MlMotion.curveOf(context, MlMotion.decelerate),
        switchOutCurve: MlMotion.curveOf(context, MlMotion.accelerate),
        // Fade only. The shipping console slid the workspace horizontally on
        // every navigation, which at 1600px is a large surface travelling a
        // long way — the single most common trigger for motion sickness in a
        // desktop app, and the reason M3 moved to a shared-axis fade.
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        // A TOP-ALIGNED stack. `AnimatedSwitcher`'s default `layoutBuilder` is
        // `Stack(alignment: Alignment.center)`, and that centres the workspace
        // VERTICALLY whenever a page is shorter than the window.
        //
        // Measured 2026-08-20: on a 1900px-tall render the three role
        // dashboards and the console dashboard all began 233–265px below the
        // top bar with a matching gap beneath them, while the fleet register —
        // a page long enough to fill the viewport — started at 100 like
        // everything else. Rendering the same dashboard at 1200px, where its
        // content does fill the height, put it back at 100. The gap scaled with
        // the window, which is what gives it away: a page does not float on a
        // laptop and float further on a monitor unless something is centring
        // it.
        //
        // It is worst on exactly the pages that are short — an empty state, a
        // settings page, a small form — where it reads as a rendering fault
        // rather than as a layout choice.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(child.runtimeType.toString() + child.hashCode.toString()),
          child: content,
        ),
      ),
    );
  }
}

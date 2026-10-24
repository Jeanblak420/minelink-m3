import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

/// The navigation rail — one renderer for every audience's tree.
///
/// This replaces the console's hand-built rail (2,031 lines, every destination
/// written **twice**: once for the expanded state and once for the collapsed
/// one) and the three interchangeable "sidebar skins" beside it (a further
/// 4,571 lines implementing the same navigation three more times). It renders
/// any [MlNavNode] tree, so the super-admin console, a mine supervisor and a
/// driver get the same rail with different entries in it.
///
/// ## Why not `NavigationRail`
///
/// Flutter's `NavigationRail` takes a flat `List<NavigationRailDestination>`
/// and has no concept of a section. MineLink's navigation is genuinely nested —
/// the console alone has six groups — and flattening it would either lose the
/// grouping or push every leaf to the top level, which is the fault the portal
/// nav rewrite (P7-01) existed to fix.
///
/// So this is a custom widget wearing M3's clothes rather than M3's widget:
/// the stadium indicator, the outlined-to-filled icon swap on selection, the
/// M3 type scale, `Badge` for counts, and `Durations`/`Easing` for motion. The
/// component theme in `AppTheme` still configures `NavigationRail` for anyone
/// who drops one in — this simply is not one.
/// The rail's **effective** expanded state, published to whatever it contains.
///
/// ## Why this exists
///
/// `MlAppShell` decides whether the rail is expanded from two things — the
/// caller's preference AND the window class:
///
/// ```dart
/// expanded: windowClass.usesExpandedRail && widget.expanded
/// ```
///
/// so on a medium window the rail narrows however the caller set the flag.
/// But `railHeader` and `railFooter` are **pre-built widgets** handed in by
/// that same caller, who set their `expanded` from the preference alone. On a
/// 760px window the shell narrowed the rail to 80dp while `MlRailIdentity`
/// went on building its 280dp layout — an avatar, a name and a role in a Row —
/// inside it. That is the 2px overflow the redesign renders reported at
/// `760x1400`, and it would have been every medium window in the product.
///
/// Two sources of truth for one fact, and the one that was wrong is the one
/// the widgets read. The rail now publishes what it actually did, and the
/// blocks below prefer it to what they were told.
///
/// Absent — a block rendered outside a rail, in a test or in the modal drawer,
/// where the surface is full width — [maybeOf] returns null and the block
/// falls back to its own parameter.
class MlRailScope extends InheritedWidget {
  const MlRailScope({
    super.key,
    required this.expanded,
    required super.child,
  });

  final bool expanded;

  static bool? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MlRailScope>()
      ?.expanded;

  @override
  bool updateShouldNotify(MlRailScope oldWidget) =>
      oldWidget.expanded != expanded;
}

class MlNavRail extends StatefulWidget {
  const MlNavRail({
    super.key,
    required this.tree,
    required this.selectedRoute,
    required this.onNavigate,
    this.expanded = true,
    this.badgeCounts = const <MlNavBadge, int>{},
    this.header,
    this.footer,
    this.onToggleExpanded,
    this.showSearch = true,
    this.width,
    this.wrapLabels = false,
  });

  final List<MlNavNode> tree;

  /// The route currently on screen.
  ///
  /// Resolved against the tree by longest match ([MlNavTree.resolveSelected]),
  /// so a detail page keeps its parent destination lit. Callers pass the raw
  /// location; they do not have to know which of their routes are destinations.
  final String? selectedRoute;

  final ValueChanged<String> onNavigate;

  /// Labels shown beside icons. False renders the 80dp icons-only rail.
  final bool expanded;

  /// Live counts for the queues the tree names.
  final Map<MlNavBadge, int> badgeCounts;

  /// The brand block at the top of the rail.
  final Widget? header;

  /// The user identity block at the bottom.
  final Widget? footer;

  /// Shows the expand/collapse control when non-null.
  final VoidCallback? onToggleExpanded;

  /// Filter box. Suppressed on short trees, where it is pure overhead.
  final bool showSearch;

  /// The expanded width, when the host is not the desktop rail. The phone
  /// drawer passes its own: up to 320dp, as M3 allows.
  final double? width;

  /// Labels may take two lines and rows grow to fit them.
  ///
  /// The phone drawer sets this. At the phone's own text size the drawer
  /// read "Communicatio…", "Account deactivati…", "Margin ledger histo…"
  /// (admin phone audit, 2026-10-24) — menu entries nobody could read in
  /// full. The desktop rail keeps one line.
  final bool wrapLabels;

  /// M3's standard rail width when it shows icons only.
  static const double collapsedWidth = 80;

  /// Below this height the rail scrolls as one list (see [build]).
  static const double compactHeight = 560;

  /// Expanded width. M3 puts an expanded rail between 220 and 360; 280 is what
  /// fits this app's longest label ("Transporter driver limits") at the default
  /// text scale without truncation.
  static const double expandedWidth = 280;

  @override
  State<MlNavRail> createState() => _MlNavRailState();
}

class _MlNavRailState extends State<MlNavRail> {
  /// Groups the user has explicitly opened or closed, by label. A group not in
  /// this map follows the selection — it is open when it holds the current
  /// route. Storing only the *overrides* means navigating into a group opens
  /// it without fighting a user who closed it by hand.
  final Map<String, bool> _groupOverride = <String, bool>{};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The raw location resolved to the destination that owns it.
  String? get _selected => widget.tree.resolveSelected(widget.selectedRoute);

  /// Whether [group] is showing its children.
  ///
  /// Two rules:
  ///
  /// 1. **CLOSED by default.** Ruled by jean, 2026-08-22: *"each of the parents
  ///    in it should also be collapsed by default on all devices and
  ///    platforms"*. This used to be open-by-default, on the reasoning that a
  ///    closed rail "makes the tree look smaller than it is" — which is true,
  ///    and is no longer the trade being made: the mine rail alone opens with
  ///    **five groups and twenty-one destinations** showing at once, which is a
  ///    wall rather than a menu, and the filter box is the tool for finding
  ///    something in it. The matching half is [AppSidebarPrefs], where the rail
  ///    itself now starts collapsed.
  /// 2. **The group holding the current route is still open.** Otherwise the
  ///    rail can be put into a state where nothing is highlighted while you are
  ///    plainly on a page — you lose your place in your own navigation. This is
  ///    not "expanded by default": it is the rail showing you where you are,
  ///    and it opens exactly one group, the one you are standing in. A user's
  ///    explicit override is remembered but overruled while they are inside.
  bool _isOpen(MlNavNode group) {
    if (group.contains(_selected)) return true;
    return _groupOverride[group.label] ?? false;
  }

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

  @override
  Widget build(BuildContext context) {
    final chrome = MlChrome.of(context);
    final expanded = widget.expanded;
    final tree = _query.isEmpty ? widget.tree : widget.tree.filtered(_query);

    final targetWidth = expanded
        ? (widget.width ?? MlNavRail.expandedWidth)
        : MlNavRail.collapsedWidth;

    return _RailLabels(
      wrap: widget.wrapLabels,
      child: AnimatedContainer(
      duration: MlMotion.of(context, MlMotion.expand),
      curve: MlMotion.curveOf(context, MlMotion.standard),
      width: targetWidth,
      decoration: BoxDecoration(gradient: chrome.railGradient),
      // Lay the content out at its TARGET width and clip, rather than letting
      // it reflow against the animating width.
      //
      // Without this the rail overflows for the whole 400ms of an expand: the
      // labels are built the instant `expanded` flips, so a 280dp row is asked
      // to fit an 80dp box and every frame in between. It throws a RenderFlex
      // overflow, and on a debug build paints the yellow-and-black bars down
      // the side of the navigation.
      //
      // Laying out at the target and clipping also gives the better motion —
      // the labels are revealed by the edge travelling across them rather than
      // squashing and popping.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: targetWidth,
          maxWidth: targetWidth,
          child: MlRailScope(
            expanded: expanded,
            child: SafeArea(
              right: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final empty = _query.isNotEmpty && tree.isEmpty;
                  final items = [
                    for (final node in tree)
                      if (node.isGroup)
                        _RailGroup(
                          node: node,
                          expanded: expanded,
                          // A search result is always open: hiding matches
                          // inside a closed group is the same fault as not
                          // matching them at all.
                          open: _query.isNotEmpty || _isOpen(node),
                          selectedRoute: _selected,
                          count: _countFor(node),
                          countFor: _countFor,
                          onToggle: () => setState(() {
                            _groupOverride[node.label] = !_isOpen(node);
                          }),
                          onNavigate: widget.onNavigate,
                        )
                      else
                        _RailTile(
                          node: node,
                          expanded: expanded,
                          selected: node.route == _selected,
                          count: _countFor(node),
                          onTap: () => widget.onNavigate(node.route!),
                        ),
                  ];
                  final chromeTop = [
                    if (widget.header != null) widget.header!,
                    if (expanded && widget.showSearch) _buildSearch(chrome),
                  ];
                  final chromeBottom = [
                    if (widget.onToggleExpanded != null)
                      _CollapseControl(
                        expanded: expanded,
                        onPressed: widget.onToggleExpanded!,
                        chrome: chrome,
                      ),
                    if (widget.footer != null) ...[
                      Divider(
                          height: 1, thickness: 1, color: chrome.railDivider),
                      widget.footer!,
                    ],
                  ];

                  // A SHORT window — a phone held sideways is ~411dp tall —
                  // scrolls the brand, search, items, collapse control and
                  // footer as ONE list. Pinned, those left the items a strip
                  // about one row high that could not be scrolled by hand
                  // (found on the S25, 2026-10-24). Taller windows keep the
                  // pinned layout below.
                  if (box.maxHeight < MlNavRail.compactHeight) {
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ...chromeTop,
                        if (empty)
                          _EmptySearch(chrome: chrome, query: _query)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: items,
                            ),
                          ),
                        ...chromeBottom,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...chromeTop,
                      Expanded(
                        child: empty
                            ? _EmptySearch(chrome: chrome, query: _query)
                            : ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                children: items,
                              ),
                      ),
                      ...chromeBottom,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSearch(MlChrome chrome) {
    // Styled here rather than by the theme: `inputDecorationTheme` is tuned for
    // the workspace, whose field fill is a light slate. Applied on navy it
    // paints a near-white box in the middle of the rail.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: chrome.railLabelSelected),
        cursorColor: chrome.railIconSelected,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: chrome.railIndicator,
          hintText: 'Search',
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: chrome.railLabel),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: chrome.railIcon,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: chrome.railIcon,
                  ),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: const OutlineInputBorder(
            borderRadius: MlShape.pill,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: MlShape.pill,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: MlShape.pill,
            borderSide: BorderSide(color: chrome.railIconSelected, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Carries [MlNavRail.wrapLabels] down to every row without threading it
/// through each constructor.
class _RailLabels extends InheritedWidget {
  const _RailLabels({required this.wrap, required super.child});

  final bool wrap;

  static bool _wrap(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RailLabels>()?.wrap ?? false;

  static int lines(BuildContext context) => _wrap(context) ? 2 : 1;

  /// A row: exactly 48 high on the rail; at least 48, growing for a second
  /// line of label, in the drawer.
  static Widget rowBox(BuildContext context, Widget row) => _wrap(context)
      ? ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: row,
          ),
        )
      : SizedBox(height: 48, child: row);

  @override
  bool updateShouldNotify(_RailLabels old) => old.wrap != wrap;
}

/// One destination.
class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.node,
    required this.expanded,
    required this.selected,
    required this.count,
    required this.onTap,
    this.indent = 0,
  });

  final MlNavNode node;
  final bool expanded;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final chrome = MlChrome.of(context);
    final text = Theme.of(context).textTheme;

    final icon = Icon(
      selected ? (node.selectedIcon ?? node.icon) : node.icon,
      size: 22,
      color: selected ? chrome.railIconSelected : chrome.railIcon,
    );

    final Widget leading = count > 0
        ? Badge.count(count: count, child: icon)
        : icon;

    final tile = Semantics(
      // `container: true` is load-bearing, not decoration. Without it the
      // annotation merges into a neighbouring node instead of creating one, and
      // the destination is simply absent from the semantics tree — a rail that
      // a screen reader cannot enumerate. Caught by
      // portal_scaffold_semantics_test, which walks the tree by label.
      container: true,
      // And the label has to be explicit, because the count has to be spoken.
      // A badge renders "3" beside "Disputes"; read out in tree order that is
      // "Disputes, 3", which is a list position, not a queue size.
      excludeSemantics: true,
      selected: selected,
      button: true,
      label: count > 0 ? '${node.label}, $count pending' : node.label,
      child: InkWell(
        onTap: onTap,
        customBorder: MlShape.pillShape,
        child: Ink(
          decoration: ShapeDecoration(
            color: selected ? chrome.railIndicator : Colors.transparent,
            shape: MlShape.pillShape,
          ),
          child: _RailLabels.rowBox(
            context,
            Row(
              children: [
                SizedBox(width: indent),
                // The selected marker. Deliberately a SHAPE and not only a
                // colour: an indicator distinguishable by hue alone fails
                // WCAG 1.4.1, and roughly one man in twelve cannot separate
                // this cyan from the resting slate on a navy field.
                SizedBox(
                  width: 4,
                  child: selected
                      ? Center(
                          child: Container(
                            width: 3,
                            height: 20,
                            decoration: ShapeDecoration(
                              color: chrome.railActiveBar,
                              shape: MlShape.pillShape,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                leading,
                if (expanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      node.label,
                      maxLines: _RailLabels.lines(context),
                      overflow: TextOverflow.ellipsis,
                      style: (selected ? text.labelLarge : text.bodyMedium)
                          ?.copyWith(
                            color: selected
                                ? chrome.railLabelSelected
                                : chrome.railLabel,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: expanded
          ? tile
          // Collapsed: the label has nowhere to render, so it has to be
          // reachable some other way or the rail is a column of unlabelled
          // glyphs.
          : Tooltip(message: node.label, child: tile),
    );
  }
}

/// A section header plus its children.
///
/// Expanded, it is an in-place disclosure. Collapsed, it is a `MenuAnchor`
/// flyout — chosen over a hand-rolled overlay because it brings dismissal on
/// outside tap and on Escape, focus traversal and screen-reader semantics with
/// it, all of which the console's hand-built flyouts had to implement and
/// mostly did not.
class _RailGroup extends StatelessWidget {
  const _RailGroup({
    required this.node,
    required this.expanded,
    required this.open,
    required this.selectedRoute,
    required this.count,
    required this.countFor,
    required this.onToggle,
    required this.onNavigate,
  });

  final MlNavNode node;
  final bool expanded;
  final bool open;
  final String? selectedRoute;
  final int count;
  final int Function(MlNavNode) countFor;
  final VoidCallback onToggle;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final chrome = MlChrome.of(context);
    final text = Theme.of(context).textTheme;
    final holdsSelection = node.contains(selectedRoute);

    if (!expanded) {
      return MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(chrome.railBottom),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(MlShape.shapeMedium),
          side: WidgetStatePropertyAll(BorderSide(color: chrome.railDivider)),
        ),
        menuChildren: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              node.label.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: chrome.railSectionLabel,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final child in node.children)
            SizedBox(
              width: 260,
              child: _RailTile(
                node: child,
                expanded: true,
                selected: child.route == selectedRoute,
                count: countFor(child),
                onTap: () => onNavigate(child.route!),
              ),
            ),
        ],
        builder: (context, controller, _) => _RailTile(
          node: node,
          expanded: false,
          selected: holdsSelection,
          count: count,
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            expanded: open,
            label: count > 0
                ? '${node.label}, $count pending'
                : node.label,
            child: InkWell(
              onTap: onToggle,
              customBorder: MlShape.pillShape,
              child: Ink(
                decoration: ShapeDecoration(
                  // A group holding the current route is tinted only when it is
                  // CLOSED. Open, its selected child already carries the
                  // indicator, and two indicators in one column read as two
                  // selections.
                  color: holdsSelection && !open
                      ? chrome.railIndicator
                      : Colors.transparent,
                  shape: MlShape.pillShape,
                ),
                child: _RailLabels.rowBox(
                  context,
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        node.icon,
                        size: 22,
                        color: holdsSelection
                            ? chrome.railIconSelected
                            : chrome.railIcon,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          node.label,
                          maxLines: _RailLabels.lines(context),
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge?.copyWith(
                            color: holdsSelection
                                ? chrome.railLabelSelected
                                : chrome.railLabel,
                          ),
                        ),
                      ),
                      // The sum of the children's queues, shown whether the
                      // group is open or shut. Open, it duplicates numbers
                      // visible just below it — but it is the only figure that
                      // survives the group being scrolled past or collapsed,
                      // and a queue that disappears depending on a disclosure
                      // state is a queue that gets missed.
                      if (count > 0) ...[
                        Badge.count(count: count),
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: MlMotion.of(context, MlMotion.stateChange),
                        curve: MlMotion.curveOf(context, MlMotion.standard),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: chrome.railIcon,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          // Never Duration.zero: with a zero duration AnimationController
          // notifies synchronously and AnimatedSize calls markNeedsLayout()
          // inside its own performLayout, which throws. MlMotion.reducedFloor
          // is 1ms for exactly this reason.
          duration: MlMotion.of(context, MlMotion.stateChange),
          curve: MlMotion.curveOf(context, MlMotion.standard),
          alignment: Alignment.topCenter,
          child: open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in node.children)
                      _RailTile(
                        node: child,
                        expanded: true,
                        selected: child.route == selectedRoute,
                        count: countFor(child),
                        indent: 16,
                        onTap: () => onNavigate(child.route!),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _CollapseControl extends StatelessWidget {
  const _CollapseControl({
    required this.expanded,
    required this.onPressed,
    required this.chrome,
  });

  final bool expanded;
  final VoidCallback onPressed;
  final MlChrome chrome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Align(
        alignment: expanded ? Alignment.centerRight : Alignment.center,
        child: IconButton(
          tooltip: expanded ? 'Collapse navigation' : 'Expand navigation',
          onPressed: onPressed,
          icon: Icon(
            expanded
                ? Icons.keyboard_double_arrow_left_rounded
                : Icons.keyboard_double_arrow_right_rounded,
            color: chrome.railIcon,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.chrome, required this.query});

  final MlChrome chrome;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: chrome.railIcon, size: 28),
          const SizedBox(height: 10),
          Text(
            'Nothing here matches “$query”',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: chrome.railLabel),
          ),
        ],
      ),
    );
  }
}

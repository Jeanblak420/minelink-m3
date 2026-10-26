import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/shell/workspace_canvas.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The height the compact bottom navigation bar occupies, above the safe area.
///
/// Material 3's default for `NavigationBar`, which is what this app gets: the
/// theme deliberately sets **no** height (see the note in `app_theme.dart`) so
/// a label that has to wrap is not clipped, and a null height falls through to
/// the M3 default rather than to something that grows.
///
/// It is named here because something OUTSIDE the `Scaffold` needs it. The
/// Scaffold reserves the bar for its own body automatically, so nothing inside
/// has to know — but the chat dock wraps the whole shell, and without this it
/// parked its launcher **on top of the bar**: measured on a 412x915 phone
/// viewport in a browser, the disc covered 68% of the width of the fifth
/// destination, which is "More" and is the only way to the drawer. No render
/// showed it because the render harness does not mount the dock.
///
/// `test/widgets/bottom_bar_reserve_test.dart` measures a real `NavigationBar`
/// under this app's theme and fails if this number stops being the truth —
/// which is what would happen the moment somebody sets a height in the theme
/// again.
const double kMlBottomNavHeight = 80.0;

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
    // Matches `UiPrefs.canvasTexture`, which went to false on 2026-08-20 —
    // every design reference page is a single flat colour. The console shell
    // passes the user's preference; this default is what a caller that has no
    // preference to pass gets, and it must not disagree with the one that does.
    this.showCanvasTexture = false,
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
  /// The fewest destinations the bar will ever show, before **More**. Two is
  /// Material 3's own floor for a `NavigationBar`; below that it is not a bar.
  static const int _minBottomDestinations = 2;

  /// The most, per the M3 cap of five tiles including More.
  static const int _maxBottomDestinations = 4;

  /// `NavigationBar` clamps its own label scaling here
  /// (`_kMaxLabelTextScaleFactor` in Flutter's `navigation_bar.dart`), so a
  /// reader at 2.0 gets 1.3 and this is the widest a label can ever be.
  static const double _labelScaleCeiling = 1.3;

  List<MlNavNode> _bottomDestinations(BuildContext context) {
    final all = widget.tree
        .take(_maxBottomDestinations)
        .toList(growable: false);
    if (all.length <= _minBottomDestinations) return all;

    // FEWER DESTINATIONS, NOT SMALLER OR SHORTER WORDS.
    //
    // Photographed on a real SM-G780G on 2026-08-22, signed in as the platform
    // admin: the console's bar read
    //
    //     Dashboar
    //     d
    //
    // — one word broken between two letters, which reads as a corrupted string
    // rather than a destination. `bottom_nav_labels_test.dart` already forbids
    // exactly that, and it did not catch this one for two reasons, both of them
    // the "a check you have not sabotaged" trap in a new costume: it swept text
    // scales 1.0 and 1.3 and nothing between, and it deliberately switched the
    // one-word rule OFF at 1.3. Measured across every tree this product builds,
    // the first break at 412px is at scale 1.2, and the band 1.05–1.2 was
    // unswept.
    //
    // The old comment argued that abbreviating was worse than wrapping, and it
    // was right — "Dashboard", "Operations", "Stockpiles" and "Production" are
    // ordinary words with no honest short form, and a `shortLabel` for each
    // would cost more than it bought. But those were not the only two options.
    // The bar's problem is that five fixed tiles across 412px give each label
    // 82px whatever the reader's type size, so the FOURTH destination is what
    // does not fit — not the words.
    //
    // So the count adapts instead. Three destinations plus More is 103px a
    // tile, two is 137px, and the destination that steps out is still one tap
    // away in the drawer with its badge folded into More's — which is what
    // More has always been for. Nothing is renamed, nothing shrinks, and a
    // reader who turned their type size up gets larger text rather than a
    // broken word.
    //
    // The arithmetic is exact rather than a fudge factor: Flutter lays each
    // destination out in an `Expanded` (so a tile is exactly `width / n`) and
    // the label carries `EdgeInsets.only(top: 4)` — no horizontal padding at
    // all. If that ever stops being true the sweep in
    // `bottom_nav_labels_test.dart` is what says so.
    final width = MediaQuery.sizeOf(context).width;
    for (var n = all.length; n > _minBottomDestinations; n--) {
      final slot = width / (n + 1); // +1 for More
      final labels = [
        ...all.take(n).map((node) => node.compactLabel),
        _moreLabel,
      ];
      if (labels.every((l) => _labelWidth(context, l) <= slot)) {
        return all.take(n).toList(growable: false);
      }
    }
    return all.take(_minBottomDestinations).toList(growable: false);
  }

  /// How wide [text] paints in the bar's label style, at the reader's own text
  /// scale and bold-text setting.
  ///
  /// Measured against the SELECTED style as well as the resting one and the
  /// wider of the two taken: M3 gives the selected destination its own
  /// `labelTextStyle`, and the selected label is the one that was broken in
  /// the photograph.
  double _labelWidth(BuildContext context, String text) {
    final theme = Theme.of(context);
    final resolver = theme.navigationBarTheme.labelTextStyle;
    final styles = <TextStyle?>[
      resolver?.resolve(<WidgetState>{}) ?? theme.textTheme.labelMedium,
      resolver?.resolve(<WidgetState>{WidgetState.selected}) ??
          theme.textTheme.labelMedium,
    ];
    // `Text` merges FontWeight.bold itself when the platform asks for bold
    // text, so a TextPainter that ignored it would under-measure for exactly
    // the readers most likely to overflow.
    final bold = MediaQuery.boldTextOf(context);
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _labelScaleCeiling);

    var widest = 0.0;
    for (final style in styles) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: bold
              ? (style ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.bold,
                )
              : style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = widest > painter.width ? widest : painter.width;
      painter.dispose();
    }
    return widest;
  }

  /// The drawer tab's label. Named once because [_bottomDestinations] has to
  /// measure it and [_buildBottomBar] has to draw it, and a bar that measured
  /// one string and painted a longer one would be measuring nothing.
  static const String _moreLabel = 'More';

  /// Where a bottom destination goes: itself, or its first child.
  String? _bottomRoute(MlNavNode node) =>
      node.isGroup ? node.leaves.first.route : node.route;

  /// A group stays lit while the user is anywhere inside it.
  bool _bottomSelected(MlNavNode node) =>
      node.contains(widget.tree.resolveSelected(widget.selectedRoute));

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
      pageKey: widget.selectedRoute,
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
      // Keep clear of side system bars. On Android 15+ the app draws edge to
      // edge, and a phone held sideways puts its navigation buttons on the
      // RIGHT: the workspace ran under them, cutting "Complete now" and the
      // chat disc (S25 and the S25-matched emulator, 2026-10-24). Top and
      // bottom are the app bar's and the bottom bar's to handle.
      body: SafeArea(
        top: false,
        bottom: false,
        child: windowClass.usesRail
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
                    onToggleExpanded:
                        windowClass.usesExpandedRail &&
                            widget.onExpandedChanged != null
                        ? () => widget.onExpandedChanged!(!widget.expanded)
                        : null,
                  ),
                ),
                Expanded(child: workspace),
              ],
            )
          : workspace,
      ),
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
      : Opacity(opacity: 0.45, child: AbsorbPointer(child: child));

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

    // ── The phone title gets TWO lines, and the bar grows to hold them ──────
    //
    // A 412px console bar spends 112 on its leading (drawer + back), 96 on its
    // two actions and 16 on title spacing, leaving the title **180px**. The
    // render harness used to pass the literal `'Global Admin'`, which fits, so
    // 218 pictures said this was fine. The app resolves
    // `Global Admin · Dashboard` — and once the harness was made to resolve the
    // title the same way the app does, the very first run reported it cut:
    //
    //     CUT OFF [console-phone-dark] 1 string(s) at 412x915:
    //       ~ Global Admin · Dashboard   180px  _AppBarTitleBox
    //
    // It is not one title, either. `Mine/Supplier transport`,
    // `Account deactivations` and `Request tracking logs` are all about that
    // long, and the page title is the one thing on a phone that says where you
    // are — the subtitle is already dropped at this width.
    //
    // Two lines rather than smaller type: shrinking below the type scale is
    // what `type_scale_codemod.py` exists to stop, and an ellipsis on the only
    // label a screen has is worse than a wrap.
    //
    // The toolbar has to grow with it, and with the READER's text scale. The
    // console lets each admin set 0.85–1.3 and the sweeps go to 2.0; two lines
    // of `titleMedium` at 2.0 is ~77px against a 72px bar, which would paint
    // the yellow-and-black overflow bars across the top of every phone screen
    // — the same 2px miss the `leadingWidth` comment above records. So the
    // height is computed from the style and the scale rather than assumed, and
    // it never goes BELOW the token.
    final compactTitleStyle = text.titleMedium;
    final compactLine =
        (compactTitleStyle?.fontSize ?? 16) *
        (compactTitleStyle?.height ?? 1.25);
    final textScaler = MediaQuery.textScalerOf(context);
    final compactToolbarHeight = math.max(
      MlTokens.appBarHeight,
      textScaler.scale(compactLine) * 2 + 20,
    );

    // ── …and when even two lines cannot hold a WORD, the title gets its own
    //    row: Material 3's medium top app bar ──────────────────────────────
    //
    // Two lines fix the titles that are long; they do nothing for the ones
    // whose single longest word is wider than the column the title is given.
    // On Jean's SM-G780G at his raised system font, the Load Controller's
    // bar — drawer, title, FOUR actions — left the title a column narrower
    // than "controller", and Flutter did the only thing it can do with a
    // word that does not fit: it broke it. The bar read
    //
    //     Load co
    //     ntroller
    //
    // and, on the next screen, `Compli` over `ance`. Found on glass on
    // 2026-08-23; every render and every sweep had passed, because none of
    // them ran a phone at that scale with four actions in the bar.
    //
    // Shrinking the type is what `type_scale_codemod.py` forbids, and an
    // ellipsis on the one label that names the screen is worse than a wrap.
    // M3 has a layout for exactly this: the MEDIUM top app bar, whose
    // headline sits on its own full-width row under the icons. So the title
    // is MEASURED against the room it would get beside the icons — with the
    // reader's text scale — and when it would need a second line there, it
    // drops to that row. Short titles keep the 72px bar they have always had.
    //
    // A second line beside the icons was allowed until 2026-10-25. On Jean's
    // S25 Ultra (411dp, system font 1.3) "My profile" sat wrapped between the
    // back arrow and the chat icon, "My" over "profile", while the pages
    // either side carried theirs on the row below — the row reads better.
    //
    // And from 2026-10-26 EVERY phone title takes that row. The measured rule
    // left the short ones in the bar, and on the S25 walk the title jumped
    // page to page: "Quality", "Buyers", "Trips" and "Tons out" beside the
    // icons, "Production", "Stockpiles" and the rest on the row below. One
    // place for the page's name is worth the 40px.
    final titleNeedsOwnRow = compact && _resolvedTitle.trim().isNotEmpty;
    final ownRowStyle = compactTitleStyle;
    final ownRowLines = titleNeedsOwnRow
        ? _lineCount(
            _resolvedTitle,
            style: ownRowStyle,
            scaler: textScaler,
            maxWidth: MediaQuery.sizeOf(context).width - 32,
          )
        : 0;
    final ownRowHeight = titleNeedsOwnRow
        ? textScaler.scale(compactLine) * ownRowLines + 12
        : 0.0;

    if (titleNeedsOwnRow) {
      return AppBar(
        backgroundColor: chrome.topBarSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: MlTokens.appBarHeight,
        shape: Border(bottom: BorderSide(color: chrome.topBarBorder)),
        titleSpacing: leading == null ? 20 : 8,
        leading: leading,
        leadingWidth: widget.leading != null ? 112 : null,
        automaticallyImplyLeading: leading == null,
        // Nothing beside the icons: the headline is the row below.
        title: const SizedBox.shrink(),
        actions: [...widget.actions, const SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(ownRowHeight),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _resolvedTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ownRowStyle,
              ),
            ),
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: chrome.topBarSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: compact ? compactToolbarHeight : null,
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
            // Two on a phone, where the title is the only thing naming the
            // screen and it has 180px to do it in; one everywhere else, where
            // there is a subtitle under it and room beside it.
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: compact ? compactTitleStyle : text.titleLarge,
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

  /// How many lines [text] takes at [maxWidth], unbounded.
  static int _lineCount(
    String text, {
    required TextStyle? style,
    required TextScaler scaler,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: math.max(1, maxWidth));
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return math.max(1, lines);
  }

  Widget _buildDrawer(MlChrome chrome) {
    // Deliberately the rail itself rather than a `NavigationDrawer`. M3's
    // drawer takes a flat destination list and cannot express a group, so
    // using it would mean maintaining a second, flattened copy of the tree —
    // the exact duplication this shell exists to delete. The drawer theme in
    // AppTheme still styles a real NavigationDrawer for anywhere one is used
    // directly.
    // As wide as M3 lets a drawer be (360), less a 56dp strip of the page to
    // tap to close it; at least the rail's own width. With two-line labels
    // that is what keeps every entry readable on a phone.
    final drawerWidth = (MediaQuery.sizeOf(context).width - 56)
        .clamp(MlNavRail.expandedWidth, 320.0);
    return Drawer(
      backgroundColor: chrome.railBottom,
      width: drawerWidth,
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
          width: drawerWidth,
          wrapLabels: true,
          onNavigate: (route) {
            Navigator.of(context).pop();
            widget.onNavigate(route);
          },
        ),
      ),
    );
  }

  /// How tall the bottom bar has to be for the labels it is actually given.
  ///
  /// ## Why this is computed and not a constant
  ///
  /// The theme carried `height: 72`. That is exactly one 16px line of label —
  /// derived: a destination is a 32px indicator, a 4px gap and the label, so
  /// 32 + 4 + 16 = 52, centred in 72 with 10px above and below. It is also the
  /// height at which a `NavigationBar` silently starts destroying words, for
  /// two reasons that compound:
  ///
  ///   1. **`NavigationBar` does not ellipsize.** A label too long for its slot
  ///      wraps. At 360px a five-destination bar gives each label a 72px slot,
  ///      and 72px does not hold "Compliance", "Procurement" or
  ///      "Reconciliation" on one line — 20 labels across 10 of this product's
  ///      trees wrapped, measured 2026-08-20. A wrapped label in a
  ///      fixed-height bar is CLIPPED, not overflowed, so nothing raises.
  ///   2. **72 ignored the text scale**, which this console hands to the user
  ///      (`ConsolePrefs.textScale`, 0.85–1.3). A fixed chrome height under a
  ///      user-controlled type size can only be right at one setting.
  ///
  /// So the bar is sized for **two** lines of the label style at the live text
  /// scale, plus real clearance. Two rather than one because the alternative is
  /// abbreviating "Reconciliation" until it stops naming anything; three is not
  /// allowed — a node whose label needs three lines gets a `shortLabel`, and
  /// `bottom_nav_labels_test.dart` fails until it does.
  double _bottomBarHeight(BuildContext context) {
    const indicator = 32.0; // M3's selected-destination pill
    const gap = 4.0; // indicator → label
    const clearance = 8.0; // above and below, so nothing sits on an edge
    const maxLabelLines = 2;

    final style =
        Theme.of(
          context,
        ).navigationBarTheme.labelTextStyle?.resolve(<WidgetState>{}) ??
        Theme.of(context).textTheme.labelMedium;
    final size = style?.fontSize ?? 12.0;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(size) * (style?.height ?? 1.33);

    return indicator + gap + maxLabelLines * lineHeight + 2 * clearance;
  }

  Widget _buildBottomBar(BuildContext context) {
    final destinations = _bottomDestinations(context);
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
      height: _bottomBarHeight(context),
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
          icon: _maybeBadgeTotal(context, const Icon(Icons.menu_rounded)),
          selectedIcon: const Icon(Icons.menu_open_rounded),
          label: _moreLabel,
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
  Widget _maybeBadgeTotal(BuildContext context, Widget icon) {
    // Everything the bar does not stand for. A bottom destination stands for
    // its whole group, so subtract by group rather than by route — counting
    // routes would re-count every sibling of a shown group's first child as
    // "hidden" and inflate the More badge.
    final shownRoutes = <String>{
      for (final node in _bottomDestinations(context))
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
///
/// ## Why this fades ONE subtree instead of cross-fading two
///
/// It used to wrap the routed child in an `AnimatedSwitcher`. An
/// `AnimatedSwitcher` mounts the OUTGOING and INCOMING subtrees together, in
/// one `Stack`, for the length of the transition — that is how a cross-fade
/// works. Under a go_router `ShellRoute` the routed child hosts the shell's
/// navigator, keyed `GlobalObjectKey(navigatorKey.hashCode)`, and it is the
/// SAME navigator on both sides of a route change. So for the length of every
/// navigation that global key was in the widget tree twice.
///
/// Measured on Jean's SM-G780G, 2026-08-22: seven navigations, seven
/// "Duplicate GlobalKey detected in widget tree" reports, each naming a
/// different `_NavHistoryRecorderState` — a fresh subtree every time — against
/// the same `GlobalObjectKey int#f0d3c`. The framework's own warning is that
/// this truncates parts of the tree.
///
/// A widget test cannot see it: `MlMotion` collapses to about a millisecond
/// under the test binding, so the overlap is gone before the next pump. The
/// handset is the instrument for this one, and the source check in
/// `shell_keeps_the_workspace_in_one_place_test.dart` is what stops it coming
/// back.
///
/// M3's fade-through is SEQUENTIAL anyway — outgoing to zero, then incoming in
/// — not an overlap, so a single-subtree fade is closer to the spec than the
/// cross-fade was, as well as being the only shape compatible with a GlobalKey
/// underneath it.
class _Workspace extends StatefulWidget {
  const _Workspace({
    required this.windowClass,
    required this.dark,
    required this.texture,
    required this.constrain,
    required this.pageKey,
    required this.child,
  });

  final MlWindowClass windowClass;
  final bool dark;
  final bool texture;
  final bool constrain;

  /// What identifies the PAGE for the cross-fade below — the selected route.
  /// See the `AnimatedSwitcher` for why this cannot be derived from [child].
  final String? pageKey;

  final Widget child;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace>
    with SingleTickerProviderStateMixin {
  /// Starts COMPLETE, so the first frame is fully opaque rather than fading
  /// in from nothing on a cold start. The duration here is a placeholder; the
  /// motion-aware one is read in [build], where there is a context.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _Workspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A NAVIGATION, and nothing else. The old cross-fade keyed off the child
    // widget's identity hash and so re-ran on any incidental rebuild.
    if (oldWidget.pageKey != widget.pageKey) {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The motion-aware duration, read here because it needs a context.
    //
    // NEVER Duration.zero, even under reduce-motion: an AnimationController
    // with a zero duration notifies its listeners SYNCHRONOUSLY, and this one
    // is driven from didUpdateWidget — mid-build. 1ms is the house workaround
    // (CLAUDE.md §10.4, where the same trap took out AnimatedSize).
    final motion = MlMotion.of(context, MlMotion.enter);
    _fade.duration = motion > Duration.zero
        ? motion
        : const Duration(milliseconds: 1);

    // FILL THE VIEWPORT, even when the page inside is shorter than it.
    //
    // `Scaffold` lays its body out under a LOOSE height constraint, and on a
    // phone the workspace IS the body (there is no rail Row with
    // `crossAxisAlignment: stretch` to tighten it). Underneath, the
    // fade below is a single child now (it used to be an `AnimatedSwitcher`
    // whose `Stack` was `StackFit.loose`) and `MlPageBody` is a
    // bare `SingleChildScrollView`, so a page whose content does not reach the
    // bottom of the screen shrink-wrapped the whole chain — and the canvas
    // painter, which sizes to its child, stopped painting exactly where the
    // content stopped. Below that line the `Scaffold`'s own `canvasBase`
    // (`#0A1424`) showed through against the canvas's `#060B15`: a hard
    // horizontal seam across the page, at a different height on every screen.
    //
    // Measured 2026-08-21 across the phone renders: **23 of 61** had it,
    // including the driver's Trip screen, the load controller's weighbridge,
    // the margin ledger and the employee register. It is not a test artefact —
    // a 915px handset shows it on any of those pages whose content ends first,
    // and it is invisible on desktop because the rail's `stretch` already
    // tightens the constraint.
    //
    // `minHeight` rather than `SizedBox.expand`, so a genuinely unbounded
    // parent (a workspace nested in a scrollable) is left alone rather than
    // asserting, and so a page TALLER than the viewport still scrolls.
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = _paintedCanvas(context);
        if (!constraints.hasBoundedHeight) return canvas;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: canvas,
        );
      },
    );
  }

  Widget _paintedCanvas(BuildContext context) {
    final content = widget.constrain
        // `Align(topCenter)`, not `Center`. The centring wanted here is
        // HORIZONTAL — cap the content at a readable measure and put it in the
        // middle of the workspace — and `Center` does both axes. See the
        // `layoutBuilder` below, which had the same fault and was the one
        // actually pushing the dashboards down the page.
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.windowClass.contentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.windowClass.contentPadding),
                child: widget.child,
              ),
            ),
          )
        : widget.child;

    return CustomPaint(
      painter: MlWorkspaceCanvasPainter(
        dark: widget.dark,
        texture: widget.texture,
      ),
      // ONE widget.child, faded in place. See the class doc: an AnimatedSwitcher
      // mounts two subtrees at once and the routed widget.child underneath carries
      // go_router's shell-navigator GlobalKey, so a cross-fade put the same
      // global key in the tree twice on every navigation.
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _fade,
          curve: MlMotion.curveOf(context, MlMotion.decelerate),
        ),
        child: content,
      ),
    );
  }
}

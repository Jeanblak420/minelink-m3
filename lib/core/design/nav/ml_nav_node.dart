// ============================================================================
// The navigation tree — one model, every audience.
// ----------------------------------------------------------------------------
// This is `PortalNavNode`, lifted out of `features/portal/nav/portal_nav.dart`
// into `core/design/` so the super-admin console can use it too. The move was
// always the plan; that file's own header says so:
//
//     "`MlNavItem` is close, but it carries no route, and importing it here
//      would point the portal at the console … `PortalNavNode` stays
//      self-contained until that extraction happens and the two can merge from
//      a shared home rather than across a feature boundary."
//
// This is the shared home, and this is that merge. `portal_nav.dart` now
// aliases these types, so nothing that referred to `PortalNavNode` had to
// change.
//
// ## Why it matters more than it looks
//
// The portal's navigation was already *data*: a value you can unit-test, search
// and filter. The console's was not — it was 2,031 lines of hand-built widget
// tree in which every destination appeared **twice**, once for the expanded
// rail and once for the collapsed one, kept in step by hand. That duplication
// is most of why the console shell is the largest file in the app, and it is
// why the console and the portal look like two products: they were not two
// styles of one navigation, they were two navigations.
//
// One model means one renderer (`MlAppShell`), which means the placement of
// everything is identical for a driver on a phone and a platform admin on a
// 32-inch monitor. That is the whole point of the redesign.
//
// The model is deliberately **pure data**: no widgets, no providers, no
// `BuildContext`.
// ============================================================================

import 'package:flutter/material.dart';

/// A live queue whose size a nav leaf displays.
///
/// The tree names the *source*, never a number: this file has no providers and
/// must not acquire any, or it stops being testable as a value. The shell
/// resolves each of these to an integer and sums a group header from its
/// children.
enum MlNavBadge {
  /// Transport / product / buyer requests awaiting this org's action —
  /// `sent_back` items it must resubmit, and its own `requested` items.
  pendingRequests,

  /// Dispatches sent to this transporter that have not been accepted.
  unacceptedDispatches,

  /// Recon disputes open against a transaction this org is party to.
  openDisputes,

  /// Compliance documents expiring inside the reminder window.
  expiringCompliance,

  /// Unread rows in `notifications` for the signed-in user.
  unreadNotifications,

  /// Trucks at the gate awaiting a security check-in.
  arrivalsAwaitingCheckIn,

  /// Trips checked in but not yet weighed by the load controller.
  loadsAwaitingWeigh,

  /// Vehicles with a service schedule due by date or odometer.
  maintenanceDue,
}

/// One entry in a navigation tree: either a **leaf** carrying a route, or a
/// **group** carrying children and no route of its own.
///
/// Groups render as expandable sections when the rail is expanded, as overlay
/// flyouts when it is collapsed, and as a second-level list inside the modal
/// drawer on a phone. A group is never itself a destination — activating the
/// header opens or closes it.
@immutable
class MlNavNode {
  /// A destination. [route] is a real, resolvable path in `app_router.dart`;
  /// there is no such thing as a leaf that goes nowhere, which is what keeps
  /// dead entries out of the rail by construction.
  const MlNavNode.leaf({
    required this.label,
    required this.icon,
    required String this.route,
    this.badge,
    this.selectedIcon,
    this.shortLabel,
  }) : children = const <MlNavNode>[];

  /// A section header with children. Carries no route and no badge of its own —
  /// its badge is the sum of its children's, computed at render time.
  const MlNavNode.group({
    required this.label,
    required this.icon,
    required this.children,
    this.selectedIcon,
    this.shortLabel,
  })  : route = null,
        badge = null;

  final String label;

  /// The label for surfaces with no room for [label] — chiefly the phone's
  /// bottom navigation bar.
  ///
  /// `NavigationBar` does not ellipsize; a long label wraps, and three wrapped
  /// lines in a 72dp bar collide with their neighbours and clip at the bottom.
  /// Measured at 412px: "Mine/Supplier transport" wrapped to three lines and
  /// overlapped both adjacent destinations.
  ///
  /// A separate field rather than truncating [label] automatically, because the
  /// short form is an editorial decision — "Requests", not "Mine/Suppl…".
  /// Defaults to [label] via [compactLabel].
  final String? shortLabel;

  /// [shortLabel] when set, otherwise [label].
  String get compactLabel => shortLabel ?? label;

  final IconData icon;

  /// The filled counterpart drawn when this destination is selected.
  ///
  /// Material 3's navigation components pair an outlined resting icon with a
  /// filled selected one — it is the second signal, after the indicator pill,
  /// that says which destination you are on, and it is the one that still
  /// works for a user who cannot distinguish the indicator's tint. Null means
  /// "use [icon] for both", which is correct for icons that have no filled
  /// twin.
  final IconData? selectedIcon;

  /// The destination path, or null on a group.
  final String? route;

  /// The queue this leaf counts, or null when it has none.
  final MlNavBadge? badge;

  /// Child destinations, empty on a leaf.
  final List<MlNavNode> children;

  bool get isGroup => children.isNotEmpty;

  /// Every leaf at or below this node, in render order.
  Iterable<MlNavNode> get leaves sync* {
    if (!isGroup) {
      yield this;
      return;
    }
    for (final child in children) {
      yield* child.leaves;
    }
  }

  /// True when this node, or any descendant, matches [query].
  ///
  /// The rail's search uses this so a nested destination is findable without
  /// expanding its group first.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    return children.any((c) => c.matches(q));
  }

  /// A copy holding only the descendants that match [query], or null when
  /// nothing in this branch does. A group whose own label matches is returned
  /// whole, so searching "fleet" shows everything under Fleet.
  MlNavNode? filtered(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return this;
    if (label.toLowerCase().contains(q)) return this;
    if (!isGroup) return null;
    final kept = children
        .map((c) => c.filtered(q))
        .whereType<MlNavNode>()
        .toList(growable: false);
    if (kept.isEmpty) return null;
    return MlNavNode.group(
      label: label,
      icon: icon,
      selectedIcon: selectedIcon,
      shortLabel: shortLabel,
      children: kept,
    );
  }

  /// True when [route] is this node's own destination, or any descendant's.
  bool contains(String? route) {
    if (route == null) return false;
    if (this.route == route) return true;
    return children.any((c) => c.contains(route));
  }
}

/// Convenience over a whole tree.
extension MlNavTree on List<MlNavNode> {
  /// Every leaf in the tree, in render order.
  Iterable<MlNavNode> get allLeaves sync* {
    for (final node in this) {
      yield* node.leaves;
    }
  }

  /// The leaf whose route is [route], or null.
  MlNavNode? leafFor(String? route) {
    if (route == null) return null;
    for (final leaf in allLeaves) {
      if (leaf.route == route) return leaf;
    }
    return null;
  }

  /// The tree filtered to [query], dropping branches with no match.
  List<MlNavNode> filtered(String query) => map((n) => n.filtered(query))
      .whereType<MlNavNode>()
      .toList(growable: false);

  /// Which destination [location] belongs to — **longest match wins**.
  ///
  /// A detail page is not itself a destination. `/portal/mine/trips/abc123` has
  /// no rail entry, but the user is unambiguously inside Trips and the rail has
  /// to say so; with exact equality every detail page in the app deselects the
  /// whole rail, and the user loses their place the moment they open a record.
  ///
  /// Longest match, not first match, because the routes genuinely nest:
  /// `/super-admin` is a prefix of every console route, so a first-match rule
  /// would light Dashboard on all thirty of them. Likewise
  /// `/super-admin/requests/buyer` against `/super-admin/requests/buyer-transport`
  /// — a naive `startsWith` collapses two sibling destinations into one, which
  /// is why the boundary is `'$route/'` and not `route`.
  ///
  /// Returns null when [location] is outside the tree entirely, which is
  /// correct: nothing should be lit.
  String? resolveSelected(String? location) {
    if (location == null) return null;
    String? best;
    for (final leaf in allLeaves) {
      final route = leaf.route;
      if (route == null) continue;
      if (location == route || location.startsWith('$route/')) {
        if (best == null || route.length > best.length) best = route;
      }
    }
    return best;
  }
}

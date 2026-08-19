/// The link to a waybill — which route it is, and what to put on the clipboard.
///
/// ## Why this exists
///
/// Four routes render a single waybill:
///
/// ```text
/// /portal/mine/trips/:id/waybill
/// /portal/buyer/trips/:id/waybill
/// /portal/transporter/trips/:id/waybill
/// /portal/driver/trip/:id/waybill          <- singular, and deliberately so
/// ```
///
/// They work and they are party-scoped. But **nothing in the app emitted one.**
/// Every waybill is opened through `showWaybillModal` — from the recon table's
/// WAYBILL NUMBER cell, from the trip detail screen — so the only way to obtain
/// one of these URLs was to know the route shape and the trip's UUID and type
/// it. A route reachability check counts them reachable, which is how they
/// passed: reachable by the router is not the same as reachable by a person.
///
/// So the modal now offers the link, and this is where the link is decided.
///
/// ## Why it only became worth doing today
///
/// Until the S7-6 fix (`initial_location.dart`) a pasted waybill URL was thrown
/// away during boot and landed the recipient on their dashboard. Handing
/// somebody a link that silently goes somewhere else is worse than handing them
/// none, so this affordance would have been a bug before that fix and is a
/// feature after it. The two belong together.
library;

/// The in-app route for [tripId]'s waybill, as seen from [currentPath], or
/// null when the current shell has no waybill route.
///
/// [currentPath] is the location the viewer is on, which is what decides the
/// org segment: a waybill opened from the mine's tons-out table is a mine
/// waybill, and the same trip opened from the buyer's loads table is a buyer
/// one. Both render the same document; they differ in which shell wraps it and
/// which party's scope the RPC answers under.
///
/// **Returns null for the super-admin console**, and that is correct rather
/// than a gap. The combined recon table at `/super-admin/recon-tables` can open
/// the modal, but no `/super-admin/**/waybill` route exists. Synthesising a
/// `/portal/mine/...` URL for an admin would hand them a link into a shell they
/// do not use. No route, no link, and the caller hides the control.
String? waybillRouteFor({required String currentPath, required String tripId}) {
  if (tripId.trim().isEmpty) return null;
  final id = Uri.encodeComponent(tripId.trim());

  // The driver's is `/trip/` singular — the driver shell has one trip at a
  // time and its route was named for that. Getting this wrong yields a 404
  // that only a driver would ever see, so it is spelled out rather than
  // derived.
  if (_inSection(currentPath, '/portal/driver')) {
    return '/portal/driver/trip/$id/waybill';
  }
  for (final org in const ['mine', 'buyer', 'transporter']) {
    if (_inSection(currentPath, '/portal/$org')) {
      return '/portal/$org/trips/$id/waybill';
    }
  }
  return null;
}

bool _inSection(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// What to actually put on the clipboard for [route].
///
/// On the web this is an absolute URL the recipient can paste into a browser.
/// Everywhere else it is the route alone: `Uri.base` in a Windows or Android
/// build is a `file:` URI of the working directory, and pasting
/// `file:///C:/…/#/portal/…` at somebody helps nobody.
///
/// ## The `#`
///
/// This app ships the **hash** URL strategy — no `usePathUrlStrategy()` call
/// anywhere in `lib/` or `web/`, which is the Flutter default and is stated as
/// fact in `initial_location.dart`. So the route lives in the fragment, and a
/// link built without the `#` would resolve to the server's document root and
/// 404 on any host that does not blanket-rewrite to `index.html`.
///
/// [base] is passed in rather than read from `Uri.base` so this is testable.
/// It should be `Uri.base` at the call site.
///
/// **If this app ever adopts the path strategy, this function is what changes**
/// — and `test/core/waybill_link_test.dart` is what will tell you, because it
/// asserts the `#` is present.
String waybillLinkToCopy({
  required Uri base,
  required String route,
  required bool isWeb,
}) {
  if (!isWeb) return route;
  // `Uri.origin` throws on anything that is not http/https, which is every
  // non-web `Uri.base`. Belt and braces alongside `isWeb`.
  if (!base.isScheme('http') && !base.isScheme('https')) return route;

  // `base.path` carries the deployment sub-path when the app is not served
  // from the root — `https://host/app/#/x` gives `/app/`. Keeping it is what
  // makes the copied link work on such a deployment; dropping it would build
  // `https://host/#/x` and miss the app entirely.
  final prefix = base.path.endsWith('/') ? base.path : '${base.path}/';
  return '${base.origin}$prefix#$route';
}

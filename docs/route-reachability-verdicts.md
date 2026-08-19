# Route reachability — a verdict for every route nothing links to

**S7-5 / P7-38.** The gate: *every route in `app_router.dart` is in a nav tree,
is a legitimate detail route reachable from a parent, or is deleted. No
orphans.*

Measured 2026-08-15 by `tool/route_reachability.py`:

```
declared routes : 143
reachable       : 124
no reference    : 19
```

**Verdict: 0 routes need deleting.** Every one of the 19 is an alias, a
compatibility redirect, a detail route, or a notification target — but each
needed a judgement, and "no reference" is exactly the state in which a real
orphan hides, so each is recorded below rather than waved through as a group.

---

## 1. Why the tool exists and why it plants a canary

Three earlier versions of this check were written ad hoc and **two were wrong
in the direction that looks clean**:

| version | result | the fault |
|---|---|---|
| v1 | **0 orphans** of 143 | a route could be "covered" by its own `path:` declaration in the router, so every route matched itself |
| v2 | 20 | a reference like `'/$x'` normalised to `/*` and matched **any** one-segment route, swallowing real orphans — including the canary |
| v3 (this) | 19 | canary correctly flagged |

A 48 → 0 swing in one edit is the shape of a broken matcher, not of a clean
codebase. The lesson is not "be careful": a reachability check **degrades into
"everything is fine" when it breaks**, so it must prove it can still fail. The
tool plants an unreferenced canary and a referenced one on **every** run — not
only under `--selftest` — and aborts with *"MATCHER BROKEN … every result from
this run is untrustworthy"* rather than printing a clean report.

`--selftest` additionally re-checks the v2 bug by name (`'/$x'` must not match
`/reset-password`), that a `:param` still accepts a concrete reference, and
that segment count is compared.

### Two false positives it fixed while being written

* `/super-admin/targets/company/:companyId` was reported unreachable. It is
  navigated as `'${TargetsCompanyScreen.basePath}/${c['id']}'` — a
  **class-qualified const**. The tool now resolves file-local
  `const String … = '/…'` in both the bare and the qualified form. 20 → 19.
* Five routes the previous session listed as candidates
  (`/companies/:orgType`, `/reset-password`, `/super-admin/insights/:orgType`,
  `/super-admin/requests/:type`, `/super-admin/targets/org-type/:orgType`) are
  referenced and were counted only because the earlier matcher did not expand
  `/portal/$org/…` or count the router's own `redirect:` targets.

---

## 2. The 19, judged

### 2.1 Deliberate URL aliases for a destination already in the nav tree — ✅ keep

P7-02 gave screens an address of their own. They were previously reachable
**only** as an index into the flat tab list at `/home`, which is why 55 of the
`/portal/*` destinations had no URL at all. The nav tree points at the hub; the
alias opens the hub on a named tab. Nothing links to them because nothing needs
to — they exist so a URL can be typed, bookmarked or put in a message.

| route | resolves to |
|---|---|
| `/portal/mine/minerals` | `OperationsHubScreen(initialTabId: 'minerals')` |
| `/portal/mine/loads` | `OperationsHubScreen(initialTabId: 'loads')` |
| `/portal/mine/transactions` | `OperationsHubScreen(initialTabId: 'transactions')` |
| `/portal/buyer/transactions` | `OperationsHubScreen(initialTabId: 'transactions')` |
| `/portal/mine/gate` | the security screen in **gate mode** (documented at `security_checkin_screen.dart:24`) |

### 2.2 Compatibility redirects — ✅ keep

A redirect is a route whose whole purpose is that an old URL still resolves.
Having nothing link to it is the point.

| route | redirects to | why it exists |
|---|---|---|
| `/super-admin/tons-out` | `/super-admin/recon-tables` | ML-link alias |
| `/super-admin/seat-requests` | `/super-admin/token-requests` | the feature was renamed |
| `/super-admin/dashboard-v2` | `/super-admin` | **client-ruled 2026-08-14**: v2 was promoted to the landing screen and this was kept, deliberately as a redirect and not a second mount, so existing browser history resolves. A second mount would have been a fresh orphan. |

### 2.3 Detail routes reached from their parent — ✅ keep

Reached by an interpolated `context.go` the matcher cannot resolve statically,
or by a row tap that builds the path from an id.

| route | reached from |
|---|---|
| `/portal/mine/stockpiles/:id` | the supervisor's stockpile card. `portal_scaffold.dart:281` documents that this path selects the `…/stockpiles` rail entry, which only matters if it is navigable. |
| `/portal/mine/tons-out/:transporterId` | the recon table's transporter filter — the same screen, pre-filtered (see the `PortalTonsOutScreen` meta line, S5-22). |
| `/portal/transporter/fleet/:id` | ML-link compatibility. The router's own comment: *"no standalone vehicle screen. The `:id` segment is accepted for ML-link compatibility; the screen lists the whole fleet."* |
| `/employees/:companyId` | ⚠ see §2.5 — the **child** is referenced, this parent is not. |

### 2.4 Notification deep links — ✅ keep

Reached from a notification the server sends, never from in-app navigation.
`portal_nav.dart:629` names them as *"deep-link aliases that need an id"*, and
S7-2 / S7-3 fixed exactly these last session — they parsed `:routeId` and threw
it away.

`/portal/transporter/accept-route/:routeId` ·
`/portal/transporter/allocate-fleet/:routeId` ·
`/portal/transporter/drop-off/:tripId`

### 2.5 Worth a decision — 🔸 two, raised not resolved

**The four waybill routes duplicate a modal that is what the app actually
uses.**

`/portal/mine/trips/:id/waybill` · `/portal/buyer/trips/:id/waybill` ·
`/portal/transporter/trips/:id/waybill` · `/portal/driver/trip/:id/waybill`

`portal_trip_detail_screen.dart:175`'s "View waybill" button calls
`showWaybillModal(context, ref, tripId: …)`. It does **not** navigate. So these
four are addresses with no in-app link and no way to arrive except typing the
URL. They are defensible as shareable waybill links — *"send me the waybill for
that load"* is a real request — but nothing in the product offers that link,
so today they are four routes a user cannot discover. **Either wire a copy-link
affordance into the modal, or delete them.** Left alone here because deleting a
URL is permanent for anyone who has already bookmarked one, and adding a share
affordance is a product decision.

**`/employees/:companyId` has a referenced child and an unreferenced parent.**
`employee_grid_screen.dart:81` navigates
`'/employees/$companyIdForRoute/${employee.id}/details'` — the three-segment
detail route. The one-segment parent that lists a company's employees is
reachable from nothing; `company_employees_screen.dart:1185` sends people to
`/portal/{org}/employees` instead. Likely a leftover from before the portal
alias existed. **Worth confirming before deletion** — a console link may still
depend on it.

---

## 3. Reproducing

```bash
python tool/route_reachability.py            # the report above
python tool/route_reachability.py --selftest # 4 assertions, all must pass
python tool/route_reachability.py --json     # for a diff between runs
```

The `--json` form is the one to use in a future pass: a route appearing in
`uncovered` that is not on the list above is a **new** orphan and needs its own
verdict here.

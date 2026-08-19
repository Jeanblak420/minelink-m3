# Seeded demo data in production — inventory for client approval

**Project:** `yftazblpmicqtamyiwyb` (production — there is no staging)
**Compiled:** 2026-08-12 · **Items:** P10-D1 … P10-D4
**Status: NOTHING HAS BEEN DELETED.** This document exists to be approved first.
Per P10-D5 the client must see and approve this list before a single `DELETE` runs.

---

## 0. The standing caveat — read before quoting any tonnage figure

> **The great majority of the tonnage on this platform is invented, by the
> client's explicit choice to keep the seeded trips.** It follows that **any
> figure checked against those totals is _verified-against-seed_, never
> proven** — and that phrase should be used, in those words, wherever such a
> figure is reported.
>
> This applies to every number derived from trip tonnage: dashboard KPIs,
> recon totals, yield and pit-to-port loss, offload variance, target dials and
> actuals, and every Rand value computed from a tonnage. A query returning the
> right answer over seeded rows demonstrates that the query is correct. It
> demonstrates nothing about the business.
>
> | measured | figure | when |
> | :-- | --: | :-- |
> | Total recorded tonnage | **1,227.9 t** | 2026-08-16 |
> | Of which seeded | **1,123.7 t** | 2026-08-12 |
> | Seeded share | **~91%** | ⚠ combines two dates — see below |
>
> ⚠ **The share is approximate and deliberately not stated more precisely.**
> The two figures were measured four days apart. No further seeding is known
> to have run in between, so the seeded volume is believed unchanged and the
> real movement to have grown by ~104 t — but that is an inference, not a
> measurement, and the 94.1% recorded in §1 below was exact only on 2026-08-12.
> **Re-measure both on the same day before quoting a share.** At time of
> writing the project is unreachable (see the health note in the session log),
> so this could not be done.
>
> The customer-facing records — companies, employees, profiles, notifications,
> fleet, seats, access tokens — **are real**, and none of the above applies to
> counts of them.

---

## 1. The one-paragraph version

Two separate seed operations put demo rows into the live database. Together they
account for **38 of 41 trips, 38 of 42 transactions, 33 of 35 proof-of-delivery
records, and 1,123.7 t of the platform's 1,193.7 t of recorded tonnage — 94.1%.**
Every super-admin figure that counts tonnage, trips or deliveries is therefore
mostly reporting invented movement.

The customer-facing records — **26 companies, 88 employees, 116 user profiles,
305 notifications, the fleet, the seats and the access tokens — are all real** and
are not proposed for deletion. The seeded rows attach to five of the real
companies but do not alter them.

---

## 2. Two seeds, and only one of them is in the repository

| Seed | Marker | Rows it owns | Migration file in git? | In the migration ledger? |
|---|---|---|---|---|
| **A — insights demo** | `transactions.metadata->>'seed' = 'insights_demo_20260803'` | **37 transactions + 37 trips + 33 PODs** | ❌ **No** | ❌ **No** |
| **B — portal logistics demo** | `metadata->>'seed' = 'portal_demo_v1'` | 1 transaction, 1 trip, 1 haul route, 1 reconciliation, 2 vehicle positions | ✅ `20260511160000_portal_logistics_demo_seed.sql` | ✅ as `20260510235420` |

> ### ⚠ Correction to the plan — P3-42 is wrong, and this is the important finding
>
> P3-42 says the demo data is removed by taking two migration files out of the
> chain. **That would remove almost none of it.**
>
> Seed A — which is 97% of the seeded volume — **exists in no migration file and
> in no ledger row.** `grep -r insights_demo` across the entire repository
> returns exactly one hit: the line in `To-Do's.md` that describes the problem.
> It was inserted straight into production by an ad-hoc script or console session
> that left no trace in git and no trace in `supabase_migrations`.
>
> Two consequences the client should know:
> 1. **It cannot be reproduced or reverted from source control.** The only record
>    that it happened is the marker inside each row's `metadata`.
> 2. **Deleting the two migration files changes nothing in the live database.**
>    Migration files are not undo scripts. The rows must be deleted explicitly,
>    which is what this document is asking approval for.
>
> Also noted for P0-05/P0-06: both seed migrations carry a **different timestamp
> in the ledger than on their filename** (`20260510235420` vs `20260511160000`;
> `20260726182845` vs `20260726090300`).

---

## 3. The inventory — every affected table, with its exact predicate

Predicates are written so they can be pasted directly into a `DELETE … WHERE`.
Delete in the order shown; the list is ordered child-before-parent.

| # | Table | Total rows | Seeded | Real | Exact predicate identifying the seeded set |
|---|---|---|---|---|---|
| 1 | `pod_uploads` | 35 | **33** | 2 | `photo_url = 'insights-demo/pod-placeholder.jpg'` — identical on all 33; `uploaded_by IS NULL` on the same 33 |
| 2 | `trips` | 41 | **38** | 3 | `transaction_id IN (SELECT id FROM transactions WHERE metadata->>'seed' IN ('insights_demo_20260803','portal_demo_v1'))` |
| 3 | `transactions` | 42 | **38** | 4 | `metadata->>'seed' IN ('insights_demo_20260803','portal_demo_v1')` |
| 4 | `reconciliations` | 2 | **1** | 1 | `metadata->>'seed' = 'portal_demo_v1'` |
| 5 | `haul_routes` | 1 | **1** | 0 | `metadata->>'seed' = 'portal_demo_v1'` |
| 6 | `vehicle_positions` | 56 | **2** | 54 | `source = 'portal_demo_v1'` (the other 54 are `source = 'driver_app'` — real GPS pings) |
| 7 | `showcase_data` | 14 | **14** | 0 | the whole table — 8 categories: buyer, driver, mine, road_request, stockpile, transporter, trip, truck. See §6. |
| 8 | `stockpiles` | 3 | **1 (query)** | 2 | `name = 'Chrome Ore - Atlas (UI test)'` — a hand-made test row, not from either seed script. Client call. |

### Not seeded — proposed to keep, listed so the client can see the whole picture

`companies` 26 · `employees` 88 · `profiles` 116 · `notifications` 305 ·
`organization_seats` 106 · `chat_messages` 38 · `chat_rooms` 13 ·
`profile_requirements` 38 · `employee_status_history` 25 (all `role_assigned`) ·
`serial_tokens` 17 · `audit_logs` 15 · `fleet_vehicles` 6 ·
`transportation_requests` 6 · `routes` 5 · `margin_ledger` 5 ·
`request_dispatches` 5 · `stockpile_transactions` 6 · `target_cycles` 4 ·
`minerals` 2 · `org_connections` 2 · `driver_assignments` 2 · `seal_records` 2 ·
`weighbridge_records` 1 · `gate_checks` 1 · `company_locations` 1 ·
`monthly_targets` 1 · plus the support-desk tables.

These were created by real use between 2026-03-28 and 2026-08-07.

---

## 4. What survives the purge — and it is very little

| Figure | Today | After the purge |
|---|---|---|
| Trips | 41 | **3** (2 completed, 1 at `arrived_at_mine`) |
| Completed trips | 37 | **2** |
| Transactions | 42 | **4** |
| Proof-of-delivery records | 35 | **2** — and both have **no photo** |
| Total tonnage recorded | 1,193.70 t | **70.00 t** |

**The client should expect the super-admin dashboards to look nearly empty.**
That is the correct outcome and the whole point of the exercise, but it will be
a visible change and is better anticipated than discovered.

---

## 5. Findings that correct the plan

### P10-D1 — the "systematic shortfall" is not a business finding ✅ confirmed

`trips.variance_tons` across all 35 reconciled loads:

| n | min | max | avg | **stddev** | **distinct values** |
|---|---|---|---|---|---|
| 35 | 0.2000 | 0.2000 | 0.2000 | **0.000000** | **1** |

One distinct value and zero dispersion across 35 independent weighings is
arithmetic, not measurement — the seed computed `delivered_tons = net_tons − 0.2`.
The P3-13 follow-up that proposed surfacing a systematic shortfall on the recon
totals **must not be built on this**, and the figure must never be shown to the
client as an operational signal. The note in P3-13 has been corrected in place.

### P10-D2 — there is no broken image, and the upload path is not broken either

Two claims in the plan, both worth restating accurately:

- **"Every POD image is a broken reference."** True as to the data: 33 rows point
  at `insights-demo/pod-placeholder.jpg` and `pod_photos` holds 0 objects. But
  **nothing renders a broken image.** There is no `Image.network` on this path.
  `PodPhotoIcon` shows a photo button; tapping it calls `resolvePodPhotoUrl`,
  which fails to sign a non-existent object, and the user gets the snackbar
  *"Could not open the POD photo."* That is already a stated failure. The only
  real defect is that a button is offered for a photo that is not there — and all
  33 rows disappear with the purge.
- **"No upload path in this app has ever produced a stored file."** The *reason*
  is not a bug. `LifecycleService.uploadPodPhoto` genuinely does
  `uploadBinary` into `pod_photos` at `companyId/<uuid>_<name>`, and it is
  correct. It has never run because **the POD photo is optional**:
  `driver_routes_screen.dart:273` reads `if (photo != null)`, and the two real
  PODs were both recorded without one. So the finding is not "the upload is
  broken" but **"proof of delivery does not actually require proof."**
  That is a product question for the client, not a code fix — see §7.

### P10-D3 — the v2 sparkline never read `weighbridge_records` ✅ corrected

The case for promoting `super_admin_dashboard_v2_screen.dart` was recorded as
"its `_spark()` reads *real* weighbridge rows", which made the single
`weighbridge_records` row alarming. It does not. `_spark()` takes
`List<RawReconRow>` and sums `netMass` from `list_raw_recon_rows` — i.e. from
**trips**. `weighbridge_records` is not in that path at all.

The promotion (P9-01) was therefore still the right call, and it has since been
done. But what that sparkline draws today is **seeded tonnage**, and after the
purge it draws a flat zero for most of its 10-day window: the only trips in the
last ten days are 4 on 2026-08-02 and 5 on 2026-08-03, all seeded. A flat line
from real rows is the honest render; it should not be "fixed".

Separately, and still true: the one `weighbridge_records` row is dated
2026-03-30 and has **`tare_weight`, `gross_weight` and `net_weight` all NULL** —
so even that row records no weighing. It is left in place; it is not seed data.

---

## 6. Two things that need a client decision beyond the purge

1. **`showcase_data` (14 rows) and the "Demo Data Active" banner.**
   `DemoDataIndicator` displays *"Demo Data Active — showing example content"*
   whenever `showcase_data` is non-empty, which is always — while no example
   content is rendered anywhere, because `ShowcaseItem.data` is never read by any
   widget. Real customers are currently told their live screens are demo data.
   Deleting the 14 rows silences the banner and loses nothing. (P10-23.)
2. **`stockpiles` — "Chrome Ore - Atlas (UI test)", balance 95.0 t.**
   Hand-made during UI work, not from either seed script, and indistinguishable
   from a real pile except by its name. The other two piles look genuine.

---

## 7. Recommendations

| # | Recommendation | Why |
|---|---|---|
| 1 | **Approve the §3 deletions** in the order given. | It is the only way the brief's "only real data" requirement can be met; the rows cannot be removed by touching migration files. |
| 2 | **Take a PITR marker / backup first (P0-08).** | Irreversible deletes on a production project with no staging. This needs a human on the Supabase dashboard — see §8. |
| 3 | **Write the deletion as one reviewable migration**, guarded by the exact predicates above and a row-count assertion that aborts if a count does not match this document. | So the delete is reproducible from git, unlike the insert that caused this. |
| 4 | **Decide whether a POD may be recorded without a photo.** | Today it may. "Proof of delivery" that carries no proof is a commercial weakness, and it is why the bucket is empty. Recommend: require the photo. |
| 5 | **Delete the 14 `showcase_data` rows** and the `DemoDataIndicator` with them. | It currently mislabels live screens as demo data for every real customer. |
| 6 | **Confirm the "Chrome Ore - Atlas (UI test)" stockpile** is disposable. | Cannot be told apart from real data by anything but its name. |

---

## 8. Blocked on a human

**P0-08 — the backup / PITR marker.** Point-in-time recovery is a paid add-on
configured from the Supabase dashboard, and taking a marker is not something the
MCP tooling exposes. **No deletion should run until someone confirms a restore
point exists.** This is the one step in the purge that an agent cannot perform.

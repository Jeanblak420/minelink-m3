# Super Global Admin — Insights metrics (layers 1–2)

This document defines how monthly KPIs are computed for the Super Global Admin **Insights** views (`/super-admin/insights/:orgType` and derived navigation). Product and engineering should treat this as the canonical definition unless superseded by an explicit change request.

## Time window

- **Period**: The **current calendar month** in **South African time (UTC+02:00)** — the one basis the whole product reckons days in. Ruled 2026-08-17; `lib/core/time/ml_time.dart` on the client, `public.ml_today()` / `public.ml_day()` in Postgres.
- **Bounds**: From the first day of the month at 00:00:00 SAST through the last instant before the next month (inclusive end), serialized as ISO-8601 for the RPC `super_admin_monthly_insights_bundle`.
- **Consistency**: The Flutter app passes the same window to Postgres so SQL rollups match list labels. Note the change: this used to be *"the current calendar month on this device"*, which meant the same query returned different numbers to two admins whose laptops were set differently — and disagreed with the mine, which runs on SAST.

> ⚠ **The database itself is still UTC, deliberately.** ~180 columns default to `timezone('utc', now())`, which returns a *naive* timestamp; storing one into a `timestamptz` column reinterprets it in the session zone, so setting the database timezone to Africa/Johannesburg would silently shift every `created_at` in the product by two hours. The zone is named explicitly wherever a **day** is decided instead — see `20260817240000_one_clock_africa_johannesburg.sql`.

## Org type and transaction party columns

Rows are attributed to a company based on **`companies.org_type`** and the matching foreign key on **`transactions`** (and joined **`trips`**):

| Org type (`companies.org_type`) | Party column on `transactions` | Role |
|----------------------------------|----------------------------------|------|
| `transporter` | `transporter_company_id` | Transporter context |
| `buyer` | `buyer_company_id` | Buyer context |
| `mineSupplier` | `supplier_company_id` | Mine / supplier context |

Trips are counted only when joined to a transaction whose party column matches the company for that org type.

## Per-company metrics (layer 2 cards)

| Field | Meaning |
|-------|---------|
| **employees** | Count of `employees` where `company_id` = company |
| **drivers** | Employees with `role = 'driver'` |
| **fleet_vehicles** | Count of `fleet_vehicles` for the company (current totals, not windowed) |
| **routes_distinct** | Distinct non-null `trips.route_id` for trips in the month window, joined to attributed transactions |
| **trips** | Trip rows in the month window (`trips.updated_at`), joined to attributed transactions |
| **loads_count** | Transaction rows in the month window (`transactions.updated_at`) attributed via the party column |
| **tons_moved** | Sum of `transactions.quantity` in that window (same attribution) |
| **completed_waybills** | Loads where `lower(trim(status)) = 'completed'` |
| **pending_waybills** | Loads where status is **not** completed (including null/empty after trim) |

## Aggregate row (layer 1 KPI strip)

For the selected org type, totals are **sums** of the per-company metrics above (except **company_count**, which is the number of companies of that type):

- **active_trips_approx**: Sum of per-company trip counts (label reflects “approximate” aggregation across companies).
- **fleet_vehicles_total**: Sum of each company’s fleet count (same caveat: sum of counts, not deduplicated vehicles across companies).
- **tons_moved**, **transactions_total** (sum of `loads_count`), **completed_waybills**, **pending_waybills**: Summed across companies.

## CSV export (mirror & insights)

Exports a **single CSV row** for one company for the **same monthly window** as Insights, via `share_plus`. Super-admin export attempts an audit entry (`insert_audit_log`, action `INSIGHTS_CSV_EXPORT`); failure to log does not block sharing.

## Fallback behavior

If the RPC `super_admin_monthly_insights_bundle` is unavailable, the client recomputes compatible metrics in Dart using the same party-column rules and month window (`MonthlyInsightsBundle.fromDatabaseRpc == false`).

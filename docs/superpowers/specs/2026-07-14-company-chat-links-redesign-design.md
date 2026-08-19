# Company Chat Links — Redesign (Super-Admin)

**Date:** 2026-07-14
**Feature branch:** feat/premium-mine-supplier-overview
**Owner:** super-admin (super global admin)
**Primary file today:** `lib/features/super_admin/screens/chat_connections_screen.dart`

## Problem

The current "Company chat links" screen is a flat list with a plain two-dropdown
link dialog. Two things are wrong for the product:

1. **Companies get chat-linked automatically** the moment they do business.
   Migration `20260713060000_auto_connect_business_parties.sql` installs
   `AFTER INSERT` triggers on `transactions` and `request_dispatches` (plus a
   one-time backfill) that call `chat_connect_orgs(...)`. The super-admin never
   chose these links. **This must stop** — every chat link is a deliberate
   super-admin action.
2. The screen offers no **org-type grouping**, no **request-driven
   recommendations**, no **clickable company names → profile**, and no way to
   link a company **from its own profile page**.

## Goals

- Linking is **100% manual**. No business event ever creates a chat link.
- A **two-sided, org-type-grouped selector** that reads like a sentence:
  *"Connect **[Company A]** to **[Company B]** via MineLink Messenger."*
- A **Recommended connections** panel, derived from **accepted requests /
  transactions**, showing each candidate pair, the **date/time** a request tied
  them together, and **why** — each with a manual "Connect" action.
- **Connected** list (current granted links) and a **History** list (revoked /
  previously connected).
- Every **company name is a clickable link** to that company's profile
  (`/super-admin/organization/:orgId`).
- On a company's **profile page** (org detail, super-admin view): a **Chat
  connections** section (list of this company's links, each clickable +
  revocable) **and** a **Link for chat** button that opens the selector with
  this company pre-locked on the left.

## Non-goals

- No schema column added for a link "reason" — the reason is **derived live**.
- No change to how non-admins see chat contacts beyond the fact that
  `org_connections` is now populated only by manual super-admin action.
- No change to the underlying `messaging_service.grantConnection /
  revokeConnection` contract (still keyed on `company_low_id/high_id`).

## Design

### A. Database — stop auto-linking, wipe existing auto-links

New migration `supabase/migrations/20260714xxxxxx_manual_only_chat_links.sql`:

1. `drop trigger if exists connect_transaction_parties on public.transactions;`
2. `drop trigger if exists connect_dispatch_parties on public.request_dispatches;`
3. `drop function if exists public.trg_connect_transaction_parties();`
4. `drop function if exists public.trg_connect_dispatch_parties();`
5. `drop function if exists public.chat_connect_orgs(uuid, uuid, uuid);`
   (only referenced by the dropped triggers — verify with grep before dropping).
6. **Start clean:** `delete from public.org_connections;` — the user chose to
   wipe all existing links (they cannot be distinguished as auto vs manual, and
   the product intent is that the super-admin builds every link from scratch).

Follow `supabase/MIGRATION_HYGIENE.txt`; list remote migrations before push.
RLS on `org_connections` is unchanged. Apply via Supabase MCP `apply_migration`
after the user authorizes the connector (currently not authorized in-session).

### B. Redesigned screen — `chat_connections_screen.dart` (top → bottom)

1. **Connect builder** (the two-sided grouped selector, section C).
2. **Recommended connections** — from `businessPairsProvider` (section E).
   Card: `CompanyNameLink A` ⇄ `CompanyNameLink B`, both org-type labels, the
   **date** a request tied them together, and the **reason** string. Action:
   **Connect via MineLink Messenger** (calls `grantConnection`). Pairs already
   present in `org_connections` (granted) are excluded from this list.
3. **Connected** — `orgConnectionsProvider` filtered to `status == granted`.
   Card: clickable names, org types, "Linked {date}", derived "why" note when a
   business pair matches, and a **Revoke** action.
4. **History** — `status == revoked`. Card: names, "Revoked {date}", and a
   **Grant again** action. (Header count "N active · M revoked" retained.)

Styling stays on `MlTokens` / `MlSemantic` / `MlTone` / `Ml*` widgets. No raw
colours or magic numbers.

### C. Two-sided grouped selector (reusable widget)

New widget e.g. `lib/features/super_admin/widgets/company_link_builder.dart`.

- Input: `List<company map>` (id, company_name, org_type), optional
  `lockedLeftCompanyId` (used from the profile page).
- **Left column:** searchable list of all companies, grouped under section
  headers **Mine / Supplier**, **Buyer**, **Transporter** (order fixed; a
  fourth "Company" bucket for unknown org types). Selecting one locks its name.
- **Right column:** same list, **excludes** the left selection.
- Live sentence: *"Connect **X** to **Y** via MineLink Messenger."*
- **Connect** button enabled only when both chosen and distinct → calls
  `messagingService.grantConnection(a, b)` and invalidates
  `orgConnectionsProvider`.
- On small screens the two columns stack; on wide screens they sit side by side
  (respect `app_breakpoints.dart`).

### D. `CompanyNameLink` widget

New small widget (e.g. in `company_link_builder.dart` or a shared file) that
renders a company name in accent/link style and, on tap, calls
`context.go('/super-admin/organization/$orgId')`. Requires the company id; the
`organizationsProvider` rows already carry `id` = organization id (verify the
org-detail route accepts that same id). Used in every card on the screen and on
the profile section.

### E. `businessPairsProvider` (live reason derivation)

New provider + service method (super-admin repository or messaging service —
match nearest existing pattern) returning, for each unordered company pair, the
**most relevant** `{ companyA, companyB, date, reason }`:

- **Accepted transport requests** (`transportation_requests` where status in
  approved/linked): pair = (buyer_company_id, supplier_company_id); reason e.g.
  *"Approved transport request — Buyer {b} ↔ Mine {s}, {product} {tons}"*; date =
  approval/linked timestamp.
- **Dispatches** (`request_dispatches` joined to the request): pairs of
  transporter ↔ buyer and transporter ↔ supplier; reason e.g. *"Route dispatch —
  {transporter} on {RT-…}"*; date = `dispatched_at`.
- **Transactions**: supplier↔buyer↔transporter pairs; reason *"Transaction —
  {…}"*; date = created_at.

If multiple sources touch the same pair, keep the most recent / most specific.
Keyed by `min(id)|max(id)` to match `org_connections` low/high ordering.
Used to (a) build the Recommended panel (candidate pairs minus already-linked)
and (b) annotate "why" on Connected cards.

### F. Company profile page — `organization_detail_screen.dart`

Add a **Chat connections** section (super-admin view):

- Lists this company's current granted links (from `orgConnectionsProvider`
  filtered to rows touching this org id), each with a `CompanyNameLink` to the
  *other* company and a **Revoke** action.
- A **Link for chat** button → opens the section-C selector with this company
  **pre-locked on the left**, so the admin only picks the counterpart.

## Data / providers touched

- `organizationsProvider` (exists) — company list with id/name/org_type.
- `orgConnectionsProvider` (exists) — invalidated after grant/revoke.
- `messagingServiceProvider.grantConnection / revokeConnection` (exist).
- **New:** `businessPairsProvider` + its service method.

## Testing

- Widget test: grouped selector renders org-type headers, excludes the left
  pick from the right list, enables Connect only for two distinct companies,
  and emits the correct (a,b).
- Unit test: `businessPairsProvider` derivation — given fixture
  requests/dispatches/transactions, produces the expected pair→reason map and
  excludes already-connected pairs from Recommended.
- `CompanyNameLink` navigates to the correct route.
- Manual/MCP check: after the migration, `org_connections` is empty and no new
  row appears when a dispatch/transaction is inserted.
- `flutter analyze` clean; `flutter test` green.

## Risks / notes

- Wiping `org_connections` makes existing chat threads between those companies
  unavailable until re-linked — accepted by the user (treat as clean start).
- Supabase MCP connector is **not authorized in this session**; the migration
  can be written to `supabase/migrations/` now but must be applied by the user
  (or in an authorized session). Do not claim it is applied until verified.
- Verify `chat_connect_orgs` has no other callers before dropping it.

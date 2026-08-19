# POD visibility · Buyer money layer · Load quality certs · Mine production — design (2026-07-27)

Four gaps closed in one build, all live on project `yftazblpmicqtamyiwyb`
(migrations `20260727210000`–`20260727240000`, also in `supabase/migrations/`).

## 1. POD photo — visible to every party

**Problem.** The driver's POD photo uploaded into the transporter's company
folder of the private `pod_photos` bucket, so the buyer and mine could see the
`pod_uploads` row (already party-scoped) but never open the picture.

**Design.**
- Storage policy `pod_photos_select_parties`: an object referenced by
  `pod_uploads.photo_url` is SELECTable by staff of the upload's transaction's
  supplier / buyer / transporter companies (platform admin already covered).
  Upload/delete stay company-folder-scoped.
- `list_raw_recon_rows` returns `pod_photo_path` (latest upload per trip).
- UI: POD column ("View" link) on the raw recon table — buyer, mine,
  transporter screens and the super-admin combined table all use `RawReconView`;
  Side B keeps its icon (now the shared `PodPhotoIcon`,
  `widgets/pod_photo_link.dart`); the driver's Recent Trips history shows a POD
  icon per delivered trip (path resolved from the party-scoped
  `list_trip_reconciliations`).

## 2. Buyer money layer — Rand on every load

**Problem.** Tonnage everywhere, Rand nowhere; the buyer could not reconcile
delivered vs invoiced money.

**Design.**
- `load_invoices`: one buyer-captured invoice per trip (number, amount R,
  optional tons, date, notes). RLS: buyer staff read/write own (insert/update
  verified against the trip's transaction buyer), managers delete, platform
  admin read. The mine and transporter can never read buyer invoices.
- `list_buyer_trip_values(p_company_id)` (SECURITY DEFINER, buyer staff or
  platform admin): per loaded trip — rate = latest `margin_ledger.agreed_price_per_ton`
  for the trip's dispatch→request (what the buyer agreed to pay; the admin
  margin and transporter price are NEVER returned), `loaded_value = net × rate`,
  `delivered_value = delivered × rate`,
  `payable_value = payable_tons × grade_factor × rate` (quality-adjusted when a
  certificate exists), invoice fields + `invoice_variance = invoiced − payable`.
- UI: buyer tab **Loads & value** — stat cards (Delivered value, Payable value,
  Invoiced, Invoice variance), per-load table with invoice capture/edit dialog,
  POD chip, read-only quality table, Excel/CSV/PDF export.

## 3. Quality certificates per load + payable-tons penalty calc

**Problem.** Grade was free text; no Cr₂O₃ %, moisture % or sizing anywhere;
lab PDFs attached to requests, never to a delivered load.

**Design.**
- `routes` gains the contract spec: `spec_cr2o3_pct`, `spec_moisture_max_pct`,
  `spec_sizing` (set via `set_route_quality_spec` — supplying mine staff or
  platform admin).
- `stockpiles` gains structured `cr2o3_pct`, `moisture_pct`, `sizing`.
- `load_quality_certs`: ONE cert per trip (unique) — structured values, notes,
  and the lab file in the new private `quality_certs` bucket
  (`<mine_id>/quality/<trip_id>/…`; mine-folder writes, cross-party reads via
  the cert reference, platform admin always). Writes only through
  `set_load_quality_cert` (mine staff of the trip's supplier or admin; trip
  must have a weighbridge net weight; upsert keeps the old file when no new
  one is sent).
- Penalty calc (server-side, identical in `list_load_quality` and the buyer
  values RPC):
  - basis = delivered tons (fallback mine net)
  - `payable_tons = basis × (1 − max(0, moisture − spec_max)/100)`
  - `grade_factor = min(1, cr2o3 / spec_cr2o3)` — penalty only, no bonus
- UI: mine tab **Quality** (spec editor per route + editable
  `LoadQualityTable`); buyer sees the same table read-only on Loads & value;
  super-admin sees it platform-wide on Recon tables.

## 4. Mine production vs dispatch

**Problem.** Only tons-out was tracked — no tons-mined input, no yield/loss
view; stockpile INSERT was locked (`with check (false)`) so mines could not
represent their own ROM piles.

**Design.**
- `stockpiles.kind`: `'order'` (system-created, capped — unchanged) vs
  `'production'` (mine-owned ROM). New INSERT policy allows stockpile writers
  to create production piles only (request/route/buyer/cap must be null);
  order piles remain system-only.
- `production_entries` + `record_production` RPC (stockpile writers): tons
  mined per day (commodity, pit/section, notes), optionally landing the
  tonnage on a production pile atomically via `stockpile_add_tons` (no cap,
  no alerts — those are order-pile behaviours).
- `mine_production_dispatch_report(company, from, to)`: per-day mined vs
  dispatched (weighbridge `trips.net_tons` where the mine is supplier).
- UI: mine tab **Production** (org, admin/management, and supervisorForeman):
  record-production dialog, window selector (7/30/90/365 d) with Mined /
  Dispatched / Yield % / Pit-to-port loss cards, daily table + export, ROM
  pile creation + add-tons cards, production log.

## Verification (live, rolled back — no residue)

Single DO block impersonating real users (`set local role authenticated` +
`request.jwt.claims`), all changes rolled back via terminal RAISE:

1. Buyer owner opens the POD storage object ✓; raw recon row carries the path ✓
2. Buyer values: rate 1200, delivered value 41 760 ✓; invoice insert ✓
3. Buyer blocked from attaching a quality cert ✓
4. Mine set spec 42 % / 8 % max, certified 38 % / 10 % → payable 34.10 t,
   grade factor 0.9048 ✓; mine sees 0 buyer invoices ✓
5. Production pile created, `record_production(120 t)` → pile balance 120,
   report 120 mined vs 35 dispatched ✓; hand-made order pile blocked ✓
6. Driver sees the POD object ✓ but 0 buyer-value rows, 0 margin_ledger rows,
   and cannot record mine production ✓

`flutter analyze`: clean. Advisors: only the project-wide informational
"SECURITY DEFINER executable by authenticated" WARNs (established pattern —
auth checks live inside each function, anon revoked).

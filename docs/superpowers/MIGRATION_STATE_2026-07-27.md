# Migration reconciliation state (fork-merge, 2026-07-27)

Companion to `supabase/MIGRATION_HYGIENE.txt`. Records the code↔DB migration
state after the ML→worktree fork merge, so the repo is coherently deployable.

## Source of truth
- The **live production DB** (project ref `yftazblpmicqtamyiwyb`) is authoritative.
  It is the worktree fork's DB and holds real data (116 profiles, 26 companies,
  88 employees, live trips/routes/margins/recon/chat/seats).
- The ML fork's DB (`lrayvsezbpxuutttfxvi`) is NOT used and NOT accessible; ML
  contributed code only, adapted to the live schema.

## What this merge added to live (additive only, applied via MCP)
Four new migrations, committed under `supabase/migrations/` (timestamp prefix
`20260726090xxx`), all `CREATE ... IF NOT EXISTS`, no existing table/data touched:
1. `..090000_mine_locations_and_waypoints.sql` — mine_locations, trip_waypoints,
   security_confirmations + party-scoped RLS + waypoint/confirmation RPCs.
2. `..090100_mine_hazards.sql` — mine_hazards (plain lat/lng) + get_nearby_hazards.
3. `..090200_mine_road_requests.sql` — mine_road_requests + RLS.
4. `..090300_showcase_data.sql` — showcase_data + 14 idempotent demo rows.

Live table count after apply: **55** (was 49). Security advisors: 0 ERROR.

## Edge functions
- `reset-admin-password` recaptured to the repo as a **decommissioned 410 no-op**
  (`supabase/functions/reset-admin-password/index.ts`); the previous live version
  was a public admin backdoor (see the git history / project memory). Redeployed
  live as v8 (verify_jwt=true). **Admin password rotation is still owed out-of-band.**

## Known divergence (pre-existing, not introduced here)
- The repo's `supabase/migrations/` contains more historical files than the live
  server's applied migration list (some applied under different timestamp prefixes,
  per `MIGRATION_HYGIENE.txt` §2). This predates the merge and does not affect the
  running app, which targets the live DB. A future clean-baseline (dump live schema
  → single baseline migration) is the recommended long-term tidy-up; it was
  intentionally NOT attempted here to avoid rewriting the historical record.

## Deploy guidance
- App config (`config/supabase.live.json` / `.local.json`) already points at
  `yftazblpmicqtamyiwyb`. New environments should baseline from a live schema dump,
  then apply any future migrations on top. Do not blindly `db push` all 120+ repo
  files against a populated DB — list remote migrations first (MCP / dashboard).

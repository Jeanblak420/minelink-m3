# `supabase/extras_project/` — migrations for the SECOND Supabase project

These apply to **`Mine-Link_Extra_Data`** (`qbydiuplqhmkaxarnuza`), **not** to the
main app database. Nothing in here should ever be applied to
`yftazblpmicqtamyiwyb`.

## Why this directory exists

`supabase/migrations/` is the main project's history and the Supabase CLI points
at it. The six migrations that build `place_index` live there because they
genuinely ran on the main project before the table was moved out
(`20260816170000_place_index_moved_to_extras.sql` ends that history). The extras
project is still built from those same six files by
`tools/place_index_move_project.py`.

Anything that applies **only** to the extras project goes here instead, so it
cannot be swept into a `supabase db push` against main.

## The MCP tools cannot reach this project

`.mcp.json` pins the main ref, so `mcp__supabase__execute_sql`,
`apply_migration`, `query_logs` and `get_advisors` **always hit the main app
database** — silently, whichever project you believe you are working on. Apply
anything here through the Management API by hand:

```bash
curl -X POST "https://api.supabase.com/v1/projects/qbydiuplqhmkaxarnuza/database/query" \
  -H "Authorization: Bearer <sbp_…>" \
  -H "Content-Type: application/json" \
  -H "User-Agent: MineLink-ops/1.0" \
  -d @- <<< "$(python -c "import json,sys;print(json.dumps({'query':open(sys.argv[1]).read()}))" migrations/<file>.sql)"
```

Cloudflare fronts `api.supabase.com` and answers the default curl/urllib agent
with HTTP 403 code 1010 — always send a real `User-Agent`.

## What may live in this project

**Bulk reference data only.** Open data with no owner, safe to read
unauthenticated, reached through a `SECURITY DEFINER` wrapper.

**Never user, company or trip data.** A JWT minted by the main project's GoTrue
is not valid here — different project, different JWT secret — so a signed-in
MineLink user arrives as `anon`. There is no session to scope rows by, which
means RLS cannot protect party-scoped data here at all. Every table on the main
project except `place_index` carries RLS policies for exactly that reason;
`place_index` had none, and that is what made it the one table safe to move.

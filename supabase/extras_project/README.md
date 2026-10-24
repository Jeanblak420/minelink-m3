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

## After re-importing `place_index`: refresh the search copy

Since `20261024150000` / `20261024160000` (2026-10-24) the address search does
not scan `place_index` itself. `_place_index_rank` reads
`place_index_search`, a materialized view holding only `id`, `name`,
`search_text` and `confidence`, stored in town order, and goes back to
`place_index` only for the rows it returns.

**Why:** this free-plan database has 455 MB of RAM and was 429 MB into swap.
A common town's matching rows were scattered one per page across
`place_index`, so a first search read thousands of pages back from swap and
ran past `anon`'s 3-second timeout ("Johannesburg" 7.7 s, "Centurion" 3.3 s).
In town order the same rows sit on neighbouring pages: fresh searches now take
40–210 ms on the server. Pre-loading the table (`pg_prewarm`) was tried and
did not help — it loads pages into a cache that is itself swapped out.

**So after any re-import of `place_index`, run:**

```sql
refresh materialized view public.place_index_search;
```

Non-concurrent on purpose (a concurrent refresh needs a 34 MB unique index
this project does not need). It takes about 25 seconds; searches made during
it wait for it.

The old full-text index on `place_index` (`place_index_search_fts`) was
dropped by `20261024160000`: nothing uses it any more. `tools/place_index_move_project.py`
and `tools/place_index_trim.py` still create it; on their next use, drop it
again afterwards (34 MB) and refresh the view.

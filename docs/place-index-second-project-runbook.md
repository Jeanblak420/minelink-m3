# Moving `place_index` to a second free Supabase project

> ## ✅ DONE — 2026-08-16. This is now a record, not a plan.
>
> The move is complete and verified. What actually happened differed from the
> plan below in three ways worth knowing:
>
> - **The trim was never run.** Once the second project existed there was no
>   reason to delete anything, so `place_index` was *copied* rather than
>   re-imported and then trimmed.
> - **South Africa only** (client instruction the same day): 611,841 ZA rows
>   carried, 177,839 rows across 28 other countries left behind. That is *more*
>   SA coverage than the trim would have kept, not less — every ZA place at
>   every confidence level rather than only confidence ≥ 0.5.
> - **Copied, not re-imported.** `tools/place_index_move_project.py` moves the
>   already-backfilled `house_number` / `street_key` columns straight across, so
>   the destination never runs the backfill that caused the outage. Nothing was
>   re-downloaded from Overture.
>
> **Result:** main went from 477 MB (95.4% of the free ceiling) to **24 MB
> (4.8%)**, and shed the workload that was **53.0% of all its query execution
> time**. Extras sits at 235 MB (47.1%). Warm searches ~0.25 s, faster than the
> 373 ms average on main beforehand.
>
> The canonical description now lives in **CLAUDE.md §1, §4 and §10.2**. Read
> those first; this file is kept for the reasoning behind the decisions.

Written 2026-08-16, immediately after the outage. Everything here is measured,
not estimated — the numbers came off the live project.

## Why

| | |
|---|---|
| Database before trim | **477 MB of a 500 MB free ceiling (95.4%)** |
| `place_index` | **413 MB** (258 MB heap + 155 MB indexes) |
| All 68 *other* `public` tables | **47 MB** |

The entire MineLink application is 47 MB. One reference table is 87% of the
database. That is what left no headroom when the Overture backfill ran, and it
is the standing risk even now that the write storm itself is fixed.

**Supabase grants two free projects per account** ([billing docs][b]) and this
account uses one. A second free project is another free 500 MB at no cost.

[b]: https://supabase.com/docs/guides/platform/billing-on-supabase

## Why this is safe to split — measured, not assumed

`place_index` is genuinely standalone. Verified on the live database:

```sql
-- 0 foreign keys in either direction; only its own PK + 2 CHECK constraints
select conname, contype from pg_constraint
where conrelid='public.place_index'::regclass
   or confrelid='public.place_index'::regclass;
--  place_index_lat_valid  c
--  place_index_lon_valid  c
--  place_index_pkey       p

-- 0 views depend on it; exactly 2 functions touch it
--  search_place_index, _place_index_rank
```

Nothing in MineLink joins to it. It takes a text query and returns coordinates.
That is the whole contract, and it is why it can live in another database
without touching trips, stockpiles, recon or targets.

## The move

### 1. Create the second free project

Same account, and note the docs' wording: the two-project limit counts across
every organization where you are Owner or Admin. Region `eu-west-1`, to match.

### 2. Apply the `place_index` migrations, in order

These six and **only** these six — they are self-contained:

```
20260815150000_place_index.sql                  table, pg_trgm, RLS, trigram index
20260815160000_place_index_word_search.sql      word search
20260815170000_place_index_fts.sql              FTS index + _place_index_rank
20260816090000_place_index_house_numbers.sql    house_number / street_key + interpolation
20260816100000_place_index_interpolated_search.sql  search_place_index
20260816140000_place_street_key_never_null.sql  the never-NULL fix (see below)
```

> ⚠️ `20260816090000` contains an **unbounded whole-table `UPDATE`** (its lines
> 98–102). Against an empty table that is instant, which is the only way it
> should ever run. Apply these to the new project **before** loading any data,
> never after. Applying them to a populated table is the shape of work that
> caused the outage.

### 3. Load it

```bash
python tools/overture_import.py --token-file <token> --project-ref <NEW_REF>
```

The full 789,680-row set fits comfortably in a fresh 500 MB project (~413 MB).
The loader is now paced (`--pause`, default 1.0s) — do not set it to 0.

If the backfill is ever needed again, use `tools/place_index_backfill.py`, never
a hand-written loop. That is the lesson the outage cost.

### 4. Point the app at it — one function

The service already takes its place-index lookup as an **injectable function**
(`place_search_service.dart:140`), so nothing structural changes. Only
`_placeIndexLookup` (line 147) needs a different client:

```dart
static Future<List<PlaceHit>> _placeIndexLookup(String query) async {
  final rows = await PlaceIndexConfig.client.rpc(   // <- was SupabaseConfig.client
    'search_place_index',
    params: {'p_query': query, 'p_limit': 6},
  ) as List;
  ...
}
```

Add a `PlaceIndexConfig` beside `SupabaseConfig` (`lib/core/config/`) holding
the second project's URL + publishable key, resolved the same way — `--dart-define`
or a bundled `config/place_index.live.json`. **Never hardcode the key**
(CLAUDE.md §1).

Keep the existing fallback chain intact. If the second project is unreachable
the search must degrade to Nominatim, exactly as it does today on an unloaded
table — an address lookup failing is not worth an exception reaching the user.

### 5. Keep it awake

**Free projects pause after 7 days of low activity.** The docs: *"Typically a
few user requests to the database each day over the previous week is enough to
keep the project from being paused."*

The picker is used irregularly, so it needs a deliberate ping — a daily
`select 1` from a scheduled job, or a cheap uptime monitor hitting the REST
endpoint. **Without this the picker will silently stop working after a quiet
week**, and the failure looks exactly like "no results" rather than an outage.

### 6. Reclaim the main project

Only after the new project answers a real search:

```sql
drop table public.place_index cascade;   -- takes search_place_index + _place_index_rank
```

Main database: **~477 MB → ~64 MB (13%)**.

## Verify before calling it done

Per CLAUDE.md §1, prove health with a probe, not a status field — and check
**every** service, on **both** projects:

```bash
curl -s -H "Authorization: Bearer <token>" \
  "https://api.supabase.com/v1/projects/<ref>/health?services=db,pooler,rest,auth,realtime,storage"
```

`realtime` reports `healthy: true` with `info.db_connected: false` when Postgres
is gone — read the nested flag.

Then the real test, which is the address that started all of this:

```sql
select * from public.search_place_index('Westway Rd Fourways', 3);
-- Micro-Ctrl — 15 Westway Rd, Fourways, Sandton, Gauteng, 2191, ZA
```

And in the app: the picker must still find
**"2nd Floor, Trumpet On Keyes, 21 Keyes Ave, Rosebank"** — a real saved
`company_locations` row, and an address **OpenStreetMap does not contain**.
That is the reason none of the free hosted geocoders (Nominatim, Photon,
LocationIQ, Geoapify — all OSM readers) can replace this table.

## After 14 September

Once the main project is on a paid plan (8 GB), this split is optional. Either
keep it — it is architecturally cleaner, and it keeps a 790k-row reference table
off the transactional database — or move it back and delete the second project.
Nothing here is one-way: Overture is open data (CDLA-Permissive-2.0) and
`overture_import.py` reproduces the table from scratch in one command.

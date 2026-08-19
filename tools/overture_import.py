#!/usr/bin/env python3
"""Load Overture Maps places for southern Africa into public.place_index.

WHY THIS EXISTS
---------------
MineLink's location picker could not find real South African addresses because
OpenStreetMap does not hold them. Measured 2026-08-15 against the live
services:

  * Overpass finds 0 objects named "Trumpet" anywhere near Rosebank, and there
    is no Westway Road in Fourways at all.
  * Nominatim and Photon both read OSM, so neither can ever return them. Nor
    can LocationIQ or Geoapify, which read it too.
  * Overture Maps holds both: "15 Westway Rd, Fourways" and "39 Westway Rd"
    carry coordinates, among 789,680 named places across southern Africa, 92%
    of them with a street address.

Overture places are open data (CDLA-Permissive-2.0), assembled from Meta,
Microsoft, Foursquare and OSM contributions. No API key, no billing, no
per-query licence — which is the constraint CLAUDE.md §4 puts on this feature.

WHY IT IS NOT RUN BY THE AGENT
------------------------------
Loading needs a direct Postgres connection. The Supabase MCP can run DDL but
not a bulk COPY, and this environment holds no SUPABASE_DB_PASSWORD
(CLAUDE.md §6). So the schema ships applied and empty, and a human runs this
once. Until then `search_place_index` returns nothing and the picker falls
through to Nominatim exactly as it does today — shipping this early is safe.

USAGE
-----
    pip install duckdb psycopg2-binary

    # Connection string: Supabase dashboard -> Project Settings -> Database ->
    # Connection string -> URI. Use the SESSION pooler (port 5432); the
    # transaction pooler does not support COPY.
    export MINELINK_DB_URL='postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres'

    python tools/overture_import.py --dry-run     # sizes it, writes nothing
    python tools/overture_import.py               # loads it

    # Cheaper subset if database size is tight (see --help):
    python tools/overture_import.py --country ZA --min-confidence 0.5

SIZE
----
The full southern-Africa set is ~790k rows, ~129 MB as CSV. In Postgres expect
roughly 150 MB of heap plus ~90 MB for the trigram index. The project database
was 64 MB before this. On Supabase Free (500 MB) that is too close to the
ceiling — use --country ZA --min-confidence 0.5 (~590k rows) or upgrade first.
Check with:  select pg_size_pretty(pg_database_size(current_database()));

RE-RUNNING
----------
Safe. Rows are upserted on Overture's GERS id, which is stable across releases,
so a later release updates rows in place rather than duplicating them.
"""

from __future__ import annotations

import argparse
import os
import sys
import time

# The picker's own region box (place_search_service.dart): the Atlantic off
# Namibia to the Mozambique Channel, the Congo copper belt down to the Cape.
BBOX = (10.0, -36.0, 42.0, -4.0)  # xmin, ymin, xmax, ymax

# Pinned rather than "latest" so a re-run is reproducible and a release that
# changes the schema cannot silently break the load.
DEFAULT_RELEASE = "2026-07-22.0"

STAGING_DDL = """
create temporary table place_index_staging (
  id            text,
  name          text,
  category      text,
  addr_street   text,
  addr_locality text,
  addr_region   text,
  addr_postcode text,
  addr_country  text,
  confidence    real,
  lat           double precision,
  lon           double precision
) on commit drop;
"""

# Upsert on the GERS id. `search_text` is a generated column and is deliberately
# absent — Postgres maintains it.
MERGE_SQL = """
insert into public.place_index
  (id, name, category, addr_street, addr_locality, addr_region,
   addr_postcode, addr_country, confidence, lat, lon)
select distinct on (id)
  id, name, category, addr_street, addr_locality, addr_region,
  addr_postcode, addr_country, confidence, lat, lon
from place_index_staging
where id is not null and name is not null
  and lat between -90 and 90 and lon between -180 and 180
order by id, confidence desc nulls last
on conflict (id) do update set
  name          = excluded.name,
  category      = excluded.category,
  addr_street   = excluded.addr_street,
  addr_locality = excluded.addr_locality,
  addr_region   = excluded.addr_region,
  addr_postcode = excluded.addr_postcode,
  addr_country  = excluded.addr_country,
  confidence    = excluded.confidence,
  lat           = excluded.lat,
  lon           = excluded.lon;
"""


def build_query(release: str, country: str | None, min_confidence: float) -> str:
    src = (
        f"s3://overturemaps-us-west-2/release/{release}"
        "/theme=places/type=place/*"
    )
    xmin, ymin, xmax, ymax = BBOX
    filters = [
        f"bbox.xmin between {xmin} and {xmax}",
        f"bbox.ymin between {ymin} and {ymax}",
        "names.primary is not null",
    ]
    if min_confidence > 0:
        filters.append(f"confidence >= {min_confidence}")
    if country:
        filters.append(f"addresses[1].country = '{country}'")
    return f"""
    select
      id,
      names.primary                         as name,
      coalesce(categories.primary, basic_category) as category,
      addresses[1].freeform                 as addr_street,
      addresses[1].locality                 as addr_locality,
      addresses[1].region                   as addr_region,
      addresses[1].postcode                 as addr_postcode,
      addresses[1].country                  as addr_country,
      confidence,
      (bbox.ymin + bbox.ymax) / 2           as lat,
      (bbox.xmin + bbox.xmax) / 2           as lon
    from read_parquet('{src}')
    where {' and '.join(filters)}
    """


def _sql_literal(v) -> str:
    """A Postgres literal. Everything here is machine-generated from Overture,
    but place names contain apostrophes and backslashes by the thousand, so the
    escaping is not optional."""
    if v is None:
        return "null"
    if isinstance(v, (int, float)):
        return "null" if v != v else repr(v)  # NaN -> null
    s = str(v).replace("\\", "\\\\").replace("'", "''")
    # Postgres rejects NUL in text; Overture has a few.
    s = s.replace("\x00", "")
    return "E'" + s + "'"


def load_via_management_api(con, token_file: str, ref: str, batch: int,
                            total: int, pause: float = 1.0,
                            max_pause: float = 15.0,
                            slow_batch: float = 8.0) -> int:
    """Push the extract through the Management API's SQL endpoint.

    Used when the database password is not available (CLAUDE.md §6). Slower
    than COPY — one HTTPS round trip per batch — but it needs no direct
    Postgres connection, which is the thing that is usually missing.

    PACED ON PURPOSE. There is one Supabase project, it is production, and the
    live app shares it (CLAUDE.md §10.1, §10.2) on the FREE plan — 500 MB disk,
    shared CPU, ~1 GB RAM. An earlier unpaced bulk pass over this same table
    wedged the instance for hours on 2026-08-16: every pooled connection sat in
    a long write, autovacuum was locked out, and Realtime's replication slot
    fell far enough behind to pin WAL. `pause` is the setting that prevents
    that, and it grows on its own if the database starts running slow. Do not
    set it to 0 to "make the import faster" — the import finishing is not the
    goal; the app staying up while it finishes is.
    """
    import json
    import urllib.error
    import urllib.request

    with open(token_file, "r", encoding="utf-8") as fh:
        token = fh.read().strip()
    if not token.startswith("sbp_"):
        print("--token-file does not contain a Supabase access token",
              file=sys.stderr)
        return 2

    url = f"https://api.supabase.com/v1/projects/{ref}/database/query"

    def run_sql(sql: str) -> None:
        req = urllib.request.Request(
            url,
            data=json.dumps({"query": sql}).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                # Cloudflare fronts api.supabase.com and answers the default
                # "Python-urllib/3.x" agent with HTTP 403, error code 1010.
                "User-Agent": "MineLink-overture-import/1.0",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            urllib.request.urlopen(req, timeout=180).read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:400]
            raise RuntimeError(f"HTTP {e.code}: {detail}") from None

    cols = ("id", "name", "category", "addr_street", "addr_locality",
            "addr_region", "addr_postcode", "addr_country", "confidence",
            "lat", "lon")
    conflict = ", ".join(f"{c} = excluded.{c}" for c in cols[1:])

    # Load with the trigram index GONE, then build it once.
    #
    # Measured on this dataset: with the GIN index in place the insert rate
    # fell from ~1,700 rows/s to ~950 and kept sagging as the table grew, and a
    # search during the load took 11.5 SECONDS because every query had to scan
    # GIN's pending list. Building the index once at the end is faster overall
    # and packs it better.
    print("Dropping the trigram index for the load ...")
    run_sql("drop index if exists public.place_index_search_trgm;")

    print(f"Loading {total:,} rows over the Management API "
          f"({batch} per statement) ...")
    t0 = time.time()
    done = 0
    offset = 0
    while True:
        chunk = con.execute(
            f"select {', '.join(cols)} from extract "
            f"order by id limit {batch} offset {offset}"
        ).fetchall()
        if not chunk:
            break
        values = ",".join(
            "(" + ",".join(_sql_literal(v) for v in row) + ")" for row in chunk
        )
        t_batch = time.time()
        run_sql(
            f"insert into public.place_index ({', '.join(cols)}) values {values} "
            f"on conflict (id) do update set {conflict};"
        )
        took = time.time() - t_batch
        done += len(chunk)
        offset += batch
        elapsed = time.time() - t0
        rate = done / elapsed if elapsed else 0
        eta = (total - done) / rate if rate else 0
        print(f"  {done:,}/{total:,}  ({100.0 * done / total:.1f}%)  "
              f"{rate:.0f} rows/s  eta {eta / 60:.1f} min", flush=True)

        # The database sets the pace. A batch that ran long means it is under
        # pressure — backing off here is what keeps the live app answering.
        if took > slow_batch:
            pause = min(max_pause, pause * 1.5)
            print(f"    batch took {took:.1f}s — easing off, "
                  f"pause now {pause:.1f}s", flush=True)
        time.sleep(pause)

    print(f"  rows in {(time.time() - t0) / 60:.1f} min")

    print("Rebuilding the trigram index (a few minutes) ...")
    t1 = time.time()
    run_sql(
        "create index if not exists place_index_search_trgm "
        "on public.place_index using gin (search_text extensions.gin_trgm_ops);"
    )
    # Without ANALYZE the planner has no statistics for a table that went from
    # empty to ~790k rows, and will happily choose a sequential scan.
    run_sql("analyze public.place_index;")
    print(f"  index + analyze in {(time.time() - t1) / 60:.1f} min")
    print(f"TOTAL {(time.time() - t0) / 60:.1f} min")
    print("Verify:  select * from search_place_index('Westway Rd Fourways', 5);")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Load Overture places into public.place_index"
    )
    ap.add_argument("--release", default=DEFAULT_RELEASE,
                    help=f"Overture release (default {DEFAULT_RELEASE})")
    ap.add_argument("--country", default=None,
                    help="ISO country filter, e.g. ZA. Default: the whole "
                         "southern-Africa box.")
    ap.add_argument("--min-confidence", type=float, default=0.0,
                    help="Drop places below this Overture confidence (0..1).")
    ap.add_argument("--dry-run", action="store_true",
                    help="Count and sample only; touch no database.")
    ap.add_argument("--token-file", default=None,
                    help="Path to a file holding a Supabase personal access "
                         "token (sbp_...). Loads over the Management API SQL "
                         "endpoint instead of a direct Postgres connection, "
                         "for when the database password is not to hand. "
                         "Slower, but needs no psycopg2 and no db password. "
                         "The token is read from the file and never logged.")
    ap.add_argument("--project-ref", default="yftazblpmicqtamyiwyb",
                    help="Supabase project ref (used with --token-file).")
    ap.add_argument("--batch", type=int, default=1500,
                    help="Rows per statement when using --token-file.")
    ap.add_argument("--pause", type=float, default=1.0,
                    help="Seconds to wait between batches (default 1.0). Gives "
                         "autovacuum and the replication slot air on a shared "
                         "free-tier instance. Grows automatically if batches "
                         "run slow. See the 2026-08-16 outage note in "
                         "load_via_management_api.")
    ap.add_argument("--limit", type=int, default=0,
                    help="Load at most N rows. For smoke-testing the pipeline "
                         "before committing to the full set.")
    args = ap.parse_args()

    try:
        import duckdb
    except ImportError:
        print("duckdb is required:  pip install duckdb", file=sys.stderr)
        return 2

    con = duckdb.connect()
    con.execute("INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';")

    query = build_query(args.release, args.country, args.min_confidence)

    print(f"Scanning Overture {args.release} over southern Africa ...")
    t0 = time.time()
    limit = f" limit {args.limit}" if args.limit else ""
    con.execute(f"create table extract as {query}{limit}")
    rows = con.execute("select count(*) from extract").fetchone()[0]
    print(f"  {rows:,} places  ({time.time() - t0:.0f}s)")

    if rows == 0:
        print("Nothing to load — check the release name and filters.")
        return 1

    sample = con.execute(
        "select name, addr_street, addr_locality from extract "
        "where addr_street is not null limit 5"
    ).fetchall()
    print("  sample:")
    for s in sample:
        print("    ", " | ".join(str(x) for x in s))

    if args.dry_run:
        print("\n--dry-run: nothing written.")
        return 0

    if args.token_file:
        return load_via_management_api(
            con, args.token_file, args.project_ref, args.batch, rows,
            pause=args.pause,
        )

    dsn = os.environ.get("MINELINK_DB_URL", "").strip()
    if not dsn:
        print("MINELINK_DB_URL is not set — see the module docstring.",
              file=sys.stderr)
        return 2

    try:
        import psycopg2
    except ImportError:
        print("psycopg2 is required:  pip install psycopg2-binary",
              file=sys.stderr)
        return 2

    csv_path = os.path.abspath("overture_place_index.csv")
    con.execute(f"copy extract to '{csv_path}' (header, delimiter ',')")
    print(f"  staged {os.path.getsize(csv_path) / 1048576:.1f} MB -> {csv_path}")

    print("Loading into public.place_index ...")
    t0 = time.time()
    conn = psycopg2.connect(dsn)
    try:
        with conn, conn.cursor() as cur:
            cur.execute(STAGING_DDL)
            with open(csv_path, "r", encoding="utf-8") as fh:
                cur.copy_expert(
                    "copy place_index_staging from stdin with "
                    "(format csv, header true)",
                    fh,
                )
            cur.execute(MERGE_SQL)
            cur.execute("select count(*) from public.place_index")
            total = cur.fetchone()[0]
    finally:
        conn.close()

    print(f"  done in {time.time() - t0:.0f}s — place_index now holds "
          f"{total:,} rows")
    print("Verify:  select * from search_place_index('Westway Rd Fourways', 5);")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

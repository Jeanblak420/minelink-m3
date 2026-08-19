#!/usr/bin/env python3
"""Trim place_index to high-confidence South African places, and give the disk back.

WHY
---
Measured on the live project 2026-08-16, after the outage:

    database          477 MB   of a 500 MB free-tier ceiling   (95.4%)
    place_index       413 MB   (258 MB heap + 155 MB indexes)
    all 68 OTHER public tables  47 MB

So the entire MineLink application is 47 MB and this one reference table is 87%
of the database. Trimming it to ZA + confidence >= 0.5 keeps 443,078 places --
including every address the picker was built to find -- and drops 346,602
low-confidence and non-ZA rows:

    place_index       413 MB -> ~234 MB
    database          477 MB -> ~297 MB   (59%)

That is exactly the subset overture_import.py's docstring recommended for the
free tier ("--country ZA --min-confidence 0.5"). After a paid upgrade the full
set can be reloaded with overture_import.py.

WHY THE ORDER MATTERS (read before changing it)
-----------------------------------------------
A plain DELETE does NOT give disk back. It leaves dead tuples, and plain VACUUM
only makes that space reusable by the same table -- `pg_database_size` does not
move. Returning space to the OS needs a rewrite (VACUUM FULL), and a rewrite
normally needs free space equal to the new copy while the old one still exists.

At 95.4% full there is only ~23 MB spare, so a naive "DELETE then VACUUM FULL"
cannot fit and would fail -- or worse, fill the disk mid-rewrite.

The order below is chosen so that PEAK USAGE NEVER EXCEEDS WHERE WE ALREADY ARE:

    step                                     place_index      peak
    ----                                     -----------      ----
    now                                      413 MB
    1. drop the 2 rebuildable indexes        339 MB           (-74 MB)
    2. delete 346,602 rows (batched)         339 MB           unchanged on disk
    3. drop the primary key                  258 MB           (-81 MB)
    4. VACUUM FULL                           146 MB           404 MB transient
                                                              (still < 413 MB)
    5. rebuild pkey + fts + street_number    ~234 MB

Step 4's transient peak -- old heap 258 MB plus new heap 146 MB -- is 404 MB,
which is LESS than the 413 MB the table occupies right now. That is the whole
reason the indexes come off first. Do not reorder this.

COST WHILE IT RUNS
------------------
Between steps 1 and 5 the address picker has no index, so search_place_index
falls back to a sequential scan and is slow, and during VACUUM FULL the table
is locked outright. That is a few minutes of degraded ADDRESS SEARCH only --
nothing else in MineLink reads this table, and the picker already degrades to
Nominatim by design. Run it off-peak anyway.

USAGE
-----
    python tools/place_index_trim.py --token-file ~/.supabase_token --dry-run
    python tools/place_index_trim.py --token-file ~/.supabase_token --yes
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request

REF_DEFAULT = "yftazblpmicqtamyiwyb"
API = "https://api.supabase.com"

KEEP_PREDICATE = "addr_country = 'ZA' and confidence >= 0.5"
DROP_PREDICATE = "addr_country is distinct from 'ZA' or confidence is null or confidence < 0.5"

# Captured verbatim from pg_indexes on the live database 2026-08-16, so the
# rebuild is identical to what was there. Note street_number carries the
# `street_key <> ''` arm -- that matters now that place_street_key returns ''
# rather than NULL for unparseable addresses (migration 20260816140000);
# without it the index would carry ~83k useless empty-key entries.
REBUILD = [
    ("place_index_pkey",
     "alter table public.place_index add constraint place_index_pkey primary key (id)"),
    ("place_index_search_fts",
     "create index place_index_search_fts on public.place_index "
     "using gin (to_tsvector('simple'::regconfig, search_text))"),
    ("place_index_street_number",
     "create index place_index_street_number on public.place_index "
     "using btree (street_key, house_number) "
     "where house_number is not null and street_key is not null and street_key <> ''"),
]


class Stop(Exception):
    pass


class Client:
    def __init__(self, token: str, ref: str) -> None:
        self._t, self._ref = token, ref

    def _req(self, path: str, payload=None, timeout: int = 120):
        req = urllib.request.Request(
            f"{API}{path}",
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={
                "Authorization": f"Bearer {self._t}",
                "Content-Type": "application/json",
                "User-Agent": "MineLink-place-index-trim/1.0",
                "Accept": "application/json",
            },
            method="POST" if payload is not None else "GET",
        )
        with urllib.request.urlopen(req, timeout=timeout) as fh:
            body = fh.read().decode("utf-8", "replace")
        return json.loads(body) if body else None

    def sql(self, q: str, timeout: int = 120):
        try:
            return self._req(f"/v1/projects/{self._ref}/database/query",
                             {"query": q}, timeout)
        except urllib.error.HTTPError as e:
            raise Stop(f"HTTP {e.code}: "
                       f"{e.read().decode('utf-8','replace')[:300]}") from None

    def sql_tolerant(self, q: str, timeout: int = 120):
        """For statements that may outlive the HTTP timeout (VACUUM FULL).
        The server keeps working after the socket drops."""
        try:
            return self.sql(q, timeout)
        except (Stop, urllib.error.URLError, TimeoutError, OSError) as e:
            print(f"    (request returned '{str(e)[:70]}' — the statement is "
                  f"still running server-side; polling)")
            return None

    def unhealthy(self) -> list[str]:
        got = self._req(
            f"/v1/projects/{self._ref}/health"
            f"?services=db,rest,auth,storage,realtime", timeout=60)
        bad = []
        for s in got or []:
            if s.get("name") in ("db", "rest", "auth", "storage") and not s.get("healthy"):
                bad.append(f"{s.get('name')}={s.get('status')}")
            if s.get("name") == "realtime" and (s.get("info") or {}).get("db_connected") is False:
                bad.append("realtime=db_disconnected")
        return bad


def sizes(c: Client) -> dict:
    r = c.sql("""
      select pg_size_pretty(pg_database_size(current_database())) as db,
             round(pg_database_size(current_database())/1048576.0) as db_mb,
             round(100.0*pg_database_size(current_database())/(500*1048576.0),1) as pct,
             pg_size_pretty(pg_total_relation_size('public.place_index')) as pi,
             (select count(*) from public.place_index) as rows;
    """, timeout=60)
    return r[0]


def show(c: Client, label: str) -> None:
    s = sizes(c)
    print(f"  [{label}] db={s['db']} ({s['pct']}% of 500 MB)  "
          f"place_index={s['pi']}  rows={int(s['rows']):,}")


def wait_idle(c: Client, needle: str, limit_s: int = 1800) -> None:
    """Poll until no backend is still running a statement matching `needle`."""
    t0 = time.time()
    while time.time() - t0 < limit_s:
        r = c.sql(
            "select count(*) as n from pg_stat_activity "
            "where state='active' and pid <> pg_backend_pid() "
            f"and query ilike '%{needle}%';", timeout=60)
        if r and int(r[0]["n"]) == 0:
            return
        print(f"    still running… ({time.time()-t0:.0f}s)", flush=True)
        time.sleep(15)
    raise Stop(f"'{needle}' did not finish within {limit_s}s")


def run(c: Client, batch: int, pause: float, dry: bool) -> int:
    bad = c.unhealthy()
    if bad:
        raise Stop(f"refusing to start — unhealthy: {', '.join(bad)}")

    n = int(c.sql(f"select count(*) as n from public.place_index "
                  f"where {DROP_PREDICATE};", timeout=60)[0]["n"])
    keep = int(c.sql(f"select count(*) as n from public.place_index "
                     f"where {KEEP_PREDICATE};", timeout=60)[0]["n"])
    print(f"Would keep {keep:,} rows ({KEEP_PREDICATE}) and delete {n:,}.")
    show(c, "before")
    if dry:
        print("\n--dry-run: nothing written.")
        return 0
    if n == 0:
        print("Already trimmed.")
        return 0

    # 1 --------------------------------------------------------------- indexes
    print("\n1. Dropping the two rebuildable indexes (frees ~74 MB headroom)…")
    c.sql("drop index if exists public.place_index_search_fts;", timeout=300)
    c.sql("drop index if exists public.place_index_street_number;", timeout=300)
    show(c, "after drop")

    # 2 ---------------------------------------------------------------- delete
    print(f"\n2. Deleting {n:,} rows in batches of {batch:,} "
          f"({pause}s between, so the app keeps answering)…")
    done = 0
    while True:
        r = c.sql(f"""
          with pick as (
            select id from public.place_index
            where {DROP_PREDICATE}
            limit {batch}
          )
          delete from public.place_index p using pick
           where p.id = pick.id
          returning 1;
        """, timeout=300)
        moved = len(r) if isinstance(r, list) else 0
        if moved == 0:
            break
        done += moved
        print(f"   {done:,}/{n:,} deleted", flush=True)
        if c.unhealthy():
            raise Stop("a service degraded mid-delete — stopping")
        time.sleep(pause)
    show(c, "after delete")

    # 3 ------------------------------------------------------------------- pkey
    print("\n3. Dropping the primary key (frees ~81 MB so the rewrite fits)…")
    c.sql("alter table public.place_index drop constraint if exists place_index_pkey;",
          timeout=300)
    show(c, "after pkey drop")

    # 4 ------------------------------------------------------------- the rewrite
    print("\n4. VACUUM FULL — rewrites the heap and returns the space to the OS.")
    print("   The table is locked for this step. May take several minutes.")
    c.sql_tolerant("vacuum full public.place_index;", timeout=900)
    wait_idle(c, "vacuum full")
    show(c, "after vacuum full")

    # 5 ---------------------------------------------------------------- rebuild
    print("\n5. Rebuilding indexes…")
    for name, ddl in REBUILD:
        print(f"   {name} …", flush=True)
        c.sql_tolerant(ddl + ";", timeout=900)
        wait_idle(c, name)
    c.sql("analyze public.place_index;", timeout=600)

    got = c.sql("""
      select indexname from pg_indexes
      where schemaname='public' and tablename='place_index' order by indexname;
    """, timeout=60)
    names = sorted(x["indexname"] for x in (got or []))
    missing = [n for n, _ in REBUILD if n not in names]
    if missing:
        raise Stop(f"index(es) did not come back: {', '.join(missing)}")
    print(f"   indexes present: {', '.join(names)}")

    show(c, "after")
    probe = c.sql("select * from public.search_place_index('Westway Rd Fourways', 3);",
                  timeout=120)
    print(f"\n  search probe returned {len(probe or [])} row(s)")
    for p in (probe or [])[:3]:
        print(f"    {p.get('name')} — {p.get('addr_street')}")
    if not probe:
        raise Stop("the search probe returned nothing — investigate before "
                   "calling this done")

    bad = c.unhealthy()
    print(f"\n  final health: {'all services healthy' if not bad else ', '.join(bad)}")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Trim place_index to ZA + confidence >= 0.5 and reclaim disk")
    ap.add_argument("--token-file", required=True)
    ap.add_argument("--project-ref", default=REF_DEFAULT)
    ap.add_argument("--batch", type=int, default=25000,
                    help="Rows per delete batch (default 25000). Deletes are "
                         "far lighter than the UPDATEs that caused the outage, "
                         "but this is still batched and paced.")
    ap.add_argument("--pause", type=float, default=1.0)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true",
                    help="Required to actually delete.")
    a = ap.parse_args()

    if not a.dry_run and not a.yes:
        print("This deletes ~346,602 rows and rewrites the table. "
              "Re-run with --yes (or --dry-run to size it first).", file=sys.stderr)
        return 2
    try:
        token = open(a.token_file, encoding="utf-8").read().strip()
    except OSError as e:
        print(f"cannot read --token-file: {e}", file=sys.stderr)
        return 2
    if not token.startswith("sbp_"):
        print("--token-file is not a Supabase access token (sbp_...)", file=sys.stderr)
        return 2

    try:
        return run(Client(token, a.project_ref), a.batch, a.pause, a.dry_run)
    except Stop as e:
        print(f"\nStopped: {e}", file=sys.stderr)
        print("The database is left consistent. Re-run to continue — every step "
              "is idempotent.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

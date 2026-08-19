#!/usr/bin/env python3
"""Move public.place_index from the main MineLink project to the extras project.

WHAT AND WHY
------------
MineLink runs on TWO Supabase projects, both on the free plan (500 MB each):

    yftazblpmicqtamyiwyb   main app   — auth, trips, stockpiles, recon, targets
    qbydiuplqhmkaxarnuza   extras     — bulk reference data ("Mine-Link_Extra_Data")

place_index (Overture Maps places, ~790k rows) was 413 MB of a 477 MB main
database — 95.4% of the ceiling — while all 68 other tables together were 47 MB.
Moving it takes the main project to ~64 MB (13%), and carries over every row
MineLink can actually use (see SOUTH AFRICA ONLY below).

The table is safe to move because it is genuinely standalone, verified on the
live database: zero foreign keys in either direction, zero dependent views, and
exactly two functions touching it (search_place_index, _place_index_rank).
Nothing in MineLink joins to it — it takes a text query and returns coordinates.

SOUTH AFRICA ONLY
-----------------
`--where` defaults to `addr_country = 'ZA'`. MineLink operates only within South
Africa until further notice (client, 2026-08-16), and the source carries 29
countries: 611,841 ZA rows against 177,839 rows / ~41 MB spread over ZW, ZM, AO,
TZ, MZ, CD, BW, NA and twenty more. Carrying those would be dead weight in a
second 500 MB database.

Note this keeps MORE South African coverage than the trim it replaces, not less:
every ZA place at every confidence level (611,841) rather than only those at
confidence >= 0.5 (443,078). The destination still lands around 276 MB (55%):

    heap ~155 MB + pkey ~63 MB + fts ~50 MB + street_number ~8 MB

If MineLink ever crosses a border, re-run with a wider --where; the source rows
are still in Overture and overture_import.py reproduces them.

WHY IT COPIES RATHER THAN RE-IMPORTS
------------------------------------
overture_import.py would re-download ~790k rows from Overture's S3 bucket and
recompute house_number/street_key. Copying moves the ALREADY-BACKFILLED columns
straight across, so the destination never has to run the backfill that caused
the 2026-08-16 outage. Nothing is recomputed and nothing is downloaded.

WHY THE TRIGRAM INDEX IS DELIBERATELY NOT REBUILT
-------------------------------------------------
Migration 20260815150000 creates place_index_search_trgm (GIN trigram, ~90 MB).
This script drops it. That is not an oversight — read _place_index_rank:

    where to_tsvector('simple', p.search_text) @@ plainto_tsquery(...)   <- indexed
    order by confidence desc limit 2000
    ... then ilike and similarity() over those <=2000 candidate rows

Only the FTS predicate touches an index. The ilike and similarity() calls run on
the 2000 candidates already selected, so they need the pg_trgm EXTENSION (for the
similarity() function) but not a trigram INDEX over the whole table. The main
project has been serving searches without it since the import dropped it, which
is the practical proof. Skipping it saves ~90 MB on a 500 MB destination:

    heap ~200 MB + pkey ~81 MB + fts ~64 MB + street_number ~10 MB = ~355 MB (74%)

versus ~445 MB (89%) with it. If a future query shape needs `%`-operator search
over the whole table, rebuild it then and budget the space.

USAGE
-----
    python tools/place_index_move_project.py --token-file <file> --dry-run
    python tools/place_index_move_project.py --token-file <file> --yes

Resumable: it copies by ascending id and skips what the destination already has,
so an interrupted run continues where it stopped. It does NOT drop the source —
that is a separate, deliberate step once you have verified the destination.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

SRC_REF = "yftazblpmicqtamyiwyb"
DST_REF = "qbydiuplqhmkaxarnuza"
API = "https://api.supabase.com"

# Applied to the destination in this order, before any data is loaded.
# 20260816090000 carries an unbounded whole-table UPDATE; against an empty table
# that is instant, which is the ONLY way it should ever run.
MIGRATIONS = [
    "20260815150000_place_index.sql",
    "20260815160000_place_index_word_search.sql",
    "20260815170000_place_index_fts.sql",
    "20260816090000_place_index_house_numbers.sql",
    "20260816100000_place_index_interpolated_search.sql",
    "20260816140000_place_street_key_never_null.sql",
    "20260816160000_place_house_number_ascii_digits.sql",
]

# Applied AFTER the shared chain, from supabase/extras_project/migrations/.
# These correct the shared migrations for this project specifically and MUST NOT
# run against main. Order matters — they undo defaults the chain above sets:
#
#   ..._revoke_table_grants   removes the table-level SELECT that Supabase
#                             auto-grants on a newly created public table, so
#                             this project matches main (RLS *and* no grant).
#   ..._grant_anon            adds the `anon` execute grant that the shared
#                             chain does not, because on main only
#                             `authenticated` is correct — here a main-project
#                             JWT is invalid and every user arrives as `anon`.
#
# Without the second one a freshly built project answers every picker search
# with `permission denied` and the app silently falls through to Nominatim.
EXTRAS_MIGRATIONS = [
    "20260816190000_place_index_revoke_table_grants.sql",
    "20260816200000_search_place_index_grant_anon.sql",
]

# search_text is GENERATED — it must never be inserted into.
COLS = [
    ("id", "text"), ("name", "text"), ("category", "text"),
    ("addr_street", "text"), ("addr_locality", "text"), ("addr_region", "text"),
    ("addr_postcode", "text"), ("addr_country", "text"),
    ("confidence", "real"), ("lat", "double precision"), ("lon", "double precision"),
    ("house_number", "int"), ("street_key", "text"),
]
COL_NAMES = [c for c, _ in COLS]
COL_DEFS = ", ".join(f"{c} {t}" for c, t in COLS)

# Rebuilt AFTER the load. Captured verbatim from pg_indexes on the source.
POST_LOAD_INDEXES = [
    ("place_index_search_fts",
     "create index if not exists place_index_search_fts on public.place_index "
     "using gin (to_tsvector('simple'::regconfig, search_text))"),
    ("place_index_street_number",
     "create index if not exists place_index_street_number on public.place_index "
     "using btree (street_key, house_number) "
     "where house_number is not null and street_key is not null and street_key <> ''"),
]


class Stop(Exception):
    pass


class Project:
    def __init__(self, token: str, ref: str, label: str) -> None:
        self.ref, self.label = ref, label
        self._t = token

    def _post(self, path: str, payload, timeout: int):
        req = urllib.request.Request(
            f"{API}{path}",
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={
                "Authorization": f"Bearer {self._t}",
                "Content-Type": "application/json",
                # Cloudflare fronts api.supabase.com and answers the default
                # urllib agent with HTTP 403 code 1010.
                "User-Agent": "MineLink-place-index-move/1.0",
                "Accept": "application/json",
            },
            method="POST" if payload is not None else "GET",
        )
        with urllib.request.urlopen(req, timeout=timeout) as fh:
            body = fh.read().decode("utf-8", "replace")
        return json.loads(body) if body else None

    def sql(self, q: str, timeout: int = 180):
        try:
            return self._post(f"/v1/projects/{self.ref}/database/query",
                              {"query": q}, timeout)
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:400]
            raise Stop(f"[{self.label}] HTTP {e.code}: {detail}") from None
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            raise Stop(f"[{self.label}] cannot reach: {e}") from None

    def healthy(self) -> list[str]:
        got = self._post(
            f"/v1/projects/{self.ref}/health"
            f"?services=db,rest,auth,storage,realtime", None, 60)
        bad = []
        for s in got or []:
            if s.get("name") in ("db", "rest", "auth", "storage") and not s.get("healthy"):
                bad.append(f"{s['name']}={s.get('status')}")
        return bad

    def scalar(self, q: str, key: str, timeout: int = 180):
        r = self.sql(q, timeout)
        if not r:
            raise Stop(f"[{self.label}] no rows from: {q[:80]}")
        return r[0][key]


def dollar_quote(payload: str) -> str:
    """Embed arbitrary text in SQL without escaping. Verifies the tag is absent
    rather than assuming it — a collision would be a silent SQL injection into
    our own statement."""
    for tag in ("mlcopy", "mlcopy2", "mlcopy3", "mlcopyx"):
        marker = f"${tag}$"
        if marker not in payload:
            return f"{marker}{payload}{marker}"
    raise Stop("could not find a safe dollar-quote tag for this batch")


def apply_migrations(dst: Project, repo: Path) -> None:
    print(f"\n1. Applying {len(MIGRATIONS)} migrations to {dst.label} "
          f"(empty table — this is the only safe order)…")
    # A brand-new project has no migration ledger; it is created by whichever
    # Supabase tool touches it first. Same DDL the CLI/MCP bootstrap uses.
    dst.sql("""
      create schema if not exists supabase_migrations;
      create table if not exists supabase_migrations.schema_migrations
        (version text not null primary key);
      alter table supabase_migrations.schema_migrations
        add column if not exists statements text[];
      alter table supabase_migrations.schema_migrations
        add column if not exists name text;
    """, timeout=120)
    for fname in MIGRATIONS:
        path = repo / "supabase" / "migrations" / fname
        if not path.exists():
            raise Stop(f"missing migration file: {path}")
        sql = path.read_text(encoding="utf-8")
        print(f"   {fname} …", flush=True)
        try:
            dst.sql(sql, timeout=600)
        except Stop as e:
            # 42P13: a later migration `create or replace`s a function with a
            # different return shape than an earlier one created. Postgres
            # refuses that outright, so this chain CANNOT be replayed onto a
            # fresh database as-is — it only ever worked on the main project
            # because the function happened to be dropped between applies.
            # That is a latent bug in the migration files themselves (a
            # `supabase db reset` would hit it too) and should be fixed there;
            # handled here so the move is not blocked on it.
            m = re.search(r"DROP FUNCTION ([a-zA-Z0-9_]+\([^)]*\))", str(e))
            if "42P13" not in str(e) or not m:
                raise
            sig = m.group(1)
            print(f"     return type changed — dropping public.{sig} and retrying")
            dst.sql(f"drop function if exists public.{sig} cascade;", timeout=300)
            dst.sql(sql, timeout=600)
        dst.sql(
            "insert into supabase_migrations.schema_migrations (version, name) "
            f"values ('{fname[:14]}', {dollar_quote(fname[15:-4])}) "
            "on conflict (version) do nothing;", timeout=60)

    # Then the extras-only corrections, from supabase/extras_project/migrations/.
    # These are NOT optional and NOT cosmetic — see the module docstring on
    # EXTRAS_MIGRATIONS. Skipping them leaves a project that looks built and
    # answers every search with `permission denied`.
    print(f"   + {len(EXTRAS_MIGRATIONS)} extras-only migrations…")
    for fname in EXTRAS_MIGRATIONS:
        path = repo / "supabase" / "extras_project" / "migrations" / fname
        if not path.exists():
            raise Stop(f"missing extras migration: {path}")
        print(f"   {fname} …", flush=True)
        dst.sql(path.read_text(encoding="utf-8"), timeout=600)
        dst.sql(
            "insert into supabase_migrations.schema_migrations (version, name) "
            f"values ('{fname[:14]}', {dollar_quote(fname[15:-4])}) "
            "on conflict (version) do nothing;", timeout=60)

    # Prove the boundary rather than assume it: the wrapper must be callable by
    # anon, and the table underneath must not be readable by anon at all.
    ok = dst.sql(
        "select has_function_privilege('anon', "
        "  'public.search_place_index(text,int)', 'execute') as rpc_ok, "
        "       has_table_privilege('anon', 'public.place_index', 'select') as table_readable;",
        timeout=60)[0]
    if not ok["rpc_ok"]:
        raise Stop("anon cannot execute search_place_index — every picker search "
                   "on this project would fail silently")
    if ok["table_readable"]:
        raise Stop("anon can read place_index directly — the table grant was "
                   "not revoked")
    print("   migrations applied (anon: RPC yes, table no — matches main).")


def prepare_for_load(dst: Project) -> None:
    print("\n2. Dropping indexes for the load (rebuilt in step 4)…")
    # The trigram index is dropped and NOT rebuilt — see the module docstring.
    for idx in ("place_index_search_trgm", "place_index_search_fts",
                "place_index_street_number"):
        dst.sql(f"drop index if exists public.{idx};", timeout=300)
    print("   done (place_index_search_trgm is dropped for good, by design).")


def copy_rows(src: Project, dst: Project, batch: int, pause: float,
              where: str) -> int:
    total = int(src.scalar(
        f"select count(*) as n from public.place_index where {where};", "n"))
    already = int(dst.scalar("select count(*) as n from public.place_index;", "n"))
    last = dst.scalar("select coalesce(max(id),'') as m from public.place_index;", "m")
    print(f"\n3. Copying {total:,} rows matching [{where}] "
          f"({already:,} already present — resuming after id '{last[:24]}')…")

    sel = ", ".join(COL_NAMES)
    done, t0 = already, time.time()
    while True:
        payload = src.scalar(
            f"select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)::text as j "
            f"from (select {sel} from public.place_index "
            f"where ({where}) and id > {dollar_quote(last)} "
            f"order by id limit {batch}) t;",
            "j", timeout=180)
        rows = json.loads(payload)
        if not rows:
            break

        dst.sql(
            f"insert into public.place_index ({sel}) "
            f"select {sel} from jsonb_to_recordset({dollar_quote(payload)}::jsonb) "
            f"as x({COL_DEFS}) "
            f"on conflict (id) do nothing;", timeout=300)

        last = rows[-1]["id"]
        done += len(rows)
        rate = (done - already) / max(time.time() - t0, 1e-6)
        eta = (total - done) / rate / 60 if rate else 0
        print(f"   {done:,}/{total:,} ({100.0*done/total:.1f}%)  "
              f"{rate:.0f} rows/s  eta {eta:.0f} min", flush=True)
        time.sleep(pause)

    return total


def finish(src: Project, dst: Project, total: int) -> int:
    print("\n4. Rebuilding indexes on the destination…")
    for name, ddl in POST_LOAD_INDEXES:
        print(f"   {name} …", flush=True)
        try:
            dst.sql(ddl + ";", timeout=900)
        except Stop as e:
            # A long CREATE INDEX can outlive the HTTP timeout while succeeding.
            print(f"     ({str(e)[:70]} — checking whether it landed)")
        got = dst.sql("select indexname from pg_indexes where schemaname='public' "
                      "and tablename='place_index';", timeout=60)
        if name not in {g["indexname"] for g in (got or [])}:
            raise Stop(f"{name} did not get built — stopping before you rely on it")
    dst.sql("analyze public.place_index;", timeout=900)

    print("\n5. Verifying…")
    dcount = int(dst.scalar("select count(*) as n from public.place_index;", "n"))
    print(f"   source {total:,} rows / destination {dcount:,} rows")
    if dcount != total:
        raise Stop(f"row count mismatch — {total-dcount:,} missing. Re-run to resume.")

    probe = dst.sql("select * from public.search_place_index('Westway Rd Fourways', 3);",
                    timeout=180)
    print(f"   search probe: {len(probe or [])} row(s)")
    for p in (probe or [])[:3]:
        print(f"     {p.get('name')} — {p.get('addr_street')}")
    if not probe:
        raise Stop("the destination returns no search results — do NOT drop the "
                   "source table until this works")

    size = dst.sql("select pg_size_pretty(pg_database_size(current_database())) as db, "
                   "pg_size_pretty(pg_total_relation_size('public.place_index')) as pi, "
                   "round(100.0*pg_database_size(current_database())/(500*1048576.0),1) as pct;",
                   timeout=60)[0]
    print(f"   destination: db={size['db']} ({size['pct']}% of 500 MB), "
          f"place_index={size['pi']}")

    bad = dst.healthy() + src.healthy()
    print(f"\n   health: {'both projects healthy' if not bad else ', '.join(bad)}")
    print("\nDone. The source table is UNTOUCHED — verify the app against the new "
          "project first, then drop it there to reclaim the 413 MB:")
    print("     drop table public.place_index cascade;")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Move place_index to the extras project")
    ap.add_argument("--token-file", required=True)
    ap.add_argument("--from-ref", default=SRC_REF)
    ap.add_argument("--to-ref", default=DST_REF)
    ap.add_argument("--repo", default=".", help="Repo root holding supabase/migrations")
    ap.add_argument("--batch", type=int, default=1000,
                    help="Rows per round trip (default 1000).")
    ap.add_argument("--pause", type=float, default=0.3)
    ap.add_argument("--where", default="addr_country = 'ZA'",
                    help="Which source rows to carry over. Defaults to South "
                         "Africa only — MineLink operates only in ZA until "
                         "further notice, and the other 28 countries are "
                         "177,839 rows / ~41 MB of dead weight. Pass "
                         "\"true\" to copy everything.")
    ap.add_argument("--skip-migrations", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true")
    a = ap.parse_args()

    if not a.dry_run and not a.yes:
        print("Re-run with --yes (or --dry-run first).", file=sys.stderr)
        return 2
    try:
        token = Path(a.token_file).read_text(encoding="utf-8").strip()
    except OSError as e:
        print(f"cannot read --token-file: {e}", file=sys.stderr)
        return 2
    if not token.startswith("sbp_"):
        print("--token-file is not a Supabase access token (sbp_...)", file=sys.stderr)
        return 2

    src = Project(token, a.from_ref, "main")
    dst = Project(token, a.to_ref, "extras")
    try:
        for p in (src, dst):
            bad = p.healthy()
            if bad:
                raise Stop(f"{p.label} ({p.ref}) unhealthy: {', '.join(bad)}")
        print(f"both projects healthy.  main={src.ref}  extras={dst.ref}")

        n = int(src.scalar("select count(*) as n from public.place_index;", "n"))
        keep = int(src.scalar(f"select count(*) as n from public.place_index "
                              f"where {a.where};", "n"))
        sz = src.scalar("select pg_size_pretty(pg_total_relation_size("
                        "'public.place_index')) as s;", "s")
        print(f"source place_index: {n:,} rows, {sz}")
        print(f"carrying over {keep:,} matching [{a.where}]; "
              f"leaving {n - keep:,} behind")
        if a.dry_run:
            print("\n--dry-run: nothing written.")
            return 0

        if not a.skip_migrations:
            apply_migrations(dst, Path(a.repo))
        prepare_for_load(dst)
        total = copy_rows(src, dst, a.batch, a.pause, a.where)
        return finish(src, dst, total)
    except Stop as e:
        print(f"\nStopped: {e}", file=sys.stderr)
        print("Nothing was dropped from the source. Re-run to resume — the copy "
              "skips rows the destination already has.", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nInterrupted. Safe to re-run — it resumes.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())

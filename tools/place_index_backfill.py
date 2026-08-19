#!/usr/bin/env python3
"""Backfill place_index.house_number / street_key WITHOUT wedging the database.

WHY THIS EXISTS
---------------
On 2026-08-16 this backfill was run as hand-written SQL through the Management
API: 20,000-row UPDATE batches, back-to-back, no pause, against the ~790k-row
place_index. Each batch took 27-45 s. Measured from the postgres logs:

  * Every batch rewrote 20,000 rows, and an UPDATE in Postgres writes a NEW row
    version rather than editing in place -- so a full pass roughly doubles the
    heap in dead tuples before anything is reclaimed.
  * Autovacuum never reclaimed them. A CREATE INDEX on the same table was
    running concurrently and holds AccessExclusiveLock, so the logs show
    "skipping vacuum of place_index --- lock not available" over and over for
    the entire window.
  * The WAL torrent outran Realtime's logical replication slot: list_changes
    went from milliseconds to 12-14 s, the slot was dropped and recreated, and
    a lagging slot PINS WAL from being recycled -- more disk, not less.
  * Every pooled connection was tied up in a 30-45 s statement, so PostgREST,
    Auth, Storage and Realtime all queued behind it and timed out.

Postgres stopped answering at 23:49 and stayed down. There is ONE Supabase
project and it is production (CLAUDE.md §10.2); the live app and other agent
sessions share it (§10.1). This project is on the FREE plan: 500 MB disk,
shared CPU, ~1 GB RAM. It has no headroom to absorb that.

This script does the same work without any of that. It is the supported way to
run the backfill; do not hand-roll the loop again.

WHAT IT DOES DIFFERENTLY
------------------------
  * Small batches (default 2,000, not 20,000) so no single statement holds a
    connection long enough to starve the app.
  * A real pause between batches (default 1.5 s), so autovacuum and the
    replication slot get scheduler time. This is the setting that matters most
    and the one the manual loop did not have at all.
  * Adaptive back-off: if a batch runs long, the pause grows. The database sets
    the pace, not the script.
  * It refuses to start unless every Supabase service is healthy, and it
    re-checks as it goes, stopping the moment anything degrades. Health is
    proven with a probe, never with the project's status field -- that field
    read ACTIVE_HEALTHY for the whole outage while nothing answered
    (CLAUDE.md §1).
  * It never builds an index while backfilling. Do that once, afterwards.
  * It asserts forward progress: the remaining count must strictly fall, or it
    stops. The original loop could not terminate at all, because
    place_street_key returned NULL for unparseable addresses and the
    `where street_key is null` predicate re-selected them forever
    (fixed in migration 20260816140000).

USAGE
-----
    # A Supabase personal access token (sbp_...), read from a file, never
    # logged and never committed.
    python tools/place_index_backfill.py --token-file ~/.supabase_token

    python tools/place_index_backfill.py --token-file ~/.supabase_token --status
    python tools/place_index_backfill.py --token-file ~/.supabase_token --dry-run

AFTERWARDS
----------
Once this reports 0 remaining, and only then, build the anchor index:

    create index concurrently if not exists place_index_street_number
      on public.place_index (street_key, house_number)
      where house_number is not null and street_key is not null and street_key <> '';
    analyze public.place_index;

CONCURRENTLY matters: the plain form takes AccessExclusiveLock and is what
locked autovacuum out during the outage.
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

# Services that must be healthy before and during the run. `pooler` and
# `realtime` are deliberately included: during the outage both reported
# healthy at the top level while `db_connected` was false underneath, so the
# check below reads the nested flags too.
REQUIRED_SERVICES = ("db", "rest", "auth", "storage")


class Stop(Exception):
    """Raised to halt the run cleanly, leaving the database in a good state."""


class Client:
    def __init__(self, token: str, ref: str) -> None:
        self._token = token
        self._ref = ref

    def _request(self, path: str, payload: dict | None = None, timeout: int = 120):
        req = urllib.request.Request(
            f"{API}{path}",
            data=json.dumps(payload).encode("utf-8") if payload is not None else None,
            headers={
                "Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json",
                # Cloudflare fronts api.supabase.com and answers the default
                # "Python-urllib/3.x" agent with HTTP 403, code 1010.
                "User-Agent": "MineLink-place-index-backfill/1.0",
                "Accept": "application/json",
            },
            method="POST" if payload is not None else "GET",
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as fh:
                body = fh.read().decode("utf-8", "replace")
            return json.loads(body) if body else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:300]
            raise Stop(f"HTTP {e.code} from {path}: {detail}") from None
        except urllib.error.URLError as e:
            raise Stop(f"cannot reach {path}: {e.reason}") from None

    def sql(self, query: str, timeout: int = 120):
        return self._request(
            f"/v1/projects/{self._ref}/database/query", {"query": query}, timeout
        )

    def unhealthy(self) -> list[str]:
        """Names of services that are not fully healthy. Empty list = all good."""
        services = ",".join(REQUIRED_SERVICES + ("pooler", "realtime"))
        got = self._request(
            f"/v1/projects/{self._ref}/health?services={services}", timeout=60
        )
        bad = []
        for svc in got or []:
            name = svc.get("name")
            if name in REQUIRED_SERVICES and not svc.get("healthy"):
                bad.append(f"{name}={svc.get('status') or 'UNHEALTHY'}")
            # Realtime reports healthy:true with db_connected:false when
            # Postgres is gone. The nested flag is the honest one.
            info = svc.get("info") or {}
            if name == "realtime" and info.get("db_connected") is False:
                bad.append("realtime=db_disconnected")
        return bad


REMAINING_SQL = """
select count(*) as remaining
from public.place_index
where addr_street is not null and street_key is null;
"""

# The batch. `pick` is bounded and ordered by primary key so each pass takes a
# small, contiguous slice rather than a scattered one, which keeps the number
# of heap pages dirtied per batch low.
BATCH_SQL = """
with pick as (
  select id from public.place_index
  where addr_street is not null and street_key is null
  order by id
  limit {batch}
)
update public.place_index p
   set house_number = public.place_house_number(p.addr_street),
       street_key   = public.place_street_key(p.addr_street)
  from pick
 where p.id = pick.id;
"""


def _remaining(client: Client) -> int:
    got = client.sql(REMAINING_SQL, timeout=90)
    if not got:
        raise Stop("no rows back from the remaining-count query")
    return int(got[0]["remaining"])


def run(client: Client, batch: int, pause: float, max_pause: float,
        slow_batch: float, dry_run: bool) -> int:
    bad = client.unhealthy()
    if bad:
        print(f"Refusing to start — unhealthy: {', '.join(bad)}", file=sys.stderr)
        print("Bring the project back before backfilling (CLAUDE.md §1).",
              file=sys.stderr)
        return 1

    remaining = _remaining(client)
    print(f"{remaining:,} rows still need street_key.")
    if remaining == 0:
        print("Nothing to do.")
        return 0
    if dry_run:
        est = (remaining / batch) * (pause + 2.0) / 60.0
        print(f"--dry-run: would run ~{remaining // batch + 1} batches of "
              f"{batch}, roughly {est:.0f} min. Nothing written.")
        return 0

    done = 0
    t_start = time.time()
    checked = time.time()

    while remaining > 0:
        t0 = time.time()
        client.sql(BATCH_SQL.format(batch=batch), timeout=180)
        took = time.time() - t0

        before, remaining = remaining, _remaining(client)
        moved = before - remaining
        done += moved

        # Terminates by construction only if the candidate set actually
        # shrinks. If it does not, the fixed-point bug is back (see
        # migration 20260816140000) and looping would repeat the outage.
        if moved <= 0:
            raise Stop(
                f"a batch of {batch} changed nothing and {remaining:,} rows "
                f"still match — stopping rather than looping forever. "
                f"Check that place_street_key returns '' and not NULL for "
                f"unparseable addresses (migration 20260816140000)."
            )

        # The database sets the pace. A batch that ran long means it is under
        # pressure, so wait longer before adding more.
        if took > slow_batch:
            pause = min(max_pause, pause * 1.5)
            print(f"  batch took {took:.1f}s — easing off, pause now {pause:.1f}s")

        rate = done / (time.time() - t_start)
        eta = remaining / rate / 60 if rate else 0
        print(f"  {done:,} done, {remaining:,} left  "
              f"({took:.1f}s/batch, {rate:.0f} rows/s, eta {eta:.0f} min)",
              flush=True)

        # Re-check health periodically, not every batch — the health endpoint
        # is not free, and hammering it during a load is its own problem.
        if time.time() - checked > 60:
            bad = client.unhealthy()
            if bad:
                raise Stop(f"stopping — a service degraded mid-run: {', '.join(bad)}")
            checked = time.time()

        time.sleep(pause)

    print(f"\nDone in {(time.time() - t_start) / 60:.1f} min.")
    print("Now build the anchor index, CONCURRENTLY — see the module docstring.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Throttled backfill for place_index.street_key/house_number"
    )
    ap.add_argument("--token-file", required=True,
                    help="File holding a Supabase access token (sbp_...). Read "
                         "from the file and never logged.")
    ap.add_argument("--project-ref", default=REF_DEFAULT)
    ap.add_argument("--batch", type=int, default=2000,
                    help="Rows per batch (default 2000). The outage was caused "
                         "by 20000; do not go back there.")
    ap.add_argument("--pause", type=float, default=1.5,
                    help="Seconds between batches (default 1.5). This is what "
                         "gives autovacuum and the replication slot air.")
    ap.add_argument("--max-pause", type=float, default=15.0,
                    help="Ceiling for the adaptive back-off.")
    ap.add_argument("--slow-batch", type=float, default=8.0,
                    help="A batch slower than this grows the pause.")
    ap.add_argument("--status", action="store_true",
                    help="Report how much is left and exit.")
    ap.add_argument("--dry-run", action="store_true",
                    help="Size the job, write nothing.")
    args = ap.parse_args()

    if args.batch > 5000:
        print("--batch above 5000 is what caused the 2026-08-16 outage on this "
              "free-tier project. Refusing.", file=sys.stderr)
        return 2

    try:
        with open(args.token_file, "r", encoding="utf-8") as fh:
            token = fh.read().strip()
    except OSError as e:
        print(f"cannot read --token-file: {e}", file=sys.stderr)
        return 2
    if not token.startswith("sbp_"):
        print("--token-file does not contain a Supabase access token (sbp_...)",
              file=sys.stderr)
        return 2

    client = Client(token, args.project_ref)
    try:
        if args.status:
            bad = client.unhealthy()
            print(f"health: {'OK' if not bad else ', '.join(bad)}")
            print(f"{_remaining(client):,} rows still need street_key.")
            return 0
        return run(client, args.batch, args.pause, args.max_pause,
                   args.slow_batch, args.dry_run)
    except Stop as e:
        print(f"\nStopped: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nInterrupted. Safe to re-run — it picks up where it left off.",
              file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())

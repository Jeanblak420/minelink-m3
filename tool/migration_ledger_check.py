#!/usr/bin/env python3
"""The migration files and the applied-migration ledger must say the same thing.

    python tool/migration_ledger_check.py
    python tool/migration_ledger_check.py --selftest
    python tool/migration_ledger_check.py --json

WHY THIS EXISTS
---------------
CLAUDE.md §6 decided on 2026-08-08 that the files under `supabase/migrations/`
are the source of truth and the ledger must match them: one file per applied
migration, one row per file, and each row's `version` equal to its filename
stamp. That rule was written because the targets work had ended up with three
applied migrations against two files, one of them a fix (`grant select`,
without which realtime is live and silent) that existed only in the database.

The rule was enforced by nothing but attention, and on 2026-08-17 attention
lost. The ledger repoint for `20260817330000`:

    update supabase_migrations.schema_migrations
       set version = '20260817330000' where name = '...';

was issued in the same statement batch as a self-rolling-back probe:

    do $$ ... raise exception 'PROBE ...' $$;

A `raise` rolls back its whole batch, and the `update` was sitting in it. So
the repoint was undone and the row silently kept the timestamp
`apply_migration` had assigned it, `20260817133116`. **Nothing failed.** The
apply succeeded, the probe printed its findings, and the ledger was quietly
wrong. It was found by hand, comparing `ls` output against a `select`.

That comparison is mechanical. This is it.

WHAT IT CHECKS
--------------
Three faults, which are the three ways the two sides can disagree:

  unapplied   a migration file with no ledger row. Either it was never applied
              (so a fresh database and this one are not the same schema), or it
              was applied under a different name.
  unmirrored  a ledger row with no file. The 2026-08-08 case: something ran
              against production that git cannot reproduce.
  misstamped  a row whose `version` is not its own filename's stamp. This
              session's case. Ordering in a cold replay comes from the version,
              so a drifted stamp can reorder a replay against the order the
              files were actually applied in.

WHY IT NEEDS THE DATABASE
-------------------------
The other checkers in this directory read source. Half of this comparison only
exists in Postgres, so this one is modelled on `tool/health_probe.py`: it reads
the same `config/supabase.live.json` the app ships with, so it checks the
database users actually reach.

`supabase_migrations` is not a schema PostgREST exposes --

    PGRST106  Invalid schema: supabase_migrations

-- so the ledger is read through `public.migration_ledger()` (migration
`20260817340000`), which is platform-admin only. That means credentials:

    ML_LEDGER_EMAIL      defaults to the walkbot test super admin
    ML_LEDGER_PASSWORD   required; no default, and never committed

There is deliberately no fallback that skips the check quietly. A checker that
cannot reach its evidence exits 2 and says so, because "could not check" read
as "green" is the exact failure this file exists to prevent.

THE BASELINE
------------
`tool/migration_ledger_baseline.json` records discrepancies that predate this
check, each with a reason. They are accepted, not hidden -- printed every run,
and a baselined entry that has since been REPAIRED is itself a failure, so the
baseline can only shrink.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS = os.path.join(ROOT, "supabase", "migrations")
BASELINE = os.path.join(ROOT, "tool", "migration_ledger_baseline.json")
CONFIG = os.path.join(ROOT, "config", "supabase.live.json")

# Cloudflare answers the default urllib agent with a 403 (code 1010).
UA = "MineLink-ops/1.0"

FILENAME = re.compile(r"^(\d{14})_(.+)\.sql$")


# ---------------------------------------------------------------------------
# The comparison. Pure, so --selftest can plant faults in it directly.
# ---------------------------------------------------------------------------

def compare(filenames, rows):
    """Faults between migration [filenames] and ledger [rows].

    [rows] is a list of (version, name). Returns a list of
    (kind, identity, detail) sorted for stable output.

    Matching is by NAME, not by stamp: `apply_migration` records the name it
    was given and assigns its own timestamp, so the name is the stable half
    and a disagreeing stamp is precisely the fault worth reporting.
    """
    faults = []

    by_name = {}
    for f in sorted(filenames):
        m = FILENAME.match(f)
        if not m:
            faults.append(("malformed", f,
                           "not <14-digit stamp>_<name>.sql, so it has no "
                           "stamp to check and will not replay in order"))
            continue
        stamp, name = m.group(1), m.group(2)
        if name in by_name:
            faults.append(("ambiguous", name,
                           "two files share this migration name: %s and %s"
                           % (by_name[name][1], f)))
            continue
        by_name[name] = (stamp, f)

    seen = {}
    for version, name in rows:
        if name in seen:
            faults.append(("ambiguous", name,
                           "two ledger rows share this migration name: "
                           "versions %s and %s" % (seen[name], version)))
            continue
        seen[name] = version

        if name not in by_name:
            faults.append(("unmirrored", name,
                           "applied as version %s, but no file in "
                           "supabase/migrations/ carries this name -- git "
                           "cannot reproduce this database" % version))
            continue

        stamp, filename = by_name[name]
        if version != stamp:
            faults.append(("misstamped", name,
                           "ledger says version %s, %s says %s -- a cold "
                           "replay would order this differently from the "
                           "order it was really applied in"
                           % (version, filename, stamp)))

    for name, (stamp, filename) in by_name.items():
        if name not in seen:
            faults.append(("unapplied", name,
                           "%s has no ledger row -- it was never applied, or "
                           "was applied under another name" % filename))

    return sorted(faults)


def identity(fault):
    """The stable key a baseline entry suppresses."""
    return "%s:%s" % (fault[0], fault[1])


def apply_baseline(faults, baseline):
    """(unexpected, accepted, stale). `stale` = baselined but now repaired."""
    accepted_keys = set(baseline)
    seen = {identity(f) for f in faults}
    unexpected = [f for f in faults if identity(f) not in accepted_keys]
    accepted = [f for f in faults if identity(f) in accepted_keys]
    stale = sorted(accepted_keys - seen)
    return unexpected, accepted, stale


# ---------------------------------------------------------------------------
# Reading the two sides
# ---------------------------------------------------------------------------

def read_files():
    return [f for f in os.listdir(MIGRATIONS) if f.endswith(".sql")]


def read_baseline():
    if not os.path.exists(BASELINE):
        return {}
    with open(BASELINE, encoding="utf-8") as f:
        return json.load(f).get("accepted", {})


def _post(url, key, token, body, timeout=30):
    headers = {
        "apikey": key,
        "Authorization": "Bearer " + (token or key),
        "Content-Type": "application/json",
        "User-Agent": UA,
    }
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            return f.status, f.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read(600).decode("utf-8", "replace")
    except Exception as e:
        return None, str(e)


class Unreachable(Exception):
    """The ledger could not be read. NOT the same as 'the ledger is fine'."""


def read_ledger():
    """[(version, name)] from the live database, or raise [Unreachable]."""
    with open(CONFIG, encoding="utf-8") as f:
        cfg = json.load(f)
    url = cfg["SUPABASE_URL"].rstrip("/")
    key = cfg["SUPABASE_PUBLISHABLE_KEY"]

    email = os.environ.get("ML_LEDGER_EMAIL",
                           "walkbot.superadmin@mineralguide.com")
    password = os.environ.get("ML_LEDGER_PASSWORD")
    if not password:
        raise Unreachable(
            "ML_LEDGER_PASSWORD is not set.\n"
            "  public.migration_ledger() is platform-admin only, so this "
            "check has to sign in.\n"
            "  Set ML_LEDGER_PASSWORD (and optionally ML_LEDGER_EMAIL, "
            "currently %s).\n"
            "  The password is deliberately not in the repo." % email)

    status, payload = _post(url + "/auth/v1/token?grant_type=password", key,
                            None, {"email": email, "password": password})
    if status != 200:
        raise Unreachable("could not sign in as %s: HTTP %s %s"
                          % (email, status, payload[:200]))
    token = json.loads(payload)["access_token"]

    status, payload = _post(url + "/rest/v1/rpc/migration_ledger", key, token,
                            {})
    if status == 404:
        raise Unreachable(
            "public.migration_ledger() does not exist on this project.\n"
            "  Apply supabase/migrations/20260817340000_the_migration_ledger"
            "_can_be_read_and_checked.sql first.")
    if status != 200:
        raise Unreachable("migration_ledger() refused: HTTP %s %s"
                          % (status, payload[:200]))

    rows = json.loads(payload)
    if not rows:
        raise Unreachable(
            "the ledger came back EMPTY, which no live project can be. "
            "Treating that as 'every file is unapplied' would be a false "
            "alarm, so this is reported as unreachable instead.")
    return [(r["version"], r["name"]) for r in rows]


# ---------------------------------------------------------------------------
# Self-test: plant each fault and prove the check bites.
# ---------------------------------------------------------------------------

def selftest():
    """A checker that matches nothing reports green forever.

    Each case plants ONE fault into a known-clean pair and asserts the check
    finds exactly it -- the same discipline as `release_guards.dart
    --selftest`. The clean case is asserted too: a check that fires on
    everything is as useless as one that fires on nothing.
    """
    clean_files = [
        "20260101000000_first.sql",
        "20260102000000_second.sql",
        "20260103000000_third.sql",
    ]
    clean_rows = [
        ("20260101000000", "first"),
        ("20260102000000", "second"),
        ("20260103000000", "third"),
    ]

    cases = []

    def case(label, files, rows, expect_kind, expect_id):
        cases.append((label, files, rows, expect_kind, expect_id))

    # 0. The control. If this ever fires, every verdict below is noise.
    case("a matching pair is clean", clean_files, clean_rows, None, None)

    # 1. A file nobody applied -- a fresh database would not match this one.
    case("file with no ledger row",
         clean_files + ["20260104000000_fourth.sql"], clean_rows,
         "unapplied", "unapplied:fourth")

    # 2. The 2026-08-08 case: something ran that git cannot reproduce.
    case("ledger row with no file",
         clean_files, clean_rows + [("20260104000000", "fourth")],
         "unmirrored", "unmirrored:fourth")

    # 3. THIS SESSION'S CASE. The repoint was rolled back by a probe in the
    #    same batch, so the row kept apply_migration's own timestamp. Note the
    #    name still matches perfectly -- only the stamp drifted, which is
    #    exactly why a count-the-rows check would have missed it.
    case("row version is not its filename stamp",
         clean_files,
         [("20260101000000", "first"), ("20260102000000", "second"),
          ("20260103133116", "third")],
         "misstamped", "misstamped:third")

    # 4. A file that cannot be ordered in a replay at all.
    case("file with no timestamp prefix",
         clean_files + ["fix_it_later.sql"], clean_rows,
         "malformed", "malformed:fix_it_later.sql")

    # 5. Two files claiming the same migration -- the shape the rule "never
    #    fold a follow-up fix into an earlier file" is guarding against.
    case("two files, one migration name",
         clean_files + ["20260104000000_third.sql"], clean_rows,
         "ambiguous", "ambiguous:third")

    ok = True
    for label, files, rows, expect_kind, expect_id in cases:
        faults = compare(files, rows)
        if expect_kind is None:
            passed = not faults
            detail = "found %s" % [identity(f) for f in faults]
        else:
            ids = [identity(f) for f in faults]
            passed = ids == [expect_id]
            detail = "found %s, wanted exactly ['%s']" % (ids, expect_id)
        ok &= passed
        print("  %-42s %s%s" % (label, "bites" if passed else "MISSED",
                                "" if passed else "  -- " + detail))

    # The baseline must suppress a known fault, and must NOT go on suppressing
    # one that has been repaired -- otherwise it becomes permanent cover.
    faults = compare(clean_files + ["20260104000000_fourth.sql"], clean_rows)
    unexpected, accepted, stale = apply_baseline(
        faults, {"unapplied:fourth": "accepted for the test"})
    suppresses = not unexpected and len(accepted) == 1
    print("  %-42s %s" % ("baseline suppresses a known fault",
                          "works" if suppresses else "BROKEN"))
    ok &= suppresses

    _, _, stale = apply_baseline(
        compare(clean_files, clean_rows), {"unapplied:gone": "no longer true"})
    detects_stale = stale == ["unapplied:gone"]
    print("  %-42s %s" % ("baseline entry that was repaired is flagged",
                          "works" if detects_stale else "BROKEN"))
    ok &= detects_stale

    print("\n%s" % ("all planted faults were caught" if ok
                    else "SELFTEST FAILED -- this checker cannot be trusted"))
    return 0 if ok else 1


# ---------------------------------------------------------------------------

def main():
    if "--selftest" in sys.argv:
        print("Planting each fault this check claims to catch:\n")
        return selftest()

    files = read_files()
    try:
        rows = read_ledger()
    except Unreachable as e:
        print("COULD NOT CHECK -- this is not a pass.\n\n  %s" % e)
        return 2

    baseline = read_baseline()
    faults = compare(files, rows)
    unexpected, accepted, stale = apply_baseline(faults, baseline)

    print("%d migration files, %d ledger rows" % (len(files), len(rows)))

    if accepted:
        # Grouped, because 101 paragraphs of identical reasoning buries the
        # verdict underneath itself. `--verbose` prints every one.
        by_kind = {}
        for fault in accepted:
            by_kind.setdefault(fault[0], []).append(fault[1])
        print("\naccepted (tool/migration_ledger_baseline.json):")
        for kind in sorted(by_kind):
            names = sorted(by_kind[kind])
            print("  %-11s %3d   %s" % (kind, len(names),
                                        baseline["%s:%s" % (kind, names[0])]
                                        .split(". ")[0] + "."))
            if "--verbose" in sys.argv:
                for n in names:
                    print("                    %s" % n)

    for kind, ident, detail in unexpected:
        print("\nFAIL  %s: %s\n      %s" % (kind, ident, detail))

    for ident in stale:
        print("\nFAIL  stale baseline entry: %s\n"
              "      this is baselined but no longer happens. Delete the "
              "entry -- a baseline that never shrinks is permanent cover."
              % ident)

    if "--json" in sys.argv:
        print(json.dumps({
            "files": len(files), "rows": len(rows),
            "unexpected": [list(f) for f in unexpected],
            "accepted": [list(f) for f in accepted],
            "stale": stale,
        }, indent=2))

    if unexpected or stale:
        print("\n%d unexpected, %d stale baseline entries"
              % (len(unexpected), len(stale)))
        return 1

    # Deliberately not "every file has its row": with a baseline in place that
    # would be false, and a check that overstates its own verdict is the thing
    # this file was written to stop.
    if accepted:
        print("\nPASS  no NEW drift. %d known discrepancies stand, each "
              "accepted in the baseline." % len(accepted))
    else:
        print("\nPASS  every file has its row, every row has its file, every "
              "version is its filename's stamp")
    return 0


raise SystemExit(main())

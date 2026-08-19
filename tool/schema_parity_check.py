#!/usr/bin/env python3
"""Production's schema must be the schema the migration files build.

    python tool/schema_parity_check.py
    python tool/schema_parity_check.py --selftest
    python tool/schema_parity_check.py --accept   (record the current state)

WHY THIS EXISTS
---------------
On 2026-08-18 this repo's migrations were replayed into an empty database for
the first time. Git could not rebuild the product: 79 of 251 files applied and
`public.profiles` was never created. Getting to 255 of 255 took a day, and the
schema diff that followed found things no replay could have:

  a whole table with no migration (`seat_reassignment_log`), four functions
  with no migration, seven columns with no migration, a column typed `uuid`
  in the files and `text` in production, and a cron job — the one that decides
  which organisations lose access — that production runs and no file creates.

Every one had the same shape: somebody changed production directly, nothing
recorded it, and nothing ever compared the two. They were found years late, by
hand, only because someone finally looked.

This is the instrument that makes looking automatic. `public.schema_fingerprint
()` (migration 20260818090000) reduces the live schema to nine digests; this
compares them with the values in `tool/schema_parity_baseline.json`, committed
to git. Change production out of band and a digest moves and this fails.

NINE SHAPES, and the ninth is the point. Tables, columns, functions, function
BODIES, policies, triggers, indexes, RLS — and CRON. Cron was added only after
the diff showed a rebuilt database would have scheduled the SUPERSEDED expiry
function against real companies every night. Nothing in the schema would have
shown it. Bodies are hashed too: a function present in both databases with a
different body is invisible to a name-level check and is exactly where
behaviour drifts.

HOW TO USE IT WHEN IT FAILS
---------------------------
A failure means production and the recorded state disagree. That is not
automatically a fault — you may have just applied a migration. The question is
always the same: **is there a file for this?**

  * Applied a migration, and the file is in `supabase/migrations/`?
    Run with `--accept` and commit the updated baseline in the SAME commit.
  * Changed something through the dashboard, the SQL editor or an MCP call
    with no file? That is the defect. Write the migration, then `--accept`.

`--accept` is deliberately a separate, explicit action. A baseline that updates
itself records drift instead of reporting it.

CREDENTIALS
-----------
`schema_fingerprint()` is platform-admin only, for the same reason as
`migration_ledger()`: the publishable key ships inside the web bundle, so an
`anon` grant is a public grant, and this returns a map of the whole schema.

    ML_LEDGER_EMAIL      defaults to the walkbot test super admin
    ML_LEDGER_PASSWORD   required; no default, never committed

A run that cannot reach the database exits 2 and says so. "Could not check"
must never read as "green" — that misreading is the reason half of this file's
opening paragraph exists.

LIMIT, STATED
-------------
This proves production matches a RECORDED state. It does not, on its own,
prove production matches what the FILES build — that needs a cold replay into
an empty project, which is a manual operation (see CLAUDE.md 6). What this
gives you is the guarantee that between replays, nothing moved unrecorded.
"""

import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "tool", "schema_parity_baseline.json")
CONFIG = os.path.join(ROOT, "config", "supabase.live.json")
UA = "MineLink-ops/1.0"

SHAPES = ("tables", "columns", "functions", "bodies", "policies",
          "triggers", "indexes", "rls", "cron")


class Unreachable(Exception):
    """Could not read the fingerprint. NOT the same as 'it matches'."""


def compare(live, recorded):
    """[(shape, recorded, live)] for every shape that moved.

    Pure, so --selftest can drive it. A shape present live but absent from the
    baseline counts as a difference: a new shape must be accepted deliberately,
    not adopted in silence.
    """
    out = []
    for shape in sorted(set(live) | set(recorded)):
        was = recorded.get(shape)
        now = live.get(shape)
        if was != now:
            out.append((shape, was, now))
    return out


def _post(url, key, token, body, timeout=60):
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(),
        headers={"apikey": key,
                 "Authorization": "Bearer " + (token or key),
                 "Content-Type": "application/json", "User-Agent": UA},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            return f.status, f.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read(600).decode("utf-8", "replace")
    except Exception as e:
        return None, str(e)


def read_live():
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
            "  public.schema_fingerprint() is platform-admin only, so this "
            "check has to sign in.\n"
            "  Set ML_LEDGER_PASSWORD (and optionally ML_LEDGER_EMAIL, "
            "currently %s)." % email)

    status, payload = _post(url + "/auth/v1/token?grant_type=password", key,
                            None, {"email": email, "password": password})
    if status != 200:
        raise Unreachable("could not sign in as %s: HTTP %s %s"
                          % (email, status, payload[:200]))
    token = json.loads(payload)["access_token"]

    status, payload = _post(url + "/rest/v1/rpc/schema_fingerprint", key,
                            token, {})
    if status == 404:
        raise Unreachable(
            "public.schema_fingerprint() does not exist on this project.\n"
            "  Apply supabase/migrations/20260818090000_the_schema_can_be_"
            "fingerprinted.sql first.")
    if status != 200:
        raise Unreachable("schema_fingerprint() refused: HTTP %s %s"
                          % (status, payload[:200]))

    rows = json.loads(payload)
    if not rows:
        raise Unreachable("the fingerprint came back EMPTY, which no live "
                          "schema can be. Reported as unreachable rather than "
                          "as 'everything changed'.")
    return {r["shape"]: {"items": r["items"], "digest": r["digest"]}
            for r in rows}


def read_baseline():
    if not os.path.exists(BASELINE):
        return {}
    with open(BASELINE, encoding="utf-8") as f:
        return json.load(f).get("shapes", {})


def write_baseline(live):
    doc = {
        "_what": "Digests of the live schema of the MAIN Supabase project "
                 "(yftazblpmicqtamyiwyb), from public.schema_fingerprint().",
        "_why": "Every gap the 2026-08-18 cold replay found was an out-of-band "
                "change to production that no migration recorded and nothing "
                "compared. This file is what makes the next one fail a check "
                "instead of being found years later.",
        "_how_to_update": "Only with `python tool/schema_parity_check.py "
                          "--accept`, and only in the SAME commit as the "
                          "migration that justifies the change. If there is no "
                          "migration, do not update this file -- write the "
                          "migration.",
        "shapes": live,
    }
    with open(BASELINE, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, sort_keys=False)
        f.write("\n")


def selftest():
    ok = True

    def case(label, live, recorded, expect):
        nonlocal ok
        got = len(compare(live, recorded))
        passed = got == expect
        ok &= passed
        print("  %-56s %s%s" % (label, "bites" if passed else "MISSED",
                                "" if passed else "  -- found %d, wanted %d"
                                % (got, expect)))

    same = {s: {"items": 1, "digest": "d" + s} for s in SHAPES}
    case("an unchanged schema is silent", same, dict(same), 0)

    # Each of these is a real thing that happened to this project.
    moved = dict(same, columns={"items": 844, "digest": "changed"})
    case("a column added out of band", moved, same, 1)

    body = dict(same, bodies={"items": 1, "digest": "rewritten"})
    case("a function body rewritten in place", body, same, 1)

    cron = dict(same, cron={"items": 9, "digest": "different"})
    case("a cron job rescheduled by hand", cron, same, 1)

    count_only = dict(same, indexes={"items": 288, "digest": "dindexes"})
    case("an index count that moved without the digest", count_only, same, 1)

    # A shape appearing for the first time must be accepted deliberately.
    case("a new shape is not adopted silently", same,
         {k: v for k, v in same.items() if k != "cron"}, 1)
    case("a shape disappearing is reported",
         {k: v for k, v in same.items() if k != "cron"}, same, 1)

    two = dict(same, rls={"items": 68, "digest": "x"},
               policies={"items": 153, "digest": "y"})
    case("two shapes at once", two, same, 2)

    print("\n%s" % ("all planted faults were caught" if ok
                    else "SELFTEST FAILED -- this checker cannot be trusted"))
    return 0 if ok else 1


def main():
    if "--selftest" in sys.argv:
        print("Planting each shape this check claims to catch:\n")
        return selftest()

    try:
        live = read_live()
    except Unreachable as e:
        print("COULD NOT CHECK -- this is not a pass.\n\n  %s" % e)
        return 2

    if "--accept" in sys.argv:
        write_baseline(live)
        print("Recorded the current schema as the baseline:\n")
        for shape in SHAPES:
            if shape in live:
                print("  %-10s %5d items  %s"
                      % (shape, live[shape]["items"], live[shape]["digest"]))
        print("\nCommit tool/schema_parity_baseline.json in the SAME commit as "
              "the migration that justifies it.")
        return 0

    recorded = read_baseline()
    if not recorded:
        print("No baseline recorded yet.\n"
              "Run with --accept once the schema is known-good, and commit the "
              "result.")
        return 2

    moved = compare(live, recorded)
    if not moved:
        print("PASS  all %d schema shapes match the recorded baseline" % len(SHAPES))
        return 0

    print("%d schema shape(s) differ from tool/schema_parity_baseline.json.\n"
          % len(moved))
    for shape, was, now in moved:
        print("  FAIL  %s" % shape)
        print("        recorded: %s" % (was or "(absent)"))
        print("        live    : %s" % (now or "(absent)"))
    print("\nIs there a migration file for this change?\n"
          "  yes -> python tool/schema_parity_check.py --accept, and commit the\n"
          "         baseline in the same commit as that migration.\n"
          "  no  -> that is the defect. Write the migration first.")
    return 1


raise SystemExit(main())

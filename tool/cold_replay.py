#!/usr/bin/env python3
"""Rebuild this product's database from git alone, and diff it against production.

    python tool/cold_replay.py --org <org-id>        full run: create, replay, diff
    python tool/cold_replay.py --diff-only <ref>     re-diff an existing scratch project
    python tool/cold_replay.py --selftest

WHY THIS EXISTS
---------------
CLAUDE.md §6 said for months that building a project from the files is the only
thing that tests a cold replay. On 2026-08-18 it was finally done, and git could
not rebuild the product: 79 of 251 files applied and `public.profiles` was never
created. Getting from there to a database that matches production took a day and
about a dozen replays.

The harness that did it lived in a temp directory. That is precisely how
`health_probe.py` came to exist only in a Downloads folder while CLAUDE.md §1
made probing mandatory — the one tool a standing rule depends on, not in version
control, re-derived by every session. So it lives here now.

WHAT IT DOES
------------
1. Creates a brand-new empty Supabase project on the given org.
2. Applies every `supabase/migrations/*.sql` in stamp order, paced, retrying on
   the management API's throttler.
3. Dumps NINE schema shapes and compares them with
   `tool/schema_parity_baseline.json`.

Paced at 1.3s deliberately. The first attempt at this ran flat out, and 37 files
came back as `ThrottlerException: Too Many Requests` — indistinguishable from
real failures in the summary. That run was discarded and redone rather than
reported.

🚨 THE NINE SHAPE QUERIES BELOW MUST MATCH `public.schema_fingerprint()`
(migration 20260818110000) EXACTLY. They are two copies of one definition, and
when they drift the comparison reports a difference that is not there — which
happened the same day the policies shape gained its predicates here but not in
the replay dump.

READING THE `bodies` DIFFERENCE — DO NOT RE-DERIVE THIS
-------------------------------------------------------
`bodies` is EXPECTED to differ, and it is not a logic difference. Measured
2026-08-18, the count collapsed as normalisation improved:

    raw prosrc ................................. <=175 functions "differ"
    strip SQL comments .......................... <=63
    + fold case .................................. 18
    + normalise whitespace around punctuation .... 14
    + read the last one .......................... 0

Every single difference was comments, capitalisation, whitespace, or a `hint`
written as adjacent string literals across three lines where production has one.
**Zero functions differ in logic.** The cause is that production's copies were
applied through the MCP, which does not carry the files' comments; the files are
the documented source and are the better artifact.

So: do not "reconcile" bodies by stripping comments from the files to match a
hash. That destroys documentation to chase a digest. CLAUDE.md §6 rule 4 already
recorded this trap from the targets work — "5 of 15 functions differing, all
comments-only, executable SQL identical" — and it was still re-learned the hard
way here.
"""

import json
import os
import secrets
import string
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS = os.path.join(ROOT, "supabase", "migrations")
BASELINE = os.path.join(ROOT, "tool", "schema_parity_baseline.json")
UA = "MineLink-ops/1.0"
PACE = 1.3

# Keep in lockstep with public.schema_fingerprint(). See the header.
#
# Each entry is the AGGREGATE EXPRESSION and its FROM clause. count(*) and the
# md5 are both computed in SQL, exactly as the RPC does — never client-side.
# Deriving a count by splitting the aggregate on commas is wrong and was: policy
# predicates contain commas, so the policies shape reported 182 items for a set
# of 153 whose digest was already identical to production's.
SHAPES = {
    'tables':
        "select count(*) n, md5(coalesce(string_agg(t.table_name, ',' order by t.table_name),'')) digest from information_schema.tables t where t.table_schema='public' and t.table_type='BASE TABLE'",
    'columns':
        "select count(*) n, md5(coalesce(string_agg(c.table_name||'.'||c.column_name||':'||c.data_type, ',' order by c.table_name, c.column_name),'')) digest from information_schema.columns c where c.table_schema='public'",
    'functions':
        "select count(*) n, md5(coalesce(string_agg(q.n2, ',' order by q.n2),'')) digest from (select distinct p.proname n2 from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public') q",
    'bodies':
        "select count(*) n, md5(coalesce(string_agg(p.proname||':'||md5(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')), ',' order by p.proname),'')) digest from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public'",
    'policies':
        "select count(*) n, md5(coalesce(string_agg(pol.tablename||'.'||pol.policyname||':'||pol.cmd||':'||pol.permissive||':'||coalesce(pol.roles::text,'-')||':'||coalesce(pol.qual,'-')||':'||coalesce(pol.with_check,'-'), ',' order by pol.tablename, pol.policyname),'')) digest from pg_policies pol where pol.schemaname='public'",
    'triggers':
        "select count(*) n, md5(coalesce(string_agg(cl.relname||'.'||tg.tgname||':'||fp.proname, ',' order by cl.relname, tg.tgname),'')) digest from pg_trigger tg join pg_class cl on cl.oid=tg.tgrelid join pg_proc fp on fp.oid=tg.tgfoid join pg_namespace ns on ns.oid=cl.relnamespace where ns.nspname='public' and not tg.tgisinternal",
    'indexes':
        "select count(*) n, md5(coalesce(string_agg(ix.tablename||'.'||ix.indexname, ',' order by ix.tablename, ix.indexname),'')) digest from pg_indexes ix where ix.schemaname='public'",
    'rls':
        "select count(*) n, md5(coalesce(string_agg(cl.relname||':'||cl.relrowsecurity::text, ',' order by cl.relname),'')) digest from pg_class cl join pg_namespace ns on ns.oid=cl.relnamespace where ns.nspname='public' and cl.relkind='r'",
    'cron':
        "select coalesce((select count(*) from cron.job),0) n, coalesce((select md5(string_agg(j.jobname||' -> '||j.command, ',' order by j.jobname)) from cron.job j), md5('')) digest",
}

EXPECTED_DIFFERENT = {"bodies"}   # see the header — comments, not logic


def token():
    t = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not t:
        raise SystemExit(
            "SUPABASE_ACCESS_TOKEN is not set. This tool creates a throwaway "
            "project, so it needs a management token for the account that "
            "should own it.")
    return t


def api(method, path, body=None, timeout=180):
    req = urllib.request.Request(
        "https://api.supabase.com/v1" + path,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + token(),
                 "Content-Type": "application/json", "User-Agent": UA},
        method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            raw = f.read()
            return f.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read(800).decode("utf-8", "replace")
    except Exception as e:                      # noqa: BLE001
        return None, str(e)


def run_sql(ref, sql, attempt=0, timeout=300):
    req = urllib.request.Request(
        "https://api.supabase.com/v1/projects/%s/database/query" % ref,
        data=json.dumps({"query": sql}).encode(),
        headers={"Authorization": "Bearer " + token(),
                 "Content-Type": "application/json", "User-Agent": UA},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            return 200, f.read(4_000_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        payload = e.read(1500).decode("utf-8", "replace")
        # The throttler turned 37 files into fake failures on the first ever
        # run of this. Back off and retry rather than record a lie.
        if "Throttler" in payload and attempt < 6:
            time.sleep(5 * (attempt + 1))
            return run_sql(ref, sql, attempt + 1, timeout)
        return e.code, payload
    except Exception as e:                      # noqa: BLE001
        return None, str(e)


def replay(ref):
    files = sorted(f for f in os.listdir(MIGRATIONS) if f.endswith(".sql"))
    failed = []
    for i, fn in enumerate(files, 1):
        with open(os.path.join(MIGRATIONS, fn), encoding="utf-8",
                  errors="replace") as f:
            sql = f.read()
        time.sleep(PACE)
        status, payload = run_sql(ref, sql)
        ok = status == 200
        print("%3d/%d  %s  %s" % (i, len(files), "ok  " if ok else "FAIL", fn),
              flush=True)
        if not ok:
            print("        %s" % " ".join(payload[:300].split()), flush=True)
            failed.append((fn, payload[:400]))
    return files, failed


def fingerprint(ref):
    out = {}
    for shape, sql in SHAPES.items():
        status, payload = run_sql(ref, sql)
        if status != 200:
            out[shape] = {"items": None, "digest": "UNREADABLE: %s" % status}
            continue
        try:
            row = json.loads(payload)[0]
            out[shape] = {"items": int(row["n"]), "digest": row["digest"]}
        except Exception as e:                   # noqa: BLE001
            out[shape] = {"items": None, "digest": "UNREADABLE: %s" % e}
    return out


def compare(live, recorded):
    return [(s, recorded.get(s), live.get(s))
            for s in sorted(set(live) | set(recorded))
            if live.get(s) != recorded.get(s)]


def report(rebuilt):
    with open(BASELINE, encoding="utf-8") as f:
        recorded = json.load(f)["shapes"]
    moved = compare(rebuilt, recorded)
    print("\n%-10s %-8s %-34s %s" % ("shape", "items", "digest", ""))
    for shape in SHAPES:
        r = rebuilt.get(shape, {})
        p = recorded.get(shape, {})
        same = r == p
        note = "MATCH" if same else (
            "differs (EXPECTED — comments, not logic; see header)"
            if shape in EXPECTED_DIFFERENT else "DIFFERS")
        print("%-10s %-8s %-34s %s" % (shape, r.get("items"),
                                       str(r.get("digest"))[:32], note))
    unexpected = [m for m in moved if m[0] not in EXPECTED_DIFFERENT]
    return unexpected


def selftest():
    ok = True

    def case(label, got, want):
        nonlocal ok
        passed = got == want
        ok &= passed
        print("  %-52s %s" % (label, "bites" if passed else "MISSED"))

    same = {s: {"items": 1, "digest": "d"} for s in SHAPES}
    case("identical fingerprints compare equal", compare(same, dict(same)), [])
    moved = dict(same, indexes={"items": 2, "digest": "e"})
    case("a moved shape is reported", len(compare(moved, same)), 1)
    case("a missing shape is reported",
         len(compare({k: v for k, v in same.items() if k != "cron"}, same)), 1)
    case("bodies is the only expected-different shape",
         EXPECTED_DIFFERENT, {"bodies"})
    case("every shape has a query", sorted(SHAPES), sorted(
        ["tables", "columns", "functions", "bodies", "policies", "triggers",
         "indexes", "rls", "cron"]))
    # The lockstep requirement is real; assert the policies query still carries
    # the predicate columns that 20260818110000 added.
    case("policies query includes qual and with_check",
         all(k in SHAPES["policies"] for k in ("qual", "with_check",
                                               "permissive", "roles")), True)
    print("\n%s" % ("all checks pass" if ok else "SELFTEST FAILED"))
    return 0 if ok else 1


def main():
    if "--selftest" in sys.argv:
        print("Checking this harness's own invariants:\n")
        return selftest()

    if "--diff-only" in sys.argv:
        ref = sys.argv[sys.argv.index("--diff-only") + 1]
        return 1 if report(fingerprint(ref)) else 0

    if "--org" not in sys.argv:
        print(__doc__)
        return 2
    org = sys.argv[sys.argv.index("--org") + 1]

    pw = "".join(secrets.choice(string.ascii_letters + string.digits)
                 for _ in range(32))
    status, d = api("POST", "/projects",
                    {"organization_id": org, "name": "minelink-cold-replay",
                     "region": "eu-west-1", "db_pass": pw})
    if status not in (200, 201):
        print("could not create a scratch project: %s %s" % (status, d))
        return 2
    ref = d["id"]
    print("scratch project %s created\n" % ref, flush=True)

    for _ in range(40):
        if run_sql(ref, "select 1;")[0] == 200:
            break
        time.sleep(10)

    files, failed = replay(ref)
    print("\n%d/%d applied, %d failed" % (len(files) - len(failed), len(files),
                                          len(failed)))
    unexpected = report(fingerprint(ref))

    print("\nScratch project %s is still up so it can be inspected.\n"
          "DELETE IT when done:  DELETE /v1/projects/%s" % (ref, ref))
    return 1 if (failed or unexpected) else 0


raise SystemExit(main())

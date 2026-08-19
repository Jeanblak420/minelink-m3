"""Prove every Supabase service answers, on both projects.

CLAUDE.md §1 makes this mandatory: no piece of work is done while the database
is in anything but a healthy state, and health has to be shown with a **probe**,
not read off a status field. `get_project` reported `ACTIVE_HEALTHY` for the
entire 2026-08-16 outage while nothing answered.

It lives in the repo as of 2026-08-17 because until then it did not: the only
copy was in a Downloads folder, passed between sessions by hand, so the one
tool the standing rule depends on was not version controlled and each session
re-derived it.

Run:  python tool/health_probe.py           (exit 0 = every service answering)
      python tool/health_probe.py --json    (machine-readable)

Reads the same config the app ships with, so it probes what users reach.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = json.load(open(os.path.join(ROOT, "config", "supabase.live.json")))
EXTRA = json.load(open(os.path.join(ROOT, "config", "place_index.live.json")))

# Cloudflare fronts these hosts and answers the default urllib agent with a 403
# (code 1010). Always send a real one.
UA = "MineLink-ops/1.0"

results = []


def request(url, key, method="GET", body=None, timeout=30):
    """(status, body, seconds). Never raises for an HTTP error status."""
    headers = {"apikey": key, "Authorization": "Bearer " + key, "User-Agent": UA}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    started = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as f:
            return f.status, f.read(400).decode("utf-8", "replace"), time.time() - started
    except urllib.error.HTTPError as e:
        return e.code, e.read(400).decode("utf-8", "replace"), time.time() - started
    except Exception as e:  # DNS, TLS, connection refused, timeout
        return None, str(e), time.time() - started


def probe(label, url, key, method="GET", body=None, expect=(200,), note=""):
    code, payload, secs = request(url, key, method, body)
    ok = code in expect
    results.append({"service": label, "ok": ok, "status": code,
                    "seconds": round(secs, 2), "note": note})
    print("%-30s %s  HTTP %-4s %5.2fs  %s"
          % (label, "OK  " if ok else "FAIL", code, secs,
             note or payload.replace("\n", " ")[:70]))
    return ok


def probe_place_index():
    """The extras project, with one retry — and both timings reported.

    A single cold attempt is not a fair verdict here and reporting it as one
    misled this very script. Measured 2026-08-17 against the live project:

        cold   Sandton  3.18s      Durban  2.07s
        warm   Sandton  0.30s      Durban  0.33s   (limit 6 and limit 20 alike)

    So the query is not slow; its pages fall out of a free-tier instance's
    cache and the first read pays for them. That is why it sits either side of
    the project's ~3s `anon` statement_timeout, and why the client retries once
    on 57014 and only on 57014 (place_search_service.dart).

    A timeout on the first attempt is therefore DEGRADED, not down — real, and
    worth seeing, but not the same as a service that cannot answer. Both are
    printed; only a second failure counts as a failure.
    """
    url = EXTRA["PLACE_INDEX_SUPABASE_URL"].rstrip("/") + "/rest/v1/rpc/search_place_index"
    key = EXTRA["PLACE_INDEX_SUPABASE_PUBLISHABLE_KEY"]
    body = {"p_query": "Sandton", "p_limit": 6}

    code, payload, secs = request(url, key, "POST", body)
    if code == 200:
        results.append({"service": "extras / search_place_index", "ok": True,
                        "status": 200, "seconds": round(secs, 2), "note": ""})
        print("%-30s OK    HTTP 200  %5.2fs" % ("extras / search_place_index", secs))
        return True

    timed_out = "57014" in (payload or "")
    print("%-30s %s  HTTP %-4s %5.2fs  %s"
          % ("extras / search_place_index", "warn" if timed_out else "FAIL",
             code, secs, "statement timeout — retrying once" if timed_out
             else (payload or "").replace("\n", " ")[:70]))
    if not timed_out:
        results.append({"service": "extras / search_place_index", "ok": False,
                        "status": code, "seconds": round(secs, 2),
                        "note": (payload or "")[:120]})
        return False

    code2, payload2, secs2 = request(url, key, "POST", body)
    ok = code2 == 200
    note = ("answered on retry — DEGRADED, the first read pays for cold pages"
            if ok else "timed out twice")
    results.append({"service": "extras / search_place_index", "ok": ok,
                    "status": code2, "seconds": round(secs2, 2),
                    "note": note, "degraded": True})
    print("%-30s %s  HTTP %-4s %5.2fs  %s"
          % ("  extras (retry)", "OK  " if ok else "FAIL", code2, secs2, note))
    return ok


def main():
    u, k = MAIN["SUPABASE_URL"].rstrip("/"), MAIN["SUPABASE_PUBLISHABLE_KEY"]

    # 401 is the CORRECT answer here, not a fault: since the publishable/secret
    # key split, the PostgREST root endpoint accepts only a secret key. An
    # earlier version of this script expected 200 and reported the healthy
    # production database as failing.
    probe("main / PostgREST root", u + "/rest/v1/", k, expect=(200, 401),
          note="401 = correct; this endpoint requires a secret key")
    probe("main / Auth", u + "/auth/v1/health", k)
    probe("main / Storage", u + "/storage/v1/bucket", k, expect=(200, 400, 401, 403))
    # Realtime answers 401 without a key — answering is the point.
    probe("main / Realtime", u + "/realtime/v1/api/tenants/health", k,
          expect=(200, 401, 403, 404))
    # A REAL RPC, so this exercises Postgres rather than only the gateway. The
    # gateway answered throughout the 2026-08-16 outage.
    probe("main / Postgres via RPC", u + "/rest/v1/rpc/ml_today", k,
          method="POST", body={}, expect=(200,))
    probe("main / Edge Functions", u + "/functions/v1/whatsapp-send-otp", k,
          method="POST", body={}, expect=(200, 400, 401, 403, 422),
          note="401 invalid signature = the function ran")
    probe_place_index()

    ok = sum(1 for r in results if r["ok"])
    degraded = [r["service"] for r in results if r.get("degraded") and r["ok"]]
    print("\n%d/%d services answering" % (ok, len(results)))
    if degraded:
        print("DEGRADED (answering, but not on the first attempt): %s"
              % ", ".join(degraded))
    if "--json" in sys.argv:
        print(json.dumps(results, indent=2))
    return 0 if ok == len(results) else 1


raise SystemExit(main())

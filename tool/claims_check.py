#!/usr/bin/env python3
"""CLAUDE.md states facts about this product. Check that they are still true.

    python tool/claims_check.py
    python tool/claims_check.py --selftest
    python tool/claims_check.py --verbose

WHY THIS EXISTS
---------------
CLAUDE.md §4 is a status table in which agents record, in prose, what they
themselves built. Nothing has ever compared it to the product. It is read at
the start of every session and believed.

Three defects found in the two sessions before this one were each found the
same way: two independent records of one fact existed, and nobody had compared
them.

  * Driver navigation was marked Built and was completely broken on web,
    because it had only ever been run on Android. The record and the runtime
    disagreed.
  * The seal-points control was fixed twice and still cut its own text at
    ordinary size, because "no overflow was thrown" and "the words are legible"
    are different facts and only the first was ever checked.
  * `tool/migration_ledger_check.py` found 101 discrepancies between the
    migration files and the applied-migration ledger, having been written on
    the strength of a handoff that said all four rows matched. They did -- the
    four its author had looked at.

This file is the same instrument pointed at the documentation. It cannot tell
you a feature WORKS. It can tell you that CLAUDE.md refers to a migration,
file, route, table or function that does not exist -- which is the cheapest
possible sign that a claim has rotted, and it needs no test run to detect.

WHAT IT CHECKS
--------------
Every concrete, checkable name CLAUDE.md mentions:

  migration   `20260717120000` -> a file with that stamp exists
  path        `lib/features/...` -> that path exists (globs allowed)
  route       `/super-admin/targets` -> a matching route in app_router.dart
  identifier  `record_truck_load` -> the name appears SOMEWHERE in the product

The identifier rule is deliberately weak. Requiring a name to be a live
function would drown in false positives (CLAUDE.md backticks columns, enum
wire strings, package names and Dart symbols in the same style), and this check
is worthless if people learn to ignore it. "Appears nowhere in lib/, supabase/,
test/, tool/ or pubspec.yaml" is a low bar, and a name that fails it is
unambiguously a claim about something that is not there.

LIMIT, STATED
-------------
Existence is not correctness. A green run here means the documentation's nouns
are real, not that its verbs are. Nothing in this file is evidence that a
feature works -- that still needs the app driven per role, which is what §4's
Built/Partial rule already demands.
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLAUDE_MD = os.path.join(ROOT, "CLAUDE.md")
ROUTER = os.path.join(ROOT, "lib", "core", "routing", "app_router.dart")
BASELINE = os.path.join(ROOT, "tool", "claims_check_baseline.json")

# Directories a backticked path may start with. Anything else that looks like a
# path is prose, a URL, or a route.
REPO_DIRS = ("lib/", "test/", "tool/", "supabase/", "assets/", "config/",
             "docs/", "android/", "ios/", "web/", "windows/", "macos/",
             "linux/")

# Where an identifier is allowed to turn up.
SEARCH_DIRS = ("lib", "supabase", "test", "tool")
SEARCH_FILES = ("pubspec.yaml", "analysis_options.yaml", "dart_test.yaml")
SEARCH_EXT = (".dart", ".sql", ".yaml", ".yml", ".json", ".ts", ".md", ".toml")

BACKTICKED = re.compile(r"`([^`\n]+)`")
MIGRATION = re.compile(r"^20\d{12}$")
IDENTIFIER = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)+$")


# ---------------------------------------------------------------------------
# Extraction and checking. Pure, so --selftest can drive them directly.
# ---------------------------------------------------------------------------

def classify(token):
    """What kind of claim [token] is, or None if it is not checkable."""
    t = token.strip()
    # `lib/features/<name>/` is a template, not a path. Anything with angle
    # brackets is describing a shape to fill in.
    if "<" in t or ">" in t:
        return None
    if MIGRATION.match(t):
        return "migration"
    if t.startswith(REPO_DIRS):
        return "path"
    if t.startswith("/") and not t.startswith("//") and len(t) > 1:
        return "route"
    if IDENTIFIER.match(t):
        return "identifier"
    return None


def extract(text):
    """{kind: {token: first_line_number}} for every checkable claim."""
    found = {}
    for lineno, line in enumerate(text.splitlines(), 1):
        for token in BACKTICKED.findall(line):
            kind = classify(token)
            if kind is None:
                continue
            found.setdefault(kind, {}).setdefault(token.strip(), lineno)
    return found


def route_patterns(router_source):
    """Every `path:` literal declared in app_router.dart."""
    return set(re.findall(r"""path:\s*['"]([^'"]+)['"]""", router_source))


def route_matches(claimed, patterns):
    """True if [claimed] is served by any declared route.

    Compares segment by segment so a `:param` in the declaration matches
    whatever the documentation put in that position -- `/portal/driver/
    navigate/:tripId` in the router is the same route as
    `/portal/driver/navigate/abc` in the prose.
    """
    want = [s for s in claimed.strip("/").split("/") if s]
    for pattern in patterns:
        have = [s for s in pattern.strip("/").split("/") if s]
        if len(have) != len(want):
            continue
        if all(h.startswith(":") or h == w for h, w in zip(have, want)):
            return True
    # Nested go_router routes declare relative sub-paths, so a claimed route
    # may be a declared prefix plus a declared suffix.
    return any(
        claimed.strip("/").endswith(p.strip("/")) for p in patterns
        if p and not p.startswith("/") and len(p.strip("/")) > 2)


def check(claims, *, migrations, paths_exist, routes, corpus):
    """[(kind, token, line, detail)] for every claim that cannot be shown true.

    Every input is passed in rather than read, so the selftest can plant a
    world in which each fault is the only difference.
    """
    faults = []

    for token, line in sorted(claims.get("migration", {}).items()):
        if token not in migrations:
            faults.append(("migration", token, line,
                           "no file in supabase/migrations/ carries this stamp"))

    for token, line in sorted(claims.get("path", {}).items()):
        if not paths_exist(token):
            faults.append(("path", token, line, "this path does not exist"))

    for token, line in sorted(claims.get("route", {}).items()):
        if not route_matches(token, routes):
            faults.append(("route", token, line,
                           "no route in app_router.dart serves this path"))

    for token, line in sorted(claims.get("identifier", {}).items()):
        if token not in corpus:
            faults.append(("identifier", token, line,
                           "this name appears nowhere in lib/, supabase/, "
                           "test/, tool/ or pubspec.yaml"))

    return sorted(faults, key=lambda f: (f[0], f[1]))


# ---------------------------------------------------------------------------
# Reading the world
# ---------------------------------------------------------------------------

def read_migrations():
    return {f[:14] for f in os.listdir(os.path.join(ROOT, "supabase", "migrations"))
            if MIGRATION.match(f[:14])}


def path_exists(token):
    """Does [token] name something on disk? Globs and trailing ** allowed."""
    candidate = token.rstrip("/")
    if "*" in candidate:
        # `lib/core/**` means the directory, not a literal glob match.
        base = candidate.split("*")[0].rstrip("/")
        if base and os.path.exists(os.path.join(ROOT, base)):
            return True
        return bool(glob.glob(os.path.join(ROOT, candidate), recursive=True))
    return os.path.exists(os.path.join(ROOT, candidate))


def read_corpus():
    """One blob of every source file a name could legitimately appear in."""
    chunks = []
    for name in SEARCH_FILES:
        p = os.path.join(ROOT, name)
        if os.path.exists(p):
            with open(p, encoding="utf-8", errors="replace") as f:
                chunks.append(f.read())
    for d in SEARCH_DIRS:
        for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, d)):
            dirnames[:] = [x for x in dirnames
                           if x not in (".dart_tool", "build", "__pycache__")]
            for fn in filenames:
                if not fn.endswith(SEARCH_EXT):
                    continue
                # A baseline file EXCUSES a missing name, and it does so by
                # quoting that name. Letting it into the corpus means every
                # entry silently satisfies the very check it is excusing —
                # measured: adding six entries made five of them stop being
                # faults, so the baseline was suppressing them twice over and
                # would have gone on doing so after the real cause was fixed.
                # Same for this checker's own source.
                if fn.endswith("_baseline.json") or fn == "claims_check.py":
                    continue
                with open(os.path.join(dirpath, fn), encoding="utf-8",
                          errors="replace") as f:
                    chunks.append(f.read())
                chunks.append(fn)
    return "\n".join(chunks)


def read_baseline():
    if not os.path.exists(BASELINE):
        return {}
    with open(BASELINE, encoding="utf-8") as f:
        return json.load(f).get("accepted", {})


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

def selftest():
    """Plant each fault, and each way of being RIGHT that must not fire."""
    ok = True

    def case(label, expect, got):
        nonlocal ok
        passed = got == expect
        ok &= passed
        print("  %-52s %s%s" % (label, "bites" if passed else "MISSED",
                                "" if passed else "  -- got %s" % (got,)))

    world = dict(
        migrations={"20260101000000"},
        paths_exist=lambda p: p in ("lib/real.dart", "supabase/migrations"),
        routes={"/portal/trip/:tripId", "/super-admin/targets"},
        corpus="record_truck_load seal_points",
    )

    def ids(text):
        return [(f[0], f[1]) for f in check(extract(text), **world)]

    # The control. Every one of these is TRUE and must stay silent -- a check
    # that fires on correct documentation gets switched off within a week.
    case("correct documentation stays silent", [],
         ids("`20260101000000` `lib/real.dart` `/super-admin/targets` "
             "`record_truck_load`"))
    case("a :param route matches a concrete path", [],
         ids("`/portal/trip/abc123`"))
    case("prose in backticks is not a claim", [],
         ids("`Ongoing` `FOB` `RT-…` `Cr2O3` `TripStatus`"))

    # The four faults.
    case("migration stamp with no file",
         [("migration", "20269999000000")], ids("`20269999000000`"))
    case("path that does not exist",
         [("path", "lib/gone.dart")], ids("`lib/gone.dart`"))
    case("route no router serves",
         [("route", "/nowhere")], ids("`/nowhere`"))
    case("identifier that exists nowhere",
         [("identifier", "no_such_rpc")], ids("`no_such_rpc`"))

    # A wrong-arity route must not be rescued by the :param rule.
    case("route with too many segments still fails",
         [("route", "/portal/trip/abc/extra")], ids("`/portal/trip/abc/extra`"))

    # Not a planted fault — a guard on the checker's own blind spot, and one
    # that had already bitten. The baseline excuses a missing name by QUOTING
    # it, so if baseline files reach the corpus every entry satisfies the check
    # it is excusing. Measured before this was fixed: six entries were added
    # and five of them immediately stopped being faults.
    canary = "claims_check_corpus_canary_do_not_remove"
    corpus_clean = canary not in read_corpus()
    case("baseline text does not satisfy the check it excuses",
         True, corpus_clean)
    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as f:
            case("the canary is still planted", True, canary in f.read())

    print("\n%s" % ("all planted faults were caught" if ok
                    else "SELFTEST FAILED -- this checker cannot be trusted"))
    return 0 if ok else 1


# ---------------------------------------------------------------------------

def main():
    if "--selftest" in sys.argv:
        print("Planting each fault this check claims to catch:\n")
        return selftest()

    with open(CLAUDE_MD, encoding="utf-8") as f:
        claims = extract(f.read())
    with open(ROUTER, encoding="utf-8") as f:
        routes = route_patterns(f.read())

    faults = check(claims,
                   migrations=read_migrations(),
                   paths_exist=path_exists,
                   routes=routes,
                   corpus=read_corpus())

    baseline = read_baseline()
    unexpected = [f for f in faults if "%s:%s" % (f[0], f[1]) not in baseline]
    accepted = [f for f in faults if "%s:%s" % (f[0], f[1]) in baseline]

    total = sum(len(v) for v in claims.values())
    print("%d checkable claims in CLAUDE.md (%s)"
          % (total, ", ".join("%d %s" % (len(v), k)
                              for k, v in sorted(claims.items()))))

    if accepted:
        print("\n%d accepted (tool/claims_check_baseline.json)" % len(accepted))
        if "--verbose" in sys.argv:
            for kind, token, line, _ in accepted:
                print("  %-11s %-46s CLAUDE.md:%s" % (kind, token, line))

    for kind, token, line, detail in unexpected:
        print("\nFAIL  %s: %s\n      CLAUDE.md:%s -- %s"
              % (kind, token, line, detail))

    if unexpected:
        print("\n%d claims in CLAUDE.md cannot be substantiated" % len(unexpected))
        return 1

    print("\nPASS  every migration, path, route and name CLAUDE.md states "
          "exists.\n      (Existence, not correctness -- see this file's "
          "header.)")
    return 0


raise SystemExit(main())

#!/usr/bin/env python3
"""The S5-20/21 work list: which SCREEN WIDGETS the portal migration must cover.

    python tool/portal_screen_inventory.py           # the work list
    python tool/portal_screen_inventory.py --shared  # only widgets serving >1 route

WHY THIS IS NOT THE SAME AS COUNTING ROUTES
-------------------------------------------
S5-20/21 are scoped per org — "Mine's 13 screens and Transporter's 13",
"Buyer's 7". Executed that way the stage would migrate the same file more than
once: `/portal/mine/employees`, `/portal/buyer/employees` and
`/portal/transporter/employees` are three destinations and ONE
`CompanyEmployeesScreen`. Measured 2026-08-15, 87 portal routes resolve to 48
distinct widget classes, and 12 of those classes serve more than one route.

So the migration's unit of work is the widget, not the org, and its
denominator is the number this prints — not the sum of three per-org counts.

The companion measurement is `test/features/portal/portal_screen_inventory_test.dart`,
which counts what each ROLE can reach (the nav rail, and the same tree the
route guard reads). Both are needed: this one says what there is to change,
that one says who sees it.

METHOD, AND ITS LIMITS
----------------------
Regex over `lib/core/routing/app_router.dart`: for each `GoRoute(`, take its
`path:` and the first `=> Widget(` in the same block. That is a parse of source
text, not of an AST, so a route built through a helper, a conditional builder,
or a widget named in a variable will show as `?`. Those are printed explicitly
rather than dropped — an unresolved route is a gap in the work list, and a work
list that quietly omits rows is how a migration reports done while screens are
untouched.
"""
import os
import re
import sys
from collections import Counter, defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROUTER = os.path.join(REPO, "lib", "core", "routing", "app_router.dart")

# Routes outside /portal/* that every org's rail still links to.
SHARED_NON_PORTAL = ("/account-security", "/appearance", "/communications")


def parse():
    src = open(ROUTER, encoding="utf-8").read()
    pairs = []
    for block in re.split(r"GoRoute\(", src)[1:]:
        m = re.search(r"path:\s*'([^']+)'", block)
        if not m:
            continue
        w = re.search(r"=>\s*(?:const\s+)?([A-Z]\w+)\s*\(", block)
        pairs.append((m.group(1), w.group(1) if w else None))
    return [(p, w) for p, w in pairs
            if p.startswith("/portal") or p in SHARED_NON_PORTAL]


def find_source(widget):
    """The file declaring `class <widget>`, or None."""
    for dirpath, _, files in os.walk(os.path.join(REPO, "lib")):
        for f in files:
            if not f.endswith(".dart"):
                continue
            p = os.path.join(dirpath, f)
            try:
                if re.search(r"^class %s\b" % re.escape(widget),
                             open(p, encoding="utf-8").read(), re.M):
                    return os.path.relpath(p, REPO).replace(os.sep, "/")
            except OSError:
                continue
    return None


# What "migrated" looks like in source, per docs/design-reference.md §4/§5.
# Each probe is a (name, regex, is_good) triple. `is_good` False marks an
# anti-pattern: the hand-rolled thing the shared component replaces.
PROBES = [
    ("header",  re.compile(r"\bMlPageHeader\b|\bMlSectionTitle\b|\bMlSectionHead\b"), True),
    ("stat",    re.compile(r"\bMlStatCard\b|\bSaStatTile\b|\bMlStat\b"), True),
    ("table",   re.compile(r"\bMlDataTable\b"), True),
    ("card",    re.compile(r"\bMlCard\b|\bMlPanel\b"), True),
    ("empty",   re.compile(r"\bMlEmptyState\b"), True),
    ("failure", re.compile(r"\bMlLoadFailure\b"), True),
    ("badge",   re.compile(r"\bMlStatusBadge\b|\bMlPill\b"), True),
    ("cap",     re.compile(r"\bMlCap\b|\bMlMicroLabel\b"), True),
    # anti-patterns
    ("RAW-HEX", re.compile(r"Color\(0x"), False),
    ("MATERIAL-COLORS", re.compile(r"\bColors\.(?!transparent\b)"), False),
    ("RAW-TABLE", re.compile(r"\bDataTable\(|\bDataColumn\(|\bTable\("), False),
]


def status(argv):
    routes = parse()
    widgets = sorted({w for _, w in routes if w})
    print("PORTAL MIGRATION STATUS — %d widget classes\n" % len(widgets))
    print("  legend: components present, then ANTI-PATTERNS in caps\n")
    rows = []
    for w in widgets:
        src = find_source(w)
        if src is None:
            rows.append((w, None, [], []))
            continue
        # Comment lines are prose ABOUT the code, not the code -- the same
        # exemption release_guards.dart applies. Without it this over-reported:
        # FleetManagementScreen came back dirty after being cleaned, because the
        # comment explaining what the old `Colors.red` had been was itself
        # counted as a `Colors.red`.
        raw = open(os.path.join(REPO, src), encoding="utf-8").read()
        text = "\n".join(l for l in raw.split("\n")
                         if not re.match(r"\s*(//|///|\*|/\*)", l))
        good = [n for n, rx, ok in PROBES if ok and rx.search(raw)]
        bad = [n for n, rx, ok in PROBES if not ok and rx.search(text)]
        rows.append((w, src, good, bad))

    rows.sort(key=lambda r: (-len(r[3]), len(r[2]), r[0]))
    for w, src, good, bad in rows:
        if src is None:
            print("  %-38s  (source not found)" % w)
            continue
        print("  %-38s  %-2d ok  %s%s"
              % (w, len(good),
                 " ".join(bad) if bad else "-",
                 "   [" + ",".join(good) + "]" if good else "   [none]"))
    clean = [r for r in rows if r[1] and not r[3]]
    dirty = [r for r in rows if r[1] and r[3]]
    none = [r for r in rows if r[1] and not r[2]]
    print("\n  no anti-patterns      : %d / %d" % (len(clean), len(rows)))
    print("  using no shared parts : %d" % len(none))
    print("  worst offenders       : %s"
          % ", ".join(r[0] for r in dirty[:5]))
    return 0


def main(argv):
    if "--status" in argv:
        return status(argv)
    routes = parse()
    by_widget = defaultdict(list)
    unresolved = []
    for path, widget in routes:
        if widget is None:
            unresolved.append(path)
        else:
            by_widget[widget].append(path)

    counts = Counter({w: len(p) for w, p in by_widget.items()})

    if "--shared" in argv:
        print("Widget classes serving more than one route "
              "(migrate once, not once per org):\n")
        for w, n in counts.most_common():
            if n > 1:
                print("  %2d  %s" % (n, w))
                for p in sorted(by_widget[w]):
                    print("        %s" % p)
        return 0

    print("PORTAL SCREEN MIGRATION WORK LIST (S5-20/21)\n")
    print("  portal routes parsed        : %d" % len(routes))
    print("  distinct widget classes     : %d   <- the denominator" % len(by_widget))
    print("  classes serving >1 route    : %d"
          % sum(1 for n in counts.values() if n > 1))
    print("  routes with no widget found : %d" % len(unresolved))
    print()
    for w in sorted(by_widget):
        paths = sorted(by_widget[w])
        marker = "  (x%d)" % len(paths) if len(paths) > 1 else ""
        print("  %s%s" % (w, marker))
        for p in paths:
            print("      %s" % p)
    if unresolved:
        print("\n  UNRESOLVED — builder not a direct `=> Widget(`; check by hand:")
        for p in sorted(unresolved):
            print("      %s" % p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

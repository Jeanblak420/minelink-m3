#!/usr/bin/env python3
"""A `drop function if exists` must name a signature something actually creates.

    python tool/drop_signature_check.py
    python tool/drop_signature_check.py --selftest

WHY THIS EXISTS
---------------
`drop function if exists public.f(...)` resolves by NAME **and argument types**.
Get the arguments wrong and it matches nothing, drops nothing, and reports
success. There is no warning, no notice, and no non-zero status — the migration
applies cleanly and the function is still there.

Measured 2026-08-18. `20260712175000` was written to remove four seat-counting
functions that production had dropped and the files had not, and it contained:

    drop function if exists public.sync_organization_seats() cascade;

The real signature is `sync_organization_seats(uuid, integer)`. The migration
applied, the replay went green, and the function was still present — found only
by fingerprinting the rebuilt schema against production and noticing the count
was one higher than it should have been.

That is the whole hazard: a drop that cannot bite looks exactly like a drop
that did.

WHAT IT CHECKS
--------------
Every `drop function [if exists] public.name(args)` in `supabase/migrations/`
is matched against the `create [or replace] function public.name(args)`
statements in the same directory, comparing the argument TYPE list with
parameter names, `default` clauses and whitespace normalised away.

A drop whose name is created somewhere but never with those argument types is
reported: it is either a typo or a signature that has since changed, and either
way it is a statement that will never do anything.

WHAT IT DELIBERATELY ALLOWS
---------------------------
  * `drop function ... ()` for a name no file creates at all. Those are
    defensive drops of objects that reached production out of band -- the very
    debt this repo is repairing -- and demanding a matching create would make
    the check fire on the repairs.
  * Every argument-less drop of a name whose only creates are argument-less.

LIMIT, STATED
-------------
Source-level type matching, not a resolver: `int` and `integer` are folded
together, but a domain, an alias or a `%TYPE` reference is compared as written.
It catches the mistake that actually happened -- a plainly different arity --
rather than proving type equivalence.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS = os.path.join(ROOT, "supabase", "migrations")

CREATE = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?([a-z0-9_]+)\s*\(",
    re.I)
DROP = re.compile(
    r"drop\s+function\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)\s*\(",
    re.I)

ALIAS = {
    "int": "integer", "int4": "integer", "int8": "bigint", "int2": "smallint",
    "bool": "boolean", "float8": "double precision", "float4": "real",
    "varchar": "character varying", "timestamptz": "timestamp with time zone",
    "timetz": "time with time zone", "decimal": "numeric",
}


def _balanced(src, open_paren):
    """Text inside the parentheses starting at [open_paren]."""
    depth = 0
    for i in range(open_paren, len(src)):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return src[open_paren + 1:i]
    return ""


def normalise_args(raw):
    """A comparable list of argument TYPES from a parameter list."""
    raw = re.sub(r"--[^\n]*", " ", raw)
    raw = re.sub(r"\s+", " ", raw).strip()
    if not raw:
        return ()
    # Split on commas that are not inside parentheses (numeric(10,2)).
    parts, depth, cur = [], 0, ""
    for ch in raw:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)

    out = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        p = re.split(r"\s+default\s+|\s*:?=\s*", p, flags=re.I)[0].strip()
        p = re.sub(r"^(in|out|inout|variadic)\s+", "", p, flags=re.I).strip()
        # A leading parameter NAME is present when two+ bare words remain and
        # the first is not itself a type word.
        tokens = p.split(" ")
        if len(tokens) > 1 and tokens[0].lower() not in (
                "character", "double", "timestamp", "time", "bit"):
            candidate = " ".join(tokens[1:])
            if candidate:
                p = candidate
        p = p.lower().replace("public.", "").strip()
        p = re.sub(r"\s+", " ", p)
        p = ALIAS.get(p, p)
        out.append(p)
    return tuple(out)


def scan(sources):
    """[(file, name, dropped_args, [known_signatures])] for every dead drop."""
    created = {}
    for path, src in sorted(sources.items()):
        for m in CREATE.finditer(src):
            args = normalise_args(_balanced(src, m.end() - 1))
            created.setdefault(m.group(1).lower(), set()).add(args)

    dead = []
    for path, src in sorted(sources.items()):
        for m in DROP.finditer(src):
            name = m.group(1).lower()
            args = normalise_args(_balanced(src, m.end() - 1))
            known = created.get(name)
            if known is None:
                continue          # defensive drop of an out-of-band object
            if args in known:
                continue
            if not args and known == {()}:
                continue
            dead.append((path, name, args, sorted(known)))
    return dead


def read_migrations():
    out = {}
    for fn in sorted(os.listdir(MIGRATIONS)):
        if not fn.endswith(".sql"):
            continue
        with open(os.path.join(MIGRATIONS, fn), encoding="utf-8",
                  errors="replace") as f:
            out["supabase/migrations/" + fn] = f.read()
    return out


def selftest():
    ok = True

    def case(label, sources, expect):
        nonlocal ok
        got = len(scan(sources))
        passed = got == expect
        ok &= passed
        print("  %-56s %s%s" % (label, "bites" if passed else "MISSED",
                                "" if passed else "  -- found %d, wanted %d"
                                % (got, expect)))

    made = "create or replace function public.f(p_a uuid, p_b integer) returns void as $$ $$;"
    # THE REAL CASE: 20260712175000 dropped sync_organization_seats() when the
    # function takes (uuid, integer). Silent, and the function survived.
    case("drop with no args when the function takes two",
         {"a.sql": made, "b.sql": "drop function if exists public.f() cascade;"}, 1)
    case("drop with the right args", {"a.sql": made,
         "b.sql": "drop function if exists public.f(uuid, integer) cascade;"}, 0)
    case("parameter names and defaults do not matter", {"a.sql": made,
         "b.sql": "drop function if exists public.f(p_x uuid, p_y integer);"}, 0)
    case("int and integer are the same type", {"a.sql": made,
         "b.sql": "drop function if exists public.f(uuid, int);"}, 0)
    case("wrong arity the other way", {"a.sql": made,
         "b.sql": "drop function if exists public.f(uuid, integer, text);"}, 1)
    # Must stay silent, or the check fires on this repo's own repairs.
    case("drop of a name no file creates is allowed",
         {"b.sql": "drop function if exists public.never_created() cascade;"}, 0)
    case("argument-less function, argument-less drop",
         {"a.sql": "create function public.g() returns void as $$ $$;",
          "b.sql": "drop function if exists public.g();"}, 0)
    case("a type containing a comma is one argument",
         {"a.sql": "create function public.h(p numeric(10,2)) returns void as $$ $$;",
          "b.sql": "drop function if exists public.h(numeric(10,2));"}, 0)

    print("\n%s" % ("all planted faults were caught" if ok
                    else "SELFTEST FAILED -- this checker cannot be trusted"))
    return 0 if ok else 1


def main():
    if "--selftest" in sys.argv:
        print("Planting each shape this check claims to catch:\n")
        return selftest()

    dead = scan(read_migrations())
    if not dead:
        print("PASS  every `drop function` names a signature the migrations create")
        return 0

    print("%d `drop function` statement(s) can never match anything.\n"
          "They apply cleanly, report success, and leave the function in place.\n"
          % len(dead))
    for path, name, args, known in dead:
        print("  FAIL  %s\n        drops   %s(%s)\n        created %s"
              % (path, name, ", ".join(args),
                 " | ".join("%s(%s)" % (name, ", ".join(k)) for k in known)))
    return 1


raise SystemExit(main())

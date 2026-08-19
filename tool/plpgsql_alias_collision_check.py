#!/usr/bin/env python3
"""A PL/pgSQL record variable must not share its name with a table alias.

    python tool/plpgsql_alias_collision_check.py
    python tool/plpgsql_alias_collision_check.py --selftest

WHY THIS EXISTS
---------------
On 2026-08-15 `create_company_token_request` was found to have never succeeded
once, for any caller, since it was written. It declared a record variable `c`
and then loaded the company with:

    select c.id, c.company_name, ... into c from public.companies c where ...

PL/pgSQL resolves `c.id` in the select list against the declared **variable**,
not the table alias of the same name. The variable is unassigned at that point,
so every call raised:

    55000  record "c" is not assigned yet

The raise lands on the third statement, before any argument validation, so no
argument combination avoids it. `token_requests` held 0 rows as a direct
result: the seat-expansion / token-renewal / new-token feature is fully built
and wired -- `company_token_requests_panel.dart` offers all three flows, each
ending in a success snackbar -- and had never written a single row.

This is the same family as the notification-vocabulary defect
(tool/notification_vocabulary_check.py): server-side SQL that is reachable,
shipped, and never executed, so nothing ever reported it. The difference is
that this one fails LOUDLY at runtime and still went unnoticed, because the
only path to it is a button nobody had pressed on live data.

WHAT IT CHECKS
--------------
Every `create [or replace] function` body in `supabase/migrations/*.sql`, for a
name declared as `record` that is later used as a table alias. Both halves must
be present for it to fire, so a variable named `c` is fine on its own and an
alias `c` is fine on its own -- it is the collision that breaks.

LIMIT, STATED
-------------
This reads the migration FILES, which is the source of truth per
MIGRATION_HYGIENE.txt -- not the live database. The live schema was audited
separately with the equivalent query, which matched exactly one function:

    select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
      and p.prosrc ~ 'into\\s+(\\w+)\\s+from\\s+public\\.\\w+\\s+\\1\\M';

Re-run that against the database if you want the other side.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS = os.path.join(ROOT, 'supabase', 'migrations')

# `create function public.foo(...) ... as $tag$ <body> $tag$`
FUNC_RE = re.compile(
    r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)'
    r'[\s\S]*?as\s+(\$\w*\$)([\s\S]*?)\2',
    re.IGNORECASE)

DECLARED_RECORD_RE = re.compile(r'\b(\w+)\s+record\s*;', re.IGNORECASE)


def alias_uses(body, name):
    """Line numbers where `name` is used as a table alias in `body`."""
    pat = re.compile(r'\b(?:from|join)\s+(?:public\.)?\w+\s+(?:as\s+)?'
                     + re.escape(name) + r'\b', re.IGNORECASE)
    return [body[:m.start()].count('\n') + 1 for m in pat.finditer(body)]


def scan_text(text):
    """Yield (function, varname, alias_line) for every collision in one file."""
    for m in FUNC_RE.finditer(text):
        fname, body = m.group(1), m.group(3)
        declared = {d.lower() for d in DECLARED_RECORD_RE.findall(body)}
        for var in sorted(declared):
            for line in alias_uses(body, var):
                yield fname, var, line


def scan_files():
    """Check the EFFECTIVE definition of each function, not every historical one.

    Migrations apply in timestamp order and `create or replace` overwrites, so
    only the last definition of a given function is live. Flagging the earlier
    body would report a defect that has already been fixed -- exactly the kind
    of false finding that makes a tool get ignored. 20260516180000 still holds
    the broken `create_company_token_request`, and must, because a migration
    already applied is history and is not edited in place; 20260815110000
    replaces it.
    """
    files = sorted(glob.glob(os.path.join(MIGRATIONS, '*.sql')))
    latest = {}  # function name -> (file, body)
    for path in files:
        with open(path, encoding='utf-8', errors='replace') as fh:
            text = fh.read()
        for m in FUNC_RE.finditer(text):
            latest[m.group(1)] = (os.path.basename(path), m.group(3))

    findings = []
    for fname, (path, body) in sorted(latest.items()):
        declared = {d.lower() for d in DECLARED_RECORD_RE.findall(body)}
        for var in sorted(declared):
            for line in alias_uses(body, var):
                findings.append((path, fname, var, line))
    return files, latest, findings


BAD = """
create or replace function public.planted_collision(p_id uuid)
returns void language plpgsql as $function$
declare
  c record;
begin
  select c.id into c from public.companies c where c.id = p_id;
end;
$function$;
"""

GOOD = """
create or replace function public.planted_ok(p_id uuid)
returns void language plpgsql as $function$
declare
  c record;
begin
  select co.id into c from public.companies co where co.id = p_id;
end;
$function$;
"""


def selftest():
    """A check that cannot fail is not a check. Prove it bites, and that it
    does not fire on the corrected form."""
    bad = list(scan_text(BAD))
    good = list(scan_text(GOOD))
    ok = len(bad) == 1 and len(good) == 0
    print('selftest: planted collision -> %d finding(s) (want 1)' % len(bad))
    print('selftest: corrected alias   -> %d finding(s) (want 0)' % len(good))
    print('%s  plpgsql-alias-collision' % ('BITES' if ok else 'BROKEN'))
    return 0 if ok else 1


def main():
    if '--selftest' in sys.argv:
        return selftest()

    files, latest, findings = scan_files()
    print('scanned     : %d migration files in supabase/migrations' % len(files))
    print('functions   : %d, each judged on its latest definition' % len(latest))

    if findings:
        print('FAIL  a record variable shares its name with a table alias.')
        print('      In PL/pgSQL the variable wins, so the query reads an')
        print('      unassigned record and raises 55000 at runtime, every call:')
        for path, fname, var, line in findings:
            print('        %s  %s()  variable "%s" aliased at body line %d'
                  % (path, fname, var, line))
        return 1

    print('PASS  no record variable is shadowed by a table alias.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

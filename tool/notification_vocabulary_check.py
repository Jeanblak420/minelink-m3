#!/usr/bin/env python3
"""Every notification type a migration raises must be in the CHECK constraint.

    python tool/notification_vocabulary_check.py

WHY THIS EXISTS
---------------
On 2026-08-15 three notification types raised by shipped RPCs were **not** in
`notifications_type_check`:

    order_assigned    link_and_dispatch_request -> the transporter
    order_dispatched  link_and_dispatch_request -> the buyer
    stockpile_ready   stockpile_add_tons        -> the +30t collect alert

Every notify call site wraps itself in `exception when others then null`, so a
`23514` violation produced no error anywhere. `link_and_dispatch_request` --
the action that creates every trip -- SUCCEEDED and delivered nothing, and
because the handler wraps the tail of the function it took the mine's *valid*
notification and the capped order stockpile down with it. It went unnoticed
from 2026-07-15 to 2026-08-15 because no dispatch happened to run in between.

The UI cannot make this mistake: `gate_checks.check_type`,
`security_incidents.severity` and `weighbridge_records.direction` are all
CHECK-constrained too, and the Dart offers them as fixed `DropdownMenuEntry`
values. The exposure is specific to **server-side** notify calls, where the
type is a bare string literal inside a function body and nothing checks it.

So this compares the two sides mechanically:

  * the vocabulary, parsed from the constraint in the migration that owns it;
  * the type argument of every `notify_company_role` /
    `create_notification_internal` call in `supabase/migrations/*.sql`.

A type in the calls but not the vocabulary is a notification that will never
arrive and will never complain. That is the whole failure mode.

LIMIT, STATED
-------------
This reads the migration FILES, which is the source of truth per
MIGRATION_HYGIENE.txt -- not the live database. A type added straight to the
database without a mirrored file is invisible here, and is already a hygiene
violation in its own right.
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS = os.path.join(REPO, 'supabase', 'migrations')
CONSTRAINT_MARKER = 'add constraint notifications_type_check'


def vocabulary_file():
    """The LATEST migration that defines `notifications_type_check`.

    Was a hard-coded filename until 2026-08-17. That was correct while exactly
    one migration had ever defined the constraint, and became wrong the moment
    a second one did: adding a type means writing a NEW migration (one file per
    applied migration — MIGRATION_HYGIENE), and a tool pinned to the old file
    would have read the old vocabulary and reported the new type as dead. An
    audit tool that invents findings is worse than no tool; so is one that
    reports a stale PASS.

    Migration filenames are timestamp-prefixed, so lexical order is apply
    order.
    """
    owners = sorted(
        f for f in os.listdir(MIGRATIONS)
        if f.endswith('.sql')
        and CONSTRAINT_MARKER in open(
            os.path.join(MIGRATIONS, f), encoding='utf-8').read()
    )
    if not owners:
        print('FAIL  no migration defines notifications_type_check')
        sys.exit(2)
    return owners[-1]

# Where the type argument sits, by position, in each notifier:
#   notify_company_role(company, roles[], title, message, TYPE, org_type, ...)
#   create_notification_internal(user, company, employee, title, message, TYPE, ...)
TYPE_ARG_INDEX = {'notify_company_role': 4, 'create_notification_internal': 5}


def vocabulary():
    """The allowed types, read from the constraint that defines them."""
    path = os.path.join(MIGRATIONS, vocabulary_file())
    src = open(path, encoding='utf-8').read()
    body = src[src.index(CONSTRAINT_MARKER):]
    body = body[:body.index(']))')]
    body = re.sub(r'--[^\n]*', '', body)
    return set(re.findall(r"'([a-zA-Z_]+)'", body))


def split_args(text):
    """Top-level comma split, ignoring commas inside nested parens or quotes."""
    out, depth, cur, in_quote = [], 0, [], False
    i = 0
    while i < len(text):
        c = text[i]
        if in_quote:
            if c == "'":
                if i + 1 < len(text) and text[i + 1] == "'":
                    cur.append("''")
                    i += 2
                    continue
                in_quote = False
            cur.append(c)
        elif c == "'":
            in_quote = True
            cur.append(c)
        elif c in '([':
            depth += 1
            cur.append(c)
        elif c in ')]':
            depth -= 1
            cur.append(c)
        elif c == ',' and depth == 0:
            out.append(''.join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    if cur:
        out.append(''.join(cur).strip())
    return out


def raised():
    """(type, file) for every notify call in any migration.

    Positional, NOT adjacency. The first version of this matched the literal
    sitting immediately before an org-type literal, which is correct for
    `notify_company_role` and wrong for `create_notification_internal`, whose
    adjacent pair is `role_scope, org_type`. It reported `supervisorForeman` --
    a ROLE -- as a dead notification type, three times. An audit tool that
    invents findings is worse than no tool, because the next person stops
    reading its output.
    """
    out = set()
    opener = re.compile(r'(notify_company_role|create_notification_internal)\s*\(')
    for f in sorted(os.listdir(MIGRATIONS)):
        if not f.endswith('.sql'):
            continue
        src = open(os.path.join(MIGRATIONS, f), encoding='utf-8',
                   errors='replace').read()
        src = re.sub(r'--[^\n]*', '', src)
        for m in opener.finditer(src):
            open_i = m.end() - 1
            depth = 0
            for i in range(open_i, len(src)):
                if src[i] == '(':
                    depth += 1
                elif src[i] == ')':
                    depth -= 1
                    if depth == 0:
                        args = split_args(src[open_i + 1:i])
                        idx = TYPE_ARG_INDEX[m.group(1)]
                        if idx < len(args):
                            lit = re.fullmatch(r"'([a-zA-Z_]+)'", args[idx])
                            if lit:
                                out.add((lit.group(1), f))
                        break
    return out


def main():
    vocab = vocabulary()
    calls = raised()
    print('vocabulary  : %d types (%s)' % (len(vocab), vocabulary_file()))
    print('notify calls: %d distinct type/file pairs in supabase/migrations\n'
          % len(calls))

    dead = sorted((t, f) for t, f in calls if t not in vocab)
    if dead:
        print('FAIL  these types are raised but NOT in the vocabulary.')
        print('      Each one is a notification that silently never arrives:')
        for t, f in dead:
            print('        %-20s raised in %s' % (t, f))
        return 1

    print('PASS  every type raised by a migration is in the vocabulary.')
    print('      types raised: %s'
          % ', '.join(sorted({t for t, _ in calls})))
    unused = sorted(vocab - {t for t, _ in calls})
    if unused:
        # Not a failure: many are raised from Dart or from edge functions.
        print('      (%d vocabulary entries are not raised by any migration)'
              % len(unused))
    return 0


if __name__ == '__main__':
    sys.exit(main())

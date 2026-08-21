"""One clock: Africa/Johannesburg. Holds the line drawn on 2026-08-17.

Jean's ruling was that every day this product decides is a South African one.
Three shapes can quietly undo that, and none of them fails a test — they are all
correct Dart and correct SQL, they just ask the wrong authority what day it is:

  1. `.toLocal()`          — the *device's* opinion. A laptop left on UTC puts a
                             22:30 SAST load on the previous day. Use
                             `MlTime.sast` / `MlTime.sastOrNull`.
  2. `DateTime.now().toIso8601String()` — a **naive** ISO string with no offset,
                             which Postgres reads in the session zone. On a SAST
                             device every such stamp landed two hours early. Use
                             `.toUtc().toIso8601String()` for an instant, or
                             `MlTime.serverParam` for a wall clock.
  3. `current_date` in SQL  — a UTC calendar day, so it flips at 02:00 SAST, in
                             the middle of a night shift. Use `public.ml_today()`.

Timestamps that merely *stamp* a row, or measure elapsed time, are not day
decisions: `DateTime.now()` on its own, TTLs, timeouts, animation and "x minutes
ago" are all fine and are not checked.

Run:  python tool/one_clock_check.py [--selftest]
"""
import os
import re
import sys
import tempfile

# `.toLocal()`, anywhere but inside a comment. The leading `\.` is the whole
# guard against a longer identifier — an earlier draft tried a lookbehind and
# thereby made the ordinary `d.toLocal()` unmatchable, which the self-test
# caught and is why the self-test exists.
TO_LOCAL = re.compile(r"\.toLocal\(\)")
# A naive write stamp: `.now()` straight to ISO with no `.toUtc()` between.
NAIVE_STAMP = re.compile(r"DateTime\.now\(\)\s*\.\s*toIso8601String\(\)")
# The same stamp WITH A LOCAL VARIABLE IN BETWEEN.
#
# `final timestamp = DateTime.now();` ... `'timestamp': timestamp.toIso8601String()`
# is the identical fault, and NAIVE_STAMP cannot see it because the two halves
# are lines apart. Found 2026-08-21 in `chat_screen.dart`, on BOTH of its insert
# paths: every chat message this app has ever sent was written as a naive
# string, which Postgres reads in the session zone -- stored two hours late and
# read back two hours late, on the one surface where when a thing was said is
# most of what it means.
#
# Scoped to a local binding, the same file, and a 60-line window, which is what
# keeps it from matching an unrelated field of the same name further down.
NAIVE_STAMP_VIA_LOCAL = re.compile(
    r"(?:final|var|late final)\s+(\w+)\s*=\s*DateTime\.now\(\)\s*;")
# `current_date` as a word, in SQL.
CURRENT_DATE = re.compile(r"\bcurrent_date\b", re.I)

# The one file allowed to name the offset and cross between the two worlds.
DART_EXEMPT = {os.path.join("lib", "core", "time", "ml_time.dart")}

# Migrations written before the ruling are history and are left as they are —
# the live definitions were rewritten by 20260817250000 / 20260817260000. Only
# new SQL has to be born on the right clock.
SQL_FLOOR = "20260817260000"

# A migration whose job is to *remove* `current_date` has to name it. Such a
# file declares itself with this marker and a reason, so the exemption is
# stated in the file rather than hidden in a floor bump here. Reported, not
# silent — an exemption nobody can see is how a rule rots.
EXEMPT_MARKER = "one-clock-exempt:"


def _strip_comments(src):
    """Blank out // line comments and /* */ blocks, preserving offsets."""
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        two = src[i:i + 2]
        if two == "//":
            j = src.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif two == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        elif src[i] in "'\"":
            q = src[i]
            j = i + 1
            while j < n and src[j] != q:
                j += 2 if src[j] == "\\" else 1
            i = min(j + 1, n)
        else:
            i += 1
    return "".join(out)


def _strip_sql_comments(src):
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        if src[i:i + 2] == "--":
            j = src.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif src[i:i + 2] == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        else:
            i += 1
    return "".join(out)


def _line_of(src, idx):
    return src.count("\n", 0, idx) + 1


def scan_dart(root):
    findings = []
    lib = os.path.join(root, "lib")
    for base, _dirs, files in os.walk(lib):
        for fn in files:
            if not fn.endswith(".dart"):
                continue
            path = os.path.join(base, fn)
            rel = os.path.relpath(path, root)
            if rel.replace("/", os.sep) in DART_EXEMPT:
                continue
            with open(path, encoding="utf-8", newline="") as fh:
                raw = fh.read()
            code = _strip_comments(raw)
            for m in TO_LOCAL.finditer(code):
                findings.append((rel, _line_of(raw, m.start()), "toLocal",
                                 "use MlTime.sast / MlTime.sastOrNull"))
            for m in NAIVE_STAMP.finditer(code):
                findings.append((rel, _line_of(raw, m.start()), "naive-stamp",
                                 "no offset: add .toUtc(), or MlTime.serverParam"))
            for m in NAIVE_STAMP_VIA_LOCAL.finditer(code):
                name = m.group(1)
                window = "\n".join(code[m.end():].split("\n")[:60])
                if re.search(r"\b%s\s*\.\s*toIso8601String\(\)" % re.escape(name),
                             window):
                    findings.append(
                        (rel, _line_of(raw, m.start()), "naive-stamp",
                         "`%s` is device-local and is written as ISO with no "
                         "offset: use MlTime.instant()" % name))
    return findings


def scan_sql(root, exemptions=None):
    findings = []
    exemptions = [] if exemptions is None else exemptions
    migrations = os.path.join(root, "supabase", "migrations")
    if not os.path.isdir(migrations):
        return findings
    for fn in sorted(os.listdir(migrations)):
        if not fn.endswith(".sql"):
            continue
        stamp = fn.split("_", 1)[0]
        if not (stamp.isdigit() and stamp >= SQL_FLOOR):
            continue
        path = os.path.join(migrations, fn)
        with open(path, encoding="utf-8", newline="") as fh:
            raw = fh.read()
        if EXEMPT_MARKER in raw:
            reason = raw.split(EXEMPT_MARKER, 1)[1].splitlines()[0].strip()
            if reason:
                exemptions.append((os.path.relpath(path, root), reason))
                continue
        code = _strip_sql_comments(raw)
        for m in CURRENT_DATE.finditer(code):
            findings.append((os.path.relpath(path, root), _line_of(raw, m.start()),
                             "current_date", "use public.ml_today()"))
    return findings


def scan(root, exemptions=None):
    return scan_dart(root) + scan_sql(root, exemptions)


SELFTEST_DART = [
    ("a display site on the device clock",
     "class A { String f(DateTime d) => fmt.format(d.toLocal()); }", True),
    ("a nullable one",
     "class A { DateTime? f(DateTime? d) => d?.toLocal(); }", True),
    ("a naive write stamp",
     "class A { var m = {'at': DateTime.now().toIso8601String()}; }", True),
    ("the same stamp as a real instant",
     "class A { var m = {'at': DateTime.now().toUtc().toIso8601String()}; }", False),
    ("a naive stamp with a local variable in between",
     "class A { void f() {\n  final t = DateTime.now();\n"
     "  db.insert({'at': t.toIso8601String()});\n} }", True),
    ("the same, corrected",
     "class A { void f() {\n  final t = MlTime.instant();\n"
     "  db.insert({'at': t.toIso8601String()});\n} }", False),
    ("a local DateTime.now() used only for elapsed time",
     "class A { void f() {\n  final t = DateTime.now();\n"
     "  if (t.difference(x) > gap) ping();\n} }", False),
    ("a local too far away to be the same statement",
     "class A { void f() {\n  final t = DateTime.now();\n" + ("  x();\n" * 70) +
     "  db.insert({'at': t.toIso8601String()});\n} }", False),
    ("elapsed time, which is not a day decision",
     "class A { var d = DateTime.now().difference(x); }", False),
    ("the word inside a comment",
     "// this used to be .toLocal(), which was the device's opinion\n"
     "class A {}", False),
    ("the word inside a doc comment",
     "/// was `DateTime.now().toIso8601String()` before the ruling\nclass A {}", False),
    ("the corrected call",
     "class A { String f(DateTime d) => fmt.format(MlTime.sast(d)); }", False),
]

SELFTEST_SQL = [
    ("a new migration reaching for the UTC calendar",
     "select * from t where d < current_date;", True),
    ("the same thing on the pit clock",
     "select * from t where d < public.ml_today();", False),
    ("a migration that exists to remove current_date",
     "-- one-clock-exempt: this migration rewrites current_date away\n"
     "select regexp_replace(src, 'current_date', 'ml_today()');", False),
    ("an exemption claimed without naming a reason",
     "-- one-clock-exempt:\nselect current_date;", True),
    ("current_date named in a comment explaining why it is gone",
     "-- this replaced current_date, which flips at 02:00 SAST\n"
     "select public.ml_today();", False),
]


def selftest():
    ok = True

    def report(name, bit, should):
        nonlocal ok
        if bit == should:
            print("SELFTEST  %-46s %s" % (name, "BITES" if bit else "clean (correct)"))
        else:
            ok = False
            print("SELFTEST  %-46s DID NOT BEHAVE: expected %s, got %s"
                  % (name, "a finding" if should else "clean",
                     "a finding" if bit else "clean"))

    for name, src, should in SELFTEST_DART:
        with tempfile.TemporaryDirectory() as td:
            os.makedirs(os.path.join(td, "lib"))
            with open(os.path.join(td, "lib", "s.dart"), "w", encoding="utf-8") as fh:
                fh.write(src)
            report(name, bool(scan_dart(td)), should)

    for name, src, should in SELFTEST_SQL:
        with tempfile.TemporaryDirectory() as td:
            mig = os.path.join(td, "supabase", "migrations")
            os.makedirs(mig)
            with open(os.path.join(mig, "29990101000000_t.sql"), "w", encoding="utf-8") as fh:
                fh.write(src)
            report(name, bool(scan_sql(td)), should)

    # The floor itself has to work, or every historical migration would fail.
    with tempfile.TemporaryDirectory() as td:
        mig = os.path.join(td, "supabase", "migrations")
        os.makedirs(mig)
        with open(os.path.join(mig, "20260101000000_old.sql"), "w", encoding="utf-8") as fh:
            fh.write("select current_date;")
        report("a migration predating the ruling", bool(scan_sql(td)), False)

    print("\nall checks bite" if ok else "\nSELFTEST FAILED")
    return 0 if ok else 1


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if "--selftest" in sys.argv:
        return selftest()
    exemptions = []
    findings = scan(root, exemptions)
    for rel, reason in exemptions:
        print("EXEMPT     %s  (%s)" % (rel, reason))
    for rel, line, kind, hint in findings:
        print("ONE-CLOCK  %s:%d  %-13s %s" % (rel, line, kind, hint))
    print("\none-clock: %d site(s) off Africa/Johannesburg" % len(findings))
    if findings:
        print(
            "Each of these asks the device, or UTC, what day it is. See "
            "CLAUDE.md §7.1 and lib/core/time/ml_time.dart."
        )
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

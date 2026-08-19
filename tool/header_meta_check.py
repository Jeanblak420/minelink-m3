#!/usr/bin/env python3
"""S5-22 — every header call site passes a meta line.

    python tool/header_meta_check.py            # report; exit 1 if any site lacks meta
    python tool/header_meta_check.py --selftest # prove the check bites

`MlPageHeader` and `MlSectionTitle` both carry a `meta:` slot. Before
2026-08-15 **not one of the 72 call sites passed anything into it**, which is
the state S5-22 exists to end. A grep cannot check this: the argument may be
twenty lines below the constructor name, and a naive fixed window either misses
a distant `meta:` or picks up the `meta:` of the *next* header down. So this
walks the parentheses.

Why a tool and not only a widget test: a widget test can prove the component
renders a meta it is given, which is a different claim from every screen giving
it one. This is the claim that regresses — a new screen added next month gets a
header with no meta and nothing notices. Run it in the same breath as
`release_guards.dart`.
"""
import os
import re
import subprocess
import sys
import tempfile

WIDGETS = ('MlPageHeader', 'MlSectionTitle')

# The files that DEFINE the widgets - their own constructor is not a call site.
DEFINITIONS = ('ml_page_header.dart', 'ml_section_title.dart')


def _tracked_dart_files(root):
    """Every tracked .dart file under lib/, or every .dart file if not a repo."""
    try:
        out = subprocess.run(['git', 'ls-files', 'lib'], cwd=root,
                             capture_output=True, text=True, check=True).stdout
        files = [f for f in out.split() if f.endswith('.dart')]
        if files:
            return files
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    found = []
    for dirpath, _, names in os.walk(root):
        for n in names:
            if n.endswith('.dart'):
                found.append(os.path.relpath(os.path.join(dirpath, n), root))
    return sorted(found)


def _argument_span(src, open_paren):
    """Index just past the matching close paren, skipping strings and comments.

    Naive bracket counting is wrong here for a reason worth stating: these call
    sites are full of `'Don\\'t'`, `'${a.b(c)}'` and `// (see below)`, and every
    one of those contains a paren that must not count.
    """
    depth = 0
    i = open_paren
    n = len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            i = src.find('\n', i)
            if i == -1:
                return n
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            i = n if j == -1 else j + 2
            continue
        if c in '\'"':
            quote = c
            triple = src.startswith(quote * 3, i)
            i += 3 if triple else 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if triple and src.startswith(quote * 3, i):
                    i += 3
                    break
                if not triple and src[i] == quote:
                    i += 1
                    break
                if not triple and src[i] == '\n':
                    break  # unterminated single-line string; bail safely
                i += 1
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


# `meta:` as a named argument, not inside a nested call and not in a comment.
_META = re.compile(r'(?m)^(?!\s*(?://|///|\*))[^\n]*?\bmeta:')


def scan(root):
    """Returns (total_sites, [(file, line, widget, title)]) for sites w/o meta."""
    total = 0
    missing = []
    for rel in _tracked_dart_files(root):
        path = os.path.join(root, rel)
        try:
            with open(path, encoding='utf-8') as fh:
                src = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        if os.path.basename(rel) in DEFINITIONS:
            continue
        for widget in WIDGETS:
            for m in re.finditer(r'\b%s\s*\(' % widget, src):
                # A declaration (`const MlPageHeader({`) is not a call site.
                if src[m.end():m.end() + 1] == '{':
                    continue
                total += 1
                end = _argument_span(src, m.end() - 1)
                args = src[m.end():end]
                if _META.search(args):
                    continue
                line = src.count('\n', 0, m.start()) + 1
                title = re.match(r"\s*('[^']*'|\"[^\"]*\"|[\w.]+)", args)
                missing.append((rel.replace('\\', '/'), line, widget,
                                title.group(1) if title else '?'))
    return total, missing


def selftest():
    """Plant a header with a meta and one without; the check must see exactly one."""
    ok = True
    with tempfile.TemporaryDirectory(prefix='mlmeta') as tmp:
        os.makedirs(os.path.join(tmp, 'lib'))
        good = os.path.join(tmp, 'lib', 'good.dart')
        with open(good, 'w', encoding='utf-8') as fh:
            fh.write(
                "Widget b() => MlPageHeader(\n"
                "  title: 'Loads',\n"
                "  // a comment mentioning meta: which must not count\n"
                "  description: 'Every load, and a )( paren in a string',\n"
                "  meta: mlCount(3, 'load'),\n"
                ");\n"
                "Widget c() => MlSectionTitle('Fills',\n"
                "    icon: Icons.x, meta: 'x');\n"
            )
        total, missing = scan(tmp)
        if total == 2 and not missing:
            print('SELFTEST  clean tree: 2 sites, 0 missing — OK')
        else:
            ok = False
            print('SELFTEST  clean tree WRONG: %d sites, %d missing %s'
                  % (total, len(missing), missing))

        with open(os.path.join(tmp, 'lib', 'bad.dart'), 'w', encoding='utf-8') as fh:
            fh.write("Widget b() => MlPageHeader(title: 'No meta here');\n")
        total, missing = scan(tmp)
        if total == 3 and len(missing) == 1 and missing[0][0].endswith('bad.dart'):
            print('SELFTEST  planted violation: BITES')
        else:
            ok = False
            print('SELFTEST  planted violation: DID NOT BITE — %d sites, %s'
                  % (total, missing))

        # A `meta:` belonging to the NEXT header must not rescue this one.
        with open(os.path.join(tmp, 'lib', 'bad.dart'), 'w', encoding='utf-8') as fh:
            fh.write(
                "Widget b() => Column(children: [\n"
                "  MlSectionTitle('First, no meta'),\n"
                "  MlSectionTitle('Second', meta: 'has one'),\n"
                "]);\n"
            )
        total, missing = scan(tmp)
        if len(missing) == 1 and 'First' in missing[0][3]:
            print('SELFTEST  adjacent-header bleed: BITES')
        else:
            ok = False
            print('SELFTEST  adjacent-header bleed: DID NOT BITE — %s' % (missing,))
    print('\nall checks bite' if ok else '\nSELFTEST FAILED')
    return 0 if ok else 1


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--selftest' in sys.argv:
        return selftest()
    total, missing = scan(root)
    for rel, line, widget, title in missing:
        print('MISSING META  %s:%d  %s(%s' % (rel, line, widget, title))
    covered = total - len(missing)
    print('header-meta: %d/%d call sites pass a meta line' % (covered, total))
    if missing:
        print('S5-22 requires every one. A header with no meta has no slot for '
              'the context the design reference puts on the right of it.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())

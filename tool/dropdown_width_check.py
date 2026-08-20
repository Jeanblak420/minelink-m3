#!/usr/bin/env python3
"""A dropdown must not be free to size itself to its widest option.

    py -3 tool/dropdown_width_check.py
    py -3 tool/dropdown_width_check.py --selftest

WHY
---
`DropdownButton` and `DropdownButtonFormField` lay their SELECTED item out at
its natural width, and size the control to the WIDEST item in the list — so one
long option decides how much room the control takes whatever is selected, and
nothing in it can ellipsize its way out.

`CLAUDE.md` §10.4 records this for `DropdownButtonFormField`: a "Seal points on
this rig" field whose longest option read *"4 seals — interlink, two trailers"*
pushed the add-vehicle dialog **357px** past a narrow phone. The plain
`DropdownButton` has exactly the same behaviour, which was not recorded — and on
2026-08-20 one of them put the employee register's status filter 31px past a
430px viewport at text scale 1.6, the moment its label moved up by a single
point.

`isExpanded: true` is the fix, and it is what this checks for. A dropdown that
expands takes the width its parent gives it and lets its item ellipsize, which
is why the parent has to be bounded — inside a `Wrap` or a `Row` that means a
`ConstrainedBox`, or the control claims the whole line and puts every other
filter on a row of its own.

This is a source check rather than a widget test because the failure is silent
at every ordinary text size: nothing overflows until a label is long enough or a
user has nudged the scale, and by then it is in front of somebody.
"""

from __future__ import annotations

import glob
import os
import re
import sys

# A Windows console is cp1252 and cannot encode the punctuation these messages
# use. `glyph_coverage_check.py` died on exactly this, printing its own results.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

OPEN = re.compile(r'\bDropdownButton(FormField)?(?:<[^>]*>)?\s*\(')


def span_end(src: str, open_paren: int) -> int:
    depth, i, n = 0, open_paren, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            q, i = c, i + 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q or src[i] == '\n':
                    break
                i += 1
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def offenders(root: str = 'lib') -> list[str]:
    out = []
    for path in sorted(glob.glob(f'{root}/**/*.dart', recursive=True)):
        n = path.replace(os.sep, '/')
        src = open(path, encoding='utf-8', errors='replace').read()
        for m in OPEN.finditer(src):
            end = span_end(src, m.end() - 1)
            if end < 0:
                continue
            if 'isExpanded' in src[m.end():end]:
                continue
            kind = 'DropdownButtonFormField' if m.group(1) else 'DropdownButton'
            line = src[:m.start()].count('\n') + 1
            out.append(f'{n}:{line}  {kind} with no isExpanded')
    return out


def main() -> int:
    bad = offenders()
    if bad:
        print(f'{len(bad)} dropdown(s) free to size themselves to their widest '
              f'option:')
        for b in bad:
            print(f'  {b}')
        print('\nAdd `isExpanded: true`, and make sure the parent is bounded — '
              'inside a Wrap or a Row that means a ConstrainedBox, or the '
              'control claims the whole line.')
        return 1
    print('every dropdown in lib/ states isExpanded')
    return 0


def selftest() -> int:
    """A grep that matches nothing reports green forever."""
    import tempfile
    bad = 0
    with tempfile.TemporaryDirectory() as d:
        os.makedirs(f'{d}/sub', exist_ok=True)
        with open(f'{d}/sub/planted.dart', 'w', encoding='utf-8') as f:
            f.write('Widget b() => DropdownButton<int>(\n'
                    '  value: 1,\n'
                    '  items: const [],\n'
                    '  onChanged: null,\n'
                    ');\n')
        found = offenders(d)
        if len(found) != 1:
            print(f'FAIL  planted violation not found (got {found})')
            bad += 1
        with open(f'{d}/sub/planted.dart', 'w', encoding='utf-8') as f:
            f.write('Widget b() => DropdownButton<int>(\n'
                    '  value: 1,\n'
                    '  isExpanded: true,\n'
                    '  items: const [],\n'
                    '  onChanged: null,\n'
                    ');\n')
        found = offenders(d)
        if found:
            print(f'FAIL  clean file reported as a violation ({found})')
            bad += 1
    print('selftest: ' + ('OK — bites on a planted dropdown and not on a '
                          'clean one' if not bad else f'{bad} failures'))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(selftest() if '--selftest' in sys.argv else main())

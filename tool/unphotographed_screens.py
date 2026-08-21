"""Which route-target screens still have no picture.

    py -3 tool/unphotographed_screens.py

The redesign's method is "photograph the screen, then measure the picture", and
every screen photographed so far has turned up a real defect. So the list that
matters is not "how many renders are there" but "which screens have never been
looked at" — and until this existed that list was kept by hand in HANDOFF.md,
which is exactly the kind of inventory that drifts.

It reads the ROUTER, because a screen a route builds is a screen a user can
reach; a widget nothing routes to is a different question. It then asks whether
`test/renders/redesign_renders_test.dart` names that class anywhere.

Two honest limits, stated rather than hidden:

  * NAME-BASED. A screen rendered through a wrapper of another name reads as
    unphotographed. Check the render file before believing an entry.
  * A NAME IN THE RENDER FILE IS NOT A PICTURE OF THE SCREEN. It could be an
    import, or a render that photographs an error card — which CLAUDE.md 10.5
    and this project's own history say is not a screen photographed at all.
    Look at the PNG.

`swept` marks a class some test under `test/` at least mentions, so a layout
sweep may already cover its widths — which is worth knowing and is not the same
as having been seen.
"""
import io
import os
import re
import sys

if hasattr(sys.stdout, 'reconfigure'):          # a Windows console is cp1252
    sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _read(*parts):
    return io.open(os.path.join(ROOT, *parts), encoding='utf-8',
                   newline='').read()


def main():
    router = _read('lib', 'core', 'routing', 'app_router.dart')
    renders = _read('test', 'renders', 'redesign_renders_test.dart')

    tests = []
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'test')):
        for fn in files:
            if fn.endswith('.dart'):
                tests.append(io.open(os.path.join(base, fn), encoding='utf-8',
                                     newline='').read())
    swept_in = '\n'.join(tests)

    # The FIRST screen class named after each `builder:` — the thing that route
    # actually builds, rather than every type mentioned nearby.
    targets = set()
    for m in re.finditer(r'builder:\s*\(context,\s*state\)\s*(=>|\{)', router):
        tail = router[m.end():m.end() + 900]
        found = re.search(r'\b([A-Z][A-Za-z0-9_]*Screen)\b', tail)
        if found:
            targets.add(found.group(1))

    photographed = set(re.findall(r'\b([A-Z][A-Za-z0-9_]*Screen)\b', renders))
    missing = sorted(targets - photographed)

    print('%d route-target screens · %d named in the renders · %d not'
          % (len(targets), len(targets & photographed), len(missing)))
    for name in missing:
        print('   %-6s %s' % ('swept' if name in swept_in else '', name))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

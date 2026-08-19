#!/usr/bin/env python3
"""A dialog that holds input fields must be able to scroll.

    python tool/dialog_scroll_check.py
    python tool/dialog_scroll_check.py --selftest

WHY THIS EXISTS
---------------
`AlertDialog(content: SizedBox(child: Column(...)))` is the house pattern for a
form dialog, and it is fine on a desktop and unusable on a phone the moment the
content grows taller than the viewport. There is no scrolling, so the overflow
is CLIPPED: the fields and the buttons below the fold cannot be reached at all.

Measured 2026-08-18 on `token_generator_dialog.dart`, at the largest text scale
the shells install on a 320px phone:

    A RenderFlex overflowed by 133 pixels on the bottom.

That is not a cosmetic overflow — a platform admin on a phone could not finish
generating a token. All three of that dialog's states had it. An audit of the
whole tree then found the same shape in 16 dialogs across 12 files.

The size that triggers it is reachable by any user: since 2026-08-17 the shells
COMPOSE the operating system's text scaler with the in-app preference, so
`kMaxEffectiveTextScale` is a real setting, not a test contrivance.

WHAT IT CHECKS
--------------
Every `AlertDialog(` in `lib/` whose argument window contains BOTH a `Column(`
and at least one input widget, and which offers no way to scroll — no
`scrollable: true`, no `SingleChildScrollView`, no `ListView`.

Input widgets are what make this urgent rather than tidy: a two-line
confirmation dialog cannot outgrow a viewport, and demanding `scrollable` there
would make this check noise that people learn to ignore.

LIMIT, STATED
-------------
This is a source scan over a fixed window after each `AlertDialog(`, not a
parse. A dialog assembled across helper methods, or one whose fields sit more
than ~2600 characters in, will not be seen. It is a floor, not a proof — the
proof is rendering the thing, which is what `test/test_helpers/dialog_sweep
.dart` is for.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
WINDOW = 2600

INPUTS = re.compile(
    r"TextFormField\(|TextField\(|DropdownButtonFormField|M3DropdownField")
SCROLLS = ("scrollable: true", "SingleChildScrollView", "ListView")


def offenders(sources):
    """[(path, line)] for every unscrollable dialog holding input fields.

    [sources] is {path: text}, so the selftest can hand in a synthetic tree.
    """
    found = []
    for path, src in sorted(sources.items()):
        for m in re.finditer(r"AlertDialog\(", src):
            window = src[m.start():m.start() + WINDOW]
            if "content:" not in window:
                continue
            if any(s in window for s in SCROLLS):
                continue
            if "Column(" not in window:
                continue
            if not INPUTS.search(window):
                continue
            found.append((path, src[:m.start()].count("\n") + 1))
    return found


def read_lib():
    sources = {}
    for dirpath, _dirnames, filenames in os.walk(LIB):
        for fn in filenames:
            if not fn.endswith(".dart"):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding="utf-8", errors="replace") as f:
                sources[os.path.relpath(p, ROOT).replace(os.sep, "/")] = f.read()
    return sources


def selftest():
    """Plant each shape, including the ones that must NOT fire."""
    ok = True

    def case(label, sources, expect):
        nonlocal ok
        got = len(offenders(sources))
        passed = got == expect
        ok &= passed
        print("  %-54s %s%s" % (label, "bites" if passed else "MISSED",
                                "" if passed else "  -- found %d, wanted %d"
                                % (got, expect)))

    form = ("AlertDialog(\n  content: SizedBox(child: Column(children: [\n"
            "    TextFormField(controller: c),\n  ])),\n)")
    case("a form dialog that cannot scroll", {"a.dart": form}, 1)
    case("...with scrollable: true",
         {"a.dart": form.replace("AlertDialog(", "AlertDialog(\n  scrollable: true,")}, 0)
    case("...wrapped in a SingleChildScrollView",
         {"a.dart": form.replace("SizedBox(child:", "SizedBox(child: SingleChildScrollView(child:")}, 0)
    # The two that must stay silent, or the check becomes noise.
    case("a confirmation dialog with no fields",
         {"a.dart": "AlertDialog(\n  content: Column(children: [Text('Sure?')]),\n)"}, 0)
    case("a dropdown-only dialog still counts",
         {"a.dart": "AlertDialog(\n  content: Column(children: [\n"
                    "    DropdownButtonFormField<int>(items: const []),\n  ]),\n)"}, 1)
    case("two offenders in one file",
         {"a.dart": form + "\n\n" + form}, 2)

    print("\n%s" % ("all planted faults were caught" if ok
                    else "SELFTEST FAILED -- this checker cannot be trusted"))
    return 0 if ok else 1


def main():
    if "--selftest" in sys.argv:
        print("Planting each shape this check claims to catch:\n")
        return selftest()

    found = offenders(read_lib())
    if not found:
        print("PASS  every AlertDialog holding input fields can scroll")
        return 0

    print("%d dialog(s) hold input fields and cannot scroll.\n"
          "On a narrow phone at a large text size their content is CLIPPED and\n"
          "the fields below the fold cannot be reached.\n" % len(found))
    for path, line in found:
        print("  FAIL  %s:%d" % (path, line))
    print("\nAdd `scrollable: true` to the AlertDialog, or wrap its content in a\n"
          "SingleChildScrollView.")
    return 1


raise SystemExit(main())

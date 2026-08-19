#!/usr/bin/env python3
"""A dialog must dismiss ITSELF, not the screen underneath it.

Fails when a `showDialog` / `showModalBottomSheet` / `showGeneralDialog` call
pops with a `BuildContext` that is not the builder's own.

WHY THIS IS A SOURCE GUARD AND NOT A UNIT TEST
----------------------------------------------
Found 2026-08-17 by driving the running app. On the super-admin request inbox,
"Send back for revision" opened its note dialog and pressing EITHER button
blanked the entire console to white — no Dart exception, no JS error
(window.onerror / unhandledrejection / console.error hooks all captured
nothing), `location.hash` unchanged, semantics tree down to 0 nodes, and the
request left untouched in the database. Pressing **Cancel** — which performs no
network call at all — did exactly the same thing, which is what pinned the cause
to the dialog's own dismissal rather than to the review RPC.

    showDialog(
      context: context,
      builder: (_) => AlertDialog(                       // context discarded
        actions: [
          TextButton(onPressed: () => Navigator.pop(context)),   // the SCREEN's
        ],
      ),
    );

The super-admin console and the portal are both GoRouter `ShellRoute`s
(`app_router.dart:657` and `:1292`), so each owns an inner `Navigator`.
`showDialog` defaults to `useRootNavigator: true` and pushes onto the ROOT
navigator, while `Navigator.pop(screenContext)` resolves to the SHELL's inner
one. The pop removes the *page*; the shell is left with nothing to draw.

Nothing in the analyzer or the test suite catches this: it type-checks, it runs,
and in a flat single-Navigator widget test it even behaves — the shape only goes
wrong once a nested Navigator is in the tree. `flutter analyze` was clean and
1191 tests were green while four sites were broken in production.

`test/widgets/dialog_pops_the_dialog_test.dart` pins the behaviour in a
ShellRoute-shaped tree. This guards the shape across the whole tree.

WHAT IS ALLOWED
---------------
Popping with a context that comes from a builder NESTED inside the dialog —
`StatefulBuilder(builder: (ctx, setLocal) => ...)` — is correct: that `ctx` is a
descendant of the dialog route, so `Navigator.of(ctx)` finds the root navigator.
Four such sites exist and are deliberately not flagged.

Usage:
    python tool/dialog_context_check.py          # check lib/
    python tool/dialog_context_check.py --self-test
"""
from __future__ import annotations

import pathlib
import re
import sys
import tempfile

SHOW_FNS = r"(?:showDialog|showModalBottomSheet|showGeneralDialog|showCupertinoDialog|showCupertinoModalPopup)"
CALL_RE = re.compile(SHOW_FNS + r"\s*(?:<[^>]*>)?\s*\(")
BUILDER_RE = re.compile(r"builder:\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*[,)]")
POP_RE = re.compile(r"Navigator\.(?:pop|of)\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)")
# A nested builder inside the dialog introduces its own, legitimate context.
NESTED_BUILDER_RE = re.compile(r"builder:\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:,\s*[A-Za-z_][A-Za-z0-9_]*\s*)?\)")


def _call_body(src: str, open_paren: int) -> str:
    """Return the parenthesised argument list starting at `open_paren`."""
    depth = 0
    i = open_paren
    while i < len(src):
        ch = src[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return src[open_paren:i + 1]
        i += 1
    return src[open_paren:]


def scan_source(src: str) -> list[tuple[int, str, list[str]]]:
    """Return (line, builder_param, offending_context_names) per bad call."""
    out: list[tuple[int, str, list[str]]] = []
    for m in CALL_RE.finditer(src):
        open_paren = src.index("(", m.end() - 1)
        body = _call_body(src, open_paren)
        bm = BUILDER_RE.search(body)
        if not bm:
            continue
        # Every context legitimately in scope inside the dialog: the outer
        # builder's own parameter plus any nested builder's.
        allowed = {n for n in NESTED_BUILDER_RE.findall(body)}
        allowed.add(bm.group(1))
        bad = sorted({n for n in POP_RE.findall(body) if n not in allowed})
        if bad:
            out.append((src[:m.start()].count("\n") + 1, bm.group(1), bad))
    return out


def scan_tree(root: pathlib.Path) -> list[str]:
    problems: list[str] = []
    for f in sorted(root.rglob("*.dart")):
        src = f.read_text(encoding="utf-8", errors="replace")
        for line, param, bad in scan_source(src):
            rel = f.as_posix()
            problems.append(
                f"{rel}:{line}  builder takes `{param}` but pops with "
                f"{', '.join('`' + b + '`' for b in bad)} - pop with `{param}`"
            )
    return problems


_PLANT = """
import 'package:flutter/material.dart';
class X extends StatelessWidget {
  const X({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
        child: const Text('open'),
      );
}
"""

_CLEAN = _PLANT.replace("builder: (_)", "builder: (dialogContext)").replace(
    "Navigator.pop(context)", "Navigator.pop(dialogContext)"
)


def self_test() -> int:
    """A grep that matches nothing reports green forever. Prove it bites."""
    ok = True
    with tempfile.TemporaryDirectory() as td:
        d = pathlib.Path(td)
        (d / "planted.dart").write_text(_PLANT, encoding="utf-8")
        found = scan_tree(d)
        if not found:
            print("SELF-TEST FAIL: the planted violation was not detected")
            ok = False
        else:
            print(f"self-test: planted violation detected -> {found[0]}")
        (d / "planted.dart").write_text(_CLEAN, encoding="utf-8")
        if scan_tree(d):
            print("SELF-TEST FAIL: the corrected form was flagged")
            ok = False
        else:
            print("self-test: the corrected form is accepted")
    return 0 if ok else 1


def main() -> int:
    if "--self-test" in sys.argv or "--selftest" in sys.argv:
        return self_test()
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "lib")
    if not root.exists():
        print(f"no such directory: {root}")
        return 2
    problems = scan_tree(root)
    if problems:
        print("FAIL - a dialog would pop the screen instead of itself:\n")
        for p in problems:
            print(f"  {p}")
        print(
            "\nPop with the builder's own context. See "
            "test/widgets/dialog_pops_the_dialog_test.dart for why."
        )
        return 1
    print("PASS - every dialog pops with its own context.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

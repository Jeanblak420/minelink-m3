#!/usr/bin/env python3
"""Attribute every LOW CONTRAST finding to the TOKEN that produced it.

Grouping by painted colour is one step short of a fix. `textFaint` is
`onSurfaceVariant` at 62% alpha, so it paints a DIFFERENT hex on every surface
in the ladder - #627084 on the card, #5E6B7E on the canvas, #5E697A on the
page - and the report names all three as separate pairs. They are one line of
code.

So this composites each candidate token onto each finding's measured ground
and asks which one it is. What comes back is the list of DECISIONS, ranked -
which is the thing you can actually act on.

Usage:
    py -3 tool/attribute_low_contrast.py <captured-test-output>
    py -3 tool/attribute_low_contrast.py out.txt --token textFaint
    py -3 tool/attribute_low_contrast.py --selftest
"""
from __future__ import annotations

import collections
import importlib.util
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_here, path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


rank = _load("rank_low_contrast", "rank_low_contrast.py")
calc = _load("contrast_calc", "contrast_calc.py")

# Every token that can paint quiet text, with the alpha it is used at.
#
# `alpha` is part of the token's identity here, not a detail: `textMuted` and
# `textFaint` are the SAME colour and differ only by it, so a table that left
# it out would attribute half the findings to the wrong decision.
TOKENS = [
    # (name, colour, alpha, where it is declared)
    ("textFaint/dark", "#94A3B8", 0.62, "ml_tokens.dart MlSemantic - onSurfaceVariant x .62"),
    ("textMuted/dark", "#94A3B8", 1.00, "ml_tokens.dart MlSemantic - onSurfaceVariant"),
    ("textFaint/light", "#475569", 0.62, "ml_tokens.dart MlSemantic - onSurfaceVariant x .62"),
    ("textMuted/light", "#475569", 1.00, "ml_tokens.dart MlSemantic - onSurfaceVariant"),
    ("MlGlass.dark.inkLo", "#6B7A9C", 1.00, "ml_surface_tokens.dart"),
    ("MlGlass.dark.inkXlo", "#606E8C", 1.00, "ml_surface_tokens.dart"),
    ("MlGlass.dark.inkMid", "#8896AE", 1.00, "ml_surface_tokens.dart"),
    ("MlGlass.light.inkLo", "#6F7E94", 1.00, "ml_surface_tokens.dart"),
    ("MlGlass.light.inkXlo", "#7C8AA0", 1.00, "ml_surface_tokens.dart"),
    ("MlGlass.light.inkMid", "#5A697F", 1.00, "ml_surface_tokens.dart"),
    ("MlChrome.railSectionLabel", "#63758F", 1.00, "m3/ml_chrome.dart"),
    ("scheme.outline/dark", "#5D6D8C", 1.00, "m3/ml_scheme.dart"),
    ("scheme.outline/light", "#94A3B8", 1.00, "m3/ml_scheme.dart"),
]


def attribute(hit) -> tuple[str, str] | None:
    """Which token paints `hit.ink` on `hit.ground`? None if no candidate does."""
    for name, colour, alpha, where in TOKENS:
        _, eff = calc.ratio(colour, hit.ground, alpha)
        if eff == hit.ink:
            return name, where
    return None


def selftest() -> int:
    ok = True

    def check(cond, msg):
        nonlocal ok
        if not cond:
            print(f"SELFTEST FAIL: {msg}")
            ok = False

    class H:
        def __init__(self, ink, ground):
            self.ink, self.ground = ink, ground

    # The four grounds textFaint/dark is measured on must all come back as ONE
    # token. This is the whole point of the file.
    for ground, ink in [
        ("#111C30", "#627084"),
        ("#060F20", "#5E6B7E"),
        ("#060B15", "#5E697A"),
        ("#0E1728", "#616E81"),
    ]:
        got = attribute(H(ink, ground))
        _, eff = calc.ratio("#94A3B8", ground, 0.62)
        if eff != ink:
            # The fixture itself must be right, or the test proves nothing.
            check(False, f"fixture wrong: slate400@.62 on {ground} is {eff}, not {ink}")
            continue
        check(got is not None and got[0] == "textFaint/dark",
              f"{ink} on {ground} should be textFaint/dark, got {got}")

    # An opaque token must not be confused with the translucent one.
    check(attribute(H("#6B7A9C", "#111C30"))[0] == "MlGlass.dark.inkLo",
          "opaque inkLo misattributed")

    # Something no token explains must come back as None, not as a guess.
    check(attribute(H("#FF00FF", "#111C30")) is None,
          "an unexplained colour must not be attributed")

    print("SELFTEST OK" if ok else "SELFTEST FAILED")
    return 0 if ok else 1


def main() -> int:
    args = sys.argv[1:]
    if "--selftest" in args:
        return selftest()
    if not args:
        print(__doc__)
        return 2

    with open(args[0], encoding="utf-8", errors="replace", newline="") as f:
        hits = rank.parse(f)

    want = None
    if "--token" in args:
        want = args[args.index("--token") + 1]

    groups = collections.defaultdict(list)
    unattributed = []
    for h in hits:
        got = attribute(h)
        if got is None:
            unattributed.append(h)
        else:
            groups[got].append(h)

    if want:
        for (name, _), hs in groups.items():
            if name != want:
                continue
            print(f"{name}: {len(hs)} string(s)")
            by_ground = collections.Counter(h.ground for h in hs)
            for g, n in by_ground.most_common():
                worst = min(h.ratio for h in hs if h.ground == g)
                print(f"  {n:5d}  on {g}   worst {worst:.2f}:1")
        return 0

    total = len(hits)
    print(f"{total} findings; {total - len(unattributed)} attributed to a "
          f"named token, {len(unattributed)} not.\n")
    print(f"{'strings':>8}  {'worst':>6}  {'grounds':>7}  token")
    print("-" * 78)
    ranked = sorted(groups.items(), key=lambda kv: -len(kv[1]))
    running = 0
    for (name, where), hs in ranked:
        running += len(hs)
        worst = min(h.ratio for h in hs)
        print(f"{len(hs):8d}  {worst:6.2f}  {len({h.ground for h in hs}):7d}  "
              f"{name}   ({running}/{total} cumulative)")
        print(f"{'':8}  {'':6}  {'':7}  {where}")
    if unattributed:
        print(f"\n{len(unattributed)} not explained by any token in the table:")
        for pair, hs in collections.Counter(
                (h.ink, h.ground) for h in unattributed).most_common(12):
            print(f"  {hs:5d}  {pair[0]} on {pair[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

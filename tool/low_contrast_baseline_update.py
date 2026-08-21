#!/usr/bin/env python3
"""Lower `test/renders/low_contrast_baseline.json` to what a run actually found.

The baseline is a RATCHET: it records how many strings each render had when
the report was last trustworthy, so a render can only get better. Nothing
lowers it automatically, because a drop is a claim - either a fix landed or
the instrument changed - and the commit has to say which.

This writes the drops and REFUSES the rises, printing both. A render that got
fainter is a finding, not a number to rewrite; use --allow-rises only when the
run being fed in is a deliberate re-baseline and say why in the commit.

Usage:
    py -3 tool/low_contrast_baseline_update.py <captured-test-output>
    py -3 tool/low_contrast_baseline_update.py out.txt --apply
    py -3 tool/low_contrast_baseline_update.py out.txt --apply --full-run
    py -3 tool/low_contrast_baseline_update.py --selftest
"""
from __future__ import annotations

import json
import os
import re
import sys

HEAD = re.compile(r"^LOW CONTRAST \[([^\]]+)\] (\d+) string\(s\) at ")
BASELINE = "test/renders/low_contrast_baseline.json"


def counts_from(path: str) -> dict[str, int]:
    found: dict[str, int] = {}
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        for line in f:
            m = HEAD.match(line)
            if m:
                found[m.group(1)] = int(m.group(2))
    return found


def selftest() -> int:
    ok = True

    def check(cond, msg):
        nonlocal ok
        if not cond:
            print(f"SELFTEST FAIL: {msg}")
            ok = False

    import tempfile
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "run.txt")
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write("LOW CONTRAST [a] 3 string(s) at 100x100:\n")
            f.write("  ~ x\n")
            f.write("noise\n")
            f.write("LOW CONTRAST [b] 0 string(s) at 100x100:\n")
        got = counts_from(p)
        check(got == {"a": 3, "b": 0}, f"parse wrong: {got}")

    base = {"a": 5, "b": 1, "c": 2}
    drops, rises, same = classify(base, {"a": 3, "b": 1})
    check(drops == {"a": (5, 3)}, f"drops wrong: {drops}")
    check(rises == {}, f"rises wrong: {rises}")
    check(same == ["b"], f"same wrong: {same}")

    # A render that got FAINTER must be reported as a rise, never folded in.
    drops, rises, _ = classify({"a": 2}, {"a": 7})
    check(rises == {"a": (2, 7)}, f"a rise must be flagged: {rises}")
    check(drops == {}, "a rise is not a drop")

    print("SELFTEST OK" if ok else "SELFTEST FAILED")
    return 0 if ok else 1


def classify(base: dict[str, int], found: dict[str, int]):
    drops, rises, same = {}, {}, []
    for render, n in found.items():
        was = base.get(render)
        if was is None:
            rises[render] = (0, n) if n else (0, 0)
            continue
        if n < was:
            drops[render] = (was, n)
        elif n > was:
            rises[render] = (was, n)
        else:
            same.append(render)
    return drops, rises, same


def main() -> int:
    args = sys.argv[1:]
    if "--selftest" in args:
        return selftest()
    if not args:
        print(__doc__)
        return 2
    path = args[0]
    apply = "--apply" in args
    allow_rises = "--allow-rises" in args
    full_run = "--full-run" in args

    found = counts_from(path)
    if not found:
        print(f"No LOW CONTRAST blocks in {path} - nothing to do.")
        return 2

    with open(BASELINE, encoding="utf-8", newline="") as f:
        base = json.load(f)

    drops, rises, same = classify(base, found)
    missing = sorted(set(base) - set(found))

    print(f"{len(found)} render(s) reported; baseline holds {len(base)}.")
    print(f"  unchanged: {len(same)}")
    print(f"  LOWER:     {len(drops)}   (total -{sum(w - n for w, n in drops.values())})")
    for r, (w, n) in sorted(drops.items(), key=lambda kv: kv[1][0] - kv[1][1], reverse=True):
        print(f"      {r:<52} {w} -> {n}")
    if rises:
        print(f"  HIGHER:    {len(rises)}   <- these got FAINTER")
        for r, (w, n) in sorted(rises.items()):
            print(f"      {r:<52} {w} -> {n}")
    if missing:
        # A render that printed NO block either did not run, or reached zero.
        # Those are opposite meanings, and only the caller knows which: a
        # filtered run must leave the others alone, a full run should bank the
        # win. So it is a flag, not a guess.
        verb = "zeroed" if full_run else "left alone"
        print(f"  not in this run ({verb}): {len(missing)}")
        for r in missing:
            print(f"      {r:<52} {base[r]} -> {0 if full_run else base[r]}")

    if rises and not allow_rises:
        print("\nRefusing to write: a render got fainter. Read the LOW CONTRAST "
              "block for it and fix the cause, or pass --allow-rises and say "
              "why in the commit.")
        return 1

    if not apply:
        print("\nDry run. Pass --apply to write.")
        return 0

    for r, (_, n) in drops.items():
        base[r] = n
    if full_run:
        for r in missing:
            base[r] = 0
    if allow_rises:
        for r, (_, n) in rises.items():
            base[r] = n
    with open(BASELINE, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(base.items())), f, indent=2)
        f.write("\n")
    print(f"\nWrote {BASELINE}: total allowance now {sum(base.values())}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

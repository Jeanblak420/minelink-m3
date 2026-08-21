#!/usr/bin/env python3
"""Rank the render harness's LOW CONTRAST findings by what would FIX them.

The report prints one block per render and one pair of lines per string.
A fix is almost never per-string: it is a change to one (ink, ground) pair,
or to one widget that paints many of them. So this groups the raw findings
three ways and prints each ranked, worst-first:

    1. by (ink, ground)  — the token decision
    2. by widget trail   — the component that paints them
    3. by render         — where to look at a picture

Usage:
    py -3 tool/rank_low_contrast.py <path-to-captured-test-output>
    py -3 tool/rank_low_contrast.py out.txt --pair "#FFFFFF on #22D3EE"
    py -3 tool/rank_low_contrast.py out.txt --selftest
"""
from __future__ import annotations

import collections
import re
import sys

# "LOW CONTRAST [console-desktop-dark] 27 string(s) at 1612x1400:"
HEAD = re.compile(r"^LOW CONTRAST \[([^\]]+)\] (\d+) string\(s\) at (\d+)x(\d+):")
# "  ~ Some text"
TEXT = re.compile(r"^  ~ (.*)$")
# "      3.38:1 (needs 4.5)  ink #627084 on #111C30   at 41,639 47x16   11px  A < B"
DETAIL = re.compile(
    r"^\s+([0-9.]+):1 \(needs ([0-9.]+)\)\s+ink (#[0-9A-F]{6}) on (#[0-9A-F]{6})\s+"
    r"at (\d+),(\d+) (\d+)x(\d+)\s+(.*)$"
)


class Hit:
    __slots__ = ("render", "text", "ratio", "needs", "ink", "ground",
                 "x", "y", "w", "h", "where", "size", "trail")

    def __init__(self, render, text, ratio, needs, ink, ground, x, y, w, h, where):
        self.render = render
        self.text = text
        self.ratio = ratio
        self.needs = needs
        self.ink = ink
        self.ground = ground
        self.x, self.y, self.w, self.h = x, y, w, h
        self.where = where
        # "11px bold  A < B < C"  ->  size "11px bold", trail "A < B < C"
        parts = where.split("  ", 1)
        self.size = parts[0].strip()
        self.trail = parts[1].strip() if len(parts) > 1 else ""

    @property
    def pair(self) -> str:
        return f"{self.ink} on {self.ground}"

    @property
    def deficit(self) -> float:
        """How far under the bar, in ratio points. Ranks severity honestly:
        a 1.81 that needed 4.5 is worse than a 4.4 that needed 4.5."""
        return self.needs - self.ratio


def parse(lines) -> list[Hit]:
    hits: list[Hit] = []
    render = None
    pending_text = None
    for line in lines:
        line = line.rstrip("\n")
        m = HEAD.match(line)
        if m:
            render = m.group(1)
            pending_text = None
            continue
        if render is None:
            continue
        m = TEXT.match(line)
        if m:
            pending_text = m.group(1)
            continue
        if pending_text is not None:
            m = DETAIL.match(line)
            if m:
                hits.append(Hit(
                    render, pending_text, float(m.group(1)), float(m.group(2)),
                    m.group(3), m.group(4), int(m.group(5)), int(m.group(6)),
                    int(m.group(7)), int(m.group(8)), m.group(9),
                ))
                pending_text = None
            else:
                # A `~` line whose detail line did not follow means the block
                # ended. Do not silently drop it - say so.
                pending_text = None
                render = render
    return hits


def _bar(n: int, top: int, width: int = 28) -> str:
    if top <= 0:
        return ""
    return "#" * max(1, round(n / top * width))


def group_report(hits: list[Hit], key, title: str, limit: int, show_examples: int = 2):
    groups: dict[str, list[Hit]] = collections.defaultdict(list)
    for h in hits:
        groups[key(h)].append(h)
    ranked = sorted(groups.items(), key=lambda kv: (-len(kv[1]), min(x.ratio for x in kv[1])))
    print()
    print("=" * 78)
    print(f"{title}   ({len(groups)} distinct, {len(hits)} strings)")
    print("=" * 78)
    top = len(ranked[0][1]) if ranked else 0
    for name, gs in ranked[:limit]:
        worst = min(g.ratio for g in gs)
        renders = len({g.render for g in gs})
        print()
        print(f"{len(gs):5d}  {_bar(len(gs), top):<28}  {name}")
        print(f"       worst {worst:.2f}:1   in {renders} render(s)")
        for g in sorted(gs, key=lambda x: x.ratio)[:show_examples]:
            txt = g.text if len(g.text) <= 46 else g.text[:45] + "…"
            print(f"         - {g.ratio:.2f}:1  {txt!r}")
            print(f"           {g.size}  {g.trail}")
            print(f"           {g.render} @ {g.x},{g.y} {g.w}x{g.h}")
    if len(ranked) > limit:
        rest = sum(len(g) for _, g in ranked[limit:])
        print()
        print(f"       ... and {len(ranked) - limit} more group(s), {rest} strings.")


def selftest() -> int:
    sample = """
LOW CONTRAST [console-desktop-dark] 2 string(s) at 1612x1400:
  ~ Fleet utilisation
      1.81:1 (needs 4.5)  ink #FFFFFF on #22D3EE   at 10,20 47x16   11px  A < B
  ~ 12
      3.38:1 (needs 4.5)  ink #627084 on #111C30   at 41,639 47x16   11px bold  C < D
some other line entirely
LOW CONTRAST [dash-mine-phone-dark] 1 string(s) at 412x915:
  ~ Balance
      1.81:1 (needs 4.5)  ink #FFFFFF on #22D3EE   at 1,2 3x4   9px  E
""".splitlines()
    hits = parse(sample)
    ok = True

    def check(cond, msg):
        nonlocal ok
        if not cond:
            print(f"SELFTEST FAIL: {msg}")
            ok = False

    check(len(hits) == 3, f"expected 3 hits, got {len(hits)}")
    check(hits[0].render == "console-desktop-dark", "render not captured")
    check(hits[0].pair == "#FFFFFF on #22D3EE", f"pair wrong: {hits[0].pair}")
    check(abs(hits[0].deficit - 2.69) < 0.001, f"deficit wrong: {hits[0].deficit}")
    check(hits[1].size == "11px bold", f"size wrong: {hits[1].size!r}")
    check(hits[1].trail == "C < D", f"trail wrong: {hits[1].trail!r}")
    check(hits[2].render == "dash-mine-phone-dark", "second block not parsed")
    pairs = collections.Counter(h.pair for h in hits)
    check(pairs["#FFFFFF on #22D3EE"] == 2, "grouping across renders failed")

    # A block whose text line has no detail line must not swallow the next hit.
    broken = """
LOW CONTRAST [x] 2 string(s) at 1x1:
  ~ orphan
  ~ real
      2.00:1 (needs 4.5)  ink #000000 on #111111   at 0,0 1x1   9px  Z
""".splitlines()
    b = parse(broken)
    check(len(b) == 1 and b[0].text == "real",
          f"orphan handling wrong: {[x.text for x in b]}")

    print("SELFTEST OK" if ok else "SELFTEST FAILED")
    return 0 if ok else 1


def main() -> int:
    args = sys.argv[1:]
    if "--selftest" in args:
        return selftest()
    if not args:
        print(__doc__)
        return 2
    path = args[0]
    want_pair = None
    if "--pair" in args:
        want_pair = args[args.index("--pair") + 1]
    limit = 14
    if "--limit" in args:
        limit = int(args[args.index("--limit") + 1])

    with open(path, "r", encoding="utf-8", errors="replace", newline="") as f:
        hits = parse(f)

    if not hits:
        print(f"No LOW CONTRAST findings in {path}.")
        return 0

    if want_pair:
        hits = [h for h in hits if h.pair == want_pair]
        print(f"Filtered to {len(hits)} string(s) with pair {want_pair}")
        for h in sorted(hits, key=lambda x: (x.render, x.y)):
            print(f"  {h.ratio:.2f}:1  {h.render:<40} {h.text!r}")
            print(f"          {h.size}  {h.trail}")
        return 0

    print(f"{len(hits)} LOW CONTRAST strings across "
          f"{len({h.render for h in hits})} renders, from {path}")

    group_report(hits, lambda h: h.pair, "BY (INK, GROUND) PAIR - the token decision", limit)
    group_report(hits, lambda h: h.trail or "(no trail)",
                 "BY WIDGET TRAIL - the component that paints them", limit, show_examples=1)
    group_report(hits, lambda h: h.render, "BY RENDER - where to look at a picture",
                 limit, show_examples=1)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

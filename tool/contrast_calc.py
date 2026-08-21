#!/usr/bin/env python3
"""WCAG contrast arithmetic for picking token values, not guessing them.

Two things this does that eyeballing a hex cannot:

  * `ratio` composites a TRANSLUCENT ink onto its ground first, exactly as
    the render harness does. `onSurfaceVariant.withValues(alpha: .62)` is a
    different colour on every surface in the ladder, and the whole point of
    the ink ladder is that it is used across all of them.
  * `solve` answers the question a fix actually asks - "what alpha, or what
    lightness, reaches 4.5:1 here?" - so a corrected token is derived rather
    than nudged until a test goes quiet.

Usage:
    py -3 tool/contrast_calc.py ratio  #94A3B8 #111C30 [alpha]
    py -3 tool/contrast_calc.py solve-alpha #94A3B8 #111C30 4.5
    py -3 tool/contrast_calc.py solve-tint  #94A3B8 #111C30 4.5
    py -3 tool/contrast_calc.py ladder #0A1424,#111C30,#16243C -- #94A3B8 ...
    py -3 tool/contrast_calc.py --selftest
"""
from __future__ import annotations

import sys


def _hex(c: str) -> tuple[int, int, int]:
    c = c.strip().lstrip("#")
    if len(c) == 8:  # AARRGGBB
        c = c[2:]
    if len(c) != 6:
        raise ValueError(f"not a colour: {c!r}")
    return int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)


def _tohex(rgb: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % rgb


def luminance(rgb: tuple[int, int, int]) -> float:
    def ch(v: int) -> float:
        f = v / 255.0
        return f / 12.92 if f <= 0.03928 else ((f + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def composite(ink: tuple[int, int, int], ground: tuple[int, int, int],
              alpha: float) -> tuple[int, int, int]:
    return tuple(round(i * alpha + g * (1 - alpha)) for i, g in zip(ink, ground))


def ratio(ink: str, ground: str, alpha: float = 1.0) -> tuple[float, str]:
    i, g = _hex(ink), _hex(ground)
    eff = composite(i, g, alpha) if alpha < 1.0 else i
    return contrast(eff, g), _tohex(eff)


def solve_alpha(ink: str, ground: str, target: float) -> float | None:
    """Lowest alpha at which this ink reaches `target` on this ground.

    Returns None when even fully opaque does not get there - which is the
    answer that matters, because it means the INK is wrong, not its opacity.
    """
    i, g = _hex(ink), _hex(ground)
    if contrast(i, g) < target:
        return None
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if contrast(composite(i, g, mid), g) >= target:
            hi = mid
        else:
            lo = mid
    return hi


def solve_tint(ink: str, ground: str, target: float):
    """Move the ink along its own hue, away from the ground, until it reaches
    `target`. Returns the corrected colour.

    Lightening a slate towards white (on a dark ground) or darkening it
    towards black (on a light ground) keeps the hue and the ladder's spacing,
    which is what a token change should do - it should not become a different
    colour, only a legible one.
    """
    i, g = _hex(ink), _hex(ground)
    towards = (255, 255, 255) if luminance(g) < 0.5 else (0, 0, 0)
    if contrast(towards, g) < target:
        return None  # target unreachable on this ground at all
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        cand = composite(towards, i, mid)
        if contrast(cand, g) >= target:
            hi = mid
        else:
            lo = mid
    return _tohex(composite(towards, i, hi)), hi


def selftest() -> int:
    ok = True

    def check(cond, msg):
        nonlocal ok
        if not cond:
            print(f"SELFTEST FAIL: {msg}")
            ok = False

    # Known WCAG anchors.
    check(abs(contrast(_hex("#FFFFFF"), _hex("#000000")) - 21.0) < 0.01,
          "white on black must be 21:1")
    check(abs(contrast(_hex("#777777"), _hex("#FFFFFF")) - 4.48) < 0.02,
          f"#777 on white should be ~4.48, got {contrast(_hex('#777777'), _hex('#FFFFFF')):.3f}")
    check(abs(contrast(_hex("#111C30"), _hex("#111C30")) - 1.0) < 1e-9,
          "a colour against itself is 1:1")

    # The composite must reproduce the harness's headline finding:
    # slate400 at 62% on the M3 card surface is #627084 and about 3.38:1.
    r, eff = ratio("#94A3B8", "#111C30", 0.62)
    check(eff == "#627084", f"composite should be #627084, got {eff}")
    check(abs(r - 3.38) < 0.02, f"should be ~3.38:1, got {r:.2f}")

    # solve_alpha must be monotone-correct and honest about impossibility.
    a = solve_alpha("#94A3B8", "#111C30", 4.5)
    check(a is not None and 0.62 < a < 1.0, f"alpha for 4.5 should be > .62, got {a}")
    check(abs(ratio("#94A3B8", "#111C30", a)[0] - 4.5) < 0.05,
          "solved alpha must actually hit the target")
    check(solve_alpha("#111C30", "#111C30", 4.5) is None,
          "an ink equal to its ground can never reach 4.5 - must return None")

    # solve_tint moves towards white on dark and towards black on light.
    dark_fix, _ = solve_tint("#94A3B8", "#111C30", 7.0)
    check(luminance(_hex(dark_fix)) > luminance(_hex("#94A3B8")),
          "on a dark ground the fix must be LIGHTER")
    light_fix, _ = solve_tint("#8D96A2", "#FFFFFF", 4.5)
    check(luminance(_hex(light_fix)) < luminance(_hex("#8D96A2")),
          "on a light ground the fix must be DARKER")
    check(contrast(_hex(light_fix), _hex("#FFFFFF")) >= 4.5,
          "solved tint must actually hit the target")

    print("SELFTEST OK" if ok else "SELFTEST FAILED")
    return 0 if ok else 1


def main() -> int:
    args = sys.argv[1:]
    if not args or "--selftest" in args:
        return selftest() if args else (print(__doc__) or 2)
    cmd = args[0]
    if cmd == "ratio":
        alpha = float(args[3]) if len(args) > 3 else 1.0
        r, eff = ratio(args[1], args[2], alpha)
        print(f"{args[1]} @ {alpha:g} on {args[2]}  ->  {eff}  {r:.2f}:1")
    elif cmd == "solve-alpha":
        a = solve_alpha(args[1], args[2], float(args[3]))
        if a is None:
            print(f"UNREACHABLE: {args[1]} cannot reach {args[3]}:1 on {args[2]} "
                  f"even at full opacity (max "
                  f"{contrast(_hex(args[1]), _hex(args[2])):.2f}:1)")
        else:
            print(f"alpha {a:.3f}  ->  {ratio(args[1], args[2], a)[0]:.2f}:1")
    elif cmd == "solve-tint":
        res = solve_tint(args[1], args[2], float(args[3]))
        if res is None:
            print("UNREACHABLE on this ground at all")
        else:
            fix, t = res
            print(f"{fix}  (moved {t*100:.0f}% toward "
                  f"{'white' if luminance(_hex(args[2])) < 0.5 else 'black'})"
                  f"  {contrast(_hex(fix), _hex(args[2])):.2f}:1")
    elif cmd == "ladder":
        grounds = args[1].split(",")
        inks = args[args.index("--") + 1:]
        w = max(len(i) for i in inks) + 2
        print(" " * w + "  ".join(f"{g:>9}" for g in grounds))
        for ink in inks:
            alpha = 1.0
            name = ink
            if "@" in ink:
                name, a = ink.split("@")
                alpha = float(a)
            cells = []
            for g in grounds:
                r, _ = ratio(name, g, alpha)
                mark = " " if r >= 4.5 else ("." if r >= 3.0 else "!")
                cells.append(f"{r:8.2f}{mark}")
            print(f"{ink:<{w}}" + "  ".join(cells))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Revert each fix in low_contrast_report.dart one at a time, so the test
that is supposed to catch it can be watched failing.

A check nobody has sabotaged is a check nobody has. And it has to be the RIGHT
half: two changes landing together can each hide the other's regression, and
a sabotage that is not the ORIGINAL BUG proves nothing either - "delete the
exclusion" and "match the declared colour instead of the painted one" are
different faults, and only the second is the one that shipped.
"""
import shutil
import subprocess
import sys

P = "test/renders/low_contrast_report.dart"
BAK = P + ".sabotage-backup"

SABOTAGES = {
    # 1. The clip test: pretend nothing is ever clipped away.
    "clip": (
        "  final visible = _visiblePaintRect(ro);\n  if (visible == null) return null;",
        "  final visible = ro.localToGlobal(Offset.zero) & ro.size;",
    ),
    # 2. The ink-line distance test: keep only the old relative half.
    "ink-line": (
        "      if (off <= _inkLineTolerance * _inkLineTolerance) inkPixels++;",
        "      if (off >= 0) inkPixels++;",
    ),
    # 3. NOT IN THE DEFAULT SET. It WAS load-bearing, and the palette moved
    #    out from under it.
    #
    #    The halo exclusion: let an anti-aliased blend count as the ground.
    #    A glyph's halo is a blend, so it can sit ~150 units from both the ink
    #    and the ground and survive a "near the ink" test - and in a tight box
    #    over a GRADIENT fill it does not have to outnumber the fill, only the
    #    fill's most common single shade. The transporters overview's rank
    #    badge did exactly that: 11 white pixels, ~20 of teal split four ways,
    #    8 of one halo colour, and the halo won. The report said
    #    `#FFFFFF on #8CB7BB - 2.19:1` for white on a teal that is 5.9:1.
    #
    #    Adding this removed that finding from the real render, which is how
    #    it was verified. It is unreachable NOW because the same session then
    #    deepened the light accent the badge is filled with, and no box in the
    #    current palette produces a halo that wins a mode vote any more.
    #
    #    A synthetic scene did not reproduce it either - two attempts, one
    #    with a flat fill and one with a gradient - so no test pretends to
    #    catch it. Run `py -3 tool/_sabotage.py halo` after any palette change
    #    that puts light ink back on a mid-saturation fill.
    "halo": (
        "      modeExcluding(effectiveInks(provisional), blendedWith: provisional);",
        "      modeExcluding(effectiveInks(provisional));",
    ),
    # 4. The modal guard: measure the page a dialog was opened over.
    "modal": (
        "      if (text.isNotEmpty && !isIcon && !_behindAModal(e)) {",
        "      if (text.isNotEmpty && !isIcon) {",
    ),
    # 4. NOT IN THE DEFAULT SET, AND THE REASON IS THE POINT.
    #
    #    This puts the ground computation back EXACTLY as it shipped: exclude
    #    by the DECLARED colour, ignoring alpha, so a translucent ink is never
    #    excluded from its own ground.
    #
    #    It is a real hole and it is UNREACHABLE with real fonts. The bug only
    #    changes the answer when the glyphs are most of their own box, and a
    #    survey of the densest cases this app can produce topped out at 45.7%
    #    coverage; below 50% the background wins the mode either way. Running
    #    all 220 renders with and without the fix returned byte-identical
    #    findings, 1,798 both times.
    #
    #    So no test catches this sabotage, and none is written that pretends
    #    to. Run it explicitly with `py -3 tool/_sabotage.py ground` to
    #    re-check that claim after any change to the fonts, the type scale, or
    #    _visiblePaintRect - all three move the coverage number.
    "ground": (
        "  final ground = modeExcluding(effectiveInks(provisional));",
        "  final ground = modeExcluding(<int>[\n"
        "    for (final c in spanColors)\n"
        "      (((c.r * 255).round()) << 16) |\n"
        "          (((c.g * 255).round()) << 8) |\n"
        "          ((c.b * 255).round()),\n"
        "  ]);",
    ),
}


def run(name):
    shutil.copy(P, BAK)
    try:
        s = open(P, encoding="utf-8", newline="").read()
        old, new = SABOTAGES[name]
        if old not in s:
            print(f"  {name}: ANCHOR MISSING - cannot sabotage")
            return False
        open(P, "w", encoding="utf-8", newline="").write(s.replace(old, new, 1))
        r = subprocess.run(
            ["flutter", "test", "test/renders/low_contrast_report_test.dart",
             "--reporter", "compact"],
            capture_output=True, text=True, shell=True,
            encoding="utf-8", errors="replace",
        )
        out = (r.stdout or "") + (r.stderr or "")
        failed = [ln for ln in out.splitlines() if " [E]" in ln]
        if r.returncode == 0:
            print(f"  {name}: *** TEST STILL PASSED - THE CHECK IS NOT REAL ***")
            return False
        print(f"  {name}: caught, {len(failed)} failing test(s)")
        for ln in failed[:6]:
            print("      " + ln.split(": ", 1)[-1].strip())
        return True
    finally:
        shutil.move(BAK, P)


if __name__ == "__main__":
    # `ground` and `halo` are excluded from the default run, each with its
    # reason recorded above. Both are correct fixes that nothing can currently
    # catch, and saying so is the point - a sabotage list that quietly omits
    # what it cannot catch is the same lie as a test that never fails.
    default = [n for n in SABOTAGES if n not in ("ground", "halo")]
    names = sys.argv[1:] or default
    print("Sabotaging low_contrast_report.dart, one fix at a time:")
    results = [run(n) for n in names]
    ok = all(results)
    print("ALL SABOTAGES CAUGHT" if ok else "SOME SABOTAGE WENT UNCAUGHT")
    raise SystemExit(0 if ok else 1)

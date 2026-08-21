#!/usr/bin/env python3
"""Every character a UI string uses must exist in the font that will draw it.

    py -3 tool/glyph_coverage_check.py
    py -3 tool/glyph_coverage_check.py --selftest

WHY
---
A Flutter `fontFamily` that resolves but lacks a GLYPH does not throw and does
not fall back predictably: on a handset the platform's own fallback chain
usually supplies the missing character, on the web it may not, and in a test
render it comes out as a tofu box. So a symbol can look correct everywhere
anyone has looked and be wrong somewhere nobody has.

Found 2026-08-20 the first time the driver's Trip screen was rendered: two
lifecycle buttons read "Arrived at loading ✓", and U+2713 is not in Plus Jakarta
Sans. The button already carried a check ICON, so the tick was redundant as well
as unprintable.

WHAT IT CHECKS
--------------
The three faces the product ships — Plus Jakarta Sans, JetBrains Mono and
Fraunces — against every non-ASCII character in a Dart string literal under
`lib/`. ASCII is assumed present; a font missing 'a' is not the failure mode
this is for.

Reads the `cmap` table out of each TTF directly rather than depending on a font
library, because a check that needs an install is a check that stops being run.
"""

from __future__ import annotations

import glob
import os
import re
import struct
import sys
import unicodedata

# Windows consoles default to cp1252, which cannot encode the very characters
# this tool exists to talk about — it died printing its own findings the first
# time it ran.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

FONTS = {
    'PlusJakartaSans': 'assets/fonts/PlusJakartaSans-Regular.ttf',
    'JetBrainsMono': 'assets/fonts/JetBrainsMono-Regular.ttf',
    'Fraunces': 'assets/fonts/Fraunces-Medium.ttf',
}

# Characters that are never drawn as text.
IGNORE = set('\n\r\t')

# Emoji are drawn by the platform's colour emoji font, never by a text face, so
# their absence from the three shipped cmaps is expected rather than a defect.
# The chat dock ships an emoji picker and a reaction bar; every one of those is
# supposed to come from the OS.
#
# This is the Emoji_Presentation set (characters that default to emoji style),
# plus everything from U+1F000 up. It is deliberately NOT "the Dingbats block",
# because U+2713 ✓ lives in Dingbats and is Emoji=No — a text tick, which is
# exactly the character this tool was written after.
EMOJI_PRESENTATION = [
    (0x231A, 0x231B), (0x23E9, 0x23EC), (0x23F0, 0x23F0), (0x23F3, 0x23F3),
    (0x25FD, 0x25FE), (0x2614, 0x2615), (0x2648, 0x2653), (0x267F, 0x267F),
    (0x2693, 0x2693), (0x26A1, 0x26A1), (0x26AA, 0x26AB), (0x26BD, 0x26BE),
    (0x26C4, 0x26C5), (0x26CE, 0x26CE), (0x26D4, 0x26D4), (0x26EA, 0x26EA),
    (0x26F2, 0x26F3), (0x26F5, 0x26F5), (0x26FA, 0x26FA), (0x26FD, 0x26FD),
    (0x2705, 0x2705), (0x270A, 0x270B), (0x2728, 0x2728), (0x274C, 0x274C),
    (0x274E, 0x274E), (0x2753, 0x2755), (0x2757, 0x2757), (0x2795, 0x2797),
    (0x27B0, 0x27B0), (0x27BF, 0x27BF), (0x2B1B, 0x2B1C), (0x2B50, 0x2B50),
    (0x2B55, 0x2B55), (0x1F000, 0x10FFFF),
]

VARIATION_SELECTOR_16 = 0xFE0F


def is_emoji(ch: str) -> bool:
    c = ord(ch)
    return any(lo <= c <= hi for lo, hi in EMOJI_PRESENTATION)


def cmap_of(path: str) -> set[int]:
    """Every code point the font's `cmap` maps, from formats 4 and 12."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] not in (b'\x00\x01\x00\x00', b'true', b'ttcf', b'OTTO'):
        raise ValueError(f'{path}: not a TrueType/OpenType file')
    num_tables = struct.unpack('>H', data[4:6])[0]
    cmap_off = None
    for i in range(num_tables):
        rec = 12 + i * 16
        if data[rec:rec + 4] == b'cmap':
            cmap_off = struct.unpack('>I', data[rec + 8:rec + 12])[0]
            break
    if cmap_off is None:
        raise ValueError(f'{path}: no cmap table')

    n = struct.unpack('>H', data[cmap_off + 2:cmap_off + 4])[0]
    points: set[int] = set()
    for i in range(n):
        rec = cmap_off + 4 + i * 8
        sub = cmap_off + struct.unpack('>I', data[rec + 4:rec + 8])[0]
        fmt = struct.unpack('>H', data[sub:sub + 2])[0]
        if fmt == 4:
            seg_x2 = struct.unpack('>H', data[sub + 6:sub + 8])[0]
            seg = seg_x2 // 2
            ends = sub + 14
            starts = ends + seg_x2 + 2
            deltas = starts + seg_x2
            ranges = deltas + seg_x2
            for s in range(seg):
                end = struct.unpack('>H', data[ends + s * 2:ends + s * 2 + 2])[0]
                start = struct.unpack(
                    '>H', data[starts + s * 2:starts + s * 2 + 2])[0]
                delta = struct.unpack(
                    '>h', data[deltas + s * 2:deltas + s * 2 + 2])[0]
                ro = struct.unpack(
                    '>H', data[ranges + s * 2:ranges + s * 2 + 2])[0]
                if start == 0xFFFF:
                    continue
                for c in range(start, end + 1):
                    if ro == 0:
                        gid = (c + delta) & 0xFFFF
                    else:
                        gi = ranges + s * 2 + ro + (c - start) * 2
                        if gi + 2 > len(data):
                            continue
                        gid = struct.unpack('>H', data[gi:gi + 2])[0]
                        if gid:
                            gid = (gid + delta) & 0xFFFF
                    if gid:
                        points.add(c)
        elif fmt == 12:
            groups = struct.unpack('>I', data[sub + 12:sub + 16])[0]
            for g in range(groups):
                o = sub + 16 + g * 12
                lo, hi, _ = struct.unpack('>III', data[o:o + 12])
                points.update(range(lo, hi + 1))
    return points


STRING = re.compile(
    r"'''(?:[^\\]|\\.)*?'''|\"\"\"(?:[^\\]|\\.)*?\"\"\"|"
    r"'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"")
LINE_COMMENT = re.compile(r'//[^\n]*')
BLOCK_COMMENT = re.compile(r'/\*.*?\*/', re.S)


def ui_characters() -> dict[str, list[str]]:
    """Non-ASCII characters in Dart string literals under lib/, with sites."""
    found: dict[str, list[str]] = {}
    for path in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        n = path.replace(os.sep, '/')
        src = open(path, encoding='utf-8', errors='replace').read()
        src = BLOCK_COMMENT.sub(' ', src)
        src = LINE_COMMENT.sub(' ', src)
        for m in STRING.finditer(src):
            line = src[:m.start()].count('\n') + 1
            text = m.group(0)
            for i, ch in enumerate(text):
                if ord(ch) < 128 or ch in IGNORE:
                    continue
                if is_emoji(ch):
                    continue
                # A character followed by U+FE0F is an emoji presentation of an
                # otherwise-text symbol — ☝️ ⛏️ ✌️ ❤️ 🏗️ all appear that way in
                # the chat dock's picker. The selector itself is skipped too.
                if ord(ch) == VARIATION_SELECTOR_16:
                    continue
                if (i + 1 < len(text)
                        and ord(text[i + 1]) == VARIATION_SELECTOR_16):
                    continue
                found.setdefault(ch, [])
                if len(found[ch]) < 4:
                    found[ch].append(f'{n}:{line}')
    return found


def main() -> int:
    missing_fonts = [p for p in FONTS.values() if not os.path.exists(p)]
    if missing_fonts:
        print('FAIL  font file(s) not found: ' + ', '.join(missing_fonts))
        return 2

    coverage = {name: cmap_of(path) for name, path in FONTS.items()}
    chars = ui_characters()

    bad, partial = [], []
    for ch, sites in sorted(chars.items()):
        # Format characters (Cf) have no glyph by definition — U+200B, the
        # zero-width space `_breakable()` uses to let a long reference wrap, is
        # handled by the layout engine and never drawn. Absence from a cmap is
        # not a tofu risk.
        if unicodedata.category(ch) in ('Cf', 'Zs') and ch != ' ':
            continue
        absent = [f for f, pts in coverage.items() if ord(ch) not in pts]
        if len(absent) == len(coverage):
            bad.append((ch, sites))
        elif absent:
            partial.append((ch, absent, sites))

    print(f'{len(chars)} distinct non-ASCII characters in lib/ UI strings')

    # Absent from EVERY shipped face: nothing in the product can draw it, and
    # what appears instead is whatever the platform happens to fall back to.
    for ch, sites in bad:
        print(f'  MISSING  U+{ord(ch):04X} {ch!r} — in none of the three faces')
        for s in sites:
            print(f'             {s}')

    # Absent from SOME face. Not a failure, and since 2026-08-21 not a hazard
    # either: this tool cannot tell which face will draw a given string, so the
    # answer was to stop needing to know. Every site that names the serif also
    # names `MlTokens.fontSerifFallback`, held by the
    # `serif-declares-its-fallback` release guard, so a character Fraunces
    # lacks is drawn by Plus Jakarta Sans instead of by nothing.
    #
    # It WAS a hazard until then. The buyer's Waybills screen heads each route
    # group with the two points and an arrow between them, and MlSectionTitle
    # draws its title in the serif — so every heading on that screen read
    # "Iron Hills Mining [tofu] Richards Bay". This list already named U+2192
    # and could only ever call it advisory.
    #
    # Still printed, because the list is the inventory of what that fallback
    # is carrying, and it is worth reading before a new symbol is introduced.
    if partial:
        print(f'\n  {len(partial)} character(s) missing from SOME face — '
              f'covered by the declared font fallback, not a failure:')
        for ch, absent, sites in partial:
            print(f'    U+{ord(ch):04X} {ch!r} — not in {", ".join(absent)} '
                  f'({sites[0]})')

    if bad:
        print(f'\n{len(bad)} character(s) NO shipped font can draw. A Flutter '
              f'font that lacks a glyph does not throw; it renders a tofu box '
              f'wherever the platform has no fallback of its own.')
        return 1
    print('\nevery character is drawable by at least one shipped face')
    return 0


def selftest() -> int:
    """A grep that matches nothing reports green forever."""
    bad = 0
    sans = cmap_of(FONTS['PlusJakartaSans'])
    for ch, want in ((0x0041, True), (0x00B7, True), (0x2014, True),
                     (0x2192, True), (0x2713, False)):
        if (ch in sans) != want:
            print(f'FAIL  U+{ch:04X} in PlusJakartaSans = {ch in sans}, '
                  f'expected {want}')
            bad += 1
    if not bad:
        print('selftest: OK — the cmap reader finds the characters the product '
              'uses (· — →) and does NOT find U+2713, which is the one that '
              'shipped as a tofu box.')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(selftest() if '--selftest' in sys.argv else main())

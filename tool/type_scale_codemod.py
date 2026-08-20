#!/usr/bin/env python3
"""Move hand-built `TextStyle(...)` literals onto the M3 type scale.

Run from the repo root:

    py -3 tool/type_scale_codemod.py --report lib/features/chat/widgets/chat_dock.dart
    py -3 tool/type_scale_codemod.py --apply  lib/features/chat/widgets/chat_dock.dart
    py -3 tool/type_scale_codemod.py --stats

WHAT IT IS FOR
--------------
A `TextStyle` written from scratch carries only what is written into it.
`height` and `letterSpacing` come from whatever `DefaultTextStyle` is in scope,
which inside a `Scaffold` is `bodyMedium` — so a hand-written 15px w800 title was
drawn with body metrics (line height 1.43 instead of 1.27, tracking +0.25
instead of -0.1). It looks nearly right, which is why ~500 of them accumulated,
and why line spacing visibly differs between two cards on one screen.

This rewrites each such literal to the scale slot it is actually playing:

    TextStyle(fontFamily: MlTokens.fontSans, fontWeight: FontWeight.w700,
              fontSize: 14, color: pal.headerText)
 -> context.mlText.titleSmall.copyWith(color: pal.headerText,
              fontWeight: FontWeight.w700)

WHAT IT REFUSES TO DO
---------------------
It is deliberately narrow, because the failure mode of a type codemod is a
screen that still compiles and now says something slightly different about its
own hierarchy. It skips, and reports, anything it cannot decide:

  * a non-literal `fontSize` (`size * 0.36`, a parameter, a ternary)
  * a `fontFamily` that resolves to none of the three faces
  * `const TextStyle(` — `Theme.of` is not a constant
  * a serif or mono literal carrying arguments `MlType.figure` / `MlType.code`
    cannot express
  * sizes below 10 or above 32 in the sans faces
  * a serif below 14 — the small companion to a numeral, which is neither an
    editorial title nor a figure

It never touches text outside a `TextStyle(` ... `)` span, so a doc comment
explaining a rule cannot be rewritten into something that no longer says it
(HANDOFF section 5).

THE SERIF DOES TWO JOBS, AND THE SPLIT IS BY SIZE
-------------------------------------------------
`docs/design-reference.md` section 3 gives Fraunces "section titles, AND every
large numeral". Measured across this tree with `--audit-serif`: every site below
28 is a title (16, 18, 19, 20, 21, 22, 24, 26) and every site at 28 or above is
a hero figure (28, 30, 32, 38, 46). Titles take the editorial rungs, figures
take `MlType.figure`. Re-run that audit before trusting the boundary — it is a
fact about the data, not a rule imposed on it.

THE SIZE DECISION IS THE REVIEWABLE PART
----------------------------------------
Snapping an off-scale size to the scale is a design decision, not a mechanical
one: a screen using 16 and 18 as two levels of sub-heading loses the
distinction if both land on 16. `--report` prints every size change under
`SIZE`, and that list is meant to be read before `--apply` -- per screen, by a
person, against what the screen is trying to say.

Ties round **up**: 13 -> 14, 19 -> 22. A tie broken downwards shrinks text that
someone deliberately made larger.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

# ---------------------------------------------------------------- the scale

# slot -> (size, weight). Mirrors lib/core/design/tokens/m3/ml_typography.dart;
# `--selftest` reads that file and fails if the two ever disagree.
SLOTS: dict[str, tuple[int, int]] = {
    'displayLarge': (45, 500),
    'displayMedium': (36, 500),
    'displaySmall': (32, 500),
    'headlineLarge': (32, 700),
    'headlineMedium': (28, 700),
    'headlineSmall': (24, 700),
    'titleLarge': (22, 600),
    'titleMedium': (16, 600),
    'titleSmall': (14, 600),
    'bodyLarge': (16, 400),
    'bodyMedium': (14, 400),
    'bodySmall': (12, 400),
    'labelLarge': (14, 600),
    'labelMedium': (12, 600),
    'labelSmall': (11, 600),
}

# The slot's own height and letterSpacing, so an explicit one that already
# agrees can be dropped rather than restated.
METRICS: dict[str, tuple[float, float]] = {
    'displayLarge': (52 / 45, -0.5),
    'displayMedium': (44 / 36, -0.3),
    'displaySmall': (40 / 32, -0.2),
    'headlineLarge': (40 / 32, -0.4),
    'headlineMedium': (36 / 28, -0.3),
    'headlineSmall': (32 / 24, -0.2),
    'titleLarge': (28 / 22, -0.1),
    'titleMedium': (24 / 16, 0.15),
    'titleSmall': (20 / 14, 0.1),
    'bodyLarge': (24 / 16, 0.5),
    'bodyMedium': (20 / 14, 0.25),
    'bodySmall': (16 / 12, 0.4),
    'labelLarge': (20 / 14, 0.1),
    'labelMedium': (16 / 12, 0.5),
    'labelSmall': (16 / 11, 0.5),
}

# The sizes a sans site may land on, and which slot each maps to at regular
# weight and at semibold-or-heavier. There is no body slot above 16 (M3's body
# ramp stops there), so 22+ regular takes a title slot with the weight put back.
STEPS = [11, 12, 14, 16, 22, 24, 28, 32]
REGULAR = {
    11: 'labelSmall', 12: 'bodySmall', 14: 'bodyMedium', 16: 'bodyLarge',
    22: 'titleLarge', 24: 'headlineSmall', 28: 'headlineMedium',
    32: 'headlineLarge',
}
STRONG = {
    11: 'labelSmall', 12: 'labelMedium', 14: 'titleSmall', 16: 'titleMedium',
    22: 'titleLarge', 24: 'headlineSmall', 28: 'headlineMedium',
    32: 'headlineLarge',
}

WEIGHT_WORDS = {'bold': 700, 'normal': 400}

# `MlTokens.fs*` are already aliases of scale steps (see ml_tokens.dart, "There
# were TWO type scales"), so resolving them here changes no size at all — these
# are the safest conversions in the whole job.
SIZE_ALIASES = {
    'MlTokens.fsDisplay': 32.0, 'MlTokens.fsH1': 24.0, 'MlTokens.fsH2': 22.0,
    'MlTokens.fsH3': 16.0, 'MlTokens.fsTitle': 16.0, 'MlTokens.fsBody': 16.0,
    'MlTokens.fsBodySm': 14.0, 'MlTokens.fsLabel': 12.0,
    'MlTokens.fsMicro': 11.0,
}

# Every name in the tree that resolves to one of the three faces. `MlGlass`,
# `MlAuth` and the overview tokens each re-declared the family — two of them as
# bare string literals rather than as aliases of `MlTokens` — so "one name per
# typeface" was true of the token file and not of the product.
#
# `kConsoleSans` WAS the exception. It was `'Sora'` — a fourth typeface, alive at
# seven sites in the console's own dashboard widgets while the rail beside them
# ran Plus Jakarta Sans — and this table carried it as a face CHANGE so the
# report could never make it a silent one. Sora was retired on 2026-08-20 and
# the constant is now an alias of `MlTokens.fontSans`, so it is an ordinary
# rename again.
#
# The `True` flag stays in the table rather than being deleted with it: the next
# name that means a different face wants exactly this treatment, and a mechanism
# with no live example is one nobody remembers is there.
FAMILY_ALIASES = {
    'MlTokens.fontSans': ('sans', False),
    'MlTokens.fontMono': ('mono', False),
    'MlTokens.fontSerif': ('serif', False),
    'MlGlass.sans': ('sans', False),
    'MlGlass.mono': ('mono', False),
    'MlGlass.display': ('serif', False),
    'MlAuth.sans': ('sans', False),
    'MlAuth.mono': ('mono', False),
    'MlAuth.serif': ('serif', False),
    'kEditorialSerif': ('serif', False),
    "'PlusJakartaSans'": ('sans', False),
    "'JetBrainsMono'": ('mono', False),
    "'Fraunces'": ('serif', False),
    'kConsoleSans': ('sans', False),  # an alias since Sora was retired
    "'Sora'": ('sans', True),  # the flag's live example, if one ever returns
}

TABULAR = ('[FontFeature.tabularFigures()]',
           'const [FontFeature.tabularFigures()]',
           '<FontFeature>[FontFeature.tabularFigures()]')

# Files this tool must never rewrite, whatever glob is typed at it.
#
# The token layer is where the raw `TextStyle(...)` literals are SUPPOSED to
# live — it is the definition of the scale. Rewriting `MlTypeScale.textTheme`
# into `context.mlText.bodyMedium` would define the scale in terms of itself, in
# a file that has no BuildContext to do it with. The theme is the same case one
# level up.
#
# This is a property of the tool rather than of the caller's glob, because
# `lib/**/*.dart` is the obvious thing to type and it is the thing that breaks.
NEVER = ('/core/design/tokens/', '/core/theme/app_theme.dart')


def excluded(path: str) -> bool:
    n = '/' + path.replace(os.sep, '/').lstrip('./')
    return any(bit in n for bit in NEVER)


def snap(size: float) -> int:
    """Nearest step, ties up. See the module docstring."""
    best = None
    for s in STEPS:
        d = abs(s - size)
        if best is None or d < best[0] - 1e-9 or (abs(d - best[0]) < 1e-9 and s > best[1]):
            best = (d, s)
    return best[1]


# ------------------------------------------------------------- dart parsing

def match_paren(src: str, start: int) -> int:
    """Index of the ')' matching the '(' at `start`. String- and comment-aware."""
    depth = 0
    i, n = start, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            q = c
            triple = src.startswith(q * 3, i)
            i += 3 if triple else 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if triple and src.startswith(q * 3, i):
                    i += 3
                    break
                if not triple and src[i] == q:
                    i += 1
                    break
                if not triple and src[i] == '\n':
                    break
                i += 1
            continue
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i)
            i = n if j < 0 else j + 2
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


# Flutter's `TextStyle`, and ONLY Flutter's.
#
# `\bTextStyle\s*\(` also matches `pw.TextStyle(` — the `pdf` package's own
# class, which shares the name and nothing else. employee_profile_pdf.dart and
# waybill_pdf.dart are full of them, and rewriting one produces
# `pw.context.mlText.titleSmall` in a file that has no BuildContext and never
# will: a PDF is composed off-screen. The lookbehind is what makes the tool
# refuse a qualified name rather than guess at it.
TEXT_STYLE = re.compile(r'(?<![\w.$])TextStyle\s*\(')

CONST_CALL = re.compile(r'\bconst\s+(?:[A-Z]\w*(?:\.\w+)?\s*)?[(\[{]')


def const_regions(src: str) -> list[tuple[int, int]]:
    """Spans of `const` expressions, which everything inside inherits.

    Checking for a literal `const TextStyle(` is not enough: Dart propagates
    const down a whole expression, so a plain `TextStyle(...)` sitting inside
    `const Text(...)` is itself const. Rewriting one of those to a method call
    compiles to `const_eval_method_invocation` — which is at least loud, but the
    point of a codemod is not to hand the compiler work it should not have been
    given.

    Conservative on purpose. A span it gets wrong means a literal is skipped and
    reported, never that one is rewritten wrongly.
    """
    spans = []
    for m in CONST_CALL.finditer(src):
        open_at = m.end() - 1
        if src[open_at] == '(':
            end = match_paren(src, open_at)
        else:
            end = _match_bracket(src, open_at)
        if end > 0:
            spans.append((m.start(), end))
    return spans


def _match_bracket(src: str, start: int) -> int:
    """`match_paren` for `[` and `{`, for `const [...]` and `const {...}`."""
    pairs = {'[': ']', '{': '}'}
    opener = src[start]
    closer = pairs[opener]
    depth = 0
    i, n = start, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            q = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q or src[i] == '\n':
                    i += 1
                    break
                i += 1
            continue
        if c == opener:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def split_args(body: str) -> list[str] | None:
    """Top-level comma split. None if the body is unbalanced."""
    out, depth, i, start, n = [], 0, 0, 0, len(body)
    while i < n:
        c = body[i]
        if c in "'\"":
            q = c
            triple = body.startswith(q * 3, i)
            i += 3 if triple else 1
            while i < n:
                if body[i] == '\\':
                    i += 2
                    continue
                if triple and body.startswith(q * 3, i):
                    i += 3
                    break
                if not triple and body[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if body.startswith('//', i):
            j = body.find('\n', i)
            i = n if j < 0 else j
            continue
        if body.startswith('/*', i):
            j = body.find('*/', i)
            i = n if j < 0 else j + 2
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth < 0:
                return None
        elif c == ',' and depth == 0:
            out.append(body[start:i])
            start = i + 1
        i += 1
    tail = body[start:]
    if tail.strip():
        out.append(tail)
    return out


NAMED = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$', re.S)


def parse_args(body: str):
    args = split_args(body)
    if args is None:
        return None
    out = []
    for a in args:
        m = NAMED.match(a)
        if not m:
            return None  # positional arg in a TextStyle: not ours to touch
        out.append((m.group(1), ' '.join(m.group(2).split())))
    return out


# ------------------------------------------------------------- the decision

class Skip(Exception):
    pass


def literal_weight(expr: str) -> int | None:
    m = re.fullmatch(r'FontWeight\.w([1-9])00', expr)
    if m:
        return int(m.group(1)) * 100
    m = re.fullmatch(r'FontWeight\.(bold|normal)', expr)
    if m:
        return WEIGHT_WORDS[m.group(1)]
    return None


def weight_hint(expr: str) -> int:
    """Heaviest weight mentioned anywhere in a non-literal weight expression.

    `active ? FontWeight.w700 : FontWeight.w500` picks its slot from the w700
    branch: the emphasised state is the one whose metrics have to be right, and
    both branches share them anyway.
    """
    found = [int(d) * 100 for d in re.findall(r'FontWeight\.w([1-9])00', expr)]
    if 'FontWeight.bold' in expr:
        found.append(700)
    if 'FontWeight.normal' in expr:
        found.append(400)
    return max(found) if found else 400


def number(expr: str) -> float | None:
    try:
        return float(expr)
    except ValueError:
        return None


def decide(args, receiver: str):
    """(replacement, note) for one TextStyle, or raise Skip(reason)."""
    named = dict(args)
    order = [k for k, _ in args]
    if len(named) != len(order):
        raise Skip('duplicate argument name')
    if 'inherit' in named:
        raise Skip('explicit inherit:')
    if not args:
        raise Skip('empty TextStyle()')

    fam = named.get('fontFamily')
    face, face_changed = 'sans', False
    if fam is not None:
        if fam not in FAMILY_ALIASES:
            raise Skip(f'fontFamily: {fam}')
        face, face_changed = FAMILY_ALIASES[fam]

    size_expr = named.get('fontSize')
    size = None
    if size_expr is not None:
        size = SIZE_ALIASES.get(size_expr, number(size_expr))
        if size is None:
            raise Skip(f'fontSize: {size_expr}')

    # `MlType.code` and `MlType.figure` both set tabular figures, so a literal
    # that asked for them separately is saying the same thing twice.
    if named.get('fontFeatures') in TABULAR and face in ('mono', 'serif'):
        args = [(k, v) for k, v in args if k != 'fontFeatures']
        named = dict(args)
        order = [k for k, _ in args]

    def told(*bits):
        """Merge the review notes for one site into a single reported line."""
        bits = [b for b in bits if b]
        if face_changed:
            bits.insert(0, f'FACE {fam} -> the sanctioned {face}')
        return '; '.join(bits) or None

    w_expr = named.get('fontWeight')
    w_lit = literal_weight(w_expr) if w_expr is not None else None
    w_for_slot = w_lit if w_lit is not None else (
        weight_hint(w_expr) if w_expr is not None else 400)

    rest_keys = [k for k in order
                 if k not in ('fontFamily', 'fontSize', 'fontWeight')]

    # ---- mono: a machine identifier, not a size of text ----
    if face == 'mono':
        allowed = {'color', 'letterSpacing'}
        if any(k not in allowed for k in rest_keys):
            bad = [k for k in rest_keys if k not in allowed]
            raise Skip(f'mono with {bad}')
        if size is None:
            raise Skip('mono without a size')
        parts = []
        if 'color' in named:
            parts.append(f'color: {named["color"]}')
        parts.append(f'size: {_num(size)}')
        # `code` defaults to w600. A literal that wrote no weight meant the
        # ambient regular, so say so — otherwise every timestamp in the app
        # quietly gains a semibold it never had.
        parts.append(f'weight: {w_expr if w_expr is not None else "FontWeight.w400"}')
        if 'letterSpacing' in named:
            parts.append(f'letterSpacing: {named["letterSpacing"]}')
        return f'{receiver}.code({", ".join(parts)})', told()

    # ---- serif: two jobs, split by size ----
    #
    # The design reference gives Fraunces "section titles, AND every large
    # numeral". Below 28 it is a title in every one of this tree's sites (16,
    # 18, 19, 20, 21, 22, 24, 26); at 28 and above it is a hero figure (28, 30,
    # 32, 38, 46). That is the boundary, and it is a fact about the data rather
    # than a guess: `--audit-serif` prints both lists.
    if face == 'serif':
        if size is None:
            raise Skip('serif without a size')

        # Below 14 the serif is neither job: it is the small companion to a
        # numeral — a unit, or an italic sub-label sitting beside a 28px
        # figure. Snapping one of those onto the editorial floor of 16 grows it
        # by a third and detaches it from the figure it belongs to, so these
        # are handed back for a decision rather than guessed at.
        if size < 14:
            raise Skip(f'serif at {_num(size)} — a numeral companion, '
                       f'neither an editorial title nor a figure')

        if size < 28:
            step = min((24, 20, 16), key=lambda s: (abs(s - size), -s))
            slot = {24: 'editorialLarge', 20: 'editorialMedium',
                    16: 'editorialSmall'}[step]
            snote = None if step == size else f'{_num(size)} -> {step}  ({slot})'
            parts = []
            if 'color' in named:
                parts.append(f'color: {named["color"]}')
            if w_expr is not None and w_lit != 500:
                parts.append(f'fontWeight: {w_expr}')
            for k in rest_keys:
                if k == 'color':
                    continue
                if k == 'height':
                    h = number(named[k])
                    want = {24: 32 / 24, 20: 26 / 20, 16: 24 / 16}[step]
                    if h is not None and abs(h - want) <= 0.12:
                        continue
                if k == 'letterSpacing':
                    ls0 = number(named[k])
                    want = {24: -0.2, 20: -0.15, 16: -0.1}[step]
                    if ls0 is not None and abs(ls0 - want) <= 0.15:
                        continue
                parts.append(f'{k}: {named[k]}')
            if not parts:
                return f'{receiver}.{slot}', told(snote)
            return (f'{receiver}.{slot}.copyWith({", ".join(parts)})',
                    told(snote))

        allowed = {'color', 'height'}
        if any(k not in allowed for k in rest_keys):
            bad = [k for k in rest_keys if k not in allowed]
            raise Skip(f'serif figure with {bad}')
        if w_lit is None and w_expr is not None:
            raise Skip('serif with a computed weight')
        parts = []
        if 'color' in named:
            parts.append(f'color: {named["color"]}')
        parts.append(f'size: {_num(size)}')
        if 'height' in named:
            parts.append(f'height: {named["height"]}')
        # `figure` is w500 — Fraunces carries emphasis without going heavier,
        # and only 500/600 are registered. A literal at some other weight was
        # already rendering as one of those two, so say what it becomes.
        wnote = (None if w_lit == 500
                 else 'weight -> w500 (Fraunces display numeral)')
        return f'{receiver}.figure({", ".join(parts)})', told(wnote)

    # ---- sans ----
    if size is None:
        raise Skip('sans without a size')
    if size < 10 or size > 32:
        raise Skip(f'sans at {_num(size)} — outside the scale, decide by hand')

    ls_expr = named.get('letterSpacing')
    ls = number(ls_expr) if ls_expr is not None else None

    # An overline is a slot of its own: 11px, heavy, widely tracked.
    if (size <= 12 and w_for_slot >= 700 and ls is not None and ls >= 0.8
            and set(rest_keys) <= {'color', 'letterSpacing'}):
        col = named.get('color')
        return (f'{receiver}.overline.copyWith(color: {col})' if col
                else f'{receiver}.overline'), told(
            None if size == 11 else f'{_num(size)} -> 11 (overline)')

    step = snap(size)
    slot = (STRONG if w_for_slot >= 600 else REGULAR)[step]
    note = None if step == size else f'{_num(size)} -> {step}  ({slot})'

    slot_size, slot_weight = SLOTS[slot]
    slot_h, slot_ls = METRICS[slot]

    parts = []
    if 'color' in named:
        parts.append(f'color: {named["color"]}')
    if w_expr is not None and (w_lit is None or w_lit != slot_weight):
        parts.append(f'fontWeight: {w_expr}')
    elif w_expr is None and slot_weight != 400 and w_for_slot == 400:
        # No weight was written, so the site meant the ambient regular. A label
        # slot would silently bold it.
        parts.append('fontWeight: FontWeight.w400')

    for k in rest_keys:
        if k == 'color':
            continue
        v = named[k]
        if k == 'height':
            h = number(v)
            # Drop a height that already agrees with the slot's; the whole
            # point is that one line-height decision governs the product.
            if h is not None and abs(h - slot_h) <= 0.12:
                continue
            parts.append(f'height: {v}')
            continue
        if k == 'letterSpacing':
            if ls is not None and abs(ls - slot_ls) <= 0.15:
                continue
            parts.append(f'letterSpacing: {v}')
            continue
        parts.append(f'{k}: {v}')

    if not parts:
        return f'{receiver}.{slot}', told(note)
    return f'{receiver}.{slot}.copyWith({", ".join(parts)})', told(note)


def _num(x: float) -> str:
    return str(int(x)) if float(x).is_integer() else str(x)


# ------------------------------------------------------------------ driving

TYPO_IMPORT = ("import 'package:flutter_application_1/core/design/tokens/"
               "m3/ml_typography.dart';")

# Only imports of the token layer can be made dead by this rewrite: it consumes
# `MlTokens.fontSans`, `MlGlass.display`, `MlAuth.mono` and their siblings, and
# nothing else. Restricting the removal to that directory matters — a general
# unused-import sweep would delete imports whose only use is an EXTENSION
# method, which is never named at the call site. `context.mlText` is itself one.
TOKEN_IMPORT = re.compile(
    r"^import 'package:flutter_application_1/(core/design/tokens/[^']+)';$")

# Top-level names a Dart file exports, near enough for "is this import still
# used". Read from the imported file rather than hardcoded, so adding a token
# class does not quietly break the check.
DECLARES = re.compile(
    r'^(?:abstract\s+)?(?:final\s+|base\s+|sealed\s+|interface\s+)?'
    r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_]\w*)|'
    r'^(?:const|final)\s+(?:[A-Za-z_][\w<>,?\s]*\s+)?([a-zA-Z_]\w*)\s*=',
    re.M)


def exported_names(rel: str) -> set[str] | None:
    try:
        text = open(f'lib/{rel}', encoding='utf-8', errors='replace').read()
    except OSError:
        return None
    return {g for m in DECLARES.finditer(text) for g in m.groups() if g}


def fix_imports(src: str, nl: str) -> str:
    """Add the typography import; drop any that the rewrite made dead."""
    if 'context.mlText' in src and TYPO_IMPORT not in src:
        lines = src.split(nl)
        idx = [i for i, l in enumerate(lines)
               if l.startswith("import 'package:flutter_application_1/")]
        if idx:
            at = next((i for i in idx if lines[i] > TYPO_IMPORT), idx[-1] + 1)
        else:
            pkg = [i for i, l in enumerate(lines) if l.startswith('import ')]
            at = (pkg[-1] + 1) if pkg else 0
        lines.insert(at, TYPO_IMPORT)
        src = nl.join(lines)

    while True:
        lines = src.split(nl)
        for i, line in enumerate(lines):
            m = TOKEN_IMPORT.match(line)
            if not m or 'ml_typography' in line:
                continue
            names = exported_names(m.group(1))
            if not names:
                continue
            body = nl.join(lines[:i] + lines[i + 1:])
            # Comments do not keep an import alive, and a comment naming the
            # class that just stopped being used is exactly what this rewrite
            # leaves behind.
            code = re.sub(r'//[^\n]*|/\*.*?\*/', '', body, flags=re.S)
            if any(re.search(r'\b' + re.escape(n) + r'\b', code)
                   for n in names):
                continue
            src = body
            break
        else:
            return src


def newline_of(src: str) -> str:
    crlf = src.count('\r\n')
    return '\r\n' if crlf and crlf >= src.count('\n') - crlf else '\n'


def wrap(expr: str, column: int, indent: int, nl: str) -> str:
    """One line when it fits in 80 columns, else one argument per line.

    `indent` is the **leading whitespace of the line the expression starts on**,
    not the column the expression starts at — that is what `dart format` indents
    a trailing argument list against, so emitting it this way means the file
    never has to be reformatted wholesale afterwards. Running `dart format` over
    a file this codemod touched churns every unrelated line in it (HANDOFF
    section 5: 131 files once, 106 another).
    """
    if column + len(expr) <= 80:
        return expr
    # The FIRST '(' is the outer call's — the expression is always
    # `receiver.slot.copyWith(…)` or `receiver.code(…)`. Taking the last one
    # instead lands inside an argument such as `MlSemantic.of(context)`, whose
    # body then fails to split and the line silently stays 94 columns wide.
    head, sep, tail = expr.partition('(')
    if not sep or not tail.endswith(')'):
        return expr
    args = split_args(tail[:-1])
    if not args:
        return expr
    pad = ' ' * (indent + 2)
    body = (',' + nl + pad).join(a.strip() for a in args)
    return f'{head}({nl}{pad}{body},{nl}{" " * indent})'


def process(path: str, receiver: str, apply: bool, verbose: bool):
    src = open(path, encoding='utf-8', newline='').read()
    nl = newline_of(src)
    flat = src.replace('\r\n', '\n')
    # Offsets are computed on the raw text, so \r stays put.
    line_starts = [0]
    for i, c in enumerate(src):
        if c == '\n':
            line_starts.append(i + 1)

    def lineno(idx):
        lo, hi = 0, len(line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if line_starts[mid] <= idx:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1

    consts = const_regions(src)
    edits, skips, notes = [], [], []
    for m in re.finditer(TEXT_STYLE, src):
        s = m.end() - 1
        before = src[max(0, m.start() - 8):m.start()]
        if before.rstrip().endswith('const'):
            skips.append((lineno(m.start()), 'const TextStyle('))
            continue
        if any(a <= m.start() < b for a, b in consts):
            skips.append((lineno(m.start()), 'inside a const expression'))
            continue
        e = match_paren(src, s)
        if e < 0:
            skips.append((lineno(m.start()), 'unbalanced'))
            continue
        if 'TextStyle(' in src[s + 1:e]:
            skips.append((lineno(m.start()), 'nested TextStyle'))
            continue
        parsed = parse_args(src[s + 1:e])
        if parsed is None:
            skips.append((lineno(m.start()), 'unparsed arguments'))
            continue
        try:
            repl, note = decide(parsed, receiver)
        except Skip as ex:
            skips.append((lineno(m.start()), str(ex)))
            continue
        ls = line_starts[lineno(m.start()) - 1]
        head = src[ls:m.start()]
        indent = len(head) - len(head.lstrip())
        edits.append((m.start(), e + 1, wrap(repl, len(head), indent, nl),
                      lineno(m.start())))
        if note:
            notes.append((lineno(m.start()), note))

    if verbose:
        print(f'\n=== {path}')
        for ln, note in notes:
            print(f'  SIZE  {ln:5d}  {note}')
        for ln, why in skips:
            print(f'  SKIP  {ln:5d}  {why}')
        print(f'  {len(edits)} rewritten, {len(skips)} skipped, '
              f'{len(notes)} size changes')

    if apply and edits:
        out = []
        prev = 0
        for a, b, repl, _ in edits:
            out.append(src[prev:a])
            out.append(repl)
            prev = b
        out.append(src[prev:])
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(fix_imports(''.join(out), nl))
    return len(edits), len(skips), len(notes)


def stats():
    rows = []
    for f in glob.glob('lib/**/*.dart', recursive=True):
        f = f.replace('\\', '/')
        if excluded(f):
            continue  # the scale defines itself in raw TextStyles, by design
        s = open(f, encoding='utf-8', errors='replace', newline='').read()
        fam = len(re.findall(r'fontFamily:\s*MlTokens\.font', s))
        size = len(re.findall(r'fontSize:\s*[0-9]', s))
        if fam or size:
            rows.append((fam * 2 + size * 2, f, fam, size))
    rows.sort(reverse=True)
    for r in rows[:40]:
        print(f'{r[0]:5d}  {r[1]}   fam={r[2]} size={r[3]}')
    print(f'\n{len(rows)} files  '
          f'fontFamily={sum(r[2] for r in rows)}  '
          f'fontSize={sum(r[3] for r in rows)}')


def audit_serif():
    """Every Fraunces site and its size, so the 28px boundary stays a fact.

    The serif does two jobs — section titles and hero numerals — and the split
    between them is by size. If a title ever appears at 30, or a numeral at 20,
    this is what says so.
    """
    faces = [k for k, (f, _) in FAMILY_ALIASES.items() if f == 'serif']
    pat = re.compile(r'fontFamily:\s*(' + '|'.join(re.escape(f) for f in faces)
                     + r')')
    small, big, other = [], [], []
    for path in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        n = path.replace(os.sep, '/')
        if excluded(n):
            continue
        src = open(path, encoding='utf-8', errors='replace', newline='').read()
        for m in re.finditer(TEXT_STYLE, src):
            e = match_paren(src, m.end() - 1)
            if e < 0:
                continue
            body = src[m.end():e]
            if not pat.search(body):
                continue
            ln = src[:m.start()].count('\n') + 1
            fs = re.search(r'fontSize:\s*([A-Za-z0-9_.]+)', body)
            raw = fs.group(1) if fs else None
            val = SIZE_ALIASES.get(raw, number(raw)) if raw else None
            row = f'{n}:{ln}  {raw}'
            (other if val is None else (big if val >= 28 else small)).append(row)
    for title, rows in (('TITLES (< 28 -> editorial*)', small),
                        ('FIGURES (>= 28 -> figure())', big),
                        ('UNDECIDABLE (size is not a literal)', other)):
        print(f'\n{title}  [{len(rows)}]')
        for r in rows:
            print(f'  {r}')


def selftest() -> int:
    """The slot table here must not drift from the one the app renders."""
    src = open('lib/core/design/tokens/m3/ml_typography.dart',
               encoding='utf-8', errors='replace').read()
    bad = 0
    for slot, (size, weight) in SLOTS.items():
        m = re.search(slot + r':\s*TextStyle\((.*?)\n\s*\),', src, re.S)
        if not m:
            print(f'FAIL  {slot}: not found in ml_typography.dart')
            bad += 1
            continue
        body = m.group(1)
        fs = re.search(r'fontSize:\s*([0-9.]+)', body)
        fw = re.search(r'fontWeight:\s*FontWeight\.w([1-9])00', body)
        if not fs or float(fs.group(1)) != size:
            print(f'FAIL  {slot}: size {fs and fs.group(1)} != {size}')
            bad += 1
        if not fw or int(fw.group(1)) * 100 != weight:
            print(f'FAIL  {slot}: weight {fw and fw.group(1)} != {weight}')
            bad += 1
    # And the snapper must round ties up.
    for got, want in ((13, 14), (19, 22), (10, 11), (15, 16), (18, 16),
                      (20, 22), (26, 28), (30, 32), (17, 16), (23, 24)):
        if snap(got) != want:
            print(f'FAIL  snap({got}) = {snap(got)}, expected {want}')
            bad += 1

    # The editorial rungs, and the line box each one borrows.
    for slot, size, height in (('editorialLarge', 24, '32 / 24'),
                               ('editorialMedium', 20, '26 / 20'),
                               ('editorialSmall', 16, '24 / 16')):
        m = re.search(slot + r'\s*=>\s*\n?\s*MlTypeScale\.editorial\('
                      r'([0-9.]+),\s*([0-9 /.]+?),', src, re.S)
        if not m:
            print(f'FAIL  {slot}: not found in ml_typography.dart')
            bad += 1
            continue
        if float(m.group(1)) != size or m.group(2).strip() != height:
            print(f'FAIL  {slot}: {m.group(1)} / {m.group(2).strip()} '
                  f'!= {size} / {height}')
            bad += 1

    # A rewrite of each shape, end to end. These are the four the tool emits.
    cases = [
        ("fontFamily: MlTokens.fontSans, fontSize: 13, fontWeight: "
         "FontWeight.w700, color: c",
         'context.mlText.titleSmall.copyWith(color: c, '
         'fontWeight: FontWeight.w700)'),
        ("fontFamily: MlTokens.fontMono, fontSize: 11, color: c",
         'context.mlText.code(color: c, size: 11, weight: FontWeight.w400)'),
        ("fontFamily: MlGlass.display, fontSize: 21, color: c",
         'context.mlText.editorialMedium.copyWith(color: c)'),
        ("fontFamily: MlTokens.fontSerif, fontSize: 30, color: c",
         'context.mlText.figure(color: c, size: 30)'),
        ("fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, "
         "color: c",
         'context.mlText.overline.copyWith(color: c)'),
    ]
    for body, want in cases:
        got, _ = decide(parse_args(body), 'context.mlText')
        if got != want:
            print(f'FAIL  {body}\n        got  {got}\n        want {want}')
            bad += 1

    # A prefixed TextStyle is somebody else's class. `pw.TextStyle` is the pdf
    # package's, in files composed off-screen with no BuildContext anywhere.
    for src_text, want in ((' TextStyle(', 1), ('pw.TextStyle(', 0),
                           ('x.TextStyle(', 0), ('MyTextStyle(', 0),
                           ('\nTextStyle(', 1), ('const TextStyle(', 1)):
        got = len(TEXT_STYLE.findall(src_text))
        if got != want:
            print(f'FAIL  TEXT_STYLE matched {got} in {src_text!r}, '
                  f'expected {want}')
            bad += 1

    # And the refusals must still refuse.
    for body in ("fontFamily: MlTokens.fontSerif, fontSize: MlTokens.fsLabel, "
                 "fontStyle: FontStyle.italic, color: c",
                 "fontFamily: MlTokens.fontSans, fontSize: size * 0.36, "
                 "color: c",
                 "fontFamily: 'Inter', fontSize: 14, color: c"):
        try:
            decide(parse_args(body), 'context.mlText')
        except Skip:
            continue
        print(f'FAIL  should have been skipped: {body}')
        bad += 1
    print('selftest: ' + ('OK' if not bad else f'{bad} failures'))
    return 1 if bad else 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--report', nargs='*', metavar='FILE')
    p.add_argument('--apply', nargs='*', metavar='FILE')
    p.add_argument('--receiver', default='context.mlText')
    p.add_argument('--stats', action='store_true')
    p.add_argument('--audit-serif', action='store_true')
    p.add_argument('--selftest', action='store_true')
    a = p.parse_args()

    if a.selftest:
        sys.exit(selftest())
    if a.audit_serif:
        audit_serif()
        return
    if a.stats:
        stats()
        return
    targets = a.apply or a.report or []
    files = []
    for t in targets:
        files.extend(sorted(glob.glob(t, recursive=True)) if '*' in t else [t])
    if not files:
        p.print_help()
        return
    tot = [0, 0, 0]
    for f in files:
        if not os.path.exists(f):
            print(f'missing: {f}')
            continue
        if excluded(f):
            print(f'\n=== {f}\n  HELD BACK  this file defines the scale; '
                  f'see NEVER in this tool')
            continue
        r = process(f, a.receiver, apply=bool(a.apply), verbose=True)
        tot = [x + y for x, y in zip(tot, r)]
    print(f'\nTOTAL  {tot[0]} rewritten, {tot[1]} skipped, {tot[2]} size changes')


if __name__ == '__main__':
    main()

# Phase 3 helpers (copied into the repo 2026-08-23 so no scratchpad has to be found)

Run every one with `py -3` and `PYTHONIOENCODING=utf-8`. None of them is part of the gate.

| file | what it does |
|---|---|
| `mypatch.py` | `patch(rel, [(old, new, count), ...])` — exact-string patching that matches the file's own line endings (this repo is mixed LF/CRLF). Import it: `PYTHONPATH=tool/phase3_helpers py -3 - <<EOF` … `from mypatch import patch`. Asserts the exact occurrence count, so a stale anchor fails loudly instead of patching the wrong place. |
| `mypair.py` | `mypair.py <render-rel-path> x0 y0 x1 y1 <out.png>` — the HEAD version of a golden beside the working copy, cropped, so a change can be LOOKED at. |
| `golden_diff.py` | for every modified golden under `docs/redesign/renders/`, prints the bounding box and changed-pixel count and writes a side-by-side crop **next to itself** — so run it from a scratch directory (copy it there), not from here. |
| `fix_eol.py` | puts back the line endings of every modified file to what `git show HEAD:<path>` has; run before every commit. |
| `cdp.py`, `setfile.py`, `takepic.py`, `attach_photos.py`, `hover.py`, `emulate.py` | the browser driver (HANDOFF.md §5) — Chrome DevTools over port 9222/9223. Not used this session. |

The reviewer agents' reports from 2026-08-23 are in `docs/redesign/reviews/2026-08-23-phase3/`.

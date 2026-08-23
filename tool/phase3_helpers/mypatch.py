"""Line-ending-aware exact-string patching. Import and call patch(rel, [(old, new, count), ...]).

WRITES VIA A TEMP FILE AND A RENAME, and does so because the naive version
destroyed a source file on 2026-08-23. `io.open(p, 'w')` TRUNCATES the target
the moment it is called; the encode happens afterwards, on `.write()`. A patch
carrying an unpaired surrogate (a `\\ud83d\\udea8` escape for an emoji, written
that way to keep the patch script pure ASCII) therefore emptied
`ml_status_badge.dart` to zero bytes and only then raised
`UnicodeEncodeError`. The file was recoverable from HEAD, but a file that had
uncommitted work in it would not have been.

Two smaller lessons from the same minute, both worth keeping:

  * `flutter analyze` reports "No issues found!" for a ZERO-BYTE Dart file. An
    empty file is valid Dart. Analyze passing is not evidence that a file
    still has anything in it.
  * write the emoji itself, not a surrogate escape. Python source is UTF-8.
"""
import io
import os

ROOT = r"C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3"


def patch(rel, pairs):
    p = ROOT + "\\" + rel.replace('/', '\\')
    s = io.open(p, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'
    for old, new, c in pairs:
        o = old.replace('\r\n', '\n').replace('\n', nl)
        n = new.replace('\r\n', '\n').replace('\n', nl)
        assert s.count(o) == c, (rel, old[:70], s.count(o), c)
        s = s.replace(o, n)

    # Encode BEFORE touching the target, so a bad character cannot truncate it.
    data = s.encode('utf-8')
    tmp = p + '.mypatch-tmp'
    with open(tmp, 'wb') as fh:
        fh.write(data)
    os.replace(tmp, p)
    print('patched', rel)

"""Undo the CRLF churn a text-mode Python write introduced.

`io.open(p, 'w')` on Windows translates '\n' to '\r\n'. This repo stores LF and
sets `core.autocrlf=false`, so a round-trip through that call rewrites every
line of the file and buries the real change. For each modified file, compare
the byte-level line endings against HEAD and put the working copy back on the
same footing.
"""
import subprocess, sys, os

ROOT = r"C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3"

out = subprocess.run(["git", "diff", "--name-only"], cwd=ROOT,
                     capture_output=True, text=True).stdout.split("\n")
fixed = []
for rel in [r.strip() for r in out if r.strip()]:
    if rel.endswith(".png"):
        continue
    head = subprocess.run(["git", "show", "HEAD:" + rel], cwd=ROOT,
                          capture_output=True).stdout
    path = os.path.join(ROOT, rel.replace("/", os.sep))
    with open(path, "rb") as fh:
        work = fh.read()
    head_crlf = b"\r\n" in head
    work_crlf = b"\r\n" in work
    if head_crlf == work_crlf:
        continue
    if work_crlf and not head_crlf:
        with open(path, "wb") as fh:
            fh.write(work.replace(b"\r\n", b"\n"))
        fixed.append((rel, "CRLF -> LF"))
    elif head_crlf and not work_crlf:
        with open(path, "wb") as fh:
            fh.write(work.replace(b"\n", b"\r\n"))
        fixed.append((rel, "LF -> CRLF"))

for rel, what in fixed:
    print("%-60s %s" % (rel, what))
print("%d file(s) renormalised" % len(fixed))

"""For each modified golden, compare the HEAD version with the working copy:
print the bounding box of every differing pixel, and write a crop of the new
image around that box (so the change can be LOOKED at), plus a side-by-side.
"""
import io, os, subprocess, sys
from PIL import Image, ImageChops

ROOT = r"C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3"
OUT = os.path.dirname(os.path.abspath(__file__))

files = subprocess.check_output(
    ["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines()
files = [l[3:].strip() for l in files if l.startswith(" M") and l.endswith(".png")]

for rel in files:
    old = subprocess.check_output(["git", "show", f"HEAD:{rel}"], cwd=ROOT)
    a = Image.open(io.BytesIO(old)).convert("RGB")
    b = Image.open(os.path.join(ROOT, rel)).convert("RGB")
    name = os.path.basename(rel)[:-4]
    if a.size != b.size:
        print(f"{name}: SIZE {a.size} -> {b.size}")
        continue
    diff = ImageChops.difference(a, b)
    box = diff.getbbox()
    n = sum(1 for p in diff.getdata() if p != (0, 0, 0))
    print(f"{name}: {a.size} bbox={box} changed_px={n}")
    if box:
        x0, y0, x1, y1 = box
        pad = 40
        crop = (max(0, x0 - pad), max(0, y0 - pad), min(a.width, x1 + pad), min(a.height, y1 + pad))
        ca, cb = a.crop(crop), b.crop(crop)
        side = Image.new("RGB", (ca.width * 2 + 10, ca.height), (255, 0, 255))
        side.paste(ca, (0, 0)); side.paste(cb, (ca.width + 10, 0))
        side.save(os.path.join(OUT, f"gd_{name}.png"))

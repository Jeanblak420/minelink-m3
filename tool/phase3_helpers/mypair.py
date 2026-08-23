"""mypair.py <render-rel-path> x0 y0 x1 y1 <out.png> — HEAD version beside the working copy, cropped."""
import io, os, subprocess, sys
from PIL import Image
R = r"C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3"
rel = sys.argv[1]; box = tuple(map(int, sys.argv[2:6])); out = sys.argv[6]
old = Image.open(io.BytesIO(subprocess.check_output(['git', 'show', 'HEAD:' + rel], cwd=R))).convert('RGB').crop(box)
new = Image.open(os.path.join(R, rel)).convert('RGB').crop(box)
o = Image.new('RGB', (old.width * 2 + 10, old.height), (255, 0, 255))
o.paste(old, (0, 0)); o.paste(new, (old.width + 10, 0)); o.save(out); print(out, o.size)

"""Line-ending-aware exact-string patching. Import and call patch(rel, [(old, new, count), ...])."""
import io
ROOT = r"C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3"

def patch(rel, pairs):
    p = ROOT + "\\" + rel
    s = io.open(p, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in s else '\n'
    for old, new, c in pairs:
        o = old.replace('\r\n', '\n').replace('\n', nl)
        n = new.replace('\r\n', '\n').replace('\n', nl)
        assert s.count(o) == c, (rel, old[:70], s.count(o), c)
        s = s.replace(o, n)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('patched', rel)

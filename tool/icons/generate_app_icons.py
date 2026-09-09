#!/usr/bin/env python3
"""Regenerate every app icon in this repo from one source image.

    py -3 tool/icons/generate_app_icons.py

Source of truth: ``tool/icons/minelink_chain_source.png`` — the gold-and-white
chain link, supplied by Jean on 2026-08-23, already alpha-cut.

Why the icons are not simply that PNG dropped in at N sizes:

* **The lower link is white.** On a transparent backing it vanishes against a
  white browser tab or a light launcher wallpaper. Every target therefore gets
  an opaque backing in ``#0A1424`` — MineLink navy, which is already what
  ``web/manifest.json`` declares as the app's ``background_color`` and
  ``theme_color``, so nothing new is being invented here.
* **iOS forbids alpha in app icons** (App Store rejects them outright), so the
  iOS set is written as RGB with no alpha channel at all.
* **A maskable icon is cropped to a circle** of 80% diameter by the platform,
  so its artwork sits in a smaller safe zone than the ordinary icons.
* **Android 8+ masks a legacy icon onto its own backdrop**, which would put the
  navy tile inside a white circle. The adaptive icon (``mipmap-anydpi-v26``)
  exists so that does not happen; the legacy PNGs stay for pre-26 devices.

Everything is downsampled with LANCZOS from a 2048px master so the 16px and
32px variants stay legible.
"""

from __future__ import annotations

import glob
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "tool", "icons", "minelink_chain_source.png")

NAVY = (10, 20, 36)  # #0A1424 — web/manifest.json background_color / theme_color
MASTER = 2048
RADIUS_FRAC = 0.2237  # Apple's squircle radius, used for every rounded tile


def _load_art() -> Image.Image:
    """The chain, trimmed to its own ink."""
    art = Image.open(SOURCE).convert("RGBA")
    box = art.split()[3].getbbox()
    return art.crop(box) if box else art


ART = _load_art()


def _place(canvas: Image.Image, box: tuple[int, int, int, int], content_frac: float) -> None:
    """Scale the chain to ``content_frac`` of ``box``'s shorter side and centre it."""
    bx0, by0, bx1, by1 = box
    bw, bh = bx1 - bx0, by1 - by0
    target = min(bw, bh) * content_frac
    scale = target / max(ART.width, ART.height)
    w, h = max(1, round(ART.width * scale)), max(1, round(ART.height * scale))
    art = ART.resize((w, h), Image.LANCZOS)
    canvas.alpha_composite(art, (bx0 + (bw - w) // 2, by0 + (bh - h) // 2))


def master_rounded(content_frac: float = 0.68) -> Image.Image:
    """Navy rounded square, transparent outside the corners."""
    img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (0, 0, MASTER - 1, MASTER - 1), radius=round(MASTER * RADIUS_FRAC), fill=NAVY + (255,)
    )
    _place(img, (0, 0, MASTER, MASTER), content_frac)
    return img


def master_square(content_frac: float) -> Image.Image:
    """Navy full-bleed square — no rounding, fully opaque."""
    img = Image.new("RGBA", (MASTER, MASTER), NAVY + (255,))
    _place(img, (0, 0, MASTER, MASTER), content_frac)
    return img


def master_macos(content_frac: float = 0.66) -> Image.Image:
    """macOS wants the art inset inside the canvas, not full-bleed."""
    img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    inset = round(MASTER * 0.10)
    tile = (inset, inset, MASTER - inset - 1, MASTER - inset - 1)
    ImageDraw.Draw(img).rounded_rectangle(
        tile, radius=round((tile[2] - tile[0]) * RADIUS_FRAC), fill=NAVY + (255,)
    )
    _place(img, (tile[0], tile[1], tile[2] + 1, tile[3] + 1), content_frac)
    return img


def master_adaptive_foreground() -> Image.Image:
    """Android adaptive foreground: art only, no backing.

    0.53 is not a guess. Google guarantees only the inner **66dp** circle of the
    108dp foreground survives every launcher mask, and the chain is diagonal, so
    what matters is the radius of its furthest *ink*, not its bounding box. At
    0.53 that radius measures 33dp — exactly the 66dp circle, so no mask can
    clip a link. (0.55 measured 34.1dp, inside the 72dp viewport but outside the
    guarantee.) ``--check`` re-measures this.
    """
    img = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    _place(img, (0, 0, MASTER, MASTER), 0.53)
    return img


def write(master: Image.Image, path: str, size: int, *, rgb: bool = False) -> None:
    out = master.resize((size, size), Image.LANCZOS)
    if rgb:
        flat = Image.new("RGB", out.size, NAVY)
        flat.paste(out, mask=out.split()[3])
        out = flat
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    out.save(full)
    print(f"  {path}  {size}x{size}{' (RGB, no alpha)' if rgb else ''}")


def check() -> int:
    """Re-assert the three rules a platform will actually reject us for."""
    import math

    fails = []

    for path in sorted(glob.glob(os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png"))):
        if Image.open(path).mode != "RGB":
            fails.append(f"iOS icon carries an alpha channel: {os.path.basename(path)}")
    print(f"  iOS: 15 icons, no alpha channel .......... {'FAIL' if fails else 'ok'}")

    for name in ("Icon-maskable-192.png", "Icon-maskable-512.png"):
        alpha = Image.open(os.path.join(ROOT, "web/icons", name)).convert("RGBA").split()[3]
        if alpha.getextrema()[0] != 255:
            fails.append(f"maskable icon is not fully opaque: {name}")
    print(f"  web: maskable icons fully opaque ......... {'FAIL' if fails else 'ok'}")

    fg = Image.open(
        os.path.join(ROOT, "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png")
    ).convert("RGBA")
    size, alpha = fg.width, fg.split()[3].load()
    centre = (size - 1) / 2
    reach = max(
        (math.hypot(x - centre, y - centre) for y in range(size) for x in range(size) if alpha[x, y] > 16),
        default=0.0,
    )
    reach_dp = reach / size * 108 * 2
    if reach_dp > 66.0:
        fails.append(f"adaptive foreground ink spans {reach_dp:.1f}dp, past the 66dp guarantee")
    print(f"  android: adaptive ink {reach_dp:5.1f}dp of 66dp ... {'FAIL' if reach_dp > 66 else 'ok'}")

    for f in fails:
        print(f"  ! {f}")
    return 1 if fails else 0


def main() -> None:
    rounded = master_rounded()
    ios = master_square(0.66)
    maskable = master_square(0.56)
    macos = master_macos()
    adaptive = master_adaptive_foreground()

    print("web/")
    write(rounded, "web/favicon.png", 32)
    write(rounded, "web/icons/Icon-192.png", 192)
    write(rounded, "web/icons/Icon-512.png", 512)
    write(maskable, "web/icons/Icon-maskable-192.png", 192)
    write(maskable, "web/icons/Icon-maskable-512.png", 512)

    print("android/ (legacy launcher PNGs, 48dp)")
    for bucket, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        write(rounded, f"android/app/src/main/res/mipmap-{bucket}/ic_launcher.png", px)

    print("android/ (adaptive foreground, 108dp)")
    for bucket, px in (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)):
        write(adaptive, f"android/app/src/main/res/mipmap-{bucket}/ic_launcher_foreground.png", px)

    print("ios/  (RGB — alpha is not permitted in iOS app icons)")
    for name, px in (
        ("20x20@1x", 20), ("20x20@2x", 40), ("20x20@3x", 60),
        ("29x29@1x", 29), ("29x29@2x", 58), ("29x29@3x", 87),
        ("40x40@1x", 40), ("40x40@2x", 80), ("40x40@3x", 120),
        ("60x60@2x", 120), ("60x60@3x", 180),
        ("76x76@1x", 76), ("76x76@2x", 152),
        ("83.5x83.5@2x", 167),
        ("1024x1024@1x", 1024),
    ):
        write(ios, f"ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{name}.png", px, rgb=True)

    print("macos/")
    for px in (16, 32, 64, 128, 256, 512, 1024):
        write(macos, f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png", px)

    print("windows/")
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    ico_path = os.path.join(ROOT, "windows", "runner", "resources", "app_icon.ico")
    rounded.resize((256, 256), Image.LANCZOS).save(ico_path, format="ICO", sizes=ico_sizes)
    print(f"  windows/runner/resources/app_icon.ico  {', '.join(f'{w}' for w, _ in ico_sizes)}")


if __name__ == "__main__":
    if "--check" in sys.argv:
        print("checking generated icons")
        raise SystemExit(check())
    main()
    print()
    print("checking generated icons")
    raise SystemExit(check())

#!/usr/bin/env python3
"""Build assets/AppIcon.icns from the rendered artwork.

    scripts/make-icon.py body.png        # body.png: 824x824 render of assets/icon/icon.html

Follows the macOS icon grid: 1024 canvas, 824 body centred, continuous-corner squircle, soft drop shadow.
"""
import subprocess, sys, tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
CANVAS, BODY = 1024, 824
SS = 4  # supersampling for the mask edge


def squircle_mask(size: int, ss: int = SS) -> Image.Image:
    """macOS icon body: rounded square with ~22.4% corner radius (Big Sur grid), antialiased by supersampling."""
    big = size * ss
    m = Image.new("L", (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, big - 1, big - 1), radius=round(big * 0.2237), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def main():
    body = Image.open(sys.argv[1]).convert("RGBA").resize((BODY, BODY), Image.LANCZOS)
    mask = squircle_mask(BODY)

    # subtle inner rim: lighter top edge, darker bottom edge (gives the glassy depth of Big Sur icons)
    rim = Image.new("RGBA", (BODY, BODY), (0, 0, 0, 0))
    inner = mask.filter(ImageFilter.GaussianBlur(10))
    edge = ImageChops.subtract(mask, inner)
    top = Image.linear_gradient("L").rotate(180).resize((BODY, BODY))          # white at top
    light = Image.new("RGBA", (BODY, BODY), (255, 255, 255, 0))
    light.putalpha(ImageChops.multiply(edge, top).point(lambda v: int(v * 0.55)))
    dark = Image.new("RGBA", (BODY, BODY), (0, 40, 70, 0))
    dark.putalpha(ImageChops.multiply(edge, ImageChops.invert(top)).point(lambda v: int(v * 0.35)))
    body = Image.alpha_composite(Image.alpha_composite(body, light), dark)
    body.putalpha(mask)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    off = (CANVAS - BODY) // 2
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sh = Image.new("L", (CANVAS, CANVAS), 0)
    sh.paste(mask, (off, off + 12))
    shadow.putalpha(sh.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.45)))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(body, (off, off))

    out_png = ROOT / "assets" / "icon" / "AppIcon-1024.png"
    canvas.save(out_png)
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for pt in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                px = pt * scale
                name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
                canvas.resize((px, px), Image.LANCZOS).save(iconset / name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ROOT / "assets" / "AppIcon.icns")], check=True)
    print("wrote", out_png, "and assets/AppIcon.icns")


if __name__ == "__main__":
    main()

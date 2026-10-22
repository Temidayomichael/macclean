#!/usr/bin/env python3
"""Draws the MacClean app icon and writes Resources/AppIcon.icns and AppIcon.png.

Only needs Pillow (pip install pillow). The .icns is assembled by hand from
PNG-encoded entries, so it works on Linux as well as macOS.
"""
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "Resources"

CANVAS = 1024
SS = 4  # supersampling factor for smooth edges

# macOS icon grid: the rounded square covers 824 of the 1024 canvas.
SHAPE = 824
RADIUS = 185

TOP = (56, 189, 248)      # sky blue
BOTTOM = (37, 99, 235)    # deep blue


def gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        px_row = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = px_row
    return img


def rounded_mask(size, shape, radius):
    mask = Image.new("L", (size, size), 0)
    off = (size - shape) // 2
    ImageDraw.Draw(mask).rounded_rectangle(
        [off, off, off + shape, off + shape], radius=radius, fill=255
    )
    return mask


def sparkle(cx, cy, r, points=240):
    """Four-pointed star with concave sides (an astroid)."""
    pts = []
    for i in range(points):
        t = 2 * math.pi * i / points
        pts.append((cx + r * math.cos(t) ** 3, cy + r * math.sin(t) ** 3))
    return pts


def draw_icon():
    size = CANVAS * SS
    shape = SHAPE * SS
    radius = RADIUS * SS
    off = (size - shape) // 2

    # Background: gradient clipped to the rounded square.
    bg = gradient(size, TOP, BOTTOM)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(bg, (0, 0), rounded_mask(size, shape, radius))

    # Soft highlight in the upper left for a little depth.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [off - shape * 0.2, off - shape * 0.45, off + shape * 0.9, off + shape * 0.55],
        fill=(255, 255, 255, 60),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(shape * 0.08))
    glow.putalpha(Image.composite(glow.getchannel("A"), Image.new("L", (size, size), 0),
                                  rounded_mask(size, shape, radius)))
    icon.alpha_composite(glow)

    # Sparkles: one large, two small, with a soft shadow under the large one.
    cx, cy = size / 2, size / 2
    big = sparkle(cx - shape * 0.04, cy + shape * 0.04, shape * 0.30)
    small1 = sparkle(cx + shape * 0.25, cy - shape * 0.24, shape * 0.10)
    small2 = sparkle(cx + shape * 0.30, cy + shape * 0.22, shape * 0.065)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon(
        [(x, y + shape * 0.02) for x, y in big], fill=(0, 40, 120, 90)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shape * 0.02))
    icon.alpha_composite(shadow)

    stars = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(stars)
    for poly in (big, small1, small2):
        d.polygon(poly, fill=(255, 255, 255, 255))
    icon.alpha_composite(stars)

    return icon.resize((CANVAS, CANVAS), Image.LANCZOS)


# ICNS entry types that accept PNG data, by pixel size.
ICNS_TYPES = {
    16: b"icp4",
    32: b"icp5",
    64: b"icp6",
    128: b"ic07",
    256: b"ic08",
    512: b"ic09",
    1024: b"ic10",
}


def write_icns(icon, path):
    entries = b""
    for px, kind in ICNS_TYPES.items():
        from io import BytesIO
        buf = BytesIO()
        icon.resize((px, px), Image.LANCZOS).save(buf, format="PNG", optimize=True)
        data = buf.getvalue()
        entries += kind + struct.pack(">I", 8 + len(data)) + data
    with open(path, "wb") as f:
        f.write(b"icns" + struct.pack(">I", 8 + len(entries)) + entries)


def main():
    OUT_DIR.mkdir(exist_ok=True)
    icon = draw_icon()
    icon.save(OUT_DIR / "AppIcon.png", format="PNG", optimize=True)
    write_icns(icon, OUT_DIR / "AppIcon.icns")
    print(f"Wrote {OUT_DIR / 'AppIcon.png'} and {OUT_DIR / 'AppIcon.icns'}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Makes App/Resources/AppIcon.icns from the envelope tile of the AMS Icon Library.

A Mac icon: a rounded tile (824 of 1024, corner 176, as in AMS Mic Check) in the app's own blue,
with the white hand-drawn envelope. Run: python3 Tools/make_icon.py
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIBRARY = os.path.expanduser("~/Documents/01 Leisure/30 App Development/AMS Icon Library")
BLUE = (10, 92, 196)          # the blue of the menu bar envelope while new mail waits
TILE, INSET, CORNER = 1024, 100, 176

source = Image.open(os.path.join(LIBRARY, "png/app-icon/envelope-1024.png")).convert("RGB")
# The library tile is white on #2f6fe0: how white a pixel is gives the glyph.
red = source.split()[0]
glyph = red.point(lambda v: max(0, min(255, round((v - 47) * 255 / (255 - 47)))))
side = TILE - 2 * INSET
glyph = glyph.resize((side, side), Image.LANCZOS)

big = 4
shape = Image.new("L", (TILE * big, TILE * big), 0)
ImageDraw.Draw(shape).rounded_rectangle(
    [INSET * big, INSET * big, (TILE - INSET) * big - 1, (TILE - INSET) * big - 1], radius=CORNER * big, fill=255)
shape = shape.resize((TILE, TILE), Image.LANCZOS)

icon = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
icon.paste(Image.new("RGBA", (TILE, TILE), BLUE + (255,)), (0, 0), shape)
white = Image.new("RGBA", (side, side), (255, 255, 255, 255))
icon.paste(white, (INSET, INSET), glyph)

with tempfile.TemporaryDirectory() as folder:
    iconset = os.path.join(folder, "AppIcon.iconset")
    os.mkdir(iconset)
    for points in (16, 32, 128, 256, 512):
        icon.resize((points, points), Image.LANCZOS).save(os.path.join(iconset, f"icon_{points}x{points}.png"))
        icon.resize((points * 2, points * 2), Image.LANCZOS).save(os.path.join(iconset, f"icon_{points}x{points}@2x.png"))
    out = os.path.join(HERE, "App/Resources/AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
    if len(sys.argv) > 1:
        icon.save(sys.argv[1])
print("made", out)

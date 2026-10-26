#!/usr/bin/env python3
"""Draws the placeholder app icon (a glossy bubble on a night sky) with Pillow."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Popcorn" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"


def main():
    size = 1024
    img = Image.new("RGB", (size, size), "#0F1B3D")
    draw = ImageDraw.Draw(img)
    for y in range(size):
        k = y / size
        r = int(0x0F + (0x7F - 0x0F) * k)
        g = int(0x1B + (0xB2 - 0x1B) * k)
        b = int(0x3D + (0xE5 - 0x3D) * k)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    # Big bubble
    cx, cy, rad = 512, 540, 330
    for i in range(rad, 0, -2):
        k = i / rad
        col = (int(0xB0 * (1 - k) + 0xE8 * k), int(0x84 * (1 - k) + 0xD8 * k), int(0xF5 * (1 - k) + 0xFF * k))
        ox, oy = int(-60 * (1 - k)), int(-70 * (1 - k))
        draw.ellipse([cx - i + ox, cy - i + oy, cx + i + ox, cy + i + oy], fill=col)
    draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline="#4B2E83", width=14)
    draw.ellipse([cx - 190, cy - 270, cx - 10, cy - 170], fill=(255, 255, 255, 200))
    # Harpoon line
    draw.line([(cx, size - 40), (cx, cy + rad - 40)], fill="#FFF3B0", width=22)
    draw.polygon([(cx - 50, cy + rad), (cx, cy + rad - 70), (cx + 50, cy + rad)], fill="#FFF3B0")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()

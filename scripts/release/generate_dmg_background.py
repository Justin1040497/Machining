#!/usr/bin/env python3
"""Generate a professional DMG background image for FrameLean.

Requires: pip install Pillow
Output: A PNG background image for use with dmgbuild.

Colors are derived from FrameLean's light theme palette
(lib/app/theme/framelean_colors.dart).
"""

import os
import sys


# FrameLean light theme colors
PRIMARY = (0x1D, 0x48, 0xE6)          # #1D48E6
PRIMARY_SOFT = (0xE9, 0xEE, 0xFF)     # #E9EEFF
SURFACE_CANVAS = (0xF5, 0xF7, 0xFB)   # #F5F7FB
SURFACE = (0xFF, 0xFF, 0xFF)          # #FFFFFF
BORDER = (0xE2, 0xE6, 0xEE)           # #E2E6EE
TEXT_SECONDARY = (0x5F, 0x68, 0x78)   # #5F6878


def generate(output_path, width=660, height=400):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print(
            "error: Pillow is not installed. Run: pip install Pillow",
            file=sys.stderr,
        )
        sys.exit(1)

    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # --- Background: surfaceCanvas with subtle gradient to white ---
    for y in range(height):
        ratio = y / height
        r = int(SURFACE_CANVAS[0] + (SURFACE[0] - SURFACE_CANVAS[0]) * ratio)
        g = int(SURFACE_CANVAS[1] + (SURFACE[1] - SURFACE_CANVAS[1]) * ratio)
        b = int(SURFACE_CANVAS[2] + (SURFACE[2] - SURFACE_CANVAS[2]) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # --- Subtle border rect ---
    margin = 16
    draw.rounded_rectangle(
        [margin, margin, width - margin, height - margin],
        radius=12,
        outline=BORDER + (120,),
        width=1,
    )

    # --- Arrow: left (app icon) to right (Applications) ---
    arrow_y = height // 2 - 8
    arrow_start_x = 240
    arrow_end_x = width - 240

    # Glow / soft track under the arrow
    draw.line(
        [(arrow_start_x - 4, arrow_y), (arrow_end_x - 4, arrow_y)],
        fill=PRIMARY_SOFT + (180,),
        width=20,
    )
    # Arrow shaft
    draw.line(
        [(arrow_start_x, arrow_y), (arrow_end_x - 12, arrow_y)],
        fill=PRIMARY + (220,),
        width=3,
    )
    # Arrow head
    head = 10
    draw.polygon(
        [
            (arrow_end_x, arrow_y),
            (arrow_end_x - head, arrow_y - head),
            (arrow_end_x - head, arrow_y + head),
        ],
        fill=PRIMARY + (220,),
    )

    # --- "Drag to install" text ---
    text = "Drag to the Applications folder to install"
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
        small_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11)
    except (IOError, OSError):
        font = ImageFont.load_default()
        small_font = font

    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(
        ((width - tw) // 2, arrow_y + 20),
        text,
        fill=TEXT_SECONDARY + (200,),
        font=font,
    )

    # --- Branding footer ---
    bbox = draw.textbbox((0, 0), "FrameLean", font=small_font)
    fw = bbox[2] - bbox[0]
    draw.text(
        ((width - fw) // 2, height - 30),
        "FrameLean",
        fill=PRIMARY + (180,),
        font=small_font,
    )

    # --- Save ---
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"DMG background saved to: {output_path}")


if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else "build/macos/dmg_background.png"
    generate(output)

"""
Test different target grid sizes for house sprites.
Generates previews at 48, 64, 96, 128 px so we can pick the best match.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_art_pipeline import convert_to_pixel_art
from PIL import Image

SPRITES_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "sprites"
OUT_DIR = Path(__file__).resolve().parent / "test_output" / "house_sizes"
OUT_DIR.mkdir(parents=True, exist_ok=True)

N_COLORS = 16

# Sample: one from each family to judge quickly
SAMPLES = [
    "pixelart_house_1.png",
    "pixelart_building_1.png",
    "pixelart_combo_4.png",
    "pixelart4_1.png",
]

for target in [48, 64, 96]:
    for name in SAMPLES:
        src = SPRITES_DIR / name
        img = Image.open(src)
        result = convert_to_pixel_art(img, target_size=target, n_colors=N_COLORS, remove_bg=True)
        out = OUT_DIR / f"{name.replace('.png','')}_{target}px.png"
        result.save(str(out))
        # 3x preview for inspection
        preview = result.resize((result.width * 3, result.height * 3), Image.NEAREST)
        preview.save(str(out.with_name(out.stem + "_preview.png")))
        print(f"{name} -> {result.width}x{result.height} ({target}px grid)")

print(f"\nPreviews in: {OUT_DIR}")

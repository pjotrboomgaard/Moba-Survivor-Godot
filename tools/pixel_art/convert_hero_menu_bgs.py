"""
Convert the 3 robot hero menu_bg sprites (Arclight/Joule, Bulwark/Tremor,
Warden/Diord) to pixel-art style matching Tobor's clean, muted look.

The source images are 1080x607 detailed AI renders. We:
  1. Downscale the full frame to a pixel grid (162x91 = 1:6.67 scale).
  2. Desaturate to match the game's muted art pass.
  3. Quantize to a limited palette (24 colors for hero detail).
  4. Upscale back to 1080x607 with NEAREST (pixel-art look, same size).

This preserves the exact same dimensions so the menu layout is unchanged.
"""

import os
import colorsys
from pathlib import Path
from PIL import Image

BASE = Path(__file__).resolve().parent.parent.parent
UI_DIR = BASE / "assets" / "ui"

# Target pixel grid: 1080/6.67 ≈ 162, 607/6.67 ≈ 91
# Use a clean divisor for even pixels: 1080/7=154, 607/7=86.7
# Let's use width-based: target 160 wide -> 1080/160 = 6.75 scale
TARGET_W = 160
N_COLORS = 24
DESAT_FACTOR = 0.55  # Match house conversion

HERO_FILES = [
    "arclight_menu_bg.png",
    "bulwark_menu_bg.png",
    "warden_menu_bg.png",
]


def downscale_to_width(img: Image.Image, target_w: int) -> Image.Image:
    """Downscale keeping aspect ratio, two-stage LANCZOS+BOX."""
    img = img.convert("RGBA")
    w, h = img.size
    scale = target_w / w
    new_w = target_w
    new_h = max(1, round(h * scale))
    mid_w = max(1, new_w * 2)
    mid_h = max(1, new_h * 2)
    small = img.resize((mid_w, mid_h), Image.LANCZOS)
    small = small.resize((new_w, new_h), Image.BOX)
    return small


def desaturate(img: Image.Image, factor: float = DESAT_FACTOR) -> Image.Image:
    """Reduce saturation of all pixels."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h_hsv, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            s = s * factor
            r2, g2, b2 = colorsys.hsv_to_rgb(h_hsv, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return img


def convert_one(src_path: str) -> Image.Image:
    """Full pipeline: downscale -> desaturate -> quantize -> upscale back."""
    img = Image.open(src_path).convert("RGBA")
    orig_w, orig_h = img.size
    print(f"    [src] {orig_w}x{orig_h}")

    # Downscale to pixel grid
    small = downscale_to_width(img, TARGET_W)
    print(f"    [downscale] -> {small.width}x{small.height}")

    # Desaturate
    small = desaturate(small, DESAT_FACTOR)

    # Quantize
    rgb = small.convert("RGB")
    rgb = rgb.point(lambda v: (v >> 2) << 2)  # Snap to 4-step grid
    quantized = rgb.quantize(colors=N_COLORS, method=Image.MEDIANCUT, kmeans=6)
    result = quantized.convert("RGBA")
    # Restore alpha
    spx = small.load()
    rpx = result.load()
    for y in range(result.height):
        for x in range(result.width):
            if spx[x, y][3] < 128:
                rpx[x, y] = (0, 0, 0, 0)

    colors_used = len(result.getcolors(maxcolors=9999))
    print(f"    [quantize] {colors_used} colors")

    # Upscale back to original size with NEAREST
    final = result.resize((orig_w, orig_h), Image.NEAREST)
    print(f"    [upscale] -> {final.width}x{final.height}")
    return final


def main():
    for name in HERO_FILES:
        src_path = str(UI_DIR / name)
        if not os.path.exists(src_path):
            print(f"[SKIP] {name} not found")
            continue

        print(f"\n[CONVERT] {name}")
        result = convert_one(src_path)

        # Save
        result.save(src_path)
        print(f"    [save] {name} -> {result.width}x{result.height}")

        # 4x preview for inspection
        bbox = result.getbbox()
        if bbox:
            content = result.crop(bbox)
        else:
            content = result
        preview = content.resize((content.width * 3, content.height * 3), Image.NEAREST)
        preview_path = str(UI_DIR / name.replace(".png", "_preview.png"))
        preview.save(preview_path)
        print(f"    [preview] {preview.width}x{preview.height}")

    print(f"\n[DONE] All hero menu_bg sprites converted to {TARGET_W}px pixel art.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Create red-eyed night variants of base + biome creep sprites.

For each creep sprite, finds the dark eye pixels (near-black, in the upper
half of the body) and replaces them with bright red, plus a small glow.
Saves as <name>_night.png alongside the original.
"""
from PIL import Image
import os, shutil

SPRITES_DIR = "assets/sprites"
CREEPS = [
    "grunt", "swarmling", "spitter", "drifter", "brute", "stalker",
    "bomber", "hexer", "sentinel", "splitter", "charger", "lurker",
    "ravager", "stormcaller",
]
BIOMES = ["docks", "factory", "ice", "volcano"]

EYE_RED = (255, 30, 20, 255)
GLOW_RED = (220, 50, 30, 200)


def find_eye_pixels(im: Image.Image):
    """Find near-black opaque pixels in the upper 60% of the sprite."""
    px = im.load()
    w, h = im.size
    search_bottom = int(h * 0.6)
    dark = []
    for y in range(search_bottom):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 128 and r < 60 and g < 60 and b < 60:
                dark.append((x, y))
    return dark


def make_night_variant(src: str, dst: str) -> bool:
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size

    eye_pixels = find_eye_pixels(im)
    if not eye_pixels:
        cx, eye_y, gap = w // 2, max(2, h // 5), max(2, w // 6)
        eye_pixels = [(cx - gap, eye_y), (cx + gap, eye_y)]

    # Replace eye pixels with bright red. For small sprites (16x16) skip glow
    # to avoid painting the whole face; for larger ones add a 1px glow ring.
    for (ex, ey) in eye_pixels:
        px[ex, ey] = EYE_RED
    if w >= 20:
        eye_set = set(eye_pixels)
        for (ex, ey) in eye_pixels:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = ex + dx, ey + dy
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in eye_set:
                        r, g, b, a = px[nx, ny]
                        if a > 128:
                            px[nx, ny] = GLOW_RED

    backup = src + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(src, backup)

    im.save(dst)
    print(f"  {os.path.basename(src)} -> {os.path.basename(dst)} ({w}x{h}), {len(eye_pixels)} eye px replaced")
    return True


def main():
    print("Creating red-eyed night variants...")
    ok = total = 0
    for name in CREEPS:
        src = os.path.join(SPRITES_DIR, f"{name}.png")
        dst = os.path.join(SPRITES_DIR, f"{name}_night.png")
        total += 1
        if not os.path.exists(src):
            print(f"  SKIP {name}.png (not found)")
            continue
        if make_night_variant(src, dst):
            ok += 1
    for biome in BIOMES:
        for name in CREEPS:
            src = os.path.join(SPRITES_DIR, f"tw_{biome}_{name}.png")
            dst = os.path.join(SPRITES_DIR, f"tw_{biome}_{name}_night.png")
            total += 1
            if not os.path.exists(src):
                continue
            if make_night_variant(src, dst):
                ok += 1
    print(f"\nDone: {ok}/{total} night variants created.")
    return 0


if __name__ == "__main__":
    exit(main())

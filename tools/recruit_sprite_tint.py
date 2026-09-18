"""Recruit-creep sprite re-tint (2026-09-18 minigame camp creeps).

The minigame "recruit" camps spawn world-1 (grass) creeps that:
  - sit idle around the 4 corner minigame circles, tinted LIGHT YELLOW
    (the "neutral / recruitable" look),
  - get recoloured to ORANGE once the player completes the minigame and
    recruits them (the player's accent colour family).

Per the user's clarification: the original grunt has a red inner body with a
dark outline. The recruit sprites keep the EXACT SAME shape and detail, but
the inner (non-outline, non-eye) pixels are recoloured — red → light yellow
for idle, red → orange for recruited. The outline and eyes stay untouched.

This script:
  1. For each source sprite, finds the dominant non-outline, non-eye colour
     (the "inner body" colour).
  2. Replaces pixels close to that dominant colour with the target tint,
     preserving alpha and keeping the outline (dark pixels) and eyes
     (near-white pixels) intact.
  3. Writes results next to the originals under a ``_recruit_yellow`` /
     ``_recruit_orange`` suffix.

Usage:
    python tools/recruit_sprite_tint.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"

# The 13 non-boss, non-world-exclusive grass (world 1) creep types.
WORLD_1_TYPES = [
    "grunt",
    "swarmling",
    "spitter",
    "drifter",
    "brute",
    "stalker",
    "bomber",
    "hexer",
    "sentinel",
    "splitter",
    "lurker",
    "charger",
    "summoner",
]

# Idle = LIGHT yellow (neutral recruitable pool). 2026-09-18: bumped to a
# paler, more pastel tone so the idle camp reads as "soft/available" rather
# than a hard saturated yellow.
YELLOW = (255, 248, 190)
# Recruited = orange (player accent colour family).
ORANGE = (255, 138, 61)


def _is_dark(rgb):
    """Outline / shadow pixels — keep untouched."""
    r, g, b = rgb
    return r < 70 and g < 70 and b < 80


def _is_eye(rgb):
    """Near-white eye / highlight pixels — keep untouched."""
    r, g, b = rgb
    return r > 220 and g > 220 and b > 220


def _dominant_inner_color(img: Image.Image) -> tuple[int, int, int]:
    """Find the most common non-outline, non-eye pixel colour.

    This is the 'inner body' colour that we want to recolor.
    """
    pixels = img.load()
    w, h = img.size
    counts: dict[tuple[int, int, int], int] = {}
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = pixels[x, y]
            if pa <= 0:
                continue
            rgb = (pr, pg, pb)
            if _is_dark(rgb) or _is_eye(rgb):
                continue
            # Quantise to 8-step buckets so near-duplicates collapse.
            key = (pr // 16 * 16, pg // 16 * 16, pb // 16 * 16)
            counts[key] = counts.get(key, 0) + 1
    if not counts:
        return (255, 255, 255)
    return max(counts, key=counts.get)


def _color_distance(c1, c2) -> float:
    return ((c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2) ** 0.5


def retint(src: Path, dest: Path, target_rgb, label: str) -> bool:
    if not src.exists():
        print(f"skip (missing source): {src.name}")
        return False
    img = Image.open(src).convert("RGBA")
    pixels = img.load()
    w, h = img.size

    dominant = _dominant_inner_color(img)
    tr, tg, tb = target_rgb
    # Threshold: recolour pixels within this distance of the dominant inner colour.
    threshold = 90.0

    recolored = 0
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = pixels[x, y]
            if pa <= 0:
                continue
            rgb = (pr, pg, pb)
            if _is_dark(rgb) or _is_eye(rgb):
                continue  # preserve outline & eyes
            if _color_distance(rgb, dominant) <= threshold:
                # Blend: keep a hint of the original shading toward the target.
                # Mix 80% target + 20% original to preserve subtle shading.
                nr = int(tr * 0.85 + pr * 0.15)
                ng = int(tg * 0.85 + pg * 0.15)
                nb = int(tb * 0.85 + pb * 0.15)
                pixels[x, y] = (min(255, nr), min(255, ng), min(255, nb), pa)
                recolored += 1

    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)
    print(f"wrote {dest.name}  (dominant={dominant}, recolored {recolored} px)")
    return True


def main() -> int:
    if not SPRITES.exists():
        print(f"sprite dir not found: {SPRITES}")
        return 1

    variants = {
        "yellow": YELLOW,
        "orange": ORANGE,
    }
    written = 0
    for type_id in WORLD_1_TYPES:
        for suffix in ("", "_night"):
            base = f"{type_id}{suffix}"
            src = SPRITES / f"{base}.png"
            if not src.exists():
                continue
            for label, rgb in variants.items():
                dest = SPRITES / f"{type_id}_recruit_{label}{suffix}.png"
                if retint(src, dest, rgb, label):
                    written += 1

    print(f"done: {written} recruit sprites written to {SPRITES}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

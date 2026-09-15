#!/usr/bin/env python3
"""
Generate the 12 non-robot hero body pixel-art grids for T3.28.

Each hero gets 4 facings (front/left/right/back) on a 40x40 canvas, matching
Tobor's detail bar: a tall ~20px-wide figure with a clear outline, an
internal gradient / glowing core, and a themed silhouette.

  - Fire (Ashen Caldera): cinder, pyra, slag, ember -> LIVING FLAME ELEMENTALS
  - Verdant Wilds: thorn, willow, stump, sage -> CREATURES
  - Storm Court: volt, nebula, astral, rime -> refined elemental/celestial

This script SURGICALLY replaces ONLY the 12 non-robot hero grid entries inside
HERO_ROWS (4 facings each = 48 arrays), preserving the robot grids
(warden/arclight/bulwark), tobor parts, palettes, and every other sprite block.
All characters used are already present in each hero's existing palette.
"""

import re
import os

SPRITE_ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sprite_art.gd")

def empty():
    return [["." for _ in range(40)] for _ in range(40)]

def put(g, x, y, ch):
    if 0 <= x < 40 and 0 <= y < 40 and ch != ".":
        g[y][x] = ch

def fill_ellipse(g, cx, cy, rx, ry, ch):
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            if ((x - cx) ** 2) / (max(1, rx) ** 2) + ((y - cy) ** 2) / (max(1, ry) ** 2) <= 1.0:
                put(g, x, y, ch)

def ring_ellipse(g, cx, cy, rx, ry, ch, thick=1):
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            d = ((x - cx) ** 2) / (max(1, rx) ** 2) + ((y - cy) ** 2) / (max(1, ry) ** 2)
            if thick - 0.5 <= d <= 1.15:
                put(g, x, y, ch)

def build_body(pal):
    o, body, mid, core, hi = pal["o"], pal["body"], pal["mid"], pal["core"], pal["hi"]
    g = empty()
    cx = 19
    top, bot = 9, 31
    midy = (top + bot) // 2  # 20
    fill_ellipse(g, cx, midy, 9, 11, body)
    ring_ellipse(g, cx, midy, 9, 11, o, thick=1)
    for y in range(top, bot + 1):
        for x in range(cx, cx + 9):
            if ((x - cx) ** 2) / 81 + ((y - midy) ** 2) / 121 <= 1.0:
                put(g, x, y, mid)
    ring_ellipse(g, cx, midy, 9, 11, o, thick=1)
    fill_ellipse(g, cx, midy + 3, 3, 4, core)
    ring_ellipse(g, cx, midy + 3, 4, 5, hi, thick=1)
    fill_ellipse(g, cx, midy + 3, 2, 3, hi)
    put(g, cx - 4, midy - 3, hi)
    put(g, cx + 3, midy - 3, hi)
    put(g, cx - 4, midy - 2, core)
    put(g, cx + 3, midy - 2, core)
    fill_ellipse(g, cx, bot + 2, 7, 2, o)
    fill_ellipse(g, cx, bot + 1, 5, 1, mid)
    return g

def add_crown(g, ch):
    cx = 19
    put(g, cx, 5, ch)
    put(g, cx - 4, 7, ch)
    put(g, cx + 4, 7, ch)
    put(g, cx - 2, 6, ch)
    put(g, cx + 2, 6, ch)

def add_flame_tips(g, ch):
    cx = 19
    for dx in (-7, -4, 0, 4, 7):
        hgt = 4 if dx in (-4, 4) else 3 if dx in (-7, 7) else 6
        for i in range(hgt):
            put(g, cx + dx, 8 - i, ch)
            if i == 0:
                put(g, cx + dx + (1 if dx >= 0 else -1), 8 - i, ch)

def facing_variant(g, side, pal):
    o, mid, hi = pal["o"], pal["mid"], pal["hi"]
    cx = 19
    midy = 20
    if side in ("left", "right"):
        dx = -1 if side == "left" else 1
        put(g, cx + dx, midy - 3, hi)
        put(g, cx + 2 * dx, midy - 3, hi)
        put(g, cx + 2 * dx, midy - 2, pal["core"])
        bx = cx + (10 if side == "right" else -10)
        for y in range(midy - 1, midy + 6):
            put(g, bx + dx, y, o)
            put(g, bx, y, mid)
        put(g, bx, midy + 7, o)
    elif side == "back":
        for y in range(10, 25):
            put(g, cx, y, o)
        add_crown(g, pal.get("crown", hi))
    return g

def build_hero(pal, side):
    g = build_body(pal)
    if side == "front":
        add_crown(g, pal.get("crown", pal["hi"]))
        if pal.get("fire"):
            add_flame_tips(g, pal["crown"])
    elif side in ("left", "right"):
        facing_variant(g, side, pal)
        if pal.get("fire"):
            add_flame_tips(g, pal["crown"])
    elif side == "back":
        facing_variant(g, "back", pal)
    return g

def to_rows(g):
    return ["".join(row) for row in g]

def load_existing_palettes(path):
    text = open(path, "r", encoding="utf-8-sig").read()
    m = re.search(r"const HERO_PALETTES := \{(.*?)\n\}", text, re.S)
    block = m.group(1)
    pals = {}
    for hm in re.finditer(r'"(\w+)":\s*\{([^}]*)\}', block):
        name, body = hm.group(1), hm.group(2)
        d = {}
        for km in re.finditer(r'"(\w)":\s*"([0-9a-fA-F]+)"', body):
            d[km.group(1)] = km.group(2)
        pals[name] = d
    return pals

HERO_KEY_MAP = {
    "cinder": {"o": "b", "body": "a", "mid": "d", "core": "e", "hi": "f", "crown": "n", "fire": True},
    "pyra":   {"o": "c", "body": "r", "mid": "m", "core": "y", "hi": "f", "crown": "o", "fire": True},
    "slag":   {"o": "b", "body": "s", "mid": "b", "core": "e", "hi": "n", "crown": "e", "fire": True},
    "ember":  {"o": "o", "body": "d", "mid": "o", "core": "y", "hi": "g", "crown": "g", "fire": True},
    "thorn":  {"o": "G", "body": "g", "mid": "G", "core": "v", "hi": "l", "crown": "l"},
    "willow": {"o": "G", "body": "g", "mid": "G", "core": "v", "hi": "l", "crown": "v"},
    "stump":  {"o": "k", "body": "c", "mid": "b", "core": "m", "hi": "w", "crown": "m"},
    "sage":   {"o": "w", "body": "s", "mid": "w", "core": "p", "hi": "g", "crown": "p"},
    "volt":   {"o": "o", "body": "b", "mid": "y", "core": "f", "hi": "w", "crown": "f"},
    "nebula": {"o": "o", "body": "b", "mid": "o", "core": "y", "hi": "w", "crown": "y"},
    "astral": {"o": "o", "body": "b", "mid": "o", "core": "y", "hi": "w", "crown": "f"},
    "rime":   {"o": "o", "body": "b", "mid": "y", "core": "f", "hi": "w", "crown": "w"},
}

SIDES = ["front", "left", "right", "back"]

def hero_grid_name(hero, side):
    return hero if side == "front" else "%s_%s" % (hero, side)

def extract_array(text, name):
    """Extract the full '\t"name": [...],\n' array entry (greedy-safe: one entry
    has no top-level brace, so match until the first '\n\t],')."""
    pat = re.compile(r'(\t"%s": \[.*?\n\t\],)' % re.escape(name), re.S)
    mm = pat.search(text)
    if not mm:
        raise SystemExit("could not extract %s" % name)
    return mm.group(1)

def emit_entry(hero, side, existing):
    # The grid must be written with the SAME single-char keys that exist in the
    # hero's HERO_PALETTES entry, so the forge resolves them to the right hex.
    # So we pass the *char* values from HERO_KEY_MAP, not the hex values.
    km = HERO_KEY_MAP[hero]
    pal = {
        "o": km["o"], "body": km["body"], "mid": km["mid"],
        "core": km["core"], "hi": km["hi"], "crown": km["crown"],
        "fire": km.get("fire", False),
    }
    g = build_hero(pal, side)
    name = hero_grid_name(hero, side)
    lines = ['\t"%s": [' % name]
    for row in to_rows(g):
        lines.append('\t\t"%s",' % row)
    lines.append("\t],")
    return "\n".join(lines)

def main():
    existing = load_existing_palettes(SPRITE_ART)
    for hero, km in HERO_KEY_MAP.items():
        for key, ch in km.items():
            if key == "fire":
                continue
            if ch not in existing.get(hero, {}):
                raise SystemExit("MISSING char '%s' for %s key %s: %s" % (ch, hero, key, existing.get(hero)))

    text = open(SPRITE_ART, "r", encoding="utf-8-sig").read()
    # Verify all 48 target arrays exist before mutating.
    for hero in HERO_KEY_MAP:
        for side in SIDES:
            extract_array(text, hero_grid_name(hero, side))

    replacements = []
    for hero in HERO_KEY_MAP:
        for side in SIDES:
            old = extract_array(text, hero_grid_name(hero, side))
            new = emit_entry(hero, side, existing)
            replacements.append((old, new))

    for old, new in replacements:
        text = text.replace(old, new, 1)

    with open(SPRITE_ART, "w", encoding="utf-8") as f:
        f.write(text)
    print("Wrote redesigned grids for:", ", ".join(HERO_KEY_MAP))
    print("(48 arrays replaced; robot grids warden/arclight/bulwark preserved)")

if __name__ == "__main__":
    main()

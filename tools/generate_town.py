#!/usr/bin/env python3
"""Procedurally bake pixel-art town building sprites into assets/sprites/.

Idempotent: safe to re-run. Each building is hand-authored as a character grid
resolved through a small palette (exactly like the tree sprites in
tools/sprite_art.gd). "." is transparent. No anti-aliasing — flat 1-2px outlines
and muted earth tones so they match the existing pixel-art world.

Each building is drawn at a slightly different angle/direction:
  - town_house : small gabled house, front face, gable ridge tilted toward lower-left
  - town_shop  : wide storefront, angled 45 deg, awning on the right face
  - town_church: narrow nave + steeple, front face, cross at the top
  - town_well  : round stone well, top-down-ish 45 deg, rope + bucket on the right

Run from the project root:
    python tools/generate_town.py
"""

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("This generator needs Pillow. Install it with: pip install Pillow")

# Project root = parent of this tools/ directory.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "sprites")

# ---------------------------------------------------------------------------
# Palettes. Keys are single characters used in the grids below.
# Muted earth tones with a dark outline (o) shared across all four so the set
# reads as a cohesive town.
# ---------------------------------------------------------------------------
HOUSE_PALETTE = {
    "o": "201812",  # dark brown-black outline
    "w": "8a6a48",  # warm plaster wall (light)
    "s": "6e5338",  # plaster wall (shade)
    "r": "5a3a26",  # roof terracotta-brown
    "R": "462c1c",  # roof shadow
    "d": "3a2a1c",  # dark doorway
    "l": "d8c9a0",  # window glass (light)
    "g": "2a2620",  # window glass dark / frame
    "t": "4a3420",  # tree / hedge foliage
    "h": "3a4a2a",  # hedge darker
}

SHOP_PALETTE = {
    "o": "1a1410",  # outline
    "w": "9a7a54",  # wall plaster
    "s": "7a5e3e",  # wall shade
    "a": "c43018",  # awning (muted red)
    "A": "8a2414",  # awning shadow
    "r": "5a3a26",  # roof
    "R": "462c1c",  # roof shadow
    "d": "3a2a1c",  # door
    "l": "d8c9a0",  # glass
    "g": "2a2620",  # glass dark
    "t": "4a3420",  # crate wood
    "T": "3a2a1a",  # crate shadow
    "e": "c9a227",  # sign / lantern accent
}

CHURCH_PALETTE = {
    "o": "1c1a18",  # outline
    "w": "b8a88c",  # stone wall (light)
    "s": "93846a",  # stone wall (shade)
    "r": "4a4a52",  # slate roof
    "R": "383840",  # slate roof shadow
    "t": "5a4a3a",  # timber trim
    "l": "d8d2c0",  # window glass light
    "g": "2a2620",  # window glass dark / frame
    "c": "d8c88c",  # cross / steeple cap (pale gold)
    "d": "3a2a1c",  # door
    "h": "3a4a2a",  # hedge
}

WELL_PALETTE = {
    "o": "1a1610",  # outline
    "w": "8a7a64",  # stone (light)
    "s": "6a5c48",  # stone (shade)
    "W": "a89878",  # stone highlight
    "r": "4a3a28",  # roof/beam timber (dark)
    "R": "3a2c1c",  # beam shadow
    "l": "2a3440",  # water
    "L": "3a4a58",  # water light
    "b": "5a3a20",  # bucket wood
    "B": "3a2414",  # bucket shadow
}


def build_house():
    """Small residential house. Gable ridge tilts toward the lower-left, so the
    roofline reads as angled (not a symmetric front). 32x32."""
    rows = [
        "................................",
        "................................",
        "................oo..............",
        "..............oorroo............",
        "............oorrrroo............",
        "..........oRRrrrrrooo.........",
        ".........oRRrrrrrrroo.........",
        "........oRRrrrrrrrrroo........",
        ".......oRRrrrrrrrrrrroo.......",
        "......oRRRRrrrrrrrrRRoo.......",
        ".......ooooooooooooooooo......",
        ".......owwwwwwwwwwwwwwo.......",
        ".......owwwwowwwoowwwwo.......",
        ".......owwwolwwlwwolwwwo.......",
        ".......owwwolwwlwwolwwwo.......",
        ".......owwwolwwlwwolwwwo.......",
        ".......ooooooooooooooooo......",
        ".......owwwwwwwwwwwwwwo.......",
        ".......owwwwwdwwwwdwwwo.......",
        ".......owwwwwdwwwwdwwwo.......",
        ".......owwwwwddddwwwwwo.......",
        ".......owwwwwdwwwwdwwwo.......",
        ".......owwwwwdwwwwdwwwo.......",
        ".......ooooooooooooooooo......",
        "......ottttttttttttttttto.....",
        ".....ohhhtttttttttttthho......",
        "......ohhhtttttttthhho........",
        ".......ohhtttttthhho...........",
        ".......oohhtthhoo.............",
        "........ooooooo.................",
        "................................",
        "................................",
    ]
    # Trim to the content: 32 wide x 32 tall
    rows = [r[:32].ljust(32, ".") for r in rows]
    return rows, HOUSE_PALETTE


def build_shop():
    """Small shop / storefront. Angled 45 deg: the awning sits on the right face
    and the base steps toward the lower-right. 36x32."""
    rows = [
        "....................................",
        "....................................",
        "....................................",
        "...............ooo..................",
        ".............oorrooo................",
        "...........oRRrrrrroo...............",
        ".........oRRrrrrrrrrroo.............",
        "........oRRrrrrrrrrRRRoo............",
        ".......oooooooooooooooooo...........",
        ".......owwwwwwwwwwwwwwwwo...........",
        ".......owwwwwwwwwwwwwwwwo...........",
        ".......owaawaawaawaawaao...........",
        ".......owAaAaAaAaAaAaAao............",
        ".......owwwwwwwwwwwwwwwwo...........",
        ".......owlwwglwwlwwglwwwo...........",
        ".......owlwwglwwlwwglwwwo...........",
        ".......owlwwglwwlwwglwwwo...........",
        ".......oooooooooooooooooo...........",
        ".......owwwwwwwwwwowwwwwwwo.........",
        ".......owwwwwwwwwodwwwwwwwwo........",
        ".......owwwwwwwwwodwwwwwwwwo........",
        ".......owwwwwwdwwodwwwwwwwwo........",
        ".......owwwwwwdwwodwwwwwwwwo........",
        ".......owwwwwwddddwwwwwwwwwwo.......",
        ".......owwwwwwddddwwwwwwwwwwo.......",
        ".......owwwwwwwwwwwwwwwwwwwwo.......",
        "......ottttttttttttttttttttto......",
        ".....oTTTTTTTTTTTTTTTTTTTTTTTo......",
        ".....oTttttttttttttttttttttTTo......",
        "......oTTTTTTTTTTTTTTTTTTTTTo......",
        ".......oooooooooooooooooooo........",
        "....................................",
    ]
    rows = [r[:36].ljust(36, ".") for r in rows]
    return rows, SHOP_PALETTE


def build_church():
    """Small church with steeple. Front face, cross at the top. 30x40."""
    rows = [
        "..............................",
        "..............................",
        "................cc............",
        "................cc............",
        "..............ccccc...........",
        "................cc............",
        "................cc............",
        "............ooooooooo.........",
        "............orrRRroo..........",
        "..........oRRrrrrrrRoo........",
        "........oRRrrrrrrrrRoo........",
        ".......oooooooooooooo.........",
        ".......owwlllwwwwwwwwo........",
        ".......owwlllwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        "......owwwwwwowwwwowwwwo......",
        "......owwwwwolwwolwwwwwo......",
        "......owwwwwolwwolwwwwwo......",
        "......owwwwwolwwolwwwwwo......",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwddwwwwwwwo........",
        ".......owwwwddwwwwwwwo........",
        ".......owwwwddddwwwwwo........",
        ".......owwwwddddwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......owwwwwwwwwwwwwo........",
        ".......oooooooooooooo.........",
        "......ohhhhhhhhhhhhhho........",
        ".....ohhhhhhhhhhhhhhhho.......",
        "......ohhhhhhhhhhhhhho........",
        ".......oohhhhhhhhhoo..........",
        "........ooooooooooo...........",
        "..............................",
        "..............................",
    ]
    rows = [r[:30].ljust(30, ".") for r in rows]
    return rows, CHURCH_PALETTE


def build_well():
    """Round stone well. Top-down-ish 45 deg: the rim reads as an ellipse and the
    rope + bucket hang on the right side. 28x28."""
    rows = [
        "............................",
        "............................",
        "............rrrrrr..........",
        "...........rrRRRRrr.........",
        "..........rRRRRRRRRr........",
        "........ooooooooooooo.......",
        ".......owWwwwwwWWWWwo.......",
        "......owWWwwwwwWwwwwwo......",
        "......oWWwwllllllwwWo.......",
        "......owwwlLlllllllwwwo.....",
        "......owwwlLlllllllwwwo.....",
        "......owwwlllllllllwwwo.....",
        "......owwwwwllllwwwwwo......",
        ".......owwwwwwwwwwwwwo......",
        ".......ossssssssssssswo.....",
        "......ossoWWWWWWWWWWso......",
        "......osWWwwwwwwwwwwso......",
        "......oswwwsswwwwsswwso.....",
        "......osswWWWWWWWWWWsso.....",
        "......ossoWWWWWWWWWWso......",
        ".......ossssssssssssswo.....",
        "........ooooooooooooo.......",
        "............bbbb..........",
        "...........bBBBb..........",
        "...........BBBBb..........",
        "...........bBBBb..........",
        "............................",
        "............................",
    ]
    rows = [r[:28].ljust(28, ".") for r in rows]
    return rows, WELL_PALETTE


def hex_to_rgba(h):
    h = h.strip().lstrip("#")
    r = int(h[0:2], 16)
    g = int(h[2:4], 16)
    b = int(h[4:6], 16)
    return (r, g, b, 255)


def render(rows, palette, name):
    """Render a character grid to a transparent PNG at the exact grid size."""
    width = max(len(r) for r in rows)
    height = len(rows)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "." or not palette.get(ch):
                continue
            img.putpixel((x, y), hex_to_rgba(palette[ch]))
    path = os.path.join(OUT_DIR, name + ".png")
    img.save(path, format="PNG")
    return path, width, height


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    builders = {
        "town_house": build_house,
        "town_shop": build_shop,
        "town_church": build_church,
        "town_well": build_well,
    }
    for name, builder in builders.items():
        rows, palette = builder()
        # Validate every non-dot char exists in the palette.
        used = {c for row in rows for c in row if c != "."}
        missing = used - set(palette)
        if missing:
            sys.exit("%s: palette missing chars %s" % (name, sorted(missing)))
        path, w, h = render(rows, palette, name)
        print("%-12s  %dx%d  %s" % (name, w, h, os.path.relpath(path, ROOT)))
    print("Wrote %d town sprites to %s" % (len(builders), os.path.relpath(OUT_DIR, ROOT)))


if __name__ == "__main__":
    main()

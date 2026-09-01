"""Render current landmark pixel rows to PNGs for visual inspection."""
import re
from PIL import Image

SRC = "tools/tobor_world_art.gd"

SPECS = [
    ("grass", "_GRASS_BELL", "Bell (wipe)"),
    ("grass", "_GRASS_POOL", "Pool (freeze)"),
    ("grass", "_GRASS_STONE", "Stone (heal)"),
    ("volcano", "_VOLCANO_ARCH", "Arch (wipe)"),
    ("volcano", "_VOLCANO_SHRINE", "Shrine (freeze)"),
    ("volcano", "_VOLCANO_WELL", "Well (heal)"),
    ("ice", "_ICE_GLADE", "Glade/Mirror (wipe)"),
    ("ice", "_ICE_HOLLOW", "Hollow (heal)"),
    ("factory", "_FACTORY_PYLON", "Pylon (wipe)"),
    ("factory", "_FACTORY_VAT", "Vat (freeze)"),
    ("factory", "_FACTORY_BAY", "Bay (heal)"),
    ("docks", "_DOCKS_LIGHTHOUSE", "Lighthouse (heal)"),
    ("docks", "_DOCKS_BELL", "Bell (wipe)"),
    ("docks", "_DOCKS_POOL", "Siren (freeze)"),
]


def extract_array(text, name):
    m = re.search(r"const %s := \[(.*?)\]" % name, text, re.S)
    if not m:
        raise SystemExit(f"missing const {name}")
    return re.findall(r'"([^"]*)"', m.group(1))


def extract_palette(text, biome):
    # landmark palettes block only
    block = text[text.index("const LANDMARK_PALETTES"):]
    block = block[:block.index("## Basalt")]
    m = re.search(r'"%s": \{([^}]*)\}' % biome, block)
    if not m:
        raise SystemExit(f"missing palette {biome}")
    return {ch: tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
            for ch, h in re.findall(r'"(\w)": "([0-9a-f]{6})"', m.group(1))}


def main():
    text = open(SRC, encoding="utf-8").read()
    scale = 20
    cols = 7
    rows = (len(SPECS) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 16 * scale, rows * 16 * scale), (24, 26, 32, 255))
    for idx, (biome, const, label) in enumerate(SPECS):
        rows_data = extract_array(text, const)
        pal = extract_palette(text, biome)
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for y, row in enumerate(rows_data):
            for x, ch in enumerate(row):
                if ch == "." or ch not in pal:
                    continue
                img.putpixel((x, y), pal[ch] + (255,))
        img = img.resize((16 * scale, 16 * scale), Image.NEAREST)
        px = (idx % cols) * 16 * scale
        py = (idx // cols) * 16 * scale
        sheet.paste(img, (px, py), img)
        print(f"#{idx}: {label:>22} ({biome} {const})")
    sheet.save("tmp/landmarks_redesigned.png")
    print("saved tmp/landmarks_redesigned.png")


if __name__ == "__main__":
    main()

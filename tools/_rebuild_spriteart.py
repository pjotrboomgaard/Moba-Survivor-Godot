"""Rebuild sprite_art.gd from HEAD, applying all session edits in correct order.
1) Normalize boss grids to 24x24.
2) Add missing 'd' palette key to boss palettes.
3) Insert HERO_ABILITY_TONES + 8 hero palettes.
4) Insert 8 new heroes' 4-facing grids (40x40 each).
5) Insert 96 ability icon rows + palettes (harvested from backup).
"""
import io, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GD = ROOT / "tools" / "sprite_art.gd"
BAK = ROOT / "tools" / "sprite_art.gd.bak"
GRID = 40

src = GD.read_text(encoding="utf-8")

# ---- 4) hero palettes + grids copied from the backup file (pre-corruption harvest) ----
# The backup still contains correctly inserted hero grid blocks (lines were valid there
# before the powert-strip). We re-extract them and graft onto clean base.

def extract_entry(full: str, dict_name: str, key: str) -> str | None:
    """Return the raw text block for a given 'key' in `const dict_name := { }` (grid array form)."""
    m = re.search(re.escape(key) + r'":\s*\[\n(?:\s*"[^\n]*",?\n)*\s*\],\n', full)
    return m.group(0) if m else None

def extract_palette(full: str, dict_name: str, key: str) -> str | None:
    m = re.search(r'\t' + re.escape(key) + r'":\s*\{[^\n]*\},\n', full)
    return m.group(0) if m else None

# extract from backup
bak = BAK.read_text(encoding="utf-8")
hero_ids = ["cinder", "pyra", "slag", "ember", "thorn", "willow", "stump", "sage"]
facings = ["", "_left", "_right", "_back"]

palette_lines = []
for hid in hero_ids:
    p = extract_palette(bak, "HERO_PALETTES", hid)
    if p:
        palette_lines.append(p)

row_blocks = []
for hid in hero_ids:
    for f in facings:
        key = hid + f
        blk = extract_entry(bak, "HERO_ROWS", key)
        if blk:
            row_blocks.append(blk)

# ---- 5) icon rows + palettes + tones harvested from backup ----
def extract_region(full: str, dict_name: str, ids) -> list[str]:
    """Return ordered raw entry lines '"id": X,' found inside the dict for the requested ids."""
    start = full.index("const %s := {" % dict_name) + len("const %s := {" % dict_name)
    close = full.index("\n}", start)
    body = full[start:close]
    out = []
    for hid in ids:
        m = re.search(r'\t"' + re.escape(hid) + r'":[^\n]*,\n', body)
        if m:
            out.append(m.group(0))
    return out


ability_ids = re.findall(r'"([a-z]+_[a-z_]+)": \{', bak)  # rowsave for harvest
ability_ids = sorted(set(i for i in ability_ids if i.split("_")[0] in hero_ids))

icon_rows = extract_region(bak, "ABILITY_ICON_ROWS", ability_ids)
icon_pals = extract_region(bak, "ABILITY_ICON_PALETTES", ability_ids)

# HERO_ABILITY_TONES: pull the whole const block from backup
tones_start = bak.index("const HERO_ABILITY_TONES := {")
tones_close = bak.index("\n}\n", tones_start)
tones_block = bak[tones_start:tones_close + len("\n}\n")]

def insert_before_close(full: str, dict_name: str, inserts: list[str]) -> str:
    start = full.index("const %s := {" % dict_name) + len("const %s := {" % dict_name)
    close = full.index("\n}", start)
    body = full[start:close]
    if not body.endswith("\n"):
        body += "\n"
    return full[:start] + "".join(inserts) + body + full[close:]

# apply in order
src = insert_before_close(src, "HERO_PALETTES", palette_lines)
src = insert_before_close(src, "HERO_ROWS", row_blocks)
src = insert_before_close(src, "ABILITY_ICON_ROWS", icon_rows)
src = insert_before_close(src, "ABILITY_ICON_PALETTES", icon_pals)

# tones: replace/insert whole const
if "const HERO_ABILITY_TONES :=" in src:
    ts = src.index("const HERO_ABILITY_TONES := {")
    tc = src.index("\n}\n", ts)
    src = ts and (src[:ts] + tones_block + src[tc + 3:]) or src
else:
    # insert just before ABILITY_ICON_ROWS
    marker = "const ABILITY_ICON_ROWS"
    src = src.replace(marker, tones_block + "\n" + marker, 1)

GD.write_text(src, encoding="utf-8", newline="\n")
print("hero palettes:", len(palette_lines), "hero grids:", len(row_blocks),
      "icon rows:", len(icon_rows), "icon pals:", len(icon_pals))

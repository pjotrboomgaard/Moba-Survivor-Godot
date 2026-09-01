import io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
t = open(r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.rebuilt", encoding="utf-8").read()

# Build palette map
def dict_entries(name):
    i = t.index("const " + name)
    j = t.index("\n}", i)
    block = t[i:j]
    d = {}
    for m in re.finditer(r'\t"([a-z_0-9]+)":\s*\{(.*?)\}', block):
        keys = set(re.findall(r'"([A-Za-z])":\s*"[0-9a-fA-F]{6}"', m.group(2)))
        d[m.group(1)] = keys
    return d

pal = dict_entries("HERO_PALETTES")

i = t.index("const HERO_ROWS")
j = t.index("const ENEMY_PALETTES")
block = t[i:j]

errors = 0
for m in re.finditer(r'\t"([a-z_0-9]+)":\s*\[\n(.*?)\n\t\],', block, re.S):
    key = m.group(1)
    rows = re.findall(r'"([\.A-Za-z\-]+)"', m.group(2))
    h = len(rows)
    wset = {len(r) for r in rows}
    if wset != {h}:
        print(f"{key}: NOT SQUARE rows={h} widths={sorted(wset)}"); errors += 1
    p = pal.get(key)
    if p is None:
        # reference palette (e.g. ROBOT_HERO_PALETTE) — skip char validation, still check squareness
        if wset == {h}:
            continue
        print(f"{key}: NO PALETTE (ref) and not square"); errors += 1; continue
    used = set()
    for r in rows:
        used |= set(r)
    used.discard(".")
    missing = used - p
    if missing:
        print(f"{key}: uses chars not in palette: {sorted(missing)}"); errors += 1

print("\nTOTAL HERO ERRORS:", errors)

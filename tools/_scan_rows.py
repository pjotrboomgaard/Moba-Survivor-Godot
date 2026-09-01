import re, io

files = [
    "tools/sprite_art.gd",
    "tools/ability_art.gd",
    "tools/tobor_world_art.gd",
    "tools/tobor_biome_enemies.gd",
]
pat = re.compile(r'^\s*"([^"]+)":\s*\[$')            # sprite entry: "name": [
rowpat = re.compile(r'^\s*"([A-Za-z0-9.]+)",?\s*$')   # pixel rows only: dots+palette chars, no ','
for path in files:
    try:
        with io.open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError:
        continue
    i = 0
    while i < len(lines):
        m = pat.match(lines[i])
        if not m:
            i += 1
            continue
        name = m.group(1)
        rows = []
        j = i + 1
        widths = set()
        while j < len(lines):
            line = lines[j].strip()
            if line.endswith("],"):
                j += 1
                break
            rm = rowpat.match(lines[j])
            if rm:
                rows.append(rm.group(1))
                widths.add(len(rm.group(1)))
            j += 1
        if rows and len(rows) > 3:
            h = len(rows)
            wmax = max(widths)
            wmin = min(widths)
            if h != wmax or wmin != wmax:
                print(f"{path}:{i+1}  \"{name}\"  height={h} widths={wmin}..{wmax}   <-- BAD GRID (not square)")
        i = j if j > i else i + 1

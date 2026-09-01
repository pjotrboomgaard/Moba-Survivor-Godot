import re, io

# Pad every pixel row of the named sprite entries to exactly 24 chars with trailing '.'.
TARGET = 24
NAMES = ["pyrelord", "frostreaver", "warhos"]
FILES = ["tools/sprite_art.gd", "tools/tobor_biome_enemies.gd", "tools/tobor_world_art.gd"]
entry_pat = re.compile(r'^(\s*)"(' + "|".join(NAMES) + r')":\s*\[\s*$')
row_pat = re.compile(r'^(\s*)"([A-Za-z0-9.]+)",?\s*$')

for path in FILES:
    try:
        with io.open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError:
        continue
    out = []
    in_block = False
    for line in lines:
        em = entry_pat.match(line)
        if em:
            in_block = True
            out.append(line)
            continue
        if in_block and row_pat.match(line):
            indent, row = row_pat.match(line).group(1), row_pat.match(line).group(2)
            if len(row) < TARGET:
                row = row + ("." * (TARGET - len(row)))
            elif len(row) > TARGET:
                row = row[:TARGET]
            out.append('%s"%s",' % (indent, row))
            continue
        out.append(line)
        if in_block and line.strip().endswith("],"):
            in_block = False
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))
    print("normalized", path)

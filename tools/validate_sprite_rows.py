import re
import sys

## Scans sprite_art.gd / tobor_world_art.gd / tobor_biome_enemies.gd for row data and
## confirms every grid is exactly SQUARE (rows == width), the contract the forge and
## the smoke test rely on. Exits 1 with a readable report when anything is off.

PATHS = [
    "c:/Users/pjotr/Documents/Development/Coop-MOBA-Survivor-Godot-Phase-1/tools/sprite_art.gd",
    "c:/Users/pjotr/Documents/Development/Coop-MOBA-Survivor-Godot-Phase-1/tools/tobor_world_art.gd",
    "c:/Users/pjotr/Documents/Development/Coop-MOBA-Survivor-Godot-Phase-1/tools/tobor_biome_enemies.gd",
]

fail = False
for path in PATHS:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    for match in re.finditer(
        r'const\s+([A-Z_]+)\s*:=\s*\{([\s\S]*?)\n\}', text
    ):
        const_name, body = match.group(1), match.group(2)
        for sub in re.finditer(r'"([^"]+)"\s*:\s*\[([\s\S]*?)\]', body):
            key, rows_text = sub.group(1), sub.group(2)
            rows = re.findall(r'"([^"]+)"', rows_text)
            if not rows:
                continue
            width = len(rows[0])
            if len(rows) != width:
                print(
                    f"{path} :: {const_name}.{key} "
                    f"-> rows={len(rows)} width={width} (expected square)"
                )
                fail = True
                for idx, r in enumerate(rows):
                    if len(r) != width:
                        print(f"    row {idx} is {len(r)} wide: {r!r}")
sys.exit(1 if fail else 0)

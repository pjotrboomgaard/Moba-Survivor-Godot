import io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
t = open(r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.replay_preview", encoding="utf-8").read()

# Extract HERO_ROWS block and list every key in order
hrs = t.index("const HERO_ROWS")
hre = t.index("const ENEMY_PALETTES")
block = t[hrs:hre]
keys = re.findall(r'\t"([a-z_0-9]+)":\s*\[', block)
from collections import Counter
c = Counter(keys)
print("HERO_ROWS keys in order:")
for k in keys:
    print("  ", k, ("DUP!" if c[k] > 1 else ""))
print("\nHERO_ROWS total keys:", len(keys), "unique:", len(c))
dups = {k: v for k, v in c.items() if v > 1}
print("DUPLICATES:", dups)

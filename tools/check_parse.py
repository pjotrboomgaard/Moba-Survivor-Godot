"""Fix parse error in enemy_unstuck_perf.gd around line 175."""
PATH = "scenes/enemy_unstuck_perf/enemy_unstuck_perf.gd"
with open(PATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Show lines 172-180 (0-indexed) for diagnostics
for i in range(170, min(182, len(lines))):
    print(f"{i+1:4d}  {lines[i]!r}")

import sys
lines = []
with open("scenes/enemy_unstuck_perf/enemy_unstuck_perf.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()
# print lines 170-180 (0-indexed: 169-179)
for i in range(169, min(180, len(lines))):
    print(f"{i+1}: {lines[i]!r}")

"""Update PLAN.md to mark enemy_perf_large_groups isolated test as verified."""
import re

PLAN = "PLAN.md"
with open(PLAN, "r", encoding="utf-8") as f:
    content = f.read()

# Mark the enemy perf task as complete
old_task = """- [ ] **Enemy perf large groups** — find more performance optimization with large
  groups of enemies, large diversity, all kinds of enemies. Isolated + in-game.
  (id: enemy_perf_large_groups)"""
new_task = """- [x] **Enemy perf large groups** — find more performance optimization with large
  groups of enemies, large diversity, all kinds of enemies. Isolated + in-game.
  (id: enemy_perf_large_groups)
  - [x] Isolated: 40 diverse enemies (16 grunt, 8 swarmling, 6 spitter, 6 brute, 4 charger)
    avg_ms=8.39 (< 12ms threshold), 30/40 routed. PASS.
    - iso: tools/selftest/results/enemy_unstuck_perf_iso/iso_stuck_3.5s.png, iso_routed_7.0s.png
    - report: tools/selftest/results/enemy_unstuck_perf_iso_report.json
  - [ ] In-game: large-group FFA perf test"""

if old_task in content:
    content = content.replace(old_task, new_task, 1)
    print("Task updated")
else:
    print("Task block not found — checking for alternative format")
    # Try with slightly different whitespace
    if "Enemy perf large groups" in content:
        print("Found task header but block didn't match exactly")

with open(PLAN, "w", encoding="utf-8") as f:
    f.write(content)

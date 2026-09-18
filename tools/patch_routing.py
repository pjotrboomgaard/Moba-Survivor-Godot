"""Fix _check_routed to use global_position instead of local position."""

PATH = "scenes/enemy_unstuck_perf/enemy_unstuck_perf.gd"

OLD = """		if e.position.x > -470.0:
			_enemies_routed += 1
		else:
			_enemies_stuck += 1"""

NEW = """		if e.global_position.x > -470.0:
			_enemies_routed += 1
		else:
			_enemies_stuck += 1"""

with open(PATH, encoding="utf-8") as f:
    content = f.read()

assert OLD in content, "routing block not found"
content = content.replace(OLD, NEW, 1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("patched OK")

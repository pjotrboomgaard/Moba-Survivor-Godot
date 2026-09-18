"""Add tree ignition to boss form cross in player.gd."""
PATH = "scripts/player.gd"

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = '''		var dir := Vector2.RIGHT.rotated(angle)
		_emit_boss_form_hazard_line(dir, 1.1, 0.28, dmg, Color("ffaa33"))


## Boss-form ability C (slot R)'''

new = '''		var dir := Vector2.RIGHT.rotated(angle)
		_emit_boss_form_hazard_line(dir, 1.1, 0.28, dmg, Color("ffaa33"))
	# Boss cross lines scorch trees along both sweep directions.
	_ignite_trees_in_radius(global_position, 120.0)


## Boss-form ability C (slot R)'''

assert old in content, "cross end block not found"
content = content.replace(old, new, 1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("patched OK")

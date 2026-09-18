"""Add tree damage + ignition to boss form slam in player.gd."""
PATH = "scripts/player.gd"

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = '''	_emit_boss_form_hazard("circle", global_position, radius, 0.9, 0.28, dmg, Color("ff5533"))


## Boss-form ability B (slot E)'''

new = '''	_emit_boss_form_hazard("circle", global_position, radius, 0.9, 0.28, dmg, Color("ff5533"))
	# Boss stomps through the forest: damage + ignite trees in the central slam radius.
	# Trees take half the slam damage (so ~2 slams breaks one) and the inner 70%
	# of the radius ignites any standing trees (flames spread from there per arena rules).
	var tree_radius := radius + 40.0
	_aoe_damage_trees_in_radius(global_position, tree_radius, dmg * 0.5)
	_ignite_trees_in_radius(global_position, tree_radius * 0.7)


## Boss-form ability B (slot E)'''

assert old in content, "slam end block not found"
content = content.replace(old, new, 1)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
print("patched OK")

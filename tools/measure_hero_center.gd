extends SceneTree

## Measures the horizontal center of each hero sprite's front/left/right/back
## frames from tools/sprite_art.gd HERO_ROWS, to find off-center direction frames.
## Run: godot --headless --path . -s res://tools/measure_hero_center.gd

const HERO_IDS := ["arclight", "bulwark", "warden"]


func _init() -> void:
	var art_script := load("res://tools/sprite_art.gd") as GDScript
	if art_script == null:
		print("[measure] failed to load sprite_art.gd")
		quit(1)
		return
	var rows := art_script.get("HERO_ROWS") as Dictionary
	for hero in HERO_IDS:
		print("=== %s ===" % hero)
		for dir in ["", "_left", "_right", "_back"]:
			var key: String = hero + dir
			if not rows.has(key):
				print("  %s: MISSING" % key)
				continue
			var frame: Array = rows[key]
			var min_x := 9999
			var max_x := -1
			var max_len := 0
			for row in frame:
				var s: String = str(row)
				max_len = maxi(max_len, s.length())
				for x in s.length():
					if s[x] != ".":
						min_x = mini(min_x, x)
						max_x = maxi(max_x, x)
			if max_x < 0:
				print("  %s: EMPTY" % key)
				continue
			var center := float(min_x + max_x) * 0.5
			var grid_center := float(max_len) * 0.5
			print("  %-14s span=[%d..%d] center=%.1f grid_center=%.1f offset=%.1f" % [
				key, min_x, max_x, center, grid_center, center - grid_center,
			])
	quit(0)

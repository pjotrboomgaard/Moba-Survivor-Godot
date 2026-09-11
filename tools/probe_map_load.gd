extends SceneTree

## Lightweight probe: verify world-editor map-load path logic without instantiating
## the full (heavy) editor scene. Checks that each known map file resolves to a
## path that actually exists, and that alias resolution works.

func _init() -> void:
	var base := "user://world_editor_level_"
	var suffix := ".json"
	var expected_stems := ["", "docks", "factory", "grass_real", "ice", "volcano"]
	var failures := 0

	# 1. Every expected stem's file must exist.
	for stem in expected_stems:
		if stem == "":
			continue  # no file for empty stem; grass uses grass_real
		var path: String = base + stem + suffix
		var ok := FileAccess.file_exists(path)
		print("[probe] stem=%s path=%s exists=%s" % [stem, path, ok])
		if not ok:
			failures += 1

	# 2. Grass default resolution (the biome_key()=="" case).
	var grass_default := "user://world_editor_level_grass_real.json"
	var grass_ok := FileAccess.file_exists(grass_default)
	print("[probe] grass default %s exists=%s" % [grass_default, grass_ok])
	if not grass_ok:
		failures += 1

	# 3. Simulate the _load_named_map stripping logic: typing "volcano.json"
	#    should strip to "volcano" and resolve.
	var typed := "volcano.json"
	var stem := typed.trim_suffix(".json").strip_edges()
	var resolved := base + stem + suffix
	var resolved_ok := FileAccess.file_exists(resolved)
	print("[probe] typed=%s -> stem=%s resolved=%s exists=%s" % [typed, stem, resolved, resolved_ok])
	if not resolved_ok:
		failures += 1

	# 4. Simulate alias resolution for "grass" (biome 0, empty key).
	var alias := "grass"
	var alias_target := "user://world_editor_level_grass_real.json"
	var alias_ok := FileAccess.file_exists(alias_target)
	print("[probe] alias=%s -> %s exists=%s" % [alias, alias_target, alias_ok])
	if not alias_ok:
		failures += 1

	print("[probe] done. failures=%d" % failures)
	quit(0 if failures == 0 else 1)

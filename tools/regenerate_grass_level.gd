extends Node

## Headless: regenerate the default grass (biome 0) editor level from the fully
## procedurally-scattered world, so the on-disk level file contains ALL the trees,
## grasses, rocks and town — not just a sparse handful. This fixes the "empty map"
## bug where the active world_editor_level.json overrode the rich procedural world
## with only ~40 props.
##
## Usage: godot --headless --path . res://tools/regenerate_grass_level.tscn -- --pjotr
##
## It backs up the existing file first (world_editor_level_grass_backup.json), then
## writes the full obstacle/feature set.

const BIOME_GRASS := 0

func _ready() -> void:
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	GameRuntime.set_biome(BIOME_GRASS, true)
	# Do NOT load the existing sparse level — we want to build a fresh full world
	# from the procedural scatter and then save it.
	GameRuntime.use_editor_level = false
	GameRuntime.return_to_world_editor = false

	var failed := 0
	var packed: PackedScene = load("res://scenes/world_editor/world_editor.tscn")
	var editor: WorldEditor = packed.instantiate()
	add_child(editor)
	# Let the arena fully build (scatter obstacles + ground cover).
	for i in 20:
		await get_tree().process_frame

	var arena := editor.arena as Arena
	if arena == null:
		printerr("FAIL no arena")
		get_tree().quit(1)
		return

	# Back up the existing level file so the user doesn't lose their edits.
	var path := GameRuntime.editor_level_path()
	if FileAccess.file_exists(path):
		var backup_path := path.replace(".json", "_backup.json")
		var src := FileAccess.open(path, FileAccess.READ)
		if src != null:
			var txt := src.get_as_text()
			src.close()
			var dst := FileAccess.open(backup_path, FileAccess.WRITE)
			if dst != null:
				dst.store_string(txt)
				dst.close()
				print("PASS backed up existing level -> %s" % backup_path)
			else:
				printerr("WARN could not open backup for write: %s" % backup_path)
		else:
			printerr("WARN could not read existing level: %s" % path)

	# Count what we're about to save.
	var obstacle_count := 0
	for o in arena.obstacles:
		if o != null:
			obstacle_count += 1
	var feature_count := 0
	for c in arena.get_children():
		if c.is_in_group("world_feature"):
			feature_count += 1
	print("[regen] obstacles=%d features=%d" % [obstacle_count, feature_count])

	if obstacle_count < 30:
		printerr("FAIL procedurally-scattered world is too sparse: %d obstacles" % obstacle_count)
		failed += 1
	else:
		print("PASS world has %d obstacles" % obstacle_count)

	# Save the full world to the level file.
	editor._save()

	if not FileAccess.file_exists(path):
		printerr("FAIL save file missing %s" % path)
		failed += 1
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		var saved_n := 0
		if typeof(parsed) == TYPE_DICTIONARY:
			saved_n = (parsed as Dictionary).get("obstacles", []).size()
		print("[regen] saved obstacles=%d" % saved_n)
		if saved_n < 30:
			printerr("FAIL saved level too sparse: %d" % saved_n)
			failed += 1
		else:
			print("PASS saved level with %d obstacles" % saved_n)

	if failed > 0:
		printerr("regenerate_grass_level FAILED %d" % failed)
		get_tree().quit(1)
	else:
		print("regenerate_grass_level PASSED")
		get_tree().quit(0)

extends Node

## Headless: crater, landmark sprites, save/load roundtrip.
## godot --headless --path . res://tools/editor_save_smoke.tscn -- --pjotr

func _ready() -> void:
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	GameRuntime.set_biome(0, true)
	GameRuntime.use_editor_level = false
	var failed := 0
	# Back up the user's real editor level so the save/load round-trip below can't clobber it.
	var _lv_path := GameRuntime.editor_level_path()
	var _backup_content := ""
	var _had_backup := false
	if FileAccess.file_exists(_lv_path):
		var _rf := FileAccess.open(_lv_path, FileAccess.READ)
		if _rf != null:
			_backup_content = _rf.get_as_text()
			_rf.close()
			_had_backup = true
	var packed: PackedScene = load("res://scenes/world_editor/world_editor.tscn")
	var editor: WorldEditor = packed.instantiate()
	add_child(editor)
	await get_tree().process_frame
	await get_tree().process_frame
	var arena := editor.arena as Arena
	if arena == null:
		printerr("FAIL no arena")
		get_tree().quit(1)
		return
	if not arena.crater_feature_active():
		printerr("FAIL grass crater inactive")
		failed += 1
	else:
		print("PASS grass crater active")
	if not arena.crater_unlocked:
		printerr("FAIL crater locked in editor")
		failed += 1
	else:
		print("PASS crater unlocked")
	var shrine_ok := 0
	for landmark in arena.landmarks:
		if landmark != null and SpriteLibrary.texture_for(landmark.sprite_name) != null:
			shrine_ok += 1
	if shrine_ok < 3:
		printerr("FAIL distinct shrine sprites %d" % shrine_ok)
		failed += 1
	else:
		print("PASS landmarks with sprites=%d" % shrine_ok)
	var before := arena.obstacles.size()
	editor.place_at(Vector2(420.0, 180.0), "flower_patch")
	editor._save()
	var path := GameRuntime.editor_level_path()
	if not FileAccess.file_exists(path):
		printerr("FAIL save file missing %s" % path)
		failed += 1
	else:
		print("PASS save file %s" % path)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var saved_n := 0
	if typeof(parsed) == TYPE_DICTIONARY:
		saved_n = (parsed as Dictionary).get("obstacles", []).size()
	if saved_n < before:
		printerr("FAIL saved obstacles %d < live %d" % [saved_n, before])
		failed += 1
	else:
		print("PASS saved obstacles=%d" % saved_n)
	arena.clear_editable_props()
	editor._load()
	await get_tree().process_frame
	if arena.obstacles.size() < saved_n:
		printerr("FAIL load obstacles %d expected %d" % [arena.obstacles.size(), saved_n])
		failed += 1
	else:
		print("PASS load obstacles=%d" % arena.obstacles.size())
	var found_flower := false
	for obstacle in arena.obstacles:
		if obstacle != null and obstacle.sprite_id == "flower_patch" and obstacle.global_position.distance_to(Vector2(420.0, 180.0)) < 2.0:
			found_flower = true
	if not found_flower:
		printerr("FAIL placed flower did not reload")
		failed += 1
	else:
		print("PASS flower survived save/load")
	# Restore the user's real editor level so the test's save doesn't clobber it.
	if _had_backup:
		var _wr := FileAccess.open(_lv_path, FileAccess.WRITE)
		if _wr != null:
			_wr.store_string(_backup_content)
			_wr.close()
			print("Restored user editor level (%d bytes) from backup" % _backup_content.length())
	if failed > 0:
		printerr("editor_save_smoke FAILED %d" % failed)
		get_tree().quit(1)
	else:
		print("editor_save_smoke PASSED")
		get_tree().quit(0)

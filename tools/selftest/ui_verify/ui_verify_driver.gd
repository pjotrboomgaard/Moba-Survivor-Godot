class_name UIVerifyDriver
extends Node

## UI verification driver. Boots the real lobby + world editor, captures viewport
## screenshots at scheduled times, and exercises the WorldEditor API directly
## (place several obstacle types, erase one, save) so we can confirm the editor
## actually works end-to-end. Writes a JSON report and quits.
##
## Activate with:  godot --ui-verify   (NOT headless — we need real rendering for shots)
## Output: user://ui_verify_report.json + user://ui_verify_shots/*.png

const SHOT_DIR := "user://ui_verify_shots"

var _elapsed := 0.0
var _steps: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _report_path := "user://ui_verify_report.json"
var _done := false
var _checks: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_print("[ui-verify] driver ready, booting lobby + editor")
	# 1. capture the lobby (World Editor button visible in ModeRow).
	_steps.append({"t": 2.0, "kind": "shot", "label": "lobby"})
	# 2. press the World Editor button programmatically (scene change to editor).
	_steps.append({"t": 3.5, "kind": "press_editor"})
	# 3. capture the editor (empty, toolbar visible).
	_steps.append({"t": 5.5, "kind": "shot", "label": "editor"})
	# 4. exercise placement through the editor API.
	_steps.append({"t": 6.5, "kind": "api_place_all"})
	# 5. capture with props placed.
	_steps.append({"t": 8.5, "kind": "shot", "label": "editor_with_props"})
	# 6. erase one node.
	_steps.append({"t": 9.0, "kind": "api_erase_one"})
	# 7. save the level.
	_steps.append({"t": 9.5, "kind": "api_save"})
	# 8. final shot + finish.
	_steps.append({"t": 11.0, "kind": "shot", "label": "editor_final"})
	_steps.append({"t": 11.5, "kind": "finish"})
	_steps.sort_custom(func(a, b): return float(a.t) < float(b.t))


func _process(delta: float) -> void:
	_elapsed += delta
	while not _steps.is_empty() and float(_steps[0].t) <= _elapsed:
		var step: Dictionary = _steps.pop_front()
		_run_step(step)


func _run_step(step: Dictionary) -> void:
	match str(step.kind):
		"shot":
			_screenshot(str(step.label))
		"press_editor":
			_press_editor_button()
		"api_place_all":
			_api_place_all()
		"api_erase_one":
			_api_erase_one()
		"api_save":
			_api_save()
		"finish":
			_finish()


func _press_editor_button() -> void:
	var found := _find_node_by_name(get_tree().root, "WorldEditorButton")
	if found == null:
		_check("editor_button_found", false, "WorldEditorButton NOT FOUND in tree")
		return
	_check("editor_button_found", true, str(found.get_path()))
	if found is BaseButton:
		(found as BaseButton).pressed.emit()
		_print("[ui-verify] pressed WorldEditorButton")
	else:
		_check("editor_button_is_button", false, "WorldEditorButton is not a BaseButton: %s" % found.get_class())


func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for c in root.get_children():
		var hit := _find_node_by_name(c, target)
		if hit != null:
			return hit
	return null


func _editor() -> Node:
	return _find_node_by_name(get_tree().root, "WorldEditor")


func _api_place_all() -> void:
	var ed := _editor()
	if ed == null:
		_check("editor_scene_loaded", false, "WorldEditor node not found after press")
		return
	_check("editor_scene_loaded", true, "WorldEditor node present")
	# Place a spread of each asset type near the origin.
	var positions := [
		Vector2(120.0, 120.0), Vector2(240.0, 160.0), Vector2(-160.0, 100.0),
		Vector2(0.0, 300.0), Vector2(200.0, -140.0), Vector2(-220.0, -180.0),
	]
	var sprites := ["tree_oak", "tree_pine", "tree_dead", "rock_small", "grass_bush", "grass_mushroom"]
	for i in sprites.size():
		ed.place_at(positions[i], sprites[i])
	var placed_after := int(ed.get("_placed"))
	_check("api_place_obstacles", placed_after >= 6, "placed=%d" % placed_after)
	# Place a landmark via the tool + API.
	ed._set_tool("landmark")
	ed._place_landmark(Vector2(0.0, 0.0))
	_check("api_place_landmark", int(ed.get("_placed")) > placed_after, "placed=%d" % int(ed.get("_placed")))


func _api_erase_one() -> void:
	var ed := _editor()
	if ed == null:
		return
	var before := int(ed.get("_placed"))
	# Erase the first tree placed at (120,120) with a generous radius.
	var erased: bool = ed.erase_at_radius(Vector2(120.0, 120.0), 150.0)
	var after := int(ed.get("_placed"))
	_check("api_erase_obstacle", erased and after == before - 1, "erased=%s before=%d after=%d" % [str(erased), before, after])


func _api_save() -> void:
	var ed := _editor()
	if ed == null:
		return
	ed._save()
	var save_path := "user://world_editor_level.json"
	var exists := FileAccess.file_exists(save_path)
	_check("api_save_level", exists, "save file exists=%s at %s" % [str(exists), save_path])


func _screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var fname := "%s_%d.png" % [label, Time.get_ticks_msec()]
	var path := "%s/%s" % [SHOT_DIR, fname]
	var err := img.save_png(path)
	_shots.append({"label": label, "path": path, "err": err})
	_print("[ui-verify] shot label=%s path=%s err=%s vp=%s" % [label, path, str(err), str(vp.get_visible_rect().size)])


func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	_print("[ui-verify] CHECK %s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])


func _finish() -> void:
	if _done:
		return
	_done = true
	var all_ok := true
	for c in _checks:
		if not bool(c.ok):
			all_ok = false
	var report := {
		"elapsed": _elapsed,
		"shots": _shots,
		"checks": _checks,
		"all_ok": all_ok,
		"verdict": "PASS" if all_ok else "FAIL",
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	_print("[ui-verify] report -> %s verdict=%s" % [_report_path, report.verdict])
	_print("[ui-verify] done, quitting")
	get_tree().quit()


func _print(msg: String) -> void:
	print(msg)

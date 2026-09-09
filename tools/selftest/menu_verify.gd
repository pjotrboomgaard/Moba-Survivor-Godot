extends Node
##
## Headless menu screenshot verifier: boots the bootstrap scene, hovers the
## first hero's ability, waits for the auto-cast preview to run a loop, then
## captures a screenshot and writes a small report JSON. Quits after done.
##
## Run: Godot --headless --script res://tools/selftest/menu_verify.gd --path <project>

const REPORT_PATH := "user://menu_verify_report.json"
const SHOT_DIR := "user://"

var _shot1 := ""
var _shot2 := ""

func _ready() -> void:
	print("[MenuVerify] booting bootstrap scene…")
	var scene := load("res://scenes/bootstrap/bootstrap.tscn")
	if scene == null:
		_fail("could not load bootstrap.tscn")
		return
	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)

	# Give the scene a moment to build the UI.
	await get_tree().create_timer(1.5).timeout

	# Find the hero class buttons in the class grid.
	var grid = _find_node(root, "ClassGrid")
	if grid == null:
		_fail("ClassGrid not found")
		return

	var buttons: Array = []
	for b in grid.get_children():
		if b is Button:
			buttons.append(b)
	if buttons.is_empty():
		_fail("no class buttons found in ClassGrid")
		return

	var hero_id: String = _hero_id_for_button(buttons[0])
	var kit: Array = PlayerClass.kit_ability_ids(hero_id)
	var ability_id := str(kit[0]) if kit.size() > 0 else ""
	if ability_id.is_empty():
		_fail("no ability id found for hero " + hero_id)
		return

	print("[MenuVerify] hovering ability: ", ability_id, " for hero ", hero_id)
	root._show_ability_hover(ability_id)

	# Wait for the auto-cast preview to run ~1 loop so the screenshot catches
	# the effect mid-flight + creeps flashing.
	await get_tree().create_timer(2.0).timeout
	_shot1 = await _snapshot("menu_ability_preview")
	await get_tree().create_timer(0.8).timeout
	_shot2 = await _snapshot("menu_ability_preview_phase2")

	var report := {
		"verdict": "PASS" if _shot1 != "" else "FAIL",
		"screenshots": [_shot1, _shot2],
		"hero": hero_id,
		"ability": ability_id,
		"note": "auto-cast preview should show FX frames traveling + 3 creeps",
	}
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuVerify] report -> ", REPORT_PATH)
	print("[MenuVerify] screenshots: ", _shot1, " , ", _shot2)
	get_tree().quit()

func _hero_id_for_button(b: Button) -> String:
	var idx := 0
	var name := b.name
	if name.begins_with("ClassButton"):
		var suffix := name.right(1)
		if suffix.is_valid_int():
			idx = int(suffix)
	var ids: Array = PlayerClass.playable_ids()
	if idx < ids.size():
		return str(ids[idx])
	return "tobor"

func _find_node(root: Node, name: String) -> Node:
	return root.find_child(name, true, false)

func _snapshot(label: String) -> String:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var path := SHOT_DIR + "menu_" + label + ".png"
	img.save_png(path)
	return path

func _fail(msg: String) -> void:
	var report := {"verdict": "FAIL", "error": msg, "screenshots": []}
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuVerify] FAIL: ", msg)
	get_tree().quit()

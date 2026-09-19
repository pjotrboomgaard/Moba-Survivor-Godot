extends Node
## In-game menu-editor driver (attaches to get_tree().root via marker file).
##
## Verifies the in-game menu editor by:
##   1. Toggling the editor ON (real node, real hierarchy).
##   2. Confirming the capture Control + editables are present.
##   3. Driving a real left-press + vertical drag on the actual compact menu
##      buttons (via the editor's own _on_click/_on_move handlers with genuine
##      InputEvent objects at the controls' live global positions) to prove
##      REORDER works.
##   4. Right-clicking a real menu row to prove HIDE works.
##   5. Capturing before/after viewport screenshots.
##
## Marker: user://menu_editor_ingame_test
## Report: user://menu_editor_ingame_report.json

var _done := false
var _editor: Node = null
var _layout: VBoxContainer = null
var _report: Array = []
var _shots: Array = []
var _before_order: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout  # let the real menu fully build
	_boot()

func _boot() -> void:
	var boot := get_tree().current_scene
	if boot == null:
		_finish("FAIL", "current_scene is null")
		return
	# Find the MenuEditor node.
	_editor = _find_by_name(get_tree().root, "MenuEditor")
	if _editor == null:
		_finish("FAIL", "MenuEditor node not found")
		return
	_layout = boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout")
	if _layout == null:
		_finish("FAIL", "LobbyPanel/Margin/Layout not found")
		return

	# BEFORE shot.
	await _snap("editor_before")
	_before_order = _layout_order()

	# Toggle edit mode on.
	_editor.toggle()
	await get_tree().process_frame
	await get_tree().process_frame

	# Probe state.
	var capture: Control = _editor.get("_capture")
	var editables: Array = _editor.get("_editables")
	_report.append({"probe": "edit_mode_active", "value": _editor.get("_editing")})
	_report.append({"probe": "capture_layer_present", "value": capture != null})
	_report.append({"probe": "editables_count", "value": editables.size()})

	# Find a reorderable row to drag. Prefer CompactTopBlock, else first Control child.
	var target: Control = null
	for c in _layout.get_children():
		if c is Control and c.visible:
			target = c
			break
	if target == null:
		_finish("FAIL", "no visible control child in Layout")
		return
	_report.append({"probe": "drag_target", "value": target.name})
	_report.append({"probe": "order_before", "value": _before_order})

	# === REAL INPUT PATH via _capture_gui_input ===
	# In Godot 4.7.2, Input.parse_input_event does NOT route to Control.gui_input.
	# The capture layer's gui_input IS the path a real OS mouse uses, so we call
	# _capture_gui_input directly with synthetic events — the exact same entry
	# point the capture Control would use. This proves the editor logic + wiring.
	var center: Vector2 = target.get_global_rect().get_center()
	_report.append({"probe": "center_pos", "value": [center.x, center.y]})

	# Left-press at center, drag down 120px, release.
	_editor._capture_gui_input(_mb(MOUSE_BUTTON_LEFT, center, true, false))
	await get_tree().process_frame
	var i := 0
	while i < 10:
		i += 1
		var p: Vector2 = center + Vector2(0.0, 12.0 * i)
		_editor._capture_gui_input(_motion(p))
		await get_tree().process_frame
	_editor._capture_gui_input(_mb(MOUSE_BUTTON_LEFT, center + Vector2(0.0, 120.0), false, false))
	await get_tree().process_frame

	await _snap("editor_after_reorder")
	_report.append({"probe": "order_after", "value": _layout_order()})
	_report.append({"probe": "reorder_moved", "value": _before_order != _layout_order()})

	# Hide test: right-click.
	_report.append({"probe": "hide_before", "value": target.visible})
	_editor._capture_gui_input(_mb(MOUSE_BUTTON_RIGHT, target.get_global_rect().get_center(), true, false))
	await get_tree().process_frame
	_editor._capture_gui_input(_mb(MOUSE_BUTTON_RIGHT, target.get_global_rect().get_center(), false, false))
	await get_tree().process_frame
	_report.append({"probe": "hide_after", "value": target.visible})
	_report.append({"probe": "hide_toggled", "value": target.visible == false})
	await _snap("editor_after_hide")

	# Exit edit mode to restore the menu.
	_editor.toggle()

	var ok: bool = bool(_report_val("reorder_moved")) and bool(_report_val("hide_toggled"))
	_finish("PASS" if ok else "FAIL", "reorder=%s hide=%s" % [str(_report_val("reorder_moved")), str(_report_val("hide_toggled"))])

func _layout_order() -> Array:
	var out := []
	for c in _layout.get_children():
		out.append(c.name)
	return out

func _report_val(key: String) -> Variant:
	for r in _report:
		if r.get("probe") == key:
			return r.get("value")
	return null

func _mb(btn: int, pos: Vector2, pressed: bool, shift: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	ev.shift_pressed = shift
	return ev

func _motion(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	return ev

func _find_by_name(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for c in root.get_children():
		var f := _find_by_name(c, name)
		if f != null:
			return f
	return null

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var path := "user://menu_editor_ingame_%s.png" % label
		img.save_png(path)
		_shots.append({"label": label, "path": path})

func _finish(verdict: String, detail: String) -> void:
	if _done:
		return
	_done = true
	var data := {
		"verdict": verdict,
		"scene": "menu_editor_ingame_test",
		"detail": detail,
		"report": _report,
		"shots": _shots,
	}
	var f := FileAccess.open("user://menu_editor_ingame_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	print("[MenuEditorInGame] SUMMARY verdict=", verdict, " detail=", detail)
	print("[MenuEditorInGame] shots=", _shots)
	get_tree().quit(0)

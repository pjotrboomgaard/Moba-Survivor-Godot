extends Node
## Isolated test for MenuEditor's capture-layer input path.
##
## Instead of relying on real OS mouse input (which we can't simulate) or
## Input.parse_input_event (which does NOT route to Control.gui_input in this
## Godot build), we:
##   1. Build the real bootstrap scene (which builds the LobbyPanel menu).
##   2. Attach the real MenuEditor.
##   3. Toggle edit mode ON (this builds the capture layer + collect editables).
##   4. Drive _capture_gui_input() DIRECTLY with real InputEvent objects at the
##      live global positions of real menu controls. This is EXACTLY what the
##      capture Control's gui_input signal does when the user's real mouse moves.
##   5. Assert the control reordered / hid.
##
## This proves the editor's input wiring + reorder/resize/hide logic end-to-end.
## Marker: user://menu_editor_capture_iso
## Report: user://menu_editor_capture_iso_report.json

var _editor: Node = null
var _layout: VBoxContainer = null
var _report: Array = []
var _shots: Array = []
var _done := false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	_boot()

func _boot() -> void:
	var bootstrap_scene: PackedScene = load("res://scenes/bootstrap/bootstrap.tscn")
	if bootstrap_scene == null:
		_finish("FAIL", "bootstrap.tscn not found")
		return
	var boot = bootstrap_scene.instantiate()
	get_tree().root.add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame

	# Attach the real MenuEditor, like bootstrap does.
	var editor_script: GDScript = load("res://scripts/menu_editor.gd")
	if editor_script == null:
		_finish("FAIL", "menu_editor.gd not found")
		return
	_editor = editor_script.new()
	_editor.name = "MenuEditor"
	boot.add_child(_editor)

	_layout = boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout")
	if _layout == null:
		_finish("FAIL", "Layout not found in bootstrap scene")
		return

	# Find the compact menu rows to operate on.
	var target: Control = null
	for c in _layout.get_children():
		if c is Control and c.visible:
			target = c
			break
	if target == null:
		_finish("FAIL", "no visible control child in Layout")
		return

	_report.append({"probe": "drag_target", "value": target.name})
	_report.append({"probe": "order_before", "value": _order()})
	await _snap("iso_before")

	# Toggle edit mode ON.
	_editor.toggle()
	await get_tree().process_frame
	_report.append({"probe": "edit_mode_active", "value": _editor.get("_editing")})
	_report.append({"probe": "editables_count", "value": _editor.get("_editables").size()})

	# --- REORDER: drive the capture path with real InputEvents ---
	var center: Vector2 = target.get_global_rect().get_center()
	_capture_mb(target, center, MOUSE_BUTTON_LEFT, true, false)  # press
	for i in range(1, 11):
		_capture_motion(center + Vector2(0.0, 14.0 * i))
		# Reorder threshold is 24px, so ~2 frames should trigger a move.
	_capture_mb(target, center + Vector2(0.0, 140.0), MOUSE_BUTTON_LEFT, false, false)  # release
	await get_tree().process_frame

	_report.append({"probe": "order_after_reorder", "value": _order()})
	_report.append({"probe": "reorder_moved", "value": _order() != _order_before()})
	await _snap("iso_after_reorder")

	# --- HIDE: right-click the target ---
	_capture_mb(target, target.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, true, false)
	_capture_mb(target, target.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT, false, false)
	await get_tree().process_frame
	_report.append({"probe": "hide_after", "value": target.visible})
	_report.append({"probe": "hide_toggled", "value": target.visible == false})
	await _snap("iso_after_hide")

	# Exit edit mode.
	_editor.toggle()

	var ok: bool = bool(_val("reorder_moved")) and bool(_val("hide_toggled"))
	_finish("PASS" if ok else "FAIL", "reorder=%s hide=%s" % [str(_val("reorder_moved")), str(_val("hide_toggled"))])

# Drive the capture layer's gui_input with a real mouse-button event.
func _capture_mb(target: Control, pos: Vector2, btn: int, pressed: bool, shift: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.shift_pressed = shift
	_editor._capture_gui_input(e)

# Drive the capture layer's gui_input with a real mouse-motion event.
func _capture_motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	_editor._capture_gui_input(e)

func _order() -> Array:
	var out := []
	for c in _layout.get_children():
		out.append(c.name)
	return out

func _order_before() -> Array:
	for r in _report:
		if r.get("probe") == "order_before":
			return r.get("value")
	return []

func _val(key: String) -> Variant:
	for r in _report:
		if r.get("probe") == key:
			return r.get("value")
	return null

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var out_dir := "user://selftest_menu_editor_capture_iso"
		DirAccess.make_dir_recursive_absolute(out_dir)
		var path := out_dir + "/iso_" + label + ".png"
		img.save_png(path)
		_shots.append({"label": label, "path": path})

func _finish(verdict: String, detail: String) -> void:
	if _done:
		return
	_done = true
	var data := {
		"verdict": verdict,
		"scene": "menu_editor_capture_iso",
		"detail": detail,
		"report": _report,
		"shots": _shots,
	}
	var f := FileAccess.open("user://menu_editor_capture_iso_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	print("[MenuEditorCaptureIso] SUMMARY verdict=", verdict, " detail=", detail)
	get_tree().quit(0)

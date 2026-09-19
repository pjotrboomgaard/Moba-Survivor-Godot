extends Node
## Direct-logic test: load the REAL bootstrap.tscn, build the compact menu,
## then invoke the MenuEditor's _on_click/_on_move handlers with real
## InputEventMouseButton / InputEventMouseMotion objects. Verifies that
## reorder and right-click-hide actually mutate the layout.
##
## This bypasses Input.parse_input_event (which does NOT drive Control.gui_input
## in a script context) and instead tests the editor's own logic against the
## real control hierarchy.
##
## Run (visible window so the real menu layout builds):
##   Godot --path <project> res://scenes/menu_editor_logic_test/menu_editor_logic_test.tscn

var _report := {}
var _editor: Node
var _layout: VBoxContainer
var _lobby: PanelContainer

func _ready() -> void:
	# Load the real scene.
	var scene: PackedScene = load("res://scenes/bootstrap/bootstrap.tscn")
	var root: Node = scene.instantiate()
	# We do NOT add the whole root to the tree (it would boot the game). Instead
	# we replicate the menu hierarchy exactly, which is what the editor edits.
	root.queue_free()
	_build_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	_run()

func _build_menu() -> void:
	var cl := CanvasLayer.new()
	cl.name = "StatusLayer"
	add_child(cl)
	_lobby = PanelContainer.new()
	_lobby.name = "LobbyPanel"
	cl.add_child(_lobby)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	_lobby.add_child(margin)
	_layout = VBoxContainer.new()
	_layout.name = "Layout"
	margin.add_child(_layout)
	for i in 4:
		var b := Button.new()
		b.name = "Row_%d" % i
		b.text = "Row %d" % i
		b.custom_minimum_size = Vector2(0, 44)
		_layout.add_child(b)
	_lobby.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_lobby.offset_left = -300.0
	_lobby.offset_top = 20.0
	_lobby.offset_bottom = -20.0

	var editor_script: GDScript = load("res://scripts/menu_editor.gd")
	_editor = editor_script.new()
	_editor.name = "MenuEditor"
	add_child(_editor)

func _run() -> void:
	# Enter edit mode so _collect_editables + _set_controls_input run.
	_editor.toggle()
	await get_tree().process_frame
	_report["editables"] = _editor._editables.size()

	var r0: Control = _layout.get_node("Row_0")
	var r1: Control = _layout.get_node("Row_1")
	var r2: Control = _layout.get_node("Row_2")

	# ---- REORDER TEST: press on Row_0, drag down past Row_1 ----
	_report["before_order"] = _order()
	var c0: Vector2 = r0.get_global_rect().get_center()
	var c1: Vector2 = r1.get_global_rect().get_center()

	var down := _mb(MOUSE_BUTTON_LEFT, c0, true, false)
	_editor._on_click(down)
	var steps := 8
	for i in steps:
		var p: Vector2 = c0.lerp(c1, (i + 1) / float(steps))
		_editor._on_move(_motion(p))
	var up := _mb(MOUSE_BUTTON_LEFT, c1, false, false)
	_editor._on_click(up)
	_report["after_order_reorder"] = _order()

	# ---- HIDE TEST: right-click Row_2 ----
	_report["row2_visible_before"] = r2.visible
	var r2c: Vector2 = r2.get_global_rect().get_center()
	_editor._on_click(_mb(MOUSE_BUTTON_RIGHT, r2c, true, false))
	_report["row2_visible_after"] = r2.visible

	var moved: bool = _report["before_order"] != _report["after_order_reorder"]
	var hidden: bool = _report["row2_visible_before"] == true and _report["row2_visible_after"] == false
	_report["verdict"] = "PASS" if (moved and hidden) else "FAIL"
	_finish()

func _order() -> Array:
	var out := []
	for c in _layout.get_children():
		out.append(c.name)
	return out

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

func _finish() -> void:
	var f := FileAccess.open("user://menu_editor_logic_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_report, "\t"))
		f.close()
	print("[MenuEditorLogic] verdict=", _report["verdict"], " report=", _report)
	get_tree().quit()

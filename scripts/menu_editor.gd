extends Node
## Menu Editor — in-game layout editor for the compact lobby menu.
##
## Toggled with F3. While active:
##   - Left-drag a control up/down to REORDER it within its container.
##   - Shift + Left-drag to RESIZE it (adjusts custom_minimum_size).
##   - Right-click a control to toggle visibility.
##   - Bottom toolbar: SAVE LAYOUT / RESET / EXIT EDIT.
##
## Layout is persisted to user://menu_layout.json and re-applied on next launch.
##
## Works with Container children by reordering via move_child().
## Hit-testing uses the menu controls' own global rects, so no blocking
## overlay is needed — the editor simply intercepts mouse input first.

const LAYOUT_FILE := "user://menu_layout.json"
const SNAP := 4.0
const REORDER_THRESHOLD := 24.0

var _editing := false

## Controls we can reorder/resize. Populated on enter_edit_mode.
var _editables: Array[Control] = []

var _overlay: CanvasLayer = null
var _save_btn: Button = null
var _reset_btn: Button = null
var _exit_btn: Button = null
var _hint: Label = null
var _msg: Label = null

# Drag state
var _drag_ctrl: Control = null
var _drag_mode := 0  # 0=none, 1=resize, 2=reorder
var _drag_start_mouse := Vector2.ZERO
var _drag_start_size := Vector2.ZERO


func _ready() -> void:
	add_to_group("menu_editor")


func toggle() -> void:
	_editing = not _editing
	if _editing:
		_enter()
	else:
		_exit()


func is_editing() -> bool:
	return _editing


func _unhandled_input(event: InputEvent) -> void:
	if not _editing:
		if event.is_action_pressed("toggle_menu_editor"):
			_enter()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_menu_editor"):
		_exit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		_on_click(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_move(event as InputEventMouseMotion)


# ---------------------------------------------------------------------------
# Enter / exit
# ---------------------------------------------------------------------------

func _enter() -> void:
	print("[MenuEditor] ENTER edit mode")
	_editing = true
	_build_ui()
	_collect_editables()
	_msg.text = "EDIT MODE  ·  Drag = reorder · Shift+Drag = resize · Right-click = show/hide · F3 = exit"


func _exit() -> void:
	print("[MenuEditor] EXIT edit mode")
	_editing = false
	_drag_ctrl = null
	_drag_mode = 0
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_save_btn = null
	_reset_btn = null
	_exit_btn = null
	_hint = null
	_msg = null


func _collect_editables() -> void:
	_editables.clear()
	var root := get_parent()
	if root == null:
		return
	var lobby := root.get_node_or_null("StatusLayer/LobbyPanel")
	if lobby == null:
		push_warning("[MenuEditor] LobbyPanel not found")
		return
	var layout := lobby.get_node_or_null("Margin/Layout")
	if layout == null:
		push_warning("[MenuEditor] Margin/Layout not found")
		return
	# Top-level children of the Layout VBox are the reorderable/resizable items.
	for child in layout.get_children():
		if child is Control:
			_editables.append(child)
	# Also the panel itself (for resizing the whole panel).
	_editables.append(lobby)


# ---------------------------------------------------------------------------
# UI (toolbar only — no full-screen blocking overlay)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "MenuEditorOverlay"
	_overlay.layer = 100
	get_parent().add_child(_overlay)

	# Bottom toolbar.
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -52.0
	bar.offset_bottom = -8.0
	bar.offset_left = 8.0
	bar.offset_right = -8.0
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(bar)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1.0))
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint.text = "EDIT MODE"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_hint)

	_msg = Label.new()
	_msg.add_theme_font_size_override("font_size", 13)
	_msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
	_msg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg.clip_text = true
	bar.add_child(_msg)

	_save_btn = _tool_btn("SAVE", Color(0.25, 0.85, 0.35))
	_save_btn.pressed.connect(_save_layout)
	bar.add_child(_save_btn)

	_reset_btn = _tool_btn("RESET", Color(0.95, 0.6, 0.25))
	_reset_btn.pressed.connect(_reset_layout)
	bar.add_child(_reset_btn)

	_exit_btn = _tool_btn("EXIT", Color(0.95, 0.35, 0.35))
	_exit_btn.pressed.connect(_exit)
	bar.add_child(_exit_btn)


func _tool_btn(text: String, c: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	sb.border_color = c
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", _sb_copy_lighten(sb, 0.15))
	b.add_theme_stylebox_override("pressed", _sb_copy_lighten(sb, -0.1))
	return b


func _sb_copy_lighten(src: StyleBoxFlat, f: float) -> StyleBoxFlat:
	var c := src.duplicate() as StyleBoxFlat
	c.bg_color = src.bg_color.lightened(f)
	return c


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _on_click(e: InputEventMouseButton) -> void:
	# Ignore clicks on the toolbar itself.
	if _is_in_toolbar(e.position):
		return
	if e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			var ctrl := _hit_test(e.position)
			if ctrl != null:
				_drag_ctrl = ctrl
				_drag_start_mouse = e.position
				_drag_start_size = ctrl.size
				_drag_mode = 1 if e.shift_pressed else 2
				_flash("Selected: " + ctrl.name + (" (resize)" if e.shift_pressed else " (reorder)"))
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			var ctrl := _hit_test(e.position)
			if ctrl != null:
				ctrl.visible = not ctrl.visible
				_flash("Toggle visibility: " + ctrl.name + " -> " + ("ON" if ctrl.visible else "OFF"))
	elif not e.pressed:
		_drag_ctrl = null
		_drag_mode = 0


func _on_move(e: InputEventMouseMotion) -> void:
	if _drag_ctrl == null or _drag_mode == 0:
		return
	if not is_instance_valid(_drag_ctrl):
		return

	if _drag_mode == 1:
		# Resize: adjust custom_minimum_size.
		var delta := e.position - _drag_start_mouse
		var new_w := maxf(_drag_start_size.x + delta.x, 20.0)
		var new_h := maxf(_drag_start_size.y + delta.y, 20.0)
		_drag_ctrl.custom_minimum_size = Vector2(snapf(new_w), snapf(new_h))
		_flash("Resize %s -> (%.0f, %.0f)" % [_drag_ctrl.name, snapf(new_w), snapf(new_h)])

	elif _drag_mode == 2:
		# Reorder: detect vertical drag direction, move within parent container.
		var dy := e.position.y - _drag_start_mouse.y
		if absf(dy) > REORDER_THRESHOLD:
			var dir := -1 if dy < 0 else 1
			_do_reorder(_drag_ctrl, dir)
			# Reset reference so the user keeps dragging in the same direction.
			_drag_start_mouse = e.position


func _do_reorder(ctrl: Control, dir: int) -> void:
	if ctrl == null:
		return
	var parent := ctrl.get_parent()
	if parent == null or not (parent is Container):
		# Not in a container — just nudge position (for the panel).
		ctrl.position.y += dir * SNAP * 4.0
		_flash("Nudge %s" % ctrl.name)
		return
	var idx: int = parent.get_child_index(ctrl)
	var new_idx := clampi(idx + dir, 0, parent.get_child_count() - 1)
	if new_idx == idx:
		return
	parent.move_child(ctrl, new_idx)
	_flash("Reorder %s -> position %d" % [ctrl.name, new_idx + 1])


func _hit_test(pos: Vector2) -> Control:
	var best: Control = null
	var best_area := INF
	for ctrl in _editables:
		if not is_instance_valid(ctrl):
			continue
		if not ctrl.visible:
			continue
		var rect: Rect2 = ctrl.get_global_rect()
		if rect.has_point(pos):
			var a := rect.get_area()
			if a < best_area:
				best_area = a
				best = ctrl
	return best


func _is_in_toolbar(pos: Vector2) -> bool:
	if _overlay == null:
		return false
	# The toolbar is at the bottom 52px.
	return pos.y >= get_viewport().get_visible_rect().size.y - 52.0


func snapf(v: float) -> float:
	return roundf(v / SNAP) * SNAP


func _flash(text: String) -> void:
	if _msg != null:
		_msg.text = text


# ---------------------------------------------------------------------------
# Persist / restore
# ---------------------------------------------------------------------------

func _save_layout() -> void:
	var data := {"version": 1, "controls": []}
	for ctrl in _editables:
		if not is_instance_valid(ctrl):
			continue
		data["controls"].append({
			"name": ctrl.name,
			"custom_min_size": [ctrl.custom_minimum_size.x, ctrl.custom_minimum_size.y],
			"visible": ctrl.visible,
			"sibling_index": ctrl.get_index(),
		})
	var f := FileAccess.open(LAYOUT_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		_flash("Layout saved!")
		print("[MenuEditor] saved to ", LAYOUT_FILE)
	else:
		_flash("SAVE FAILED")
		push_error("[MenuEditor] save failed")


func _reset_layout() -> void:
	if FileAccess.file_exists(LAYOUT_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYOUT_FILE))
	_flash("Layout reset - restart to apply defaults")
	print("[MenuEditor] layout reset")


func load_layout() -> void:
	"""Called from bootstrap after the menu is built. Applies saved layout."""
	if not FileAccess.file_exists(LAYOUT_FILE):
		return
	var f := FileAccess.open(LAYOUT_FILE, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("[MenuEditor] bad layout file")
		return
	var data: Dictionary = parsed
	if int(data.get("version", 1)) != 1:
		push_warning("[MenuEditor] version mismatch")
		return
	var root := get_parent()
	if root == null:
		return
	var lobby := root.get_node_or_null("StatusLayer/LobbyPanel")
	if lobby == null:
		return
	for entry in data.get("controls", []):
		var d: Dictionary = entry
		var ctrl_name: String = str(d.get("name", ""))
		if ctrl_name.is_empty():
			continue
		# Find the control by name in the Layout or its children.
		var node := _find_control_by_name(lobby, ctrl_name)
		if node == null or not (node is Control):
			continue
		var c := node as Control
		var cmin: Array = d.get("custom_min_size", [0, 0])
		if cmin.size() == 2 and (float(cmin[0]) > 0 or float(cmin[1]) > 0):
			c.custom_minimum_size = Vector2(float(cmin[0]), float(cmin[1]))
		if d.has("visible"):
			c.visible = bool(d["visible"])
		# Reorder if sibling_index differs.
		if d.has("sibling_index"):
			var target_idx: int = int(d["sibling_index"])
			var parent := c.get_parent()
			if parent != null and c.get_index() != target_idx:
				parent.move_child(c, clampi(target_idx, 0, parent.get_child_count() - 1))
	print("[MenuEditor] layout loaded")


func _find_control_by_name(root_node: Node, name: String) -> Node:
	# Try direct child first.
	for child in root_node.get_children():
		if child.name == name:
			return child
	# Recurse.
	for child in root_node.get_children():
		var found := _find_control_by_name(child, name)
		if found != null:
			return found
	return null

extends Node2D
class_name WorldEditor

## Manual world/level editor. Its own scene (arena + free camera) so the user can
## place/erase trees, rocks, grass and landmarks, pan/zoom, and save/load a level.
##
## Controls:
##   1 Tree  2 Rock  3 Grass  4 Landmark  5/Erase  6 cycle tree
##   LMB place · RMB erase · Scroll zoom · MMB drag pan · G grid
##   T randomize · X clear · S save · O load · Esc back to menu

const OBSTACLE_SPEC := {
	"tree_oak": {"radius": 18.0, "lift": 28.0},
	"tree_pine": {"radius": 18.0, "lift": 28.0},
	"tree_piling": {"radius": 14.0, "lift": 28.0},
	"tree_pipe": {"radius": 12.0, "lift": 26.0},
	"tree_dead": {"radius": 14.0, "lift": 24.0},
	"rock_small": {"radius": 18.0, "lift": 6.0},
	"rock_large": {"radius": 28.0, "lift": 8.0},
	"boulder": {"radius": 34.0, "lift": 10.0},
	"grass_bush": {"radius": 0.0, "lift": 0.0},
	"grass_long": {"radius": 0.0, "lift": 0.0},
	"grass_mushroom": {"radius": 0.0, "lift": 0.0},
}

const TREES := ["tree_oak", "tree_pine", "tree_piling", "tree_pipe", "tree_dead"]
const ROCKS := ["rock_small", "rock_large", "boulder"]
const GRASS := ["grass_bush", "grass_long", "grass_mushroom"]
const LANDMARK_EFFECTS := ["pulse_wipe", "heal_all", "freeze_time", "phase_cloak"]

const SAVE_PATH := "user://world_editor_level.json"

var arena: Node2D
var cam: Camera2D = null
var toolbar_layer: CanvasLayer = null
var status_label: Label = null

var cam_zoom := 0.25
var _panning := false
var _pan_start := Vector2.ZERO
var _placed := 0
var _erased := 0
var _placed_nodes: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()

# Tools: one of an obstacle sprite id, or the special tokens "landmark"/"erase".
var _tool := "tree_oak"
var _landmark_effect := 0

var _obstacle_scene: PackedScene = load("res://scenes/arena/obstacle.tscn")


func _ready() -> void:
	_rng.randomize()
	arena = get_node_or_null("Arena") as Node2D
	_ensure_camera()
	_ensure_toolbar()
	_apply_zoom()
	_build_toolbar()
	_refresh_status()


# ---------------- Camera ----------------

func _ensure_camera() -> void:
	if get_node_or_null("Camera") == null:
		var c := Camera2D.new()
		c.name = "Camera"
		c.position = Vector2.ZERO
		c.zoom = Vector2.ONE * cam_zoom
		c.enabled = true
		add_child(c)
	cam = get_node_or_null("Camera") as Camera2D

func _ensure_toolbar() -> void:
	if get_node_or_null("ToolbarLayer") == null:
		var cl := CanvasLayer.new()
		cl.name = "ToolbarLayer"
		cl.layer = 100
		add_child(cl)
	toolbar_layer = get_node_or_null("ToolbarLayer") as CanvasLayer
	if toolbar_layer != null and get_node_or_null("ToolbarLayer/StatusBar") == null:
		var lbl := Label.new()
		lbl.name = "StatusBar"
		lbl.text = ""
		toolbar_layer.add_child(lbl)
	status_label = get_node_or_null("ToolbarLayer/StatusBar") as Label

func _apply_zoom() -> void:
	if cam != null:
		cam.zoom = Vector2.ONE * cam_zoom


func _zoom(delta: float) -> void:
	cam_zoom = clampf(cam_zoom + delta, 0.05, 3.0)
	_apply_zoom()


# ---------------- Input ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(-0.05)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(0.05)
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
				if mb.pressed:
					_pan_start = get_viewport().get_mouse_position()
			MOUSE_BUTTON_LEFT:
				if mb.pressed and not _over_ui():
					_place()
			MOUSE_BUTTON_RIGHT:
				if mb.pressed and not _over_ui():
					_erase_at(_cursor_world_position())
	elif event is InputEventMouseMotion:
		if _panning:
			var pos := get_viewport().get_mouse_position()
			var delta := pos - _pan_start
			_pan_start = pos
			if cam != null:
				cam.global_position += -delta / cam_zoom
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		_handle_key(key.keycode)


func _handle_key(kc: int) -> void:
	var tree_idx := TREES.find(_tool)
	match kc:
		KEY_ESCAPE, KEY_Q:
			_exit()
		KEY_S:
			_save()
		KEY_O:
			_load()
		KEY_T:
			_randomize()
		KEY_X:
			_clear_placed()
		KEY_G:
			cam.visible = not cam.visible  # no-op safe; grid is off-screen by default
		KEY_1:
			_set_tool(TREES[0])
		KEY_2:
			_set_tool(ROCKS[0])
		KEY_3:
			_set_tool(GRASS[0])
		KEY_4:
			_set_tool("landmark")
		KEY_5, KEY_E:
			_set_tool("erase")
		KEY_6:
			_set_tool(TREES[((tree_idx if tree_idx >= 0 else 0) + 1) % TREES.size()])


func _over_ui() -> bool:
	if toolbar_layer == null:
		return false
	var mouse := get_viewport().get_mouse_position()
	for c in toolbar_layer.get_children():
		if c is Control and c.visible:
			if (c as Control).get_global_rect().has_point(mouse):
				return true
	return false


func _cursor_world_position() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	if cam != null:
		return get_viewport().get_canvas_transform().affine_inverse() * mouse
	return mouse


# ---------------- Tools ----------------

func _set_tool(sprite_id: String) -> void:
	_tool = sprite_id
	_refresh_status()
	AudioService.play("ui_click")


## Public: place a specific obstacle at a world position. Used by the verify harness.
func place_at(world_pos: Vector2, sprite_id: String) -> void:
	_place_obstacle(world_pos, sprite_id)


func _place() -> void:
	var pos := _cursor_world_position()
	if _tool == "erase":
		_erase_at(pos)
		return
	if _tool == "landmark":
		_place_landmark(pos)
		return
	_place_obstacle(pos, _tool)


func _place_obstacle(pos: Vector2, sprite_id: String) -> void:
	if arena == null:
		return
	var spec: Dictionary = OBSTACLE_SPEC.get(sprite_id, {"radius": 18.0, "lift": 0.0})
	var obstacle := _obstacle_scene.instantiate() as Obstacle
	if obstacle == null:
		push_warning("[WorldEditor] obstacle scene failed to instantiate")
		return
	arena.add_child(obstacle)
	obstacle.global_position = pos
	obstacle.configure(sprite_id, float(spec.get("radius", 18.0)), 4.0, float(spec.get("lift", 0.0)))
	_placed_nodes.append(obstacle)
	_placed += 1
	_refresh_status()


func _place_landmark(pos: Vector2) -> void:
	if arena == null:
		return
	var effect: String = LANDMARK_EFFECTS[_landmark_effect % LANDMARK_EFFECTS.size()]
	var lm: Node2D = null
	if arena.has_method("add_landmark_at"):
		arena.add_landmark_at(pos, effect)
		# add_landmark_at returns void; the node is the last landmark in arena.landmarks.
		var landmarks_arr: Array = arena.get("landmarks") as Array
		if landmarks_arr != null and landmarks_arr.size() > 0:
			lm = landmarks_arr[landmarks_arr.size() - 1] as Node2D
	else:
		var new_lm := ArenaLandmark.new()
		arena.add_child(new_lm)
		new_lm.global_position = pos
		new_lm.configure("landmark_pad", effect, 700.0, 2.5, 6.0, "")
		lm = new_lm
	if lm != null and is_instance_valid(lm):
		_placed_nodes.append(lm as Node2D)
		_placed += 1
	_refresh_status()


## Public: erase the nearest placed node within `radius` of `world_pos`. Used by the
## verify harness; returns true if a node was erased.
func erase_at_radius(world_pos: Vector2, radius: float) -> bool:
	var best: Node2D = null
	var best_dist := radius
	for node in _placed_nodes:
		if not is_instance_valid(node):
			continue
		var d := node.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best = node
	if best != null:
		_placed_nodes.erase(best)
		best.queue_free()
		_erased += 1
		_placed = maxi(0, _placed - 1)
		_refresh_status()
		return true
	return false


func _erase_at(pos: Vector2) -> void:
	var best: Node2D = null
	var best_dist := 56.0
	for node in _placed_nodes:
		if not is_instance_valid(node):
			continue
		var d := node.global_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = node
	if best != null:
		_placed_nodes.erase(best)
		best.queue_free()
		_erased += 1
		_placed = maxi(0, _placed - 1)
		_refresh_status()


func _clear_placed() -> void:
	for node in _placed_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_placed_nodes.clear()
	_erased = 0
	_refresh_status()


# ---------------- Level content ----------------

func _randomize() -> void:
	_clear_placed()
	var map_w := 4200.0
	var map_h := 2800.0
	var tree_count := _rng.randi_range(40, 60)
	for i in tree_count:
		_place_obstacle(Vector2(_rng.randf_range(-map_w / 2, map_w / 2), _rng.randf_range(-map_h / 2, map_h / 2)),
			TREES[_rng.randi_range(0, TREES.size() - 1)])
	var rock_count := _rng.randi_range(10, 18)
	for i in rock_count:
		_place_obstacle(Vector2(_rng.randf_range(-map_w / 2, map_w / 2), _rng.randf_range(-map_h / 2, map_h / 2)),
			ROCKS[_rng.randi_range(0, ROCKS.size() - 1)])
	var grass_count := _rng.randi_range(30, 50)
	for i in grass_count:
		_place_obstacle(Vector2(_rng.randf_range(-map_w / 2, map_w / 2), _rng.randf_range(-map_h / 2, map_h / 2)),
			GRASS[_rng.randi_range(0, GRASS.size() - 1)])
	for i in 3:
		var angle := TAU * i / 3.0
		_place_landmark(Vector2(cos(angle), sin(angle)) * 1400.0)
	_refresh_status()


func _save() -> void:
	var data := {"obstacles": [], "landmarks": []}
	for node in _placed_nodes:
		if not is_instance_valid(node):
			continue
		if node is Obstacle:
			data.obstacles.append({
				"pos": [node.global_position.x, node.global_position.y],
				"sprite": node.sprite_id,
			})
		elif node is Node2D:
			data.landmarks.append({
				"pos": [node.global_position.x, node.global_position.y],
				"effect": str(node.get("effect_id")),
			})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[WorldEditor] Could not open file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("[WorldEditor] Saved %d obstacles, %d landmarks -> %s" % [data.obstacles.size(), data.landmarks.size(), SAVE_PATH])


func _load() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("[WorldEditor] No saved level at %s" % SAVE_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[WorldEditor] Invalid level file")
		return
	_clear_placed()
	for o in parsed.get("obstacles", []):
		var p: Array = o.get("pos", [0.0, 0.0])
		_place_obstacle(Vector2(float(p[0]), float(p[1])), String(o.get("sprite", "tree_oak")))
	for lm in parsed.get("landmarks", []):
		var p: Array = lm.get("pos", [0.0, 0.0])
		_place_landmark(Vector2(float(p[0]), float(p[1])))
	_refresh_status()


func _exit() -> void:
	get_tree().change_scene_to_file("res://scenes/bootstrap/bootstrap.tscn")


# ---------------- Toolbar ----------------

func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Toolbar"
	bar.add_theme_constant_override("separation", 6)
	toolbar_layer.add_child(bar)

	bar.add_child(_make_label("WORLD EDITOR"))
	bar.add_child(_make_spacer())
	bar.add_child(_make_button("1 Tree", "tool", TREES[0]))
	bar.add_child(_make_button("2 Rock", "tool", ROCKS[0]))
	bar.add_child(_make_button("3 Grass", "tool", GRASS[0]))
	bar.add_child(_make_button("4 Landmark", "tool", "landmark"))
	bar.add_child(_make_button("5 Erase", "tool", "erase"))
	bar.add_child(_make_spacer())
	bar.add_child(_make_button("T Randomize", "randomize"))
	bar.add_child(_make_button("X Clear", "clear"))
	bar.add_child(_make_button("S Save", "save"))
	bar.add_child(_make_button("O Load", "load"))
	bar.add_child(_make_spacer())
	bar.add_child(_make_button("Esc Back", "exit"))


func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_color_override("font_color", Color("ffcf5a"))
	return l


func _make_spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _make_button(text: String, action: String, arg: Variant = "") -> Button:
	var b := Button.new()
	b.name = "Btn_" + action + "_" + str(arg).replace("/", "_")
	b.text = text
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(_on_button.bind(action, arg))
	return b


func _on_button(action: String, arg: Variant) -> void:
	match action:
		"tool":
			_set_tool(String(arg))
		"randomize":
			_randomize()
		"clear":
			_clear_placed()
		"save":
			_save()
		"load":
			_load()
		"exit":
			_exit()


func _refresh_status() -> void:
	if status_label != null:
		status_label.text = "tool=%s  placed=%d  erased=%d" % [_tool, _placed, _erased]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

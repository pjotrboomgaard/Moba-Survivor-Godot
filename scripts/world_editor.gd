extends Node2D
class_name WorldEditor

const WorldClock := preload("res://scripts/world_clock.gd")

## Manual world/level editor. Its own scene (arena + free camera) so the user can
## place/erase trees, rocks, grass and landmarks, pan/zoom, and save/load a level.
##
## Controls:
##   1 Tree  2 Rock  3 Grass  4 Landmark  5/Erase  6 cycle tree  7 cycle rock  8 cycle grass
##   LMB place · RMB erase · WASD move · Scroll zoom · MMB drag pan
##   Ctrl+S save · Ctrl+Z undo · F6 playtest · Esc back to menu
##   Sprawl: click to scatter the current tool (or mix ground covers)
##   Brush: hold LMB to paint a round stamp; same radius/density sliders
##   Ctrl+wheel radius · Shift+wheel density
##   [ / ] switch world (grass/volcano/ice/factory/docks) -- each world keeps its own
##   save file, so switching worlds swaps to that world's own saved layout (or blank).
##   T randomize · X clear · S save · O load · Esc back to menu

const OBSTACLE_SPEC := {
	"tree_oak": {"radius": 18.0, "lift": 28.0},
	"tree_pine": {"radius": 18.0, "lift": 28.0},
	"tree_piling": {"radius": 14.0, "lift": 28.0},
	"tree_pipe": {"radius": 12.0, "lift": 26.0},
	"tree_dead": {"radius": 14.0, "lift": 24.0},
	"tree_willow": {"radius": 18.0, "lift": 28.0},
	"tree_round": {"radius": 18.0, "lift": 28.0},
	"tree_fir": {"radius": 16.0, "lift": 30.0},
	"tree_palm": {"radius": 14.0, "lift": 32.0},
	"tree_cypress": {"radius": 12.0, "lift": 34.0},
	"tree_maple": {"radius": 18.0, "lift": 28.0},
	"rock_small": {"radius": 18.0, "lift": 6.0},
	"rock_large": {"radius": 28.0, "lift": 8.0},
	"boulder": {"radius": 34.0, "lift": 10.0},
	"rock_jagged": {"radius": 20.0, "lift": 7.0},
	"spire": {"radius": 20.0, "lift": 10.0},
	"grass_bush": {"radius": 0.0, "lift": 0.0},
	"grass_long": {"radius": 0.0, "lift": 0.0},
	"grass_mushroom": {"radius": 0.0, "lift": 0.0},
	"grass_wild": {"radius": 0.0, "lift": 0.0},
	"grass_tuft": {"radius": 0.0, "lift": 0.0},
	"grass_flower": {"radius": 0.0, "lift": 0.0},
	"grass_bloom": {"radius": 0.0, "lift": 0.0},
	"flower_patch": {"radius": 0.0, "lift": 0.0},
	"grass_lush": {"radius": 0.0, "lift": 0.0},
	"grass_meadow": {"radius": 0.0, "lift": 0.0},
	"dirt_tile": {"radius": 0.0, "lift": 0.0},
	"lava_chunk": {"radius": 16.0, "lift": 8.0},
	"ice_crystal": {"radius": 14.0, "lift": 16.0},
	"crate_box": {"radius": 18.0, "lift": 8.0},
	"barrel_keg": {"radius": 16.0, "lift": 8.0},
	"bollard": {"radius": 10.0, "lift": 20.0},
	"vent_cap": {"radius": 16.0, "lift": 6.0},
	"town_house": {"radius": 22.0, "lift": 12.0},
	"town_shop": {"radius": 26.0, "lift": 12.0},
	"town_church": {"radius": 20.0, "lift": 16.0},
	"town_well": {"radius": 14.0, "lift": 6.0},
	# --- Lagoon (tropical) architecture ---
	"lagoon_palm_hut": {"radius": 22.0, "lift": 12.0},
	"lagoon_fruit_tree": {"radius": 16.0, "lift": 30.0},
	"lagoon_shrine": {"radius": 16.0, "lift": 10.0},
	"lagoon_well": {"radius": 14.0, "lift": 6.0},
	"lagoon_bonfire": {"radius": 12.0, "lift": 4.0},
	# --- Lagoon (tropical) creatures ---
	"lagoon_dodo": {"radius": 10.0, "lift": 0.0},
	"lagoon_flamingo": {"radius": 10.0, "lift": 0.0},
	"lagoon_parrot": {"radius": 9.0, "lift": 0.0},
	"lagoon_crab": {"radius": 8.0, "lift": 0.0},
	"lagoon_fish": {"radius": 8.0, "lift": 0.0},
	"lagoon_shell": {"radius": 6.0, "lift": 0.0},
	"lagoon_egg": {"radius": 6.0, "lift": 0.0},
	"lagoon_palm": {"radius": 14.0, "lift": 32.0},
	# --- Forest (woodland) architecture ---
	"forest_hut": {"radius": 20.0, "lift": 12.0},
	"forest_treehouse": {"radius": 18.0, "lift": 28.0},
	"forest_stump_shrine": {"radius": 14.0, "lift": 8.0},
	"forest_well": {"radius": 13.0, "lift": 6.0},
	"forest_totem": {"radius": 10.0, "lift": 10.0},
	"forest_bonfire": {"radius": 10.0, "lift": 4.0},
	"forest_camp": {"radius": 16.0, "lift": 8.0},
	# --- Forest (woodland) creatures ---
	"forest_stag": {"radius": 12.0, "lift": 0.0},
	"forest_owl": {"radius": 9.0, "lift": 0.0},
	"forest_squirrel": {"radius": 8.0, "lift": 0.0},
	"forest_wolf": {"radius": 11.0, "lift": 0.0},
	"forest_fox": {"radius": 9.0, "lift": 0.0},
	"forest_badger": {"radius": 9.0, "lift": 0.0},
	"forest_rabbit": {"radius": 7.0, "lift": 0.0},
	"forest_beetle": {"radius": 6.0, "lift": 0.0},
	# --- Mountain (alpine) architecture ---
	"mountain_isometric_hut": {"radius": 20.0, "lift": 12.0},
	"mountain_igloo": {"radius": 18.0, "lift": 10.0},
	"mountain_shrine": {"radius": 16.0, "lift": 10.0},
	"mountain_well": {"radius": 13.0, "lift": 6.0},
	"mountain_tower": {"radius": 16.0, "lift": 16.0},
	"mountain_bonfire": {"radius": 10.0, "lift": 4.0},
	"mountain_cairn": {"radius": 12.0, "lift": 6.0},
	# --- Mountain (alpine) creatures ---
	"mountain_goat": {"radius": 11.0, "lift": 0.0},
	"mountain_yeti": {"radius": 14.0, "lift": 0.0},
	"mountain_wolf": {"radius": 11.0, "lift": 0.0},
	"mountain_owl": {"radius": 9.0, "lift": 0.0},
	"mountain_icebear": {"radius": 16.0, "lift": 0.0},
	"mountain_lizard": {"radius": 8.0, "lift": 0.0},
	# --- Town creatures ---
	"wolf": {"radius": 11.0, "lift": 0.0},
	"fox": {"radius": 9.0, "lift": 0.0},
	"raven": {"radius": 8.0, "lift": 0.0},
	"otter": {"radius": 9.0, "lift": 0.0},
	"boar": {"radius": 12.0, "lift": 0.0},
	"golem": {"radius": 14.0, "lift": 0.0},
}

const TREES := [
	"tree_oak", "tree_round", "tree_pine", "tree_fir", "tree_willow",
	"tree_maple", "tree_cypress", "tree_palm", "tree_dead", "tree_piling", "tree_pipe",
]
const ROCKS := ["rock_small", "rock_large", "spire", "rock_jagged", "boulder"]
const GRASS := [
	"grass_tuft", "grass_bush", "grass_long", "grass_mushroom", "grass_wild",
	"grass_flower", "grass_bloom", "flower_patch", "grass_lush", "grass_meadow", "dirt_tile",
]
const THEME := ["lava_chunk", "ice_crystal", "crate_box", "barrel_keg", "bollard", "vent_cap"]
## Recruit-area / corner-structure sprites available in every biome's palette.
## These are the pixel-art houses/architecture + creatures for the four
## recruit areas (Town, Lagoon, Forest, Mountain) plus the Town animals.
const RECRUIT_AREA_SPRITES := [
	# Town
	"town_house", "town_shop", "town_church", "town_well",
	"wolf", "fox", "raven", "otter", "boar", "golem",
	# Lagoon
	"lagoon_palm_hut", "lagoon_fruit_tree", "lagoon_shrine",
	"lagoon_well", "lagoon_bonfire", "lagoon_palm",
	"lagoon_dodo", "lagoon_flamingo", "lagoon_parrot",
	"lagoon_crab", "lagoon_fish", "lagoon_shell", "lagoon_egg",
	# Forest
	"forest_hut", "forest_treehouse", "forest_stump_shrine",
	"forest_well", "forest_totem", "forest_bonfire", "forest_camp",
	"forest_stag", "forest_owl", "forest_squirrel",
	"forest_wolf", "forest_fox", "forest_badger", "forest_rabbit", "forest_beetle",
	# Mountain
	"mountain_isometric_hut", "mountain_igloo", "mountain_shrine",
	"mountain_well", "mountain_tower", "mountain_bonfire", "mountain_cairn",
	"mountain_goat", "mountain_yeti", "mountain_wolf",
	"mountain_owl", "mountain_icebear", "mountain_lizard",
]
const LANDMARK_EFFECTS := ["pulse_wipe", "heal_all", "freeze_time", "phase_cloak", "speed_surge", "battle_frenzy"]
const ASSET_LABELS := {
	"tree_oak": "Oak", "tree_round": "Round", "tree_pine": "Pine", "tree_fir": "Fir",
	"tree_willow": "Willow", "tree_maple": "Maple", "tree_cypress": "Cypress",
	"tree_palm": "Palm", "tree_dead": "Dead", "tree_piling": "Piling", "tree_pipe": "Pipe",
	"rock_small": "Small rock", "rock_large": "Large rock", "boulder": "Boulder",
	"rock_jagged": "Jagged", "spire": "Blue rock", "grass_bush": "Bush", "grass_long": "Tall grass",
	"grass_mushroom": "Mushroom", "grass_wild": "Wild grass", "flower_patch": "Flowers",
	"grass_tuft": "Tuft", "grass_flower": "Flower", "grass_bloom": "Bloom",
	"grass_lush": "Lush", "grass_meadow": "Meadow", "dirt_tile": "Dirt",
	"lava_chunk": "Lava chunk", "ice_crystal": "Ice crystal", "crate_box": "Crate",
	"barrel_keg": "Barrel", "bollard": "Bollard", 	"vent_cap": "Vent",
	"grass_waterfall": "Waterfall", "grass_campfire": "Campfire", "grass_pond": "Lily pond",
	"volcano_plume": "Volcano", "lava_fall": "Lava fall", "ember_crack": "Ember crack",
	"ice_geyser": "Geyser", "ice_fall": "Ice fall", "aurora_spire": "Aurora",
	"factory_stack": "Smokestack", "spark_coil": "Spark coil", "warning_lamp": "Lamp",
	"docks_wave": "Waves", "lighthouse": "Lighthouse", "dock_lantern": "Lantern",
	"town_house": "House", "town_shop": "Shop", "town_church": "Church", "town_well": "Well",
	"lagoon_palm_hut": "Palm hut", "lagoon_fruit_tree": "Fruit tree", "lagoon_shrine": "Lagoon shrine",
	"lagoon_well": "Lagoon well", "lagoon_bonfire": "Lagoon fire", "lagoon_palm": "Palm",
	"lagoon_dodo": "Dodo", "lagoon_flamingo": "Flamingo", "lagoon_parrot": "Parrot",
	"lagoon_crab": "Crab", "lagoon_fish": "Fish", "lagoon_shell": "Shell", "lagoon_egg": "Egg",
	"forest_hut": "Forest hut", "forest_treehouse": "Treehouse", "forest_stump_shrine": "Stump shrine",
	"forest_well": "Forest well", "forest_totem": "Totem", "forest_bonfire": "Forest fire", "forest_camp": "Camp",
	"forest_stag": "Stag", "forest_owl": "Owl", "forest_squirrel": "Squirrel", "forest_wolf": "F- wolf",
	"forest_fox": "Fox", "forest_badger": "Badger", "forest_rabbit": "Rabbit", "forest_beetle": "Beetle",
	"mountain_isometric_hut": "M- hut", "mountain_igloo": "Igloo", "mountain_shrine": "M- shrine",
	"mountain_well": "M- well", "mountain_tower": "Tower", "mountain_bonfire": "M- fire", "mountain_cairn": "Cairn",
	"mountain_goat": "Goat", "mountain_yeti": "Yeti", "mountain_wolf": "M- wolf", "mountain_owl": "M- owl",
	"mountain_icebear": "Ice bear", "mountain_lizard": "Lizard",
	"wolf": "Wolf", "fox": "Town fox", "raven": "Raven", "otter": "Otter", "boar": "Boar", "golem": "Golem",
	"landmark": "Landmark", "erase": "Erase",
}

const FEATURES := [
	"grass_waterfall", "grass_campfire", "grass_pond",
	"volcano_plume", "lava_fall", "ember_crack",
	"ice_geyser", "ice_fall", "aurora_spire",
	"factory_stack", "spark_coil", "warning_lamp",
	"docks_wave", "lighthouse", "dock_lantern",
]
const WorldFeatureScript := preload("res://scripts/world_feature.gd")
const WorldFeatureArtScript := preload("res://scripts/world_feature_art.gd")

const SAVE_DIR := "user://world_editor_levels/"

var arena: Node2D
var cam: Camera2D = null
var toolbar_layer: CanvasLayer = null
var status_label: Label = null
var world_label: Label = null
var _palette_list: VBoxContainer = null

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
var _ghost: Sprite2D = null
var _palette_buttons: Dictionary = {}
var _undo_stack: Array = []
var _sprawl_enabled := false
var _paint_enabled := false
var _mix_ground := false
var _painting := false
var _paint_last := Vector2.INF
var _paint_stroke: Array[Node2D] = []
var _sprawl_radius := 240.0
var _sprawl_density := 1.0
var _sprawl_button: Button = null
var _paint_button: Button = null
var _mix_button: Button = null
var _radius_slider: HSlider = null
var _density_slider: HSlider = null
var _sprawl_label: Label = null
var _save_as_input: LineEdit = null
var _save_as_data: Dictionary = {}
var _load_as_input: LineEdit = null
var _load_picker: Control = null

var _obstacle_scene: PackedScene = load("res://scenes/arena/obstacle.tscn")


func _ready() -> void:
	add_to_group("world_editor")
	_rng.randomize()
	arena = get_node_or_null("Arena") as Node2D
	_ensure_camera()
	_ensure_toolbar()
	_ensure_ghost()
	_apply_zoom()
	_build_toolbar()
	if FileAccess.file_exists(_save_path_for_current_world()):
		_load()
	else:
		_adopt_arena_props()
	if arena is Arena:
		(arena as Arena).set_crater_unlocked(true)
	_refresh_status()
	_refresh_ghost()


## Save path is per-world so switching worlds doesn't clobber another world's saved
## level. Grass (biome_key() == "") keeps the original bare filename so the existing
## UI-verify harness (which checks for "user://world_editor_level.json" specifically)
## keeps working unmodified.
func _save_path_for_current_world() -> String:
	return GameRuntime.editor_level_path()


## Switch which world/biome the editor is dressing. Rebuilding the arena frees every
## child except Walls (see Arena.rebuild()) -- including any obstacles/landmarks we
## placed -- so this always starts the new world from a blank (or its own previously
## saved) canvas rather than carrying over props that wouldn't make sense in a
## different biome (e.g. volcano rocks sitting on an ice field).
func _switch_world(delta: int) -> void:
	var count: int = GameRuntime.BIOME_KEYS.size()
	var next_id: int = posmod(GameRuntime.biome_id + delta, count)
	GameRuntime.set_biome(next_id, true)
	_placed_nodes.clear()
	_placed = 0
	_erased = 0
	_undo_stack.clear()
	# dress_from_runtime_biome() (not a plain rebuild()) -- it re-derives Arena's internal
	# _world_id from GameRuntime.biome_id before rebuilding, which is what actually swaps
	# the tileset/void/pad theme. rebuild() alone reuses whatever _world_id was already set
	# (from the editor's initial grass dressing) and would silently keep showing grass.
	if arena != null and arena.has_method("dress_from_runtime_biome"):
		arena.dress_from_runtime_biome()
	elif arena != null and arena.has_method("rebuild"):
		arena.rebuild()
	_load()
	if _placed_nodes.is_empty():
		_adopt_arena_props()
	_rebuild_palette()
	_refresh_status()
	AudioService.play("ui_click")


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

func _process(delta: float) -> void:
	WorldClock.tick(delta)
	_wasd_move(delta)
	if _paint_enabled and _painting:
		_paint_tick()
	_refresh_ghost()
	queue_redraw()


func _wasd_move(delta: float) -> void:
	if cam == null:
		return
	if Input.is_key_pressed(KEY_CTRL):
		return
	var move := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if move == Vector2.ZERO:
		return
	var speed := 1800.0 / maxf(cam_zoom, 0.08)
	cam.global_position += move.normalized() * speed * delta


func _ensure_ghost() -> void:
	if _ghost != null:
		return
	_ghost = Sprite2D.new()
	_ghost.name = "PlacePreview"
	_ghost.z_as_relative = false
	_ghost.z_index = 40
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.58)
	add_child(_ghost)


func _refresh_ghost() -> void:
	if _ghost == null:
		return
	if _tool == "erase" or _tool == "landmark" or _over_ui():
		_ghost.visible = false
		return
	var spec: Dictionary = OBSTACLE_SPEC.get(_tool, {"radius": 18.0, "lift": 0.0})
	var tex: Texture2D = null
	var zoom := 4.0
	var lift := float(spec.get("lift", 0.0))
	if WorldFeatureArtScript.is_feature(_tool):
		tex = WorldFeatureArtScript.preview_texture(_tool)
		zoom = WorldFeatureArtScript.zoom_for(_tool)
		lift = 0.0
	else:
		tex = SpriteLibrary.texture_for(_tool)
		zoom = Obstacle.display_zoom(_tool, 4.0, tex)
	_ghost.texture = tex
	_ghost.visible = tex != null
	if tex == null:
		return
	_ghost.scale = Vector2(zoom, zoom)
	if _tool.contains("tree"):
		_ghost.offset = Vector2(0.0, -float(tex.get_height()) * 0.5)
	else:
		_ghost.offset = Vector2(0.0, -lift)
	_ghost.global_position = _cursor_world_position()


func _draw() -> void:
	var pos := _cursor_world_position()
	var line := 3.0 / maxf(cam_zoom, 0.05)
	if _area_tool_active():
		var color := Color(0.95, 0.72, 0.35, 0.9) if _paint_enabled else Color(0.55, 0.95, 0.55, 0.85)
		draw_arc(pos, _sprawl_radius, 0.0, TAU, 64, color, line, true)
		draw_circle(pos, 4.0 / maxf(cam_zoom, 0.05), color)
	var target := _nearest_editable(pos, _erase_world_slop())
	if target == null:
		return
	var radius := maxf(18.0, _erase_visual_radius(target))
	var color := Color(1.0, 0.35, 0.2, 0.95) if _tool == "erase" else Color(1.0, 0.75, 0.2, 0.55)
	draw_arc(target.global_position, radius, 0.0, TAU, 48, color, line, true)


func _unhandled_input(event: InputEvent) -> void:
	_handle_editor_input(event)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			if _over_ui():
				return
			_handle_editor_input(event)
			get_viewport().set_input_as_handled()


func _handle_editor_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if _area_tool_active() and Input.is_key_pressed(KEY_CTRL):
					_set_sprawl_radius(_sprawl_radius + 20.0)
				elif _area_tool_active() and Input.is_key_pressed(KEY_SHIFT):
					_set_sprawl_density(_sprawl_density + 0.1)
				else:
					_zoom(-0.05)
			MOUSE_BUTTON_WHEEL_DOWN:
				if _area_tool_active() and Input.is_key_pressed(KEY_CTRL):
					_set_sprawl_radius(_sprawl_radius - 20.0)
				elif _area_tool_active() and Input.is_key_pressed(KEY_SHIFT):
					_set_sprawl_density(_sprawl_density - 0.1)
				else:
					_zoom(0.05)
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
				if mb.pressed:
					_pan_start = get_viewport().get_mouse_position()
			MOUSE_BUTTON_LEFT:
				if mb.pressed and not _over_ui():
					if _paint_enabled and _tool != "erase" and _tool != "landmark":
						_painting = true
						_paint_stroke.clear()
						_paint_last = Vector2.INF
						_paint_tick()
					else:
						_place()
				elif not mb.pressed:
					_finish_paint_stroke()
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
		if key.ctrl_pressed and key.keycode == KEY_S:
			_save()
			return
		if key.ctrl_pressed and key.keycode == KEY_Z:
			_undo()
			return
		if key.keycode == KEY_F6:
			_playtest()
			return
		_handle_key(key.keycode)


func _handle_key(kc: int) -> void:
	var trees := current_trees()
	var rocks := current_rocks()
	var grass := current_grass()
	var tree_idx := trees.find(_tool)
	var rock_idx := rocks.find(_tool)
	var grass_idx := grass.find(_tool)
	match kc:
		KEY_ESCAPE, KEY_Q:
			_exit()
		KEY_O:
			_load()
		KEY_T:
			_randomize()
		KEY_X:
			_clear_placed()
		KEY_G:
			cam.visible = not cam.visible  # no-op safe; grid is off-screen by default
		KEY_BRACKETLEFT:
			_switch_world(-1)
		KEY_BRACKETRIGHT:
			_switch_world(1)
		KEY_1:
			if not trees.is_empty():
				_set_tool(str(trees[0]))
		KEY_2:
			if not rocks.is_empty():
				_set_tool(str(rocks[0]))
		KEY_3:
			if not grass.is_empty():
				_set_tool(str(grass[0]))
		KEY_4:
			if _tool == "landmark":
				_landmark_effect = (_landmark_effect + 1) % LANDMARK_EFFECTS.size()
			_set_tool("landmark")
		KEY_5, KEY_E:
			_set_tool("erase")
		KEY_6:
			if not trees.is_empty():
				_set_tool(str(trees[((tree_idx if tree_idx >= 0 else 0) + 1) % trees.size()]))
		KEY_7:
			if not rocks.is_empty():
				_set_tool(str(rocks[((rock_idx if rock_idx >= 0 else 0) + 1) % rocks.size()]))
		KEY_8:
			if not grass.is_empty():
				_set_tool(str(grass[((grass_idx if grass_idx >= 0 else 0) + 1) % grass.size()]))


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
	if cam != null:
		return cam.get_global_mouse_position()
	return get_global_mouse_position()


# ---------------- Tools ----------------

func _set_tool(sprite_id: String) -> void:
	_tool = sprite_id
	for id in _palette_buttons.keys():
		var button := _palette_buttons[id] as Button
		if button != null:
			button.modulate = Color("d4ff9a") if id == _tool else Color.WHITE
	_refresh_status()
	_refresh_ghost()
	AudioService.play("ui_click")


## Public: place a specific obstacle at a world position. Used by the verify harness.
func place_at(world_pos: Vector2, sprite_id: String) -> void:
	var node := _spawn_at(world_pos, sprite_id)
	if node != null:
		_push_undo_create([node])


func _area_tool_active() -> bool:
	return (_sprawl_enabled or _paint_enabled) and _tool != "erase" and _tool != "landmark"


func _is_ground_cover(sprite_id: String) -> bool:
	var spec: Dictionary = OBSTACLE_SPEC.get(sprite_id, {})
	return float(spec.get("radius", 18.0)) < 1.0 and not WorldFeatureArtScript.is_feature(sprite_id)


func _stamp_id() -> String:
	if _mix_ground and _is_ground_cover(_tool):
		var covers: Array = []
		for id in current_grass():
			if _is_ground_cover(str(id)):
				covers.append(id)
		if not covers.is_empty():
			return str(covers[_rng.randi() % covers.size()])
	return _tool


func _place() -> void:
	var pos := _cursor_world_position()
	if _tool == "erase":
		_erase_at(pos)
		return
	if _sprawl_enabled and _tool != "landmark":
		_place_sprawl(pos)
		return
	if _tool == "landmark":
		var lm := _place_landmark(pos)
		if lm != null:
			_push_undo_create([lm])
		return
	var node := _spawn_at(pos, _stamp_id())
	if node != null:
		_push_undo_create([node])


func _spawn_at(world_pos: Vector2, sprite_id: String) -> Node2D:
	if WorldFeatureArtScript.is_feature(sprite_id):
		return _place_feature(world_pos, sprite_id)
	return _place_obstacle(world_pos, sprite_id)


func _sprawl_count() -> int:
	var area_units := PI * pow(_sprawl_radius / 90.0, 2.0)
	return clampi(int(round(_sprawl_density * area_units)), 1, 80)


func _place_sprawl(center: Vector2) -> void:
	var count := _sprawl_count()
	var created: Array[Node2D] = []
	var min_gap := 28.0
	if _tool.begins_with("tree"):
		min_gap = 46.0
	elif WorldFeatureArtScript.is_feature(_tool):
		min_gap = 90.0
	var spots: Array[Vector2] = []
	var guard := 0
	while spots.size() < count and guard < count * 12:
		guard += 1
		var ang := _rng.randf() * TAU
		var dist := sqrt(_rng.randf()) * _sprawl_radius
		var candidate := center + Vector2.from_angle(ang) * dist
		var ok := true
		for existing in spots:
			if existing.distance_to(candidate) < min_gap:
				ok = false
				break
		if not ok:
			continue
		spots.append(candidate)
	for spot in spots:
		var node := _spawn_at(spot, _stamp_id())
		if node != null:
			created.append(node)
	if not created.is_empty():
		_push_undo_create(created)
	_refresh_status()


func _paint_spacing() -> float:
	return lerpf(52.0, 16.0, (_sprawl_density - 0.2) / 3.8)


func _paint_dab_count() -> int:
	return clampi(int(round(_sprawl_density * 2.0)), 1, 10)


func _paint_tick() -> void:
	if not _paint_enabled or _tool == "erase" or _tool == "landmark":
		return
	var pos := _cursor_world_position()
	if _paint_last.is_finite() and pos.distance_to(_paint_last) < _paint_spacing():
		return
	_paint_last = pos
	var count := _paint_dab_count()
	var min_gap := 18.0
	if _tool.begins_with("tree"):
		min_gap = 40.0
	elif WorldFeatureArtScript.is_feature(_tool):
		min_gap = 70.0
	var spots: Array[Vector2] = []
	var guard := 0
	while spots.size() < count and guard < count * 10:
		guard += 1
		var ang := _rng.randf() * TAU
		var dist := sqrt(_rng.randf()) * _sprawl_radius
		var candidate := pos + Vector2.from_angle(ang) * dist
		var ok := true
		for existing in spots:
			if existing.distance_to(candidate) < min_gap:
				ok = false
				break
		if ok:
			spots.append(candidate)
	for spot in spots:
		var node := _spawn_at(spot, _stamp_id())
		if node != null:
			_paint_stroke.append(node)


func _finish_paint_stroke() -> void:
	_painting = false
	if not _paint_stroke.is_empty():
		_push_undo_create(_paint_stroke.duplicate())
		_paint_stroke.clear()
		_refresh_status()


func _place_obstacle(pos: Vector2, sprite_id: String) -> Node2D:
	if arena == null:
		return null
	var spec: Dictionary = OBSTACLE_SPEC.get(sprite_id, {"radius": 18.0, "lift": 0.0})
	var obstacle := _obstacle_scene.instantiate() as Obstacle
	if obstacle == null:
		push_warning("[WorldEditor] obstacle scene failed to instantiate")
		return null
	arena.add_child(obstacle)
	obstacle.global_position = pos
	obstacle.configure(sprite_id, float(spec.get("radius", 18.0)), 4.0, float(spec.get("lift", 0.0)))
	if arena is Arena:
		(arena as Arena).register_obstacle(obstacle)
	_placed_nodes.append(obstacle)
	_placed += 1
	_refresh_status()
	return obstacle


func _place_feature(pos: Vector2, feature_id: String) -> Node2D:
	if arena == null:
		return null
	var feature := WorldFeatureScript.new()
	arena.add_child(feature)
	feature.configure(feature_id)
	feature.global_position = pos
	_placed_nodes.append(feature)
	_placed += 1
	_refresh_status()
	return feature


func _place_landmark(pos: Vector2) -> Node2D:
	if arena == null:
		return null
	var effect: String = LANDMARK_EFFECTS[_landmark_effect % LANDMARK_EFFECTS.size()]
	var lm: Node2D = null
	if arena.has_method("add_landmark_at"):
		lm = arena.add_landmark_at(pos, effect)
	else:
		var new_lm := ArenaLandmark.new()
		arena.add_child(new_lm)
		new_lm.global_position = pos
		new_lm.configure("tw_grass_landmark_bell", effect, 700.0, 2.5, 6.0, "")
		lm = new_lm
	if lm != null and is_instance_valid(lm) and not _placed_nodes.has(lm):
		_placed_nodes.append(lm as Node2D)
		_placed = _placed_nodes.size()
	_refresh_status()
	return lm


## Public: erase the nearest placed node within `radius` of `world_pos`. Used by the
## verify harness; returns true if a node was erased.
func erase_at_radius(world_pos: Vector2, radius: float) -> bool:
	return _erase_nearest(world_pos, radius)


func _erase_at(pos: Vector2) -> void:
	_erase_nearest(pos, _erase_world_slop())


func _erase_world_slop() -> float:
	var zoom := cam.zoom.x if cam != null else cam_zoom
	return 56.0 / maxf(zoom, 0.05)


func _erase_visual_radius(node: Node2D) -> float:
	if node is ArenaLandmark:
		return ArenaLandmark.STAND_RADIUS
	if node is Obstacle:
		var obstacle := node as Obstacle
		var visual := maxf(24.0, obstacle.body_radius)
		var sprite := obstacle.get_node_or_null("Sprite") as Sprite2D
		if sprite != null and sprite.texture != null:
			var size := Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale.abs()
			visual = maxf(visual, maxf(size.x, size.y) * 0.45)
		return visual
	if node.is_in_group("world_feature"):
		return 64.0
	return 32.0


func _erase_score(node: Node2D, pos: Vector2) -> float:
	var best := node.global_position.distance_to(pos)
	var sprite := node.get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		best = minf(best, sprite.global_position.distance_to(pos))
	return best - _erase_visual_radius(node)


func _nearest_editable(pos: Vector2, slop: float) -> Node2D:
	var best: Node2D = null
	var best_score := slop
	for node in _editable_nodes():
		var score := _erase_score(node, pos)
		if score < best_score:
			best_score = score
			best = node
	return best


func _erase_nearest(pos: Vector2, radius: float) -> bool:
	var best := _nearest_editable(pos, radius)
	if best == null:
		return false
	_push_undo_erase([_snapshot_node(best)])
	_forget_placed(best)
	best.queue_free()
	_erased += 1
	_placed = maxi(0, _placed_nodes.size())
	_refresh_status()
	return true


func _editable_nodes() -> Array[Node2D]:
	var found: Array[Node2D] = []
	if arena == null:
		return found
	for child in arena.get_children():
		if not (child is Node2D):
			continue
		if child is Obstacle or child is ArenaLandmark or child.is_in_group("world_feature"):
			found.append(child as Node2D)
	return found


func _adopt_arena_props() -> void:
	_placed_nodes.clear()
	_placed_nodes.append_array(_editable_nodes())
	_placed = _placed_nodes.size()


func _forget_placed(node: Node2D) -> void:
	_placed_nodes.erase(node)
	if arena is Arena:
		if node is Obstacle:
			(arena as Arena).unregister_obstacle(node as Obstacle)
		elif node is ArenaLandmark:
			(arena as Arena).unregister_landmark(node as ArenaLandmark)


func _push_undo_create(nodes: Array[Node2D]) -> void:
	var refs: Array = []
	for node in nodes:
		if node != null and is_instance_valid(node):
			refs.append(node)
	if refs.is_empty():
		return
	_undo_stack.append({"op": "create", "nodes": refs})
	if _undo_stack.size() > 80:
		_undo_stack.pop_front()


func _push_undo_erase(snaps: Array) -> void:
	if snaps.is_empty():
		return
	_undo_stack.append({"op": "erase", "snaps": snaps})
	if _undo_stack.size() > 80:
		_undo_stack.pop_front()


func _snapshot_node(node: Node2D) -> Dictionary:
	if node is Obstacle:
		return {
			"kind": "obstacle",
			"pos": node.global_position,
			"sprite": (node as Obstacle).sprite_id,
		}
	if node is ArenaLandmark:
		var lm := node as ArenaLandmark
		return {
			"kind": "landmark",
			"pos": node.global_position,
			"sprite": lm.sprite_name,
			"effect": String(lm.effect_id),
			"radius": lm.effect_radius,
			"seconds": lm.stand_seconds,
			"arg": lm.effect_arg,
			"hint": lm._hint,
		}
	if node.is_in_group("world_feature"):
		return {
			"kind": "feature",
			"pos": node.global_position,
			"id": str(node.get("feature_id")),
		}
	return {}


func _restore_snapshot(snap: Dictionary) -> void:
	var kind := str(snap.get("kind", ""))
	var pos: Vector2 = snap.get("pos", Vector2.ZERO)
	match kind:
		"obstacle":
			_place_obstacle(pos, str(snap.get("sprite", "rock_small")))
		"feature":
			_place_feature(pos, str(snap.get("id", "grass_campfire")))
		"landmark":
			if arena != null and arena.has_method("add_landmark_at"):
				var lm: Node2D = arena.add_landmark_at(pos, str(snap.get("effect", "pulse_wipe")), str(snap.get("sprite", "")), str(snap.get("hint", "")))
				if lm is ArenaLandmark:
					var landmark := lm as ArenaLandmark
					landmark.effect_radius = float(snap.get("radius", 700.0))
					landmark.stand_seconds = float(snap.get("seconds", 2.5))
					landmark.effect_arg = float(snap.get("arg", 6.0))
				if lm != null and is_instance_valid(lm) and not _placed_nodes.has(lm):
					_placed_nodes.append(lm)
					_placed = _placed_nodes.size()
			else:
				_place_landmark(pos)


func _undo() -> void:
	if _undo_stack.is_empty():
		_refresh_status()
		return
	var act: Dictionary = _undo_stack.pop_back()
	match str(act.get("op", "")):
		"create":
			for node in act.get("nodes", []):
				if node is Node2D and is_instance_valid(node):
					_forget_placed(node)
					(node as Node2D).queue_free()
					_erased += 1
		"erase":
			for snap in act.get("snaps", []):
				if snap is Dictionary:
					_restore_snapshot(snap)
	_placed = maxi(0, _placed_nodes.size())
	_refresh_status()
	AudioService.play("ui_click")


func _set_sprawl_radius(value: float) -> void:
	_sprawl_radius = clampf(value, 60.0, 900.0)
	if _radius_slider != null and not is_equal_approx(_radius_slider.value, _sprawl_radius):
		_radius_slider.value = _sprawl_radius
	_refresh_status()


func _set_sprawl_density(value: float) -> void:
	_sprawl_density = clampf(value, 0.2, 4.0)
	if _density_slider != null and not is_equal_approx(_density_slider.value, _sprawl_density):
		_density_slider.value = _sprawl_density
	_refresh_status()


func _toggle_sprawl() -> void:
	_sprawl_enabled = not _sprawl_enabled
	if _sprawl_enabled:
		_paint_enabled = false
		_finish_paint_stroke()
	if _sprawl_button != null:
		_sprawl_button.modulate = Color("d4ff9a") if _sprawl_enabled else Color.WHITE
	if _paint_button != null:
		_paint_button.modulate = Color("d4ff9a") if _paint_enabled else Color.WHITE
	_refresh_status()


func _toggle_paint() -> void:
	_paint_enabled = not _paint_enabled
	if _paint_enabled:
		_sprawl_enabled = false
	else:
		_finish_paint_stroke()
	if _paint_button != null:
		_paint_button.modulate = Color("d4ff9a") if _paint_enabled else Color.WHITE
	if _sprawl_button != null:
		_sprawl_button.modulate = Color("d4ff9a") if _sprawl_enabled else Color.WHITE
	_refresh_status()


func _toggle_mix() -> void:
	_mix_ground = not _mix_ground
	if _mix_button != null:
		_mix_button.modulate = Color("d4ff9a") if _mix_ground else Color.WHITE
	_refresh_status()


func _strip_editable_props() -> void:
	if arena != null:
		for node in _editable_nodes():
			_forget_placed(node)
			node.free()
	_placed_nodes.clear()
	_placed = 0


func _clear_placed() -> void:
	_strip_editable_props()
	_erased = 0
	_undo_stack.clear()
	_refresh_status()


# ---------------- Level content ----------------

func _randomize() -> void:
	_clear_placed()
	var map_w := 4200.0
	var map_h := 2800.0
	var kit: Dictionary = world_kit(GameRuntime.biome_id)
	var trees: Array = kit.get("trees", [])
	var ground: Array = kit.get("ground", [])
	if not trees.is_empty():
		var tree_count := _rng.randi_range(12, 22)
		for i in tree_count:
			_place_obstacle(Vector2(_rng.randf_range(-map_w / 2, map_w / 2), _rng.randf_range(-map_h / 2, map_h / 2)),
				str(trees[_rng.randi_range(0, trees.size() - 1)]))
	var rock_count := _rng.randi_range(8, 14)
	for i in rock_count:
		_place_obstacle(Vector2(_rng.randf_range(-map_w / 2, map_w / 2), _rng.randf_range(-map_h / 2, map_h / 2)),
			ROCKS[_rng.randi_range(0, mini(2, ROCKS.size() - 1))])
	if not ground.is_empty():
		var grass_count := _rng.randi_range(16, 28)
		for i in grass_count:
			_place_obstacle(Vector2(_rng.randf_range(-map_w / 2, map_w / 2), _rng.randf_range(-map_h / 2, map_h / 2)),
				str(ground[_rng.randi_range(0, ground.size() - 1)]))
	for i in 3:
		var angle := TAU * i / 3.0
		_place_landmark(Vector2(cos(angle), sin(angle)) * 1400.0)
	_refresh_status()


func _collect_level() -> Dictionary:
	var data := {"obstacles": [], "landmarks": [], "features": [], "biome": GameRuntime.biome_id}
	var baked_sprays: Dictionary = {}
	if arena is Arena:
		# Baked decorative props (grass, mushrooms, trees, flowers, dirt) are NOT live
		# Obstacle nodes, so they are invisible to _editable_nodes(). Without this they
		# are silently dropped on every re-save — the exact "grass disappears" bug.
		for prop in (arena as Arena).baked_props:
			var sprite_id := str(prop.get("sprite", ""))
			var pos: Vector2 = prop.get("pos", Vector2.ZERO)
			data.obstacles.append({"pos": [pos.x, pos.y], "sprite": sprite_id})
			# De-dupe: if the same prop was also placed as a live obstacle in this
			# session it would already be in the list above; keep only one copy.
			baked_sprays[sprite_id + "|" + str(pos.x) + "," + str(pos.y)] = true
	for node in _editable_nodes():
		if not is_instance_valid(node):
			continue
		if node.is_in_group("world_feature"):
			data.features.append({
				"pos": [node.global_position.x, node.global_position.y],
				"id": str(node.get("feature_id")),
			})
		elif node is Obstacle:
			var ob := node as Obstacle
			var key := ob.sprite_id + "|" + str(node.global_position.x) + "," + str(node.global_position.y)
			if baked_sprays.has(key):
				# Already saved from baked_props — skip the live-node duplicate.
				continue
			data.obstacles.append({
				"pos": [node.global_position.x, node.global_position.y],
				"sprite": ob.sprite_id,
			})
		elif node is ArenaLandmark:
			var lm := node as ArenaLandmark
			data.landmarks.append({
				"pos": [node.global_position.x, node.global_position.y],
				"effect": str(lm.effect_id),
				"sprite": lm.sprite_name,
				"hint": str(lm.get("_hint")),
			})
	return data


func _save() -> void:
	var data := _collect_level()
	var path := _save_path_for_current_world()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[WorldEditor] Could not open file for writing: %s err=%s" % [path, error_string(FileAccess.get_open_error())])
		_refresh_status()
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("[WorldEditor] Saved %d obstacles, %d features, %d landmarks -> %s" % [data.obstacles.size(), data.features.size(), data.landmarks.size(), path])
	if status_label != null:
		status_label.text = "saved %d props -> %s" % [data.obstacles.size() + data.features.size() + data.landmarks.size(), path]


func _show_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _save_as() -> void:
	# Prompt the user for a file name, then save the current level to a new
	# file so they can later tell the game exactly which map to use.
	if _save_as_input != null and is_instance_valid(_save_as_input):
		_show_status("already in Save As")
		return
	var data := _collect_level()
	var prompt_bar := HBoxContainer.new()
	prompt_bar.name = "SaveAsBar"
	prompt_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	prompt_bar.offset_left = 292.0
	prompt_bar.offset_right = -12.0
	prompt_bar.offset_top = 48.0
	prompt_bar.offset_bottom = 72.0
	prompt_bar.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Save As name:"
	label.custom_minimum_size = Vector2(0, 0)
	_save_as_input = LineEdit.new()
	_save_as_input.placeholder_text = "my_map"
	_save_as_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_as_input.text_submitted.connect(func(txt: String): _save_as_submit(txt, prompt_bar))
	prompt_bar.add_child(label)
	prompt_bar.add_child(_save_as_input)
	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok_btn.custom_minimum_size = Vector2(0, 34)
	ok_btn.pressed.connect(func(): _save_as_submit(_save_as_input.text, prompt_bar))
	prompt_bar.add_child(ok_btn)
	toolbar_layer.add_child(prompt_bar)
	_save_as_input.grab_focus()
	# Hide the status label so it doesn't overlap the prompt.
	if status_label != null:
		status_label.visible = false
	# Save the collected data so _save_as_submit doesn't re-scan the scene.
	_save_as_data = data


func _save_as_submit(text: String, prompt_bar: HBoxContainer) -> void:
	var name := _sanitize_map_name(text)
	if name.is_empty():
		_show_status("invalid name")
		return
	# Save to user://world_editor_level_<name>.json so the user can later
	# tell the game exactly which map to use via GameRuntime.custom_editor_level_name.
	var path := "user://world_editor_level_%s" % name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[WorldEditor] Save As failed: %s" % error_string(FileAccess.get_open_error()))
		_show_status("Save As failed")
		_remove_save_as_bar(prompt_bar)
		return
	file.store_string(JSON.stringify(_save_as_data))
	file.close()
	# Point the game at this new map so the next Play/FFA uses it immediately.
	var stem := name.trim_suffix(".json")
	GameRuntime.persist_custom_map_name(stem)
	# Also back the file up into the repo so it survives and is versioned.
	_backup_level_to_repo(name, _save_as_data)
	_remove_save_as_bar(prompt_bar)
	_show_status("SAVED AS %s (%d props) — game now uses: %s" % [stem, _save_as_data.obstacles.size() + _save_as_data.features.size() + _save_as_data.landmarks.size(), path])
	print("[WorldEditor] Saved As -> %s (custom_editor_level_name=%s)" % [path, stem])


func _remove_save_as_bar(prompt_bar: HBoxContainer) -> void:
	if is_instance_valid(prompt_bar):
		prompt_bar.queue_free()
	_save_as_input = null
	if status_label != null:
		status_label.visible = true


func _sanitize_map_name(raw: String) -> String:
	var n := raw.strip_edges()
	n = n.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	if n.is_empty():
		return ""
	if not n.ends_with(".json"):
		n += ".json"
	# Keep it reasonable in length.
	if n.length() > 48:
		n = n.left(48)
	# Strip a trailing ".json.json" if it was doubled.
	while n.ends_with(".json.json"):
		n = n.left(n.length() - 6)
	return n


func _backup_level_to_repo(name: String, data: Dictionary) -> void:
	# Write a copy into assets/levels/ so the map is versioned and survives
	# even if user:// is wiped. Best-effort: silently skip on failure.
	var repo_rel := "assets/levels/" + name
	if not name.ends_with(".json"):
		repo_rel += ".json"
	var abs_path := ProjectSettings.globalize_path("res://") + repo_rel
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	print("[WorldEditor] Backed up level to repo: %s" % abs_path)


func _load_as() -> void:
	# Prompt the user for a saved map name (from a previous Save As), then load it.
	if _load_as_input != null and is_instance_valid(_load_as_input):
		_show_status("already in Load As")
		return
	var prompt_bar := HBoxContainer.new()
	prompt_bar.name = "LoadAsBar"
	prompt_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	prompt_bar.offset_left = 292.0
	prompt_bar.offset_right = -12.0
	prompt_bar.offset_top = 48.0
	prompt_bar.offset_bottom = 72.0
	prompt_bar.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Load map:"
	_load_as_input = LineEdit.new()
	_load_as_input.placeholder_text = _list_saved_maps_summary()
	_load_as_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_as_input.text_submitted.connect(func(txt: String): _load_as_submit(txt, prompt_bar))
	prompt_bar.add_child(label)
	prompt_bar.add_child(_load_as_input)
	var ok_btn := Button.new()
	ok_btn.text = "Load"
	ok_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok_btn.custom_minimum_size = Vector2(0, 34)
	ok_btn.pressed.connect(func(): _load_as_submit(_load_as_input.text, prompt_bar))
	prompt_bar.add_child(ok_btn)
	toolbar_layer.add_child(prompt_bar)
	_load_as_input.grab_focus()
	if status_label != null:
		status_label.visible = false


func _load_as_submit(text: String, prompt_bar: HBoxContainer) -> void:
	var name := _sanitize_map_name(text)
	if name.is_empty():
		_show_status("invalid name")
		if is_instance_valid(prompt_bar):
			prompt_bar.queue_free()
		_load_as_input = null
		if status_label != null:
			status_label.visible = true
		return
	_load_named_map(name)
	if is_instance_valid(prompt_bar):
		prompt_bar.queue_free()
	_load_as_input = null
	if status_label != null:
		status_label.visible = true


func _load_named_map(name: String) -> void:
	# Accept either the bare stem ("volcano") or a full filename ("volcano.json") —
	# the Load As prompt sanitizes input and appends ".json", so strip it here to
	# avoid a doubled suffix that would make the path not exist.
	var stem := name.trim_suffix(".json").strip_edges()
	var file := FileAccess.open(_map_path_for_stem(stem), FileAccess.READ)
	# Fuzzy fallback: a typed biome alias ("grass", "ice", "vulkaan") or the bare
	# word for the current biome should resolve to that biome's default file even
	# when the user has not explicitly saved under that exact stem.
	if file == null:
		var aliased := _resolve_alias_to_map(stem)
		if not aliased.is_empty():
			file = FileAccess.open(aliased, FileAccess.READ)
			if file != null:
				path = aliased
	if file == null:
		# Be explicit about what's available so the user can't be stuck on a dead end.
		var available := ", ".join(_list_saved_maps())
		_show_status("map not found: %s  (available: %s)" % [stem, available if not available.is_empty() else "none"])
		push_warning("[WorldEditor] Load failed: %s (have: [%s])" % [path, available])
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_show_status("invalid map file: %s" % name)
		push_warning("[WorldEditor] Invalid level file: %s" % path)
		return
	if arena is Arena:
		(arena as Arena).apply_saved_level(parsed as Dictionary)
	_adopt_arena_props()
	_undo_stack.clear()
	_refresh_status()
	_show_status("loaded %s (%d props)" % [name, _placed])
	print("[WorldEditor] Loaded named map -> %s" % path)


## The on-disk path for a bare map stem, without assuming a ".json" suffix.
func _map_path_for_stem(stem: String) -> String:
	return "user://world_editor_level_%s.json" % stem


## Resolve a typed biome alias (e.g. "grass", "ice", "vulkaan", "4") to the
## biome's default map file, so the Load As prompt works even when the user has
## not explicitly saved a custom map under that name.
func _resolve_alias_to_map(stem: String) -> String:
	var key := stem.to_lower()
	# Grass has an empty biome_key, so map the alias words to the real default file.
	if key in ["grass", "gras", "verdant", "0", ""]:
		return "user://world_editor_level_grass_real.json"
	var aliased := GameRuntime.parse_biome(key)
	if aliased >= 0:
		var biome_key := str(GameRuntime.BIOME_KEYS[aliased])
		if biome_key.is_empty():
			return "user://world_editor_level_grass_real.json"
		if FileAccess.file_exists(_map_path_for_stem(biome_key)):
			return _map_path_for_stem(biome_key)
	return ""

Now let me verify lint:

	# List user:// for world_editor_level_<name>.json files (Save As outputs).
	var names: Array = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://")):
		return names
	var da := DirAccess.open(ProjectSettings.globalize_path("user://"))
	if da == null:
		return names
	da.list_dir_begin()
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir():
			if file_name.begins_with("world_editor_level_") and file_name.ends_with(".json"):
				var stem := file_name.trim_prefix("world_editor_level_").trim_suffix(".json")
				if not stem.is_empty():
					names.append(stem)
		file_name = da.get_next()
	da.list_dir_end()
	names.sort()
	return names


func _list_saved_maps_summary() -> String:
	var names := _list_saved_maps()
	if names.is_empty():
		return "(no saved maps yet)"
	return ", ".join(names)


func _all_maps() -> Array:
	## Return a list of all loadable maps: the current biome's default + all
	## Save As outputs. Each entry: {"name": <stem or "" for default>, "label": ..., "path": ...}
	var maps: Array = []
	var key := GameRuntime.biome_key()
	# The biome default map (always listed first). Grass keeps the dense "grass_real"
	# filename (the actual authored level), so the default entry points at the real file.
	var default_path := GameRuntime.editor_level_path()
	if key.is_empty():
		maps.append({"name": "", "label": "Grass (default)", "path": default_path})
	else:
		maps.append({"name": key, "label": "%s (default)" % GameRuntime.biome_name().capitalize(), "path": default_path})
	# Save As outputs (world_editor_level_<name>.json, name != biome key).
	for stem in _list_saved_maps():
		if stem == key:
			continue
		if key.is_empty() and stem == "":
			continue
		var p := "user://world_editor_level_%s.json" % stem
		if FileAccess.file_exists(p):
			maps.append({"name": stem, "label": stem, "path": p})
	return maps


func _load() -> void:
	# Open a picker that lists every saved map (biome defaults + Save As outputs)
	# and lets the user click one to load it.
	if _load_picker != null and is_instance_valid(_load_picker):
		_show_status("already in Load picker")
		return
	var maps := _all_maps()
	if maps.is_empty():
		_show_status("no saved maps found")
		return
	var panel := VBoxContainer.new()
	panel.name = "LoadPicker"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 292.0
	panel.offset_right = -12.0
	panel.offset_top = 48.0
	panel.offset_bottom = 420.0
	panel.add_theme_constant_override("separation", 4)
	var header := Label.new()
	header.text = "Choose a map to load:"
	panel.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	for m in maps:
		var b := Button.new()
		b.text = m.label
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _load_pick(m.name, panel))
		list_box.add_child(b)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel.pressed.connect(func(): _close_load_picker(panel))
	panel.add_child(cancel)
	_load_picker = panel
	toolbar_layer.add_child(panel)
	if status_label != null:
		status_label.visible = false


func _load_pick(name: String, panel: Control) -> void:
	# Empty name == biome default. Otherwise it's a Save As stem.
	if name.is_empty():
		_load_default_map()
	else:
		_load_named_map(name)
	_close_load_picker(panel)


func _load_default_map() -> void:
	var path := _save_path_for_current_world()
	if not FileAccess.file_exists(path):
		_show_status("no saved map for this biome")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_status("could not open %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[WorldEditor] Invalid level file")
		_show_status("invalid level file")
		return
	if arena is Arena:
		(arena as Arena).apply_saved_level(parsed as Dictionary)
	_adopt_arena_props()
	_undo_stack.clear()
	_refresh_status()
	# Clear any custom map pointer so the default biome map is used by the game.
	GameRuntime.persist_custom_map_name("")
	_show_status("loaded default map (%d props)" % _placed)
	print("[WorldEditor] Loaded default map from %s" % path)


func _close_load_picker(panel: Control) -> void:
	_load_picker = null
	if is_instance_valid(panel):
		panel.queue_free()
	if status_label != null:
		status_label.visible = true


func _playtest() -> void:
	_save()
	GameRuntime.return_to_world_editor = true
	GameRuntime.use_editor_level = true
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _exit() -> void:
	get_tree().change_scene_to_file("res://scenes/bootstrap/bootstrap.tscn")


static func world_kit(biome_id: int) -> Dictionary:
	match biome_id:
		1:
			return {
				"name": "Volcano",
				"trees": ["tree_dead"],
				"ground": ["grass_tuft", "grass_wild", "grass_lush", "grass_meadow", "dirt_tile", "lava_chunk"],
				"theme": ["lava_chunk"],
				"anim": ["volcano_plume", "lava_fall", "ember_crack"],
			}
		2:
			return {
				"name": "Ice",
				"trees": ["tree_pine", "tree_fir", "tree_cypress"],
				"ground": ["ice_crystal", "grass_bloom", "grass_flower", "grass_tuft", "grass_lush", "grass_meadow", "dirt_tile"],
				"theme": ["ice_crystal"],
				"anim": ["ice_geyser", "ice_fall", "aurora_spire"],
			}
		3:
			return {
				"name": "Factory",
				"trees": ["tree_pipe"],
				"ground": ["crate_box", "barrel_keg", "vent_cap", "grass_lush", "grass_meadow", "dirt_tile"],
				"theme": ["crate_box", "barrel_keg", "vent_cap"],
				"anim": ["factory_stack", "spark_coil", "warning_lamp"],
			}
		4:
			return {
				"name": "Docks",
				"trees": ["tree_piling", "tree_palm"],
				"ground": ["bollard", "barrel_keg", "grass_tuft", "flower_patch", "grass_lush", "grass_meadow", "dirt_tile"],
				"theme": ["bollard", "barrel_keg", "town_house", "town_shop", "town_church", "town_well"],
				"anim": ["docks_wave", "lighthouse", "dock_lantern"],
			}
		_:
			return {
				"name": "Grass",
				"trees": ["tree_oak", "tree_round", "tree_pine", "tree_fir", "tree_willow", "tree_maple", "tree_cypress", "tree_palm"],
				"ground": ["grass_tuft", "grass_bush", "grass_long", "grass_mushroom", "grass_wild", "grass_flower", "grass_bloom", "flower_patch", "grass_lush", "grass_meadow", "dirt_tile"],
				"theme": [],
				"anim": ["grass_waterfall", "grass_campfire", "grass_pond"],
			}


func current_trees() -> Array:
	return world_kit(GameRuntime.biome_id).get("trees", [])


func current_rocks() -> Array:
	return ROCKS.duplicate()


func current_grass() -> Array:
	return world_kit(GameRuntime.biome_id).get("ground", [])


func current_features() -> Array:
	return world_kit(GameRuntime.biome_id).get("anim", [])


# ---------------- Toolbar ----------------

func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Toolbar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 292.0
	bar.offset_right = -12.0
	bar.offset_top = 8.0
	bar.offset_bottom = 46.0
	bar.add_theme_constant_override("separation", 6)
	toolbar_layer.add_child(bar)

	bar.add_child(_make_label("WORLD EDITOR"))
	bar.add_child(_make_button("[ Prev", "world_prev"))
	world_label = _make_label("")
	bar.add_child(world_label)
	bar.add_child(_make_button("Next ]", "world_next"))
	bar.add_child(_make_spacer())
	bar.add_child(_make_button("Ctrl+S Save", "save"))
	bar.add_child(_make_button("Save As", "save_as"))
	bar.add_child(_make_button("Ctrl+Z Undo", "undo"))
	bar.add_child(_make_button("O Load", "load"))
	bar.add_child(_make_button("Load As", "load_as"))
	bar.add_child(_make_button("F6 Play", "playtest"))
	bar.add_child(_make_button("X Clear", "clear"))
	bar.add_child(_make_button("Esc Back", "exit"))

	if status_label != null:
		status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		status_label.offset_left = 292.0
		status_label.offset_right = -12.0
		status_label.offset_top = 48.0
		status_label.offset_bottom = 68.0
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var sprawl_bar := HBoxContainer.new()
	sprawl_bar.name = "SprawlBar"
	sprawl_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sprawl_bar.offset_left = 292.0
	sprawl_bar.offset_right = -12.0
	sprawl_bar.offset_top = 72.0
	sprawl_bar.offset_bottom = 110.0
	sprawl_bar.add_theme_constant_override("separation", 8)
	toolbar_layer.add_child(sprawl_bar)
	_sprawl_button = _make_button("Sprawl", "sprawl_toggle")
	sprawl_bar.add_child(_sprawl_button)
	_paint_button = _make_button("Brush", "paint_toggle")
	sprawl_bar.add_child(_paint_button)
	_mix_button = _make_button("Mix covers", "mix_toggle")
	sprawl_bar.add_child(_mix_button)
	sprawl_bar.add_child(_make_label("Radius"))
	_radius_slider = HSlider.new()
	_radius_slider.min_value = 60.0
	_radius_slider.max_value = 900.0
	_radius_slider.step = 10.0
	_radius_slider.value = _sprawl_radius
	_radius_slider.custom_minimum_size = Vector2(180, 28)
	_radius_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_radius_slider.value_changed.connect(_set_sprawl_radius)
	sprawl_bar.add_child(_radius_slider)
	sprawl_bar.add_child(_make_label("Density"))
	_density_slider = HSlider.new()
	_density_slider.min_value = 0.2
	_density_slider.max_value = 4.0
	_density_slider.step = 0.1
	_density_slider.value = _sprawl_density
	_density_slider.custom_minimum_size = Vector2(140, 28)
	_density_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_density_slider.value_changed.connect(_set_sprawl_density)
	sprawl_bar.add_child(_density_slider)
	_sprawl_label = _make_label("")
	sprawl_bar.add_child(_sprawl_label)
	sprawl_bar.add_child(_make_label("Ctrl+wheel radius · Shift+wheel density"))

	var panel := Panel.new()
	panel.name = "Palette"
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 0.0
	panel.offset_right = 280.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	toolbar_layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_right = -8.0
	scroll.offset_top = 8.0
	scroll.offset_bottom = -8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "PaletteList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_palette_list = list
	_rebuild_palette()


func _rebuild_palette() -> void:
	if _palette_list == null:
		return
	for child in _palette_list.get_children():
		_palette_list.remove_child(child)
		child.free()
	_palette_buttons.clear()
	_palette_list.add_child(_make_label("ASSETS BY WORLD"))
	_palette_list.add_child(_palette_section("Rocks", ROCKS))
	for biome in 5:
		var kit: Dictionary = world_kit(biome)
		var ids: Array = []
		ids.append_array(kit.get("trees", []))
		ids.append_array(kit.get("ground", []))
		ids.append_array(kit.get("theme", []))
		ids.append_array(kit.get("anim", []))
		_palette_list.add_child(_palette_section(str(kit.get("name", "World")), ids))
	# Recruit-area sprites (houses/creatures for Town, Lagoon, Forest, Mountain)
	# are available in every world so the user can place them in any biome.
	_palette_list.add_child(_palette_section("Recruit areas", RECRUIT_AREA_SPRITES))
	_palette_list.add_child(_palette_section("Tools", ["landmark", "erase"]))
	if not _palette_buttons.has(_tool):
		var trees := current_trees()
		if not trees.is_empty():
			_tool = str(trees[0])
		elif not ROCKS.is_empty():
			_tool = ROCKS[0]
	_set_tool(_tool)


func _palette_section(title: String, ids: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var header := _make_label(title)
	header.add_theme_color_override("font_color", Color("9ad4ff"))
	box.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for id in ids:
		if str(id).is_empty():
			continue
		grid.add_child(_make_palette_button(str(id)))
	return box


func _make_palette_button(sprite_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 72)
	b.tooltip_text = sprite_id
	b.text = str(ASSET_LABELS.get(sprite_id, sprite_id))
	b.clip_text = true
	var tex := SpriteLibrary.texture_for(sprite_id)
	if tex == null and WorldFeatureArtScript.is_feature(sprite_id):
		tex = WorldFeatureArtScript.preview_texture(sprite_id)
	if tex == null:
		tex = SideQuestArt.texture(sprite_id)
	if tex != null:
		b.icon = tex
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 48)
	b.pressed.connect(_set_tool.bind(sprite_id))
	_palette_buttons[sprite_id] = b
	return b


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
		"world_prev":
			_switch_world(-1)
		"world_next":
			_switch_world(1)
		"tool":
			_set_tool(String(arg))
		"randomize":
			_randomize()
		"clear":
			_clear_placed()
		"save":
			_save()
		"save_as":
			_save_as()
		"load_as":
			_load_as()
		"undo":
			_undo()
		"load":
			_load()
		"playtest":
			_playtest()
		"exit":
			_exit()
		"sprawl_toggle":
			_toggle_sprawl()
		"paint_toggle":
			_toggle_paint()
		"mix_toggle":
			_toggle_mix()


func _refresh_status() -> void:
	if world_label != null:
		world_label.text = "WORLD: %s" % GameRuntime.biome_name().to_upper()
	if status_label != null:
		status_label.text = "tool=%s  props=%d  erased=%d  WASD · Ctrl+S save · Ctrl+Z undo · F6 play · RMB erase" % [_tool, _placed, _erased]
		if _tool == "landmark":
			status_label.text += "  shrine=%s" % LANDMARK_EFFECTS[_landmark_effect % LANDMARK_EFFECTS.size()]
		if _area_tool_active():
			var mode := "brush" if _paint_enabled else "sprawl"
			status_label.text += "  %s r=%d n=%d" % [mode, int(_sprawl_radius), _sprawl_count()]
			if _mix_ground:
				status_label.text += " mix"
	if _sprawl_label != null:
		_sprawl_label.text = "r %d · n %d" % [int(_sprawl_radius), _sprawl_count()]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

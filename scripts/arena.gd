class_name Arena
extends Node2D

## Fired after `_spawn_landmarks` so main can rebind `triggered` when rebuild replaces instances.
signal landmarks_changed

## Terrain reward: some bosses leave a crater that unlocks fire-themed ability modifiers.
## Stubbed here so main.gd's unlock hook runs even before boss rewards are wired up.
var crater_unlocked: bool = true

func set_crater_unlocked(unlocked: bool) -> void:
	if crater_unlocked == unlocked:
		return
	crater_unlocked = unlocked
	if is_inside_tree():
		queue_redraw()

## Single active arena lives under main. Players / enemies resolve it through this so
## nobody needs to hard-wire the path (and so the offline smoke harness can find it).
const TeleportRingScript := preload("res://scripts/teleport_ring.gd")
static func arena_root(node: Node) -> Arena:
	if node == null:
		return null
	var tree := node.get_tree()
	if tree == null:
		return null
	for candidate in tree.get_nodes_in_group("arena"):
		if candidate is Arena:
			return candidate as Arena
	return null


## Worlds (PlayerClass.World) the arena can dress itself as. set_world(world_id) swaps
## the biome palette, pads, obstacles, decals and landmark layout to match.
enum World {
	IRON_FOUNDRY,
	ASHEN_CALDERA,
	VERDANT_WILDS,
	STORM_COURT,
}

## World -> existing biome id (see GameRuntime.BIOME_KEYS). Worlds reuse the four non-grass
## biomes that already have pad layouts and tile art: Iron Foundry walks the factory
## floors, Ashen Caldera the volcano, Verdant Wilds the docks, Storm Court the ice floes.
const WORLD_TO_BIOME: Array[int] = [3, 1, 4, 2]

const WORLD_NAMES: Array[String] = ["Iron Foundry", "Ashen Caldera", "Verdant Wilds", "Storm Court"]

## Landmarks per world. Each entry:
##   [sprite_id, effect_id, radius, stand_seconds, effect_arg, hint, angle_deg, dist_frac]
## Three inner roles every map: wipe (effect_arg = boss HP %), heal (HP), freeze (seconds),
## fanned across angles 20/140/260. _landmark_spot() turns dist_frac into an absolute
## world distance via minf(half.x, half.y) * dist_frac, so when the maps doubled, these
## three needed their dist_frac halved (0.70/0.76/0.72 -> 0.35/0.38/0.36) to keep the same
## absolute distance from spawn as before the doubling — otherwise heal_all in particular
## ends up too far to reach as an emergency save mid-boss-fight. A fourth landmark sits
## further out (dist_frac ~0.78–0.92, effect_arg = buff seconds) on the new outer pads each
## world grew when the maps doubled — a different temporary player buff per world; those
## are meant to be far out in the new outer areas, so they keep their larger dist_frac.
const WORLD_LANDMARKS: Array[Array] = [
	# Iron Foundry — slag pulse chunks elites, steam heals, quench freeze + mark. Turbo
	# manifold out on the east annex wing doubles speed for a burst.
	[
		["tw_factory_landmark_pylon", "pulse_wipe", 1600.0, 0.75, 18.0, "Molten Pylon", 20.0, 0.35],
		["tw_factory_landmark_vat", "heal_all", 480.0, 0.65, 80.0, "Steam Vent", 140.0, 0.38],
		["tw_factory_landmark_bay", "freeze_time", 560.0, 0.70, 10.0, "Quench Bay", 260.0, 0.36],
		["tw_factory_landmark_bay", "speed_surge", 600.0, 0.70, 13.0, "Turbo Manifold", -12.0, 0.78],
	],
	# Ashen Caldera — rift wipe, ember heal, long obsidian freeze. Ember fury totem out on
	# the far lava islands doubles attack speed and damage.
	[
		["tw_volcano_landmark_arch", "pulse_wipe", 1600.0, 0.75, 16.0, "Rift Portal", 20.0, 0.35],
		["tw_volcano_landmark_shrine", "heal_all", 500.0, 0.65, 88.0, "Ember Shrine", 140.0, 0.38],
		["tw_volcano_landmark_well", "freeze_time", 580.0, 0.70, 12.0, "Obsidian Font", 260.0, 0.36],
		["tw_volcano_landmark_well", "battle_frenzy", 620.0, 0.75, 30.0, "Ember Fury Totem", 203.0, 0.82],
	],
	# Verdant Wilds — grove wipe hits packs hard, spring heal, root freeze. Whispering
	# thicket out on the far pier cloaks the party and sends nearby packs wandering.
	[
		["tw_grass_landmark_bell", "pulse_wipe", 1600.0, 0.75, 18.0, "Grove Bell", 20.0, 0.35],
		["tw_grass_landmark_pool", "heal_all", 480.0, 0.65, 76.0, "Wild Spring", 140.0, 0.38],
		["tw_grass_landmark_stone", "freeze_time", 540.0, 0.70, 10.0, "Root Stone", 260.0, 0.36],
		["tw_grass_landmark_stone", "phase_cloak", 560.0, 0.65, 11.0, "Whispering Thicket", -7.5, 0.82],
	],
	# Storm Court — storm pulse, frost-well heal, crystal freeze. Glacial sprint rune out
	# on the far floes doubles speed for a burst.
	[
		["tw_docks_landmark_lighthouse", "pulse_wipe", 1600.0, 0.75, 16.0, "Storm Lighthouse", 20.0, 0.35],
		["tw_ice_landmark_hollow", "heal_all", 480.0, 0.65, 76.0, "Frost Well", 140.0, 0.38],
		["tw_ice_landmark_glade", "freeze_time", 560.0, 0.70, 11.0, "Frozen Crystal", 260.0, 0.36],
		["tw_ice_landmark_glade", "speed_surge", 600.0, 0.70, 14.0, "Glacial Sprint Rune", 206.0, 0.92],
	],
]

## Per-biome kits so every playable world (including docks) gets four contested
## N/E/S/W shrines with sprites that actually exist.
const BIOME_LANDMARKS: Array[Array] = [
	[
		["tw_grass_landmark_bell", "pulse_wipe", 1600.0, 0.75, 18.0, "Grove Bell"],
		["tw_grass_landmark_pool", "heal_all", 480.0, 0.65, 76.0, "Wild Spring"],
		["tw_grass_landmark_stone", "freeze_time", 540.0, 0.70, 10.0, "Root Stone"],
		["tw_grass_landmark_stone", "phase_cloak", 560.0, 0.65, 11.0, "Whispering Thicket"],
	],
	[
		["tw_volcano_landmark_arch", "pulse_wipe", 1600.0, 0.75, 16.0, "Rift Portal"],
		["tw_volcano_landmark_shrine", "heal_all", 500.0, 0.65, 88.0, "Ember Shrine"],
		["tw_volcano_landmark_well", "freeze_time", 580.0, 0.70, 12.0, "Obsidian Font"],
		["tw_volcano_landmark_pad", "battle_frenzy", 620.0, 0.75, 30.0, "Ember Fury"],
	],
	[
		["tw_docks_landmark_lighthouse", "pulse_wipe", 1600.0, 0.75, 16.0, "Storm Spire"],
		["tw_ice_landmark_hollow", "heal_all", 480.0, 0.65, 76.0, "Frost Well"],
		["tw_ice_landmark_glade", "freeze_time", 560.0, 0.70, 11.0, "Frozen Crystal"],
		["tw_ice_landmark_pad", "speed_surge", 600.0, 0.70, 14.0, "Sprint Rune"],
	],
	[
		["tw_factory_landmark_pylon", "pulse_wipe", 1600.0, 0.75, 18.0, "Molten Pylon"],
		["tw_factory_landmark_vat", "heal_all", 480.0, 0.65, 80.0, "Steam Vent"],
		["tw_factory_landmark_bay", "freeze_time", 560.0, 0.70, 10.0, "Quench Bay"],
		["tw_factory_landmark_pad", "speed_surge", 600.0, 0.70, 13.0, "Turbo Bay"],
	],
	[
		["tw_docks_landmark_lighthouse", "pulse_wipe", 1600.0, 0.75, 16.0, "Storm Lighthouse"],
		["tw_docks_landmark_pool", "heal_all", 480.0, 0.65, 76.0, "Tide Pool"],
		["tw_docks_landmark_bell", "freeze_time", 560.0, 0.70, 11.0, "Harbor Bell"],
		["tw_docks_landmark_pad", "speed_surge", 600.0, 0.70, 14.0, "Pilot Skiff"],
	],
]

## Live landmark instances the current world spawned. Emptied and rebuilt on set_world.
var landmarks: Array[ArenaLandmark] = []
## Teleporter pads (factory biome only). Each entry is a Dictionary with "pos" (Vector2),
## "partner" (index of partner pad), "color" (Color for glow).
var teleporter_pads: Array[Dictionary] = []

var _world_id: int = World.IRON_FOUNDRY


func world() -> int:
	return _world_id


## Landmark costume for a PlayerClass.World. Does not lock GameRuntime biome — wave
## cycling owns biome_id. Call dress_from_runtime_biome() when the map should follow
## the current wave biome (pads, void, tiles, landmarks).
func set_world(world_id: int) -> void:
	var index := clampi(world_id, 0, WORLD_TO_BIOME.size() - 1)
	if index == _world_id and not landmarks.is_empty():
		return
	_world_id = index
	if is_inside_tree():
		rebuild()


## Grass / volcano / ice / factory / docks → landmark world that fits the theme.
const BIOME_TO_WORLD: Array[int] = [
	World.VERDANT_WILDS,
	World.ASHEN_CALDERA,
	World.STORM_COURT,
	World.IRON_FOUNDRY,
	World.VERDANT_WILDS,
]


func dress_from_runtime_biome() -> void:
	var biome := clampi(GameRuntime.biome_id, 0, BIOME_TO_WORLD.size() - 1)
	_world_id = BIOME_TO_WORLD[biome]
	if is_inside_tree():
		rebuild()


const BASE_SIZE := Vector2(4800.0, 3200.0)
## Per-biome playfield footprints (indexed by GameRuntime.biome_id). Authored pad /
## hazard / shop coordinates live in BASE_SIZE space and scale up with the field.
## These are the original (pre-doubling) sizes: corner spawns stay inset so they
## don't sit on top of each other, and mid-edge landmarks stay contested.
const SIZE_BY_BIOME: Array[Vector2] = [
	Vector2(8400.0, 5600.0),
	Vector2(9600.0, 6800.0),
	Vector2(10400.0, 6800.0),
	Vector2(9200.0, 7200.0),
	Vector2(11200.0, 7200.0),
]
const SPAWN_INSET := 0.74
const LANDMARK_MID_FRAC := 0.42
## Central boss bowl, world-space (not scaled). Round crater ~600 across.
const CRATER_SIZE := Vector2(600.0, 600.0)
## Volcano only: walkable scorched plug so origin stays a legal spawn inside the lava lip.
const CRATER_INNER := Vector2(360.0, 360.0)


static func crater_rect() -> Rect2:
	return Rect2(-CRATER_SIZE * 0.5, CRATER_SIZE)


static func crater_radius() -> float:
	return CRATER_SIZE.x * 0.5


static func crater_inner_radius() -> float:
	return CRATER_INNER.x * 0.5


func crater_contains(world_position: Vector2, extra: float = 0.0) -> bool:
	return world_position.length() <= crater_radius() + extra


## Grass meadow and volcano own the centerpiece crater in PvE. FFA always has a
## center bowl so the arena still reads a crater, but creeps walk it like anyone else.
func crater_feature_active() -> bool:
	if not GameRuntime.uses_biomes() or GameRuntime.is_classic():
		return false
	if GameRuntime.is_ffa():
		return true
	return GameRuntime.biome_id == 0 or GameRuntime.biome_id == 1


## Kept for status logs. Creeps are no longer held on this rim.
static func ffa_creep_rim_radius(body_radius: float = 20.0) -> float:
	return crater_radius() + body_radius + 14.0


static func ffa_blocks_creeps_from_crater() -> bool:
	return false


static func playfield_size() -> Vector2:
	if GameRuntime.is_classic() or not GameRuntime.uses_biomes():
		return BASE_SIZE
	var index := clampi(GameRuntime.biome_id, 0, SIZE_BY_BIOME.size() - 1)
	return SIZE_BY_BIOME[index]


## Four co-op / FFA spawn rooms: NW, NE, SW, SE. Inset so heroes don't clip the wall.
static func corner_spawn(slot: int) -> Vector2:
	var half := playfield_size() * 0.5
	var inset := Vector2(half.x * SPAWN_INSET, half.y * SPAWN_INSET)
	match slot % 4:
		0:
			return Vector2(-inset.x, -inset.y)
		1:
			return Vector2(inset.x, -inset.y)
		2:
			return Vector2(-inset.x, inset.y)
		_:
			return Vector2(inset.x, inset.y)


## Mid-edge landmark seats between the four corner spawns (N, E, S, W).
static func contested_landmark_spots() -> Array[Vector2]:
	var half := playfield_size() * 0.5
	var mid := Vector2(half.x * LANDMARK_MID_FRAC, half.y * LANDMARK_MID_FRAC)
	return [
		Vector2(0.0, -mid.y),
		Vector2(mid.x, 0.0),
		Vector2(0.0, mid.y),
		Vector2(-mid.x, 0.0),
	]

const OBSTACLE_SCENE: PackedScene = preload("res://scenes/arena/obstacle.tscn")
const SHOP_STAND_SCENE: PackedScene = preload("res://scenes/arena/shop_stand.tscn")
const WorldFeatureScript := preload("res://scripts/world_feature.gd")
const WorldFeatureArtScript := preload("res://scripts/world_feature_art.gd")

## Walk-up shop, always open (unlike the forced breather every 10 waves) — see main.gd's
## proximity check. Placed off-center so it doesn't sit in the middle of the fight.
const SHOP_STAND_POSITION := Vector2(560.0, -260.0)
const SHOP_STAND_CLEARANCE := 140.0
const SHOP_STAND_INTERACT_RADIUS := 200.0

## Resolved shop spot for the currently built field. Defaults to the scaled base spot;
## _snap_shop_stand_to_pad() rewrites it when a biome's pads would leave the stand in a
## void. Static because both instances and the smoke test read it via shop_stand_position().
static var _shop_position := Vector2.ZERO


static func shop_stand_position() -> Vector2:
	if _shop_position != Vector2.ZERO:
		return _shop_position
	return SHOP_STAND_POSITION * (playfield_size() / BASE_SIZE)

## One art pixel becomes this many world pixels, for ground, decals and rocks
## alike, so everything shares the same chunky grid.
const PIXEL_ZOOM := 4.0

const OBSTACLE_TYPES: Array[Dictionary] = [
	{"sprite": "rock_small", "radius": 24.0, "lift": 3.0},
	{"sprite": "rock_large", "radius": 30.0, "lift": 3.0},
	{"sprite": "boulder", "radius": 44.0, "lift": 5.0},
	{"sprite": "spire", "radius": 28.0, "lift": 8.0},
]
const DECAL_SPRITES: Array[String] = ["grass_tuft", "grass_tuft", "grass_flower", "grass_bloom"]
const ZONE_KINDS: Array[String] = [
	"grass", "flowers", "forest", "rocks", "clearing", "thicket", "bloom", "barren", "mixed",
]
const TREE_SPACING := 118.0

## Everything below is laid out from a fixed seed, so every peer in a session
## builds the exact same field without replicating a single byte.
const LAYOUT_SEED := 20260819
const OBSTACLE_COUNT := 90
const ISLAND_OBSTACLE_COUNT := 70
const DECAL_COUNT := 800
const WALL_MARGIN := 140.0
const SPAWN_CLEARANCE := 210.0
const OBSTACLE_SPACING := 96.0
## Kept for layer-name compatibility. Lava/water gaps are walkable (5% HP/s burn);
## only the outer Walls body stays solid.
const VOID_LAYER := 32
## Slow current on the void tile — see _draw_void_rect / _update_water_drift.
const WATER_DRIFT_INTERVAL := 2.0
const WATER_DRIFT_STEP := 1.4
var _water_drift_offset := Vector2.ZERO
var _water_drift_timer := 0.0

var obstacles: Array[Obstacle] = []
## Static decorative props (grass tufts, flowers, small rocks) baked into a single
## background texture instead of living Obstacle nodes. Each entry is
## { "sprite": String, "pos": Vector2 }. Rebuilt on every rebuild(); the editor's
## eraser clears this list so it stays in sync with the live props.
var baked_props: Array = []
## Walkable pads for Pjotr biomes. Empty means the whole playfield is walkable
## (Pjotr grass meadow). Classic keeps the clean grid.
var walk_pads: Array[Rect2] = []
## Solid void leftover after subtracting pads (water, lava, slag pits). Used by
## drawing, collision, and water_spawn_point.
var void_rects: Array[Rect2] = []
## Ground tiles overdraw this many world pixels into the void so shores read.
const PAD_DRAW_RIM := 12.0
## Terrain hazards (lava pools, etc.) carved from the playfield independent of pads.
## Each entry: shape (rect/circle/ring) + type/dots. Circle/ring also store center + radius.
var hazard_zones: Array[Dictionary] = []
## Nine organic biome patches (grass, flowers, forest, rocks, ...). Same roles every world.
var terrain_zones: Array[Dictionary] = []
## Worlds that get lava hazards (PlayerClass.World: 0=IRON_FOUNDRY, 1=ASHEN_CALDERA).
## Foundry pools read as molten-slag basins; Caldera pools are straight lava.
const HAZARD_WORLDS: Array[int] = [0, 1]
## Authored circular pools per world (base-size coords). Three basins sit at compass
## points so they read as a layout, not a random scatter, and stay off the crater + shop.
const WORLD_HAZARD_POOLS: Array[Array] = [
	# Extra dunk bowls stay off — the void between pads is the lava/water, and
	# satellite pools made the carved worlds too tight.
	[],
	[],
]
## Flat DPS is only a fallback — player lava/slag uses percent-of-max-HP so a
## high-HP late-run hero cannot stand in a pool for free. Enemies still use the flat tick.
const HAZARD_PLAYER_DOT := 14.0
const HAZARD_PLAYER_PERCENT_PER_SECOND := 0.05
const HAZARD_ENEMY_DOT := 16.0
const HAZARD_DUNK_BURST := 60.0
const HAZARD_DUNK_SCRAMBLE := 2.5
## Hover still takes most of the burn — 0.5 used to read as "I can loiter in lava".
const HAZARD_HOVER_REDUCTION := 0.8


## Throttle for viewport culling — we don't need to re-evaluate every frame.
var _cull_timer := 0.0
const CULL_INTERVAL := 0.25

func _process(delta: float) -> void:
	_update_water_drift(delta)
	_update_biome_weather(delta)
	# Periodic biome hazards fire only when a biome is active.
	if GameRuntime.uses_biomes() and GameRuntime.biome_id > 0:
		var interval := 0.0
		match GameRuntime.biome_id:
			1:
				interval = BIOME_HAZARD_INTERVAL_VOLCANO
			3:
				interval = BIOME_HAZARD_INTERVAL_FACTORY
		if interval > 0.0:
			_biome_hazard_timer -= delta
			if _biome_hazard_timer <= 0.0:
				_emit_biome_hazard()
				_biome_hazard_timer = interval
	# Throttled viewport culling: hide obstacle + decal sprites that are far
	# off-screen to cut per-frame draw calls. Runs at 4 Hz, cheap enough to not
	# add CPU overhead.
	_cull_timer += delta
	if _cull_timer >= CULL_INTERVAL:
		_cull_timer = 0.0
		_cull_offscreen_sprites()


## Hides obstacle sprites (and their shadows) that are outside the camera viewport.
## Only affects visibility, not collision — physics still works on hidden rocks.
## Uses the first camera from the "players" group; falls back to the world origin.
var _cached_cull_cam: Node2D = null
var _cull_cam_dirty := true

## Resolves the active player camera (first enabled Camera2D in the "players"
## group). Cached until the players group changes. Shared by obstacle culling
## and baked-decal culling so both agree on the same view rect.
func _cull_camera() -> Camera2D:
	if _cull_cam_dirty:
		_cull_cam_dirty = false
		_cached_cull_cam = null
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p) or not p is Node2D:
				continue
			var cam: Node = (p as Node2D).get_node_or_null("Camera2D")
			if cam != null and cam is Camera2D and (cam as Camera2D).enabled:
				_cached_cull_cam = p as Node2D
				break
	if _cached_cull_cam == null:
		return null
	var cam: Node = _cached_cull_cam.get_node_or_null("Camera2D")
	if cam == null or not (cam is Camera2D) or not (cam as Camera2D).enabled:
		return null
	return cam as Camera2D


func _cull_offscreen_sprites() -> void:
	var cam_node := _cull_camera()
	if cam_node == null:
		return
	var cam_pos: Vector2 = cam_node.get_global_position()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom: Vector2 = cam_node.zoom
	# Half-extent in world units. Add a generous margin so tall/offset sprites
	# (trees, houses lifted above their collision base) are never culled before
	# they visually enter the screen. Margin must exceed the tallest sprite's
	# upward offset + half its size.
	# A fixed 180 world-unit margin covers the tallest lifted sprites (trees,
	# houses) and keeps them on-screen just before they visually enter the view.
	# Keeping it independent of zoom means zooming out culls more obstacles,
	# cutting live draw calls instead of piling them on the canvas.
	var margin := 180.0
	var half_w: float = (vp_size.x * 0.5 / maxf(0.1, zoom.x)) + margin
	var half_h: float = (vp_size.y * 0.5 / maxf(0.1, zoom.y)) + margin
	var cull_rect := Rect2(
		cam_pos.x - half_w, cam_pos.y - half_h,
		half_w * 2.0, half_h * 2.0
	)
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		var inside := cull_rect.has_point(obstacle.global_position)
		if obstacle.visible != inside:
			obstacle.visible = inside


## Steps the void tile's sampled UV one WATER_DRIFT_STEP along a fixed direction every
## WATER_DRIFT_INTERVAL seconds — a slow, deliberate current rather than a continuous
## scroll (see _draw_void_rect). No-ops on the flat grid (walk_pads empty) and in Classic.
func _update_water_drift(delta: float) -> void:
	if walk_pads.is_empty() or GameRuntime.is_classic():
		return
	_water_drift_timer += delta
	if _water_drift_timer < WATER_DRIFT_INTERVAL:
		return
	_water_drift_timer = 0.0
	_water_drift_offset += Vector2(0.8, 0.35).normalized() * WATER_DRIFT_STEP
	var void_tex := SpriteLibrary.texture_for("void_tile")
	if void_tex != null:
		var size := Vector2(void_tex.get_width(), void_tex.get_height())
		if size.x > 0.0 and size.y > 0.0:
			_water_drift_offset = Vector2(fmod(_water_drift_offset.x, size.x), fmod(_water_drift_offset.y, size.y))
	queue_redraw()


func _ready() -> void:
	add_to_group("arena")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crater_unlocked = true
	_fit_walls()
	if not GameRuntime.is_classic():
		# Hazards first so obstacles respect them (rocks shouldn't sit inside lava pools).
		_build_hazards()
		_build_field()
		_spawn_landmarks()
		_apply_editor_level_if_any()
	_spawn_biome_weather()
	queue_redraw()


func rebuild() -> void:
	for child in get_children():
		if child.name == "Walls":
			continue
		child.free()
	obstacles.clear()
	baked_props.clear()
	walk_pads.clear()
	void_rects.clear()
	landmarks.clear()
	hazard_zones.clear()
	_fit_walls()
	if not GameRuntime.is_classic():
		# Hazards first so _scatter_obstacles skips pool interiors.
		_build_hazards()
		_build_field()
		_spawn_landmarks()
		_apply_editor_level_if_any()
	queue_redraw()


func _apply_editor_level_if_any() -> void:
	var path := GameRuntime.editor_level_path()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	apply_saved_level(parsed as Dictionary)


func clear_editable_props() -> void:
	for obstacle in obstacles.duplicate():
		if is_instance_valid(obstacle):
			obstacle.free()
	obstacles.clear()
	baked_props.clear()
	for landmark in landmarks.duplicate():
		if is_instance_valid(landmark):
			landmark.free()
	landmarks.clear()
	for child in get_children():
		if child.is_in_group("world_feature"):
			child.free()


func apply_saved_level(data: Dictionary) -> void:
	clear_editable_props()
	for entry in data.get("obstacles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pos_a: Array = entry.get("pos", [0.0, 0.0])
		var sprite_id := String(entry.get("sprite", "rock_small"))
		var spec := _saved_obstacle_spec(sprite_id)
		_add_obstacle(Vector2(float(pos_a[0]), float(pos_a[1])), spec)
	for entry in data.get("features", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var fp: Array = entry.get("pos", [0.0, 0.0])
		var feature := WorldFeatureScript.new()
		feature.configure(String(entry.get("id", "grass_waterfall")))
		feature.global_position = Vector2(float(fp[0]), float(fp[1]))
		add_child(feature)
	for entry in data.get("landmarks", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var lp: Array = entry.get("pos", [0.0, 0.0])
		add_landmark_at(
			Vector2(float(lp[0]), float(lp[1])),
			String(entry.get("effect", "pulse_wipe")),
			String(entry.get("sprite", "")),
			String(entry.get("hint", ""))
		)
	# The saved level now includes the full procedural scatter (trees, rocks,
	# grass tufts) plus any user-placed props. If the saved level was authored
	# before the dense ground-cover scatter was enabled, it may be sparse. To
	# guarantee the "40% of edges missing grass" bug never surfaces, we top up
	# with non-clobbering ground cover: only place where there's actually room.
	_top_up_ground_cover()
	queue_redraw()
	landmarks_changed.emit()


## After loading a saved level, fill remaining empty ground with grass/flowers.
## Uses the same collision check as _scatter_ground_cover, so existing props are
## never overwritten — only empty spots get new tufts. This is the fix for the
## "grass not loaded on ~40% of map edges" issue.
func _top_up_ground_cover() -> void:
	var kit := _ground_cover_sprites()
	if kit.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 997  # different seed so top-ups don't overlap scatter
	var limit := playfield_size() * 0.5 - Vector2(WALL_MARGIN, WALL_MARGIN)
	var target_count := 400  # top-up target: fill gaps in the saved level
	var planted := 0
	var attempts := 0
	while planted < target_count and attempts < target_count * 40:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(-limit.x, limit.x),
			rng.randf_range(-limit.y, limit.y)
		)
		var sprite_id := kit[rng.randi() % kit.size()]
		if _try_place_obstacle(candidate, rng, _cover_type(sprite_id), 22.0):
			planted += 1
	if planted > 0:
		print("[ground_cover_topup] added ", planted, " ground props to fill sparse edges")


func _saved_obstacle_spec(sprite_id: String) -> Dictionary:
	if sprite_id.begins_with("tree"):
		return {"sprite": sprite_id, "radius": 18.0, "lift": 28.0}
	match sprite_id:
		"grass_tuft", "grass_long", "grass_bush", "grass_mushroom", "grass_wild", "grass_flower", "grass_bloom", "flower_patch", "grass_lush", "grass_meadow", "dirt_tile":
			return {"sprite": sprite_id, "radius": 0.0, "lift": 0.0}
		"rock_large":
			return {"sprite": sprite_id, "radius": 30.0, "lift": 3.0}
		"boulder":
			return {"sprite": sprite_id, "radius": 44.0, "lift": 5.0}
		"spire":
			return {"sprite": sprite_id, "radius": 28.0, "lift": 8.0}
		"town_house":
			return {"sprite": sprite_id, "radius": 22.0, "lift": 12.0}
		"town_house2":
			return {"sprite": sprite_id, "radius": 20.0, "lift": 10.0}
		"town_house3":
			return {"sprite": sprite_id, "radius": 24.0, "lift": 12.0}
		"town_cottage":
			return {"sprite": sprite_id, "radius": 18.0, "lift": 8.0}
		"town_shop":
			return {"sprite": sprite_id, "radius": 26.0, "lift": 12.0}
		"town_church":
			return {"sprite": sprite_id, "radius": 20.0, "lift": 16.0}
		"town_well":
			return {"sprite": sprite_id, "radius": 14.0, "lift": 6.0}
		_:
			return {"sprite": sprite_id, "radius": 18.0, "lift": 3.0}


## Scatter the authored lava-pool layout for worlds that opt in (ASHEN_CALDERA + IRON_FOUNDRY).
## Pools are circular basins at fixed compass points so they read as a map feature.
## Volcano lava is the void between islands — no dunk-ring around origin.
func _build_hazards() -> void:
	hazard_zones.clear()
	if not GameRuntime.uses_biomes():
		return
	var biome_kind := _hazard_biome_kind()
	var scale_factor := playfield_size() / BASE_SIZE
	if HAZARD_WORLDS.has(_world_id) and _world_id < WORLD_HAZARD_POOLS.size():
		for pool in WORLD_HAZARD_POOLS[_world_id]:
			var center: Vector2 = pool["center"] * scale_factor
			var radius := float(pool["radius"]) * minf(scale_factor.x, scale_factor.y)
			_append_circle_lava(center, radius, biome_kind)


func _append_lava_zone(rect: Rect2, biome_kind: String) -> void:
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	hazard_zones.append({
		"shape": "rect",
		"rect": rect,
		"type": "lava",
		"biome_kind": biome_kind,
		"player_dot": HAZARD_PLAYER_DOT,
		"percent_per_second": HAZARD_PLAYER_PERCENT_PER_SECOND,
		"enemy_dot": HAZARD_ENEMY_DOT,
		"dunk_burst": HAZARD_DUNK_BURST,
		"scramble_seconds": HAZARD_DUNK_SCRAMBLE,
	})


func _append_circle_lava(center: Vector2, radius: float, biome_kind: String) -> void:
	if radius < 12.0:
		return
	hazard_zones.append({
		"shape": "circle",
		"center": center,
		"radius": radius,
		"rect": Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		"type": "lava",
		"biome_kind": biome_kind,
		"player_dot": HAZARD_PLAYER_DOT,
		"percent_per_second": HAZARD_PLAYER_PERCENT_PER_SECOND,
		"enemy_dot": HAZARD_ENEMY_DOT,
		"dunk_burst": HAZARD_DUNK_BURST,
		"scramble_seconds": HAZARD_DUNK_SCRAMBLE,
	})


## Central volcano crater: round lava lip around a scorched inner plug so Vector2.ZERO
## stays a legal spawn. Crossing the lip is a dunk.
func _append_crater_lava() -> void:
	hazard_zones.append({
		"shape": "ring",
		"center": Vector2.ZERO,
		"radius": crater_radius(),
		"inner_radius": crater_inner_radius(),
		"rect": crater_rect(),
		"type": "lava",
		"biome_kind": "volcano_lava",
		"player_dot": HAZARD_PLAYER_DOT,
		"percent_per_second": HAZARD_PLAYER_PERCENT_PER_SECOND,
		"enemy_dot": HAZARD_ENEMY_DOT,
		"dunk_burst": HAZARD_DUNK_BURST,
		"scramble_seconds": HAZARD_DUNK_SCRAMBLE,
	})


func _hazard_biome_kind() -> String:
	match _world_id:
		0:
			return "factory_slag"
		1:
			return "volcano_lava"
		_:
			return "lava"


## Resolve the hazard under a world position. Returns {} when safe. Pools are small
## enough that first-hit wins; if two overlapped the first in the list takes precedence.
## T3.6: while the volcano lava is in its "cooled" phase, the zone reports zero
## player/enemy DOT so walking on it is harmless (the visual darkens via
## _draw_cooled_lava_overlay).
func hazard_at(world_position: Vector2) -> Dictionary:
	for zone in hazard_zones:
		if _zone_contains(zone, world_position, 0.0):
			if _lava_cooled and GameRuntime.biome_id == 1:
				var cooled := zone.duplicate(true)
				cooled["player_dot"] = 0.0
				cooled["enemy_dot"] = 0.0
				cooled["percent_per_second"] = 0.0
				cooled["cooled"] = true
				return cooled
			return zone
	return {}


## Spawn every landmark in the current world's kit, each at its own walkable,
## seeded-relative spot. Non-grass worlds carry >= 2 (one rift / attack, one resource).
func _spawn_landmarks() -> void:
	if not GameRuntime.uses_biomes():
		landmarks_changed.emit()
		return
	var kit: Array = []
	if GameRuntime.biome_id >= 0 and GameRuntime.biome_id < BIOME_LANDMARKS.size():
		kit = BIOME_LANDMARKS[GameRuntime.biome_id]
	elif _world_id >= 0 and _world_id < WORLD_LANDMARKS.size():
		kit = WORLD_LANDMARKS[_world_id]
	if kit.is_empty():
		landmarks_changed.emit()
		return
	var spots := contested_landmark_spots()
	var placed: Array[Vector2] = []
	for index in kit.size():
		var spec: Array = kit[index]
		if spec.size() < 6:
			continue
		# Remove the pulse_wipe "center wipe" landmark from every mode except classic.
		# The user explicitly asked for it to stop randomly appearing on the grass world
		# (it read as an intrusive "wipe thing"). Classic keeps its original behavior.
		if str(spec[1]) == "pulse_wipe" and not GameRuntime.is_classic():
			continue
		var landmark := ArenaLandmark.new()
		var preferred := spots[index] if index < spots.size() else _landmark_spot(float(spec[6]) if spec.size() > 6 else 0.0, float(spec[7]) if spec.size() > 7 else 0.42, placed)
		if GameRuntime.is_ffa() and index < spots.size():
			preferred = spots[index]
		landmark.position = free_position_near(preferred, ArenaLandmark.STAND_RADIUS * 0.55)
		if GameRuntime.is_ffa() and landmark.position.distance_to(preferred) > 220.0:
			landmark.position = preferred
		add_child(landmark)
		landmark.configure(
			str(spec[0]),
			StringName(spec[1]),
			float(spec[2]),
			float(spec[3]),
			float(spec[4]),
			str(spec[5])
		)
		_clear_pad_obstacles(landmark.position)
		placed.append(landmark.position)
		landmarks.append(landmark)
		print("[landmark] spawn %s (%s) at %s" % [spec[5], spec[1], landmark.position])
	_dress_landmark_props()
	for landmark in landmarks:
		if is_instance_valid(landmark):
			_clear_pad_obstacles(landmark.position)
	_clear_crater_props()
	landmarks_changed.emit()


func add_landmark_at(world_position: Vector2, effect: String, sprite_id: String = "", hint_text: String = "") -> ArenaLandmark:
	var spec := _landmark_spec_for_effect(effect)
	var sprite := sprite_id if not sprite_id.is_empty() else str(spec[0])
	var hint := hint_text if not hint_text.is_empty() else str(spec[5])
	var landmark := ArenaLandmark.new()
	landmark.position = world_position
	add_child(landmark)
	landmark.configure(
		sprite,
		StringName(spec[1]) if sprite_id.is_empty() else StringName(effect),
		float(spec[2]),
		float(spec[3]),
		float(spec[4]),
		hint
	)
	landmarks.append(landmark)
	landmarks_changed.emit()
	return landmark


func unregister_landmark(landmark: ArenaLandmark) -> void:
	landmarks.erase(landmark)
	landmarks_changed.emit()


func _landmark_spec_for_effect(effect: String) -> Array:
	var kit: Array = []
	if GameRuntime.biome_id >= 0 and GameRuntime.biome_id < BIOME_LANDMARKS.size():
		kit = BIOME_LANDMARKS[GameRuntime.biome_id]
	for spec in kit:
		if spec is Array and spec.size() >= 6 and str(spec[1]) == effect:
			return spec
	if not kit.is_empty() and kit[0] is Array:
		var fallback: Array = kit[0]
		if fallback.size() >= 6:
			var copy := fallback.duplicate()
			copy[1] = effect
			return copy
	return ["tw_grass_landmark_bell", effect, 700.0, 2.5, 6.0, "Landmark"]


## A seeded, walkable position for one landmark — placed at the given polar offset from
## spawn, kept clear of the shop stand, and nudged onto a walk pad if the biome carves
## the field up. angle_deg / dist_frac come from the world's landmark kit so multiple
## landmarks fan out across the field instead of stacking.
func _landmark_spot(angle_deg: float, dist_frac: float, placed: Array[Vector2] = []) -> Vector2:
	var half := playfield_size() * 0.5
	var distance := minf(half.x, half.y) * dist_frac
	var candidate := Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * distance
	if candidate.length() < SPAWN_CLEARANCE + 80.0:
		candidate = candidate.normalized() * (SPAWN_CLEARANCE + 120.0)
	if crater_feature_active() and crater_contains(candidate, ArenaLandmark.STAND_RADIUS):
		candidate = candidate.normalized() * (crater_radius() + ArenaLandmark.STAND_RADIUS + 80.0)
	if candidate.distance_to(shop_stand_position()) < SHOP_STAND_CLEARANCE + ArenaLandmark.STAND_RADIUS:
		candidate = candidate.rotated(deg_to_rad(55.0))
	for other in placed:
		if candidate.distance_to(other) < ArenaLandmark.STAND_RADIUS * 3.2:
			candidate = candidate.rotated(deg_to_rad(50.0))
	# Wide search so the octagon pad doesn't sit on a rock or lava lip.
	return free_position_near(candidate, ArenaLandmark.STAND_RADIUS * 0.55)


## Drop rocks, flowers, and other props that would sit on a landmark pad.
func _clear_pad_obstacles(spot: Vector2) -> void:
	var keep: Array[Obstacle] = []
	var clear_r := ArenaLandmark.STAND_RADIUS + 12.0
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		if obstacle.global_position.distance_to(spot) < clear_r + maxf(obstacle.body_radius, 8.0):
			obstacle.queue_free()
		else:
			keep.append(obstacle)
	obstacles = keep
	for child in get_children():
		if child.is_in_group("world_feature") and child.global_position.distance_to(spot) < clear_r:
			child.queue_free()


## Volcano bowl stays scorched and empty — no tufts, flowers, or rim rocks.
func _clear_crater_props() -> void:
	if GameRuntime.biome_id != 1:
		return
	if _skip_auto_props():
		return
	var clear_r := crater_radius() + 40.0
	var keep: Array[Obstacle] = []
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		if obstacle.global_position.length() < clear_r + maxf(obstacle.body_radius, 8.0):
			obstacle.queue_free()
		else:
			keep.append(obstacle)
	obstacles = keep
	for child in get_children():
		if child.is_in_group("world_feature") and child.global_position.length() < clear_r:
			child.queue_free()


## True when a circle of the given radius would overlap a rock or unwalkable biome
## terrain, so spawners can pick somewhere else instead of shoving enemies into lava.
func is_blocked(world_position: Vector2, radius: float = 20.0) -> bool:
	if not _is_walkable(world_position, radius):
		return true
	if is_in_hazard(world_position, radius):
		return true
	for obstacle in obstacles:
		if world_position.distance_to(obstacle.global_position) < obstacle.body_radius + radius:
			return true
	return false


## Pools count as "blocked" for placement, but NOT for movement (heroes + enemies are
## allowed to stand in lava if pushed / willing — that's the point of the dunk system).
func is_in_hazard(world_position: Vector2, radius: float = 0.0) -> bool:
	for zone in hazard_zones:
		if _zone_contains(zone, world_position, radius):
			return true
	return false

func get_hazard_zones() -> Array:
	return hazard_zones


## True when standing over the void between pads (water/lava/slag gap) rather than on a
## walkable pad. Gaps are walkable for everyone now; this only gates the 5%/s burn.
func is_in_void(world_position: Vector2, radius: float = 0.0) -> bool:
	if walk_pads.is_empty():
		return false
	return _inside_playfield(world_position) and not _is_walkable(world_position, radius)


## Geometry-aware escape: pushes straight out of whichever hazard zone(s) contain
## world_position, using each zone's actual shape instead of a blind radial search —
## a radial search centered on a position deep inside a large pool (routine on the
## bigger maps) can fail to reach clear ground within its search bounds and get stuck.
func nearest_hazard_exit(world_position: Vector2, margin: float = 24.0) -> Vector2:
	var point := world_position
	var guard := 0
	while guard < hazard_zones.size() + 2:
		guard += 1
		var containing: Dictionary = {}
		for zone in hazard_zones:
			if _zone_contains(zone, point, 0.0):
				containing = zone
				break
		if containing.is_empty():
			return point
		var shape := str(containing.get("shape", "rect"))
		match shape:
			"circle":
				var center: Vector2 = containing.get("center", Vector2.ZERO)
				var out_dir := point - center
				if out_dir.length() < 1.0:
					out_dir = Vector2.RIGHT
				point = center + out_dir.normalized() * (float(containing.get("radius", 0.0)) + margin)
			"ring":
				var origin: Vector2 = containing.get("center", Vector2.ZERO)
				var dist := point.distance_to(origin)
				var outer := float(containing.get("radius", 0.0))
				var inner := float(containing.get("inner_radius", 0.0))
				var dir := point - origin
				if dir.length() < 1.0:
					dir = Vector2.RIGHT
				dir = dir.normalized()
				if dist - inner <= outer - dist:
					point = origin + dir * maxf(0.0, inner - margin)
				else:
					point = origin + dir * (outer + margin)
			_:
				var rect: Rect2 = containing.get("rect", Rect2())
				var to_left := point.x - rect.position.x
				var to_right := rect.end.x - point.x
				var to_top := point.y - rect.position.y
				var to_bottom := rect.end.y - point.y
				var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
				if nearest == to_left:
					point.x = rect.position.x - margin
				elif nearest == to_right:
					point.x = rect.end.x + margin
				elif nearest == to_top:
					point.y = rect.position.y - margin
				else:
					point.y = rect.end.y + margin
	return point


func _zone_contains(zone: Dictionary, world_position: Vector2, extra: float) -> bool:
	var shape := str(zone.get("shape", "rect"))
	match shape:
		"circle":
			var center: Vector2 = zone.get("center", Vector2.ZERO)
			return world_position.distance_to(center) <= float(zone.get("radius", 0.0)) + extra
		"ring":
			var origin: Vector2 = zone.get("center", Vector2.ZERO)
			var dist := world_position.distance_to(origin)
			var outer := float(zone.get("radius", 0.0)) + extra
			var inner := maxf(0.0, float(zone.get("inner_radius", 0.0)) - extra)
			return dist <= outer and dist >= inner
		_:
			var rect: Rect2 = zone.get("rect", Rect2())
			return rect.grow(extra).has_point(world_position)


func _is_walkable(world_position: Vector2, radius: float = 20.0) -> bool:
	if walk_pads.is_empty():
		return true
	for pad in walk_pads:
		if _pad_contains(pad, world_position, radius):
			return true
	return false


func _pad_contains(pad: Rect2, point: Vector2, inset: float) -> bool:
	var max_ix := maxf(0.0, pad.size.x * 0.5 - 1.0)
	var max_iy := maxf(0.0, pad.size.y * 0.5 - 1.0)
	var ix := minf(maxf(0.0, inset), max_ix)
	var iy := minf(maxf(0.0, inset), max_iy)
	var inner := Rect2(pad.position + Vector2(ix, iy), Vector2(pad.size.x - 2.0 * ix, pad.size.y - 2.0 * iy))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return pad.has_point(point)
	return inner.has_point(point)


func is_water_biome() -> bool:
	# Ice/docks water, volcano lava, factory slag — packs climb out of the void.
	return GameRuntime.uses_biomes() and GameRuntime.biome_id >= 1


## Volcano lava and factory slag gaps — standing in the void here is a burn, not a chill.
func is_lava_void() -> bool:
	return GameRuntime.uses_biomes() and (GameRuntime.biome_id == 1 or GameRuntime.biome_id == 3)


## Ice / docks (and any carved biome): a void point near a pad shore, biased toward
## `toward`, so fliers can arrive from the water. Open field returns `toward`.
## Grounded callers should snap onto a pad with free_position_near.
func water_spawn_point(toward: Vector2, flying: bool = false) -> Vector2:
	if walk_pads.is_empty():
		return toward
	var shore := _void_point_near_pad(toward)
	if not flying:
		return shore
	var edge := _nearest_pad_edge(shore)
	var outward := shore - edge
	if outward.length_squared() < 1.0:
		outward = shore - toward
	if outward.length_squared() < 1.0:
		outward = Vector2.RIGHT
	var pushed := edge + outward.normalized() * 96.0
	if _inside_playfield(pushed) and not _is_walkable(pushed, 8.0):
		return pushed
	return shore


func _void_point_near_pad(toward: Vector2) -> Vector2:
	var best := toward
	var best_score := INF
	var found := false
	var pieces: Array[Rect2] = void_rects
	if pieces.is_empty():
		pieces = [_arena_rect()]
	for piece in pieces:
		if piece.size.x < 18.0 or piece.size.y < 18.0:
			continue
		var inner := piece.grow(-16.0)
		if inner.size.x < 6.0 or inner.size.y < 6.0:
			inner = piece
		var candidate := Vector2(
			clampf(toward.x, inner.position.x, inner.end.x),
			clampf(toward.y, inner.position.y, inner.end.y)
		)
		if not _inside_playfield(candidate):
			continue
		if _is_walkable(candidate, 6.0):
			continue
		var shore := candidate.distance_squared_to(_nearest_pad_edge(candidate))
		var score := candidate.distance_squared_to(toward) + shore
		if score < best_score:
			best_score = score
			best = candidate
			found = true
	if found:
		return best
	var edge := _nearest_pad_edge(toward)
	var dir := toward - edge
	if dir.length_squared() < 1.0:
		dir = edge
	if dir.length_squared() < 1.0:
		dir = Vector2.RIGHT
	var fallback := edge + dir.normalized() * 40.0
	if _inside_playfield(fallback) and not _is_walkable(fallback, 6.0):
		return fallback
	return toward


func _nearest_pad_edge(world_position: Vector2) -> Vector2:
	if walk_pads.is_empty():
		return world_position
	var best := walk_pads[0].get_center()
	var best_d := INF
	for pad in walk_pads:
		var closest := Vector2(
			clampf(world_position.x, pad.position.x, pad.end.x),
			clampf(world_position.y, pad.position.y, pad.end.y)
		)
		var distance := closest.distance_squared_to(world_position)
		if distance < best_d:
			best_d = distance
			best = closest
	return best


## The nearest free spot on a short outward search, used for enemy spawns.
func free_position_near(world_position: Vector2, radius: float = 20.0) -> Vector2:
	if not is_blocked(world_position, radius):
		return world_position
	for step in range(1, 12):
		var push := float(step) * 40.0
		for turn in 8:
			var angle := TAU * float(turn) / 8.0
			var candidate := world_position + Vector2.RIGHT.rotated(angle) * push
			if _inside_playfield(candidate) and not is_blocked(candidate, radius):
				return candidate
	if not walk_pads.is_empty():
		var offsets: Array[Vector2] = [
			Vector2(0.5, 0.5), Vector2(0.28, 0.5), Vector2(0.72, 0.5),
			Vector2(0.5, 0.28), Vector2(0.5, 0.72)
		]
		for pad in walk_pads:
			for offset in offsets:
				var candidate: Vector2 = pad.position + pad.size * offset
				if _inside_playfield(candidate) and not is_blocked(candidate, radius):
					return candidate
	return world_position


func _inside_playfield(world_position: Vector2) -> bool:
	var limit := playfield_size() * 0.5 - Vector2(WALL_MARGIN, WALL_MARGIN)
	return absf(world_position.x) < limit.x and absf(world_position.y) < limit.y


func half_extents() -> Vector2:
	return playfield_size() * 0.5


func _build_field() -> void:
	# Non-grass biomes carve the field into their signature pad layouts (volcano islands,
	# ice floes, factory halls, dock piers). Grass/classic keeps the open walkable field.
	walk_pads.clear()
	if GameRuntime.uses_biomes() and GameRuntime.biome_id > 0:
		walk_pads = _pads_for_biome(GameRuntime.biome_id)
		_snap_shop_stand_to_pad()
	# Pre-editor layout: scattered rocks/spires plus flower tufts on one ground tile.
	# The world editor stamps extra props on top of this base; it does not strip it.
	_scatter_obstacles()
	_pack_pad_rocks()
	_plant_cover_rocks()
	_scatter_ground_cover()
	_clear_crater_props()
	var shop_stand := SHOP_STAND_SCENE.instantiate() as Node2D
	shop_stand.global_position = shop_stand_position()
	add_child(shop_stand)
	# Solid void for the water / lava / pit between pads so bodies can't leave the pads.
	_build_void_bodies()
	_spawn_teleporters()
	_spawn_docks_booby_traps()


## Factory biome: scatter paired teleport pads so the player can shortcut across the
## large map. Stepping on a pad instantly moves you to its partner — no cooldown.
func _spawn_teleporters() -> void:
	teleporter_pads.clear()
	if GameRuntime.biome_id != 3:
		return
	var half := playfield_size() * 0.5
	# Six pads in three pairs placed at opposite corners of walkable floor.
	var raw_positions: Array[Vector2] = [
		half * Vector2(-0.88, -0.88),
		half * Vector2(0.88, 0.88),
		half * Vector2(0.88, -0.88),
		half * Vector2(-0.88, 0.88),
		half * Vector2(-0.88, 0.0),
		half * Vector2(0.88, 0.0),
	]
	var colors: Array[Color] = [
		Color("7ec8ff"),
		Color("7ec8ff"),
		Color("ff8ac8"),
		Color("ff8ac8"),
		Color("b0ff7e"),
		Color("b0ff7e"),
	]
	for i in raw_positions.size():
		var pos := free_position_near(raw_positions[i], 60.0)
		teleporter_pads.append({"pos": pos, "partner": i ^ 1, "color": colors[i]})
		var pad := Area2D.new()
		pad.name = "TeleporterPad_%d" % i
		var shape := CircleShape2D.new()
		shape.radius = 34.0
		var collider := CollisionShape2D.new()
		collider.shape = shape
		pad.add_child(collider)
		pad.collision_layer = 0
		pad.collision_mask = 1 << 0
		var glow := Sprite2D.new()
		glow.name = "Glow"
		glow.texture = _teleporter_pad_texture(colors[i])
		glow.z_index = 2
		pad.add_child(glow)
		pad.global_position = pos
		add_child(pad)
		pad.body_entered.connect(_on_teleporter_body_entered.bind(i))


func _teleporter_pad_texture(color: Color) -> Texture2D:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x - center.x, y - center.y).length() / (size * 0.5)
			var alpha := 0.0
			if d < 0.62:
				alpha = 0.9
			elif d < 0.8:
				alpha = 0.45
			elif d < 1.0:
				alpha = 0.18
			if alpha > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)


func _on_teleporter_body_entered(body: Node2D, pad_index: int) -> void:
	if pad_index >= teleporter_pads.size():
		return
	var entry: Dictionary = teleporter_pads[pad_index]
	var partner: int = int(entry.get("partner", -1))
	if partner < 0 or partner >= teleporter_pads.size():
		return
	if not body is CharacterBody2D:
		return
	if "active" in body and not (body as CharacterBody2D).active:
		return
	var target := Vector2(float(teleporter_pads[partner]["pos"].x), float(teleporter_pads[partner]["pos"].y))
	body.global_position = target
	var color: Color = entry.get("color", Color("7ec8ff"))
	if not GameRuntime.is_dedicated_server():
		_spawn_teleport_ring(target, color)


func _spawn_teleport_ring(pos: Vector2, color: Color) -> void:
	var ring := TeleportRingScript.new(color)
	ring.global_position = pos
	add_child(ring)


## Docks biome: place booby traps (cannons + spike plates) at fixed, seeded
## positions so the layout is deterministic across clients.
const _DOCKS_BOOMY_TRAP := preload("res://scripts/docks_booby_trap.gd")
const _BIOME_HAZARD := preload("res://scripts/biome_hazard.gd")
var _docks_booby_traps: Array[Node2D] = []

func _spawn_docks_booby_traps() -> void:
	for trap in _docks_booby_traps:
		if is_instance_valid(trap):
			trap.queue_free()
	_docks_booby_traps.clear()
	if GameRuntime.biome_id != 4:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 733
	var half := playfield_size() * 0.5
	# 3 cannons at fixed compass points
	var cannon_positions: Array[Vector2] = [
		half * Vector2(-0.72, -0.72),
		half * Vector2(0.72, -0.72),
		half * Vector2(0.72, 0.72),
	]
	for pos in cannon_positions:
		var snap := _snap_feature_to_ground(pos)
		var trap := _DOCKS_BOOMY_TRAP.new()
		trap.global_position = snap
		add_child(trap)
		trap.configure_as_cannon()
		_docks_booby_traps.append(trap)
	# 4 spike plates at mid-map spots
	var spike_positions: Array[Vector2] = [
		half * Vector2(-0.35, 0.0),
		half * Vector2(0.35, 0.0),
		half * Vector2(0.0, -0.45),
		half * Vector2(0.0, 0.45),
	]
	for pos in spike_positions:
		var snap := _snap_feature_to_ground(pos)
		var trap := _DOCKS_BOOMY_TRAP.new()
		trap.global_position = snap
		add_child(trap)
		trap.configure_as_spike_plate()
		_docks_booby_traps.append(trap)


## Volcano (biome 1): periodic lava geysers that erupt at random walkable spots.
## Factory (biome 3): periodic EMP bursts that slow nearby units and drain HP.
var _biome_hazard_timer := 0.0
const BIOME_HAZARD_INTERVAL_VOLCANO := 6.0
const BIOME_HAZARD_INTERVAL_FACTORY := 16.0
const GeyserRadius := 150.0
const GeyserDamage := 12.0
const EMP_RADIUS := 260.0
const EMP_DAMAGE := 8.0
const EMP_SLOW := 0.45
const EMP_SLOW_DURATION := 2.5


## ============================================================================
## T3.5 / T3.6 / T3.7 — Biome weather + cooldown phases
## ============================================================================
## Rain happens *occasionally* in every world (T3.5). The volcano lava
## periodically cools to a harmless black state (T3.6). The factory ground
## periodically electrocutes (T3.7). All three are driven by timers below.

const _BIOME_WEATHER := preload("res://scripts/biome_weather.gd")
var _biome_weather: Node2D = null
var _rain_timer := 12.0            # seconds until the next rain onset
const RAIN_ONSET_MIN := 18.0
const RAIN_ONSET_MAX := 45.0
const RAIN_DURATION_MIN := 8.0
const RAIN_DURATION_MAX := 15.0
var _rain_active := false
var _rain_remaining := 0.0

## Volcano black-lava phase: while true, lava hazard_at() reports no damage.
var _lava_cooled := false
var _lava_cool_timer := 20.0       # seconds until the next cooling onset
const LAVA_COOL_ONSET_MIN := 20.0
const LAVA_COOL_ONSET_MAX := 30.0
const LAVA_COOL_DURATION := 6.0
var _lava_cool_remaining := 0.0

## Factory electro ground phase: a small floor patch that ticks damage.
var _electro_active := false
var _electro_timer := 18.0         # seconds until the next electro onset
const ELECTRO_ONSET_MIN := 15.0
const ELECTRO_ONSET_MAX := 25.0
const ELECTRO_DURATION := 3.0
const ELECTRO_DPS := 3.0
var _electro_origin := Vector2.ZERO
var _electro_radius := 90.0
var _electro_remaining := 0.0


func _spawn_biome_weather() -> void:
	if _biome_weather != null and is_instance_valid(_biome_weather):
		return
	_biome_weather = _BIOME_WEATHER.new()
	add_child(_biome_weather)


func _update_biome_weather(delta: float) -> void:
	if not GameRuntime.uses_biomes():
		return
	# Rain (all biomes).
	if _rain_active:
		_rain_remaining -= delta
		if _rain_remaining <= 0.0:
			_set_rain(false)
	else:
		_rain_timer -= delta
		if _rain_timer <= 0.0:
			_set_rain(true)
			_rain_remaining = randf_range(RAIN_DURATION_MIN, RAIN_DURATION_MAX)
			_rain_timer = randf_range(RAIN_ONSET_MIN, RAIN_ONSET_MAX)
	# Volcano black lava.
	if GameRuntime.biome_id == 1:
		if _lava_cooled:
			_lava_cool_remaining -= delta
			if _lava_cool_remaining <= 0.0:
				_lava_cooled = false
				queue_redraw()
		else:
			_lava_cool_timer -= delta
			if _lava_cool_timer <= 0.0:
				_lava_cooled = true
				_lava_cool_remaining = LAVA_COOL_DURATION
				_lava_cool_timer = randf_range(LAVA_COOL_ONSET_MIN, LAVA_COOL_ONSET_MAX)
				_play_lava_cool_sfx()
				queue_redraw()
	# Factory electro ground.
	if GameRuntime.biome_id == 3:
		if _electro_active:
			_electro_remaining -= delta
			_tick_electro_damage(delta)
			if _electro_remaining <= 0.0:
				_electro_active = false
		else:
			_electro_timer -= delta
			if _electro_timer <= 0.0:
				_electro_active = true
				_electro_remaining = ELECTRO_DURATION
				_electro_origin = _random_walkable_hazard_spot() if _random_walkable_hazard_spot() != null else Vector2.ZERO
				_electro_timer = randf_range(ELECTRO_ONSET_MIN, ELECTRO_ONSET_MAX)
				_play_electro_sfx()
		queue_redraw()


func _set_rain(active: bool) -> void:
	if _rain_active == active:
		return
	_rain_active = active
	if _biome_weather == null:
		_spawn_biome_weather()
	if _biome_weather != null:
		_biome_weather.set_rain_active(active)


func is_lava_cooled() -> bool:
	return _lava_cooled


func _play_lava_cool_sfx() -> void:
	_play_theme_stream("res://assets/audio/themes/lava_cool.wav")


func _play_electro_sfx() -> void:
	_play_theme_stream("res://assets/audio/themes/electro_crackle.wav")


## Play a one-shot theme SFX by file path, loaded lazily (no preload so a
## missing import file never breaks script parsing).
func _play_theme_stream(path: String) -> void:
	var aud := get_tree().get_first_node_in_group("audio_service")
	if aud == null or not aud.has_method("play_theme_stream"):
		return
	aud.play_theme_stream(path)


func _tick_electro_damage(delta: float) -> void:
	if not _electro_active:
		return
	var r_sq := _electro_radius * _electro_radius
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or not p.get("active"):
			continue
		var h = p.get("health")
		if h == null or h.is_dead:
			continue
		if _electro_origin.distance_squared_to(p.global_position) <= r_sq:
			h.take_damage(ELECTRO_DPS * delta, p)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var eh = e.get("health")
		if eh == null or eh.is_dead:
			continue
		if _electro_origin.distance_squared_to(e.global_position) <= r_sq:
			eh.take_damage(ELECTRO_DPS * 0.6 * delta, e)


func _emit_biome_hazard() -> void:
	var spot := _random_walkable_hazard_spot()
	if spot == null:
		return
	if GameRuntime.biome_id == 1:
		# Volcano geyser: telegraphed expanding circle that damages players AND enemies.
		_emit_biome_hazard_hazard(spot, GeyserRadius, GeyserDamage, "ff5a1e", 1.6, 1.0)
	elif GameRuntime.biome_id == 3:
		# Factory EMP: telegraphed ring that slows and damages.
		_emit_biome_hazard_hazard(spot, EMP_RADIUS, EMP_DAMAGE, "7ec8ff", 1.4, 0.9)


func _emit_biome_hazard_hazard(origin: Vector2, radius: float, damage: float, color_hex: String, telegraph: float, active: float) -> void:
	var hazard := _BIOME_HAZARD.new()
	hazard.global_position = origin
	hazard.configure(radius, damage, Color(color_hex), telegraph, active, GameRuntime.biome_id)
	add_child(hazard)


func _random_walkable_hazard_spot() -> Vector2:
	# Pick a random spot on the playfield, prefer near where the action is (near a player).
	var players := get_tree().get_nodes_in_group("players")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var half := playfield_size() * 0.5
	if not players.is_empty():
		# 60% chance near a random active player, otherwise fully random.
		if rng.randf() < 0.6:
			var alive: Array = []
			for p in players:
				if is_instance_valid(p) and p.get("active") and not ((p.get("health") as HealthComponent).is_dead):
					alive.append(p)
			if alive.size() > 0:
				var focus: Node2D = alive[rng.randi() % alive.size()]
				var angle := rng.randf_range(0.0, TAU)
				var dist := rng.randf_range(180.0, 420.0)
				var spot: Vector2 = focus.global_position + Vector2.from_angle(angle) * dist
				if _snap_feature_to_ground(spot) != null:
					return spot
	# Fully random fallback
	var spot := Vector2(rng.randf_range(-half.x + 80.0, half.x - 80.0), rng.randf_range(-half.y + 80.0, half.y - 80.0))
	return spot


func _spawn_world_features() -> void:
	if not GameRuntime.uses_biomes():
		return
	var ids := WorldFeatureArtScript.feature_ids_for_biome(GameRuntime.biome_id)
	var spots := _world_feature_spots()
	var count := mini(ids.size(), spots.size())
	for index in count:
		var feature := WorldFeatureScript.new()
		feature.name = "WorldFeature_%d" % index
		feature.configure(str(ids[index]))
		feature.global_position = spots[index]
		add_child(feature)


func _world_feature_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var spawn0 := corner_spawn(0)
	if spawn0.length() > 1.0:
		spots.append(_snap_feature_to_ground(spawn0 + (-spawn0).normalized() * 360.0))
	spots.append(_snap_feature_to_ground(Vector2(crater_radius() + 220.0, -48.0)))
	spots.append(_snap_feature_to_ground(Vector2(-(crater_radius() + 200.0), 96.0)))
	return spots


func _snap_feature_to_ground(world_position: Vector2) -> Vector2:
	var candidate := world_position
	if crater_feature_active() and crater_contains(candidate, 48.0):
		var away := candidate if candidate.length() > 1.0 else Vector2.RIGHT
		candidate = away.normalized() * (crater_radius() + 180.0)
	if candidate.distance_to(shop_stand_position()) < SHOP_STAND_CLEARANCE:
		candidate = candidate.rotated(deg_to_rad(40.0))
	if walk_pads.is_empty():
		return candidate
	for pad in walk_pads:
		if _pad_contains(pad, candidate, 36.0):
			return candidate
	var best := candidate
	var best_distance := INF
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) < 96.0:
			continue
		var inner := pad.grow(-40.0)
		var clamped := Vector2(
			clampf(candidate.x, inner.position.x, inner.end.x),
			clampf(candidate.y, inner.position.y, inner.end.y)
		)
		var distance := clamped.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = clamped
	return best


## When a biome carves the field into islands, pull the shop stand onto the big pad
## nearest its default scaled spot so its marker and interact radius sit on walkable
## ground. Grass/classic leaves the static default untouched.
func _snap_shop_stand_to_pad() -> void:
	_shop_position = SHOP_STAND_POSITION * (playfield_size() / BASE_SIZE)
	var best := _shop_position
	var best_distance := INF
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) < 220.0:
			continue
		var inner := pad
		if pad.size.x > SHOP_STAND_CLEARANCE * 2.0 + 8.0 and pad.size.y > SHOP_STAND_CLEARANCE * 2.0 + 8.0:
			inner = pad.grow(-SHOP_STAND_CLEARANCE)
		var candidate := Vector2(
			clampf(_shop_position.x, inner.position.x, inner.end.x),
			clampf(_shop_position.y, inner.position.y, inner.end.y)
		)
		var distance := candidate.distance_to(_shop_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	_shop_position = best


func _layout_seed() -> int:
	if GameRuntime.uses_biomes():
		return LAYOUT_SEED + GameRuntime.biome_id
	return LAYOUT_SEED


func _scatter_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed()
	var limit := playfield_size() * 0.5 - Vector2(WALL_MARGIN, WALL_MARGIN)
	var area_scale := (playfield_size().x + playfield_size().y) / (BASE_SIZE.x + BASE_SIZE.y)
	var base_count := ISLAND_OBSTACLE_COUNT if not walk_pads.is_empty() else OBSTACLE_COUNT
	var wanted := mini(140, int(round(float(base_count) * maxf(1.0, area_scale))))
	# On island biomes, candidates must land inside a walk pad — sampling blindly
	# across the whole playfield makes that a rare hit, so pick a pad first.
	var usable_pads: Array[Rect2] = _rock_pads()
	var attempts := 0
	while obstacles.size() < wanted and attempts < wanted * 160:
		attempts += 1
		var candidate: Vector2
		if not usable_pads.is_empty():
			var pad: Rect2 = usable_pads[rng.randi() % usable_pads.size()]
			candidate = Vector2(
				rng.randf_range(pad.position.x, pad.end.x),
				rng.randf_range(pad.position.y, pad.end.y)
			)
		else:
			candidate = Vector2(
				rng.randf_range(-limit.x, limit.x),
				rng.randf_range(-limit.y, limit.y)
			)
		_try_place_obstacle(candidate, rng)


func _fits_obstacle(candidate: Vector2) -> bool:
	# Rocks don't sit mid-pool — a boulder in lava looks wrong and would block dunk shots.
	if is_in_hazard(candidate, 48.0):
		return false
	if crater_feature_active() and crater_contains(candidate, 80.0):
		return false
	if walk_pads.is_empty():
		return true
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) < 72:
			continue
		if _pad_contains(pad, candidate, 28.0):
			return true
	return false


func _too_close_to_other_obstacle(candidate: Vector2, spacing: float = OBSTACLE_SPACING) -> bool:
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		# Decorative grass/flowers don't block rock placement, and rocks don't
		# push tufts apart at boulder spacing.
		if obstacle.body_radius < 1.0 and spacing > 40.0:
			continue
		var need := spacing
		if obstacle.body_radius < 1.0:
			need = maxf(18.0, spacing)
		if candidate.distance_to(obstacle.global_position) < need:
			return true
	return false


func _near_corner_spawn(candidate: Vector2, radius: float) -> bool:
	for slot in 4:
		if candidate.distance_to(corner_spawn(slot)) < radius:
			return true
	return false


## Sprites that block nothing and are purely cosmetic ground cover. These get baked
## into the arena's single background texture instead of a live Obstacle node, which
## removes thousands of StaticBody2D / CollisionShape2D / Sprite2D + shadow nodes in
## the dense open-field worlds. Collision/interactable props stay as real nodes.
## Trees are safe to bake too: their shadow uses the shared per-type silhouette
## texture and trees are never glow-eligible, so no per-frame behaviour is lost.
func _is_decorative_prop(sprite_id: String, radius: float) -> bool:
	if radius > 0.0:
		return false
	# Trees are live Obstacle nodes again (they keep their own shadow Sprite2D), so
	# they are never baked into the background. Only ground cover (grass/flowers/
	# dirt) bakes into the background texture.
	if sprite_id.begins_with("grass") or sprite_id == "flower_patch" \
			or sprite_id == "grass_lush" or sprite_id == "grass_meadow" \
			or sprite_id == "dirt_tile":
		return true
	return false


func _add_obstacle(world_position: Vector2, type_data: Dictionary) -> void:
	var sprite_id := str(type_data.sprite)
	var radius := float(type_data.radius)
	# Bake pure decoration so a dense grass meadow doesn't carry thousands of
	# per-frame nodes. The eraser in the world editor only targets collision props
	# and features, so baked cover is safe to fold into the background.
	if _is_decorative_prop(sprite_id, radius):
		baked_props.append({"sprite": sprite_id, "pos": world_position})
		return
	var obstacle := OBSTACLE_SCENE.instantiate() as Obstacle
	obstacle.global_position = world_position
	add_child(obstacle)
	obstacle.configure(str(type_data.sprite), float(type_data.radius), PIXEL_ZOOM, float(type_data.lift))
	obstacle.add_to_group("obstacles")
	obstacle.add_to_group("obstacle_" + str(type_data.sprite))
	register_obstacle(obstacle)


func register_obstacle(obstacle: Obstacle) -> void:
	if obstacle != null and not obstacles.has(obstacle):
		obstacles.append(obstacle)


func unregister_obstacle(obstacle: Obstacle) -> void:
	obstacles.erase(obstacle)


func _rock_pads() -> Array[Rect2]:
	var usable: Array[Rect2] = []
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) >= 72:
			usable.append(pad)
	return usable


func _try_place_obstacle(candidate: Vector2, rng: RandomNumberGenerator, type_override: Dictionary = {}, spacing: float = OBSTACLE_SPACING) -> bool:
	if candidate.length() < SPAWN_CLEARANCE:
		return false
	if _near_corner_spawn(candidate, SPAWN_CLEARANCE * 0.72):
		return false
	if candidate.distance_to(shop_stand_position()) < SHOP_STAND_CLEARANCE:
		return false
	if _on_landmark_pad(candidate, 12.0):
		return false
	if GameRuntime.biome_id == 1 and crater_contains(candidate, 40.0):
		return false
	if not _fits_obstacle(candidate):
		return false
	if _too_close_to_other_obstacle(candidate, spacing):
		return false
	var type_data: Dictionary = type_override
	if type_data.is_empty():
		type_data = _random_scatter_type(rng)
	_add_obstacle(candidate, type_data)
	return true


func _random_scatter_type(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = []
	pool.append_array(OBSTACLE_TYPES)
	match GameRuntime.biome_id:
		1:
			# Volcano: fiery rocks + obsidian shards instead of plain boulders
			pool.append({"sprite": "volcano_rock_fiery", "radius": 18.0, "lift": 4.0})
			pool.append({"sprite": "volcano_obsidian", "radius": 16.0, "lift": 4.0})
			pool.append({"sprite": "lava_chunk", "radius": 16.0, "lift": 8.0})
		2:
			# Ice: snow hills + frost-covered rocks instead of plain crystals
			pool.append({"sprite": "ice_snow_hill", "radius": 20.0, "lift": 3.0})
			pool.append({"sprite": "ice_frost_rock", "radius": 16.0, "lift": 4.0})
			pool.append({"sprite": "ice_crystal", "radius": 14.0, "lift": 16.0})
		3:
			# Factory: utility masts, towers, crates, barrels — industrial clutter
			pool.append({"sprite": "factory_mast", "radius": 14.0, "lift": 6.0})
			pool.append({"sprite": "factory_tower", "radius": 16.0, "lift": 6.0})
			pool.append({"sprite": "crate_box", "radius": 18.0, "lift": 8.0})
			pool.append({"sprite": "barrel_keg", "radius": 16.0, "lift": 8.0})
			pool.append({"sprite": "vent_cap", "radius": 16.0, "lift": 6.0})
		4:
			# Docks: wooden poles, barrel stacks, crates, town buildings
			pool.append({"sprite": "docks_pole", "radius": 12.0, "lift": 10.0})
			pool.append({"sprite": "docks_barrel_stack", "radius": 16.0, "lift": 8.0})
			pool.append({"sprite": "bollard", "radius": 10.0, "lift": 20.0})
			pool.append({"sprite": "crate_box", "radius": 18.0, "lift": 8.0})
			# Town landmarks — distinct buildings for the dockside town feel.
			pool.append({"sprite": "town_house", "radius": 22.0, "lift": 12.0})
			pool.append({"sprite": "town_house2", "radius": 20.0, "lift": 10.0})
			pool.append({"sprite": "town_house3", "radius": 24.0, "lift": 12.0})
			pool.append({"sprite": "town_cottage", "radius": 18.0, "lift": 8.0})
			pool.append({"sprite": "town_shop", "radius": 26.0, "lift": 12.0})
			pool.append({"sprite": "town_church", "radius": 20.0, "lift": 16.0})
			pool.append({"sprite": "town_well", "radius": 14.0, "lift": 6.0})
	return pool[rng.randi() % pool.size()]


func _ground_cover_sprites() -> Array[String]:
	match GameRuntime.biome_id:
		1:
			# Volcano: no grass, no flowers — only rocky/volcanic ground cover.
			return ["volcano_rock_fiery", "volcano_obsidian", "lava_chunk", "volcano_rock_fiery", "volcano_obsidian"]
		2:
			# Ice/water: no grass, no flowers — only ice/snow props.
			return ["ice_snow_hill", "ice_frost_rock", "ice_crystal", "ice_snow_hill", "ice_frost_rock"]
		3:
			return ["crate_box", "barrel_keg", "vent_cap", "factory_mast", "factory_tower"]
		4:
			# Docks: no random houses — towns are authored via the world editor, not scattered.
			return ["bollard", "barrel_keg", "docks_pole", "docks_barrel_stack"]
		_:
			# Grass world: basic grass only. Flowers/bushes are placed manually
			# via the world editor — no random scattering here.
			return [
				"grass_tuft", "grass_tuft", "grass_wild", "grass_wild",
				"grass_long",
			]


func _cover_type(sprite_id: String) -> Dictionary:
	return {"sprite": sprite_id, "radius": 0.0, "lift": 0.0}


func _scatter_ground_cover() -> void:
	# Every biome (including the grass meadow, biome 0) scatters procedural ground
	# cover so the "regular map" always reads as a dense, rich field — grass,
	# flowers, tufts — rather than an empty meadow. The world editor can still add
	# extra props on top of this base; it no longer has to be the sole source.
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 211
	var kit := _ground_cover_sprites()
	if kit.is_empty():
		return
	var limit := playfield_size() * 0.5 - Vector2(WALL_MARGIN, WALL_MARGIN)
	var wanted := DECAL_COUNT if walk_pads.is_empty() else int(round(float(DECAL_COUNT) * 0.7))
	var pads: Array[Rect2] = _rock_pads()
	var planted := 0
	var attempts := 0
	while planted < wanted and attempts < wanted * 50:
		attempts += 1
		var candidate: Vector2
		if not pads.is_empty():
			var pad: Rect2 = pads[rng.randi() % pads.size()]
			candidate = Vector2(
				rng.randf_range(pad.position.x, pad.end.x),
				rng.randf_range(pad.position.y, pad.end.y)
			)
		else:
			candidate = Vector2(rng.randf_range(-limit.x, limit.x), rng.randf_range(-limit.y, limit.y))
		var sprite_id := kit[rng.randi() % kit.size()]
		var spacing := 22.0 if float(_cover_type(sprite_id).radius) < 1.0 else 48.0
		if _try_place_obstacle(candidate, rng, _cover_type(sprite_id), spacing):
			planted += 1
	if planted > 0:
		print("[ground_cover] planted ", planted, " of ", wanted, " (baked_props now ", baked_props.size(), ")")
	else:
		print("[ground_cover] planted 0 of ", wanted, " — checks failing. limit=", limit, " pads=", pads.size())


## Stuff extra boulders onto every walk pad so island worlds don't look empty.
func _pack_pad_rocks() -> void:
	if walk_pads.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 17
	for pad in _rock_pads():
		var extra := 3
		if mini(int(pad.size.x), int(pad.size.y)) >= 220:
			extra = 6
		for _i in extra:
			var candidate := Vector2(
				rng.randf_range(pad.position.x, pad.end.x),
				rng.randf_range(pad.position.y, pad.end.y)
			)
			_try_place_obstacle(candidate, rng)


## Grass (and any leftover open ground) gets grove rings and hedge lines so the
## field isn't a flat empty lawn between the four contested shrines.
func _plant_cover_rocks() -> void:
	# Island biomes stay open — rocks on narrow pads used to choke every route.
	if not walk_pads.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 91
	var factor := playfield_size() / BASE_SIZE
	for spot in contested_landmark_spots():
		for index in 12:
			if index % 4 == 0:
				continue
			var radius := 210.0 + rng.randf_range(-18.0, 36.0)
			var candidate := spot + Vector2.RIGHT.rotated(TAU * float(index) / 12.0 + 0.18) * radius
			_try_place_obstacle(candidate, rng)
	var groves: Array[Vector2] = [
		Vector2(-720, -280), Vector2(780, -340), Vector2(-640, 360), Vector2(700, 300),
		Vector2(-240, -620), Vector2(280, 640), Vector2(-1100, 40), Vector2(1180, -40),
		Vector2(-420, 180), Vector2(460, -160), Vector2(40, -880), Vector2(-80, 900),
	]
	for grove in groves:
		var center := grove * factor
		for _i in 5:
			var candidate := center + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
			_try_place_obstacle(candidate, rng)
	var hedges: Array[Vector2] = [
		Vector2(-1600, -700), Vector2(-1400, -500), Vector2(1500, -680), Vector2(1320, -460),
		Vector2(-1560, 620), Vector2(-1340, 420), Vector2(1480, 640), Vector2(1280, 440),
		Vector2(-200, -1280), Vector2(200, -1280), Vector2(-180, 1240), Vector2(220, 1240),
	]
	for hedge in hedges:
		_try_place_obstacle(hedge * factor, rng)


func _build_terrain_zones() -> void:
	terrain_zones.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 7
	var half := playfield_size() * 0.5 - Vector2(80.0, 80.0)
	var kinds: Array[String] = ZONE_KINDS.duplicate()
	for index in kinds.size():
		var swap := rng.randi_range(index, kinds.size() - 1)
		var temp := kinds[index]
		kinds[index] = kinds[swap]
		kinds[swap] = temp
	for index in 9:
		var grid_x := index % 3
		var grid_y := int(index / 3)
		var center := Vector2(
			lerpf(-half.x, half.x, (float(grid_x) + 0.5) / 3.0),
			lerpf(-half.y, half.y, (float(grid_y) + 0.5) / 3.0)
		)
		center += Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-160.0, 160.0))
		terrain_zones.append({
			"kind": kinds[index],
			"center": center,
			"rx": rng.randf_range(720.0, 980.0),
			"ry": rng.randf_range(520.0, 760.0),
			"warp": rng.randf_range(0.78, 1.28),
		})


func _zone_sample(zone: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var angle := rng.randf() * TAU
	var radius := sqrt(rng.randf())
	return zone.center + Vector2(cos(angle) * float(zone.rx) * radius, sin(angle) * float(zone.ry) * radius)


func _skip_auto_props() -> bool:
	return get_parent() != null and get_parent().is_in_group("world_editor")


func vision_tree_positions() -> PackedVector2Array:
	var points := PackedVector2Array()
	for obstacle in obstacles:
		if obstacle != null and is_instance_valid(obstacle) and obstacle.is_vision_blocker():
			points.append(obstacle.global_position)
	return points


func _tree_obstacle_type(rng: RandomNumberGenerator) -> Dictionary:
	var sprite := "tree_oak"
	match GameRuntime.biome_id:
		1:
			sprite = "tree_dead"
		2:
			sprite = "tree_pine"
		3:
			sprite = "tree_pipe"
		4:
			sprite = "tree_piling"
		_:
			sprite = "tree_pine" if rng.randf() < 0.35 else "tree_oak"
	return {"sprite": sprite, "radius": 18.0, "lift": 28.0}


func _plant_zone_props() -> void:
	if terrain_zones.is_empty():
		return
	# Volcano and ice biomes: no trees — only rocks and terrain-specific props.
	var biome := GameRuntime.biome_id if GameRuntime.uses_biomes() else 0
	var no_trees := biome == 1 or biome == 2
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 131
	for zone in terrain_zones:
		var kind := str(zone.kind)
		match kind:
			"forest", "thicket", "mixed", "grass":
				if no_trees:
					continue
				var trees := 42 if kind == "forest" else (16 if kind == "thicket" else (10 if kind == "mixed" else 6))
				var spacing := TREE_SPACING if kind == "forest" else (96.0 if kind == "thicket" else (TREE_SPACING if kind == "mixed" else TREE_SPACING * 1.15))
				for _i in trees:
					_try_place_obstacle(_zone_sample(zone, rng), rng, _tree_obstacle_type(rng), spacing)
				if kind == "forest":
					for _i in 10:
						_try_place_obstacle(_zone_sample(zone, rng), rng, _tree_obstacle_type(rng), TREE_SPACING * 0.82)
			"rocks":
				var extra := 14 if walk_pads.is_empty() else 6
				for _i in extra:
					_try_place_obstacle(_zone_sample(zone, rng), rng, {}, 80.0)


func _decal_sprites_for_zone(kind: String) -> Array[String]:
	var biome := GameRuntime.biome_id if GameRuntime.uses_biomes() else 0
	match biome:
		1:
			# Volcano: no grass or flowers — volcanic rock and lava only.
			return ["volcano_rock_fiery", "volcano_obsidian", "rock_small", "lava_chunk"]
		2:
			# Ice/water: no grass or flowers — ice/snow only.
			return ["ice_snow_hill", "ice_frost_rock", "ice_crystal", "rock_small"]
		3:
			match kind:
				"forest", "thicket":
					return ["grass_tuft", "grass_long"]
				"rocks", "barren":
					return ["rock_small", "grass_tuft"]
				"flowers", "bloom":
					return ["grass_bloom", "grass_flower"]
				_:
					return ["grass_tuft", "grass_long"]
		4:
			match kind:
				"forest", "thicket":
					return ["grass_long", "grass_tuft", "grass_bush"]
				"rocks", "barren":
					return ["rock_small", "grass_tuft"]
				"flowers", "bloom":
					return ["grass_flower", "grass_bloom"]
				_:
					return ["grass_tuft", "grass_long"]
		_:
			match kind:
				"grass":
					return ["grass_tuft", "grass_long", "grass_tuft"]
				"flowers":
					return ["grass_flower", "grass_flower", "grass_bloom"]
				"forest":
					return ["grass_tuft", "grass_bush", "grass_long", "grass_mushroom"]
				"rocks":
					return ["rock_small", "grass_tuft", "rock_small"]
				"clearing":
					return ["grass_flower", "grass_tuft"]
				"thicket":
					return ["grass_bush", "grass_long", "grass_tuft", "rock_small"]
				"bloom":
					return ["grass_bloom", "grass_flower", "grass_bloom"]
				"barren":
					return ["rock_small", "grass_tuft"]
				_:
					return DECAL_SPRITES


## Corner spawn rooms, mid-edge landmark plazas, and the four lanes that connect them.
## Authored in BASE_SIZE space so they scale with the playfield. `wide` is factory halls.
func _contest_lane_pads(wide: bool) -> Array[Rect2]:
	var lane := 280.0 if wide else 240.0
	var half_lane := lane * 0.5
	return [
		Rect2(-2132, -1448, 640, 500),
		Rect2(1492, -1448, 640, 500),
		Rect2(-2132, 948, 640, 500),
		Rect2(1492, 948, 640, 500),
		Rect2(-380, -380, 760, 760),
		Rect2(-240, -852, 480, 360),
		Rect2(828, -180, 480, 360),
		Rect2(-240, 492, 480, 360),
		Rect2(-1248, -180, 480, 360),
		Rect2(-2200, -half_lane, 4400, lane),
		Rect2(-half_lane, -1500, lane, 3000),
		Rect2(-1912, -1288, 1842, lane),
		Rect2(-1912, -1288, lane, 1218),
		Rect2(70, -1288, 1842, lane),
		Rect2(1832, -1288, lane, 1218),
		Rect2(-1912, 1168, 1842, lane),
		Rect2(-1912, 70, lane, 1218),
		Rect2(70, 1168, 1842, lane),
		Rect2(1832, 70, lane, 1218),
	]


func _pads_for_biome(biome: int) -> Array[Rect2]:
	var pads: Array[Rect2] = []
	match biome:
		1:
			pads.append_array(_contest_lane_pads(false))
			pads.append_array([
				Rect2(-360, -360, 720, 720),
				Rect2(-56, -720, 112, 380),
				Rect2(-56, 340, 112, 380),
				Rect2(-720, -56, 380, 112),
				Rect2(340, -56, 380, 112),
				Rect2(420, -560, 360, 300),
				Rect2(220, -280, 220, 56),
				Rect2(680, -280, 140, 200),
				Rect2(560, -90, 56, 180),
				Rect2(480, 80, 280, 220),
				Rect2(200, 180, 300, 56),
				Rect2(-140, 480, 280, 220),
				Rect2(-1080, -200, 280, 280),
				Rect2(-820, -40, 560, 56),
				Rect2(-1040, 220, 220, 180),
				Rect2(-840, 160, 56, 80),
				Rect2(-1080, -620, 240, 180),
				Rect2(-860, -460, 56, 280),
				Rect2(80, -720, 180, 140),
				Rect2(-420, -80, 140, 110),
				Rect2(820, -280, 400, 240),
				Rect2(-1480, -620, 400, 220),
				Rect2(-200, 700, 360, 320),
				Rect2(-620, -980, 220, 160),
				Rect2(980, 720, 240, 180),
				Rect2(-1600, 320, 200, 160),
				Rect2(1400, -720, 180, 140),
			])
		2:
			pads.append_array(_contest_lane_pads(false))
			pads.append_array([
				Rect2(-200, -150, 400, 300),
				Rect2(520, -420, 380, 300),
				Rect2(180, -180, 360, 56),
				Rect2(-1100, -760, 340, 220),
				Rect2(-800, -560, 56, 420),
				Rect2(-800, -160, 620, 56),
				Rect2(660, 400, 380, 260),
				Rect2(160, 130, 56, 300),
				Rect2(160, 400, 520, 56),
				Rect2(-1100, 420, 360, 260),
				Rect2(-780, 140, 56, 300),
				Rect2(-780, 140, 580, 56),
				Rect2(40, -60, 110, 80),
				Rect2(-420, -320, 130, 90),
				Rect2(880, -80, 150, 110),
				Rect2(-80, 260, 90, 70),
				Rect2(320, 220, 100, 80),
				Rect2(-980, -40, 120, 90),
				Rect2(40, -720, 160, 120),
				Rect2(80, -600, 56, 460),
				Rect2(-500, 500, 140, 100),
				Rect2(-380, 420, 56, 100),
				Rect2(1030, -100, 380, 260),
				Rect2(-1500, -800, 400, 300),
				Rect2(600, 660, 500, 340),
				Rect2(-1680, 180, 220, 160),
				Rect2(1480, -640, 200, 150),
				Rect2(-540, 880, 180, 140),
				Rect2(420, -1100, 200, 140),
			])
		3:
			pads.append_array(_contest_lane_pads(true))
			pads.append_array([
				Rect2(-1100, -100, 2200, 200),
				Rect2(-100, -740, 200, 1480),
				Rect2(-1060, -740, 180, 1480),
				Rect2(880, -740, 180, 1480),
				Rect2(-1100, -740, 2200, 140),
				Rect2(-1100, 600, 2200, 140),
				Rect2(120, -440, 740, 260),
				Rect2(-860, -500, 280, 200),
				Rect2(240, -500, 280, 180),
				Rect2(-860, 280, 280, 200),
				Rect2(240, 280, 280, 200),
				Rect2(-600, -180, 56, 80),
				Rect2(160, -180, 56, 80),
				Rect2(-600, 100, 56, 80),
				Rect2(160, 100, 56, 80),
				Rect2(-420, -720, 200, 120),
				Rect2(220, 500, 200, 120),
				Rect2(1100, -300, 320, 600),
				Rect2(-1420, -300, 320, 600),
				Rect2(-300, -1100, 600, 360),
				Rect2(-1680, 520, 280, 220),
				Rect2(1320, 520, 280, 220),
				Rect2(1320, -720, 260, 200),
				Rect2(-700, 880, 320, 180),
			])
		4:
			pads.append_array(_contest_lane_pads(false))
			pads.append_array([
				Rect2(-1100, -50, 2200, 120),
				Rect2(-1100, -500, 360, 920),
				Rect2(380, -480, 460, 440),
				Rect2(-900, 50, 72, 720),
				Rect2(-460, 50, 72, 700),
				Rect2(-20, 50, 72, 740),
				Rect2(420, 50, 72, 700),
				Rect2(860, 50, 72, 660),
				Rect2(-220, -740, 72, 710),
				Rect2(180, -740, 72, 420),
				Rect2(-720, -720, 220, 180),
				Rect2(900, -280, 180, 140),
				Rect2(-980, 620, 140, 90),
				Rect2(-40, 640, 120, 80),
				Rect2(520, 620, 140, 90),
				Rect2(-980, 540, 56, 90),
				Rect2(20, 560, 56, 90),
				Rect2(580, 540, 56, 90),
				Rect2(640, -200, 160, 120),
				Rect2(1080, -320, 340, 300),
				Rect2(-1460, -350, 360, 500),
				Rect2(-140, 720, 360, 300),
				Rect2(-1760, 640, 240, 160),
				Rect2(1560, 640, 240, 160),
				Rect2(1560, -820, 220, 160),
				Rect2(-400, -1180, 280, 140),
			])
		_:
			pass
	pads.append_array(_world_filigree_pads(biome))
	return _scale_pads(_thicken_pads(pads, 200.0))


## Extra rooms, doglegs and stepping stones unique to each carved world so lanes
## aren't just a plus-sign through empty void.
func _world_filigree_pads(biome: int) -> Array[Rect2]:
	match biome:
		1:
			return [
				Rect2(-280, -1100, 160, 120),
				Rect2(300, 980, 180, 130),
				Rect2(-1280, -980, 140, 110),
				Rect2(1180, 280, 150, 100),
				Rect2(-480, 820, 90, 220),
				Rect2(640, -980, 90, 200),
				Rect2(-900, 720, 180, 70),
				Rect2(860, 180, 70, 180),
				Rect2(-1800, -200, 180, 80),
				Rect2(1640, 360, 170, 90),
				Rect2(-220, 1120, 150, 90),
				Rect2(180, -1240, 150, 90),
				Rect2(-1020, -1180, 80, 220),
				Rect2(1080, 760, 80, 200),
				Rect2(-1760, 760, 140, 80),
				Rect2(1500, -200, 80, 160),
				Rect2(-80, -1280, 200, 70),
				Rect2(-720, 1080, 70, 160),
			]
		2:
			return [
				Rect2(-200, -980, 120, 90),
				Rect2(240, 980, 130, 90),
				Rect2(-1280, -420, 100, 80),
				Rect2(1320, 280, 110, 80),
				Rect2(-640, 160, 80, 200),
				Rect2(520, -200, 80, 180),
				Rect2(-40, 820, 200, 56),
				Rect2(-900, -980, 160, 70),
				Rect2(-1760, -200, 160, 80),
				Rect2(1680, 120, 150, 80),
				Rect2(-320, 1120, 180, 80),
				Rect2(280, -1240, 160, 80),
				Rect2(-1480, 640, 90, 180),
				Rect2(1400, -880, 90, 180),
				Rect2(-80, -1280, 220, 64),
				Rect2(40, 1180, 200, 64),
				Rect2(-1880, -720, 140, 70),
				Rect2(1760, 720, 140, 70),
			]
		3:
			return [
				Rect2(-480, -1100, 200, 160),
				Rect2(480, -1100, 200, 160),
				Rect2(-1680, -720, 220, 180),
				Rect2(40, 880, 180, 140),
				Rect2(-240, 320, 80, 220),
				Rect2(280, -320, 80, 220),
				Rect2(-1280, 40, 220, 80),
				Rect2(1080, 40, 220, 80),
				Rect2(-1880, -200, 180, 120),
				Rect2(1680, -200, 180, 120),
				Rect2(-1880, 200, 180, 120),
				Rect2(1680, 200, 180, 120),
				Rect2(-80, -1280, 240, 90),
				Rect2(-80, 1180, 240, 90),
				Rect2(-400, 1080, 80, 180),
				Rect2(320, 1080, 80, 180),
				Rect2(-400, -1280, 80, 180),
				Rect2(320, -1280, 80, 180),
				Rect2(-1480, 880, 160, 80),
				Rect2(1280, -980, 160, 80),
			]
		4:
			return [
				Rect2(320, -1180, 240, 140),
				Rect2(-1760, -720, 200, 140),
				Rect2(-80, 980, 200, 120),
				Rect2(980, 280, 140, 90),
				Rect2(-1280, 280, 140, 90),
				Rect2(200, -980, 72, 220),
				Rect2(-520, -980, 72, 200),
				Rect2(720, 820, 180, 70),
				Rect2(-1880, 40, 160, 90),
				Rect2(1760, 40, 160, 90),
				Rect2(-80, -1320, 220, 80),
				Rect2(-80, 1180, 220, 80),
				Rect2(-900, -1180, 72, 200),
				Rect2(860, -1180, 72, 200),
				Rect2(-900, 980, 72, 180),
				Rect2(860, 980, 72, 180),
				Rect2(-1480, -980, 180, 80),
				Rect2(1400, 880, 180, 80),
				Rect2(40, 280, 90, 220),
			]
		_:
			return []


## Narrow island bridges used to be 56–112 wide; bump every pad so routes stay open.
func _thicken_pads(pads: Array[Rect2], min_span: float) -> Array[Rect2]:
	var thick: Array[Rect2] = []
	for pad in pads:
		var rect := pad
		if rect.size.x < min_span:
			var extra := min_span - rect.size.x
			rect.position.x -= extra * 0.5
			rect.size.x = min_span
		if rect.size.y < min_span:
			var extra := min_span - rect.size.y
			rect.position.y -= extra * 0.5
			rect.size.y = min_span
		thick.append(rect)
	return thick


func _scale_pads(pads: Array[Rect2]) -> Array[Rect2]:
	var factor := playfield_size() / BASE_SIZE
	if factor.is_equal_approx(Vector2.ONE):
		return pads
	var scaled: Array[Rect2] = []
	for pad in pads:
		scaled.append(Rect2(pad.position * factor, pad.size * factor))
	return scaled


## Rim dressing stays outside the stand circle so the pad itself stays clear.
func _dress_landmark_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 44
	var kit := _ground_cover_sprites()
	for landmark in landmarks:
		if not is_instance_valid(landmark):
			continue
		var effect := str(landmark.effect_id)
		if effect == "pulse_wipe" or effect == "battle_frenzy":
			for index in 7:
				var angle := TAU * float(index) / 7.0 + 0.21
				var dist := ArenaLandmark.STAND_RADIUS + rng.randf_range(36.0, 88.0)
				_try_place_obstacle(landmark.position + Vector2.from_angle(angle) * dist, rng)
		var extra := 8
		if effect == "heal_all":
			extra = 14
		elif effect == "freeze_time":
			extra = 10
		for _i in extra:
			var ring := ArenaLandmark.STAND_RADIUS + rng.randf_range(28.0, 90.0)
			var spot := landmark.position + Vector2.from_angle(rng.randf() * TAU) * ring
			var sprite_id := kit[rng.randi() % kit.size()]
			if effect == "heal_all":
				sprite_id = "grass_bloom" if rng.randf() < 0.5 else "flower_patch"
			_try_place_obstacle(spot, rng, _cover_type(sprite_id), 20.0)


func _on_landmark_pad(world_position: Vector2, extra: float = 0.0) -> bool:
	var need := ArenaLandmark.STAND_RADIUS + extra
	for landmark in landmarks:
		if is_instance_valid(landmark) and world_position.distance_to(landmark.global_position) < need:
			return true
	return false


func _fit_walls() -> void:
	var walls := get_node_or_null("Walls") as StaticBody2D
	if walls == null:
		return
	var half := playfield_size() * 0.5
	var top := walls.get_node_or_null("Top") as CollisionShape2D
	var bottom := walls.get_node_or_null("Bottom") as CollisionShape2D
	var left := walls.get_node_or_null("Left") as CollisionShape2D
	var right := walls.get_node_or_null("Right") as CollisionShape2D
	if top != null:
		var bar := RectangleShape2D.new()
		bar.size = Vector2(playfield_size().x + 80.0, 40.0)
		top.shape = bar
		top.position = Vector2(0.0, -half.y - 20.0)
	if bottom != null:
		var bar := RectangleShape2D.new()
		bar.size = Vector2(playfield_size().x + 80.0, 40.0)
		bottom.shape = bar
		bottom.position = Vector2(0.0, half.y + 20.0)
	if left != null:
		var bar := RectangleShape2D.new()
		bar.size = Vector2(40.0, playfield_size().y + 80.0)
		left.shape = bar
		left.position = Vector2(-half.x - 20.0, 0.0)
	if right != null:
		var bar := RectangleShape2D.new()
		bar.size = Vector2(40.0, playfield_size().y + 80.0)
		right.shape = bar
		right.position = Vector2(half.x + 20.0, 0.0)


func _build_void_bodies() -> void:
	void_rects.clear()
	if walk_pads.is_empty():
		return
	void_rects.append(_arena_rect())
	for pad in walk_pads:
		var next_voids: Array[Rect2] = []
		for piece in void_rects:
			next_voids.append_array(_subtract_rect(piece, pad))
		void_rects = next_voids
	# Geometry only — heroes and creeps walk the gaps and take the 5%/s burn.
	# Outer Walls stay solid so nobody leaves the arena.


func _arena_rect() -> Rect2:
	return Rect2(-playfield_size() * 0.5, playfield_size())


func _subtract_rect(base: Rect2, hole: Rect2) -> Array[Rect2]:
	var pieces: Array[Rect2] = []
	var clip := base.intersection(hole)
	if clip.size.x <= 1.0 or clip.size.y <= 1.0:
		pieces.append(base)
		return pieces
	var base_end := base.end
	var clip_end := clip.end
	if clip.position.y > base.position.y:
		pieces.append(Rect2(base.position, Vector2(base.size.x, clip.position.y - base.position.y)))
	if clip_end.y < base_end.y:
		pieces.append(Rect2(Vector2(base.position.x, clip_end.y), Vector2(base.size.x, base_end.y - clip_end.y)))
	if clip.position.x > base.position.x:
		pieces.append(Rect2(Vector2(base.position.x, clip.position.y), Vector2(clip.position.x - base.position.x, clip.size.y)))
	if clip_end.x < base_end.x:
		pieces.append(Rect2(Vector2(clip_end.x, clip.position.y), Vector2(base_end.x - clip_end.x, clip.size.y)))
	return pieces


func _draw() -> void:
	var rect := _arena_rect()
	if GameRuntime.is_classic():
		_draw_classic_grid(rect)
		return

	if walk_pads.is_empty():
		_draw_ground_rect(rect)
	else:
		_draw_void_rect(rect)
		_draw_void_wash(rect)
		for pad in walk_pads:
			_draw_ground_rect(pad.grow(PAD_DRAW_RIM))
		_draw_pad_shores()
	_draw_crater()
	_draw_decals()
	_draw_hazards()
	_draw_cooled_lava_overlay()
	_draw_electro_ground()
	_draw_night_glow_overlays()
	if GameRuntime.uses_biomes():
		# Biome accent rims match the desaturated tiles in tobor_world_art.gd (roughly
		# 30% gray mixed in) so the arena frame no longer pops against a muted floor.
		var rim := Color("1a2a18")
		var inner := Color(0.09, 0.16, 0.09, 0.40)
		match GameRuntime.biome_id:
			1:
				rim = Color("a8664a")
				inner = Color(0.22, 0.11, 0.08, 0.40)
			2:
				rim = Color("7a94a4")
				inner = Color(0.11, 0.16, 0.22, 0.40)
			3:
				rim = Color("5a8280")
				inner = Color(0.09, 0.11, 0.13, 0.40)
			4:
				rim = Color("66788c")
				inner = Color(0.10, 0.12, 0.17, 0.40)
		draw_rect(rect, rim, false, 16.0)
		draw_rect(rect.grow(-16.0), inner, false, 4.0)
	else:
		draw_rect(rect, Color("1a2a18"), false, 16.0)
		draw_rect(rect.grow(-16.0), Color(0.09, 0.16, 0.09, 0.40), false, 4.0)


func _void_color() -> Color:
	match GameRuntime.biome_id:
		1:
			return Color("4a1408")
		2:
			return Color("1a3a58")
		3:
			return Color("12141a")
		4:
			return Color("0e2438")
		_:
			return Color("2a2018")


## Slow current: every WATER_DRIFT_INTERVAL seconds the void tile's sampled UV nudges one
## step along a fixed direction (see _update_water_drift) so water/lava/slag reads as
## flowing instead of a static image, without redrawing every frame — same texture, same
## tint, it just steps a little. Fixed direction (not random) keeps every co-op peer's
## draw identical since they all tick the same timer off the same delta.
func _draw_void_rect(world_rect: Rect2) -> void:
	var void_tex := SpriteLibrary.texture_for("void_tile")
	var tint := _void_tile_tint()
	if void_tex == null:
		draw_rect(world_rect, _void_color(), true)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
	var dest := Rect2(world_rect.position / PIXEL_ZOOM, world_rect.size / PIXEL_ZOOM)
	draw_texture_rect_region(
		void_tex,
		dest,
		Rect2(dest.position + _water_drift_offset, dest.size),
		tint,
		false,
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _void_tile_tint() -> Color:
	# Keep void quieter than heroes/enemies so units pop. No chroma boosts.
	# At night, lava/fire biomes compensate for the dark ambient so they stay
	# bright and read as glowing rather than just darkened.
	var night_boost := _night_glow_boost()
	match GameRuntime.biome_id:
		1:
			# Volcano lava: push it clearly red/orange so it reads as molten, not grey.
			return Color(0.86, 0.34, 0.20, 1.0) * night_boost
		2:
			return Color(0.70, 0.74, 0.78, 1.0)
		3:
			return Color(0.46, 0.46, 0.48, 1.0)
		4:
			# Factory: slight warm glow at night so powerlines read as energized.
			return Color(0.66, 0.70, 0.74, 1.0) * night_boost
		_:
			return Color.WHITE


## Returns a multiplier that compensates for the night ambient darkening on
## emissive terrain (lava, factory powerlines). At night the CanvasModulate
## applies a ~0.38-0.58 blue tint; this boost pushes those specific tiles back
## to full brightness and slightly above, so they "glow" against the darkness.
func _night_glow_boost() -> float:
	if not WorldClock.is_night:
		return 1.0
	return 1.5


func _draw_void_wash(world_rect: Rect2) -> void:
	match GameRuntime.biome_id:
		1:
			draw_rect(world_rect, Color(0.28, 0.22, 0.20, 0.22), true)
		2:
			draw_rect(world_rect, Color(0.18, 0.32, 0.42, 0.10), true)
		3:
			draw_rect(world_rect, Color(0.10, 0.10, 0.12, 0.28), true)
		4:
			draw_rect(world_rect, Color(0.14, 0.26, 0.36, 0.10), true)


func _draw_pad_shores() -> void:
	var rim := Color.TRANSPARENT
	var width := 6.0
	match GameRuntime.biome_id:
		1:
			rim = Color("8a5a40")
			width = 8.0
		2:
			rim = Color("4a6880")
			width = 5.0
		3:
			rim = Color("2a2e38")
			width = 7.0
		4:
			rim = Color("3a5870")
			width = 5.0
		_:
			return
	for pad in walk_pads:
		draw_rect(pad, rim, false, width)


func _draw_ground_rect(world_rect: Rect2) -> void:
	var ground := SpriteLibrary.texture_for(_ground_tile_id())
	if ground == null:
		var fill := Color("2f4f26")
		if GameRuntime.uses_biomes() and GameRuntime.biome_id != 0:
			fill = _void_color().lightened(0.12)
		draw_rect(world_rect, fill, true)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
	draw_texture_rect(
		ground,
		Rect2(world_rect.position / PIXEL_ZOOM, world_rect.size / PIXEL_ZOOM),
		true,
		_ground_tile_modulate()
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var wash := _ground_desat_wash()
	if wash.a > 0.0:
		draw_rect(world_rect, wash, true)


## Biome-aware ground tile. tobor_world_art generates tw_<biome>_grass_tile for each
## non-grass world; fall back to the plain grass tile when a biome isn't customized.
func _ground_tile_id() -> String:
	if not GameRuntime.uses_biomes() or GameRuntime.biome_id <= 0:
		return "grass_tile"
	var biome := GameRuntime.biome_key()
	if biome == "":
		return "grass_tile"
	var candidate := "tw_%s_grass_tile" % biome
	if SpriteLibrary.texture_for(candidate) != null:
		return candidate
	return "grass_tile"


func _ground_tile_modulate() -> Color:
	# Mute biome floors only. Props, enemies, and heroes stay full chroma.
	# Volcano floor stays warmer/brighter at night so the lava world reads as alive.
	var night_boost := _night_glow_boost()
	match GameRuntime.biome_id:
		1:
			return Color(0.46, 0.44, 0.42) * night_boost
		2:
			return Color(0.68, 0.72, 0.76)
		3:
			return Color(0.48, 0.48, 0.50)
		4:
			# Factory floor: slight warm boost at night for powerline glow.
			return Color(0.64, 0.68, 0.72) * night_boost
		_:
			return Color.WHITE


func _ground_desat_wash() -> Color:
	match GameRuntime.biome_id:
		1:
			return Color(0.32, 0.28, 0.26, 0.42)
		3:
			return Color(0.22, 0.22, 0.24, 0.40)
		_:
			return Color(0, 0, 0, 0)


func _zone_ground_tile(kind: String) -> String:
	match kind:
		"forest", "thicket":
			return "grass_lush"
		"flowers", "bloom", "clearing":
			return "grass_meadow"
		"rocks", "barren", "mixed":
			return "dirt_tile"
		_:
			return ""


func _draw_zone_floors() -> void:
	for zone in terrain_zones:
		var tile_id := _zone_ground_tile(str(zone.kind))
		if tile_id.is_empty():
			continue
		var tile := SpriteLibrary.texture_for(tile_id)
		if tile == null:
			continue
		var half := Vector2(float(zone.rx), float(zone.ry))
		var world_rect := Rect2(zone.center - half, half * 2.0)
		# Soft transition wash: a few slightly-larger bands with decreasing alpha
		# outside the zone edge, so the seam into the base ground fades instead of
		# reading as a hard pixel line. World-space draw calls (like _draw_pad_shores).
		_draw_zone_soft_edges(world_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
		draw_texture_rect(
			tile,
			Rect2(world_rect.position / PIXEL_ZOOM, world_rect.size / PIXEL_ZOOM),
			true,
			_ground_tile_modulate()
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var wash := _ground_desat_wash()
		if wash.a > 0.0:
			draw_rect(world_rect, wash, true)
		# Cliff-edge border: the elevated zone reads as a raised rock terrace.
		_draw_zone_cliff_border(world_rect)


## Soft falloff band just outside each zone edge: 3 concentric, slightly larger
## rects with decreasing alpha in a darkened base-ground tone, so the zone tile
## blends into the surrounding floor instead of meeting it at a hard seam.
func _draw_zone_soft_edges(world_rect: Rect2) -> void:
	var base := _void_color().lightened(0.18)
	for band in 3:
		var grow := 4.0 + float(band) * 4.0
		var alpha := 0.05 + float(band) * 0.05
		draw_rect(world_rect.grow(-grow), Color(base, alpha), true)


## Rocky cliff-edge border around a zone, matching the dirt/dirt-rock palette
## (4a3a28 / 5c4a32 / 6b5a40 from SpriteArt's dirt_tile). Two nested rings of
## decreasing width read as rock strata: a thick dark base ring and a thinner
## lighter inner ring for a raised-terrace look.
func _draw_zone_cliff_border(world_rect: Rect2) -> void:
	var dark := Color("4a3a28")
	var mid := Color("5c4a32")
	var light := Color("6b5a40")
	# Outer rock ring: ~14px of strata around the whole perimeter.
	draw_rect(world_rect.grow(6.0), dark, false, 14.0)
	# Inner lip: lighter ring on the inside edge for the "top of the cliff".
	draw_rect(world_rect.grow(-8.0), mid, false, 6.0)
	draw_rect(world_rect.grow(-14.0), light, false, 3.0)


func _draw_decals() -> void:
	# Baked ground cover paints in one pass. Even though there are no per-frame
	# nodes, we still cull the draw calls to the camera view so a dense meadow
	# doesn't rasterise 2,000+ textures every frame.
	if baked_props.is_empty():
		return
	var drawn := 0
	var cull := _baked_cull_rect()
	for prop in baked_props:
		var pos: Vector2 = prop.pos
		if not cull.has_point(pos):
			continue
		_draw_one_decal(str(prop.sprite), pos)
		drawn += 1
	if drawn == 0 and baked_props.size() > 0:
		print("[draw_decals] has ", baked_props.size(), " props but cull rect is empty. cull=", cull)


## Camera-view rect (world space) with a small margin, used to skip draw calls for
## baked props that are off-screen. Reuses the same camera resolution as obstacle culling.
func _baked_cull_rect() -> Rect2:
	var cam := _cull_camera()
	if cam == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	var cam_pos: Vector2 = cam.get_global_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var zoom: Vector2 = cam.zoom
	var margin := 200.0
	var half_w := (vp.x * 0.5 / maxf(0.1, zoom.x)) + margin
	var half_h := (vp.y * 0.5 / maxf(0.1, zoom.y)) + margin
	return Rect2(cam_pos.x - half_w, cam_pos.y - half_h, half_w * 2.0, half_h * 2.0)


func _draw_one_decal(sprite_name: String, spot: Vector2) -> void:
	var texture := SpriteLibrary.texture_for(sprite_name)
	if texture == null:
		return
	if crater_feature_active() and crater_contains(spot, 8.0):
		return
	if not walk_pads.is_empty() and not _is_walkable(spot, 6.0):
		return
	var zoom := Obstacle.display_zoom(sprite_name, PIXEL_ZOOM, texture)
	var size := Vector2(texture.get_width(), texture.get_height()) * zoom
	draw_texture_rect(texture, Rect2(spot - size * 0.5, size), false)


## Lava pools paint on top of the ground but under rocks/heroes: round basins tiled with
## the biome void texture, plus a hot rim so they still read as lava bowls.
func _draw_hazards() -> void:
	if hazard_zones.is_empty():
		return
	var rim := Color("6a4a38")
	var slag_rim := Color("4a5058")
	for zone in hazard_zones:
		var kind := str(zone.get("biome_kind", "lava"))
		var edge := slag_rim if kind == "factory_slag" else rim
		var tile := _hazard_tile(kind)
		var shape := str(zone.get("shape", "rect"))
		match shape:
			"circle":
				_draw_lava_disc(zone.get("center", Vector2.ZERO), float(zone.get("radius", 0.0)), tile, edge)
			"ring":
				_draw_lava_ring(
					zone.get("center", Vector2.ZERO),
					float(zone.get("inner_radius", 0.0)),
					float(zone.get("radius", 0.0)),
					tile,
					edge
				)
			_:
				var rect: Rect2 = zone.get("rect", Rect2())
				if rect.size.x <= 0.0 or rect.size.y <= 0.0:
					continue
				_draw_lava_rect(rect, tile, edge)


## T3.6: when the volcano lava has cooled to a black/solid state, paint a dark
## overlay over the lava zones so they read as harmless solidified rock.
func _draw_cooled_lava_overlay() -> void:
	if not _lava_cooled or GameRuntime.biome_id != 1:
		return
	var dark := Color(0.18, 0.16, 0.15, 0.78)
	for zone in hazard_zones:
		var kind := str(zone.get("biome_kind", "lava"))
		if kind != "volcano_lava" and kind != "lava":
			continue
		var shape := str(zone.get("shape", "rect"))
		match shape:
			"circle":
				var c := Vector2(zone.get("center", Vector2.ZERO))
				var rad := float(zone.get("radius", 0.0))
				draw_circle(c, rad, dark)
			"ring":
				var c := Vector2(zone.get("center", Vector2.ZERO))
				var inner := float(zone.get("inner_radius", 0.0))
				var outer := float(zone.get("radius", 0.0))
				draw_circle(c, outer, dark)
				draw_circle(c, inner, Color(0, 0, 0, 0))
			_:
				var rect: Rect2 = zone.get("rect", Rect2())
				if rect.size.x > 0.0 and rect.size.y > 0.0:
					draw_rect(rect, dark, true)
	# A subtle "the lava cooled" label near the center for legibility.
	if not hazard_zones.is_empty():
		var zone0: Dictionary = hazard_zones[0]
		var shape0 := str(zone0.get("shape", "rect"))
		var center0: Vector2 = Vector2.ZERO
		if shape0 == "circle":
			center0 = zone0.get("center", Vector2.ZERO)
		elif shape0 == "ring":
			center0 = zone0.get("center", Vector2.ZERO)
		else:
			var rect0: Rect2 = zone0.get("rect", Rect2())
			if rect0.size.x > 0.0 and rect0.size.y > 0.0:
				center0 = rect0.position
		draw_string(ThemeDB.fallback_font, center0 + Vector2(0, -30), "the lava cools...", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.85, 0.85, 0.9, 0.85))


## T3.7: factory electro ground — a crackling electric patch that deals small
## damage ticks while active.
func _draw_electro_ground() -> void:
	if not _electro_active or GameRuntime.biome_id != 3:
		return
	var t := clampf(1.0 - _electro_remaining / ELECTRO_DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	var col := Color(0.55, 0.85, 1.0, 0.35 + 0.25 * pulse)
	draw_circle(_electro_origin, _electro_radius, col)
	draw_arc(_electro_origin, _electro_radius, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, 0.7), 2.0, true)
	# Crackling zigzag lines across the patch.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 100.0)
	for i in 6:
		var ang := rng.randf() * TAU
		var r0 := rng.randf_range(0.0, _electro_radius * 0.5)
		var r1 := rng.randf_range(_electro_radius * 0.5, _electro_radius)
		var p0 := _electro_origin + Vector2.from_angle(ang) * r0
		var p1 := _electro_origin + Vector2.from_angle(ang + rng.randf_range(-0.4, 0.4)) * r1
		draw_line(p0, p1, Color(0.85, 0.95, 1.0, 0.6 + 0.3 * pulse), 1.5)
	# Label.
	draw_string(ThemeDB.fallback_font, _electro_origin + Vector2(0, -_electro_radius - 8), "electrified!", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.7, 0.9, 1.0, 0.9))


func _hazard_tile(biome_kind: String) -> Texture2D:
	if biome_kind == "factory_slag":
		var slag := SpriteLibrary.texture_for("tw_factory_void_tile")
		if slag != null:
			return slag
	var lava := SpriteLibrary.texture_for("tw_volcano_void_tile")
	if lava != null:
		return lava
	return SpriteLibrary.texture_for("void_tile")


## At night the CanvasModulate darkens the whole scene with WorldClock.ambient
## (a dark blue ~0.38-0.58). This overlay counteracts that darkening on the
## lava/fire zones so they stay bright red and visibly glow at night — the
## "lava should stay the same brightness" requirement.
func _draw_night_glow_overlays() -> void:
	if not WorldClock.is_night:
		return
	# Compensation factor: divide by ambient to restore day brightness.
	# GLOW_BOOST pushes it slightly above day so the zone reads as glowing.
	var ambient := WorldClock.ambient
	var boost := 1.25
	var r := minf(boost / maxf(0.01, ambient.r), 3.0)
	var g := minf(boost / maxf(0.01, ambient.g), 3.0)
	var b := minf(boost / maxf(0.01, ambient.b), 3.0)

	# Lava zones: warm orange-red glow.
	var lava_glow := Color(minf(r, 3.0), minf(g * 0.6, 3.0), minf(b * 0.3, 3.0), 0.35)
	# Factory slag/powerlines: keep the colored lines glowing.
	var factory_glow := Color(minf(r, 3.0), minf(g * 0.8, 3.0), minf(b * 0.5, 3.0), 0.25)

	for zone in hazard_zones:
		var kind := str(zone.get("biome_kind", "lava"))
		var shape := str(zone.get("shape", "rect"))
		var glow := factory_glow if kind == "factory_slag" else lava_glow
		match shape:
			"circle":
				var c := Vector2(zone.get("center", Vector2.ZERO))
				var rad := float(zone.get("radius", 0.0))
				# Soft radial glow: concentric circles with decreasing alpha.
				for band in 4:
					var grow := rad * 0.15 * (band + 1)
					var alpha := 0.22 - band * 0.05
					draw_circle(c, rad + grow, Color(glow.r, glow.g, glow.b, maxf(0.0, alpha)))
			"ring":
				var c := Vector2(zone.get("center", Vector2.ZERO))
				var inner := float(zone.get("inner_radius", 0.0))
				var outer := float(zone.get("radius", 0.0))
				for band in 3:
					var grow := outer * 0.12 * (band + 1)
					var alpha := 0.18 - band * 0.05
					draw_arc(c, outer + grow, 0.0, TAU, 64, Color(glow.r, glow.g, glow.b, maxf(0.0, alpha)), 2.0)
			_:
				var rect: Rect2 = zone.get("rect", Rect2())
				if rect.size.x <= 0.0 or rect.size.y <= 0.0:
					continue
				for band in 3:
					var grow := 8.0 + band * 8.0
					var alpha := 0.20 - band * 0.06
					draw_rect(rect.grow(grow), Color(glow.r, glow.g, glow.b, maxf(0.0, alpha)), true)


func _draw_lava_rect(rect: Rect2, tile: Texture2D, rim: Color) -> void:
	if tile != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
		draw_texture_rect(tile, Rect2(rect.position / PIXEL_ZOOM, rect.size / PIXEL_ZOOM), true, _void_tile_tint())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_rect(rect, Color("4a2a22"), true)
	draw_rect(rect, rim, false, 6.0)


func _draw_lava_disc(center: Vector2, radius: float, tile: Texture2D, rim: Color) -> void:
	if radius < 8.0:
		return
	_fill_lava_tiles(center, 0.0, radius, tile)
	var facets := 12
	for index in facets:
		var a0 := TAU * float(index) / float(facets) + PI / float(facets)
		var a1 := TAU * float(index + 1) / float(facets) + PI / float(facets)
		draw_line(center + Vector2.from_angle(a0) * radius, center + Vector2.from_angle(a1) * radius, rim, 6.0)


func _draw_lava_ring(center: Vector2, inner: float, outer: float, tile: Texture2D, rim: Color) -> void:
	if outer <= inner + 4.0:
		return
	_fill_lava_tiles(center, inner, outer, tile)
	draw_arc(center, outer, 0.0, TAU, 24, rim, 7.0, false)
	draw_arc(center, inner, 0.0, TAU, 20, rim.darkened(0.15), 5.0, false)


func _fill_lava_tiles(center: Vector2, inner: float, outer: float, tile: Texture2D) -> void:
	if tile == null:
		if inner <= 1.0:
			draw_colored_polygon(_regular_polygon(center, outer, 12), Color("4a2a22"))
		else:
			draw_arc(center, (inner + outer) * 0.5, 0.0, TAU, 28, Color("4a2a22"), outer - inner, false)
		return
	var cell := Vector2(float(tile.get_width()), float(tile.get_height())) * PIXEL_ZOOM
	if cell.x < 4.0 or cell.y < 4.0:
		return
	# Same slow current as _draw_void_rect (see _update_water_drift), just shifting the
	# whole tile grid's placement instead of the sampled UV since this path draws each
	# cell as a separate untiled draw call — visually equivalent drift for a repeating tile.
	var start := center - Vector2(outer, outer) + _water_drift_offset * PIXEL_ZOOM
	var x := start.x
	while x < center.x + outer:
		var y := start.y
		while y < center.y + outer:
			var mid := Vector2(x, y) + cell * 0.5
			var dist := mid.distance_to(center)
			if dist <= outer and dist >= inner:
				draw_texture_rect(tile, Rect2(Vector2(x, y), cell), false, _void_tile_tint())
			y += cell.y
		x += cell.x
	var wash := Color(0.32, 0.22, 0.18, 0.12) if GameRuntime.biome_id == 1 else Color(0.16, 0.16, 0.18, 0.14)
	if inner <= 1.0:
		draw_colored_polygon(_regular_polygon(center, outer, 12), wash)
	else:
		draw_arc(center, (inner + outer) * 0.5, 0.0, TAU, 28, wash, outer - inner, false)


func _regular_polygon(center: Vector2, radius: float, facets: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := maxi(3, facets)
	for index in count:
		pts.append(center + Vector2.from_angle(TAU * float(index) / float(count) + PI / float(count)) * radius)
	return pts


## Themed centerpiece crater. Grass: walkable earth bowl. Volcano: lava lip around a
## scorched inner plug (the lava fill itself is painted by _draw_hazards).
func _draw_crater() -> void:
	if not crater_feature_active():
		return
	# Gated on crater_unlocked so the opening crash-landing cinematic can build the
	# arena with the crater hidden, then reveal it on the ship's impact.
	if not crater_unlocked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 7
	var bowl := crater_rect()
	var radius := CRATER_SIZE.x * 0.5
	if GameRuntime.biome_id == 1:
		_draw_volcano_crater(bowl, rng, radius)
	else:
		_draw_grass_crater(bowl, rng, radius)


func _draw_grass_crater(_bowl: Rect2, rng: RandomNumberGenerator, radius: float) -> void:
	# Raised turf shadow, then the sunken round earth bowl (faceted, not a square).
	draw_arc(Vector2.ZERO, radius + 48.0, 0.0, TAU, 24, Color(0, 0, 0, 0.20), 36.0, false)
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, radius + 18.0, 16), Color("4a3824"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, radius, 16), Color("5c5044"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, maxf(48.0, radius - 72.0), 12), Color("3a2c1b"))
	var facets := 16
	var core := Color("3a2c1b")
	for index in facets:
		var a0 := TAU * float(index) / float(facets)
		var a1 := a0 + TAU / float(facets) * 1.08
		var r0 := (radius - 40.0) * rng.randf_range(0.88, 1.04)
		var shade := core
		if index % 3 == 0:
			shade = core.lightened(0.12)
		elif index % 3 == 1:
			shade = core.darkened(0.08)
		draw_colored_polygon(PackedVector2Array([
			Vector2.from_angle(a0) * r0,
			Vector2.from_angle(a1) * r0,
			Vector2.from_angle(a0 * 0.5 + a1 * 0.5) * r0 * 0.32,
		]), shade)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color("7a5630"), 8.0, false)
	var crack := Color(0, 0, 0, 0.32)
	for index in 8:
		var angle := TAU * float(index) / 8.0 + rng.randf_range(-0.18, 0.18)
		var start := Vector2.from_angle(angle) * radius * 0.18
		var finish := Vector2.from_angle(angle + rng.randf_range(-0.12, 0.12)) * radius * rng.randf_range(0.72, 0.94)
		draw_line(start, finish, crack, 5.0, true)
	_draw_crater_debris(rng, radius, ["tw_crater_shard", "tw_crater_stone", "rock_large"], true)


func _draw_volcano_crater(_bowl: Rect2, rng: RandomNumberGenerator, radius: float) -> void:
	# Walkable scorched bowl — no lava donut. Orange rim is paint only; lava is the void.
	draw_arc(Vector2.ZERO, radius + 40.0, 0.0, TAU, 24, Color(0.16, 0.05, 0.02, 0.45), 28.0, false)
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, radius + 16.0, 16), Color("5a2210"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, radius, 16), Color("6a2e14"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, maxf(48.0, radius - 80.0), 12), Color("4a1c0c"))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color("6a4030"), 7.0, false)


func _draw_crater_debris(rng: RandomNumberGenerator, radius: float, sprites: Array, grow_grass: bool) -> void:
	for index in 14:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(radius * 0.72, radius + 36.0)
		var spot := Vector2.from_angle(angle) * dist
		var sprite_name := str(sprites[index % sprites.size()])
		var texture := SpriteLibrary.texture_for(sprite_name)
		if texture == null:
			texture = SpriteLibrary.texture_for("rock_small")
		if texture == null:
			continue
		var size := Vector2(texture.get_width(), texture.get_height()) * PIXEL_ZOOM * rng.randf_range(0.5, 0.85)
		size.y *= 0.62
		draw_texture_rect(texture, Rect2(spot - size * 0.5, size), false)
	if not grow_grass:
		return
	for index in 10:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(radius * 0.82, radius + 70.0)
		var spot := Vector2.from_angle(angle) * dist
		var texture := SpriteLibrary.texture_for("grass_tuft")
		if texture == null:
			continue
		var size := Vector2(texture.get_width(), texture.get_height()) * PIXEL_ZOOM * rng.randf_range(0.7, 1.0)
		draw_texture_rect(texture, Rect2(spot - size * 0.5, size), false)


func _draw_classic_grid(rect: Rect2) -> void:
	draw_rect(rect, Color("111827"), true)
	var grid_color := Color(0.15, 0.20, 0.29, 0.7)
	var half := BASE_SIZE * 0.5
	for x in range(int(-half.x), int(half.x) + 1, 100):
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), grid_color, 1.0)
	for y in range(int(-half.y), int(half.y) + 1, 100):
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), grid_color, 1.0)
	draw_rect(rect, Color("4b6388"), false, 8.0)

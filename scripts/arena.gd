class_name Arena
extends Node2D

## Fired after `_spawn_landmarks` so main can rebind `triggered` when rebuild replaces instances.
signal landmarks_changed

## Terrain reward: some bosses leave a crater that unlocks fire-themed ability modifiers.
## Stubbed here so main.gd's unlock hook runs even before boss rewards are wired up.
var crater_unlocked: bool = false

func set_crater_unlocked(unlocked: bool) -> void:
	if crater_unlocked == unlocked:
		return
	crater_unlocked = unlocked
	if is_inside_tree():
		queue_redraw()

## Single active arena lives under main. Players / enemies resolve it through this so
## nobody needs to hard-wire the path (and so the offline smoke harness can find it).
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
		["tw_volcano_landmark_well", "battle_frenzy", 620.0, 0.75, 30.0, "Ember Fury"],
	],
	[
		["tw_ice_landmark_hollow", "heal_all", 480.0, 0.65, 76.0, "Frost Well"],
		["tw_ice_landmark_glade", "freeze_time", 560.0, 0.70, 11.0, "Frozen Crystal"],
		["tw_ice_landmark_glade", "speed_surge", 600.0, 0.70, 14.0, "Sprint Rune"],
		["tw_docks_landmark_lighthouse", "pulse_wipe", 1600.0, 0.75, 16.0, "Storm Spire"],
	],
	[
		["tw_factory_landmark_pylon", "pulse_wipe", 1600.0, 0.75, 18.0, "Molten Pylon"],
		["tw_factory_landmark_vat", "heal_all", 480.0, 0.65, 80.0, "Steam Vent"],
		["tw_factory_landmark_bay", "freeze_time", 560.0, 0.70, 10.0, "Quench Bay"],
		["tw_factory_landmark_bay", "speed_surge", 600.0, 0.70, 13.0, "Turbo Bay"],
	],
	[
		["tw_docks_landmark_lighthouse", "pulse_wipe", 1600.0, 0.75, 16.0, "Storm Lighthouse"],
		["tw_docks_landmark_pool", "heal_all", 480.0, 0.65, 76.0, "Tide Pool"],
		["tw_docks_landmark_bell", "freeze_time", 560.0, 0.70, 11.0, "Harbor Bell"],
		["tw_docks_boat", "speed_surge", 600.0, 0.70, 14.0, "Pilot Skiff"],
	],
]

## Live landmark instances the current world spawned. Emptied and rebuilt on set_world.
var landmarks: Array[ArenaLandmark] = []

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
## center bowl so creeps can be held on the rim while heroes fight inside.
func crater_feature_active() -> bool:
	if not GameRuntime.uses_biomes() or GameRuntime.is_classic():
		return false
	if GameRuntime.is_ffa():
		return true
	return GameRuntime.biome_id == 0 or GameRuntime.biome_id == 1


## FFA only: creeps may not cross this radius. Heroes still walk the bowl.
static func ffa_creep_rim_radius(body_radius: float = 20.0) -> float:
	return crater_radius() + body_radius + 14.0


static func ffa_blocks_creeps_from_crater() -> bool:
	return GameRuntime.is_ffa()


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

## Everything below is laid out from a fixed seed, so every peer in a session
## builds the exact same field without replicating a single byte.
const LAYOUT_SEED := 20260819
const OBSTACLE_COUNT := 220
const ISLAND_OBSTACLE_COUNT := 80
const DECAL_COUNT := 320
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


func _process(delta: float) -> void:
	_update_water_drift(delta)


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
	_fit_walls()
	if not GameRuntime.is_classic():
		# Hazards first so obstacles respect them (rocks shouldn't sit inside lava pools).
		_build_hazards()
		_build_field()
		_spawn_landmarks()
	queue_redraw()


func rebuild() -> void:
	for child in get_children():
		if child.name == "Walls":
			continue
		child.free()
	obstacles.clear()
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
	queue_redraw()


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
func hazard_at(world_position: Vector2) -> Dictionary:
	for zone in hazard_zones:
		if _zone_contains(zone, world_position, 0.0):
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
	landmarks_changed.emit()


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


## Drop rocks that would sit under a landmark pad so the shrine reads cleanly.
func _clear_pad_obstacles(spot: Vector2) -> void:
	var keep: Array[Obstacle] = []
	var clear_r := ArenaLandmark.STAND_RADIUS + 18.0
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		if obstacle.global_position.distance_to(spot) < clear_r + obstacle.body_radius:
			obstacle.queue_free()
		else:
			keep.append(obstacle)
	obstacles = keep


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
	_scatter_obstacles()
	_pack_pad_rocks()
	_plant_cover_rocks()
	var shop_stand := SHOP_STAND_SCENE.instantiate() as Node2D
	shop_stand.global_position = shop_stand_position()
	add_child(shop_stand)
	# Solid void for the water / lava / pit between pads so bodies can't leave the pads.
	_build_void_bodies()


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
	var wanted := mini(220, int(round(float(base_count) * maxf(1.0, area_scale))))
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
	if crater_feature_active() and crater_contains(candidate, 24.0):
		return false
	if walk_pads.is_empty():
		return true
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) < 72:
			continue
		if _pad_contains(pad, candidate, 28.0):
			return true
	return false


func _too_close_to_other_obstacle(candidate: Vector2) -> bool:
	for obstacle in obstacles:
		if candidate.distance_to(obstacle.global_position) < OBSTACLE_SPACING:
			return true
	return false


func _near_corner_spawn(candidate: Vector2, radius: float) -> bool:
	for slot in 4:
		if candidate.distance_to(corner_spawn(slot)) < radius:
			return true
	return false


func _add_obstacle(world_position: Vector2, type_data: Dictionary) -> void:
	var obstacle := OBSTACLE_SCENE.instantiate() as Obstacle
	obstacle.global_position = world_position
	add_child(obstacle)
	obstacle.configure(str(type_data.sprite), float(type_data.radius), PIXEL_ZOOM, float(type_data.lift))
	obstacles.append(obstacle)


func _rock_pads() -> Array[Rect2]:
	var usable: Array[Rect2] = []
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) >= 72:
			usable.append(pad)
	return usable


func _try_place_obstacle(candidate: Vector2, rng: RandomNumberGenerator) -> bool:
	if candidate.length() < SPAWN_CLEARANCE:
		return false
	if _near_corner_spawn(candidate, SPAWN_CLEARANCE * 0.72):
		return false
	if candidate.distance_to(shop_stand_position()) < SHOP_STAND_CLEARANCE:
		return false
	if not _fits_obstacle(candidate):
		return false
	if _too_close_to_other_obstacle(candidate):
		return false
	_add_obstacle(candidate, OBSTACLE_TYPES[rng.randi() % OBSTACLE_TYPES.size()])
	return true


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


## Heal pads get a flower ring (drawn in _draw_decals). Damage pads get extra rim rocks.
func _dress_landmark_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 44
	for landmark in landmarks:
		if not is_instance_valid(landmark):
			continue
		var effect := str(landmark.effect_id)
		if effect == "pulse_wipe" or effect == "battle_frenzy":
			for index in 7:
				var angle := TAU * float(index) / 7.0 + 0.21
				var dist := ArenaLandmark.STAND_RADIUS + rng.randf_range(36.0, 88.0)
				_try_place_obstacle(landmark.position + Vector2.from_angle(angle) * dist, rng)


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
	match GameRuntime.biome_id:
		1:
			return Color(1.08, 0.82, 0.68, 1.0)
		2:
			return Color(0.62, 0.84, 1.12, 1.0)
		4:
			return Color(0.62, 0.84, 1.12, 1.0)
		3:
			return Color(0.78, 0.82, 0.88, 1.0)
		_:
			return Color.WHITE


func _draw_void_wash(world_rect: Rect2) -> void:
	match GameRuntime.biome_id:
		1:
			draw_rect(world_rect, Color(1.0, 0.28, 0.06, 0.16), true)
		2:
			draw_rect(world_rect, Color(0.10, 0.32, 0.52, 0.22), true)
		3:
			draw_rect(world_rect, Color(0.04, 0.05, 0.08, 0.28), true)
		4:
			draw_rect(world_rect, Color(0.08, 0.28, 0.46, 0.22), true)


func _draw_pad_shores() -> void:
	var rim := Color.TRANSPARENT
	var width := 6.0
	match GameRuntime.biome_id:
		1:
			rim = Color("ff7a29")
			width = 8.0
		2:
			rim = Color("3a7aa0")
			width = 5.0
		3:
			rim = Color("1a1e28")
			width = 7.0
		4:
			rim = Color("1a5a80")
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
	if GameRuntime.uses_biomes() and GameRuntime.biome_id > 0:
		draw_rect(world_rect, Color(0.38, 0.36, 0.34, 0.22), true)


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
	if not GameRuntime.uses_biomes() or GameRuntime.biome_id <= 0:
		return Color.WHITE
	return Color(0.76, 0.74, 0.72, 1.0)


func _draw_decals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 1
	var limit := playfield_size() * 0.5 - Vector2(60.0, 60.0)
	var meadow := walk_pads.is_empty()
	var patch_sprites: Array[String] = DECAL_SPRITES.duplicate()
	if not meadow:
		match GameRuntime.biome_id:
			1:
				patch_sprites = ["rock_small", "grass_tuft", "rock_small"]
			2:
				patch_sprites = ["grass_bloom", "grass_tuft", "rock_small"]
			3:
				patch_sprites = ["rock_small", "rock_large", "grass_tuft"]
			4:
				patch_sprites = ["grass_tuft", "rock_small", "grass_flower"]
	# Organic clusters instead of a uniform sprinkle.
	var patches := 16 if meadow else 10
	for _patch in patches:
		var center := Vector2(rng.randf_range(-limit.x, limit.x), rng.randf_range(-limit.y, limit.y))
		if not meadow and not _is_walkable(center, 8.0):
			continue
		var kind := patch_sprites[rng.randi() % patch_sprites.size()]
		for _blade in rng.randi_range(7, 16):
			var spot := center + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-70.0, 70.0))
			_draw_one_decal(kind, spot)
	# Landmark dressing: flowers on heal, extra rock scatter on damage pads.
	for landmark in landmarks:
		if not is_instance_valid(landmark):
			continue
		var effect := str(landmark.effect_id)
		var extra_kind := "grass_flower"
		var extra_count := 4
		if effect == "heal_all":
			extra_kind = "grass_bloom" if rng.randf() < 0.45 else "grass_flower"
			extra_count = 18
		elif effect == "pulse_wipe" or effect == "battle_frenzy":
			extra_kind = "rock_small"
			extra_count = 8
		elif effect == "freeze_time":
			extra_kind = "grass_bloom"
			extra_count = 8
		else:
			extra_kind = "grass_tuft"
			extra_count = 6
		for _i in extra_count:
			var ring := rng.randf_range(28.0, ArenaLandmark.STAND_RADIUS + 24.0)
			var spot := landmark.position + Vector2.from_angle(rng.randf() * TAU) * ring
			_draw_one_decal(extra_kind, spot)


func _draw_one_decal(sprite_name: String, spot: Vector2) -> void:
	var texture := SpriteLibrary.texture_for(sprite_name)
	if texture == null:
		return
	if crater_feature_active() and crater_contains(spot, 8.0):
		return
	if not walk_pads.is_empty() and not _is_walkable(spot, 6.0):
		return
	var size := Vector2(texture.get_width(), texture.get_height()) * PIXEL_ZOOM
	draw_texture_rect(texture, Rect2(spot - size * 0.5, size), false)


## Lava pools paint on top of the ground but under rocks/heroes: round basins tiled with
## the biome void texture, plus a hot rim so they still read as lava bowls.
func _draw_hazards() -> void:
	if hazard_zones.is_empty():
		return
	var rim := Color("ff7a29")
	var slag_rim := Color("e07020")
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


func _hazard_tile(biome_kind: String) -> Texture2D:
	if biome_kind == "factory_slag":
		var slag := SpriteLibrary.texture_for("tw_factory_void_tile")
		if slag != null:
			return slag
	var lava := SpriteLibrary.texture_for("tw_volcano_void_tile")
	if lava != null:
		return lava
	return SpriteLibrary.texture_for("void_tile")


func _draw_lava_rect(rect: Rect2, tile: Texture2D, rim: Color) -> void:
	if tile != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
		draw_texture_rect(tile, Rect2(rect.position / PIXEL_ZOOM, rect.size / PIXEL_ZOOM), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_rect(rect, Color("c43018"), true)
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
			draw_colored_polygon(_regular_polygon(center, outer, 12), Color("c43018"))
		else:
			draw_arc(center, (inner + outer) * 0.5, 0.0, TAU, 28, Color("c43018"), outer - inner, false)
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
				draw_texture_rect(tile, Rect2(Vector2(x, y), cell), false)
			y += cell.y
		x += cell.x
	# Heat wash so the tiled rock still reads as molten.
	if inner <= 1.0:
		draw_colored_polygon(_regular_polygon(center, outer, 12), Color(1.0, 0.32, 0.08, 0.22))
	else:
		draw_arc(center, (inner + outer) * 0.5, 0.0, TAU, 28, Color(1.0, 0.32, 0.08, 0.22), outer - inner, false)


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
	if GameRuntime.biome_id == 0 and not crater_unlocked:
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
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color("ff7a29"), 7.0, false)
	_draw_crater_debris(rng, radius, ["rock_small", "rock_large", "boulder"], false)


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

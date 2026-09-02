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
## Three roles every map: wipe (effect_arg = boss HP %), heal (HP), freeze (seconds).
## Angles 20/140/260 and dist_frac ~0.68–0.76 fan them across the field.
const WORLD_LANDMARKS: Array[Array] = [
	# Iron Foundry — slag pulse chunks elites, steam heals, quench freeze + mark.
	[
		["tw_factory_landmark_pylon", "pulse_wipe", 1600.0, 0.75, 22.0, "Molten Pylon", 20.0, 0.70],
		["tw_factory_landmark_vat", "heal_all", 480.0, 0.65, 80.0, "Steam Vent", 140.0, 0.76],
		["tw_factory_landmark_bay", "freeze_time", 560.0, 0.70, 10.0, "Quench Bay", 260.0, 0.72],
	],
	# Ashen Caldera — rift wipe, ember heal, long obsidian freeze.
	[
		["tw_volcano_landmark_arch", "pulse_wipe", 1600.0, 0.75, 20.0, "Rift Portal", 20.0, 0.70],
		["tw_volcano_landmark_shrine", "heal_all", 500.0, 0.65, 88.0, "Ember Shrine", 140.0, 0.76],
		["tw_volcano_landmark_well", "freeze_time", 580.0, 0.70, 12.0, "Obsidian Font", 260.0, 0.72],
	],
	# Verdant Wilds — grove wipe hits packs hard, spring heal, root freeze.
	[
		["tw_grass_landmark_bell", "pulse_wipe", 1600.0, 0.75, 22.0, "Grove Bell", 20.0, 0.70],
		["tw_grass_landmark_pool", "heal_all", 480.0, 0.65, 76.0, "Wild Spring", 140.0, 0.76],
		["tw_grass_landmark_stone", "freeze_time", 540.0, 0.70, 10.0, "Root Stone", 260.0, 0.72],
	],
	# Storm Court — storm pulse, frost-well heal, crystal freeze.
	[
		["tw_docks_landmark_lighthouse", "pulse_wipe", 1600.0, 0.75, 20.0, "Storm Lighthouse", 20.0, 0.70],
		["tw_ice_landmark_hollow", "heal_all", 480.0, 0.65, 76.0, "Frost Well", 140.0, 0.76],
		["tw_ice_landmark_glade", "freeze_time", 560.0, 0.70, 11.0, "Frozen Crystal", 260.0, 0.72],
	],
]

## Live landmark instances the current world spawned. Emptied and rebuilt on set_world.
var landmarks: Array[ArenaLandmark] = []

var _world_id: int = World.IRON_FOUNDRY


func world() -> int:
	return _world_id


## Dress the arena as the given PlayerClass.World. Locks GameRuntime to the matching biome
## so pad layouts, void colors and tile art all agree, then rebuilds obstacles + landmarks.
## Safe to call before the field is built (deferred via call_deferred when inside tree).
func set_world(world_id: int) -> void:
	var index := clampi(world_id, 0, WORLD_TO_BIOME.size() - 1)
	if index == _world_id and not landmarks.is_empty():
		return
	_world_id = index
	var target_biome: int = WORLD_TO_BIOME[index]
	if GameRuntime.uses_biomes() and GameRuntime.biome_id != target_biome:
		# Lock so wave progression doesn't slide the arena out from under the hero's world.
		GameRuntime.set_biome(target_biome, true)
	if is_inside_tree():
		rebuild()


const BASE_SIZE := Vector2(2400.0, 1600.0)
## Per-biome playfield footprints (indexed by GameRuntime.biome_id). Authored pad /
## hazard / shop coordinates live in BASE_SIZE space and scale up with the field, so
## classic stays the original 2400×1600 grid while biome worlds restore the larger
## footprints (roughly 1.8–2× the flattened sizes). Grass stays the smallest.
##   0 grass meadow — open field, walkable boss-bowl crater in the center.
##   1 volcano      — caldera: island pads over lava, lava crater bowl in the center.
##   2 ice          — wide floe field, long sightlines between ice floes.
##   3 factory      — boxy halls; taller than grass so the corridors have room.
##   4 docks        — widest: boardwalk and piers over water.
const SIZE_BY_BIOME: Array[Vector2] = [
	Vector2(4200.0, 2800.0),
	Vector2(4800.0, 3400.0),
	Vector2(5200.0, 3400.0),
	Vector2(4600.0, 3600.0),
	Vector2(5600.0, 3600.0),
]
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


## Grass meadow and volcano caldera own the centerpiece crater; other biomes do not.
func crater_feature_active() -> bool:
	if not GameRuntime.uses_biomes() or GameRuntime.is_classic():
		return false
	return GameRuntime.biome_id == 0 or GameRuntime.biome_id == 1


static func playfield_size() -> Vector2:
	if GameRuntime.is_classic() or not GameRuntime.uses_biomes():
		return BASE_SIZE
	var index := clampi(GameRuntime.biome_id, 0, SIZE_BY_BIOME.size() - 1)
	return SIZE_BY_BIOME[index]

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
const OBSTACLE_COUNT := 30
const ISLAND_OBSTACLE_COUNT := 14
const DECAL_COUNT := 320
const WALL_MARGIN := 140.0
const SPAWN_CLEARANCE := 320.0
const OBSTACLE_SPACING := 165.0

var obstacles: Array[Obstacle] = []
## Walkable pads for Pjotr biomes. Empty means the whole playfield is walkable
## (Pjotr grass meadow). Classic keeps the clean grid.
var walk_pads: Array[Rect2] = []
## Terrain hazards (lava pools, etc.) carved from the playfield independent of pads.
## Each entry: shape (rect/circle/ring) + type/dots. Circle/ring also store center + radius.
var hazard_zones: Array[Dictionary] = []
## Worlds that get lava hazards (PlayerClass.World: 0=IRON_FOUNDRY, 1=ASHEN_CALDERA).
## Foundry pools read as molten-slag basins; Caldera pools are straight lava.
const HAZARD_WORLDS: Array[int] = [0, 1]
## Authored circular pools per world (base-size coords). Three basins sit at compass
## points so they read as a layout, not a random scatter, and stay off the crater + shop.
const WORLD_HAZARD_POOLS: Array[Array] = [
	# Iron Foundry — slag troughs flanking the foundry floor.
	[
		{"center": Vector2(-620.0, -280.0), "radius": 118.0},
		{"center": Vector2(680.0, 140.0), "radius": 108.0},
		{"center": Vector2(-80.0, 640.0), "radius": 96.0},
	],
	# Ashen Caldera — satellite lava bowls around the round crater (the lip is extra).
	[
		{"center": Vector2(-780.0, 120.0), "radius": 112.0},
		{"center": Vector2(720.0, -360.0), "radius": 100.0},
		{"center": Vector2(220.0, 700.0), "radius": 92.0},
	],
]
## Tune the lava dunk numbers (player tick vs enemy tick vs burst on knockback-land).
const HAZARD_PLAYER_DOT := 14.0
const HAZARD_ENEMY_DOT := 16.0
const HAZARD_DUNK_BURST := 60.0
const HAZARD_DUNK_SCRAMBLE := 2.5
const HAZARD_HOVER_REDUCTION := 0.5


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
## Volcano also carves a round caldera lip (lava ring around a walkable plug).
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
	if GameRuntime.biome_id == 1:
		_append_crater_lava()


func _append_lava_zone(rect: Rect2, biome_kind: String) -> void:
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	hazard_zones.append({
		"shape": "rect",
		"rect": rect,
		"type": "lava",
		"biome_kind": biome_kind,
		"player_dot": HAZARD_PLAYER_DOT,
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
	if _world_id < 0 or _world_id >= WORLD_LANDMARKS.size():
		landmarks_changed.emit()
		return
	var kit: Array = WORLD_LANDMARKS[_world_id]
	var placed: Array[Vector2] = []
	for spec in kit:
		if spec.size() < 6:
			continue
		var angle_deg := float(spec[6]) if spec.size() > 6 else 0.0
		var dist_frac := float(spec[7]) if spec.size() > 7 else 0.72
		var landmark := ArenaLandmark.new()
		landmark.position = _landmark_spot(angle_deg, dist_frac, placed)
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
		if pad.grow(-radius).has_point(world_position):
			return true
	return false


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
		return walk_pads[0].get_center()
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
		var inner := pad.grow(-SHOP_STAND_CLEARANCE)
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
	var area_scale := (playfield_size().x * playfield_size().y) / (BASE_SIZE.x * BASE_SIZE.y)
	var wanted := int(round(float(ISLAND_OBSTACLE_COUNT if not walk_pads.is_empty() else OBSTACLE_COUNT) * area_scale))
	var attempts := 0
	while obstacles.size() < wanted and attempts < wanted * 50:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(-limit.x, limit.x),
			rng.randf_range(-limit.y, limit.y)
		)
		if candidate.length() < SPAWN_CLEARANCE:
			continue
		if candidate.distance_to(shop_stand_position()) < SHOP_STAND_CLEARANCE:
			continue
		if not _fits_obstacle(candidate):
			continue
		if _too_close_to_other_obstacle(candidate):
			continue
		_add_obstacle(candidate, OBSTACLE_TYPES[rng.randi() % OBSTACLE_TYPES.size()])


func _fits_obstacle(candidate: Vector2) -> bool:
	# Rocks don't sit mid-pool — a boulder in lava looks wrong and would block dunk shots.
	if is_in_hazard(candidate, 48.0):
		return false
	if crater_feature_active() and crater_contains(candidate, 24.0):
		return false
	if walk_pads.is_empty():
		return true
	for pad in walk_pads:
		if mini(int(pad.size.x), int(pad.size.y)) < 160:
			continue
		if pad.grow(-48.0).has_point(candidate):
			return true
	return false


func _too_close_to_other_obstacle(candidate: Vector2) -> bool:
	for obstacle in obstacles:
		if candidate.distance_to(obstacle.global_position) < OBSTACLE_SPACING:
			return true
	return false


func _add_obstacle(world_position: Vector2, type_data: Dictionary) -> void:
	var obstacle := OBSTACLE_SCENE.instantiate() as Obstacle
	obstacle.global_position = world_position
	add_child(obstacle)
	obstacle.configure(str(type_data.sprite), float(type_data.radius), PIXEL_ZOOM, float(type_data.lift))
	obstacles.append(obstacle)


func _pads_for_biome(biome: int) -> Array[Rect2]:
	var pads: Array[Rect2] = []
	match biome:
		1:
			# Volcano: spawn island (holds the 600×600 caldera bowl after scale), shop
			# island, and outcrops linked by bridges over lava. Authored in BASE_SIZE
			# space; _scale_pads grows them with the 4800×3400 playfield.
			pads.append_array([
				Rect2(-340, -280, 680, 560),
				Rect2(400, -420, 420, 300),
				Rect2(280, -300, 160, 100),
				Rect2(-200, -760, 400, 300),
				Rect2(-50, -500, 100, 240),
				Rect2(-200, 400, 400, 300),
				Rect2(-50, 240, 100, 180),
				Rect2(-1100, -220, 440, 440),
				Rect2(-680, -60, 360, 120),
			])
		2:
			# Ice: floes with thin ice between them. Gaps are water.
			pads.append_array([
				Rect2(-300, -220, 600, 440),
				Rect2(380, -400, 400, 280),
				Rect2(260, -280, 140, 90),
				Rect2(-1080, -740, 520, 340),
				Rect2(-800, -420, 120, 220),
				Rect2(480, 280, 520, 400),
				Rect2(200, 140, 320, 100),
				Rect2(-1000, 240, 480, 440),
				Rect2(-540, 80, 280, 100),
			])
		3:
			# Factory: orthogonal halls. The pits between corridors are unwalkable.
			pads.append_array([
				Rect2(-1100, -140, 2200, 280),
				Rect2(-140, -740, 280, 1480),
				Rect2(140, -360, 560, 220),
				Rect2(780, -740, 240, 1480),
				Rect2(-1020, -740, 240, 1480),
				Rect2(-1100, 420, 2200, 220),
			])
		4:
			# Docks: boardwalk plus piers over water.
			pads.append_array([
				Rect2(-1100, -160, 2200, 320),
				Rect2(420, -420, 320, 280),
				Rect2(-80, -760, 160, 620),
				Rect2(-720, 140, 160, 600),
				Rect2(80, 140, 160, 600),
				Rect2(720, 140, 160, 600),
				Rect2(-1100, -500, 280, 1000),
			])
		_:
			pass
	return _scale_pads(pads)


func _scale_pads(pads: Array[Rect2]) -> Array[Rect2]:
	var factor := playfield_size() / BASE_SIZE
	if factor.is_equal_approx(Vector2.ONE):
		return pads
	var scaled: Array[Rect2] = []
	for pad in pads:
		scaled.append(Rect2(pad.position * factor, pad.size * factor))
	return scaled


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
	if walk_pads.is_empty():
		return
	var voids: Array[Rect2] = []
	voids.append(_arena_rect())
	for pad in walk_pads:
		var next_voids: Array[Rect2] = []
		for piece in voids:
			next_voids.append_array(_subtract_rect(piece, pad))
		voids = next_voids
	var body := StaticBody2D.new()
	body.name = "Voids"
	body.collision_layer = 1
	body.collision_mask = 6
	for piece in voids:
		if piece.size.x < 12.0 or piece.size.y < 12.0:
			continue
		var shape_node := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = piece.size
		shape_node.shape = rect_shape
		shape_node.position = piece.get_center()
		body.add_child(shape_node)
	add_child(body)


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

	_draw_ground_rect(rect)
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


func _draw_void_rect(world_rect: Rect2) -> void:
	var lava := SpriteLibrary.texture_for("void_tile")
	if lava == null:
		draw_rect(world_rect, _void_color(), true)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
	draw_texture_rect(
		lava,
		Rect2(world_rect.position / PIXEL_ZOOM, world_rect.size / PIXEL_ZOOM),
		true
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		true
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _draw_decals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _layout_seed() + 1
	var limit := playfield_size() * 0.5 - Vector2(60.0, 60.0)
	var count := int(round(float(DECAL_COUNT) * (playfield_size().x * playfield_size().y) / (BASE_SIZE.x * BASE_SIZE.y)))
	for _index in count:
		var spot := Vector2(rng.randf_range(-limit.x, limit.x), rng.randf_range(-limit.y, limit.y))
		var sprite_name := DECAL_SPRITES[rng.randi() % DECAL_SPRITES.size()]
		var texture := SpriteLibrary.texture_for(sprite_name)
		if texture == null or is_blocked(spot, 30.0):
			continue
		if crater_feature_active() and crater_contains(spot, 8.0):
			continue
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
	var start := center - Vector2(outer, outer)
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
	# Round ash lip around the caldera lake. Inner plug stays scorched rock so spawn is
	# safe; the lava ring is a hazard zone drawn later by _draw_hazards.
	var inner_r := crater_inner_radius()
	draw_arc(Vector2.ZERO, radius + 40.0, 0.0, TAU, 24, Color(0.16, 0.05, 0.02, 0.55), 32.0, false)
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, radius + 16.0, 16), Color("5a2210"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, radius, 16), Color("3a1408"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, inner_r, 14), Color("6a2e14"))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, maxf(40.0, inner_r - 28.0), 12), Color("4a1c0c"))
	draw_arc(Vector2.ZERO, inner_r, 0.0, TAU, 16, Color("c45a28"), 5.0, false)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 18, Color("ff7a29"), 8.0, false)
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

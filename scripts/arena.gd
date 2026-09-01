class_name Arena
extends Node2D

## Terrain reward: some bosses leave a crater that unlocks fire-themed ability modifiers.
## Stubbed here so main.gd's unlock hook runs even before boss rewards are wired up.
var crater_unlocked: bool = false

func set_crater_unlocked(unlocked: bool) -> void:
	crater_unlocked = unlocked


const BASE_SIZE := Vector2(2400.0, 1600.0)
## Each later biome is a bigger field: grass < volcano < ice < factory < docks.
const SIZE_BY_BIOME: Array[Vector2] = [
	Vector2(2400.0, 1600.0),
	Vector2(3360.0, 2240.0),
	Vector2(4560.0, 3040.0),
	Vector2(5760.0, 3840.0),
	Vector2(7200.0, 4800.0),
]


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


static func shop_stand_position() -> Vector2:
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


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_walls()
	if not GameRuntime.is_classic():
		_build_field()
	queue_redraw()


func rebuild() -> void:
	for child in get_children():
		if child.name == "Walls":
			continue
		child.free()
	obstacles.clear()
	walk_pads.clear()
	_fit_walls()
	if not GameRuntime.is_classic():
		_build_field()
	queue_redraw()


## True when a circle of the given radius would overlap a rock or unwalkable biome
## terrain, so spawners can pick somewhere else instead of shoving enemies into lava.
func is_blocked(world_position: Vector2, radius: float = 20.0) -> bool:
	if not _is_walkable(world_position, radius):
		return true
	for obstacle in obstacles:
		if world_position.distance_to(obstacle.global_position) < obstacle.body_radius + radius:
			return true
	return false


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
	if GameRuntime.uses_biomes():
		walk_pads = _pads_for_biome(GameRuntime.biome_id)
		_build_void_bodies()
	_scatter_obstacles()
	var shop_stand := SHOP_STAND_SCENE.instantiate() as Node2D
	shop_stand.global_position = shop_stand_position()
	add_child(shop_stand)


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
			# Volcano: spawn island, shop island, and outcrops linked by bridges over lava.
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

	if not walk_pads.is_empty():
		_draw_void_rect(rect)
		for pad in walk_pads:
			_draw_ground_rect(pad)
	else:
		_draw_ground_rect(rect)
	_draw_decals()
	if GameRuntime.uses_biomes():
		var rim := Color("1a2a18")
		var inner := Color(0.09, 0.16, 0.09, 0.55)
		match GameRuntime.biome_id:
			1:
				rim = Color("e85a2a")
				inner = Color(0.28, 0.08, 0.05, 0.55)
			2:
				rim = Color("8ad7ff")
				inner = Color(0.10, 0.18, 0.28, 0.55)
			3:
				rim = Color("2bbfbe")
				inner = Color(0.08, 0.10, 0.14, 0.55)
			4:
				rim = Color("4f8fe0")
				inner = Color(0.10, 0.12, 0.18, 0.55)
		draw_rect(rect, rim, false, 16.0)
		draw_rect(rect.grow(-16.0), inner, false, 4.0)
	else:
		draw_rect(rect, Color("1a2a18"), false, 16.0)
		draw_rect(rect.grow(-16.0), Color(0.09, 0.16, 0.09, 0.55), false, 4.0)


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
	var ground := SpriteLibrary.texture_for("grass_tile")
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
		var size := Vector2(texture.get_width(), texture.get_height()) * PIXEL_ZOOM
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

class_name Arena
extends Node2D

const ARENA_SIZE := Vector2(2400.0, 1600.0)

const OBSTACLE_SCENE: PackedScene = preload("res://scenes/arena/obstacle.tscn")
const SHOP_STAND_SCENE: PackedScene = preload("res://scenes/arena/shop_stand.tscn")

## Walk-up shop, always open (unlike the forced breather every 10 waves) — see main.gd's
## proximity check. Placed off-center so it doesn't sit in the middle of the fight.
const SHOP_STAND_POSITION := Vector2(560.0, -260.0)
const SHOP_STAND_CLEARANCE := 140.0

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
const DECAL_COUNT := 320
const WALL_MARGIN := 140.0
const SPAWN_CLEARANCE := 320.0
const OBSTACLE_SPACING := 165.0

var obstacles: Array[Obstacle] = []


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if not GameRuntime.is_classic():
		_build_field()
	queue_redraw()


## True when a circle of the given radius would overlap a rock, so spawners can
## pick somewhere else instead of shoving enemies into the scenery.
func is_blocked(world_position: Vector2, radius: float = 20.0) -> bool:
	for obstacle in obstacles:
		if world_position.distance_to(obstacle.global_position) < obstacle.body_radius + radius:
			return true
	return false


## The nearest free spot on a short outward search, used for enemy spawns.
func free_position_near(world_position: Vector2, radius: float = 20.0) -> Vector2:
	if not is_blocked(world_position, radius):
		return world_position
	for step in range(1, 9):
		var push := float(step) * 40.0
		for turn in 8:
			var angle := TAU * float(turn) / 8.0
			var candidate := world_position + Vector2.RIGHT.rotated(angle) * push
			if _inside_playfield(candidate) and not is_blocked(candidate, radius):
				return candidate
	return world_position


func _inside_playfield(world_position: Vector2) -> bool:
	var limit := ARENA_SIZE * 0.5 - Vector2(WALL_MARGIN, WALL_MARGIN)
	return absf(world_position.x) < limit.x and absf(world_position.y) < limit.y


func _build_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED
	var limit := ARENA_SIZE * 0.5 - Vector2(WALL_MARGIN, WALL_MARGIN)

	var attempts := 0
	while obstacles.size() < OBSTACLE_COUNT and attempts < OBSTACLE_COUNT * 40:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(-limit.x, limit.x),
			rng.randf_range(-limit.y, limit.y)
		)
		if candidate.length() < SPAWN_CLEARANCE:
			continue
		if candidate.distance_to(SHOP_STAND_POSITION) < SHOP_STAND_CLEARANCE:
			continue
		if _too_close_to_other_obstacle(candidate):
			continue
		_add_obstacle(candidate, OBSTACLE_TYPES[rng.randi() % OBSTACLE_TYPES.size()])

	var shop_stand := SHOP_STAND_SCENE.instantiate() as Node2D
	shop_stand.global_position = SHOP_STAND_POSITION
	add_child(shop_stand)


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


func _draw() -> void:
	var rect := Rect2(-ARENA_SIZE * 0.5, ARENA_SIZE)
	if GameRuntime.is_classic():
		_draw_classic_grid(rect)
		return

	var ground := SpriteLibrary.texture_for("grass_tile")
	if ground == null:
		draw_rect(rect, Color("2f4f26"), true)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL_ZOOM, PIXEL_ZOOM))
		draw_texture_rect(ground, Rect2(rect.position / PIXEL_ZOOM, rect.size / PIXEL_ZOOM), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_decals()
	draw_rect(rect, Color("1a2a18"), false, 16.0)
	draw_rect(rect.grow(-16.0), Color(0.09, 0.16, 0.09, 0.55), false, 4.0)


func _draw_decals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED + 1
	var limit := ARENA_SIZE * 0.5 - Vector2(60.0, 60.0)
	for _index in DECAL_COUNT:
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
	for x in range(-1200, 1201, 100):
		draw_line(Vector2(x, -800), Vector2(x, 800), grid_color, 1.0)
	for y in range(-800, 801, 100):
		draw_line(Vector2(-1200, y), Vector2(1200, y), grid_color, 1.0)
	draw_rect(rect, Color("4b6388"), false, 8.0)

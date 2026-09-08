extends Node2D

## Tougher creep camp spawner (HoN-style). Spawned by main.gd after arena/player setup.
## No class_name on purpose: keep the global script-class registry clean.

const RESPAWN_INTERVAL := 45.0
const SQUAD_SIZE := 3
const MAX_ALIVE_PER_CAMP := 2
const CAMP_JITTER := 46.0
const MARKER_Z_INDEX := 2000  # above the depth_z range (~400+int(y)) so camp rings stay visible

const TOUGH_TYPES: Array[String] = ["brute", "sentinel", "stalker", "summoner"]
const HEALTH_RANGE := [2.0, 4.0]
const SPEED_RANGE := [0.8, 1.2]

var _main: Node = null
var _arena: Node2D = null
var _camp_positions: Array[Vector2] = []
var _camp_markers: Array = []
var _camp_alive_counts: Dictionary = {}
var _spawn_timer := 0.0
var _enabled := false

func start(main_node: Node, arena_node: Node2D) -> void:
	_main = main_node
	_arena = arena_node

	if _main == null or _arena == null:
		push_warning("CreepCamp: main or arena is null, camp spawner disabled.")
		return

	if not _main.has_method("_spawn_enemy_at"):
		push_warning("CreepCamp: main._spawn_enemy_at missing, camp spawner disabled.")
		return

	if not _arena.has_method("half_extents"):
		push_warning("CreepCamp: arena.half_extents missing, camp spawner disabled.")
		return

	_camp_positions = _build_camp_positions()
	_build_markers()

	for i in _camp_positions.size():
		_camp_alive_counts[i] = 0

	# Initial fill so camps aren't empty at game start.
	_respawn_camps()
	_enabled = true

func _process(delta: float) -> void:
	if not _enabled:
		return
	_spawn_timer += delta
	if _spawn_timer >= RESPAWN_INTERVAL:
		_spawn_timer = 0.0
		_respawn_camps()


## Public: return the positions of camps that still have living elites
## (i.e. camps worth fighting). Used by the selftest bot to seek camps.
func active_camp_positions() -> Array[Vector2]:
	if not _enabled:
		return []
	var out: Array[Vector2] = []
	for i in _camp_positions.size():
		var alive := int(_camp_alive_counts.get(i, 0))
		if alive > 0 and alive < MAX_ALIVE_PER_CAMP:
			out.append(_camp_positions[i])
	return out

func _build_camp_positions() -> Array[Vector2]:
	var half: Vector2 = _arena.half_extents()
	if half.x < 80.0 or half.y < 80.0:
		half = Vector2(2360.0, 1560.0) * 0.5
	# 4 fixed camps at roughly 1/3 and 2/3 of the half extents on each axis.
	return [
		Vector2(-half.x * 0.34, -half.y * 0.55),
		Vector2( half.x * 0.55, -half.y * 0.34),
		Vector2(-half.x * 0.55,  half.y * 0.34),
		Vector2( half.x * 0.34,  half.y * 0.55),
	]

func _respawn_camps() -> void:
	_update_alive_counts()
	for i in _camp_positions.size():
		var alive := int(_camp_alive_counts.get(i, 0))
		if alive >= MAX_ALIVE_PER_CAMP:
			continue
		var missing := maxi(1, SQUAD_SIZE - alive)
		for _slot in missing:
			var pos := _camp_positions[i] + Vector2(
				randf_range(-CAMP_JITTER, CAMP_JITTER),
				randf_range(-CAMP_JITTER, CAMP_JITTER),
			)
			var type_id := TOUGH_TYPES[randi() % TOUGH_TYPES.size()]
			var health_mult := randf_range(HEALTH_RANGE[0], HEALTH_RANGE[1])
			var speed_mult := randf_range(SPEED_RANGE[0], SPEED_RANGE[1])
			_main._spawn_enemy_at(pos, type_id, health_mult, speed_mult)
			_camp_alive_counts[i] = int(_camp_alive_counts.get(i, 0)) + 1

func _update_alive_counts() -> void:
	for i in _camp_positions.size():
		var alive := 0
		var enemies_ref: Variant = _main.get("enemies")
		if enemies_ref is Dictionary:
			for enemy in (enemies_ref as Dictionary).values():
				if not is_instance_valid(enemy):
					continue
				var hp = enemy.get("health")
				if hp == null or hp.get("is_dead"):
					continue
				if enemy.global_position.distance_to(_camp_positions[i]) < 140.0:
					alive += 1
		_camp_alive_counts[i] = alive

func _build_markers() -> void:
	var tex := _make_marker_texture()
	for i in _camp_positions.size():
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = _camp_positions[i]
		spr.z_index = MARKER_Z_INDEX
		spr.z_as_relative = false
		spr.modulate = Color(0.9, 0.7, 1.0, 0.55)
		add_child(spr)
		_camp_markers.append(spr)

func _make_marker_texture() -> ImageTexture:
	var size := 56
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := size / 2.0
	var cy := size / 2.0
	var outer := size * 0.48
	var inner := size * 0.34
	for y in size:
		for x in size:
			var p := Vector2(x - cx, y - cy)
			var d := p.length()
			var a := 0.0
			if d <= outer and d >= outer - 3.0:
				a = 0.9
			elif d <= inner and d >= inner - 2.0:
				a = 0.45
			elif d < inner - 2.0:
				a = 0.18
			if a > 0.0:
				img.set_pixel(x, y, Color(0.95, 0.72, 1.0, a))
	return ImageTexture.create_from_image(img)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_main = null
		_arena = null

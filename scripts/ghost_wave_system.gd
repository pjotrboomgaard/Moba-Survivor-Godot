extends Node2D

## Continuous "ghost trickle" system.
##
## Ghosts are lightweight records (NOT real Enemy nodes): {pos, vel, type_id, hp_mult,
## speed_mult}. They spawn continuously from the map perimeter and stream toward the
## active player(s). When a ghost enters a player's camera viewport rectangle, it
## "materializes" into a real Enemy just off-screen via main._spawn_enemy_at().
##
## The minimap reads get_ghosts() every frame to draw incoming dots.
## This is ADDITIONAL to the wave system — it does not replace or gate WaveDirector.

const GHOST_CAP := 200
const GHOST_SPAWN_MARGIN := 80.0
const MATERIALIZE_PUSH := 50.0
const VIEWPORT_EXPAND := 120.0
const MAX_MATERIALIZE_PER_FRAME := 4
const GHOST_TYPES: Array[String] = ["grunt", "swarmling", "spitter", "brute", "charger", "drifter", "stalker"]

signal ghosts_updated

var _ghosts: Array[Dictionary] = []
var _spawn_accumulator := 0.0
var _dirty := false
var _viewport_rects: Array[Rect2] = []
var _main: Node = null
var _active := false
var _game_over := false


func get_ghosts() -> Array:
	return _ghosts


func bind(main_node: Node) -> void:
	_main = main_node
	if _main != null:
		_active = not _main.get("game_over")


func _process(delta: float) -> void:
	if not _active or _game_over:
		return
	_update_ghosts(delta)
	_spawn_new_ghosts(delta)
	_compute_viewport_rects()
	_materialize_into_viewports()
	if _dirty:
		_dirty = false
		ghosts_updated.emit()


func _update_ghosts(delta: float) -> void:
	var i := 0
	while i < _ghosts.size():
		var g := _ghosts[i]
		g.pos = g.pos + g.vel * delta
		if _is_way_off_map(g.pos):
			_ghosts.remove_at(i)
			_dirty = true
		else:
			i += 1


func _spawn_new_ghosts(delta: float) -> void:
	if _ghosts.size() >= GHOST_CAP:
		return
	_spawn_accumulator += _spawn_rate_per_second() * delta
	while _spawn_accumulator >= 1.0 and _ghosts.size() < GHOST_CAP:
		_spawn_accumulator -= 1.0
		_spawn_one_ghost()
		_dirty = true


func _spawn_rate_per_second() -> float:
	var wave := 1
	if _main != null:
		wave = maxi(1, int(_main.get("current_wave")))
	var wave_factor := 1.0 + 0.08 * float(wave - 1)
	var player_count := 1
	if _main != null:
		player_count = maxi(1, (_main.get("players") as Dictionary).size())
	var player_factor := 1.0 + 0.25 * float(player_count - 1)
	return 1.4 * wave_factor * player_factor


func _spawn_one_ghost() -> void:
	var type_id: String = str(GHOST_TYPES.pick_random())
	var speed: float = float(EnemyType.field(type_id, "movement_speed"))
	if speed <= 0.0:
		speed = 90.0
	var speed_mult := randf_range(0.82, 1.18)
	var hp_mult := 1.0
	if _main != null and _main.get("wave_director") != null:
		hp_mult = float((_main.get("wave_director") as WaveDirector).health_multiplier_for_wave(maxi(1, int(_main.get("current_wave")))))
	var half := _playfield_half()
	var pos := _random_perimeter_point(half)
	var target := _pick_target_position()
	var dir := target - pos
	if dir.length_squared() < 1.0:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var vel := dir.normalized() * speed * speed_mult
	_ghosts.append({
		"pos": pos,
		"vel": vel,
		"type_id": type_id,
		"hp_mult": hp_mult,
		"speed_mult": speed_mult,
	})


func _random_perimeter_point(half: Vector2) -> Vector2:
	var m := GHOST_SPAWN_MARGIN
	var edge := randi() % 4
	match edge:
		0:
			return Vector2(randf_range(-half.x - m, half.x + m), -half.y - m)
		1:
			return Vector2(randf_range(-half.x - m, half.x + m), half.y + m)
		2:
			return Vector2(-half.x - m, randf_range(-half.y - m, half.y + m))
		3:
			return Vector2(half.x + m, randf_range(-half.y - m, half.y + m))
		_:
			return Vector2(half.x + m, randf_range(-half.y - m, half.y + m))


func _pick_target_position() -> Vector2:
	if _main != null:
		for player_node in (_main.get("players") as Dictionary).values():
			var p := player_node as Player
			if p != null and is_instance_valid(p) and p.active:
				return p.global_position
	return Vector2.ZERO


func _playfield_half() -> Vector2:
	if _main != null and _main.get("arena") != null and (_main.get("arena") as Node).has_method("half_extents"):
		return (_main.get("arena") as Arena).half_extents()
	return Vector2(2400.0, 1600.0)


func _is_way_off_map(pos: Vector2) -> bool:
	var half := _playfield_half() + Vector2(2000.0, 2000.0)
	return absf(pos.x) > half.x or absf(pos.y) > half.y


func _compute_viewport_rects() -> void:
	_viewport_rects.clear()
	if _main == null:
		return
	for player_node in (_main.get("players") as Dictionary).values():
		var p := player_node as Player
		if p == null or not is_instance_valid(p) or not p.active:
			continue
		var camera := p.get_node_or_null("Camera2D")
		if camera == null or not (camera is Camera2D):
			continue
		var cam := camera as Camera2D
		if not cam.enabled:
			continue
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var half_world: Vector2 = viewport_size / (cam.zoom * 2.0) + Vector2(VIEWPORT_EXPAND, VIEWPORT_EXPAND)
		_viewport_rects.append(Rect2(p.global_position - half_world, half_world * 2.0))


func _materialize_into_viewports() -> void:
	if _viewport_rects.is_empty():
		return
	var materialized := 0
	var i := _ghosts.size() - 1
	while i >= 0 and materialized < MAX_MATERIALIZE_PER_FRAME:
		var g := _ghosts[i]
		var pos: Vector2 = g.pos
		var hit_rect := Rect2()
		var hit := false
		for rect in _viewport_rects:
			if rect.has_point(pos):
				hit = true
				hit_rect = rect
				break
		if not hit:
			i -= 1
			continue
		var mat_pos := _materialize_position(pos, hit_rect)
		var type_id: String = g.type_id
		var hp_mult: float = g.hp_mult
		var spd_mult: float = g.speed_mult
		_ghosts.remove_at(i)
		if _main.has_method("_spawn_enemy_at"):
			var enemy: Enemy = _main._spawn_enemy_at(mat_pos, type_id, hp_mult, spd_mult)
			if enemy != null:
				materialized += 1
		_dirty = true
		i -= 1


func _materialize_position(ghost_pos: Vector2, rect: Rect2) -> Vector2:
	var cx := clampf(ghost_pos.x, rect.position.x, rect.end.x)
	var cy := clampf(ghost_pos.y, rect.position.y, rect.end.y)
	var on_boundary := Vector2(cx, cy)
	var dir := on_boundary - rect.get_center()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	return on_boundary + dir * MATERIALIZE_PUSH


func set_game_over(next: bool) -> void:
	_game_over = next
	if next and not _ghosts.is_empty():
		_ghosts.clear()
		_dirty = true
		ghosts_updated.emit()

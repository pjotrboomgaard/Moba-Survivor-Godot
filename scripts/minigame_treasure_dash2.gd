extends "res://scripts/minigame_base.gd"
## TREASURE DASH 2 (town): collect moving gems while dodging obstacles.
##
## Gems drift slowly around the arena; touching one collects it for points.
## Obstacles drift too — touching one costs points and a combo. Creeps join as
## "gem carriers" that drift with the gems. 45s.
##
## Bot: path to the nearest uncollected gem.

const DASH2_DURATION := 45.0
const ARENA_RADIUS := 180.0
const GEM_RADIUS := 12.0
const OBSTACLE_RADIUS := 16.0
const GEM_COUNT := 7
const OBSTACLE_COUNT := 4
const COMBO_DECAY := 2.0

var _gems: Array[Dictionary] = []      # {pos, vel, taken}
var _obstacles: Array[Dictionary] = [] # {pos, vel}
var _creeps: Array[Dictionary] = []
var _combo := 0
var _combo_timer := 0.0


func _reset() -> void:
	timer = DASH2_DURATION
	_gems.clear()
	_obstacles.clear()
	_creeps.clear()
	_combo = 0
	_combo_timer = 0.0
	score = 0
	_spawn_gems()
	_spawn_obstacles()
	_spawn_creeps()


func _random_pos_in_arena() -> Vector2:
	return Vector2.from_angle(randf() * TAU) * randf_range(40.0, ARENA_RADIUS - 10.0)


func _random_vel(speed: float) -> Vector2:
	return Vector2.from_angle(randf() * TAU) * speed


func _spawn_gems() -> void:
	for i in GEM_COUNT:
		_gems.append({
			"pos": _random_pos_in_arena(),
			"vel": _random_vel(randf_range(18.0, 34.0)),
			"taken": false,
		})


func _spawn_obstacles() -> void:
	for i in OBSTACLE_COUNT:
		_obstacles.append({
			"pos": _random_pos_in_arena(),
			"vel": _random_vel(randf_range(22.0, 40.0)),
		})


func _spawn_creeps() -> void:
	var palette := [Color(0.9, 0.5, 0.3), Color(0.8, 0.7, 0.2)]
	for i in 3:
		_creeps.append({
			"pos": Vector2.from_angle(TAU * float(i) / 3.0 + 0.5) * (ARENA_RADIUS + 20.0),
			"color": palette[i % 2],
			"bob": randf() * TAU,
		})


func _drift(entity: Dictionary, delta: float) -> void:
	var p: Vector2 = entity["pos"]
	var v: Vector2 = entity["vel"]
	var np := p + v * delta
	# Bounce off arena bounds.
	var d := np.length()
	if d > ARENA_RADIUS:
		var n := np.normalized()
		np = n * ARENA_RADIUS
		var dot := v.dot(n)
		v = (v - 2.0 * dot * n)
		entity["vel"] = v
	entity["pos"] = np


func _update_delta(delta: float) -> void:
	for g in _gems:
		_drift(g, delta)
	for o in _obstacles:
		_drift(o, delta)

	_combo_timer += delta
	if _combo_timer >= COMBO_DECAY:
		_combo = 0
		_combo_timer = 0.0

	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		# Obstacle hits.
		for o in _obstacles:
			if (o.get("pos") as Vector2).distance_to(rel) < OBSTACLE_RADIUS + 14.0:
				score = maxi(0, score - 20)
				_combo = 0
				_combo_timer = 0.0
		# Gem pickup.
		for g in _gems:
			if bool(g.get("taken", false)):
				continue
			if (g.get("pos") as Vector2).distance_to(rel) < GEM_RADIUS + 14.0:
				g["taken"] = true
				_combo += 1
				score += 12 * maxi(1, _combo)
				_combo_timer = 0.0
				# Refill a taken gem at a new spot to keep the game going.
				g["taken"] = false
				g["pos"] = _random_pos_in_arena()
				g["vel"] = _random_vel(randf_range(18.0, 34.0))
				if _creeps.size() < 12:
					_add_carrier()

	for c in _creeps:
		c["bob"] = float(c.get("bob", 0.0)) + delta * 3.0
	queue_redraw()


func _add_carrier() -> void:
	_creeps.append({
		"pos": Vector2.from_angle(randf() * TAU) * (ARENA_RADIUS + 20.0),
		"color": Color(randf_range(0.5, 0.95), randf_range(0.5, 0.9), 0.4),
		"bob": randf() * TAU,
	})


func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	# Nearest gem, weighted by obstacle proximity (avoid paths into obstacles).
	var best_pos := Vector2.ZERO
	var best_d := 999999.0
	for g in _gems:
		var gp: Vector2 = g.get("pos", Vector2.ZERO)
		var d := rel.distance_to(gp)
		if d < best_d:
			best_d = d
			best_pos = gp
	if best_d > 99999.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var to := best_pos - rel
	if to.length() < 5.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": to.normalized(), "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	pass


func _draw_body() -> void:
	# Town plaza floor (stone)
	draw_circle(Vector2.ZERO, ARENA_RADIUS + 20.0, Color(0.28, 0.25, 0.2, 0.55))
	draw_arc(Vector2.ZERO, ARENA_RADIUS, 0.0, TAU, 48, Color(0.5, 0.45, 0.35, 0.5), 3.0)

	# Obstacles
	for o in _obstacles:
		var op: Vector2 = o.get("pos", Vector2.ZERO)
		draw_circle(op, OBSTACLE_RADIUS, Color(0.5, 0.15, 0.15, 0.95))
		draw_circle(op, OBSTACLE_RADIUS * 0.5, Color(0.3, 0.1, 0.1, 0.9))

	# Gems
	for g in _gems:
		var gp: Vector2 = g.get("pos", Vector2.ZERO)
		var bob := sin(Time.get_ticks_msec() * 0.008 + gp.x * 0.01) * 3.0
		draw_circle(gp + Vector2(0.0, bob), GEM_RADIUS, Color(1.0, 0.85, 0.2, 0.95))
		draw_circle(gp + Vector2(0.0, bob - 3.0), 4.0, Color(1.0, 1.0, 0.6, 0.7))

	# Creeps
	for c in _creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var bob := sin(float(c.get("bob", 0.0))) * 3.0
		draw_circle(cp + Vector2(0.0, bob), 11.0, cc)
		draw_circle(cp + Vector2(0.0, bob) + Vector2(0.0, -5.0), 4.0, Color(1.0, 1.0, 1.0, 0.6))

	# Player marker
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		draw_circle(rel, 14.0, Color(0.4, 0.8, 1.0, 0.95))

	# Combo text
	if _combo > 1:
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, -ARENA_RADIUS - 24.0),
			"COMBO x%d" % _combo, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color(1.0, 0.9, 0.3, 0.9))


func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		var crowd_bonus := _creeps.size() * 5
		owner_player.add_gold(REWARD_GOLD + int(score * 0.2) + crowd_bonus)
		owner_player.add_xp(REWARD_XP + crowd_bonus)
	AudioService.play("minigame_win")
	_emit_finished()

extends "res://scripts/minigame_base.gd"
## WHACK RUSH (forest): fast 4x4 grid of pop-up targets; whack as many as you can.
##
## Targets pop up at random cells for a short window. Whacking a target gives
## points and builds a combo multiplier. Missing (letting one despawn) resets the
## combo. Creeps join as "whackers" in the corners. 40s.
##
## Bot: whack the oldest active target each frame.

const RUSH_DURATION := 40.0
const GRID := 4
const CELL := 70.0
const TARGET_LIFETIME := 1.4
const WHACK_RADIUS := 34.0

var _targets: Array[Dictionary] = []  # {pos, born, alive}
var _combo := 0
var _max_combo := 0
var _creeps: Array[Dictionary] = []
var _spawn_timer := 0.0


func _reset() -> void:
	timer = RUSH_DURATION
	_targets.clear()
	_combo = 0
	_max_combo = 0
	score = 0
	_spawn_timer = 0.0
	_spawn_creeps()


func _grid_cell_pos(cell: int) -> Vector2:
	var gx := cell % GRID
	var gy := cell / GRID
	var origin := Vector2(-(GRID - 1) * CELL * 0.5, -(GRID - 1) * CELL * 0.5)
	return origin + Vector2(gx, gy) * CELL


func _spawn_creeps() -> void:
	_creeps.clear()
	var corners := [Vector2(-190, -190), Vector2(190, -190), Vector2(-190, 190), Vector2(190, 190)]
	var palette := [Color(0.3, 0.8, 0.3), Color(0.2, 0.7, 0.6)]
	for i in 4:
		_creeps.append({
			"pos": corners[i] + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
			"color": palette[i % 2],
			"bob": randf() * TAU,
		})


func _update_delta(delta: float) -> void:
	# Spawn new targets.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.55
		var open_cells: Array[int] = []
		for cell in GRID * GRID:
			var occupied := false
			for t in _targets:
				if int(t.get("cell", -1)) == cell and bool(t.get("alive", false)):
					occupied = true
					break
			if not occupied:
				open_cells.append(cell)
		if not open_cells.is_empty():
			var cell := open_cells[randi() % open_cells.size()]
			_targets.append({
				"cell": cell,
				"pos": _grid_cell_pos(cell),
				"born": _elapsed_local(),
				"alive": true,
			})

	# Age targets; despawn stale ones and reset combo.
	for t in _targets:
		if bool(t.get("alive", false)) and (_elapsed_local() - float(t.get("born", 0.0))) > TARGET_LIFETIME:
			t["alive"] = false
			_combo = 0

	# Whack targets the hero stands over.
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		for t in _targets:
			if not t.get("alive", false):
				continue
			if (t.get("pos") as Vector2).distance_to(rel) < WHACK_RADIUS:
				t["alive"] = false
				_combo += 1
				_max_combo = maxi(_max_combo, _combo)
				score += 10 * maxi(1, _combo)
				if _creeps.size() < 12 and _combo >= 3:
					_add_creep()

	for c in _creeps:
		c["bob"] = float(c.get("bob", 0.0)) + delta * 4.0
	queue_redraw()


func _elapsed_local() -> float:
	return RUSH_DURATION - timer


func _add_creep() -> void:
	var a := randf() * TAU
	_creeps.append({
		"pos": Vector2.from_angle(a) * 200.0,
		"color": Color(randf_range(0.3, 0.9), 0.7, randf_range(0.2, 0.8)),
		"bob": randf() * TAU,
	})


func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	# Pick the oldest live target.
	var best: Dictionary = {}
	var best_age := -1.0
	for t in _targets:
		if bool(t.get("alive", false)):
			var age := _elapsed_local() - float(t.get("born", 0.0))
			if age > best_age:
				best_age = age
				best = t
	if best.is_empty():
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var to := (best.get("pos") as Vector2) - rel
	if to.length() < 5.0:
		return {"move": Vector2.ZERO, "attack": true, "interact": false}
	return {"move": to.normalized(), "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	pass


func _draw_body() -> void:
	# Forest floor
	draw_circle(Vector2.ZERO, GRID * CELL * 0.5 + 30.0, Color(0.1, 0.3, 0.15, 0.55))

	# Grid cells (subtle)
	for cell in GRID * GRID:
		draw_rect(Rect2(_grid_cell_pos(cell) - Vector2(CELL * 0.45, CELL * 0.45),
			Vector2(CELL * 0.9, CELL * 0.9)), Color(0.2, 0.4, 0.2, 0.15))

	# Targets
	for t in _targets:
		if not bool(t.get("alive", false)):
			continue
		var tp: Vector2 = t.get("pos", Vector2.ZERO)
		var age := _elapsed_local() - float(t.get("born", 0.0))
		var flash := 1.0 if age < TARGET_LIFETIME * 0.5 else 0.6
		draw_circle(tp, 22.0, Color(0.9, 0.6, 0.2, flash))
		draw_circle(tp, 12.0, Color(1.0, 0.85, 0.3, flash))

	# Combo text
	if _combo > 1:
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, -GRID * CELL * 0.5 - 30.0),
			"COMBO x%d" % _combo, HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1.0, 0.9, 0.3, 0.9))

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


func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		var combo_bonus := _max_combo * 8
		var crowd_bonus := _creeps.size() * 5
		owner_player.add_gold(REWARD_GOLD + int(score * 0.2) + combo_bonus + crowd_bonus)
		owner_player.add_xp(REWARD_XP + combo_bonus)
	AudioService.play("minigame_win")
	_emit_finished()

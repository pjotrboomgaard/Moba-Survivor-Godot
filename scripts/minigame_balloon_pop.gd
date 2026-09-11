extends "res://scripts/minigame_base.gd"
## BALLOON POP (lagoon): pop balloons that float up from the bottom.
##
## Balloons rise from the bottom of the arena. The hero must move to pop them
## before they float away at the top. Each pop scores points; faster pops build
## a combo. Creeps join as "balloon carriers" that hold extra balloons. 40s.
##
## Bot: target the lowest (closest to escaping) balloon.

const BALLOON_DURATION := 40.0
const FIELD_H := 260.0
const BALLOON_RADIUS := 14.0
const POP_DIST := 32.0
const RISE_SPEED := 45.0
const MAX_BALLOONS := 8

var _balloons: Array[Dictionary] = []
var _spawn_timer := 0.0
var _combo := 0
var _max_combo := 0
var _creeps: Array[Dictionary] = []
var _comment_text := ""
var _comment_timer := 0.0

func _reset() -> void:
	timer = BALLOON_DURATION
	_spawn_timer = 0.5
	_combo = 0
	_max_combo = 0
	_comment_text = ""
	_comment_timer = 0.0
	_balloons.clear()
	_spawn_creeps()
	score = 0

func _spawn_creeps() -> void:
	_creeps.clear()
	var palette := [Color(0.4, 0.85, 0.7), Color(0.3, 0.75, 0.9), Color(0.5, 0.9, 0.5)]
	for i in 3:
		var a := TAU * float(i) / 3.0
		_creeps.append({
			"pos": Vector2.from_angle(a) * 180.0,
			"color": palette[i % palette.size()],
			"bob": randf() * TAU,
		})

func _spawn_balloon() -> void:
	if _balloons.size() >= MAX_BALLOONS:
		return
	var x := randf_range(-140.0, 140.0)
	var colors := [Color(0.95, 0.3, 0.3), Color(0.95, 0.8, 0.2), Color(0.3, 0.85, 0.4), Color(0.5, 0.5, 0.95), Color(0.9, 0.5, 0.8)]
	_balloons.append({
		"pos": Vector2(x, FIELD_H * 0.5),
		"color": colors[randi() % colors.size()],
		"sway_phase": randf() * TAU,
	})

func _update_delta(delta: float) -> void:
	# Spawn timer.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_balloon()
		_spawn_timer = randf_range(0.6, 1.4)
	# Move balloons upward.
	for i in _balloons.size() - 1:
		var b: Dictionary = _balloons[i]
		b["pos"] = (b.get("pos") as Vector2) + Vector2(0.0, -RISE_SPEED * delta)
		var bp: Vector2 = b.get("pos", Vector2.ZERO)
		# Escaped off the top.
		if bp.y < -FIELD_H * 0.5:
			_balloons.remove_at(i)
			_combo = 0
			continue
		# Check pop by hero.
		if owner_player != null and is_instance_valid(owner_player):
			var rel := owner_player.global_position - global_position
			if bp.distance_to(rel) < POP_DIST:
				_balloons.remove_at(i)
				_combo += 1
				_max_combo = maxi(_max_combo, _combo)
				score += 10 * maxi(1, _combo)
				_spawn_next_creep()
				_check_comment()
	# Bob the creeps.
	for c in _creeps:
		c["bob"] = float(c.get("bob", 0.0)) + delta * 3.0
	_comment_timer = maxf(0.0, _comment_timer - delta)
	queue_redraw()

func _spawn_next_creep() -> void:
	if _creeps.size() < 14:
		var a := randf() * TAU
		_creeps.append({
			"pos": Vector2.from_angle(a) * 200.0,
			"color": Color(0.4 + randf_range(0.0, 0.4), 0.8, 0.7),
			"bob": randf() * TAU,
		})

func _check_comment() -> void:
	if _combo >= 10:
		_comment_text = "Balloon bonanza!"
		_comment_timer = 2.5
	elif _combo >= 5:
		_comment_text = "Great popping!"
		_comment_timer = 2.0

func bot_tick(_delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Target the lowest balloon (closest to bottom = will escape soonest from top).
	var best: Dictionary = {}
	var best_y := -INF
	for b in _balloons:
		var bp: Vector2 = b.get("pos", Vector2.ZERO)
		if bp.y > best_y:
			best_y = bp.y
			best = b
	if best.is_empty():
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	var target: Vector2 = best.get("pos", Vector2.ZERO)
	var to_target := target - rel
	if to_target.length() < 4.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": to_target.normalized(), "attack": false, "interact": false}

func on_input_event(_event: InputEvent) -> void:
	pass

func _draw_body() -> void:
	# Lagoon water floor.
	draw_circle(Vector2.ZERO, 170.0, Color(0.1, 0.3, 0.4, 0.5))
	# Balloons.
	for b in _balloons:
		var bp: Vector2 = b.get("pos", Vector2.ZERO)
		var bc: Color = b.get("color", Color.WHITE)
		var sway := sin(Time.get_ticks_msec() * 0.003 + float(bp.x) * 0.02) * 4.0
		draw_circle(bp + Vector2(sway, 0.0), BALLOON_RADIUS, bc)
		draw_circle(bp + Vector2(sway - 4.0, -5.0), 4.0, Color(1.0, 1.0, 1.0, 0.5))
		draw_line(bp + Vector2(sway, BALLOON_RADIUS), bp + Vector2(sway * 0.5, BALLOON_RADIUS + 18.0), Color(0.8, 0.8, 0.8, 0.4), 1.5)
	# Creeps.
	for c in _creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var bob := sin(float(c.get("bob", 0.0))) * 3.0
		draw_circle(cp + Vector2(0.0, bob), 11.0, cc)
		draw_circle(cp + Vector2(0.0, bob) + Vector2(0.0, -5.0), 4.0, Color(1.0, 1.0, 1.0, 0.6))
	# Player marker.
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		draw_circle(rel, 14.0, Color(0.5, 0.9, 0.95, 0.95))
	# Combo + score.
	var combo_text := "x%d" % _combo if _combo >= 2 else ""
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, -FIELD_H * 0.55),
		"Pop! %s" % combo_text, HORIZONTAL_ALIGNMENT_CENTER, 120, 14,
		Color(1.0, 0.9, 0.4, 0.9))
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 2.5, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-100.0, 35.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 15,
			Color(0.4, 1.0, 0.9, alpha))

func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		var combo_bonus := _max_combo * 3
		var crowd_bonus := _creeps.size() * 4
		owner_player.add_gold(REWARD_GOLD + int(score * 0.15) + combo_bonus + crowd_bonus)
		owner_player.add_xp(REWARD_XP + int(score * 0.1) + crowd_bonus)


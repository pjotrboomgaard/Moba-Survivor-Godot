extends "res://scripts/minigame_base.gd"
## CREEP PINBALL (factory): steer a paddle to bounce creeps into score pockets.
##
## Creeps fall from the top; the hero is a paddle at the bottom. Bounce creeps
## into left/right/center pockets to score. Creeps that miss the paddle are lost.
## Joined creeps fall faster. 40s.
##
## Bot: steer paddle under the nearest falling creep.

const PINBALL_DURATION := 40.0
const FIELD_W := 300.0
const FIELD_H := 240.0
const PADDLE_W := 60.0
const PADDLE_H := 10.0
const PADDLE_Y := 100.0
const CREEP_RADIUS := 10.0
const POCKET_W := 50.0
const FALL_SPEED_BASE := 80.0

var _creeps: Array[Dictionary] = []
var _paddle_x := 0.0
var _creep_speed := FALL_SPEED_BASE
var _max_creeps := 4
var _comment_text := ""
var _comment_timer := 0.0

func _reset() -> void:
	timer = PINBALL_DURATION
	_paddle_x = 0.0
	_creep_speed = FALL_SPEED_BASE
	_max_creeps = 4
	_comment_text = ""
	_comment_timer = 0.0
	_creeps.clear()
	score = 0
	# Initial creeps
	for i in 3:
		_spawn_creep()

func _spawn_creep() -> void:
	if _creeps.size() >= _max_creeps:
		return
	var x := randf_range(-FIELD_W * 0.4, FIELD_W * 0.4)
	var palette := [Color(0.9, 0.3, 0.3), Color(0.9, 0.7, 0.2), Color(0.3, 0.9, 0.4), Color(0.4, 0.6, 0.95)]
	_creeps.append({
		"pos": Vector2(x, -FIELD_H * 0.5),
		"vel": Vector2(0.0, _creep_speed * randf_range(0.85, 1.15)),
		"color": palette[randi() % palette.size()],
		"alive": true,
	})

func _update_delta(delta: float) -> void:
	# Move paddle toward hero's x (clamped to field).
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		_paddle_x = clampf(rel.x, -FIELD_W * 0.5 + PADDLE_W * 0.5, FIELD_W * 0.5 - PADDLE_W * 0.5)
	# Move creeps.
	var to_remove: Array[int] = []
	for i in _creeps.size():
		var c: Dictionary = _creeps[i]
		if not bool(c.get("alive", true)):
			continue
		c["pos"] = (c.get("pos") as Vector2) + (c.get("vel") as Vector2) * delta
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		# Paddle bounce.
		if cp.y >= PADDLE_Y - CREEP_RADIUS and cp.y <= PADDLE_Y + PADDLE_H and absf(cp.x - _paddle_x) <= PADDLE_W * 0.5 + CREEP_RADIUS:
			c["vel"] = Vector2(randf_range(-1.0, 1.0) * 0.3, -_creep_speed * 1.1)
			c["pos"] = Vector2(cp.x, PADDLE_Y - CREEP_RADIUS)
			# Score on bounce.
			score += 3
		# Wall bounces (left/right).
		if cp.x < -FIELD_W * 0.5 + CREEP_RADIUS:
			c["vel"] = Vector2(absf(float((c.get("vel") as Vector2).x)), float((c.get("vel") as Vector2).y))
			c["pos"] = Vector2(-FIELD_W * 0.5 + CREEP_RADIUS, cp.y)
		elif cp.x > FIELD_W * 0.5 - CREEP_RADIUS:
			c["vel"] = Vector2(-absf(float((c.get("vel") as Vector2).x)), float((c.get("vel") as Vector2).y))
			c["pos"] = Vector2(FIELD_W * 0.5 - CREEP_RADIUS, cp.y)
		# Top wall bounce.
		if cp.y < -FIELD_H * 0.5 + CREEP_RADIUS:
			c["vel"] = Vector2(float((c.get("vel") as Vector2).x), absf(float((c.get("vel") as Vector2).y)))
			c["pos"] = Vector2(cp.x, -FIELD_H * 0.5 + CREEP_RADIUS)
		# Pocket check (bottom corners + center).
		if cp.y > PADDLE_Y + 40.0:
			# Check pockets.
			if absf(cp.x - (-FIELD_W * 0.5 + POCKET_W * 0.5)) < POCKET_W * 0.5 or \
			   absf(cp.x - (FIELD_W * 0.5 - POCKET_W * 0.5)) < POCKET_W * 0.5 or \
			   absf(cp.x) < POCKET_W * 0.4:
				c["alive"] = false
				score += 20
				# Spawn replacement + maybe join a creep.
				_spawn_creep()
				if _creeps.size() < 8:
					_max_creeps = 5
					_creep_speed += 10.0
				_check_comment()
			else:
				# Missed - lost.
				c["alive"] = false
				_spawn_creep()
	# Periodic spawn.
	if _creeps.filter(func(c): return bool(c.get("alive", true))).size() < _max_creeps:
		_spawn_creep()
	queue_redraw()

func _check_comment() -> void:
	if score >= 100:
		_comment_text = "Pinball master!"
		_comment_timer = 2.0
	elif score >= 50:
		_comment_text = "Nice bounces!"
		_comment_timer = 2.0

func bot_tick(_delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Find nearest falling creep, steer under it.
	var best_c: Dictionary = {}
	var best_d := INF
	for c in _creeps:
		if not bool(c.get("alive", true)):
			continue
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cv: Vector2 = c.get("vel", Vector2.ZERO)
		if cv.y <= 0:
			continue
		var d := absf(cp.x - _paddle_x)
		if d < best_d:
			best_d = d
			best_c = c
	if best_c.is_empty():
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var target_x: float = (best_c.get("pos") as Vector2).x
	var rel := owner_player.global_position - global_position
	var dx := target_x - rel.x
	if absf(dx) < 4.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": Vector2(signf(dx), 0.0), "attack": false, "interact": false}

func on_input_event(_event: InputEvent) -> void:
	pass

func _draw_body() -> void:
	# Field background.
	draw_rect(Rect2(-FIELD_W * 0.5, -FIELD_H * 0.5, FIELD_W, FIELD_H + 60.0), Color(0.12, 0.14, 0.18, 0.7))
	# Walls.
	draw_rect(Rect2(-FIELD_W * 0.5, -FIELD_H * 0.5, 4.0, FIELD_H + 60.0), Color(0.5, 0.5, 0.6, 0.8))
	draw_rect(Rect2(FIELD_W * 0.5 - 4.0, -FIELD_H * 0.5, 4.0, FIELD_H + 60.0), Color(0.5, 0.5, 0.6, 0.8))
	draw_rect(Rect2(-FIELD_W * 0.5, -FIELD_H * 0.5, FIELD_W, 4.0), Color(0.5, 0.5, 0.6, 0.8))
	# Pockets — chunky square pockets (3 side blocks + open top) instead of arcs.
	var pocket_half := POCKET_W * 0.45
	var pocket_h := 14.0
	var py := PADDLE_Y + 40.0
	# Left pocket.
	var plx := -FIELD_W * 0.5 + POCKET_W * 0.5
	draw_rect(Rect2(plx - pocket_half - 3.0, py, 3.0, pocket_h), Color(1.0, 0.4, 0.3, 0.8))
	draw_rect(Rect2(plx + pocket_half, py, 3.0, pocket_h), Color(1.0, 0.4, 0.3, 0.8))
	draw_rect(Rect2(plx - pocket_half - 3.0, py + pocket_h, pocket_half * 2.0 + 6.0, 3.0), Color(1.0, 0.4, 0.3, 0.8))
	# Center pocket.
	var pcx := 0.0
	draw_rect(Rect2(pcx - pocket_half * 0.8 - 3.0, py, 3.0, pocket_h), Color(1.0, 0.8, 0.2, 0.8))
	draw_rect(Rect2(pcx + pocket_half * 0.8, py, 3.0, pocket_h), Color(1.0, 0.8, 0.2, 0.8))
	draw_rect(Rect2(pcx - pocket_half * 0.8 - 3.0, py + pocket_h, pocket_half * 1.6 + 6.0, 3.0), Color(1.0, 0.8, 0.2, 0.8))
	# Right pocket.
	var prx := FIELD_W * 0.5 - POCKET_W * 0.5
	draw_rect(Rect2(prx - pocket_half - 3.0, py, 3.0, pocket_h), Color(1.0, 0.4, 0.3, 0.8))
	draw_rect(Rect2(prx + pocket_half, py, 3.0, pocket_h), Color(1.0, 0.4, 0.3, 0.8))
	draw_rect(Rect2(prx - pocket_half - 3.0, py + pocket_h, pocket_half * 2.0 + 6.0, 3.0), Color(1.0, 0.4, 0.3, 0.8))
	# Paddle.
	draw_rect(Rect2(_paddle_x - PADDLE_W * 0.5, PADDLE_Y - PADDLE_H * 0.5, PADDLE_W, PADDLE_H), Color(0.5, 0.9, 1.0, 0.95))
	# Creeps — chunky blocky creeps (body + head + eye highlight).
	for c in _creeps:
		if not bool(c.get("alive", true)):
			continue
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var cr := CREEP_RADIUS
		draw_rect(Rect2(cp + Vector2(-cr, -cr * 0.7), Vector2(cr * 2.0, cr * 1.8)), cc)
		draw_rect(Rect2(cp + Vector2(-cr * 0.7, -cr * 1.4), Vector2(cr * 1.4, cr * 1.0)), cc.lightened(0.15))
		draw_rect(Rect2(cp + Vector2(-3.5, -cr * 1.2), Vector2(7.0, 4.0)), Color(1.0, 1.0, 1.0, 0.7))
	# Score + comment.
	draw_string(ThemeDB.fallback_font, Vector2(-50.0, -FIELD_H * 0.5 - 15.0),
		"Score %d" % score, HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Color(0.9, 0.9, 0.5, 0.9))
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 2.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-100.0, 30.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 14,
			Color(1.0, 0.8, 0.3, alpha))

func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		owner_player.add_gold(REWARD_GOLD + int(score * 0.15))
		owner_player.add_xp(REWARD_XP + int(score * 0.1))


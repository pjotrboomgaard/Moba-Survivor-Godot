extends "res://scripts/minigame_base.gd"
## RING ROLL (ice): steer your ring to lap a frozen track and collect gems.
##
## A glowing ring follows the hero; each lap collects the gems on the track.
## Creeps join as "followers" that trail the ring, growing the crowd. 45s.
##
## Bot: steer toward the next gem on the ring track.

const ROLL_DURATION := 45.0
const RING_RADIUS := 150.0
const GEM_RADIUS := 10.0
const COLLECT_DIST := 30.0
const GEM_COUNT := 8

var _gems: Array[Dictionary] = []
var _active_gem := 0
var _laps := 0
var _creeps: Array[Dictionary] = []
var _comment_text := ""
var _comment_timer := 0.0

func _reset() -> void:
	timer = ROLL_DURATION
	_laps = 0
	_active_gem = 0
	_comment_text = ""
	_comment_timer = 0.0
	_spawn_gems()
	_spawn_creeps()
	score = 0

func _spawn_gems() -> void:
	_gems.clear()
	var palette := [Color(0.5, 0.9, 1.0), Color(0.7, 0.85, 1.0), Color(0.4, 0.8, 0.95)]
	for i in GEM_COUNT:
		var a := TAU * float(i) / float(GEM_COUNT)
		_gems.append({
			"pos": Vector2.from_angle(a) * RING_RADIUS,
			"color": palette[i % palette.size()],
			"taken": false,
		})

func _spawn_creeps() -> void:
	_creeps.clear()
	for i in 3:
		var a := TAU * float(i) / 3.0
		_creeps.append({
			"pos": Vector2.from_angle(a) * 200.0,
			"color": Color(0.6, 0.85, 1.0),
			"bob": randf() * TAU,
		})

func _update_delta(delta: float) -> void:
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		var g: Dictionary = _gems[_active_gem]
		if not bool(g.get("taken", false)):
			if (g.get("pos") as Vector2).distance_to(rel) < COLLECT_DIST:
				g["taken"] = true
				score += 12
				_active_gem = (_active_gem + 1) % _gems.size()
				_spawn_next_group()
				_check_comment()
	# Bob the creeps.
	for c in _creeps:
		c["bob"] = float(c.get("bob", 0.0)) + delta * 3.0
	queue_redraw()

func _spawn_next_group() -> void:
	if _creeps.size() < 14:
		var a := randf() * TAU
		_creeps.append({
			"pos": Vector2.from_angle(a) * 210.0,
			"color": Color(0.5 + randf_range(0.0, 0.4), 0.8, 1.0),
			"bob": randf() * TAU,
		})

func _check_comment() -> void:
	if _active_gem == 3:
		_comment_text = "Nice roll!"
		_comment_timer = 2.0
	elif _active_gem == 6:
		_comment_text = "Keep spinning!"
		_comment_timer = 2.0

func bot_tick(_delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	var target: Vector2 = _gems[_active_gem].pos
	if bool(_gems[_active_gem].get("taken", false)):
		target = _gems[(_active_gem + 1) % _gems.size()].pos
	var to_target := target - rel
	if to_target.length() < 6.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": to_target.normalized(), "attack": false, "interact": false}

func on_input_event(_event: InputEvent) -> void:
	pass

func _draw_body() -> void:
	# Frozen floor.
	draw_circle(Vector2.ZERO, RING_RADIUS + 40.0, Color(0.15, 0.25, 0.35, 0.5))
	# Ring track.
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, 0.5), 3.0, true)

	# Gems.
	for g in _gems:
		var gp: Vector2 = g.get("pos", Vector2.ZERO)
		if bool(g.get("taken", false)):
			continue
		var is_active := _gems.find(g) == _active_gem
		var gc: Color = g.get("color", Color.WHITE)
		var bob := sin(Time.get_ticks_msec() * 0.008) * 4.0
		draw_circle(gp + Vector2(0.0, bob), GEM_RADIUS, gc)
		if is_active:
			draw_arc(gp + Vector2(0.0, bob), GEM_RADIUS + 6.0, 0.0, TAU, 20, Color(0.8, 1.0, 1.0, 0.7), 2.0)

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
		draw_circle(rel, 14.0, Color(0.5, 0.9, 1.0, 0.95))

	# Progress.
	var taken := 0
	for g in _gems:
		if bool(g.get("taken", false)):
			taken += 1
	draw_string(ThemeDB.fallback_font, Vector2(-50.0, -RING_RADIUS - 40.0),
		"Gems %d/%d" % [taken, _gems.size()], HORIZONTAL_ALIGNMENT_CENTER, 100, 13, Color(0.7, 0.9, 1.0, 0.8))

	# Comment text.
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 2.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-100.0, 40.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 15,
			Color(0.8, 1.0, 0.5, alpha))

func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	_comment_text = ""
	_comment_timer = 0.0
	if owner_player != null and is_instance_valid(owner_player):
		var crowd_bonus := _creeps.size() * 5
		owner_player.add_gold(REWARD_GOLD + int(score * 0.2) + crowd_bonus)
		owner_player.add_xp(REWARD_XP + crowd_bonus)


extends "res://scripts/minigame_base.gd"
## CREEP TAG (mountain): chase and tag wandering creeps to "catch" them.
##
## Creeps wander the arena. You're "it" — touching a creep tags it (turns
## friendly, it then helps you tag others by running ahead). Tag 8 creeps to win.
## More creeps spawn as you tag. 50s.
##
## Bot: chase the nearest untagged creep.

const TAG_DURATION := 50.0
const ARENA_RADIUS := 200.0
const CREEP_RADIUS := 14.0
const TAG_RADIUS := 28.0
const TARGET_TAGS := 8
const CREEP_SPEED := 60.0

var _creeps: Array[Dictionary] = []
var _tags := 0
var _total_tagged := 0
var _comment_text := ""
var _comment_timer := 0.0


func _reset() -> void:
	timer = TAG_DURATION
	_creeps.clear()
	_tags = 0
	_total_tagged = 0
	score = 0
	_spawn_wave(5)


func _spawn_wave(count: int) -> void:
	for i in count:
		var a := randf() * TAU
		var r := randf_range(30.0, ARENA_RADIUS - 20.0)
		_creeps.append({
			"pos": Vector2.from_angle(a) * r,
			"vel": Vector2.from_angle(randf() * TAU) * CREEP_SPEED,
			"tagged": false,
			"color": Color(randf_range(0.4, 0.9), randf_range(0.3, 0.7), randf_range(0.3, 0.7)),
			"wander_timer": 0.0,
		})


func _update_delta(delta: float) -> void:
	# Creeps wander (change direction periodically), tagged creeps move faster.
	for c in _creeps:
		c["wander_timer"] = float(c.get("wander_timer", 0.0)) - delta
		if float(c.get("wander_timer", 0.0)) <= 0.0:
			c["wander_timer"] = randf_range(1.5, 3.5)
			var spd := CREEP_SPEED * 1.6 if bool(c.get("tagged", false)) else CREEP_SPEED
			c["vel"] = Vector2.from_angle(randf() * TAU) * spd

		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var v: Vector2 = c.get("vel", Vector2.ZERO)
		var np := cp + v * delta
		if np.length() > ARENA_RADIUS:
			np = np.normalized() * ARENA_RADIUS
			var n := np.normalized()
			var dot := v.dot(n)
			c["vel"] = (v - 2.0 * dot * n) * 0.8
		c["pos"] = np

	# Tag check: player touches untagged creep.
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		for c in _creeps:
			if bool(c.get("tagged", false)):
				continue
			var cp: Vector2 = c.get("pos", Vector2.ZERO)
			if cp.distance_to(rel) < TAG_RADIUS:
				c["tagged"] = true
				_tags += 1
				_total_tagged += 1
				score += 25
				# Spawn a small group of new creeps to keep the game going.
				if _creeps.size() < 14:
					_spawn_wave(randi_range(2, 3))
				if _total_tagged >= 3 and _total_tagged % 3 == 0:
					_comment_text = "Nice tagging! %d caught!" % _total_tagged
					_comment_timer = 2.0
				if _total_tagged >= TARGET_TAGS:
					_comment_text = "You're a master tagger!"
					_comment_timer = 3.0

	queue_redraw()


func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	# Chase nearest untagged creep.
	var best: Vector2 = Vector2.ZERO
	var best_d := 999999.0
	for c in _creeps:
		if bool(c.get("tagged", false)):
			continue
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var d := rel.distance_to(cp)
		if d < best_d:
			best_d = d
			best = cp
	if best_d > 99999.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var to := best - rel
	if to.length() < 5.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": to.normalized(), "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	pass


func _draw_body() -> void:
	# Mountain floor (rocky, grey-blue)
	draw_circle(Vector2.ZERO, ARENA_RADIUS + 20.0, Color(0.2, 0.22, 0.28, 0.55))
	draw_arc(Vector2.ZERO, ARENA_RADIUS, 0.0, TAU, 48, Color(0.5, 0.5, 0.6, 0.4), 3.0)

	# Creeps
	for c in _creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var tagged: bool = c.get("tagged", false)
		if tagged:
			cc = Color(0.3, 1.0, 0.5, 0.9)
		draw_circle(cp, CREEP_RADIUS, cc)
		# Eyes
		var eye_off := (c.get("vel") as Vector2).normalized() * 4.0
		draw_circle(cp + eye_off + Vector2(-3, -4), 2.5, Color(0.1, 0.1, 0.1))
		draw_circle(cp + eye_off + Vector2(3, -4), 2.5, Color(0.1, 0.1, 0.1))
		if tagged:
			draw_string(ThemeDB.fallback_font, cp + Vector2(-12, -22), "x",
				HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color(0.3, 1.0, 0.5, 0.9))

	# Player marker
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		draw_circle(rel, 15.0, Color(1.0, 0.6, 0.2, 0.95))
		draw_string(ThemeDB.fallback_font, rel + Vector2(-14, -28), "IT!",
			HORIZONTAL_ALIGNMENT_CENTER, 28, 13, Color(1.0, 0.6, 0.2, 0.9))

	# Tag count
	draw_string(ThemeDB.fallback_font, Vector2(-40.0, -ARENA_RADIUS - 24.0),
		"Tagged: %d / %d" % [_total_tagged, TARGET_TAGS],
		HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color(0.5, 1.0, 0.6, 0.9))


func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		var tag_bonus := _total_tagged * 12
		owner_player.add_gold(REWARD_GOLD + tag_bonus)
		owner_player.add_xp(REWARD_XP + tag_bonus)
	AudioService.play("minigame_win")
	_emit_finished()

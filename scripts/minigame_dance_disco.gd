extends "res://scripts/minigame_base.gd"

## Dance Disco — standalone minigame that tests all movement-based mechanics.
## A dancing bot moves in patterns; the player must mirror its position
## relative to the floor center. Accuracy scores over time. Creep groups
## join the floor progressively as the player dances well.
##
## DURATION: 60s. Bigger crowd at end = bigger reward.
## Bot path: bot_tick returns the direction to mirror the dancing bot.

const DANCE_DURATION := 60.0
const FLOOR_RADIUS := 160.0  # disco floor radius
const DANCE_BOT_RADIUS := 100.0  # how far the bot orbits/dances from center
const ACCURACY_RADIUS := 50.0  # how close player must be to bot's spot
const GROUP_JOIN_TIMES: Array[float] = [12.0, 24.0, 36.0, 48.0]  # when each creep group joins
const GROUP_SIZES: Array[int] = [2, 3, 4, 5]  # how many creeps per group

# Dance pattern phases: 0=circle, 1=figure-8, 2=zigzag, 3=spin
var _dance_phase := 0
var _dance_phase_timer := 0.0
var _dance_phase_duration := 10.0  # seconds per phase

# Bot position (relative to floor center)
var _bot_pos := Vector2.ZERO

# Accuracy tracking
var _accuracy_sum := 0.0
var _accuracy_count := 0
var _current_accuracy := 0.0  # 0.0 to 1.0

# Creep groups
var _joined_creeps: Array[Dictionary] = []  # {"pos": Vector2, "color": Color}
var _group_index := 0
var _comment_text := ""
var _comment_timer := 0.0

# Disco ball
var _discoball_angle := 0.0


func _reset() -> void:
	timer = DANCE_DURATION
	_dance_phase = 0
	_dance_phase_timer = 0.0
	_bot_pos = Vector2.ZERO
	_accuracy_sum = 0.0
	_accuracy_count = 0
	_current_accuracy = 0.0
	_joined_creeps.clear()
	_group_index = 0
	_comment_text = ""
	_comment_timer = 0.0
	_discoball_angle = 0.0
	# Start with a small group already on the floor
	_spawn_crewp_group(0)


func _update_delta(delta: float) -> void:
	if not active:
		return

	_discoball_angle += delta * 2.5
	_comment_timer = maxf(0.0, _comment_timer - delta)

	# Advance dance phase
	_dance_phase_timer += delta
	if _dance_phase_timer >= _dance_phase_duration:
		_dance_phase_timer = 0.0
		_dance_phase = (_dance_phase + 1) % 4

	# Compute bot position from dance pattern
	_bot_pos = _compute_bot_position()

	# Accuracy: compare player position (relative to center) vs bot position
	if owner_player != null and is_instance_valid(owner_player):
		var player_rel := owner_player.global_position - global_position
		var dist_to_bot := player_rel.distance_to(_bot_pos)
		# Accuracy: 1.0 when player is within ACCURACY_RADIUS of bot, 0.0 at 2x
		var acc := clampf(1.0 - (dist_to_bot - ACCURACY_RADIUS) / ACCURACY_RADIUS, 0.0, 1.0)
		_accuracy_sum += acc
		_accuracy_count += 1
		_current_accuracy = _accuracy_sum / maxf(1.0, float(_accuracy_count))

		# Score: accumulate accuracy
		score = int(_accuracy_sum / float(maxf(1, _accuracy_count)) * 100.0)

		# Check for creep group joins
		_check_group_joins()

	queue_redraw()


func _compute_bot_position() -> Vector2:
	var t := _dance_phase_timer
	match _dance_phase:
		0:  # Circle
			return Vector2.from_angle(t * 1.8) * DANCE_BOT_RADIUS
		1:  # Figure-8 (lemniscate)
			var a := t * 1.5
			return Vector2(sin(a), sin(a) * cos(a)) * DANCE_BOT_RADIUS
		2:  # Zigzag (square path)
			var phase := fmod(t * 1.2, 4.0)
			var side := int(phase)
			var frac := fmod(phase, 1.0)
			match side:
				0: return Vector2(frac * 2.0 - 1.0, -1.0) * DANCE_BOT_RADIUS
				1: return Vector2(1.0, frac * 2.0 - 1.0) * DANCE_BOT_RADIUS
				2: return Vector2(1.0 - frac * 2.0, 1.0) * DANCE_BOT_RADIUS
				_: return Vector2(-1.0, 1.0 - frac * 2.0) * DANCE_BOT_RADIUS
		_:  # Spin (fast circle)
			return Vector2.from_angle(t * 3.0) * DANCE_BOT_RADIUS * 0.7


func _spawn_crewp_group(group_idx: int) -> void:
	var count := GROUP_SIZES[group_idx] if group_idx < GROUP_SIZES.size() else 2
	for i in count:
		var angle := _discoball_angle + TAU * float(i) / float(count) + randf_range(0.0, 0.5)
		var dist := randf_range(30.0, FLOOR_RADIUS * 0.7)
		var p := Vector2.from_angle(angle) * dist
		var col := Color(randf_range(0.3, 1.0), randf_range(0.3, 1.0), randf_range(0.3, 1.0), 1.0)
		_joined_creeps.append({"pos": p, "color": col})


func _check_group_joins() -> void:
	if _group_index >= GROUP_JOIN_TIMES.size():
		return
	var elapsed := DANCE_DURATION - timer
	if elapsed >= GROUP_JOIN_TIMES[_group_index]:
		# Only join if accuracy is decent (above 40% at that point)
		if _current_accuracy > 0.35:
			_spawn_crewp_group(_group_index)
			_set_comment(_get_join_comment(_group_index))
			_group_index += 1
		else:
			# Missed the window; skip this group
			_set_comment("Too slow! The group skipped away...")
			_group_index += 1


func _set_comment(txt: String) -> void:
	_comment_text = txt
	_comment_timer = 3.0


func _get_join_comment(idx: int) -> String:
	match idx:
		0: return "Nice! A pair of creeps join the floor!"
		1: return "Great sync! More dancers arrive!"
		2: return "You're a natural! The crowd grows!"
		_: return "The whole crew is dancing with you!"
	return ""


func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Bot mirrors the dancing bot's position.
	var player_rel := owner_player.global_position - global_position
	var to_bot := _bot_pos - player_rel
	if to_bot.length() < 5.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": to_bot.normalized(), "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	# Movement-based; no special input events needed.
	pass


func _draw_body() -> void:
	# Disco floor: concentric rings + rotating colored tiles
	var floor_col := Color(0.15, 0.12, 0.25, 0.6)
	draw_circle(Vector2.ZERO, FLOOR_RADIUS, floor_col)

	# Rotating grid lines
	var lines := 8
	for i in lines:
		var a1 := _discoball_angle + TAU * float(i) / float(lines)
		var p1 := Vector2.from_angle(a1) * (FLOOR_RADIUS - 10.0)
		var p2 := Vector2.from_angle(a1 + TAU / float(lines)) * (FLOOR_RADIUS - 10.0)
		# Draw a tile edge
		draw_line(Vector2.from_angle(a1) * 40.0, p1, Color(0.4, 0.3, 0.8, 0.3), 2.0)
		draw_line(Vector2.from_angle(a1 + 0.4) * 40.0, Vector2.from_angle(a1 + 0.4) * (FLOOR_RADIUS - 10.0),
			Color(0.8, 0.3, 0.6, 0.2), 2.0)

	# Floor border
	draw_arc(Vector2.ZERO, FLOOR_RADIUS, 0.0, TAU, 48, Color(0.6, 0.4, 1.0, 0.5), 3.0)

	# Disco ball: a shiny circle above the floor (drawn at a fixed "hanging" spot)
	var ball_pos := Vector2(0.0, -FLOOR_RADIUS - 40.0)
	var ball_radius := 22.0
	# Ball body
	var ball_grad := 0.5 + 0.5 * sin(_discoball_angle * 2.0)
	draw_circle(ball_pos, ball_radius, Color(0.7 + 0.3 * ball_grad, 0.7 + 0.3 * ball_grad, 0.9, 0.95))
	# Ball sparkle facets
	for i in 6:
		var fa := _discoball_angle + TAU * float(i) / 6.0
		var fp := ball_pos + Vector2.from_angle(fa) * ball_radius * 0.6
		draw_circle(fp, 3.0, Color(1.0, 1.0, 1.0, 0.7 + 0.3 * sin(_discoball_angle + float(i))))
	# String
	draw_line(ball_pos + Vector2(0.0, -ball_radius), Vector2(0.0, -FLOOR_RADIUS - 120.0),
		Color(0.8, 0.8, 0.8, 0.5), 2.0)
	# Light rays from ball
	for i in 4:
		var ra := _discoball_angle + TAU * float(i) / 4.0
		var r_start := ball_pos + Vector2.from_angle(ra) * ball_radius
		var r_end := ball_pos + Vector2.from_angle(ra) * (FLOOR_RADIUS + 60.0)
		draw_line(r_start, r_end, Color(1.0, 0.9, 0.5, 0.15), 1.5)

	# Dancing bot (the one to mimic)
	var bot_color := Color(0.3, 0.9, 0.5, 0.95)
	draw_circle(_bot_pos, 18.0, bot_color)
	# Bot direction indicator
	var bot_dir := Vector2.from_angle(_discoball_angle)
	draw_circle(_bot_pos + bot_dir * 12.0, 6.0, Color(1.0, 1.0, 0.5, 0.9))
	# Bot label
	draw_string(ThemeDB.fallback_font, Vector2(_bot_pos.x - 30.0, _bot_pos.y - 28.0),
		"DANCE!", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 1.0, 0.5, 0.8))

	# Joined creeps (the crowd)
	for c in _joined_creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		# Bounce animation
		var bounce := sin(Time.get_ticks_msec() * 0.008 + cp.x * 0.01) * 4.0
		draw_circle(cp + Vector2(0.0, bounce), 12.0, cc)
		draw_circle(cp + Vector2(0.0, bounce) + Vector2(0.0, -6.0), 5.0, Color(1.0, 1.0, 1.0, 0.6))

	# Player marker
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		if rel.length() < FLOOR_RADIUS * 1.3:
			draw_circle(rel, 14.0, Color(0.4, 0.8, 1.0, 0.95))
			# Accuracy ring around player
			var acc_col := Color(0.3, 1.0, 0.3, 0.7) if _current_accuracy > 0.7 else (
				Color(1.0, 0.9, 0.3, 0.7) if _current_accuracy > 0.4 else Color(1.0, 0.3, 0.3, 0.7))
			draw_arc(rel, 20.0, 0.0, TAU * _current_accuracy, 24, acc_col, 2.5)

	# Accuracy display
	var acc_pct := int(_current_accuracy * 100.0)
	draw_string(ThemeDB.fallback_font, Vector2(-80.0, FLOOR_RADIUS + 20.0),
		"Sync: %d%%  |  Crowd: %d" % [acc_pct, _joined_creeps.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(0.9, 0.9, 0.9, 0.9))

	# Dance phase name
	var phase_names := ["CIRCLE", "FIGURE-8", "ZIGZAG", "SPIN"]
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, FLOOR_RADIUS + 40.0),
		"Style: " + phase_names[_dance_phase],
		HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.6, 0.6, 0.9, 0.7))

	# Comment from the dance bot
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 3.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-120.0, -FLOOR_RADIUS - 60.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 240, 16,
			Color(1.0, 0.95, 0.6, alpha))


## Override reward: bigger crowd = bigger reward.
func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	var crowd_bonus := _joined_creeps.size() * 10  # +10 gold per creep
	var acc_bonus := int(_current_accuracy * 20.0)  # up to +20 for high accuracy
	if owner_player != null and is_instance_valid(owner_player):
		owner_player.add_gold(REWARD_GOLD + crowd_bonus + acc_bonus)
		owner_player.add_xp(REWARD_XP + crowd_bonus)
	AudioService.play("minigame_win")
	_vfx_burst(Color(0.6, 0.4, 1.0), 20.0, 200.0)
	_emit_finished()

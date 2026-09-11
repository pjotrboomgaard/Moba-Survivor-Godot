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
	# Disco floor: a pixel-art checkerboard of chunky square tiles (T3.4 — minigames
	# use pixel art only). Each tile is 40u; tiles are clipped to the floor radius.
	var floor_col := Color(0.13, 0.10, 0.24, 0.85)
	var r_sq := FLOOR_RADIUS * FLOOR_RADIUS
	var tile := 40.0
	var grid_color_a := Color(0.28, 0.20, 0.45, 0.9)
	var grid_color_b := Color(0.18, 0.14, 0.34, 0.9)
	var tiles := int(FLOOR_RADIUS * 2.0 / tile)
	for gx in range(tiles + 1):
		for gy in range(tiles + 1):
			var c := Vector2((gx - tiles * 0.5) * tile, (gy - tiles * 0.5) * tile)
			if c.length_squared() > r_sq:
				continue
			var checker := (gx + gy) % 2
			var col := grid_color_a if checker == 0 else grid_color_b
			# A subtle "light" pulse that travels with the disco ball.
			var pulse := 0.5 + 0.5 * sin(_discoball_angle * 2.0 + (gx + gy) * 0.5)
			col = col.lerp(Color(0.55, 0.4, 0.95, 0.9), pulse * 0.25)
			draw_rect(Rect2(c - Vector2(tile * 0.48, tile * 0.48), Vector2(tile * 0.96, tile * 0.96)), col)

	# Pixel-art floor border: a thick square ring clipped to the circle.
	draw_arc(Vector2.ZERO, FLOOR_RADIUS, 0.0, TAU, 32, Color(0.7, 0.5, 1.0, 0.9), 5.0)

	# Disco ball: a faceted pixel cube (not a smooth circle) with a spinning
	# 4x4 grid of shiny squares, hung from a string, with light beams.
	var ball_pos := Vector2(0.0, -FLOOR_RADIUS - 40.0)
	var ball_half := 22.0
	# Ball body: a slightly rounded square.
	var ball_grad := 0.5 + 0.5 * sin(_discoball_angle * 2.0)
	draw_rect(
		Rect2(ball_pos - Vector2(ball_half, ball_half), Vector2(ball_half * 2, ball_half * 2)),
		Color(0.6 + 0.3 * ball_grad, 0.6 + 0.3 * ball_grad, 0.85, 0.95)
	)
	# Faceted pixel squares (4x4 grid), brightness driven by spin angle.
	var facet := ball_half * 0.5
	for fx in 4:
		for fy in 4:
			var fp := ball_pos + Vector2(fx - 1.5, fy - 1.5) * facet
			var spin := 0.5 + 0.5 * sin(_discoball_angle * 3.0 + (fx * 1.3 + fy * 0.9))
			var fc := Color(0.85 + 0.15 * spin, 0.85 + 0.15 * spin, 1.0, 0.9)
			draw_rect(Rect2(fp - Vector2(facet * 0.42, facet * 0.42), Vector2(facet * 0.84, facet * 0.84)), fc)
	# String (pixel column)
	for sy in 8:
		var sp := ball_pos + Vector2(0.0, -ball_half - 4.0 - sy * 4.0)
		draw_rect(Rect2(sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(0.85, 0.85, 0.9, 0.5))
	# Light beams from the ball: chunky pixel rays.
	for i in 6:
		var ra := _discoball_angle + TAU * float(i) / 6.0
		var beam := Vector2.from_angle(ra)
		var r_start := ball_pos + beam * (ball_half + 4.0)
		var r_end := ball_pos + beam * (FLOOR_RADIUS + 40.0)
		# Draw as a thick short column so it reads pixel-art, not a hairline.
		for seg in 5:
			var t0 := float(seg) / 5.0
			var t1 := float(seg + 1) / 5.0
			var p0 := r_start.lerp(r_end, t0)
			var p1 := r_start.lerp(r_end, t1)
			var a01 := p1 - p0
			if a01.length_squared() <= 0.0:
				continue
			var nrm := a01.normalized().orthogonal()
			draw_rect(Rect2(p0 - nrm * 2.0, Vector2(a01.length() + 4.0, 4.0)), Color(1.0, 0.95, 0.5, 0.18))

	# Dancing bot (the one to mimic) — pixel-art blocky bot with a head + body.
	var bot_color := Color(0.3, 0.9, 0.5, 0.95)
	var bot_bounce := sin(Time.get_ticks_msec() * 0.008) * 3.0
	# Body (square torso)
	draw_rect(Rect2(_bot_pos + Vector2(-12, -6 + bot_bounce), Vector2(24, 22)), bot_color)
	# Head (smaller square on top)
	draw_rect(Rect2(_bot_pos + Vector2(-8, -22 + bot_bounce), Vector2(16, 16)), bot_color.lightened(0.15))
	# Eyes (two dark pixels)
	draw_rect(Rect2(_bot_pos + Vector2(-6, -17 + bot_bounce), Vector2(4, 4)), Color(0.1, 0.1, 0.15))
	draw_rect(Rect2(_bot_pos + Vector2(2, -17 + bot_bounce), Vector2(4, 4)), Color(0.1, 0.1, 0.15))
	# Direction indicator (arrow pixel)
	var bot_dir := Vector2.from_angle(_discoball_angle)
	draw_rect(Rect2(_bot_pos + bot_dir * 20.0 + bot_bounce * Vector2(0,1) - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 1.0, 0.5, 0.9))
	# Bot label
	draw_string(ThemeDB.fallback_font, Vector2(_bot_pos.x - 30.0, _bot_pos.y - 30.0),
		"DANCE!", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 1.0, 0.5, 0.8))

	# Joined creeps (the crowd) — pixel-art blocky creeps with a head + body.
	for c in _joined_creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		# Bounce animation
		var bounce := sin(Time.get_ticks_msec() * 0.008 + cp.x * 0.01) * 4.0
		# Body
		draw_rect(Rect2(cp + Vector2(-10, -4 + bounce), Vector2(20, 18)), cc)
		# Head
		draw_rect(Rect2(cp + Vector2(-7, -16 + bounce), Vector2(14, 14)), cc.lightened(0.2))
		# Eyes
		draw_rect(Rect2(cp + Vector2(-4, -11 + bounce), Vector2(3, 3)), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(cp + Vector2(2, -11 + bounce), Vector2(3, 3)), Color(0.1, 0.1, 0.15))

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

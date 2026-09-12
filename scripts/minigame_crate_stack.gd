extends "res://scripts/minigame_base.gd"

## Crate Stack — forest-themed timing/positioning minigame.
## Crates drop from above; the player must move under each falling crate to
## "catch" it and stack it. Each catch adds to the stack height and score.
## Forest critters (squirrels, owls) join as stackers when the player catches well.
##
## DURATION: 45s. Taller stack = bigger reward.

const STACK_DURATION := 45.0
const ARENA_RADIUS := 200.0
const CATCH_RADIUS := 34.0
const JOIN_THRESHOLDS: Array[int] = [4, 8, 14, 22]
const GROUP_SIZES: Array[int] = [2, 2, 3, 4]

var _crates: Array[Dictionary] = []
var _helpers: Array[Dictionary] = []
var _join_index := 0
var _stack_height := 0
var _spawn_timer := 0.0
var _spawn_interval := 1.4
var _stack_flash := 0.0
var _leaf_time := 0.0
var _comment_text := ""
var _comment_timer := 0.0


func _reset() -> void:
	timer = STACK_DURATION
	_crates.clear()
	_helpers.clear()
	_join_index = 0
	_stack_height = 0
	_spawn_timer = 0.0
	_spawn_interval = 1.4
	_stack_flash = 0.0
	_leaf_time = 0.0
	_comment_text = ""
	_comment_timer = 0.0
	_spawn_crate()


func _update_delta(delta: float) -> void:
	if not active:
		return
	_leaf_time += delta
	_stack_flash = maxf(0.0, _stack_flash - delta * 2.5)
	_comment_timer = maxf(0.0, _comment_timer - delta)

	# Spawn crates
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		_spawn_crate()
		_spawn_interval = maxf(0.7, _spawn_interval - 0.02)

	# Update crates falling
	for i in _crates.size():
		var c := _crates[i]
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		var vel: Vector2 = c.get("vel", Vector2(0, 120))
		pos.y += vel.y * delta
		_crates[i] = {"pos": pos, "vel": vel, "alive": true}

	# Catch check
	if owner_player != null and is_instance_valid(owner_player):
		var player_pos := owner_player.global_position - global_position
		for i in _crates.size():
			var c := _crates[i]
			var pos: Vector2 = c.get("pos", Vector2.ZERO)
			if player_pos.distance_to(pos) <= CATCH_RADIUS:
				_stack_height += 1
				score += 15 + _stack_height * 2
				_stack_flash = 1.0
				_vfx_burst(Color(0.5, 0.8, 0.4), 130.0, 0.4)
				_crates.erase(c)
				break

	# Remove crates that fell off
	var remaining: Array[Dictionary] = []
	for c in _crates:
		var p: Vector2 = c.get("pos", Vector2.ZERO)
		if p.y < ARENA_RADIUS + 40.0:
			remaining.append(c)
	_crates = remaining

	# Check helper joins
	_check_helper_joins()
	queue_redraw()


func _spawn_crate() -> void:
	var x := randf_range(-ARENA_RADIUS * 0.7, ARENA_RADIUS * 0.7)
	var y := -ARENA_RADIUS - 20.0
	var speed := randf_range(100.0, 170.0)
	_crates.append({
		"pos": Vector2(x, y),
		"vel": Vector2(0.0, speed),
		"alive": true,
	})


func _check_helper_joins() -> void:
	if _join_index >= JOIN_THRESHOLDS.size():
		return
	if score >= JOIN_THRESHOLDS[_join_index]:
		_spawn_helper_group(_join_index)
		_set_comment(_get_join_comment(_join_index))
		_join_index += 1


func _spawn_helper_group(idx: int) -> void:
	var count := GROUP_SIZES[idx] if idx < GROUP_SIZES.size() else 2
	for i in count:
		var angle := TAU * randf()
		var dist := randf_range(40.0, ARENA_RADIUS * 0.75)
		var p := Vector2.from_angle(angle) * dist
		var col := Color(randf_range(0.4, 0.7), randf_range(0.3, 0.6), 0.2, 1.0)
		_helpers.append({"pos": p, "color": col})


func _set_comment(txt: String) -> void:
	_comment_text = txt
	_comment_timer = 3.0


func _get_join_comment(idx: int) -> String:
	match idx:
		0: return "Squirrels are stacking with you!"
		1: return "An owl landed to assist!"
		2: return "The forest crew is growing!"
		_: return "The whole grove is stacking!"
	return ""


func bot_tick(_delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var player_rel := owner_player.global_position - global_position
	var nearest := Vector2.ZERO
	var min_dist := 99999.0
	for c in _crates:
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		var d := Vector2(pos.x, pos.y).distance_to(player_rel)
		if d < min_dist:
			min_dist = d
			nearest = pos
	if min_dist > CATCH_RADIUS * 0.4:
		return {"move": (nearest - player_rel).normalized(), "attack": false, "interact": false}
	return {"move": Vector2.ZERO, "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	super.on_input_event(event)


func _draw_body() -> void:
	# Falling leaf particles — small pixel squares.
	for i in 10:
		var lx := fmod(sin(_leaf_time * 0.4 + float(i) * 1.9) * 120.0, ARENA_RADIUS)
		var ly := fmod(_leaf_time * 30.0 + float(i) * 50.0, ARENA_RADIUS * 2.0) - ARENA_RADIUS
		var la := 0.25 * (1.0 - absf(ly) / ARENA_RADIUS)
		draw_rect(Rect2(Vector2(lx - 2.5, ly - 2.5), Vector2(5.0, 5.0)), Color(0.5, 0.8, 0.3, la))

	# Crates — chunky crate (body + border + pixel X-brace via two thin diagonal blocks).
	for c in _crates:
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		# Crate body.
		draw_rect(Rect2(pos.x - 12.0, pos.y - 12.0, 24.0, 24.0), Color(0.6, 0.45, 0.25, 0.95))
		# Border (4 side bars).
		var bcol := Color(0.4, 0.3, 0.15, 0.9)
		draw_rect(Rect2(pos.x - 12.0, pos.y - 12.0, 24.0, 3.0), bcol)
		draw_rect(Rect2(pos.x - 12.0, pos.y + 9.0, 24.0, 3.0), bcol)
		draw_rect(Rect2(pos.x - 12.0, pos.y - 9.0, 3.0, 18.0), bcol)
		draw_rect(Rect2(pos.x + 9.0, pos.y - 9.0, 3.0, 18.0), bcol)
		# X-brace: two short diagonal pixel blocks.
		var xcol := Color(0.35, 0.25, 0.12, 0.8)
		for d in 4:
			var off := d * 3.5 - 7.0
			draw_rect(Rect2(pos.x + off - 2.0, pos.y + off - 2.0, 4.0, 4.0), xcol)
			draw_rect(Rect2(pos.x - off - 2.0, pos.y + off - 2.0, 4.0, 4.0), xcol)

	# Stack indicator at center
	if _stack_height > 0:
		for s in _stack_height:
			var sy := 20.0 + s * 10.0
			draw_rect(Rect2(-10.0, sy, 20.0, 8.0), Color(0.55, 0.4, 0.2, 0.7))

	# Helper critters — chunky body + head.
	for h in _helpers:
		var hp: Vector2 = h.get("pos", Vector2.ZERO)
		var hc: Color = h.get("color", Color.WHITE)
		var hop := sin(_leaf_time * 4.0 + hp.x * 0.05) * 4.0
		var hb := hp + Vector2(0.0, hop)
		draw_rect(Rect2(hb + Vector2(-7.0, -3.0), Vector2(14.0, 14.0)), hc)
		draw_rect(Rect2(hb + Vector2(-5.0, -12.0), Vector2(10.0, 9.0)), hc.lightened(0.15))
		draw_rect(Rect2(hb + Vector2(-3.5, -8.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(hb + Vector2(1.0, -8.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))

	# Stack flash — chunky square frame.
	if _stack_flash > 0.0:
		var fs := 50.0
		var col := Color(0.5, 1.0, 0.4, _stack_flash * 0.4)
		draw_rect(Rect2(Vector2(-fs, -fs), Vector2(fs * 2.0, 4.0)), col)
		draw_rect(Rect2(Vector2(-fs, fs - 4.0), Vector2(fs * 2.0, 4.0)), col)
		draw_rect(Rect2(Vector2(-fs, -fs + 4.0), Vector2(4.0, fs * 2.0 - 8.0)), col)
		draw_rect(Rect2(Vector2(fs - 4.0, -fs + 4.0), Vector2(4.0, fs * 2.0 - 8.0)), col)

	# Comment
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 3.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-140.0, -ARENA_RADIUS - 20.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 280, 16,
			Color(0.6, 1.0, 0.5, alpha))

	# Stats
	draw_string(ThemeDB.fallback_font, Vector2(-100.0, ARENA_RADIUS + 20.0),
		"Stack: %d  |  Crew: %d" % [_stack_height, _helpers.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color(0.8, 0.9, 0.6, 0.85))

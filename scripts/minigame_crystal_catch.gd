extends "res://scripts/minigame_base.gd"

## Crystal Catch — mountain-themed falling-catch minigame.
## Crystal shards fall from the top of the arena; the player must move under
## them to catch them before they hit the ground. Each catch scores points.
## Mountain creatures (rock golems, eagles) join as helpers when the player
## catches well.
##
## DURATION: 45s. Bigger helper crew = bigger reward.

const CRYSTAL_DURATION := 45.0
const ARENA_RADIUS := 200.0
const CATCH_RADIUS := 30.0
const CRYSTAL_FALL_SPEED_MIN := 80.0
const CRYSTAL_FALL_SPEED_MAX := 160.0
const JOIN_THRESHOLDS: Array[int] = [5, 10, 18, 28]
const GROUP_SIZES: Array[int] = [2, 3, 4, 5]

var _crystals: Array[Dictionary] = []
var _helpers: Array[Dictionary] = []
var _join_index := 0
var _spawn_timer := 0.0
var _spawn_interval := 1.2
var _catch_flash := 0.0
var _snow_time := 0.0
var _comment_text := ""
var _comment_timer := 0.0


func _reset() -> void:
	timer = CRYSTAL_DURATION
	_crystals.clear()
	_helpers.clear()
	_join_index = 0
	_spawn_timer = 0.0
	_spawn_interval = 1.2
	_catch_flash = 0.0
	_snow_time = 0.0
	_comment_text = ""
	_comment_timer = 0.0


func _update_delta(delta: float) -> void:
	if not active:
		return
	_snow_time += delta
	_catch_flash = maxf(0.0, _catch_flash - delta * 2.5)
	_comment_timer = maxf(0.0, _comment_timer - delta)

	# Spawn crystals
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		_spawn_crystal()
		_spawn_interval = maxf(0.5, _spawn_interval - 0.03)

	# Update crystals
	for i in _crystals.size():
		var c := _crystals[i]
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		var vel: Vector2 = c.get("vel", Vector2(0, 100))
		pos.y += vel.y * delta
		pos.x += vel.x * delta
		_crystals[i] = {"pos": pos, "vel": vel, "type": c.get("type", 0), "alive": true}
		# Despawn only when a crystal has fallen well BELOW the arena (positive
		# y beyond the floor), not when it is high above the arena at spawn.
		if pos.y > ARENA_RADIUS + 40.0:
			_crystals[i]["alive"] = false

	var new_crystals: Array[Dictionary] = []
	for c in _crystals:
		if c.get("alive", false):
			new_crystals.append(c)
	_crystals = new_crystals
	_check_catches()
	_check_helper_joins()
	queue_redraw()


func _spawn_crystal() -> void:
	var x := randf_range(-ARENA_RADIUS * 0.8, ARENA_RADIUS * 0.8)
	var y := -ARENA_RADIUS - 30.0
	var speed := randf_range(CRYSTAL_FALL_SPEED_MIN, CRYSTAL_FALL_SPEED_MAX)
	var drift := randf_range(-20.0, 20.0)
	var c_type := randi() % 3
	_crystals.append({
		"pos": Vector2(x, y),
		"vel": Vector2(drift, speed),
		"type": c_type,
		"alive": true,
	})


func _check_catches() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var player_pos := owner_player.global_position - global_position
	for i in _crystals.size():
		var c := _crystals[i]
		if not c.get("alive", false):
			continue
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		if player_pos.distance_to(pos) <= CATCH_RADIUS:
			var c_type: int = c.get("type", 0)
			var points := 10 + int(c_type) * 5
			score += points
			_catch_flash = 1.0
			var flash_colors: Array[Color] = [Color(0.4, 0.7, 1.0), Color(0.4, 1.0, 0.5), Color(0.8, 0.4, 1.0)]
			_vfx_burst(flash_colors[c_type], 120.0, 0.35)
			_crystals[i]["alive"] = false
			break


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
		var dist := randf_range(50.0, ARENA_RADIUS * 0.7)
		var p := Vector2.from_angle(angle) * dist
		var col := Color(0.7, 0.7, 0.8, 1.0) if idx % 2 == 0 else Color(0.5, 0.7, 0.9, 1.0)
		_helpers.append({"pos": p, "color": col})


func _set_comment(txt: String) -> void:
	_comment_text = txt
	_comment_timer = 3.0


func _get_join_comment(idx: int) -> String:
	match idx:
		0: return "A rock golem joins the catch!"
		1: return "Eagles swoop down to help!"
		2: return "The mountain crew grows!"
		_: return "The whole peak is catching crystals!"
	return ""


func bot_tick(_delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var player_rel := owner_player.global_position - global_position
	var nearest := Vector2.ZERO
	var min_dist := 99999.0
	for c in _crystals:
		if not c.get("alive", false):
			continue
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		# Only target crystals that are actually within the arena (not far above).
		if pos.length() > ARENA_RADIUS:
			continue
		var priority := pos.y / 100.0
		var d := player_rel.distance_to(pos) - priority
		if d < min_dist:
			min_dist = d
			nearest = pos
	if min_dist > CATCH_RADIUS * 0.5:
		return {"move": (nearest - player_rel).normalized(), "attack": false, "interact": false}
	return {"move": Vector2.ZERO, "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	super.on_input_event(event)


func _draw_body() -> void:
	# Snow particles — small pixel squares.
	for i in 8:
		var sx := fmod(sin(_snow_time * 0.5 + float(i) * 1.7) * 100.0, ARENA_RADIUS)
		var sy := fmod(_snow_time * 20.0 + float(i) * 60.0, ARENA_RADIUS * 2.0) - ARENA_RADIUS
		var snow_alpha := 0.3 * (1.0 - absf(sy) / ARENA_RADIUS)
		draw_rect(Rect2(Vector2(sx - 2.0, sy - 2.0), Vector2(4.0, 4.0)), Color(1.0, 1.0, 1.0, snow_alpha))

	# Crystals — chunky diamond made of 4 stacked rects (diamond silhouette).
	for c in _crystals:
		if not c.get("alive", false):
			continue
		var pos: Vector2 = c.get("pos", Vector2.ZERO)
		var c_type: int = c.get("type", 0)
		var crystal_colors: Array[Color] = [
			Color(0.4, 0.7, 1.0, 0.95),
			Color(0.4, 1.0, 0.5, 0.95),
			Color(0.8, 0.4, 1.0, 0.95)
		]
		var col: Color = crystal_colors[c_type]
		var s := 12.0
		# Diamond: 4 horizontal bars stacked, narrowing toward the point.
		draw_rect(Rect2(pos + Vector2(-s * 0.7, -s), Vector2(s * 1.4, s * 0.35)), col)  # top point
		draw_rect(Rect2(pos + Vector2(-s * 0.9, -s * 0.5), Vector2(s * 1.8, s * 0.55)), col)  # widest
		draw_rect(Rect2(pos + Vector2(-s * 0.6, s * 0.05), Vector2(s * 1.2, s * 0.55)), col)  # lower
		draw_rect(Rect2(pos + Vector2(-s * 0.3, s * 0.6), Vector2(s * 0.6, s * 0.4)), col)  # bottom point
		# Inner highlight.
		var s2 := s * 0.4
		draw_rect(Rect2(pos + Vector2(-s2, -s2), Vector2(s2 * 2.0, s2 * 1.5)), Color(col.r, col.g, col.b, 0.5))

	# Helper creatures — chunky body + head.
	for h in _helpers:
		var hp: Vector2 = h.get("pos", Vector2.ZERO)
		var hc: Color = h.get("color", Color.WHITE)
		var bob := sin(_snow_time * 2.0 + hp.x * 0.03) * 3.0
		var hb := hp + Vector2(0.0, bob)
		draw_rect(Rect2(hb + Vector2(-8.0, -3.0), Vector2(16.0, 16.0)), hc)
		draw_rect(Rect2(hb + Vector2(-5.0, -13.0), Vector2(10.0, 10.0)), hc.lightened(0.15))
		draw_rect(Rect2(hb + Vector2(-3.5, -9.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(hb + Vector2(1.0, -9.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))

	# Catch flash — a chunky square frame.
	if _catch_flash > 0.0:
		var fs := ARENA_RADIUS * 0.6
		var col := Color(0.8, 0.9, 1.0, _catch_flash * 0.3)
		draw_rect(Rect2(Vector2(-fs, -fs), Vector2(fs * 2.0, 3.0)), col)
		draw_rect(Rect2(Vector2(-fs, fs - 3.0), Vector2(fs * 2.0, 3.0)), col)
		draw_rect(Rect2(Vector2(-fs, -fs + 3.0), Vector2(3.0, fs * 2.0 - 6.0)), col)
		draw_rect(Rect2(Vector2(fs - 3.0, -fs + 3.0), Vector2(3.0, fs * 2.0 - 6.0)), col)

	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 3.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-140.0, -ARENA_RADIUS - 30.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 280, 16,
			Color(0.8, 0.9, 1.0, alpha))

	draw_string(ThemeDB.fallback_font, Vector2(-100.0, ARENA_RADIUS + 20.0),
		"Catches: %d  |  Crew: %d" % [score / 10, _helpers.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color(0.8, 0.9, 1.0, 0.85))

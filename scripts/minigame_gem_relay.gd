extends "res://scripts/minigame_base.gd"
## GEM RELAY (lagoon): run between relay markers to collect gems.
##
## 6 relay markers in a ring. Each time you reach a marker, it spawns a gem you
## must collect before the next marker activates. Miss a gem and you lose points.
## Creeps join as "runners" who dance in the corners. 45s.
##
## Bot: path to the active marker in sequence.

const RELAY_DURATION := 45.0
const RING_RADIUS := 140.0
const MARKER_RADIUS := 18.0
const GEM_RADIUS := 10.0
const COLLECT_DIST := 30.0

var _markers: Array[Vector2] = []
var _active_marker := 0
var _gem_pos := Vector2.ZERO
var _gem_spawned := false
var _marker_progress := 0.0
var _creeps: Array[Dictionary] = []
var _comment_text := ""
var _comment_timer := 0.0


func _reset() -> void:
	timer = RELAY_DURATION
	_comment_text = ""
	_comment_timer = 0.0
	_markers.clear()
	for i in 6:
		var a := TAU * float(i) / 6.0
		_markers.append(Vector2.from_angle(a) * RING_RADIUS)
	_active_marker = 0
	_gem_spawned = false
	_marker_progress = 0.0
	score = 0
	_spawn_creeps()


func _spawn_creeps() -> void:
	_creeps.clear()
	var palette := [Color(0.2, 0.8, 0.6), Color(0.1, 0.7, 0.9), Color(0.3, 0.9, 0.4)]
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.7
		_creeps.append({
			"pos": Vector2.from_angle(a) * 190.0,
			"color": palette[i % palette.size()],
			"bob": randf() * TAU,
		})


func _update_delta(delta: float) -> void:
	_marker_progress += delta
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		var marker_pos := _markers[_active_marker]
		var dist_to_marker := rel.distance_to(marker_pos)
		if dist_to_marker < COLLECT_DIST and not _gem_spawned:
			# Reached marker: spawn a gem near it, require collection.
			_gem_pos = marker_pos + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
			_gem_spawned = true
			score += 5
			_spawn_next_group()
		elif dist_to_marker < COLLECT_DIST and _gem_spawned:
			# Collect the gem.
			_gem_spawned = false
			score += 15
			_active_marker = (_active_marker + 1) % _markers.size()
			# Jump to next unvisited marker for variety.
			if _active_marker == 0 and _marker_progress > 5.0:
				_active_marker = int(randi() % _markers.size())
			_check_comment()
	# Bob the creeps.
	for c in _creeps:
		c["bob"] = float(c.get("bob", 0.0)) + delta * 3.0
	queue_redraw()


func _spawn_next_group() -> void:
	# Add a new runner creep each time a marker is reached.
	if _creeps.size() < 12:
		var a := randf() * TAU
		_creeps.append({
			"pos": Vector2.from_angle(a) * 200.0,
			"color": Color(randf_range(0.3, 0.9), randf_range(0.3, 0.9), randf_range(0.3, 0.9)),
			"bob": randf() * TAU,
		})


func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	var target := _markers[_active_marker]
	if _gem_spawned:
		target = _gem_pos
	var to_target := target - rel
	if to_target.length() < 6.0:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	return {"move": to_target.normalized(), "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	pass


func _check_comment() -> void:
	if _active_marker == 2:
		_comment_text = "Nice legs!"
		_comment_timer = 2.0
	elif _active_marker == 4:
		_comment_text = "Keep going!"
		_comment_timer = 2.0


func _draw_body() -> void:
	# Water-ish floor — a chunky square panel.
	var floor_half := RING_RADIUS + 20.0
	draw_rect(Rect2(Vector2(-floor_half, -floor_half), Vector2(floor_half * 2.0, floor_half * 2.0)), Color(0.1, 0.25, 0.35, 0.5))

	# Markers — chunky squares; active one gets a pulsing square frame.
	for i in _markers.size():
		var mp := _markers[i]
		var is_active := i == _active_marker
		var col := Color(0.2, 0.9, 0.7, 0.95) if is_active else Color(0.3, 0.5, 0.6, 0.6)
		var mr := MARKER_RADIUS
		draw_rect(Rect2(mp + Vector2(-mr, -mr), Vector2(mr * 2.0, mr * 2.0)), col)
		if is_active:
			var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
			var ph := (MARKER_RADIUS + 10.0) * pulse
			var fc := Color(0.3, 1.0, 0.8, 0.5)
			var bar := 3.0
			draw_rect(Rect2(mp + Vector2(-ph, -ph), Vector2(ph * 2.0, bar)), fc)
			draw_rect(Rect2(mp + Vector2(-ph, ph - bar), Vector2(ph * 2.0, bar)), fc)
			draw_rect(Rect2(mp + Vector2(-ph, -ph + bar), Vector2(bar, ph * 2.0 - bar * 2.0)), fc)
			draw_rect(Rect2(mp + Vector2(ph - bar, -ph + bar), Vector2(bar, ph * 2.0 - bar * 2.0)), fc)

	# Gem — chunky 3-piece gem (core + top facet + bottom facet).
	if _gem_spawned:
		var gem_col := Color(1.0, 0.9, 0.2, 0.95)
		var bob := sin(Time.get_ticks_msec() * 0.008) * 4.0
		var gp := _gem_pos + Vector2(0.0, bob)
		var s := GEM_RADIUS
		draw_rect(Rect2(gp + Vector2(-s * 0.7, -s * 0.7), Vector2(s * 1.4, s * 1.4)), gem_col)
		draw_rect(Rect2(gp + Vector2(-s * 0.7, -s * 1.1), Vector2(s * 1.4, s * 0.4)), gem_col.lightened(0.25))
		draw_rect(Rect2(gp + Vector2(-s * 0.5, -s * 1.6), Vector2(s * 1.0, s * 0.4)), Color(1.0, 1.0, 0.6, 0.7))

	# Creeps — blocky body + head + eyes.
	for c in _creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var bob := sin(float(c.get("bob", 0.0))) * 3.0
		var cb := cp + Vector2(0.0, bob)
		draw_rect(Rect2(cb + Vector2(-9.0, -4.0), Vector2(18.0, 18.0)), cc)
		draw_rect(Rect2(cb + Vector2(-6.0, -16.0), Vector2(12.0, 12.0)), cc.lightened(0.2))
		draw_rect(Rect2(cb + Vector2(-4.0, -12.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(cb + Vector2(2.0, -12.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))

	# Player marker — chunky square.
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		draw_rect(Rect2(rel + Vector2(-13.0, -13.0), Vector2(26.0, 26.0)), Color(0.4, 0.8, 1.0, 0.95))
		draw_rect(Rect2(rel + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), Color(0.4, 0.8, 1.0, 0.5))

	# Progress text
	draw_string(ThemeDB.fallback_font, Vector2(-50.0, -RING_RADIUS - 50.0),
		"Gem %d/%d" % [_active_marker, _markers.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 100, 13, Color(0.6, 1.0, 0.9, 0.8))

	# Comment text
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 2.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-100.0, 40.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 15,
			Color(1.0, 0.9, 0.4, alpha))


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
		var gem_bonus := int(score * 0.8)
		var crowd_bonus := _creeps.size() * 5
		owner_player.add_gold(REWARD_GOLD + gem_bonus + crowd_bonus)
		owner_player.add_xp(REWARD_XP + crowd_bonus)

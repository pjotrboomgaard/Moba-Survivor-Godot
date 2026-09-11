extends "res://scripts/minigame_base.gd"

## Treasure Dash — Town corner (-1,-1).
## The player/bot must collect N treasure gems by moving (WASD for local,
## bot-driven movement for CPU). The "marker" is the player's position relative
## to the minigame center. Gems spawn within a bounded area; touching one collects it.
## Score = gems collected.

const GEM_COUNT := 5
const BOUNDS := 200.0  # half-extent of the playable box (world units)
const GEM_RADIUS := 18.0
const COLLECT_RADIUS := 40.0  # distance at which player collects a gem

var _gems: Array[Vector2] = []
var _collected := 0


func _reset() -> void:
	_collected = 0
	_gems.clear()
	for i in GEM_COUNT:
		_spawn_gem()


func _update_delta(delta: float) -> void:
	if not active or owner_player == null:
		return
	# Check gem collection: use owner's world position relative to minigame center.
	var rel := owner_player.global_position - global_position
	for i in _gems.size():
		if rel.distance_to(_gems[i]) <= COLLECT_RADIUS:
			_collected += 1
			score += 1
			AudioService.play("sfx_heal")
			_gems.remove_at(i)
			# Respawn a new gem to keep the count constant
			_spawn_gem()
			break
	queue_redraw()


func _spawn_gem() -> void:
	var p := Vector2(randf_range(-BOUNDS, BOUNDS), randf_range(-BOUNDS, BOUNDS))
	# Avoid spawning too close to center
	var attempts := 0
	while p.length() < 40.0 and attempts < 8:
		p = Vector2(randf_range(-BOUNDS, BOUNDS), randf_range(-BOUNDS, BOUNDS))
		attempts += 1
	_gems.append(p)


## Returns the desired movement direction for the bot to chase the nearest gem.
func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Find nearest gem and head toward it.
	if _gems.is_empty():
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var owner_rel := owner_player.global_position - global_position
	var target: Vector2 = _gems[0]
	var best_d := owner_rel.distance_to(target)
	for i in _gems.size():
		var d := owner_rel.distance_to(_gems[i])
		if d < best_d:
			best_d = d
			target = _gems[i]
	var to_gem := (target - owner_rel).normalized()
	return {"move": to_gem, "attack": false, "interact": false}


func on_input_event(event: InputEvent) -> void:
	# WASD movement is handled by the player's normal movement system;
	# the minigame just reads the player's position each frame.
	pass


func _draw_body() -> void:
	# Bounded box (drawn in local space, so relative to minigame center)
	var hw := BOUNDS
	var hh := BOUNDS
	# Outer border
	var border := Color(0.6, 0.7, 0.8, 0.35)
	draw_rect(Rect2(-hw, -hh, hw * 2.0, 2.0), border)
	draw_rect(Rect2(-hw, hh - 2.0, hw * 2.0, 2.0), border)
	draw_rect(Rect2(-hw, -hh, 2.0, hh * 2.0), border)
	draw_rect(Rect2(hw - 2.0, -hh, 2.0, hh * 2.0), border)
	# Corner markers
	var corner_col := Color(0.6, 0.7, 0.8, 0.5)
	for cx in [-hw, hw]:
		for cy in [-hh, hh]:
			draw_circle(Vector2(cx, cy), 4.0, corner_col)
	# Gems
	var gem_col := Color(1.0, 0.85, 0.3, 0.95)
	for g in _gems:
		var s := GEM_RADIUS
		var p1 := g + Vector2(0.0, -s)
		var p2 := g + Vector2(s * 0.7, 0.0)
		var p3 := g + Vector2(0.0, s)
		var p4 := g + Vector2(-s * 0.7, 0.0)
		var poly := PackedVector2Array([p1, p2, p3, p4])
		draw_colored_polygon(poly, gem_col)
		draw_circle(g, 4.0, Color(1.0, 1.0, 1.0, 0.6))
		# Sparkle ring
		draw_arc(g, s + 6.0, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, 0.3), 1.5)
	# Player marker (relative position)
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		if rel.length() < BOUNDS * 1.2:
			draw_circle(rel, 12.0, Color(0.4, 0.9, 0.6, 0.95))
			draw_arc(rel, 16.0, 0.0, TAU, 24, Color(0.4, 0.9, 0.6, 0.5), 2.0)
	# Count
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, BOUNDS + 20.0),
		"Gems: %d / %d" % [_collected, GEM_COUNT],
		HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.9, 0.9, 0.9, 0.85))

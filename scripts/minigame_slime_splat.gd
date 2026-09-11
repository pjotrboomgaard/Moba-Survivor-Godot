extends "res://scripts/minigame_base.gd"

## Slime Splat — lagoon-themed whack-a-mole minigame.
## Slimes pop up on water tiles around the arena; the player taps (attacks)
## them before they sink. Accuracy scores over time. Lagoon critters (fish,
## turtles) join as helpers when the player splats slimes well.
##
## DURATION: 45s. Bigger helper crew = bigger reward.

const SLIME_DURATION := 45.0
const ARENA_RADIUS := 200.0
const SLIME_HIT_RADIUS := 26.0
const SLIME_POP_LIFETIME := 2.6  # seconds a slime stays up before sinking
const TILE_SPACING := 80.0
const JOIN_THRESHOLDS: Array[int] = [6, 12, 20, 30]  # score milestones for joining
const GROUP_SIZES: Array[int] = [2, 3, 4, 5]

var _tiles: Array[Vector2] = []  # water tile positions
var _slimes: Array[Dictionary] = []  # {"pos":Vector2, "timer":float, "scale":float}
var _helpers: Array[Dictionary] = []  # {"pos":Vector2, "color":Color}
var _join_index := 0
var _splat_flash := 0.0
var _water_shimmer := 0.0
var _comment_text := ""
var _comment_timer := 0.0


func _reset() -> void:
	timer = SLIME_DURATION
	_slimes.clear()
	_helpers.clear()
	_join_index = 0
	_splat_flash = 0.0
	_water_shimmer = 0.0
	_comment_text = ""
	_comment_timer = 0.0
	_build_tiles()
	# Start with 2 slimes
	for i in 2:
		_spawn_slime()


func _build_tiles() -> void:
	_tiles.clear()
	var ring_counts: Array[int] = [6, 10, 14]
	var radii: Array[float] = [60.0, 120.0, 180.0]
	for r in ring_counts.size():
		var count := ring_counts[r]
		var radius := radii[r]
		for i in count:
			var angle := TAU * float(i) / float(count) + (0.3 if r % 2 == 1 else 0.0)
			_tiles.append(Vector2.from_angle(angle) * radius)


func _spawn_slime() -> void:
	if _tiles.is_empty():
		return
	# Pick a random tile that doesn't already have a slime.
	var occupied: Array[Vector2] = []
	for s in _slimes:
		occupied.append(s.get("pos", Vector2.ZERO))
	var free_tiles: Array[Vector2] = []
	for t in _tiles:
		var is_free := true
		for op in occupied:
			if t.distance_to(op) < TILE_SPACING * 0.4:
				is_free = false
				break
		if is_free:
			free_tiles.append(t)
	if free_tiles.is_empty():
		free_tiles = _tiles.duplicate()
	var pos: Vector2 = free_tiles[randi() % free_tiles.size()]
	_slimes.append({"pos": pos, "timer": SLIME_POP_LIFETIME, "scale": 0.0})


func _update_delta(delta: float) -> void:
	if not active:
		return
	_water_shimmer += delta
	_splat_flash = maxf(0.0, _splat_flash - delta * 2.0)
	_comment_timer = maxf(0.0, _comment_timer - delta)

	# Update slimes
	var to_remove: Array[int] = []
	for i in _slimes.size():
		var s := _slimes[i]
		var t: float = s.get("timer", 0.0)
		t -= delta
		if t <= 0.0:
			to_remove.append(i)
		else:
			# Scale in over first 0.3s, out over last 0.4s
			var elapsed := SLIME_POP_LIFETIME - t
			var scale := 1.0
			if elapsed < 0.3:
				scale = elapsed / 0.3
			elif t < 0.4:
				scale = t / 0.4
			_slimes[i] = {"pos": s.get("pos", Vector2.ZERO), "timer": t, "scale": scale}
	for i in range(to_remove.size() - 1, -1, -1):
		_slimes.remove_at(to_remove[i])
	# Spawn new slimes to keep 3-5 active
	var desired := 3 + int(_water_shimmer * 0.05)  # slowly increase
	if _slimes.size() < desired:
		_spawn_slime()

	# Check helper joins
	_check_helper_joins()

	queue_redraw()


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
		var dist := randf_range(40.0, ARENA_RADIUS * 0.8)
		var p := Vector2.from_angle(angle) * dist
		var col := Color(randf_range(0.2, 0.6), randf_range(0.6, 1.0), randf_range(0.4, 0.8), 1.0)
		_helpers.append({"pos": p, "color": col})


func _set_comment(txt: String) -> void:
	_comment_text = txt
	_comment_timer = 3.0


func _get_join_comment(idx: int) -> String:
	match idx:
		0: return "A fish swims by to help!"
		1: return "Turtles join the splat crew!"
		2: return "The lagoon crowd grows!"
		_: return "All the critters are helping you!"
	return ""


## Check if the player attacked a slime this frame. The player's primary
## attack is a melee swing; we check if any slime is within hit range.
func _check_splat_hits() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var player_pos := owner_player.global_position - global_position
	for s in _slimes:
		var pos: Vector2 = s.get("pos", Vector2.ZERO)
		if player_pos.distance_to(pos) <= SLIME_HIT_RADIUS + 14.0:
			# Splat! Remove the slime and score.
			score += 10
			_splat_flash = 1.0
			_vfx_burst(Color(0.3, 0.9, 0.5), 100.0, 0.3)
			# Remove this slime
			var idx := _slimes.find(s)
			if idx >= 0:
				_slimes.remove_at(idx)
			break  # one hit per frame


func bot_tick(_delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Bot moves toward the nearest slime.
	var player_rel := owner_player.global_position - global_position
	var nearest := Vector2.ZERO
	var min_dist := 99999.0
	for s in _slimes:
		var pos: Vector2 = s.get("pos", Vector2.ZERO)
		var d := player_rel.distance_to(pos)
		if d < min_dist:
			min_dist = d
			nearest = pos
	if min_dist > SLIME_HIT_RADIUS:
		return {"move": (nearest - player_rel).normalized(), "attack": false, "interact": false}
	# In range: attack.
	return {"move": Vector2.ZERO, "attack": true, "interact": false}


func on_input_event(event: InputEvent) -> void:
	# Attack input triggers a splat check.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_check_splat_hits()
	else:
		super.on_input_event(event)


func _draw_body() -> void:
	# Lagoon water tiles (subtle animated ripples)
	var shimmer := 0.5 + 0.5 * sin(_water_shimmer * 2.0)
	for t in _tiles:
		var ripple_col := Color(0.15, 0.4, 0.55, 0.25 + 0.1 * shimmer)
		draw_circle(t, 30.0, ripple_col)
		draw_arc(t, 30.0, 0.0, TAU, 24, Color(0.3, 0.6, 0.8, 0.2), 1.5)

	# Slimes
	for s in _slimes:
		var pos: Vector2 = s.get("pos", Vector2.ZERO)
		var scale: float = s.get("scale", 1.0)
		var slime_col := Color(0.3, 0.85, 0.4, 0.9 * scale)
		# Body (squishy blob)
		var wobble := 1.0 + 0.1 * sin(_water_shimmer * 4.0 + pos.x * 0.05)
		draw_circle(pos, 16.0 * scale * wobble, slime_col)
		draw_circle(pos, 10.0 * scale * wobble, Color(0.5, 1.0, 0.6, 0.5 * scale))
		# Eyes
		if scale > 0.5:
			draw_circle(pos + Vector2(-5.0 * scale, -3.0 * scale), 2.5 * scale, Color(0.1, 0.3, 0.1))
			draw_circle(pos + Vector2(5.0 * scale, -3.0 * scale), 2.5 * scale, Color(0.1, 0.3, 0.1))

	# Helper critters
	for h in _helpers:
		var hp: Vector2 = h.get("pos", Vector2.ZERO)
		var hc: Color = h.get("color", Color.WHITE)
		var bounce := sin(_water_shimmer * 3.0 + hp.x * 0.02) * 3.0
		draw_circle(hp + Vector2(0.0, bounce), 10.0, hc)
		# Little tail
		var tail_dir := Vector2.from_angle(_water_shimmer + hp.y * 0.01)
		draw_line(hp + Vector2(0.0, bounce), hp + Vector2(0.0, bounce) + tail_dir * 8.0, hc, 2.0)

	# Splat flash
	if _splat_flash > 0.0:
		draw_arc(Vector2.ZERO, ARENA_RADIUS, 0.0, TAU, 32, Color(0.4, 1.0, 0.5, _splat_flash * 0.3), 3.0)

	# Comment
	if _comment_timer > 0.0 and _comment_text != "":
		var alpha := clampf(_comment_timer / 3.0, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-140.0, -ARENA_RADIUS - 20.0),
			_comment_text, HORIZONTAL_ALIGNMENT_CENTER, 280, 16,
			Color(0.6, 1.0, 0.8, alpha))

	# Progress: helper count
	draw_string(ThemeDB.fallback_font, Vector2(-100.0, ARENA_RADIUS + 20.0),
		"Splats: %d  |  Crew: %d" % [score / 10, _helpers.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color(0.8, 0.9, 1.0, 0.85))


## Override: hook splat checks into the update loop.
func _process(delta: float) -> void:
	super._process(delta)
	if active:
		# Check splat hits every frame (melee range check)
		_check_splat_hits()

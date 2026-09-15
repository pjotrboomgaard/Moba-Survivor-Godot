extends Node2D

## Periodic rain overlay for the active biome.
## Rain is *occasional* — it starts and stops on its own, lasts 8-15 seconds,
## and plays a quiet rain SFX loop while active. The visual is a full-screen
## (camera-follow) particle overlay of falling streaks.
##
## Controlled by the arena: it sets `rain_active` (true/false) and this node
## crossfades the visuals + SFX. In non-biome modes the arena simply never
## enables it.
##
## T3.49 (2026-09-13): rain now follows the camera so it covers the full
## visible viewport regardless of where the camera is in the world.

var rain_active := false
## T3.13: when true, the overlay switches to a storm profile — denser, faster,
## longer streaks + a darker ambient veil. The arena toggles this during a storm.
var storm_active := false
var _fade := 0.0
var _streaks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _camera_pos := Vector2.ZERO

const STREAK_COUNT := 120
const STORM_STREAK_COUNT := 240
const STREAK_LEN_MIN := 14.0
const STREAK_LEN_MAX := 28.0
const STORM_LEN_MIN := 20.0
const STORM_LEN_MAX := 40.0
const STREAK_SPEED_MIN := 520.0
const STREAK_SPEED_MAX := 850.0
const STORM_SPEED_MIN := 950.0
const STORM_SPEED_MAX := 1500.0
const STREAK_ALPHA := 0.45
const STORM_ALPHA := 0.55
const STREAK_TINT := Color(0.62, 0.72, 0.86)
## Dark veil painted over the viewport while a storm is active.
const STORM_VEEIL := Color(0.02, 0.03, 0.08, 0.42)
## World-space margin around the camera that the rain covers.
const RAIN_MARGIN := 40.0


func _ready() -> void:
	_rng.randomize()
	z_index = 900
	z_as_relative = false


func _process(delta: float) -> void:
	# Track the camera position so the rain follows the player's view.
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		_camera_pos = camera.get_screen_center_position()

	var target := 1.0 if (rain_active or storm_active) else 0.0
	_fade = move_toward(_fade, target, delta * 1.6)
	if rain_active or storm_active:
		_tick_streaks(delta)
	if _fade > 0.01:
		queue_redraw()


func _seed_streaks() -> void:
	_streaks.clear()
	# Use the actual viewport size (converted to world units at the current zoom)
	# plus margin so rain covers the full screen at any zoom level.
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	# visible size in WORLD units = pixel size / zoom. (The old * zoom was inverted,
	# so at zoom < 1 the rain only covered a small central patch — T3.78.)
	var zoom := cam.zoom.x if cam != null and cam.zoom.x > 0.01 else 1.0
	var half_w := vp.x * 0.5 / zoom + RAIN_MARGIN
	var half_h := vp.y * 0.5 / zoom + RAIN_MARGIN
	var count := STORM_STREAK_COUNT if storm_active else STREAK_COUNT
	for i in count:
		_streaks.append({
			"x": _rng.randf_range(-half_w, half_w),
			"y": _rng.randf_range(-half_h - STREAK_LEN_MAX, half_h),
			"len": _rng.randf_range(STORM_LEN_MIN, STORM_LEN_MAX) if storm_active else _rng.randf_range(STREAK_LEN_MIN, STREAK_LEN_MAX),
			"speed": _rng.randf_range(STORM_SPEED_MIN, STORM_SPEED_MAX) if storm_active else _rng.randf_range(STREAK_SPEED_MIN, STREAK_SPEED_MAX),
		})


func set_rain_active(active: bool) -> void:
	if rain_active == active:
		return
	rain_active = active
	if active:
		_seed_streaks()
		_play_rain_sfx(true)
	else:
		_play_rain_sfx(false)


## T3.13: switch between calm rain and the denser storm profile. Re-seeds the
## streak field so the visual density change is immediate and readable.
func set_storm_active(active: bool) -> void:
	if storm_active == active:
		return
	storm_active = active
	_seed_streaks()
	queue_redraw()


func _tick_streaks(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	# world-unit half extents = pixel size / zoom (T3.78).
	var zoom := cam.zoom.x if cam != null and cam.zoom.x > 0.01 else 1.0
	var half_h := vp.y * 0.5 / zoom + RAIN_MARGIN
	var half_w := vp.x * 0.5 / zoom + RAIN_MARGIN
	var recycle_y := half_h + STREAK_LEN_MAX
	for s in _streaks:
		s.y += float(s.speed) * delta
		s.x -= float(s.speed) * 0.18 * delta
		if float(s.y) > recycle_y:
			s.y = -recycle_y
			s.x = _rng.randf_range(-half_w, half_w)
		# Recycle horizontally if the streak drifts off-screen.
		elif float(s.x) < -half_w:
			s.x = half_w


func _draw() -> void:
	if _fade <= 0.01:
		return
	# Draw in camera-relative space: translate to camera center so the rain
	# always covers the visible viewport. This node sits at world origin, so to
	# render a streak at the camera's view we add (NOT subtract) the camera's
	# world position. T3.42 fix: the old `- _camera_pos` mirrored the field to
	# the wrong side of the map whenever the camera moved off origin.
	var offset := _camera_pos
	# Storm darkening veil: full-screen rect.
	if storm_active:
		var vp := get_viewport().get_visible_rect().size
		draw_rect(Rect2(offset - vp * 0.5, vp), STORM_VEEIL * _fade)
	var a := (STORM_ALPHA if storm_active else STREAK_ALPHA) * _fade
	var col := Color(STREAK_TINT.r, STREAK_TINT.g, STREAK_TINT.b, a)
	for s in _streaks:
		var top := Vector2(float(s.x), float(s.y)) + offset
		var bottom := Vector2(float(s.x) + float(s.len) * 0.18, float(s.y) + float(s.len)) + offset
		draw_line(top, bottom, col, 2.5)


func _play_rain_sfx(on: bool) -> void:
	if not Engine.is_editor_hint():
		var aud = get_tree().get_first_node_in_group("audio_service")
		if aud != null and aud.has_method("set_rain"):
			aud.set_rain(on)

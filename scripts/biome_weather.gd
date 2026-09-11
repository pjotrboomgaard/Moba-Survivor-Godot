extends Node2D

## Periodic rain overlay for the active biome.
## Rain is *occasional* — it starts and stops on its own, lasts 8-15 seconds,
## and plays a quiet rain SFX loop while active. The visual is a full-screen
## (viewport-space) particle overlay of falling streaks.
##
## Controlled by the arena: it sets `rain_active` (true/false) and this node
## crossfades the visuals + SFX. In non-biome modes the arena simply never
## enables it.

var rain_active := false
var _fade := 0.0
var _streaks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

const STREAK_COUNT := 48
const STREAK_LEN_MIN := 8.0
const STREAK_LEN_MAX := 16.0
const STREAK_SPEED_MIN := 520.0
const STREAK_SPEED_MAX := 780.0
const STREAK_ALPHA := 0.22
const STREAK_TINT := Color(0.62, 0.72, 0.86)


func _ready() -> void:
	_rng.randomize()
	_seed_streaks()
	z_index = 900
	z_as_relative = false


func _seed_streaks() -> void:
	_streaks.clear()
	var viewport_size := Vector2(1280.0, 720.0)
	for i in STREAK_COUNT:
		_streaks.append({
			"x": _rng.randf_range(-viewport_size.x * 0.6, viewport_size.x * 0.6),
			"y": _rng.randf_range(-viewport_size.y * 0.7, viewport_size.y * 0.7),
			"len": _rng.randf_range(STREAK_LEN_MIN, STREAK_LEN_MAX),
			"speed": _rng.randf_range(STREAK_SPEED_MIN, STREAK_SPEED_MAX),
		})


func set_rain_active(active: bool) -> void:
	if rain_active == active:
		return
	rain_active = active
	if active:
		_play_rain_sfx(true)
	else:
		_play_rain_sfx(false)


func _process(delta: float) -> void:
	var target := 1.0 if rain_active else 0.0
	_fade = move_toward(_fade, target, delta * 1.6)
	if rain_active:
		_tick_streaks(delta)
	if _fade > 0.01:
		queue_redraw()


func _tick_streaks(delta: float) -> void:
	var viewport_size := Vector2(1280.0, 720.0)
	for s in _streaks:
		s.y += float(s.speed) * delta
		s.x -= float(s.speed) * 0.18 * delta
		if float(s.y) > viewport_size.y * 0.7:
			s.y = -viewport_size.y * 0.7
			s.x = _rng.randf_range(-viewport_size.x * 0.6, viewport_size.x * 0.6)


func _draw() -> void:
	if _fade <= 0.01:
		return
	var a := STREAK_ALPHA * _fade
	var col := Color(STREAK_TINT.r, STREAK_TINT.g, STREAK_TINT.b, a)
	for s in _streaks:
		var x := float(s.x)
		var y := float(s.y)
		var len := float(s.len)
		var top := Vector2(x, y)
		var bottom := Vector2(x + len * 0.18, y + len)
		draw_line(top, bottom, col, 1.5)


func _play_rain_sfx(on: bool) -> void:
	if not Engine.is_editor_hint():
		var aud = get_tree().get_first_node_in_group("audio_service")
		if aud != null and aud.has_method("set_rain"):
			aud.set_rain(on)

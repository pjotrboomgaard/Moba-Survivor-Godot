extends "res://scripts/minigame_base.gd"

## Keg Toss — Lagoon corner (-1,1).
## Tap to throw a keg at a moving target ring. Score by accuracy (closer = more points).
## Simple power/aim timer: target oscillates back and forth; press 1/2/3 or click to throw.
## 5 throws total. Bot drives via bot_tick.

const THROW_COUNT := 5
const TARGET_SPEED := 1.8  # oscillation speed multiplier
const TARGET_AMPLITUDE := 40.0  # how far target swings

var _throws := 0
var _target_phase := 0.0  # 0..TAU oscillation phase
var _target_dir := 1.0
var _last_throw_pos := Vector2.ZERO
var _throw_result := 0  # accuracy points from last throw
var _result_flash := 0.0


func _reset() -> void:
	_throws = 0
	_target_phase = 0.0
	_target_dir = 1.0
	_last_throw_pos = Vector2.ZERO
	_throw_result = 0
	_result_flash = 0.0


func _update_delta(delta: float) -> void:
	if not active:
		return
	_target_phase += delta * TARGET_SPEED * _target_dir
	# Oscillate: bounce between -1 and 1
	if _target_phase > 1.0:
		_target_phase = 1.0
		_target_dir = -1.0
	elif _target_phase < -1.0:
		_target_phase = -1.0
		_target_dir = 1.0
	_result_flash = maxf(0.0, _result_flash - delta * 2.0)


func on_input_event(event: InputEvent) -> void:
	if not active:
		return
	# Any key press 1/2/3 or click triggers a throw
	if event is InputEventKey and event.pressed and event.keycode in [KEY_1, KEY_2, KEY_3]:
		_do_throw()
	elif event is InputEventMouseButton and event.pressed:
		_do_throw()


func bot_tick(delta: float) -> Dictionary:
	if not active:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Bot throws when the target is near the center (phase close to 0) for max accuracy
	if _throws < THROW_COUNT and absf(_target_phase) < 0.15:
		_do_throw()
	return {"move": Vector2.ZERO, "attack": false, "interact": false}


func _do_throw() -> void:
	if _throws >= THROW_COUNT:
		return
	_throws += 1
	# Score based on how close the target is to center (0 = perfect)
	var accuracy := 1.0 - absf(_target_phase)  # 0..1
	var points := int(round(accuracy * 100.0))
	score += points
	_throw_result = points
	_result_flash = 1.0
	AudioService.play("minigame_keg_toss")
	_vfx_burst(Color(0.4, 0.9, 1.0), 16.0, 120.0)
	if _throws >= THROW_COUNT:
		_finish_with_reward()
	queue_redraw()


func _draw_body() -> void:
	# Target (oscillating) — chunky pixel-art ring + bullseye + track.
	var target_x := _target_phase * TARGET_AMPLITUDE
	var target_pos := Vector2(target_x, -20.0)
	var target_size := 28.0
	# Target ring: a chunky square ring (4 sides) made of rects.
	var ring_col := Color(0.4, 0.9, 1.0, 0.9)
	var half := target_size
	draw_rect(Rect2(target_pos + Vector2(-half, -half), Vector2(target_size * 2.0, 4.0)), ring_col)  # top
	draw_rect(Rect2(target_pos + Vector2(-half, half - 4.0), Vector2(target_size * 2.0, 4.0)), ring_col)  # bottom
	draw_rect(Rect2(target_pos + Vector2(-half, -half + 4.0), Vector2(4.0, target_size * 2.0 - 8.0)), ring_col)  # left
	draw_rect(Rect2(target_pos + Vector2(half - 4.0, -half + 4.0), Vector2(4.0, target_size * 2.0 - 8.0)), ring_col)  # right
	# Center dot (bullseye) — a chunky square.
	draw_rect(Rect2(target_pos + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), Color(0.4, 0.9, 1.0, 0.95))
	# Track — a chunky horizontal bar made of segments.
	var track_col := Color(0.3, 0.6, 0.8, 0.4)
	var seg_w := 12.0
	var start_x := -TARGET_AMPLITUDE
	var end_x := TARGET_AMPLITUDE
	var nseg := int(ceil((end_x - start_x) / seg_w))
	for s in nseg:
		var sx := start_x + s * seg_w
		draw_rect(Rect2(sx, -20.0 - 2.0, minf(seg_w - 2.0, end_x - sx), 4.0), track_col)
	# Mark center (bullseye) — a chunky square.
	draw_rect(Rect2(Vector2(0.0, -20.0) + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), Color(1.0, 1.0, 0.3, 0.8))
	# Throw count
	var text := "Throw %d/%d" % [_throws, THROW_COUNT]
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, 20.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, 120, 14, Color(0.9, 0.9, 0.9, 0.85))
	# Last throw result
	if _result_flash > 0.0:
		var color := Color(0.5, 1.0, 0.5, _result_flash) if _throw_result >= 60 else Color(1.0, 0.5, 0.5, _result_flash)
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, 38.0), "+%d!" % _throw_result,
			HORIZONTAL_ALIGNMENT_LEFT, 120, 16, color)

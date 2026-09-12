extends Node2D
## Isolated electro ground (T3.7) test scene. Self-contained:
##
##   1. Draws an empty flat factory-style world.
##   2. Activates an electro patch at centre: pulsing cyan disc + crackling zigzag
##      lines + "electrified!" label (mirrors arena.gd _draw_electro_ground).
##   3. Captures screenshots: before, mid (peak), late (fading).
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/electro_isolated.json
##      -Scene res://scenes/electro_test/electro_test.tscn

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

## Electro active window.
const ACTIVE_AT := 1.0
const DURATION := 4.0
const ORIGIN := Vector2(0.0, 0.0)
const RADIUS := 90.0

const CAPTURES: Array = [
	[0.5, "electro_off"],
	[1.6, "electro_peak"],
	[3.0, "electro_peak2"],
	[4.5, "electro_fading"],
]
var _captured := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_rng.randomize()
	_run_dir = "user://electro_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("ELECTRO_TEST ready: patch at %s r=%.0f, active %.1f-%.1fs" % [str(ORIGIN), RADIUS, ACTIVE_AT, ACTIVE_AT + DURATION])


func _is_active() -> bool:
	return _elapsed >= ACTIVE_AT and _elapsed <= ACTIVE_AT + DURATION


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	_capture_due()
	if _elapsed > 6.0 and not _done:
		_finish()


func _capture_due() -> void:
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			continue
		if _elapsed >= float(c[0]):
			_captured[label] = _capture(label)


func _capture(label: String) -> String:
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[Electro] snap %s -> %s" % [label, path])
	return path


func _draw() -> void:
	var half := Vector2(500.0, 500.0)
	# Factory dark floor.
	draw_rect(Rect2(-half, half * 2.0), Color(0.14, 0.15, 0.18), true)
	# Floor grid.
	var step := 100.0
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(1, 1, 1, 0.04), 2.0)
		x += step
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(1, 1, 1, 0.04), 2.0)
		y += step
	if _is_active():
		_draw_electro()


func _draw_electro() -> void:
	var t := clampf(1.0 - (_elapsed - ACTIVE_AT) / DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	var col := Color(0.55, 0.85, 1.0, 0.35 + 0.25 * pulse)
	draw_circle(ORIGIN, RADIUS, col)
	draw_arc(ORIGIN, RADIUS, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, 0.7), 2.0, true)
	# Crackling zigzag lines.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 100.0)
	for i in 7:
		var ang := rng.randf() * TAU
		var r0 := rng.randf_range(0.0, RADIUS * 0.5)
		var r1 := rng.randf_range(RADIUS * 0.5, RADIUS)
		var p0 := ORIGIN + Vector2.from_angle(ang) * r0
		var p1 := ORIGIN + Vector2.from_angle(ang + rng.randf_range(-0.4, 0.4)) * r1
		draw_line(p0, p1, Color(0.85, 0.95, 1.0, 0.6 + 0.3 * pulse), 1.5)
	# Sparks.
	for i in 4:
		var a2 := rng.randf() * TAU
		var sp := ORIGIN + Vector2.from_angle(a2) * rng.randf_range(0.0, RADIUS)
		draw_circle(sp, 2.0, Color(1.0, 1.0, 1.0, 0.8))
	# Label.
	draw_string(ThemeDB.fallback_font, ORIGIN + Vector2(0, -RADIUS - 8), "electrified!", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.7, 0.9, 1.0, 0.9))


func _finish() -> void:
	if _done:
		return
	_done = true
	_write_report()
	print("ELECTRO_TEST SUMMARY: active window %.1f-%.1fs, captured=%d" % [ACTIVE_AT, ACTIVE_AT + DURATION, _captured.size()])
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": "PASS" if _captured.size() >= 3 else "FAIL",
		"scene": "electro_test",
		"captured": _captured.size(),
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

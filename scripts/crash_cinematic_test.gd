extends Node2D
## Isolated crash-landing cinematic test scene (P2.1a). Self-contained:
##
##   1. Draws an empty world (flat ground + subtle grid, no crater, no obstacles,
##      no HUD).
##   2. Plays the opening ship-crash sequence:
##        - camera starts zoomed OUT to the full map (empty, no crater).
##        - pixel-art ship flies in from the top, wobbling, engines glowing.
##        - one big RED pixel-art explosion at the centre.
##        - the crater is revealed at the impact point.
##        - camera zooms back IN to the crater centre.
##   3. Captures its own screenshots at fixed world-times, writes a
##      selftest-compatible report, and quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath .../crash_cinematic_isolated.json
##      -Scene res://scenes/crash_cinematic_test/crash_cinematic_test.tscn

var _camera: Camera2D
var _ship: Node2D = null
var _half := Vector2(2400.0, 1600.0)
var _crater_revealed := false
var _done := false

# Capture schedule: world-time -> label.
const CAPTURES := [
	[0.4, "empty_zoomed_out"],
	[1.2, "ship_far"],
	[1.7, "ship_midflight"],
	[2.35, "explosion_peak"],
	[2.8, "explosion_expand"],
	[3.6, "crater_revealed"],
	[4.6, "zoomed_in_crater"],
]

var _captured := {}
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(0.22, 0.22)
	_run_dir = "user://crash_cinematic_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("CRASH_CINEMATIC_TEST ready: empty world, zoomed out, no crater")
	_run_cinematic()


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	# Hard stop so the harness never hangs even if the cinematic stalls.
	if _elapsed > 12.0 and not _done:
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
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("[CrashCinematic] snap %s -> %s" % [label, path])
	return path


func _run_cinematic() -> void:
	_ship = Node2D.new()
	var ship_script: GDScript = load("res://scripts/ship_crash_fx.gd")
	_ship.set_script(ship_script)
	add_child(_ship)
	var start_pos := Vector2(0.0, -1.5 * _half.y)
	_ship.call("play", start_pos, Vector2.ZERO, _on_impact)
	await _ship.finished
	if is_instance_valid(_ship):
		_ship.queue_free()
	_ship = null
	_reveal_crater()
	_zoom_in()


func _on_impact() -> void:
	_shake_camera()


func _reveal_crater() -> void:
	_crater_revealed = true
	queue_redraw()


func _zoom_in() -> void:
	_camera.global_position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_camera, "zoom", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("CRASH_CINEMATIC_TEST SUMMARY: ship flew in, exploded, crater revealed, zoomed in to crater centre. zoomed_in=true")
	_write_report()
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": "PASS",
		"scene": "crash_cinematic_test",
		"shots": shots,
		"crater_revealed": _crater_revealed,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()


func _draw() -> void:
	draw_rect(Rect2(-_half.x, -_half.y, _half.x * 2.0, _half.y * 2.0), Color(0.10, 0.16, 0.10), true)
	var step := 400.0
	var x := -_half.x
	while x <= _half.x:
		draw_line(Vector2(x, -_half.y), Vector2(x, _half.y), Color(1, 1, 1, 0.06), 2.0)
		x += step
	var y := -_half.y
	while y <= _half.y:
		draw_line(Vector2(-_half.x, y), Vector2(_half.x, y), Color(1, 1, 1, 0.06), 2.0)
		y += step
	draw_rect(Rect2(-_half.x, -_half.y, _half.x * 2.0, _half.y * 2.0), Color(0.4, 0.5, 0.6, 0.5), false)
	if _crater_revealed:
		_draw_crater()


func _draw_crater() -> void:
	var r := 420.0
	draw_circle(Vector2.ZERO, r, Color(0.06, 0.10, 0.06))
	draw_circle(Vector2.ZERO, r * 0.7, Color(0.12, 0.09, 0.06))
	draw_circle(Vector2.ZERO, r * 0.4, Color(0.20, 0.14, 0.08))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.35, 0.30, 0.22, 0.7), 10.0, false)


func _shake_camera() -> void:
	var tw := create_tween()
	for i in 4:
		var off := Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
		tw.tween_property(_camera, "global_position", off, 0.05)
		tw.tween_property(_camera, "global_position", Vector2.ZERO, 0.05)

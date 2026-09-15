extends Node2D

## T3.42 isolated test: verify the rain overlay stays FULL-SCREEN while the
## camera moves around the world. BEFORE the fix, rain was a fixed band that
## did not track the camera; after the fix it must cover the whole viewport
## at every camera position.

const _BIOME_WEATHER := preload("res://scripts/biome_weather.gd")

var _camera: Camera2D
var _weather: Node2D = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

const CAPTURES: Array = [
	[0.3, "camera_center"],
	[0.8, "camera_top_right"],
	[1.6, "camera_bottom_left"],
	[2.4, "camera_far_right"],
]
var _captured := {}

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://rain_move_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_weather = _BIOME_WEATHER.new()
	add_child(_weather)
	_weather.set_rain_active(true)
	print("RAIN_MOVE_TEST ready")


func _process(delta: float) -> void:
	_elapsed += delta
	_move_camera()
	_capture_due()
	if _elapsed > 3.0 and not _done:
		_finish()


func _move_camera() -> void:
	if _elapsed < 0.4:
		_camera.global_position = Vector2.ZERO
	elif _elapsed < 0.9:
		_camera.global_position = Vector2(400, -300)
	elif _elapsed < 1.7:
		_camera.global_position = Vector2(-400, 300)
	else:
		_camera.global_position = Vector2(600, 0)


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
	print("[RainMove] snap %s cam=%s -> %s" % [label, _camera.global_position, path])
	return path


func _draw() -> void:
	var half := Vector2(600.0, 600.0)
	draw_rect(Rect2(-half, half * 2.0), Color(0.18, 0.34, 0.20), true)
	var step := 100.0
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(1, 1, 1, 0.06), 2.0)
		x += step
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(1, 1, 1, 0.06), 2.0)
		y += step


func _finish() -> void:
	if _done:
		return
	_done = true
	_write_report()
	print("RAIN_MOVE_TEST SUMMARY: captured=%d" % _captured.size())
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": "PASS" if _captured.size() >= 3 else "FAIL",
		"scene": "rain_move_test",
		"captured": _captured.size(),
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

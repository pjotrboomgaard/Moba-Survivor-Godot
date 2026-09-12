extends Node2D
## Isolated rain (T3.5) test scene. Self-contained:
##
##   1. Draws an empty flat grass world.
##   2. Spawns a biome_weather overlay in normal-rain mode.
##   3. Captures screenshots at fixed world-times to show the rain streaks clearly.
##   4. Writes user://selftest_report.json + quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/rain_verify.json
##      -Scene res://scenes/rain_test/rain_test.tscn

const _BIOME_WEATHER := preload("res://scripts/biome_weather.gd")

var _camera: Camera2D
var _weather: Node2D = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

const CAPTURES: Array = [
	[0.3, "rain_off"],
	[0.8, "rain_on_fadein"],
	[1.6, "rain_full"],
	[3.0, "rain_full2"],
]
var _captured := {}


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://rain_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_weather = _BIOME_WEATHER.new()
	add_child(_weather)
	_weather.set_rain_active(true)
	print("RAIN_TEST ready: rain overlay forced on")


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 4.5 and not _done:
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
	print("[Rain] snap %s -> %s" % [label, path])
	return path


func _draw() -> void:
	var half := Vector2(500.0, 500.0)
	# Grass ground.
	draw_rect(Rect2(-half, half * 2.0), Color(0.18, 0.34, 0.20), true)
	var step := 100.0
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(1, 1, 1, 0.05), 2.0)
		y += step
	# A few static trees for context.
	var spots := [Vector2(-300.0, -200.0), Vector2(200.0, -250.0), Vector2(350.0, 150.0), Vector2(-150.0, 220.0)]
	for s in spots:
		var tex := SpriteLibrary.texture_for("tree_oak")
		if tex != null:
			var zoom := Obstacle.tree_display_zoom(4.0, tex)
			var size := Vector2(tex.get_width(), tex.get_height()) * zoom
			draw_texture_rect(tex, Rect2(s - size * 0.5, size), false)


func _finish() -> void:
	if _done:
		return
	_done = true
	_write_report()
	print("RAIN_TEST SUMMARY: captured=%d" % _captured.size())
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": "PASS" if _captured.size() >= 3 else "FAIL",
		"scene": "rain_test",
		"captured": _captured.size(),
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

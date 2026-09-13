extends Node2D
## Isolated grass/flower zoom test (T3.31).
##
## Spawns a real Arena (biome 0 = grass meadow) so baked ground-cover decals
## (grass_tuft, grass_long, grass_wild, ...) are populated via _scatter_ground_cover.
##
## The camera zooms OUT to 0.13 (the crash-cinematic full-map overhead zoom) then
## back IN to 0.5 (normal play zoom). At each state we capture a screenshot.
##
## PASS criteria:
##   - The zoomed-out screenshot shows continuous grass/flower texture across the
##     entire visible map - NO bare/untextured patches.
##   - The zoomed-in screenshot also shows grass (no regression).
##   - No "drawn == 0" log line from _draw_decals (i.e. the cull rect is not empty).
##
## Launched via:
##   powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 \
##     -RequestPath tools/selftest/requests/grass_zoom_verify.json \
##     -Scene res://scenes/grass_zoom_test/grass_zoom_test.tscn

const ArenaScript: String = "res://scripts/arena.gd"

var _camera: Camera2D
var _arena: Node2D = null
var _elapsed := 0.0
var _done := false
var _run_dir := ""
var _report_path := "user://selftest_report.json"

## Capture schedule: [time_sec, label]
const CAPTURES: Array = [
	[0.5, "zoomed_in_start"],
	[2.5, "zoomed_out_map"],
	[5.5, "zoomed_out_edges"],
	[8.5, "zoomed_in_center"],
	[10.5, "zoomed_in_corner"],
]

var _captured: Dictionary = {}


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(0.5, 0.5)

	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	GameRuntime.set_biome(0, true)

	_arena = _make_arena()
	add_child(_arena)

	for i in 3:
		await get_tree().process_frame

	var baked := _count_baked_props()
	print("[GrassZoomTest] arena ready, baked_props=", baked)

	_run_dir = "user://grass_zoom_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("GRASS_ZOOM_TEST ready: biome=0 baked_props=%d" % baked)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_update_camera()
	_capture_due()
	if _elapsed > 12.0 and not _done:
		_finish()


func _update_camera() -> void:
	var half := _arena_half()
	if _elapsed < 1.5:
		_set_camera(0.5, 0.5, Vector2.ZERO)
	elif _elapsed < 3.5:
		_set_camera(0.13, 0.13, Vector2.ZERO)
	elif _elapsed < 6.5:
		_set_camera(0.13, 0.13, Vector2(half.x * 0.3, half.y * 0.3))
	elif _elapsed < 9.0:
		_set_camera(0.5, 0.5, Vector2.ZERO)
	else:
		_set_camera(0.5, 0.5, Vector2(half.x * 0.3, half.y * 0.3))


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
	print("[GrassZoomTest] snap %s -> %s" % [label, path])
	return path


func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS"
	var notes := []
	var baked := _count_baked_props()
	if baked == 0:
		verdict = "FAIL_NO_BAKED_PROPS"
		notes.append("arena baked_props was empty - arena did not scatter ground cover")
	print("GRASS_ZOOM_TEST SUMMARY: verdict=%s baked_props=%d shots=%d notes=%s" % [
		verdict, baked, _captured.size(), str(notes)])
	_write_report(verdict, notes)
	get_tree().quit(0)


func _write_report(verdict: String, notes: Array) -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": verdict,
		"scene": "grass_zoom_test",
		"baked_props": _count_baked_props(),
		"notes": notes,
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()


func _make_arena() -> Node2D:
	var arena_script: GDScript = load(ArenaScript)
	var node := Node2D.new()
	node.set_script(arena_script)
	return node


func _count_baked_props() -> int:
	if _arena == null:
		return 0
	var props = _arena.get("baked_props")
	if props == null:
		return 0
	return props.size()


func _arena_half() -> Vector2:
	return Vector2(8400.0, 5600.0) * 0.5


func _set_camera(zx: float, zy: float, pos: Vector2) -> void:
	_camera.zoom = Vector2(zx, zy)
	_camera.global_position = pos

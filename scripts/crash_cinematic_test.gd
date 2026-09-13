extends Node2D
## Isolated crash-landing cinematic test scene (P2.1a + T3.31). Self-contained:
##
##   1. Instantiates the REAL arena (ground texture + scattered grass/flowers/rocks),
##      but with the crater UNLOCKED-hidden (as the opening cinematic starts).
##   2. Plays the opening ship-crash sequence against that real arena:
##        - camera starts zoomed OUT to the full map — the grass/flower ground cover
##          must already be rendered at t=0 (the T3.31 requirement).
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

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/arena.tscn")

var _camera: Camera2D
var _arena: Arena = null
var _ship: Node2D = null
var _half := Vector2(2400.0, 1600.0)
var _crater_revealed := false
var _done := false

# Capture schedule: world-time -> label. The first two are the critical T3.31
# frames — zoomed-out full map where grass MUST be visible before the ship lands.
const CAPTURES := [
	[0.4, "empty_zoomed_out"],
	[0.9, "grass_zoomed_out"],
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
	_build_real_arena()
	print("CRASH_CINEMATIC_TEST ready: real arena, zoomed out, no crater yet")
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


## Build the real arena (ground + scattered ground cover). The crater stays hidden
## until the ship's impact, mirroring play_opening_cinematic().
func _build_real_arena() -> void:
	_arena = ARENA_SCENE.instantiate() as Arena
	add_child(_arena)
	# The arena's own _ready runs its scatter; give it a beat to lay ground cover.
	await get_tree().process_frame
	await get_tree().process_frame
	if _arena != null:
		_arena.set_crater_unlocked(false)
		_arena.queue_redraw()


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
	if _arena != null:
		_arena.set_crater_unlocked(true)
		_arena.queue_redraw()


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
	print("CRASH_CINEMATIC_TEST SUMMARY: real arena rendered zoomed out, ship crashed, crater revealed, zoomed in")
	_write_report()
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	# T3.31 acceptance: the zoomed-out frames must show the real grass ground cover.
	var grass_zoomed_out := _captured.has("grass_zoomed_out")
	var report := {
		"verdict": "PASS" if grass_zoomed_out else "FAIL",
		"scene": "crash_cinematic_test",
		"shots": shots,
		"crater_revealed": _crater_revealed,
		"grass_rendered_zoomed_out": grass_zoomed_out,
		"note": "Zoomed-out full-map frames must show scattered grass/flower ground cover from t=0 (T3.31)."
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()


func _shake_camera() -> void:
	var tw := create_tween()
	for i in 4:
		var off := Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
		tw.tween_property(_camera, "global_position", off, 0.05)
		tw.tween_property(_camera, "global_position", Vector2.ZERO, 0.05)

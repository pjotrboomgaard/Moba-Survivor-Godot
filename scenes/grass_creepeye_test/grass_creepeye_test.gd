extends Node2D
## T3.85 isolated test: empty world (flat black background, no grass/HUD/props) with
## a single real Enemy (grunt) + a real Player placed next to it. The Player is
## required so the grunt's far-mode cull (which needs a nearby Player) does not
## hide its sprite — without it the grunt would be invisible in the capture.
##
## Toggles WorldClock.is_night: day (faint eyes) -> night (bright red eyes).
## PASSes when the night frame has more red pixels than the day frame.
## Writes user://selftest_report.json + screenshots, then quits.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _enemy: Node2D = null
var _player: Node2D = null
var _elapsed := 0.0
var _done := false
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _captured := {}
var _red_counts: Array = []

## [time, label]. Day first, then night, then day again.
const CAPTURES: Array = [
	[0.9, "day_before"],
	[1.7, "night_after"],
	[2.5, "day_restore"],
]

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://creep_eye_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Real Player near the grunt so the grunt never enters far-mode (which hides
	# its sprite and would make the red-eyes test impossible).
	_player = PLAYER_SCENE.instantiate()
	_player.name = "AnchorPlayer"
	add_child(_player)
	_player.global_position = Vector2(60.0, 0.0)

	_enemy = ENEMY_SCENE.instantiate()
	_enemy.name = "EyeGrub"
	add_child(_enemy)
	_enemy.global_position = Vector2.ZERO
	if _enemy.has_method("configure"):
		_enemy.configure(1, true, "grunt", 1.0, 1.0)

func _process(delta: float) -> void:
	_elapsed += delta
	# Night for the middle window, day otherwise.
	var in_night_window: bool = _elapsed >= 1.3 and _elapsed < 2.1
	if in_night_window and not WorldClock.is_night:
		WorldClock.time_of_day = 0.80
		WorldClock._refresh()
		WorldClock.revision += 1
	elif not in_night_window and WorldClock.is_night:
		WorldClock.time_of_day = 0.30
		WorldClock._refresh()
		WorldClock.revision += 1
	_capture_due()
	if _elapsed > 2.9 and not _done:
		_finish()

var _capture_in_progress := false

func _capture_due() -> void:
	if _capture_in_progress:
		return
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			continue
		if _elapsed >= float(c[0]):
			_capture_in_progress = true
			_capture(label)
			_capture_in_progress = false

func _count_red(img: Image) -> int:
	# Count BRIGHT-red pixels (the night eyes). The day eyes are dark red
	# (~42,10,10) which fails c.r > 0.8. The night eyes are bright (255,30,20)
	# which passes. Sample every 2nd pixel to keep the O(n) scan fast.
	var count := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.8 and c.g < 0.35 and c.b < 0.35:
				count += 1
	return count

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var img: Image = null
	var vp := get_viewport()
	if vp != null and vp.get_texture() != null:
		img = vp.get_texture().get_image()
	var ok := false
	if img != null and img.get_width() > 0:
		ok = (img.save_png(path) == OK)
	var red := _count_red(img) if img != null else -1
	print("[CreepEye] snap %s is_night=%s red_pixels=%d" % [label, str(WorldClock.is_night), red])
	_shots.append({"label": label, "path": path, "t": _elapsed, "is_night": WorldClock.is_night, "red_pixels": red})
	_red_counts.append({"label": label, "red": red})
	_captured[label] = true

func _draw() -> void:
	draw_rect(Rect2(-640, -360, 1280, 720), Color(0.03, 0.03, 0.05), true)
	draw_circle(Vector2.ZERO, 46.0, Color(0.10, 0.10, 0.12), true)
	draw_circle(Vector2.ZERO, 46.0, Color(0.20, 0.20, 0.24), false, 2.0)

func _finish() -> void:
	if _done:
		return
	_done = true
	var day_shot: Dictionary = {}
	var night_shot: Dictionary = {}
	for s in _shots:
		if s["label"] == "day_before":
			day_shot = s
		elif s["label"] == "night_after":
			night_shot = s
	var verdict := "FAIL"
	if not day_shot.is_empty() and not night_shot.is_empty():
		var day_red: int = int(day_shot.get("red_pixels", 0))
		var night_red: int = int(night_shot.get("red_pixels", 0))
		# Night must have noticeably more red than day (eyes glow at night).
		if night_red > day_red + 100:
			verdict = "PASS"
	var report := {
		"verdict": verdict,
		"scene": "grass_creepeye_test",
		"shots": _shots,
		"red_counts": _red_counts,
		"enemy_alive": is_instance_valid(_enemy),
		"final_is_night": WorldClock.is_night,
	}
	var json_text := JSON.stringify(report, "  ")
	for rp in [_report_path, "user://selftest_report.json"]:
		var f := FileAccess.open(rp, FileAccess.WRITE)
		if f != null:
			f.store_string(json_text)
			f.close()
	print("CREEP_EYE SUMMARY verdict=%s" % verdict)
	get_tree().quit(0 if verdict == "PASS" else 1)

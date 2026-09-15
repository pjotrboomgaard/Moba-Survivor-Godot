## T3.90: Isolated empty-world test for tree regrowth.
##
## This scene contains ONLY:
## - A camera framing a stump + regrowing tree
## - Direct drawing of the fade-in (no full arena dependency)
## - A timer that simulates 3 day/night cycles then a 1-second fade-in
## - Snapshots at key moments
##
## It writes user://selftest_report.json and calls get_tree().quit().

extends Node2D

const SpriteLibrary := preload("res://scripts/sprite_library.gd")

var _report: Dictionary = {}
var _snap_schedule: Array = []  # [seconds, label]
var _snap_index := 0
var _time_acc := 0.0
var _done := false

# Simulated regrow state (mirrors arena.gd logic).
var _REGROW_CYCLES := 3
# T3.90 update: the regrow is now a 1-second fade-in (not a 10s scale morph).
var _REGROW_FADE_SECONDS := 1.0
var _cycles_remaining := 3
var _fade_progress := 0.0
var _regrowing := false
var _replanted := false
var _replanted_at := -1.0
var _last_tod := 0.0
# Simulate 1 cycle per 4 seconds of wall-clock so the test runs ~12s total.
const _CYCLE_SECONDS := 4.0

var _stump_pos := Vector2(0.0, 0.0)
var _tree_tex: Texture2D = null

func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(0.0, 60.0)
	cam.zoom = Vector2(1.2, 1.2)
	add_child(cam)
	_tree_tex = SpriteLibrary.texture_for("tree_01")
	_snap_schedule = [
		[0.5, "stump_only"],
		[_CYCLE_SECONDS * 3 + 0.3, "fade_early"],
		[_CYCLE_SECONDS * 3 + 0.6, "fade_mid"],
		[_CYCLE_SECONDS * 3 + 1.2, "fade_complete_replanted"],
	]
	_report["tree_tex_found"] = _tree_tex != null
	_report["started_at"] = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()))
	_report["user_dir"] = ProjectSettings.globalize_path("user://")

func _process(delta: float) -> void:
	_time_acc += delta
	# Simulate day/night cycle wrapping every _CYCLE_SECONDS.
	var tod := fmod(_time_acc, _CYCLE_SECONDS)
	if tod < _last_tod:
		if not _regrowing:
			_cycles_remaining -= 1
			if _cycles_remaining <= 0:
				_regrowing = true
				_fade_progress = 0.0
	_last_tod = tod
	if _regrowing and not _replanted:
		_fade_progress += delta / _REGROW_FADE_SECONDS
		if _fade_progress >= 1.0:
			_fade_progress = 1.0
			_replanted = true
			_replanted_at = _time_acc
	# Take next snapshot if due.
	if _snap_index < _snap_schedule.size():
		var due: Array = _snap_schedule[_snap_index]
		if _time_acc >= float(due[0]):
			_take_snapshot(str(due[1]))
			_snap_index += 1
	# Done when all snapshots are taken.
	if _snap_index >= _snap_schedule.size() and not _done:
		_done = true
		_write_report()

func _draw() -> void:
	# Draw a simple dark ground.
	draw_rect(Rect2(Vector2(-200, -200), Vector2(400, 400)), Color(0.08, 0.1, 0.08), true)
	var p: Vector2 = _stump_pos
	# Draw the stump (small brown base).
	draw_circle(p, 10.0, Color(0.35, 0.25, 0.15))
	draw_circle(p, 6.0, Color(0.5, 0.38, 0.22))
	# Draw the regrowing tree — a simple fade-in at full size.
	if _tree_tex != null:
		if _regrowing or _replanted:
			var t: float = clampf(_fade_progress, 0.0, 1.0)
			var w: float = _tree_tex.get_width() * 0.5
			var h: float = _tree_tex.get_height() * 0.5
			var base_offset: Vector2 = Vector2(0.0, -h)
			var alpha_f: float = t
			if alpha_f > 0.001:
				draw_texture_rect(_tree_tex, Rect2(p + base_offset - Vector2(w, 0.0), Vector2(w * 2.0, h)), false, Color(1, 1, 1, alpha_f))
	# Draw status text.
	var status := "cycles_left=%d regrowing=%s fade=%.2f replanted=%s" % [_cycles_remaining, str(_regrowing), _fade_progress, str(_replanted)]
	var font: Font = ThemeDB.get_fallback_font()
	draw_string(font, Vector2(-180, -180), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _take_snapshot(label: String) -> void:
	# Force a redraw before capturing.
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "user://selftest_%s.png" % label
	var err: int = img.save_png(path)
	if err != OK:
		push_error("save_png failed: err=%d path=%s" % [err, path])
	_report[label] = path
	print("[tree_regrow_test] snapshot %s -> %s (cycles=%d fade=%.2f replanted=%s)" % [label, path, _cycles_remaining, _fade_progress, str(_replanted)])

func _write_report() -> void:
	_report["verdict"] = "PASS" if (_replanted and _snap_index >= _snap_schedule.size()) else "FAIL"
	_report["cycles_remaining"] = _cycles_remaining
	_report["fade_progress"] = _fade_progress
	_report["replanted"] = _replanted
	_report["replanted_at_time"] = _replanted_at
	_report["snapshots_taken"] = _snap_index
	_report["finished_at"] = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()))
	var json := JSON.stringify(_report, "\t")
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()
		print("[tree_regrow_test] report -> user://selftest_report.json verdict=%s" % _report["verdict"])
	get_tree().quit()

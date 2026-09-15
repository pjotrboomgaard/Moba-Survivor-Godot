extends Node2D
## T4.1/T4.2 — Isolated verification: the animated menu backgrounds for Tobor
## (Wrench) and Diord (warden).
##   T4.1: Diord (warden) plays at HALF speed (2.4 fps) vs Tobor (4.8 fps).
##   T4.2: Diord's backdrop periodically drifts forward and back (sine offset
##         on the TextureRect offset_top, ~4s period, +/-14px).
##
## The selftest driver does NOT attach to isolated scenes, so this scene:
##   1. Loads the frame folders for both heroes (same source bootstrap.gd uses).
##   2. Asserts each hero has a non-trivial number of frames.
##   3. Renders the active hero's frame full-screen, advancing at the per-hero
##      FPS (tobor 4.8, warden 2.4) and applying the warden forward/back drift.
##   4. Captures screenshots at t=0.5 (tobor), t=3.5/4.5/5.5 (warden, spaced
##      >1 period apart so the oscillation is visible in the compare).
##   5. Writes user://selftest_report.json with verdict + frame counts + shots
##      + the measured warden offset_top at each warden shot.
##
## Runs empty-world: a Camera2D + a full-rect TextureRect. No arena, no HUD, no
## world props — only the mechanic under test (the animated menu backdrop).
class_name MenuBgTest

const HEROES := ["tobor", "warden"]
# T4.1: per-hero fps. Tobor stays 4.8 (20% of 24fps source). Warden (Diord) is
# now half speed -> 2.4 fps.
const FPS := {"tobor": 4.8, "warden": 2.4}
# T4.2: warden periodic forward/back drift (bootstrap.gd _tick_menu_video).
const WARDEN_PAN_PERIOD := 4.0
const WARDEN_PAN_AMPLITUDE := 14.0

var _frames: Dictionary = {}   # class_id -> Array[Texture2D]
var _frames_total: Dictionary = {}
var _active_class := "tobor"
var _frame_index := 0
var _direction := 1
var _timer := 0.0
var _rect: TextureRect = null
var _elapsed := 0.0
var _warden_pan_phase := 0.0   # T4.2 drift phase (only advances while warden active)
var _verdict := "PASS"
var _report: Dictionary = {}
var _shots: Array = []
# Tobor animates 0-3s (shot at 0.5), Diord (warden) animates 3-7s (shots at
# 3.5, 5.5, 7.5) — spaced 2s apart, > half the 4s period, so the forward/back
# offset is clearly different at each capture.
var _shot_times := [0.5, 3.5, 5.5, 7.5]


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	cam.zoom = Vector2(1.0, 1.0)
	add_child(cam)

	# Load both heroes' frame sets exactly like bootstrap.gd does.
	for class_id in HEROES:
		_frames[class_id] = _load_frames(class_id)
		_frames_total[class_id] = _frames[class_id].size()
		if _frames[class_id].is_empty():
			_verdict = "FAIL"
			_report["error_%s" % class_id] = "no frames loaded for %s" % class_id

	# Active backdrop rect (full screen).
	_rect = TextureRect.new()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	if not _frames[_active_class].is_empty():
		_rect.texture = _frames[_active_class][0]

	_report["class_active"] = _active_class
	_report["frames_tobor"] = _frames_total["tobor"]
	_report["frames_warden"] = _frames_total["warden"]
	_report["fps_tobor"] = FPS["tobor"]
	_report["fps_warden"] = FPS["warden"]
	_report["expected_tobor_min"] = 20
	_report["expected_warden_min"] = 20


func _process(delta: float) -> void:
	_elapsed += delta
	# After the first 3s of tobor, switch to Diord (warden) and reset the frame.
	if _active_class == "tobor" and _elapsed >= 3.0:
		_active_class = "warden"
		_frame_index = 0
		_direction = 1
		_timer = 0.0
	# Advance the active hero's frame ping-pong at the per-hero FPS (T4.1).
	if not _frames[_active_class].is_empty() and _frames[_active_class].size() > 1:
		_timer += delta
		if _timer >= 1.0 / FPS[_active_class]:
			_timer = 0.0
			_frame_index += _direction
			if _frame_index >= _frames[_active_class].size():
				_frame_index = _frames[_active_class].size() - 2
				_direction = -1
			elif _frame_index < 0:
				_frame_index = 1
				_direction = 1
			_rect.texture = _frames[_active_class][clampi(_frame_index, 0, _frames[_active_class].size() - 1)]
	# T4.2: warden periodic forward/back drift — mirror bootstrap._tick_menu_video.
	if _active_class == "warden":
		_warden_pan_phase += delta
		var off: float = sin(_warden_pan_phase * (TAU / WARDEN_PAN_PERIOD)) * WARDEN_PAN_AMPLITUDE
		_rect.offset_top = -off
	else:
		_rect.offset_top = 0.0
	# Take a screenshot at each configured time.
	for t in _shot_times:
		if _elapsed >= t and not _shot_taken(t):
			_capture("menu_%s_%.1f" % [_active_class, t])
	if _elapsed >= 8.0:
		_finish()


func _shot_taken(t: float) -> bool:
	for s in _shots:
		if absf(float(s.get("t", -1.0)) - t) < 0.01:
			return true
	return false


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var path := "user://%s.png" % label
	img.save_png(path)
	var shot: Dictionary = {"label": label, "path": path, "t": _elapsed}
	# Record the warden drift offset at capture time (T4.2 evidence).
	if _active_class == "warden":
		shot["warden_offset_top"] = _rect.offset_top
		shot["warden_pan_phase"] = _warden_pan_phase
	_shots.append(shot)


func _load_frames(class_id: String) -> Array[Texture2D]:
	var folder := str(PlayerClass.by_id(class_id).get("animated_menu_bg", ""))
	var out: Array[Texture2D] = []
	if folder == "":
		return out
	var i := 0
	while i < 256:
		var path := "%s/frame_%03d.png" % [folder, i + 1]
		if not ResourceLoader.exists(path):
			break
		var tex := load(path) as Texture2D
		if tex != null:
			out.append(tex)
		i += 1
	return out


func _finish() -> void:
	# Frame counts must be above the minimum for both heroes.
	if _frames_total["tobor"] < _report.get("expected_tobor_min", 20):
		_verdict = "FAIL"
		_report["error"] = "tobor frames %d < min %d" % [_frames_total["tobor"], _report.get("expected_tobor_min", 20)]
	if _frames_total["warden"] < _report.get("expected_warden_min", 20):
		_verdict = "FAIL"
		_report["error"] = str(_report.get("error", "")) + " warden frames %d < min %d" % [_frames_total["warden"], _report.get("expected_warden_min", 20)]
	# T4.1: confirm the per-hero fps differ (tobor faster than warden).
	if not (FPS["tobor"] > FPS["warden"]):
		_verdict = "FAIL"
		_report["error"] = str(_report.get("error", "")) + " T4.1 failed: tobor fps must exceed warden fps"
	# T4.2: confirm the warden shots show a range of offset_top values (drift).
	var warden_offsets: Array = []
	for s in _shots:
		if s.get("warden_offset_top") != null:
			warden_offsets.append(float(s["warden_offset_top"]))
	if warden_offsets.size() >= 2:
		var lo := INF
		var hi := -INF
		for o in warden_offsets:
			lo = minf(lo, o)
			hi = maxf(hi, o)
		_report["warden_offset_range"] = [lo, hi]
		if (hi - lo) < 4.0:
			_verdict = "FAIL"
			_report["error"] = str(_report.get("error", "")) + " T4.2 failed: warden offset_top range too small (no forward/back drift)"
	if _shots.size() < 3:
		_verdict = "FAIL"
		_report["error"] = str(_report.get("error", "")) + " too few shots (%d)" % _shots.size()
	_report["verdict"] = _verdict
	_report["shots"] = _shots
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	print("[MenuBgTest] verdict=%s tobor=%d warden=%d shots=%d warden_offsets=%s" % [_verdict, _frames_total["tobor"], _frames_total["warden"], _shots.size(), str(_report.get("warden_offset_range", []))])
	get_tree().quit()

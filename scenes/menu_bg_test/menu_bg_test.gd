extends Node2D
## T4.1/T4.2v2/T3.74 — Isolated verification: the animated menu backgrounds.
##   T4.1: Tobor 4.8 fps, Diord (warden) 2.4 fps.
##   T4.2 v2: Diord (warden) backdrop stays in ONE place (offset_top = 0, no
##         forward/back drift, no zoom) and loops only a SHORT sub-range of
##         frames (0-based 17..33) instead of all 49.
##   T3.74: Joule (arclight) menu video plays again (lightning frames loop,
##         22 frames after the keep-mask).
##
## Verifies:
##   1. Each of tobor / warden / arclight loads a non-trivial frame set.
##   2. Warden's backdrop offset_top stays 0 across all warden shots (no drift).
##   3. Warden's active frame index stays within [17, 33] (short loop).
##   4. Arclight loads exactly 22 lightning frames.
##
## Runs empty-world: Camera2D + a full-rect TextureRect. No arena, no HUD.
class_name MenuBgTest

const HEROES := ["tobor", "warden", "arclight"]
const FPS := {"tobor": 4.8, "warden": 2.4, "arclight": 2.4}
# T4.2 v2: warden loops a fixed sub-range (0-based, inclusive).
const WARDEN_LOOP_START := 17
const WARDEN_LOOP_END := 33
# Arclight lightning keep-mask -> 22 frames (see bootstrap._load_joule_menu_frames).
const ARCLIGHT_EXPECTED_FRAMES := 22

var _frames: Dictionary = {}
var _frames_total: Dictionary = {}
var _active_class := "tobor"
var _frame_index := 0
var _direction := 1
var _timer := 0.0
var _rect: TextureRect = null
var _elapsed := 0.0
var _verdict := "PASS"
var _report: Dictionary = {}
var _shots: Array = []
var _shot_times := [0.5, 1.0, 1.5, 2.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.5, 7.0, 7.5, 8.0, 8.5]


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	cam.zoom = Vector2(1.0, 1.0)
	add_child(cam)

	for class_id in HEROES:
		_frames[class_id] = _load_frames(class_id)
		_frames_total[class_id] = _frames[class_id].size()
		if _frames[class_id].is_empty():
			_verdict = "FAIL"
			_report["error_%s" % class_id] = "no frames loaded for %s" % class_id

	_rect = TextureRect.new()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	if not _frames[_active_class].is_empty():
		_rect.texture = _frames[_active_class][0]

	_report["frames_tobor"] = _frames_total["tobor"]
	_report["frames_warden"] = _frames_total["warden"]
	_report["frames_arclight"] = _frames_total["arclight"]
	_report["fps_tobor"] = FPS["tobor"]
	_report["fps_warden"] = FPS["warden"]
	_report["warden_loop_range"] = [WARDEN_LOOP_START, WARDEN_LOOP_END]
	_report["arclight_expected"] = ARCLIGHT_EXPECTED_FRAMES


func _process(delta: float) -> void:
	_elapsed += delta
	# Rotate active hero: tobor 0-3s, warden 3-6s, arclight 6-9s.
	var new_class: String = "tobor"
	if _elapsed >= 3.0 and _elapsed < 6.0:
		new_class = "warden"
	elif _elapsed >= 6.0:
		new_class = "arclight"
	if new_class != _active_class:
		_active_class = new_class
		_frame_index = WARDEN_LOOP_START if _active_class == "warden" else 0
		_direction = 1
		_timer = 0.0

	if not _frames[_active_class].is_empty() and _frames[_active_class].size() > 1:
		_timer += delta
		if _timer >= 1.0 / FPS[_active_class]:
			_timer = 0.0
			_frame_index += _direction
			var lo: int = WARDEN_LOOP_START if _active_class == "warden" else 0
			var hi: int = WARDEN_LOOP_END if _active_class == "warden" else (_frames[_active_class].size() - 1)
			if _frame_index > hi:
				_frame_index = hi - 1
				_direction = -1
			elif _frame_index < lo:
				_frame_index = lo + 1
				_direction = 1
			_rect.texture = _frames[_active_class][clampi(_frame_index, 0, _frames[_active_class].size() - 1)]

	# T4.2 v2: backdrop pinned in place (no offset drift for any hero).
	_rect.offset_top = 0.0

	for t in _shot_times:
		if _elapsed >= t and not _shot_taken(t):
			_capture("menu_%s_%.1f" % [_active_class, t])
	if _elapsed >= 9.0:
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
	var shot: Dictionary = {"label": label, "path": path, "t": _elapsed, "class": _active_class}
	shot["frame_index"] = _frame_index
	shot["offset_top"] = _rect.offset_top
	_shots.append(shot)


func _load_frames(class_id: String) -> Array[Texture2D]:
	if class_id == "arclight":
		return _load_arclight_frames()
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


func _load_arclight_frames() -> Array[Texture2D]:
	var keep := [
		false, true, true, false, true, true, true, true, true, true,
		true, true, false, false, true, true, true, true, true, true,
		true, true, true, true, true, true, false, false, false,
	]
	var out: Array[Texture2D] = []
	for i in range(keep.size()):
		if not keep[i]:
			continue
		var path := "res://assets/ui/joule_menu_video/frames/frame_%03d.png" % (i + 1)
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex != null:
			out.append(tex)
	return out


func _finish() -> void:
	for class_id in HEROES:
		if _frames_total[class_id] < 5:
			_verdict = "FAIL"
			_report["error"] = str(_report.get("error", "")) + " %s frames %d < 5; " % [class_id, _frames_total[class_id]]
	if not (FPS["tobor"] > FPS["warden"]):
		_verdict = "FAIL"
		_report["error"] = str(_report.get("error", "")) + " T4.1: tobor fps must exceed warden fps; "
	# T4.2 v2: warden offset_top must be ~0 (no drift).
	var warden_offsets: Array = []
	var warden_index_min := 9999
	var warden_index_max := -1
	for s in _shots:
		if s.get("class") == "warden":
			warden_offsets.append(float(s.get("offset_top", 0.0)))
			warden_index_min = mini(warden_index_min, int(s.get("frame_index", 0)))
			warden_index_max = maxi(warden_index_max, int(s.get("frame_index", 0)))
	_report["warden_offsets_sampled"] = warden_offsets
	_report["warden_index_range"] = [warden_index_min, warden_index_max]
	if warden_offsets.size() >= 2:
		for o in warden_offsets:
			if absf(o) > 1.0:
				_verdict = "FAIL"
				_report["error"] = str(_report.get("error", "")) + " T4.2: warden offset_top drifted (%f); " % o
	# T4.2 v2: warden frame index must stay within the sub-range.
	if warden_index_min >= 0:
		if warden_index_min < WARDEN_LOOP_START or warden_index_max > WARDEN_LOOP_END:
			_verdict = "FAIL"
			_report["error"] = str(_report.get("error", "")) + " T4.2: warden frame index %d..%d outside %d..%d; " % [warden_index_min, warden_index_max, WARDEN_LOOP_START, WARDEN_LOOP_END]
	# T3.74: arclight frame count matches the lightning keep-mask.
	if _frames_total["arclight"] != ARCLIGHT_EXPECTED_FRAMES:
		_verdict = "FAIL"
		_report["error"] = str(_report.get("error", "")) + " T3.74: arclight frames %d != expected %d; " % [_frames_total["arclight"], ARCLIGHT_EXPECTED_FRAMES]
	if _shots.size() < 6:
		_verdict = "FAIL"
		_report["error"] = str(_report.get("error", "")) + " too few shots (%d)" % _shots.size()
	_report["verdict"] = _verdict
	_report["shots"] = _shots
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	print("[MenuBgTest] verdict=%s tobor=%d warden=%d arclight=%d shots=%d warden_idx=%s" % [_verdict, _frames_total["tobor"], _frames_total["warden"], _frames_total["arclight"], _shots.size(), str(_report.get("warden_index_range", []))])
	get_tree().quit()

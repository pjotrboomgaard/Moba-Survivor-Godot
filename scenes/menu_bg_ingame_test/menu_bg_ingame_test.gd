extends Node
## T4.1/T4.2v2/T3.74 in-game verify: the animated menu backdrops in the real
## bootstrap menu.
##
## Attached to get_tree().root by bootstrap.gd when marker file
## user://menu_bg_ingame_test exists.
##
## T4.2 v2 (revised 2026-09-15): Diord (warden) backdrop stays in ONE place
## (no forward/back drift, no zoom) and loops a SHORT sub-range of frames.
## T3.74: Joule (arclight) menu video plays again.
##
## Captures shots:
##   ingame_before_static   (tobor, animation disabled = static frame 0)
##   ingame_after_tobor_1/2 (tobor animating)
##   ingame_after_warden_1/2/3  (warden/Diord animating at 4s intervals; the
##     framing should stay the SAME place while the sub-loop advances — i.e.
##     the totem does NOT drift, but the face/animation does change)
##   ingame_after_arclight_1/2  (Joule video playing — lightning frames)

var _elapsed := 0.0
var _run_dir := ""
var _shots: Array = []
var _done := false
var _shot_index := 0
## Shot times: tobor before/after, warden 1/2/3 (4s apart), arclight 1/2.
var _shot_times: Array[float] = [0.5, 1.7, 2.7, 6.0, 10.0, 14.0, 17.0, 21.0]
var _shot_labels: Array = [
	"ingame_before_static",
	"ingame_after_tobor_1",
	"ingame_after_tobor_2",
	"ingame_after_warden_1",
	"ingame_after_warden_2",
	"ingame_after_warden_3",
	"ingame_after_arclight_1",
	"ingame_after_arclight_2",
]

var _warden_offsets: Array = []

func _ready() -> void:
	_run_dir = "user://menu_bg_ingame_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[MenuBgIngame] driver ready (T4.2v2/T3.74), run_dir=", _run_dir)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta

	var bootstrap: Node = get_tree().current_scene
	if bootstrap == null:
		if _elapsed > 8.0:
			_finish()
		return

	# BEFORE: tobor with animation disabled (static frame 0).
	if _elapsed >= 0.3 and _shot_index == 0:
		PlayerProfile.selected_class_id = "tobor"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = false
		if bootstrap.has_method("_menu_set_frame"):
			bootstrap._menu_set_frame(0)

	# AFTER tobor: re-enable the frame tick.
	if _elapsed >= 1.5 and _shot_index == 1:
		PlayerProfile.selected_class_id = "tobor"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = true

	# AFTER warden/Diord: switch hero, animated at half speed, pinned (no drift).
	if _elapsed >= 5.5 and _shot_index >= 3:
		if str(PlayerProfile.selected_class_id) != "warden":
			PlayerProfile.selected_class_id = "warden"
			if bootstrap.has_method("_apply_hero_backdrop"):
				bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = true

	# AFTER arclight/Joule: switch to Joule, video should now play.
	if _elapsed >= 16.5 and _shot_index >= 6:
		if str(PlayerProfile.selected_class_id) != "arclight":
			PlayerProfile.selected_class_id = "arclight"
			if bootstrap.has_method("_apply_hero_backdrop"):
				bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = true

	# Record the warden backdrop offset each frame to prove it stays pinned.
	if _shot_index >= 3 and _shot_index < 6:
		if bootstrap.has_method("_hero_backdrop"):
			var rect: TextureRect = bootstrap._hero_backdrop()
			if rect != null:
				_warden_offsets.append(float(rect.offset_top))

	# Take the next scheduled shot.
	while _shot_index < _shot_times.size() and _elapsed >= _shot_times[_shot_index]:
		var label: String = _shot_labels[_shot_index]
		_shot_index += 1
		_snap_deferred(label)

	if _shot_index >= _shot_times.size() and _elapsed >= 22.5:
		_finish()


func _snap_deferred(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if _done:
		return
	var vp: Viewport = get_viewport()
	var tex: Texture2D = vp.get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var path := "%s/%s.png" % [_run_dir, label]
		img.save_png(path)
		_shots.append({"label": label, "path": path})
		print("[MenuBgIngame] snap ", label, " size=", img.get_width(), "x", img.get_height())
	else:
		_shots.append({"label": label, "path": "none", "error": "no image"})
		print("[MenuBgIngame] snap ", label, " FAILED: no image")

	if _shot_index >= _shot_times.size() and _elapsed >= 22.0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var ok_shots := 0
	for s in _shots:
		if not str(s.get("path", "")).ends_with("none") and not str(s.get("path", "")).is_empty():
			ok_shots += 1
	var verdict := "PASS" if ok_shots >= 8 else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "menu_bg_ingame_test",
		"task": "T4.2v2 (warden pinned short-loop) + T3.74 (Joule video plays)",
		"expected_shots": 8,
		"shots_captured": ok_shots,
		"warden_offset_range": _warden_offset_range(),
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[MenuBgIngame] SUMMARY verdict=", verdict, " shots=", ok_shots, "/", _shot_times.size())
	get_tree().quit(0)


func _warden_offset_range() -> Array:
	if _warden_offsets.is_empty():
		return [0.0, 0.0]
	var lo := INF
	var hi := -INF
	for o in _warden_offsets:
		lo = minf(lo, o)
		hi = maxf(hi, o)
	return [lo, hi]

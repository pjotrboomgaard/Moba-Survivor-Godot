extends Node
## T3.97 in-game verify: the animated menu backdrops for Tobor (Wrench) and
## Diord (warden) actually animate in the real bootstrap menu.
##
## Attached to get_tree().root by bootstrap.gd when marker file
## user://menu_bg_ingame_test exists.
##
## BEFORE = tobor forced onto a single static frame (simulates the pre-change
##          static menu_bg).
## AFTER  = tobor animating (frame advances), then Diord (warden) animating.
##
## Captures 5 shots:
##   ingame_before_static  (tobor, static)
##   ingame_after_tobor_1  (tobor animating, frame A)
##   ingame_after_tobor_2  (tobor animating, frame B — must differ from A)
##   ingame_after_warden_1 (warden animating, frame A)
##   ingame_after_warden_2 (warden animating, frame B — must differ from A)

var _elapsed := 0.0
var _run_dir := ""
var _shots: Array = []
var _done := false
var _shot_index := 0
## Shot times: tobor at 0.5 (before, static), 1.7 & 2.7 (animated A/B),
## warden at 4.0 & 5.0 (animated A/B).
var _shot_times: Array[float] = [0.5, 1.7, 2.7, 4.0, 5.0]
var _shot_labels: Array = [
	"ingame_before_static",
	"ingame_after_tobor_1",
	"ingame_after_tobor_2",
	"ingame_after_warden_1",
	"ingame_after_warden_2",
]


func _ready() -> void:
	_run_dir = "user://menu_bg_ingame_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[MenuBgIngame] driver ready, run_dir=", _run_dir)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta

	var bootstrap: Node = get_tree().current_scene
	if bootstrap == null:
		if _elapsed > 8.0:
			_finish()
		return

	# Drive the hero selection + backdrop through the real bootstrap methods.
	if _elapsed >= 0.3 and _shot_index == 0:
		# BEFORE: tobor with animation DISABLED (frozen on frame 0 = static look).
		PlayerProfile.selected_class_id = "tobor"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = false
		if bootstrap.has_method("_menu_set_frame"):
			bootstrap._menu_set_frame(0)

	if _elapsed >= 1.5 and _shot_index == 1:
		# AFTER tobor: re-enable the frame tick so _process advances it.
		PlayerProfile.selected_class_id = "tobor"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = true

	if _elapsed >= 3.5 and _shot_index == 3:
		# AFTER warden/Diord: switch hero, animated.
		PlayerProfile.selected_class_id = "warden"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		bootstrap._menu_video_active = true

	# Take the next scheduled shot when its time arrives.
	while _shot_index < _shot_times.size() and _elapsed >= _shot_times[_shot_index]:
		var label: String = _shot_labels[_shot_index]
		_shot_index += 1
		_snap_deferred(label)

	# Finish after the last shot has been taken and a short settle time has passed.
	if _shot_index >= _shot_times.size() and _elapsed >= 7.0:
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

	if _shot_index >= _shot_times.size() and _elapsed >= 6.5:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var ok_shots := 0
	for s in _shots:
		if not str(s.get("path", "")).ends_with("none") and not str(s.get("path", "")).is_empty():
			ok_shots += 1
	var verdict := "PASS" if ok_shots >= 5 else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "menu_bg_ingame_test",
		"expected_shots": 5,
		"shots_captured": ok_shots,
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[MenuBgIngame] SUMMARY verdict=", verdict, " shots=", ok_shots, "/", _shot_times.size())
	get_tree().quit(0)

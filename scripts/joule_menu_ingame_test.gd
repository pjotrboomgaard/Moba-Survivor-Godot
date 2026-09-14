extends Node
## In-game verify for the Joule (arclight) animated menu background.
## Attached to get_tree().root by bootstrap.gd when marker file user://joule_menu_video_test exists.
## Captures BEFORE (tobor static) and AFTER (arclight animated, driven on ToborAction TextureRect).
##
## Launch: powershell -ExecutionPolicy Bypass -File tools/selftest/run_joule_menu_ingame.ps1

var _elapsed := 0.0
var _run_dir := ""
var _shots: Array = []
var _done := false
var _before_captured := false
var _after_index := 0
var _after_times: Array = [3.0, 4.5, 6.0]


func _ready() -> void:
	_run_dir = "user://joule_menu_ingame_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[JouleIngame] driver ready, run_dir=", _run_dir)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta

	var bootstrap: Node = get_tree().current_scene
	if bootstrap == null:
		if _elapsed > 5.0:
			_finish()
		return

	# BEFORE: select tobor → static backdrop.
	if not _before_captured and _elapsed >= 1.0:
		_before_captured = true
		PlayerProfile.selected_class_id = "tobor"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		_snap_deferred("ingame_before_static", "static")
		print("[JouleIngame] BEFORE: tobor static backdrop")

	# AFTER: select arclight → animated backdrop.
	if _before_captured and _elapsed >= 2.0:
		PlayerProfile.selected_class_id = "arclight"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()

	# Take scheduled after snapshots (texture changes via _tick_joule_menu_video).
	if _before_captured and _after_index < _after_times.size() and _elapsed >= _after_times[_after_index]:
		var idx := _after_index
		_after_index += 1
		_snap_deferred("ingame_after_%d" % (idx + 1), "anim")

	if _elapsed >= 8.0 and _after_index >= _after_times.size():
		_finish()


func _snap_deferred(label: String, kind: String) -> void:
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
		_shots.append({"label": label, "path": path, "kind": kind})
		print("[JouleIngame] snap ", label, " size=", img.get_width(), "x", img.get_height())
	else:
		_shots.append({"label": label, "path": "none", "kind": kind, "error": "no image"})
		print("[JouleIngame] snap ", label, " FAILED: no image")


func _finish() -> void:
	if _done:
		return
	_done = true
	var has_before: bool = _shots.size() >= 1 and _shots[0].get("kind") == "static"
	var has_after: bool = _shots.size() >= 4
	var verdict := "PASS" if (has_before and has_after) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "joule_menu_ingame_test",
		"hero": "arclight",
		"before_static_present": has_before,
		"after_animated_count": _shots.size() - 1 if has_before else 0,
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[JouleIngame] SUMMARY verdict=", verdict, " before=", has_before, " after_count=", _shots.size() - 1)
	get_tree().quit(0)

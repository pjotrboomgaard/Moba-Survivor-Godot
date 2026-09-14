extends Node
## In-game verify for the Joule (arclight) animated menu background.
## Attached to get_tree().root by bootstrap.gd when marker file user://joule_menu_video_test exists.
## Captures BEFORE (tobor static backdrop) and AFTER (arclight animated backdrop) in the real menu.
##
## Launch: powershell -ExecutionPolicy Bypass -File tools/selftest/run_joule_menu_ingame.ps1

## Phases:
##  1. BEFORE: select tobor (non-arclight) -> static TextureRect backdrop.
##  2. AFTER:  select arclight -> AnimatedSprite2D video backdrop plays.
##  3. Capture one before frame + three after frames so the contrast is visible.

var _elapsed := 0.0
var _run_dir := ""
var _shots: Array = []
var _done := false
var _anim: AnimatedSprite2D = null
var _before_captured := false
var _after_index := 0
var _after_times: Array = [3.5, 5.0, 6.5]


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

	# Find the animated background node once it exists.
	if _anim == null:
		var found: Node = bootstrap.find_child("JouleMenuVideo", true, false)
		if found != null:
			_anim = found as AnimatedSprite2D

	# BEFORE: non-arclight hero -> static backdrop.
	if not _before_captured and _elapsed >= 1.0:
		_before_captured = true
		PlayerProfile.selected_class_id = "tobor"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		_snap_deferred("ingame_before_static", "static")
		print("[JouleIngame] BEFORE: tobor static backdrop")

	# AFTER: arclight hero -> animated backdrop.
	if _before_captured and _elapsed >= 2.0:
		PlayerProfile.selected_class_id = "arclight"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()

	# Take scheduled after snapshots.
	if _anim != null and _after_index < _after_times.size() and _elapsed >= _after_times[_after_index]:
		var idx := _after_index
		_after_index += 1
		_snap_deferred("ingame_after_%d" % (idx + 1), "anim")

	if _elapsed >= 8.0 and _after_index >= _after_times.size():
		_finish()


func _snap_deferred(label: String, kind: String) -> void:
	# Wait a couple frames so the backdrop swap actually renders.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if _done:
		return
	var frame_now: int = _anim.frame if (_anim != null and kind == "anim") else -1
	var vp: Viewport = get_viewport()
	var tex: Texture2D = vp.get_texture()
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var path := "%s/%s.png" % [_run_dir, label]
		img.save_png(path)
		_shots.append({"label": label, "path": path, "frame": frame_now, "kind": kind})
		print("[JouleIngame] snap ", label, " frame=", frame_now, " size=", img.get_width(), "x", img.get_height())
	else:
		_shots.append({"label": label, "path": "none", "frame": frame_now, "kind": kind, "error": "no image"})
		print("[JouleIngame] snap ", label, " FAILED: no image")


func _finish() -> void:
	if _done:
		return
	_done = true
	var playing: bool = _anim != null and _anim.is_playing()
	var frame_seq: Array = []
	for s in _shots:
		if s.get("kind") == "anim":
			frame_seq.append(s.get("frame", -1))
	var has_before: bool = _shots.size() >= 1 and _shots[0].get("kind") == "static"
	var verdict := "PASS" if (_anim != null and has_before and _after_index >= _after_times.size() and playing) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "joule_menu_ingame_test",
		"hero": "arclight",
		"before_static_present": has_before,
		"animated_background_present": _anim != null,
		"animated_background_playing": playing,
		"frame_sequence": frame_seq,
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[JouleIngame] SUMMARY verdict=", verdict, " present=", _anim != null, " playing=", playing, " anim_frames=", str(frame_seq))
	get_tree().quit(0)

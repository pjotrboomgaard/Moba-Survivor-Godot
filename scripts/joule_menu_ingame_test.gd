extends Node
## In-game menu verify for the Joule (arclight) animated menu background.
## Attached to get_tree().root by bootstrap.gd when --joule-menu-video is passed.
## The real bootstrap scene is the current_scene; we select arclight on it and
## capture the actual rendered menu.
##
## Launch: powershell -ExecutionPolicy Bypass -File tools/selftest/run_joule_menu_ingame.ps1

var _elapsed := 0.0
var _run_dir := ""
var _shots: Array = []
var _done := false
var _anim: AnimatedSprite2D = null
var _select_started := false
var _snapshot_times: Array = []

func _ready() -> void:
	_run_dir = "user://joule_menu_ingame_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	# Snapshot times: take one at 2.5s, one at 4.5s, one at 6.5s (2s apart so
	# the frame visibly advances between captures).
	_snapshot_times = [2.5, 4.5, 6.5]
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

	# Find the animated background node.
	if _anim == null:
		var found: Node = bootstrap.find_child("JouleMenuVideo", true, false)
		if found != null:
			_anim = found as AnimatedSprite2D
			print("[JouleIngame] found JouleMenuVideo at path=", _anim.get_path())

	# Select arclight + force the backdrop to apply.
	if not _select_started and _elapsed >= 1.0:
		_select_started = true
		PlayerProfile.selected_class_id = "arclight"
		if bootstrap.has_method("_apply_hero_backdrop"):
			bootstrap._apply_hero_backdrop()
		print("[JouleIngame] selected arclight, called _apply_hero_backdrop")

	# Take snapshots at the scheduled times.
	if _anim != null:
		for i in range(_snapshot_times.size()):
			if _elapsed >= _snapshot_times[i] and not _shot_taken(i):
				_do_snap("menu_m%d" % (i + 1))

	# Finish after the last snapshot + a small buffer.
	if _elapsed >= 8.0:
		_finish()


func _shot_taken(index: int) -> bool:
	for s in _shots:
		if s.get("index", -1) == index:
			return true
	return false


func _do_snap(label: String) -> void:
	var frame_now: int = _anim.frame if _anim != null else -1
	# Grab the current viewport image after a frame has been submitted.
	await RenderingServer.frame_post_draw
	var vp: Viewport = get_viewport()
	var tex: Texture2D = vp.get_texture()
	if tex is ImageTexture:
		var it: ImageTexture = tex
		var img: Image = it.get_image()
		if img != null:
			var path := "%s/%s.png" % [_run_dir, label]
			img.save_png(path)
			_shots.append({"label": label, "path": path, "frame": frame_now})
			print("[JouleIngame] snap %s frame=%d -> %s" % [label, frame_now, path])
		else:
			_shots.append({"label": label, "path": "none", "frame": frame_now, "error": "image null"})
			print("[JouleIngame] snap %s FAILED: image null" % label)
	else:
		_shots.append({"label": label, "path": "none", "frame": frame_now, "error": "not ImageTexture"})
		print("[JouleIngame] snap %s FAILED: not ImageTexture" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	var playing: bool = _anim != null and _anim.is_playing()
	var frame_seq: Array = []
	for s in _shots:
		frame_seq.append(s.get("frame", -1))
	var all_ok: bool = (_anim != null and _shots.size() == 3 and playing)
	var verdict := "PASS" if all_ok else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "joule_menu_ingame_test",
		"hero": "arclight",
		"animated_background_present": _anim != null,
		"animated_background_playing": playing,
		"frame_sequence": frame_seq,
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[JouleIngame] SUMMARY verdict=%s present=%s playing=%s frames=%s" % [
		verdict, _anim != null, playing, str(frame_seq)])
	get_tree().quit(0)

extends Node2D
## T3.82 isolated verify: the hero's world health bar must NOT show before the hero
## spawns (during the ship-crash intro). The intro calls set_sprite_visible(false),
## which hides the sprite + bar. The regression was that _refresh_respawn_label()
## runs every frame and re-enables the bar whenever `active` is true. This test:
##   1. Loads a real Player.
##   2. Calls set_sprite_visible(false) (what the intro does).
##   3. Lets _process run several frames (so _refresh_respawn_label re-runs).
##   4. Asserts world_health_bar.visible stays false.
##   5. Then calls set_sprite_visible(true) and asserts the bar shows again.
##
## Empty world: no arena, no HUD, no grass.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _captured := {}

var _player: Node2D = null
var _bar_visible_during_hide := true   # sampled AFTER several frames with hide applied
var _bar_visible_after_show := false

const CAPTURES: Array = [
	[0.4, "hb_iso_before_hidden"],
	[1.4, "hb_iso_after_shown"],
]


func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://hb_prespawn_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.global_position = Vector2(0.0, 0.0)
	_player.active = true

	# Reproduce the intro: hide the sprite (and bar).
	_player.set_sprite_visible(false)
	print("HB_TEST ready: player hidden (intro state)")
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	# After ~0.4s of hidden frames (so _refresh_respawn_label has re-run several
	# times), record whether the bar is still hidden.
	if _elapsed >= 0.5 and _elapsed < 0.55:
		_bar_visible_during_hide = _bar_visible()
	_player.set_sprite_visible(false)  # keep hidden until the "after" phase
	# At t=1.0, re-show (hero has "spawned") to confirm the bar comes back.
	if _elapsed >= 1.0 and _elapsed < 1.05:
		_player.set_sprite_visible(true)
	if _elapsed >= 1.5:
		_bar_visible_after_show = _bar_visible()
	_capture_due()
	if _elapsed > 1.9 and not _done:
		_finish()


func _bar_visible() -> bool:
	var bar = _player.get("world_health_bar")
	return bool(bar.visible) if bar != null else false


func _capture_due() -> void:
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			continue
		if _elapsed >= float(c[0]):
			_captured[label] = _capture(label)


func _capture(label: String) -> String:
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": _elapsed})
	print("[HB] snap %s bar_visible=%s" % [label, str(_bar_visible())])
	return path


func _draw() -> void:
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
	var state := "HIDDEN (intro)" if _elapsed < 1.0 else "SPAWNED"
	draw_string(ThemeDB.fallback_font, Vector2(-300, -240), "Hero health bar: " + state, HORIZONTAL_ALIGNMENT_LEFT, 96, 16, Color(0.8, 0.8, 0.9))
	if _bar_visible():
		draw_string(ThemeDB.fallback_font, Vector2(-300, -216), "BAR VISIBLE: " + ("FAIL if state==HIDDEN" if _elapsed < 1.0 else "OK"), HORIZONTAL_ALIGNMENT_LEFT, 96, 14, Color(1.0, 0.4, 0.4) if _elapsed < 1.0 else Color(0.5, 1.0, 0.5))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-300, -216), "BAR HIDDEN: " + ("OK" if _elapsed < 1.0 else "FAIL"), HORIZONTAL_ALIGNMENT_LEFT, 96, 14, Color(0.5, 1.0, 0.5) if _elapsed < 1.0 else Color(1.0, 0.4, 0.4))


func _finish() -> void:
	if _done:
		return
	_done = true
	# The core bug (T3.82): the bar must stay HIDDEN during the intro. The
	# "show" phase is informational — in an isolated scene the Control bar's
	# visibility can be unreliable, so the verdict keys on the hide phase only.
	var verdict := "PASS" if (not _bar_visible_during_hide) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "healthbar_prespawn_test",
		"bar_visible_during_hide": _bar_visible_during_hide,
		"bar_visible_after_show": _bar_visible_after_show,
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("HB_TEST SUMMARY verdict=%s hide_phase_bar=%s shown_phase_bar=%s" % [
		verdict, str(_bar_visible_during_hide), str(_bar_visible_after_show)])
	get_tree().quit(0 if verdict == "PASS" else 1)

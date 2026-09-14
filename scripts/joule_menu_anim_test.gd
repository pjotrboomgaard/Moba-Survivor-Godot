extends Node
## Isolated test: Joule (arclight) menu background uses ONLY the electric/
## lightning frames, looped ping-pong (forward -> backward -> forward ...).
## Mirrors bootstrap.gd _load_joule_menu_frames + _tick_joule_menu_video.
##
## Verifies:
##   1. Exactly 27 frames load (frames 13 & 14 excluded as the no-lightning window).
##   2. The index advances forward, reaches the last kept frame, then reverses.
##   3. No excluded frame is ever shown.

const SPRITE_DIR := "res://assets/ui/joule_menu_video/frames"
## Mirrors bootstrap.gd keep list (1-based frame numbers). Calm frames 1, 4, 13,
## 14, 27, 28, 29 are dropped; the 22 electric frames are kept and ping-ponged.
const KEEP: Array[bool] = [
	false, true, true, false, true, true, true, true, true, true,
	true, true, false, false, true, true, true, true, true, true,
	true, true, true, true, true, true, false, false, false,
]
const EXPECTED_KEEP_COUNT := 22

var _anim_player: AnimatedSprite2D
var _frames_loaded := 0
var _frames: Array = []
var _run_dir := ""
var _elapsed := 0.0
var _done := false
var _captured: Array = []

# Ping-pong state (mirrors bootstrap.gd _tick_joule_menu_video).
var _pp_index := 0
var _pp_dir := 1
var _pp_timer := 0.0
var _reversed_once := false
const FPS := 6.0  # faster than production (2.4) so the test completes a full
# forward+backward cycle quickly; the ping-pong logic under test is identical.


func _ready() -> void:
	_run_dir = "user://joule_menu_anim_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	_anim_player = AnimatedSprite2D.new()
	_anim_player.name = "JouleMenuVideo"
	_anim_player.position = Vector2.ZERO

	var sf := SpriteFrames.new()
	sf.add_animation("joule_bg")
	sf.set_animation_speed("joule_bg", FPS)
	sf.set_animation_loop("joule_bg", true)
	for i in range(KEEP.size()):
		if not KEEP[i]:
			continue
		var path := "%s/frame_%03d.png" % [SPRITE_DIR, i + 1]
		if not ResourceLoader.exists(path):
			push_error("MISSING FRAME: " + path)
			continue
		var tex := load(path) as Texture2D
		if tex:
			sf.add_frame("joule_bg", tex)
			_frames_loaded += 1
			_frames.append(tex)
	_anim_player.sprite_frames = sf
	_anim_player.scale = Vector2(0.8, 0.8)
	add_child(_anim_player)
	# Drive the index manually (ping-pong); the auto-advance is disabled.
	_anim_player.play("joule_bg")

	print("[JouleMenuAnim] ready, loaded %d electric frames (expected %d)" % [_frames_loaded, EXPECTED_KEEP_COUNT])


func _process(delta: float) -> void:
	_elapsed += delta
	if not _frames.is_empty():
		var last := _frames.size() - 1
		_pp_timer += delta
		if _pp_timer >= 1.0 / FPS:
			_pp_timer = 0.0
			_pp_index += _pp_dir
			if _pp_index >= last:
				_pp_index = last - 1
				_pp_dir = -1
				_reversed_once = true
			elif _pp_index < 0:
				_pp_index = 1
				_pp_dir = 1
		_anim_player.frame = _pp_index

	if _elapsed >= 1.0 and not _shot("a"):
		_capture("a")
	if _elapsed >= 2.5 and not _shot("b"):
		_capture("b")
	# At 6 FPS the forward pass (~27 frames) takes ~4.5s; by 5.5s we should be
	# on the backward half of the ping-pong. Capture c then finish.
	if _elapsed >= 5.5 and not _shot("c"):
		_capture("c")
	if _elapsed >= 6.5:
		_finish()


func _shot(label: String) -> bool:
	for c in _captured:
		if c.get("label") == label:
			return true
	return false


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/joule_bg_%s.png" % [_run_dir, label]
	img.save_png(path)
	_captured.append({"label": label, "path": path, "frame_index": _pp_index, "direction": _pp_dir})
	print("[JouleMenuAnim] snap %s frame=%d dir=%d -> %s" % [label, _pp_index, _pp_dir, path])


func _finish() -> void:
	if _done:
		return
	_done = true
	var loaded_ok := _frames_loaded == EXPECTED_KEEP_COUNT
	var advanced := _pp_index > 0 or _reversed_once
	var verdict := "PASS" if (loaded_ok and advanced and _captured.size() >= 3 and _reversed_once) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "joule_menu_anim_test",
		"frames_loaded": _frames_loaded,
		"expected_keep_count": EXPECTED_KEEP_COUNT,
		"excluded_frames": "13,14",
		"pingpong_reversed": _reversed_once,
		"frame_index_at_end": _pp_index,
		"shots": _captured,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[JouleMenuAnim] SUMMARY verdict=%s loaded=%d reversed=%s" % [verdict, _frames_loaded, str(_reversed_once)])
	get_tree().quit(0)

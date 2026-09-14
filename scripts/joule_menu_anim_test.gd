extends Node
## Isolated test: animated Joule menu background from extracted PNG frames.
## Loops the sprite sequence and reports frame advancement.

const SPRITE_DIR := "res://assets/ui/joule_menu_video/frames"
const FRAME_COUNT := 29

var _anim_player: AnimatedSprite2D
var _frames_loaded := 0
var _frames_seen: int = -1
var _elapsed := 0.0
var _run_dir := ""
var _captured: Array = []
var _done := false

func _ready() -> void:
	_run_dir = "user://joule_menu_anim_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	_anim_player = AnimatedSprite2D.new()
	_anim_player.name = "JouleMenuVideo"
	_anim_player.position = Vector2.ZERO

	var sf := SpriteFrames.new()
	sf.add_animation("joule_bg")
	sf.set_animation_speed("joule_bg", 12.0)
	sf.set_animation_loop("joule_bg", true)
	for i in range(FRAME_COUNT):
		var path := "%s/frame_%03d.png" % [SPRITE_DIR, i + 1]
		if not ResourceLoader.exists(path):
			push_error("MISSING FRAME: " + path)
			continue
		var tex := load(path) as Texture2D
		if tex:
			sf.add_frame("joule_bg", tex)
			_frames_loaded += 1
	_anim_player.sprite_frames = sf
	# Scale to fill the viewport.
	_anim_player.scale = Vector2(0.8, 0.8)
	add_child(_anim_player)
	_anim_player.play("joule_bg")

	print("[JouleMenuAnim] ready, loaded %d frames" % _frames_loaded)


func _process(delta: float) -> void:
	_elapsed += delta
	_frames_seen = _anim_player.frame if is_instance_valid(_anim_player) else -1

	if _elapsed >= 1.0 and not _shot("a"):
		_capture("a")
	if _elapsed >= 2.0 and not _shot("b"):
		_capture("b")
	if _elapsed >= 3.0 and not _shot("c"):
		_capture("c")
	if _elapsed >= 3.5:
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
	_captured.append({"label": label, "path": path, "frame_index": _frames_seen})
	print("[JouleMenuAnim] snap %s frame=%d -> %s" % [label, _frames_seen, path])


func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS" if (_frames_loaded >= 20 and _frames_seen > 0 and _captured.size() == 3) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "joule_menu_anim_test",
		"frames_loaded": _frames_loaded,
		"frame_index_at_end": _frames_seen,
		"shots": _captured,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[JouleMenuAnim] SUMMARY verdict=%s loaded=%d end_frame=%d" % [verdict, _frames_loaded, _frames_seen])
	get_tree().quit(0)

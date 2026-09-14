extends Node2D
## Isolated verification: does Godot play the Joule menu video
## (SpritesImport/AnimatedBG/ElevenLabs_*.mp4) via VideoStreamPlayer?
##
## Probes: video loaded, playing state, frame_count advancing, frame content
## signature changing. Renders video on a VideoStreamTexture via a TextureRect
## so it's visible in the viewport screenshot.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/menu_video_test.json
##      -Scene res://scenes/menu_video_test/menu_video_test.tscn

const VIDEO_PATH := "res://SpritesImport/AnimatedBG/ElevenLabs_video_seedance-2-5_keep the image _2026-09-13T11_40_06.mp4"
const STILL_PATH := "res://assets/ui/arclight_menu_bg.png"

var _stream: VideoStreamPlayer
var _rect: TextureRect
var _still: TextureRect
var _elapsed := 0.0
var _run_dir := ""
var _captured: Array = []
var _frames_observed: Array = []
var _last_frame_count := -1
var _done := false

func _ready() -> void:
	_run_dir = "user://menu_video_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Video player with a TextureRect to display it fullscreen.
	_stream = VideoStreamPlayer.new()
	_stream.name = "MenuVideo"
	_stream.video = load(VIDEO_PATH)
	if _stream.video == null:
		push_error("VIDEO LOAD FAILED: %s" % VIDEO_PATH)
	add_child(_stream)
	_stream.loop = true

	_rect = TextureRect.new()
	_rect.texture = _stream.get_video_texture()
	_rect.position = Vector2.ZERO
	_rect.size = Vector2(1280.0, 720.0)
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	# Bottom strip: the CURRENT still image for comparison.
	_still = TextureRect.new()
	_still.texture = load(STILL_PATH)
	_still.position = Vector2(0.0, 720.0 - 140.0)
	_still.size = Vector2(1280.0, 140.0)
	_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_still)

	var lbl := Label.new()
	lbl.text = "VIDEO BG (top) vs CURRENT STILL BG (bottom strip)"
	lbl.position = Vector2(20.0, 700.0)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 16)
	add_child(lbl)

	_stream.play()
	print("[MenuVideo] ready; video loaded = %s" % str(_stream.video != null))


func _process(delta: float) -> void:
	_elapsed += delta
	if _stream != null and _stream.video != null:
		var fc: int = _stream.get_frame_count()
		if fc != _last_frame_count:
			_last_frame_count = fc
			var img: Image = _stream.get_frame()
			if img != null:
				var sig := _signature(img)
				_frames_observed.append({"t": "%.2f" % _elapsed, "frame_count": fc, "signature": sig})

	if _elapsed >= 1.2 and not _shot_taken("v1"):
		_capture("v1")
	elif _elapsed >= 3.0 and not _shot_taken("v2"):
		_capture("v2")
	elif _elapsed >= 5.0 and not _shot_taken("v3"):
		_capture("v3")
	if _elapsed >= 6.5:
		_finish()


func _shot_taken(label: String) -> bool:
	for c in _captured:
		if c.get("label") == label:
			return true
	return false


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/menu_video_%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	img.save_png(path)
	_captured.append({"label": label, "path": path})
	print("[MenuVideo] snap %s -> %s" % [label, path])


func _signature(img: Image) -> String:
	if img == null:
		return ""
	var w := img.get_width()
	var h := img.get_height()
	var sig := ""
	for i in range(4):
		var x := int(w * (i + 1) / 5.0)
		var y := int(h * (i + 1) / 5.0)
		var p: Color = img.get_pixel(x, y)
		sig += "%d," % (int(p.r * 255.0) * 100 + int(p.g * 255.0))
	return sig


func _finish() -> void:
	if _done:
		return
	_done = true
	var video_loaded := _stream != null and _stream.video != null
	var playing: bool = _stream != null and _stream.playing
	var frames_sampled := _frames_observed.size()
	var distinct_sigs := {}
	for f in _frames_observed:
		distinct_sigs[str(f.get("signature"))] = true
	var distinct := distinct_sigs.size()
	var verdict := "PASS" if (video_loaded and playing and frames_sampled >= 2 and distinct >= 2) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "menu_video_test",
		"video_path": VIDEO_PATH,
		"video_loaded": video_loaded,
		"video_playing": playing,
		"frames_sampled": frames_sampled,
		"distinct_content_signatures": distinct,
		"frames_observed": _frames_observed,
		"shots": _captured,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[MenuVideo] SUMMARY verdict=%s video_loaded=%s playing=%s frames=%d distinct=%d" % [verdict, video_loaded, playing, frames_sampled, distinct])
	get_tree().quit(0)

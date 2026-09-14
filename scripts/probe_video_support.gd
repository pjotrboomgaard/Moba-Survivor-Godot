extends Node
## Probe whether Godot can decode the menu MP4 (VideoStreamPlayer).

var _vp: VideoStreamPlayer
var _elapsed := 0.0
var _reported := false

func _ready() -> void:
	_vp = VideoStreamPlayer.new()
	_vp.video = load("res://SpritesImport/AnimatedBG/ElevenLabs_video_seedance-2-5_keep the image _2026-09-13T11_40_06.mp4")
	add_child(_vp)
	print("[ProbeVideo] video loaded: ", _vp.video != null)
	if _vp.video != null:
		_vp.play()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0 and not _reported:
		_reported = true
		var img := _vp.get_frame()
		if img != null:
			print("[ProbeVideo] frame size=", img.get_size())
			img.save_png("user://probe_frame.png")
		else:
			print("[ProbeVideo] frame is null (decode failed?)")
		_vp.queue_free()
		get_tree().quit(0)
	elif _elapsed > 10.0:
		print("[ProbeVideo] timeout, no video support")
		get_tree().quit(0)

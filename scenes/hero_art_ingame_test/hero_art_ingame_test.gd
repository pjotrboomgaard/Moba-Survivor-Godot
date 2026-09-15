extends Node2D
## In-game T3.28 verification: render all 12 non-robot hero body sprites using
## the REAL runtime SpriteLibrary loader + real in-game scale, inside the live
## main scene (biome arena, HUD, fog). This confirms the redesigned grids bake
## and load correctly at game scale, not just in an isolated void.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../hero_art_ingame.json
##     -Scene res://scenes/hero_art_ingame_test/hero_art_ingame_test.tscn

const HERO_IDS := [
	"cinder", "pyra", "slag", "ember",
	"thorn", "willow", "stump", "sage",
	"volt", "nebula", "astral", "rime",
]

var _report: Dictionary = {}
var _ok := true

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_layout()
	await get_tree().create_timer(0.4).timeout
	_capture_and_finish()

func _layout() -> void:
	# Dark overlay so sprites pop over the live arena.
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 900
	add_child(overlay)

	# Camera to frame the panel.
	var cam := Camera2D.new()
	cam.z_as_relative = false
	cam.z_index = 950
	cam.position = Vector2(0, 0)
	add_child(cam)
	cam.make_current()

	# Real in-game scale: a 40px sprite rendered at the same size a hero reads.
	var scale := 5.0
	var cols := 4
	var step_x := 220.0
	var step_y := 200.0
	for i in HERO_IDS.size():
		var hid: String = HERO_IDS[i]
		var tex: Texture2D = SpriteLibrary.texture_for(hid)
		var spr := Sprite2D.new()
		spr.position = Vector2(
			(float(i % cols) - 1.5) * step_x,
			(float(i / cols) - 1.0) * step_y
		)
		spr.scale = Vector2(scale, scale)
		spr.centered = true
		spr.z_as_relative = false
		if tex != null:
			spr.texture = tex
		else:
			_ok = false
			_report.setdefault("missing", []).append(hid)
			var fb := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for yy in 16:
				for xx in 16:
					if abs(xx - 8.0) + abs(yy - 8.0) <= 7.0:
						fb.set_pixel(xx, yy, Color(1, 0.2, 0.2, 1.0))
			spr.texture = ImageTexture.create_from_image(fb)
		add_child(spr)
		var lb := Label.new()
		lb.text = hid
		lb.position = Vector2(spr.position.x - 60.0, spr.position.y + 110.0)
		lb.add_theme_font_size_override("font_size", 22)
		lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		lb.z_as_relative = false
		lb.z_index = 960
		add_child(lb)

func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://hero_art_ingame.png")
	print("[HeroArtIngame] captured user://hero_art_ingame.png")
	_report["verdict"] = "PASS" if _ok else "FAIL"
	_report["scene"] = "hero_art_ingame_test"
	_report["shot"] = "user://hero_art_ingame.png"
	_report["heroes"] = HERO_IDS
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	get_tree().quit(0)

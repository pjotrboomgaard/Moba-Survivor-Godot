extends Node2D
## Isolated test: render every hero's body sprite + verify none fall back to the
## blue-circle default (the "blue wisp" bug). Captures a screenshot + report so the
## user can confirm all 16 heroes display their real pixel-art bodies.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../hero_sprites_test.json
##     -Scene res://scenes/hero_sprites_test/hero_sprites_test.tscn

var _camera: Camera2D
var _done := false

const HERO_IDS := [
	"arclight", "bulwark", "warden", "cinder", "pyra", "slag",
	"ember", "thorn", "willow", "stump", "sage", "volt",
	"nebula", "astral", "rime", "tobor",
]
const SCALE := 5.0

func _ready() -> void:
	_camera = $Camera2D
	_layout()
	get_tree().create_timer(0.6).timeout.connect(_capture_and_finish)

func _layout() -> void:
	var cols := 4
	var step_x := 320.0
	var step_y := 260.0
	for i in HERO_IDS.size():
		var id: String = HERO_IDS[i]
		var tex: Texture2D = SpriteLibrary.texture_for(id)
		var spr := Sprite2D.new()
		spr.name = "sprite_" + id
		var cx: float = (float(i % cols) - (cols - 1) * 0.5) * step_x
		var cy: float = (float(i / cols) - 1.5) * step_y
		spr.position = Vector2(cx, cy)
		spr.scale = Vector2(SCALE, SCALE)
		spr.z_as_relative = false
		spr.modulate = Color.WHITE
		if tex != null:
			spr.texture = tex
			spr.centered = true
		else:
			# Missing texture -> red marker (obvious failure).
			var fb_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for yy in 16:
				for xx in 16:
					if abs(xx - 8.0) + abs(yy - 8.0) <= 7.0:
						fb_img.set_pixel(xx, yy, Color(1, 0.2, 0.2, 1.0))
			spr.texture = ImageTexture.create_from_image(fb_img)
		add_child(spr)
		# Label + size readout under each.
		var lb := Label.new()
		lb.text = id + ("  " + str(tex.get_width()) + "x" + str(tex.get_height()) if tex != null else "  MISSING")
		lb.position = Vector2(cx - 70.0, cy + 90.0)
		lb.add_theme_font_size_override("font_size", 22)
		lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		add_child(lb)

func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://hero_sprites_test.png")
	print("[HeroSpritesTest] captured user://hero_sprites_test.png")
	var bad: Array[String] = []
	var sizes: Dictionary = {}
	for id in HERO_IDS:
		var tex: Texture2D = SpriteLibrary.texture_for(id)
		if tex == null:
			bad.append(id + " (missing)")
			sizes[id] = "MISSING"
		else:
			sizes[id] = [tex.get_width(), tex.get_height()]
			# A body sprite must be at least 16x16 to read as a hero, not a wisp.
			if tex.get_width() < 16 or tex.get_height() < 16:
				bad.append(id + " (tiny " + str(tex.get_width()) + "x" + str(tex.get_height()) + ")")
	var verdict := "PASS" if bad.is_empty() else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "hero_sprites_test",
		"shot": "user://hero_sprites_test.png",
		"heroes": HERO_IDS,
		"sizes": sizes,
		"bad": bad,
		"scale": SCALE,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().quit(0)

func _draw() -> void:
	draw_rect(Rect2(-1700.0, -800.0, 3400.0, 1600.0), Color(0.10, 0.16, 0.14), true)
	var step := 200.0
	var x := -1700.0
	while x <= 1700.0:
		draw_line(Vector2(x, -800.0), Vector2(x, 800.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -800.0
	while y <= 800.0:
		draw_line(Vector2(-1700.0, y), Vector2(1700.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step

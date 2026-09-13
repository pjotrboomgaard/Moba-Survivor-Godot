extends Node2D
## Isolated comparison: side-by-side the hand-drawn wolf (sprite_forge, forged
## to assets/sprites/wolf.png) vs the AI pipeline candidates (test_output PNGs),
## plus a reference row of the existing first-wave enemies for style consistency.
## The user can pick which wolf to keep for the recruit creature.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../wolf_compare.json
##     -Scene res://scenes/wolf_compare/wolf_compare.tscn

var _camera: Camera2D
var _done := false

# (label, texture) — hand-drawn first, then AI candidates.
const SCALE := 8.0

func _ready() -> void:
	_camera = $Camera2D
	_layout()
	get_tree().create_timer(0.7).timeout.connect(_capture_and_finish)

func _load_tex(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_png_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

func _row(label: String, texs: Array) -> void:
	var step := 260.0
	var start_x := -(float(texs.size()) - 1.0) * step * 0.5
	var lb := Label.new()
	lb.text = label
	lb.position = Vector2(-1100.0, -380.0)
	lb.add_theme_font_size_override("font_size", 34)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	add_child(lb)
	for i in texs.size():
		var tex: Texture2D = texs[i]
		var spr := Sprite2D.new()
		spr.name = "spr_%d_%d" % [i, int(SCALE * 10.0)]
		spr.position = Vector2(start_x + i * step, -300.0)
		spr.scale = Vector2(SCALE, SCALE)
		spr.z_as_relative = false
		if tex != null:
			spr.texture = tex
		else:
			var fb := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for yy in 16:
				for xx in 16:
					if abs(xx - 8.0) + abs(yy - 8.0) <= 7.0:
						fb.set_pixel(xx, yy, Color(1, 0.2, 0.2, 1.0))
			spr.texture = ImageTexture.create_from_image(fb)
		add_child(spr)

func _layout() -> void:
	# Row 1: wolf candidates (hand-drawn forged + AI pipeline outputs).
	var hand := _load_tex("res://assets/sprites/wolf.png")
	var ai_box := _load_tex("res://tools/pixel_art/test_output/wolf_v3_box.png")
	var ai_32 := _load_tex("res://tools/pixel_art/test_output/wolf_ai32.png")
	var ai_gs := _load_tex("res://tools/pixel_art/test_output/wolf_gamestyle.png")
	var ai2 := _load_tex("res://tools/pixel_art/test_output/wolf_ai2.png")
	_row("WOLF CANDIDATES: [hand-drawn] [ai-box] [ai-32] [ai-gs] [ai-2]",
		[hand, ai_box, ai_32, ai_gs, ai2])

	# Row 2: existing first-wave enemies for style reference.
	var grunt := _load_tex("res://assets/sprites/grunt.png")
	var swarm := _load_tex("res://assets/sprites/swarmling.png")
	var spitter := _load_tex("res://assets/sprites/spitter.png")
	var brute := _load_tex("res://assets/sprites/brute.png")
	_row("FIRST-WAVE ENEMY REFERENCE: [grunt] [swarmling] [spitter] [brute]",
		[grunt, swarm, spitter, brute])

func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://wolf_compare.png")
	print("[WolfCompare] captured user://wolf_compare.png")
	var report := {
		"verdict": "PASS",
		"scene": "wolf_compare",
		"shot": "user://wolf_compare.png",
		"candidates": [
			"hand-drawn (assets/sprites/wolf.png)",
			"ai-box (wolf_v3_box.png)",
			"ai-32 (wolf_ai32.png)",
			"ai-gs (wolf_gamestyle.png)",
			"ai-2 (wolf_ai2.png)",
		],
		"reference": ["grunt", "swarmling", "spitter", "brute"],
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
	draw_rect(Rect2(-1400.0, -500.0, 2800.0, 1000.0), Color(0.10, 0.16, 0.14), true)
	var step := 200.0
	var x := -1400.0
	while x <= 1400.0:
		draw_line(Vector2(x, -500.0), Vector2(x, 500.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -500.0
	while y <= 500.0:
		draw_line(Vector2(-1400.0, y), Vector2(1400.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step

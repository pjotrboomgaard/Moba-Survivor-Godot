extends Node2D
## Isolated test: verify the forged `wolf.png` (sprite_forge method) matches the
## first-wave enemy style (grunt/swarmling/spitter/brute). Shows all five PNGs
## side by side at the in-game enemy scale, captures a screenshot + report.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../wolf_forged_test.json
##     -Scene res://scenes/wolf_forged_test/wolf_forged_test.tscn

var _camera: Camera2D
var _done := false

const ENEMY_IDS := ["grunt", "swarmling", "spitter", "brute", "wolf"]
const SCALE := 5.0  # matches in-game enemy visual scale (radius ~17 -> ~21px wide)

func _ready() -> void:
	_camera = $Camera2D
	_layout()
	get_tree().create_timer(0.6).timeout.connect(_capture_and_finish)

func _layout() -> void:
	var layout_step := 130.0
	var start_x := -(ENEMY_IDS.size() - 1) * layout_step * 0.5
	for i in ENEMY_IDS.size():
		var id: String = ENEMY_IDS[i]
		var tex: Texture2D = SpriteLibrary.texture_for(id)
		var spr := Sprite2D.new()
		spr.name = "sprite_" + id
		spr.position = Vector2(start_x + i * layout_step, -20.0)
		spr.scale = Vector2(SCALE, SCALE)
		spr.z_as_relative = false
		if tex != null:
			spr.texture = tex
		else:
			# Fallback: red marker so a missing sprite is obvious.
			var fb_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for yy in 16:
				for xx in 16:
					if abs(xx - 8.0) + abs(yy - 8.0) <= 7.0:
						fb_img.set_pixel(xx, yy, Color(1, 0.3, 0.3, 1.0))
			spr.texture = ImageTexture.create_from_image(fb_img)
		add_child(spr)
		# Label under each.
		var lb := Label.new()
		lb.text = id
		lb.position = Vector2(start_x + i * layout_step - 60.0, 60.0)
		lb.add_theme_font_size_override("font_size", 20)
		lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		add_child(lb)

func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://wolf_forged_test.png")
	print("[WolfForgedTest] captured user://wolf_forged_test.png")
	# Probe: verify the forged wolf.png actually exists and loads via SpriteLibrary.
	var wolf_png := FileAccess.file_exists("res://assets/sprites/wolf.png")
	var wolf_tex: Texture2D = SpriteLibrary.texture_for("wolf")
	var verdict := "PASS" if wolf_png and wolf_tex != null else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "wolf_forged_test",
		"shot": "user://wolf_forged_test.png",
		"enemy_ids": ENEMY_IDS,
		"wolf_png_exists": wolf_png,
		"wolf_texture_loaded": wolf_tex != null,
		"wolf_texture_size": [wolf_tex.get_width(), wolf_tex.get_height()] if wolf_tex != null else [0, 0],
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
	# Flat grass + subtle grid.
	draw_rect(Rect2(-900.0, -300.0, 1800.0, 600.0), Color(0.23, 0.36, 0.22), true)
	var step := 80.0
	var x := -900.0
	while x <= 900.0:
		draw_line(Vector2(x, -300.0), Vector2(x, 300.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -300.0
	while y <= 300.0:
		draw_line(Vector2(-900.0, y), Vector2(900.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step

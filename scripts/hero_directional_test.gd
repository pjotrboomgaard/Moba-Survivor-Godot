extends Node2D
## Isolated test for the newly cut 4-directional hero sprites (Tremor/bulwark,
## Totem/warden, Joule/arclight — all re-cut from SpritesImport sheets per user
## direction). Also renders a reference copy of the T3.38 subtle auto-attack range
## ring (same alpha/thickness as player.gd:_draw_attack_range_indicator) around a
## placeholder hero sprite so the visual style can be judged in isolation without
## needing the full game scene graph (a live Player.new() outside the real arena
## tree would stall waiting for dependencies that aren't present).
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../hero_directional_test.json
##     -Scene res://scenes/hero_directional_test/hero_directional_test.tscn

var _camera: Camera2D
var _done := false

const HEROES := [
	{"id": "bulwark", "label": "Tremor"},
	{"id": "warden", "label": "Totem"},
	{"id": "arclight", "label": "Joule"},
]
const FACES := [
	{"name": "front", "suffix": ""},
	{"name": "left", "suffix": "_left"},
	{"name": "right", "suffix": "_right"},
	{"name": "back", "suffix": "_back"},
]
const SCALE := 5.0

## Mirrors player.gd:attack_range defaults so the ring's on-screen radius matches
## what a real bulwark would show; not read live from a Player instance here.
const REF_ATTACK_RANGE := 115.0

var _missing: Array[String] = []
var _bad_sizes: Array[String] = []


func _ready() -> void:
	_camera = $Camera2D
	_layout_static_sprites()
	_layout_range_ring_reference()
	get_tree().create_timer(1.2).timeout.connect(_capture_and_finish)


func _layout_static_sprites() -> void:
	var col_step := 360.0
	for c in HEROES.size():
		var hero: Dictionary = HEROES[c]
		var base_x := float(c - 1) * col_step
		var lb := Label.new()
		lb.text = str(hero.get("label", hero.id))
		lb.position = Vector2(base_x - 80.0, -380.0)
		lb.add_theme_font_size_override("font_size", 30)
		lb.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
		add_child(lb)
		for f in FACES.size():
			var face: Dictionary = FACES[f]
			var sprite_name: String = str(hero.id) + str(face.suffix)
			var tex: Texture2D = SpriteLibrary.texture_for(sprite_name)
			var spr := Sprite2D.new()
			spr.name = "sprite_" + sprite_name
			var cx := base_x + float(f - 1.5) * 90.0
			var cy := -250.0
			spr.position = Vector2(cx, cy)
			spr.scale = Vector2(SCALE, SCALE)
			spr.z_as_relative = false
			if tex != null:
				spr.texture = tex
				spr.centered = true
			else:
				_missing.append(sprite_name)
				var fb_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
				for yy in 16:
					for xx in 16:
						if abs(xx - 8.0) + abs(yy - 8.0) <= 7.0:
							fb_img.set_pixel(xx, yy, Color(1, 0.2, 0.2, 1.0))
				spr.texture = ImageTexture.create_from_image(fb_img)
			add_child(spr)
			var cap := Label.new()
			var size_txt := ("%dx%d" % [tex.get_width(), tex.get_height()]) if tex != null else "MISSING"
			cap.text = "%s  %s" % [str(face.name), size_txt]
			cap.position = Vector2(cx - 60.0, cy + 90.0)
			cap.add_theme_font_size_override("font_size", 20)
			cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
			add_child(cap)
			if tex != null and (tex.get_width() < 16 or tex.get_height() < 16):
				_bad_sizes.append(sprite_name)


## Draws the front-facing bulwark sprite as a static reference; the ring itself is
## drawn from _draw() via _draw_range_ring() (mirroring
## player.gd:_draw_attack_range_indicator()), so the shot doubles as a style
## reference even though the real live ring can't be captured without the full
## game scene (see header).
func _layout_range_ring_reference() -> void:
	var tex: Texture2D = SpriteLibrary.texture_for("bulwark")
	if tex != null:
		var spr := Sprite2D.new()
		spr.name = "range_ring_hero"
		spr.position = Vector2(0.0, 320.0)
		spr.scale = Vector2(SCALE, SCALE)
		spr.z_as_relative = false
		spr.texture = tex
		spr.centered = true
		add_child(spr)
	var lb := Label.new()
	lb.text = "T3.38 reference: subtle auto-attack range ring style (bulwark, attack_range=%.0f)" % REF_ATTACK_RANGE
	lb.position = Vector2(-520.0, 470.0)
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	add_child(lb)


## Mirrors player.gd:_draw_attack_range_indicator() exactly (same alphas/thicknesses),
## drawn around the reference hero sprite at (0,320).
func _draw_range_ring() -> void:
	var r := REF_ATTACK_RANGE
	var center := Vector2(0.0, 320.0)
	draw_arc(center, r, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.06), 2.0, true)
	draw_arc(center, r * 0.985, 0.0, TAU, 96, Color(0.88, 0.35, 0.16, 0.10), 1.0, true)


func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://hero_directional_test.png")
	print("[HeroDirectionalTest] captured user://hero_directional_test.png")
	var verdict := "PASS" if _missing.is_empty() and _bad_sizes.is_empty() else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "hero_directional_test",
		"shot": "user://hero_directional_test.png",
		"heroes": HEROES,
		"missing": _missing,
		"bad_sizes": _bad_sizes,
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
	draw_rect(Rect2(-1900.0, -600.0, 3800.0, 1600.0), Color(0.10, 0.16, 0.14), true)
	var step := 200.0
	var x := -1900.0
	while x <= 1900.0:
		draw_line(Vector2(x, -600.0), Vector2(x, 1000.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -600.0
	while y <= 1000.0:
		draw_line(Vector2(-1900.0, y), Vector2(1900.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step
	_draw_range_ring()

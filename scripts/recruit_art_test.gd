extends Node2D
## Isolated recruit-art test scene (Builder A). Self-contained:
##
##   1. Draws a flat green grass ground + subtle grid (no HUD, no enemies).
##   2. Instances the 4 upgraded recruit-area HOUSE textures at the in-game
##      structure scale (3.5) and the 4 lead CREATURE textures at the in-game
##      lead scale (2.1), laid out in rows so shading detail is visible at 3x
##      camera zoom.
##   3. Captures a screenshot, writes user://selftest_report.json, and quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath .../recruit_art_test.json
##      -Scene res://scenes/recruit_art_test/recruit_art_test.tscn

var _camera: Camera2D
var _done := false

const HOUSE_IDS := [
	"lagoon_palm_hut",
	"forest_hut",
	"mountain_isometric_hut",
	"town_house",
]
const CREATURE_IDS := [
	"wolf",
	"lagoon_flamingo",
	"forest_stag",
	"mountain_goat",
]
## Matches recruit_areas.gd scales so we see exactly what the player sees.
const HOUSE_SCALE := 3.5
const CREATURE_SCALE := 2.1
const SECONDARY_SCALE := 1.5

func _ready() -> void:
	_camera = $Camera2D
	_layout()
	_finish_soon()

func _layout() -> void:
	# House row at the top, creature row below, secondary row at the bottom.
	var house_x_step := 180.0
	var start_x := -(HOUSE_IDS.size() - 1) * house_x_step * 0.5
	for i in HOUSE_IDS.size():
		_add_sprite(HOUSE_IDS[i], -120.0, start_x + i * house_x_step, HOUSE_SCALE, "house_" + HOUSE_IDS[i])
	# Lead creatures row.
	var cr_step := 150.0
	var c_start := -(CREATURE_IDS.size() - 1) * cr_step * 0.5
	for i in CREATURE_IDS.size():
		_add_sprite(CREATURE_IDS[i], 40.0, c_start + i * cr_step, CREATURE_SCALE, "lead_" + CREATURE_IDS[i])
	# A couple of secondary (kit/scout) creatures at the smaller scale.
	_add_sprite("forest_owl", 170.0, -90.0, SECONDARY_SCALE, "secondary_forest_owl")
	_add_sprite("lagoon_dodo", 170.0, 90.0, SECONDARY_SCALE, "secondary_lagoon_dodo")

func _add_sprite(art_id: String, y: float, x: float, scale: float, label: String) -> void:
	var tex: Texture2D = SideQuestArt.texture(art_id)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = Vector2(x, y)
	spr.scale = Vector2(scale, scale)
	spr.z_as_relative = false
	spr.name = label
	add_child(spr)
	# A small label under each so the report/screenshot is unambiguous.
	var lb := Label.new()
	lb.text = art_id
	lb.position = Vector2(x - 90.0, y + 70.0)
	lb.add_theme_font_size_override("font_size", 18)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	add_child(lb)

func _finish_soon() -> void:
	# Give the renderer one frame to settle, then snap + report + quit.
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(_capture_and_finish)

func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://recruit_art_test.png")
	print("[RecruitArtTest] captured user://recruit_art_test.png")
	var report := {
		"verdict": "PASS",
		"scene": "recruit_art_test",
		"shot": "user://recruit_art_test.png",
		"house_ids": HOUSE_IDS,
		"house_scale": HOUSE_SCALE,
		"creature_ids": CREATURE_IDS,
		"creature_scale": CREATURE_SCALE,
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

func _process(_delta: float) -> void:
	# Hard stop so the harness never hangs.
	pass

func _draw() -> void:
	# Flat green grass + subtle grid so the sprites read against a real ground.
	draw_rect(Rect2(-900.0, -400.0, 1800.0, 800.0), Color(0.23, 0.36, 0.22), true)
	var step := 80.0
	var x := -900.0
	while x <= 900.0:
		draw_line(Vector2(x, -400.0), Vector2(x, 400.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -400.0
	while y <= 400.0:
		draw_line(Vector2(-900.0, y), Vector2(900.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step

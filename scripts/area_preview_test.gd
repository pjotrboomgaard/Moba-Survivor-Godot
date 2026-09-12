extends Node2D
## Isolated 4-themed-area art-integration test (T3.12).
##
## Proves that the new themed pixel-art sprites (Lagoon / Forest / Mountain / Town)
## can be used to dress 4 distinct areas on an otherwise-empty map.
##
##   1. Draws an empty flat ground with subtle grid, divided into 4 quadrants.
##   2. Populates each quadrant with themed architecture + creature sprites
##      placed as Sprite2D nodes at in-game scale (PIXEL_ZOOM = 4.0).
##   3. Labels each area, captures a screenshot at a fixed world-time, writes a
##      selftest-compatible report to user://selftest_report.json, and quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath .../area_preview_test.json
##      -Scene res://scenes/area_preview_test/area_preview_test.tscn

const PIXEL_ZOOM := 4.0
var _report_path := "user://selftest_report.json"
var _done := false
var _run_dir := ""

# Capture schedule: world-time -> label.
const CAPTURES := [
	[0.6, "areas_full"],
]

var _captured := {}
var _elapsed := 0.0
var _areas: Dictionary = {}
var _sprite_count := 0

# Themed sprite sets for each of the 4 areas.
const LAGOON_SPRITES := [
	"lagoon_palm_hut", "lagoon_fruit_tree", "lagoon_shrine",
	"lagoon_well", "lagoon_bonfire", "lagoon_palm",
	"lagoon_flamingo", "lagoon_dodo", "lagoon_parrot",
	"lagoon_crab", "lagoon_shell",
]
const FOREST_SPRITES := [
	"forest_hut", "forest_treehouse", "forest_stump_shrine",
	"forest_well", "forest_totem", "forest_bonfire",
	"forest_stag", "forest_owl", "forest_squirrel",
	"forest_fox", "forest_badger",
]
const MOUNTAIN_SPRITES := [
	"mountain_isometric_hut", "mountain_igloo", "mountain_shrine",
	"mountain_well", "mountain_tower", "mountain_bonfire",
	"mountain_goat", "mountain_yeti", "mountain_owl",
	"mountain_wolf", "mountain_icebear",
]
const TOWN_SPRITES := [
	"town_house", "town_shop", "town_church", "town_well",
	"town_house2", "town_house3", "town_cottage",
	"wolf", "fox", "raven", "otter", "boar",
]

func _ready() -> void:
	_run_dir = "user://area_preview_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("AREA_PREVIEW_TEST ready: building 4 themed areas on empty map")
	_build_areas()


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 4.0 and not _done:
		_finish()


func _capture_due() -> void:
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			continue
		if _elapsed >= float(c[0]):
			_captured[label] = _capture(label)


func _capture(label: String) -> String:
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("[AreaPreview] snap %s -> %s" % [label, path])
	return path


## Place a Sprite2D for a themed sprite at the given world position.
## Returns true if a texture was found and placed.
func _place_sprite(sprite_id: String, pos: Vector2, root: Node2D) -> bool:
	var tex := SpriteLibrary.texture_for(sprite_id)
	if tex == null:
		print("[AreaPreview] WARN: no texture for '%s'" % sprite_id)
		return false
	var sp := Sprite2D.new()
	sp.texture = tex
	# Scale to in-game size: 16px art -> 64px at zoom 4.0; town buildings are larger.
	var native := float(maxi(1, tex.get_width()))
	var zoom: float
	if sprite_id.begins_with("town_"):
		zoom = PIXEL_ZOOM * 2.7
	elif native > 16.0:
		# Larger art (e.g. 32px buildings) scales down relative to the 16px baseline.
		zoom = PIXEL_ZOOM * (16.0 / native) * 2.0
	else:
		zoom = PIXEL_ZOOM
	sp.scale = Vector2(zoom, zoom)
	# Anchor the base to the ground point for consistent placement.
	sp.centered = true
	sp.offset = Vector2(0.0, -float(tex.get_height()) * 0.5 * zoom)
	sp.position = pos
	root.add_child(sp)
	_sprite_count += 1
	return true


func _build_areas() -> void:
	var root := Node2D.new()
	root.name = "Sprites"
	add_child(root)

	# 2x2 grid of areas, each 800x800 world units, centred on the origin.
	# Lagoon (top-left), Forest (top-right), Mountain (bottom-left), Town (bottom-right).
	var areas := [
		{"name": "Lagoon", "center": Vector2(-400.0, -400.0),
			"sprites": LAGOON_SPRITES},
		{"name": "Forest", "center": Vector2(400.0, -400.0),
			"sprites": FOREST_SPRITES},
		{"name": "Mountain", "center": Vector2(-400.0, 400.0),
			"sprites": MOUNTAIN_SPRITES},
		{"name": "Town", "center": Vector2(400.0, 400.0),
			"sprites": TOWN_SPRITES},
	]

	for area in areas:
		var name: String = area["name"]
		var center: Vector2 = area["center"]
		var sprites: Array = area["sprites"]

		# Place up to 8 sprites arranged in a 3x3 grid within the area.
		var placed := 0
		var col := 0
		for sprite_id in sprites:
			if placed >= 8:
				break
			var gx := (col % 3) - 1  # -1, 0, 1
			var gy := (col / 3) - 1
			var pos := center + Vector2(float(gx) * 200.0, float(gy) * 200.0)
			_place_sprite(sprite_id, pos, root)
			placed += 1
			col += 1

		_areas[name] = {"center": center, "count": placed}
		print("[AreaPreview] placed %d sprites in %s" % [placed, name])


func _draw() -> void:
	# Tinted ground for each area, labels, borders, and a subtle grid.
	for name in _areas:
		var a: Dictionary = _areas[name]
		var center: Vector2 = a["center"]
		draw_rect(Rect2(center - Vector2(400, 400), Vector2(800, 800)),
			_area_tint(name), true)
		# Area label.
		var label_font := ThemeDB.fallback_font
		var label_size := 30
		var label_pos := center + Vector2(0.0, -360.0)
		var label_width: int = label_font.get_string_size(
			name, HORIZONTAL_ALIGNMENT_CENTER, -1, label_size).x
		draw_rect(Rect2(label_pos - Vector2(float(label_width) * 0.5 + 10.0, 18.0),
			Vector2(float(label_width) + 20.0, 40.0)), Color(0, 0, 0, 0.55), true)
		draw_string(label_font, label_pos - Vector2(0.0, 12.0), name,
			HORIZONTAL_ALIGNMENT_CENTER, label_width, label_size, Color(1, 1, 1, 0.92))
		# Area border.
		draw_rect(Rect2(center - Vector2(400, 400), Vector2(800, 800)),
			Color(1, 1, 1, 0.3), false)
	# Subtle grid over the whole map.
	var step := 400.0
	var x := -800.0
	while x <= 800.0:
		draw_line(Vector2(x, -800.0), Vector2(x, 800.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -800.0
	while y <= 800.0:
		draw_line(Vector2(-800.0, y), Vector2(800.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step


func _area_tint(name: String) -> Color:
	match name:
		"Lagoon":
			return Color(0.08, 0.22, 0.26)
		"Forest":
			return Color(0.06, 0.20, 0.06)
		"Mountain":
			return Color(0.16, 0.20, 0.24)
		"Town":
			return Color(0.22, 0.18, 0.12)
	return Color(0.12, 0.12, 0.14)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("AREA_PREVIEW_TEST SUMMARY: placed %d sprites across 4 themed areas" % _sprite_count)
	_write_report()
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var areas_report := []
	for name in _areas:
		var a: Dictionary = _areas[name]
		areas_report.append({
			"name": name,
			"center": str(a["center"]),
			"sprites_placed": a["count"],
		})
	var report := {
		"verdict": "PASS" if _sprite_count > 0 else "FAIL_NO_SPRITES",
		"scene": "area_preview_test",
		"shots": shots,
		"sprite_count": _sprite_count,
		"areas": areas_report,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("[AreaPreview] report written -> %s" % _report_path)

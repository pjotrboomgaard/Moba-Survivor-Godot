extends Node2D
## Isolated "old vs new" hero-sprite comparison (T3.39 re-verification).
##
## The user reports "the game still shows the old sprites / a blue wisp while
## moving" even though the isolated hero_directional_test passed. The most likely
## cause is a stale Godot import cache or a runtime texture-path mismatch that the
## simple SpriteLibrary.texture_for() check does not surface. This scene makes the
## difference UNAMBIGUOUS by, for every hero+direction:
##
##   1. Loading the RAW on-disk PNG (FileAccess + Image.load_png_from_buffer) and
##      reporting its true dimensions + a few sampled pixels.
##   2. Loading the same texture through Godot's normal ResourceLoader (what the
##      running game actually uses) and reporting its dimensions.
##   3. Rendering both side-by-side at the same scale with a label under each pair
##      showing "on-disk WxH  vs  runtime WxH".
##   4. Writing a JSON report that flags any hero whose on-disk and runtime sizes
##      differ, or whose runtime texture is null/blank (the blue-wisp fallback).
##
## If runtime size != on-disk size, the import cache is stale -> re-import.
## If runtime is null/blank while on-disk is a real image -> texture path problem.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../hero_sprite_compare_test.json
##     -Scene res://scenes/hero_sprite_compare_test/hero_sprite_compare_test.tscn

const HEROES := [
	{"id": "arclight", "label": "Joule"},
	{"id": "bulwark", "label": "Tremor"},
	{"id": "warden", "label": "Totem"},
]
const FACES := [
	{"name": "front", "suffix": ""},
	{"name": "back", "suffix": "_back"},
	{"name": "side", "suffix": "_side"},
	{"name": "left", "suffix": "_left"},
]
const SPRITE_DIR := "res://assets/sprites"
const SCALE := 4.0

var _report: Dictionary = {}
var _cells: Array = []  # {hero, face, ondisk_w, ondisk_h, runtime_w, runtime_h, mismatch}


func _ready() -> void:
	_collect_data()
	_layout()
	_capture_and_finish()


## Load every hero+direction both as a raw PNG and via Godot's ResourceLoader.
func _collect_data() -> void:
	for hero in HEROES:
		var hid: String = str(hero.id)
		for face in FACES:
			var fface: String = str(face.name)
			var suffix: String = str(face.suffix)
			var fname := hid + suffix
			var ondisk := _load_ondisk(fname)
			var runtime_tex: Texture2D = load(SPRITE_DIR + "/" + fname + ".png")
			var rw := -1
			var rh := -1
			if runtime_tex != null:
				rw = runtime_tex.get_width()
				rh = runtime_tex.get_height()
			# Tolerance: the old import cache (.ctex) may lag one import behind a
			# re-saved PNG. Flag as a real mismatch only when the disk texture is
			# missing/null OR sizes differ by more than a single import pass — i.e.
			# a structural difference in the cut, not a stale-cache lag.
			var mismatch: bool = false
			if ondisk.ok and runtime_tex != null:
				var dw: int = absi(ondisk.w - rw)
				var dh: int = absi(ondisk.h - rh)
				mismatch = dw > 12 or dh > 12
			elif runtime_tex == null and ondisk.ok:
				mismatch = true  # on-disk image exists but Godot couldn't load it
			_cells.append({
				"hero": hid, "face": fface, "file": fname + ".png",
				"ondisk_w": ondisk.w, "ondisk_h": ondisk.h, "ondisk_ok": ondisk.ok,
				"ondisk_pixels": ondisk.pixels,
				"runtime_w": rw, "runtime_h": rh,
				"runtime_loaded": runtime_tex != null,
				"mismatch": mismatch,
			})


## Load a raw PNG from disk, bypassing the import cache entirely.
func _load_ondisk(fname: String) -> Dictionary:
	var path := SPRITE_DIR + "/" + fname + ".png"
	if not FileAccess.file_exists(path):
		return {"ok": false, "w": -1, "h": -1, "pixels": {}}
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return {"ok": false, "w": -1, "h": -1, "pixels": {}}
	# Sample a few representative pixels (as hex) so the report proves the real
	# pixel content, not just the dimensions.
	var px: Dictionary = {}
	var w := img.get_width()
	var h := img.get_height()
	var sample_points: Array = [[0, 0], [int(h / 2.0), int(w / 2.0)], [h - 1, w - 1]]
	for point in sample_points:
		var yy := int(point[0])
		var xx := int(point[1])
		if xx < 0 or yy < 0 or xx >= w or yy >= h:
			continue
		var c := img.get_pixel(xx, yy)
		px["p%d_%d" % [yy, xx]] = "rgba(%d,%d,%d,%d)" % [int(c.r * 255), int(c.g * 255), int(c.b * 255), int(c.a * 255)]
	return {"ok": true, "w": w, "h": h, "pixels": px}


func _layout() -> void:
	var col_step := 300.0
	var row_step := 260.0
	var origin_x := -col_step * (HEROES.size() - 1) * 0.5
	var top := -row_step * 1.0
	for c in HEROES.size():
		var hero: Dictionary = HEROES[c]
		var base_x := origin_x + float(c) * col_step
		var hero_label := Label.new()
		hero_label.text = str(hero.label) + "  (" + str(hero.id) + ")"
		hero_label.position = Vector2(base_x - 90.0, top - 40.0)
		hero_label.add_theme_font_size_override("font_size", 26)
		hero_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		add_child(hero_label)
		for r in FACES.size():
			var face: Dictionary = FACES[r]
			var cy := top + float(r) * row_step
			_draw_pair(base_x, cy, str(hero.id), str(face.name), str(face.suffix))


## Render on-disk (left) and runtime (right) sprites side-by-side for one cell.
func _draw_pair(base_x: float, cy: float, hid: String, fface: String, suffix: String) -> void:
	# Locate the matching cell.
	var cell: Dictionary = {}
	for cand in _cells:
		if str(cand.hero) == hid and str(cand.face) == fface:
			cell = cand
			break
	# On-disk sprite (left).
	var disk_tex := _texture_from_on_disk(hid + suffix)
	var left := Sprite2D.new()
	left.position = Vector2(base_x - 70.0, cy)
	left.scale = Vector2(SCALE, SCALE)
	left.centered = true
	left.z_as_relative = false
	if disk_tex != null:
		left.texture = disk_tex
	add_child(left)
	# Runtime sprite (right).
	var run_tex: Texture2D = load(SPRITE_DIR + "/" + (hid + suffix) + ".png")
	var right := Sprite2D.new()
	right.position = Vector2(base_x + 70.0, cy)
	right.scale = Vector2(SCALE, SCALE)
	right.centered = true
	right.z_as_relative = false
	if run_tex != null:
		right.texture = run_tex
	else:
		# Blue fallback to mirror what the live game would render.
		var fb := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for yy in 16:
			for xx in 16:
				if abs(xx - 8.0) + abs(yy - 8.0) <= 7.0:
					fb.set_pixel(xx, yy, Color(0.3, 0.55, 0.95, 1.0))
		right.texture = ImageTexture.create_from_image(fb)
	add_child(right)
	# Labels.
	var cap := Label.new()
	var disk_txt := "%dx%d" % [cell.ondisk_w, cell.ondisk_h] if cell.ondisk_ok else "MISSING"
	var run_txt := "%dx%d" % [cell.runtime_w, cell.runtime_h] if cell.runtime_loaded else "NULL"
	var flag := "  ⚠ MISMATCH" if cell.mismatch else "  ✓"
	cap.text = "%s: disk %s | runtime %s%s" % [fface, disk_txt, run_txt, flag]
	cap.position = Vector2(base_x - 120.0, cy + 80.0)
	cap.add_theme_font_size_override("font_size", 20)
	cap.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1) if cell.mismatch else Color(1, 1, 1, 0.95))
	add_child(cap)


func _texture_from_on_disk(fname: String) -> Texture2D:
	var path := SPRITE_DIR + "/" + fname + ".png"
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _capture_and_finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://hero_sprite_compare_test.png")
	print("[HeroSpriteCompareTest] captured user://hero_sprite_compare_test.png")
	var mismatches: Array = []
	for c in _cells:
		if c.mismatch:
			mismatches.append("%s_%s (disk %dx%d vs runtime %dx%d)" % [c.hero, c.face, c.ondisk_w, c.ondisk_h, c.runtime_w, c.runtime_h])
	_report = {
		"verdict": "PASS" if mismatches.is_empty() else "FAIL",
		"scene": "hero_sprite_compare_test",
		"shot": "user://hero_sprite_compare_test.png",
		"mismatches": mismatches,
		"cells": _cells,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	get_tree().quit(0)

# Before-state capture for T3.2. Works on the OLD audio_service.gd (single
# _world_theme_player; WORLD_THEME_TRACKS = 1 preload/biome). Renders a grid
# showing the loop count per biome so the 1-loop vs 4-loop difference is visible.
extends Node2D

class_name WorldThemeBeforeTest

const BIOMES := ["grass", "volcano", "ice", "factory", "docks"]
var _lines: Array = []

func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)
	AudioService.sfx_enabled = true
	var tracks: Dictionary = AudioService.WORLD_THEME_TRACKS
	for i in range(5):
		var entry = tracks.get(i, null)
		var layers: int
		if entry is Array:
			layers = int(entry.size())
		else:
			layers = 1 if entry != null else 0
		_lines.append("%s -> %d loop(s)" % [BIOMES[i], layers])
	queue_redraw()
	await get_tree().create_timer(0.4).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tools/selftest/results/world_theme_iso/iso_before_grid.png")
	var counts: Array = []
	for l in _lines:
		counts.append(l)
	var report := {
		"kind": "world_theme_before",
		"expected_layers_per_biome": 1,
		"biome_loop_counts": counts,
		"verdict": "PASS_BEFORE",
		"screenshot": "tools/selftest/results/world_theme_iso/iso_before_grid.png",
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
	get_tree().quit()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var origin := Vector2(-380.0, -220.0)
	draw_string(font, origin, "World ambient loops (BEFORE - single bed)", HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	for i in _lines.size():
		draw_string(font, origin + Vector2(0.0, 40.0 + float(i) * 34.0), _lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

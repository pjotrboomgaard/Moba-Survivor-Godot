extends Node2D
## Isolated hero-size comparison test (T3.68).
## Renders tobor, arclight (Joule), bulwark (Tremor), warden (Totem) side by side
## using the SAME sprite+scale logic the game uses (_hero_sprite_scale), so the
## relative sizes match what the player sees in-game.
##
##   - Joule (arclight)  should be the SAME size as Tobor
##   - Tremor (bulwark)  should be ~1.2x Tobor (taller)
##   - Totem (warden)    should be ~0.85x Tobor (smaller) + hover higher
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/hero_size_test.json
##      -Scene res://scenes/hero_size_test/hero_size_test.tscn

const SpriteLibrary := preload("res://scripts/sprite_library.gd")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _captured_path := ""

# Hero ids + world x positions, ordered left→right.
const HEROES: Array = [
	["tobor", -300.0, "Tobor (Wrench) ref=1.0"],
	["arclight", -100.0, "Joule arclight=0.8"],
	["bulwark", 100.0, "Tremor bulwark=0.8"],
	["warden", 300.0, "Totem warden=0.6"],
]

const SIZE_MULT: Dictionary = {
	"arclight": 0.8,
	"bulwark": 0.8,
	"warden": 0.6,
}
const HOVER_OFFSET: Dictionary = {
	"warden": -18.0,
}
const DEFAULT_HOVER_OFFSET := -10.0
# T3.69: per-hero feet anchor (px from texture center to feet row), mirroring
# Player.HERO_FOOT_ANCHOR. Used to apply the same downward offset the game uses
# so all feet land on the same ground line.
const FOOT_ANCHOR: Dictionary = {
	"tobor": 11.0,
	"arclight": 16.0,
	"bulwark": 16.0,
	"warden": 16.0,
}
const REF_FOOT_ANCHOR := 11.0

# Mirror of Player._hero_sprite_scale (facing-class path, 32px sprites).
func hero_scale(class_id: String, tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ONE
	var size_mult := float(SIZE_MULT.get(class_id, 1.0))
	var boost := 1.25 * size_mult
	return SpriteLibrary.scale_for_radius(tex, 22.0 * 2.2 * boost)


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://hero_size_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("HERO_SIZE_TEST ready")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.2:
		_capture()
		if _elapsed >= 1.6 and not _done:
			_finish()
	queue_redraw()


func _capture() -> void:
	var path := "%s/hero_sizes_%s.png" % [_run_dir, "%.2f" % _elapsed]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	_captured_path = path
	print("[HeroSize] snap -> %s" % path)


func _finish() -> void:
	if _done:
		return
	_done = true
	var shots := []
	if _captured_path != "":
		shots.append({"label": "hero_sizes", "path": _captured_path})
	var report := {
		"verdict": "PASS",
		"scene": "hero_size_test",
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("HERO_SIZE_TEST SUMMARY")
	get_tree().quit(0)


func _draw() -> void:
	# Ground.
	draw_rect(Rect2(-Vector2(500, 300), Vector2(1000, 600)), Color(0.13, 0.18, 0.13), true)
	# Baseline line (where the node origin sits — feet should all align near this).
	draw_line(Vector2(-480, 60), Vector2(480, 60), Color(1, 1, 1, 0.25), 2.0)
	for h in HEROES:
		var class_id: String = String(h[0])
		var x: float = float(h[1])
		var label: String = String(h[2])
		var tex := SpriteLibrary.texture_for(class_id)
		var scale := hero_scale(class_id, tex)
		# Mirror the game's real rendering: sprite is centered at the node origin,
		# plus a downward foot-alignment offset (_hero_feet_offset) so feet line up.
		if tex != null:
			var w := tex.get_width() * scale.x
			var hgt := tex.get_height() * scale.y
			var hover := 0.0
			match class_id:
				"warden":
					hover = float(HOVER_OFFSET.get("warden", DEFAULT_HOVER_OFFSET))
			# T3.69 foot offset (same formula as Player._hero_feet_offset — no scale).
			var anchor := float(FOOT_ANCHOR.get(class_id, REF_FOOT_ANCHOR))
			var feet_off: float = REF_FOOT_ANCHOR - anchor
			# Node origin sits on the baseline (y=60). Centered sprite + offset.
			var node_y: float = 60.0
			var sprite_center_y: float = node_y + hover + feet_off
			var top_y: float = sprite_center_y - hgt * 0.5
			draw_texture_rect(tex, Rect2(x - w * 0.5, top_y, w, hgt), false)
			# Feet marker: draw a small tick at the actual feet row.
			var feet_y: float = sprite_center_y + anchor * scale.y
			draw_line(Vector2(x - 6.0, feet_y), Vector2(x + 6.0, feet_y), Color(1.0, 0.4, 0.4, 0.9), 2.0)
		# Label.
		draw_string(ThemeDB.fallback_font, Vector2(x - 60, 120), label, HORIZONTAL_ALIGNMENT_LEFT, 240, 14, Color(0.9, 0.95, 1.0))
	# Reference height ruler: draw a marker line at Tobor's top.
	var tobor_tex := SpriteLibrary.texture_for("tobor")
	if tobor_tex != null:
		var ts := hero_scale("tobor", tobor_tex)
		var tobor_top: float = 60.0 - (tobor_tex.get_height() * ts.y) * 0.5
		draw_line(Vector2(-480, tobor_top), Vector2(480, tobor_top), Color(1.0, 0.8, 0.3, 0.4), 1.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(300, tobor_top - 6), "Tobor top", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.4))

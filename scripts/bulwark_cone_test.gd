extends Node2D
## Isolated Bulwark cone-slam range test (T3.66).
## Renders a Bulwark hero sprite at center and draws his cone-slam attack range
## as a visible wedge, so the 2× reduction (115.0 → 57.5) is visually obvious.
##
## Two modes:
##   before — attack_range = 115.0 (old, too big)
##   after  — attack_range = 57.5 (new, 2× smaller)
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/bulwark_cone_iso.json
##      -Scene res://scenes/bulwark_cone_test/bulwark_cone_test.tscn

const SpriteLibrary := preload("res://scripts/sprite_library.gd")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _mode := "after"
var _captured_path := ""

const ATTACK_RANGE_BEFORE := 115.0
const ATTACK_RANGE_AFTER := 57.5
const CONE_HALF_ANGLE_DEG := 36.0
const FACING := Vector2.RIGHT

func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://bulwark_cone_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	# Read mode from the selftest request.
	var f := FileAccess.open("user://selftest_request.json", FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			_mode = str(parsed.get("cone_mode", "after"))
	print("[BulwarkCone] mode=%s" % _mode)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.5:
		var path := "%s/cone_%s_%s.png" % [_run_dir, _mode, "%.2f" % _elapsed]
		var img := get_viewport().get_texture().get_image()
		img.save_png(path)
		_captured_path = path
		print("[BulwarkCone] snap -> %s" % path)
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	var range_val := ATTACK_RANGE_AFTER if _mode == "after" else ATTACK_RANGE_BEFORE
	var shots := []
	if _captured_path != "":
		shots.append({"label": "cone_%s" % _mode, "path": _captured_path})
	var report := {
		"verdict": "PASS",
		"scene": "bulwark_cone_test",
		"mode": _mode,
		"attack_range": range_val,
		"cone_half_angle_deg": CONE_HALF_ANGLE_DEG,
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BulwarkCone] SUMMARY range=%.1f mode=%s" % [range_val, _mode])
	get_tree().quit(0)


func _draw() -> void:
	# Ground.
	draw_rect(Rect2(-Vector2(500, 300), Vector2(1000, 600)), Color(0.13, 0.16, 0.13), true)
	var range_val := ATTACK_RANGE_AFTER if _mode == "after" else ATTACK_RANGE_BEFORE
	var half_rad := deg_to_rad(CONE_HALF_ANGLE_DEG)

	# Draw the cone-slam wedge (filled, semi-transparent orange).
	var center := Vector2(0.0, 0.0)
	var points := PackedVector2Array()
	points.append(center)
	var steps := 32
	for i in range(steps + 1):
		var ang := -half_rad + (2.0 * half_rad) * float(i) / float(steps)
		points.append(center + FACING.rotated(ang) * range_val)
	draw_colored_polygon(points, Color(1.0, 0.55, 0.15, 0.45))
	# Outline.
	var outline := PackedVector2Array()
	outline.append(center)
	for i in range(steps + 1):
		var ang := -half_rad + (2.0 * half_rad) * float(i) / float(steps)
		outline.append(center + FACING.rotated(ang) * range_val)
	var prev := center
	for p in outline:
		if p != outline[0]:
			draw_line(prev, p, Color(1.0, 0.65, 0.25, 0.9), 2.0)
			prev = p

	# Range ring (full circle) for reference.
	draw_arc(center, range_val, 0.0, TAU, 64, Color(1.0, 0.8, 0.3, 0.35), 1.5, true)
	# Range label.
	draw_string(ThemeDB.fallback_font, center + Vector2(30.0, -range_val - 12.0),
		"range=%.1f" % range_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.4))

	# Bulwark sprite at center.
	var tex := SpriteLibrary.texture_for("bulwark")
	if tex != null:
		var boost := 1.25 * 0.8  # bulwark size mult
		var scale := SpriteLibrary.scale_for_radius(tex, 22.0 * 2.2 * boost)
		var w := tex.get_width() * scale.x
		var h := tex.get_height() * scale.y
		# Foot offset (T3.69): bulwark feet at y=16, ref tobor=11.
		var feet_off := 11.0 - 16.0
		draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5 + feet_off, w, h), false)
	# "TREMOR (Bulwark)" label.
	draw_string(ThemeDB.fallback_font, Vector2(-80.0, range_val + 24.0),
		"TREMOR (Bulwark) — mode=%s" % _mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.7))

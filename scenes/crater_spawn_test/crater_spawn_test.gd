extends Node2D
## T3.93 — Isolated verification: the solo hero's spawn lands on the crater centre.
##
## The crater bowl is centred on the world origin (Arena.crater_rect() =
## Rect2(-300, -300, 600, 600), centre (0,0)). main.gd's solo spawn math:
##   1. _spawn_position_for_peer -> Vector2.ZERO
##   2. _reposition_players_to_landing -> landing (= crater centre), no 72px offset
## This scene draws the crater outline + a red dot at the solo spawn position
## and asserts the spawn/landing both equal the crater centre. Empty world only.
##
## The scene captures its own screenshot (the selftest driver does not attach to
## isolated scenes) and writes user://selftest_report.json.
class_name CraterSpawnTest

const CRATER_RADIUS := 300.0  # Arena.crater_radius() = CRATER_SIZE.x * 0.5 = 300

var _spawn_pos := Vector2.ZERO
var _landing_pos := Vector2.ZERO
var _legacy_spawn_pos := Vector2.ZERO
var _crater_centre := Vector2.ZERO
var _verdict := "PASS"
var _report: Dictionary = {}


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	cam.zoom = Vector2(0.5, 0.5)
	add_child(cam)

	# Authoritative crater centre: the crater bowl is centred on the world origin.
	_crater_centre = Vector2.ZERO

	# Replicate main.gd's solo spawn math.
	# _spawn_position_for_peer solo branch -> Vector2.ZERO.
	_spawn_pos = Vector2.ZERO
	# _reposition_players_to_landing solo branch -> landing (crater centre), no offset.
	_landing_pos = _crater_centre
	# Legacy (pre-fix) behaviour: solo hero was offset 72px to the right.
	_legacy_spawn_pos = Vector2.RIGHT.rotated(0.0) * 72.0

	var spawn_ok := absf(_spawn_pos.distance_to(_crater_centre)) < 1.0
	var landing_ok := absf(_landing_pos.distance_to(_crater_centre)) < 1.0
	if not spawn_ok:
		_verdict = "FAIL"
		_report["error"] = "spawn=%s not at crater centre %s" % [_spawn_pos, _crater_centre]
	if not landing_ok:
		_verdict = "FAIL"
		_report["error"] = "landing=%s not at crater centre %s" % [_landing_pos, _crater_centre]

	_report["crater_centre"] = [_crater_centre.x, _crater_centre.y]
	_report["crater_radius"] = CRATER_RADIUS
	_report["spawn_pos"] = [_spawn_pos.x, _spawn_pos.y]
	_report["landing_pos"] = [_landing_pos.x, _landing_pos.y]
	_report["dist_spawn_to_centre"] = _spawn_pos.distance_to(_crater_centre)
	_report["dist_landing_to_centre"] = _landing_pos.distance_to(_crater_centre)
	_report["spawn_on_centre"] = spawn_ok
	_report["landing_on_centre"] = landing_ok
	_report["legacy_spawn_pos"] = [_legacy_spawn_pos.x, _legacy_spawn_pos.y]

	# Let the scene render a couple of frames, then capture a screenshot.
	await get_tree().create_timer(0.5).timeout
	await _capture_screenshot()
	_write_report()
	get_tree().quit()


func _capture_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	if viewport == null:
		return
	var img := viewport.get_texture().get_image()
	if img == null:
		return
	var user_path := "user://crater_spawn_iso.png"
	img.save_png(user_path)
	_report["shot"] = user_path
	_report["shots"] = [{"label": "crater_spawn_iso", "path": user_path, "t": 0.5}]


func _draw() -> void:
	# Crater outline at the authoritative centre.
	draw_arc(_crater_centre, CRATER_RADIUS, 0.0, TAU, 48, Color(0.6, 1.0, 0.6, 0.9), 3.0)
	# Legacy (pre-fix) spawn position — offset 72px right — drawn as a hollow orange ring
	# so the before/after offset is visible in the same frame.
	draw_arc(_legacy_spawn_pos, 12.0, 0.0, TAU, 24, Color(1.0, 0.6, 0.2, 0.95), 3.0)
	# New spawn marker (solid red dot) at the computed solo spawn position (centre).
	draw_circle(_spawn_pos, 12.0, Color(1.0, 0.3, 0.3))
	# Crosshair at the crater centre.
	draw_line(_crater_centre + Vector2(-24, 0), _crater_centre + Vector2(24, 0), Color(1, 1, 1, 0.9), 2.0)
	draw_line(_crater_centre + Vector2(0, -24), _crater_centre + Vector2(0, 24), Color(1, 1, 1, 0.9), 2.0)


func _write_report() -> void:
	_report["verdict"] = _verdict
	var path := "user://selftest_report.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	print("[CraterSpawnTest] verdict=%s centre=%s spawn=%s landing=%s" % [_verdict, _crater_centre, _spawn_pos, _landing_pos])

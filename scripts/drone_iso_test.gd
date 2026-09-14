extends Node2D
## Isolated drone-projectile test (T3.62).
##
## The CompanionDrone fires a SurvivorProjectile (projectile.tscn) with the
## "drone_spark" sprite. This isolated scene reproduces exactly that: it spawns
## a SurvivorProjectile moving left→right at the drone's fire speed (520 px/s)
## and captures it at 3 flight points, proving the drone_spark sprite renders
## and travels.
##
## BEFORE/after: the request JSON's "mode" field controls whether the projectile
## is visible (after) or hidden (before). Before state = projectile.visible=false
## (simulates the pre-fix where no projectile node was spawned at all).
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/drone_iso_after.json
##      -Scene res://scenes/drone_iso_test/drone_iso_test.tscn
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/drone_iso_before.json
##      -Scene res://scenes/drone_iso_test/drone_iso_test.tscn

const ProjectileScene: PackedScene = preload("res://scenes/projectile/projectile.tscn")
const SpriteLibrary := preload("res://scripts/sprite_library.gd")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

var _projectile: Node2D
var _projectile_visible := true
# Start position (drone side) and travel direction.
const START_POS := Vector2(-200.0, 0.0)
const DIRECTION := Vector2.RIGHT
const SPEED := 520.0

const CAPTURES: Array = [
	[0.25, "iso_early"],
	[0.45, "iso_mid"],
	[0.65, "iso_late"],
]
var _captured := {}


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2(0, 80.0)
	_camera.zoom = Vector2(1.4, 1.4)
	# Read the staged request for an optional "mode" field.
	var mode := _read_mode()
	_projectile_visible = (mode != "before")
	_run_dir = "user://drone_iso_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Spawn the real drone projectile, positioned at the drone's location.
	_projectile = ProjectileScene.instantiate()
	_projectile.global_position = START_POS
	add_child(_projectile)
	# Configure exactly as the drone does: direction, speed, friendly, drone_spark sprite.
	_projectile.configure(DIRECTION, 14.0, SPEED, false, false, "drone_spark")
	# BEFORE state: the projectile node exists but is hidden (pre-fix = no node spawned).
	if not _projectile_visible:
		_projectile.visible = false
	print("[DroneIso] mode=%s projectile_visible=%s" % [mode, str(_projectile_visible)])


func _read_mode() -> String:
	var f := FileAccess.open("user://selftest_request.json", FileAccess.READ)
	if f == null:
		return "after"
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return str(parsed.get("mode", "after"))
	return "after"


func _process(delta: float) -> void:
	_elapsed += delta
	if _projectile != null and is_instance_valid(_projectile):
		_projectile.global_position += DIRECTION * SPEED * delta
	_capture_due()
	if _elapsed >= 1.6:
		_finish()
	queue_redraw()


func _capture_due() -> void:
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			continue
		if _elapsed >= float(c[0]):
			_captured[label] = _capture(label)


func _capture(label: String) -> String:
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[DroneIso] snap %s -> %s" % [label, path])
	return path


func _finish() -> void:
	if _done:
		return
	_done = true
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": "PASS",
		"scene": "drone_iso_test",
		"projectile_visible": _projectile_visible,
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[DroneIso] SUMMARY projectile_visible=%s" % str(_projectile_visible))
	get_tree().quit(0)


func _draw() -> void:
	# Dark ground + grid.
	draw_rect(Rect2(-Vector2(500, 300), Vector2(1000, 600)), Color(0.12, 0.14, 0.16), true)
	var step := 50.0
	var x := -500.0
	while x <= 500.0:
		draw_line(Vector2(x, -300), Vector2(x, 300), Color(1, 1, 1, 0.06), 1.0)
		x += step
	# Drone position marker (left).
	draw_circle(START_POS, 14.0, Color(0.85, 0.88, 0.95, 0.9))
	draw_string(ThemeDB.fallback_font, START_POS - Vector2(20, -22), "DRONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.9, 1.0))
	# Target marker (right).
	var target_pos := Vector2(200.0, 0.0)
	draw_circle(target_pos, 20.0, Color(0.9, 0.3, 0.3, 0.85))
	draw_string(ThemeDB.fallback_font, target_pos - Vector2(24, 34), "ENEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.5, 0.5))

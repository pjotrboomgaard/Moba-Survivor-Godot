extends Node2D
## Isolated drone-projectile (T3.62) test scene.
##
## Verifies the drone's visible projectile now renders on screen:
##   1. A "player" stub (exposing only the surface the drone touches) stands at the left.
##   2. A gun-drone CompanionDrone orbits the player.
##   3. A single very-high-HP target in the drone's firing range sits at the right.
##   4. This root exposes spawn_player_projectile(...) — the SAME call the drone makes —
##      so we count how many projectiles the drone requested AND spawn a visible
##      SurvivorProjectile each time, so a screenshot catches one in flight.
##
## Fully isolated: no arena, no HUD, no world — just the drone + its projectile + a target.
## The report asserts projectiles_spawned >= 1 (the drone actually requested the shot).
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/drone_isolated_test.json
##      -Scene res://scenes/drone_isolated_test/drone_isolated_test.tscn

const CompanionDroneScript := preload("res://scripts/companion_drone.gd")
const ProjectileScene: PackedScene = preload("res://scenes/effects/projectile_sprite.tscn")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

var _player_stub: _PlayerStub
var _drone: Node2D
var _target_stub: Area2D
var _projectiles_spawned := 0
var _skip_projectile := false

const CAPTURES: Array = [
	[0.6, "d0_drone_idle"],
	[1.0, "d1_drone_firing"],
	[1.3, "d2_projectile_mid"],
	[1.6, "d3_projectile_late"],
	[2.0, "d4_target_still_alive"],
]
var _captured := {}


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	# Read the staged request for an optional "mode" field: "before" disables the
	# projectile visual (pre-fix state), "after" (default) shows it.
	_skip_projectile = _read_request_mode() == "before"
	_run_dir = "user://drone_isolated_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[DroneIso] mode=%s" % ("before" if _skip_projectile else "after"))

	_player_stub = _PlayerStub.new()
	_player_stub.global_position = Vector2(-150.0, 0.0)
	add_child(_player_stub)

	# Target at the right, well inside the drone's 300px reach. Give it a huge HP so it
	# survives the whole capture window and the drone keeps firing.
	_target_stub = Area2D.new()
	_target_stub.name = "TargetStub"
	_target_stub.global_position = Vector2(150.0, 0.0)
	_target_stub.add_to_group("enemies")
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	_target_stub.add_child(collision)
	var health := HealthComponent.new()
	health.max_health = 99999.0
	health.name = "HealthComponent"
	_target_stub.add_child(health)  # _ready() sets current_health = max_health
	add_child(_target_stub)

	_drone = CompanionDroneScript.new()
	add_child(_drone)
	_drone.setup(_player_stub, "gun_drone", 0)

	print("DRONE_ISOLATED_TEST ready: drone orbiting player, target in range")
	queue_redraw()


## The root exposes the exact method the drone calls (owner_player.get_parent()
## returns this root, since the player stub is a child of it). Counts the request and
## spawns a real visible SurvivorProjectile so a screenshot can catch it in flight.
## When mode is "before", we count but do NOT spawn the visual projectile.

func spawn_player_projectile(origin: Vector2, direction: Vector2, source) -> void:
	_projectiles_spawned += 1
	if _skip_projectile:
		print("[DroneIso] spawn_player_projectile #%d SKIPPED (before-state)" % _projectiles_spawned)
		return
	var projectile := ProjectileScene.instantiate()
	projectile.global_position = origin
	add_child(projectile)
	# Hostile=false so it targets "enemies" (the stub target) and uses the "spark" sprite.
	projectile.configure(direction, 10.0, 520.0, false, false, "spark")
	print("[DroneIso] spawn_player_projectile #%d from %s" % [_projectiles_spawned, str(origin)])


func _read_request_mode() -> String:
	# The harness stages the request JSON to user://selftest_request.json.
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
	_capture_due()
	if _elapsed > 5.5 and not _done:
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
	print("[DroneIso] snap %s -> %s (projectiles_spawned=%d)" % [label, path, _projectiles_spawned])
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
	var verdict := "PASS" if _projectiles_spawned >= 1 else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "drone_isolated_test",
		"projectiles_spawned": _projectiles_spawned,
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("DRONE_ISOLATED_TEST SUMMARY: projectiles_spawned=%d verdict=%s" % [_projectiles_spawned, verdict])
	get_tree().quit(0 if verdict == "PASS" else 1)


func _draw() -> void:
	draw_rect(Rect2(-Vector2(500, 300), Vector2(1000, 600)), Color(0.12, 0.14, 0.16), true)
	var step := 50.0
	var x := -500.0
	while x <= 500.0:
		draw_line(Vector2(x, -300), Vector2(x, 300), Color(1, 1, 1, 0.06), 1.0)
		x += step
	var y := -300.0
	while y <= 300.0:
		draw_line(Vector2(-500, y), Vector2(500, y), Color(1, 1, 1, 0.06), 1.0)
		y += step
	if _player_stub != null:
		draw_circle(_player_stub.global_position, 14.0, Color(0.3, 0.8, 0.9, 0.9))
		draw_string(ThemeDB.fallback_font, _player_stub.global_position - Vector2(20, 24), "PLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.9, 1.0))
	if _target_stub != null:
		draw_circle(_target_stub.global_position, 20.0, Color(0.9, 0.3, 0.3, 0.85))
		draw_string(ThemeDB.fallback_font, _target_stub.global_position - Vector2(24, 34), "ENEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.5, 0.5))
	if _drone != null and is_instance_valid(_drone):
		draw_string(ThemeDB.fallback_font, _drone.global_position - Vector2(14, -18), "DRONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0))


## Minimal stand-in for Player: exposes only the surface the CompanionDrone touches.
class _PlayerStub:
	extends Node2D
	var active := true
	var damage_dealt_multiplier := 1.0
	var weapon_damage := 10.0

	func _damage_enemy(_target: Node, _power: float) -> void:
		pass

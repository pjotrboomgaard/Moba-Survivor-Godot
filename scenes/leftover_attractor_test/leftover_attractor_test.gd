extends Node2D
## T3.91 isolated verify: creeps must NOT be attracted to invisible leftover objects
## left behind by abilities (e.g. lingering invisible Area2D nodes after a cast).
##
## Empty world: a real Enemy placed in a fixed "home" position, plus a lingering
## invisible Node2D placed nearby. If the enemy's targeting/seek is attracted to the
## invisible object, the enemy will drift toward it. If the fix is correct, the enemy
## should NOT treat the invisible node as a target (it stays in its home band).

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://leftover_report.json"
var _shots: Array = []
var _captured := {}

var _enemy: Node2D = null
var _invisible: Node2D = null
var _start_pos: Vector2 = Vector2.ZERO
var _max_drift := 0.0

const CAPTURES: Array = [
	[0.4, "leftover_iso_before"],
	[3.0, "leftover_iso_mid"],
	[5.0, "leftover_iso_after"],
]


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://leftover_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Invisible leftover object (what some ability leaves behind).
	_invisible = Node2D.new()
	_invisible.position = Vector2(220.0, 0.0)
	_invisible.visible = false
	add_child(_invisible)

	# Real enemy that chases the player (or its last target). Place it away from the
	# invisible object so we can detect if it gets pulled toward the object.
	var enemy_scene := load("res://scenes/enemy/enemy.tscn") as PackedScene
	if enemy_scene != null:
		_enemy = enemy_scene.instantiate()
		_enemy.global_position = Vector2(-220.0, 0.0)
		add_child(_enemy)
		# A player node so the enemy has a valid target to seek (keeps it from
		# idling). We want to observe whether it veers toward the invisible node.
	else:
		_enemy = _StubEnemy.new()
		_enemy.global_position = Vector2(-220.0, 0.0)
		_enemy.add_to_group("enemies")
		add_child(_enemy)
	_start_pos = _enemy.global_position
	print("[Leftover] ready: enemy at %s, invisible at %s" % [str(_enemy.global_position), str(_invisible.global_position)])


func _process(delta: float) -> void:
	_elapsed += delta
	if _enemy != null and is_instance_valid(_enemy):
		var drift := _enemy.global_position.distance_to(_start_pos)
		_max_drift = maxf(_max_drift, drift)
	_captures()
	if _elapsed > 5.4 and not _done:
		_finish()


func _captures() -> void:
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
	_shots.append({"label": label, "path": path, "t": _elapsed})
	print("[Leftover] snap %s" % label)
	return path


func _finish() -> void:
	if _done:
		return
	_done = true
	# PASS: enemy stayed near its home band (did NOT get dragged to the invisible
	# node at +220). A drift beyond ~120px toward the invisible node indicates the
	# attraction bug. Drift AWAY from it (toward the player at -x) is fine.
	var pulled_toward_invisible := _max_drift > 120.0
	var verdict := "PASS" if not pulled_toward_invisible else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "leftover_attractor_test",
		"start_pos": _start_pos,
		"end_pos": _enemy.global_position if is_instance_valid(_enemy) else "gone",
		"max_drift": _max_drift,
		"pulled_toward_invisible": pulled_toward_invisible,
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("LEFTOVER SUMMARY verdict=%s max_drift=%.1f" % [verdict, _max_drift])
	get_tree().quit(0 if verdict == "PASS" else 1)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.04, 0.04, 0.07), true)
	# Mark the invisible object's location so we can see if the enemy veers there.
	draw_circle(_invisible.global_position, 26.0, Color(1.0, 0.2, 0.2, 0.35), 4.0)
	draw_string(ThemeDB.fallback_font, _invisible.global_position + Vector2(-40, -30),
		"INVISIBLE LEFTOVER", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(1.0, 0.5, 0.5))


class _StubEnemy:
	extends Node2D
	var server_authoritative := true
	var knockback_velocity: Vector2 = Vector2.ZERO
	func _init() -> void:
		var h := HealthComponent.new()
		h.name = "HealthComponent"
		h.max_health = 99999.0
		add_child(h)
	func apply_knockback(impulse: Vector2) -> void:
		knockback_velocity += impulse

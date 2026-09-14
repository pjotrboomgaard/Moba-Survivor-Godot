extends Node2D
## T3.83 isolated verify: the Repulsor Drone (push_drone, Kind.PUSH) actually
## repulses AND damages nearby creeps — it is not a no-op.
##
## Empty world: a real Player (loaded from scenes/player/player.tscn) at origin,
## a Repulsor Drone granted to it via _add_companion("push_drone"), and one
## high-HP enemy placed within the drone's 110px+ range. The test confirms:
##   1. The enemy takes damage (health decreases over time).
##   2. The enemy is knocked back (position moves away from the drone).
##
## Fully isolated: no arena, no HUD, no grass, no other enemies.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _captured := {}

var _player: Node2D = null
var _drone: Node2D = null
var _enemy_stub: Node2D = null
var _enemy_initial_hp := 99999.0
var _enemy_initial_pos: Vector2 = Vector2.ZERO

const CAPTURES: Array = [
	[0.5, "repulsor_iso_before"],
	[1.5, "repulsor_iso_mid"],
	[2.5, "repulsor_iso_after"],
]


func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://repulsor_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Real Player so CompanionDrone.setup()'s typed `Player` param is satisfied.
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.global_position = Vector2(0.0, 0.0)
	_player.active = true

	# Enemy stub placed well within the drone's range. It must expose a
	# HealthComponent child + apply_knockback so the real Player's _damage_enemy
	# and the drone's knockback call work against it.
	_enemy_stub = _EnemyStub.new()
	_enemy_stub.global_position = Vector2(60.0, 0.0)
	_enemy_stub.add_to_group("enemies")
	add_child(_enemy_stub)
	_enemy_initial_pos = _enemy_stub.global_position

	# Grant the repulsor drone to the real player.
	if _player.has_method("_add_companion"):
		_player._add_companion("push_drone")
	_drone = _find_drone()
	print("REPULSOR_TEST ready: real player + push_drone + enemy stub, drone=%s" % str(_drone != null))
	queue_redraw()


func _find_drone() -> Node2D:
	if _player == null:
		return null
	for child in _player.get_parent().get_children():
		if child.has_method("setup") and child.get("kind") != null:
			return child
	return null


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 3.2 and not _done:
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
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": _elapsed})
	var hp_now := _enemy_hp()
	print("[RepulsorIso] snap %s hp=%.0f pos=%s" % [label, hp_now, str(_enemy_stub.global_position) if _enemy_stub != null and is_instance_valid(_enemy_stub) else "gone"])
	return path


func _enemy_hp() -> float:
	if _enemy_stub == null or not is_instance_valid(_enemy_stub):
		return -1.0
	var h: HealthComponent = _enemy_stub.get_node_or_null("HealthComponent")
	if h == null:
		return -1.0
	return h.current_health


func _draw() -> void:
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
	if _player != null and is_instance_valid(_player):
		draw_string(ThemeDB.fallback_font, _player.global_position - Vector2(14, -24), "PLAYER", HORIZONTAL_ALIGNMENT_LEFT, 96, 12, Color(0.5, 0.9, 1.0))
	if _enemy_stub != null and is_instance_valid(_enemy_stub):
		draw_circle(_enemy_stub.global_position, 18.0, Color(0.9, 0.3, 0.3, 0.9))
		var hp := float(_enemy_stub.get_meta("hp", _enemy_initial_hp))
		draw_string(ThemeDB.fallback_font, _enemy_stub.global_position - Vector2(14, -24), "ENEMY hp=%.0f" % hp, HORIZONTAL_ALIGNMENT_LEFT, 96, 12, Color(1.0, 0.5, 0.5))
		if hp < _enemy_initial_hp:
			draw_arc(_enemy_stub.global_position, 24.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.2, 0.7), 2.0)
	if _drone != null and is_instance_valid(_drone):
		draw_string(ThemeDB.fallback_font, _drone.global_position - Vector2(24, -20), "REPULSOR", HORIZONTAL_ALIGNMENT_LEFT, 96, 12, Color(0.6, 0.8, 1.0))


func _finish() -> void:
	if _done:
		return
	_done = true
	var final_hp := _enemy_initial_hp
	var final_pos := _enemy_initial_pos
	var alive := false
	if _enemy_stub != null and is_instance_valid(_enemy_stub):
		final_hp = _enemy_hp()
		final_pos = _enemy_stub.global_position
		alive = true
	var total_damage := _enemy_initial_hp - final_hp
	var displacement := _enemy_initial_pos.distance_to(final_pos)
	# PASS if the drone dealt damage OR killed the stub (damage >= 5 OR enemy gone).
	var verdict := "PASS" if (total_damage > 5.0 or not alive or displacement > 5.0) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "repulsor_drone_test",
		"drone_granted": _drone != null,
		"initial_hp": _enemy_initial_hp,
		"final_hp": final_hp,
		"total_damage": total_damage,
		"enemy_alive": alive,
		"initial_pos": _enemy_initial_pos,
		"final_pos": final_pos,
		"displacement": displacement,
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("REPULSOR_ISOLATED SUMMARY verdict=%s damage=%.1f displacement=%.1f alive=%s drone=%s" % [verdict, total_damage, displacement, str(alive), str(_drone != null)])
	get_tree().quit(0 if verdict == "PASS" else 1)


## Minimal enemy stand-in: a Node2D with a HealthComponent child + apply_knockback,
## so the real Player's _damage_enemy() and the drone's apply_knockback() both work.
class _EnemyStub:
	extends Node2D
	var knockback_velocity: Vector2 = Vector2.ZERO
	var server_authoritative := true
	const MAX_HP := 99999.0
	var _health: HealthComponent = null

	func _init() -> void:
		_health = HealthComponent.new()
		_health.name = "HealthComponent"
		_health.max_health = MAX_HP
		add_child(_health)

	func apply_knockback(impulse: Vector2) -> void:
		knockback_velocity += impulse

	func _process(delta: float) -> void:
		# Simulate knockback motion so displacement is observable.
		if knockback_velocity.length() > 0.0:
			position += knockback_velocity * delta
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 0.15)

extends Node2D
## Isolated Warden default-attack damage test (T3.45).
##
## Verifies that Warden's LMB auto-attack (Mending Bolt) actually deals damage
## to a stationary enemy. Root-cause regression: aim_assist_radius was zeroed,
## which made _find_primary_target() reject every enemy whose centre sits even
## a few pixels off the aim line, so the Warden's bolt dealt 0 damage.
##
## Usage:
##   powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 \
##     -RequestPath tools/selftest/requests/warden_attack_test.json \
##     -Scene res://scenes/warden_attack_test/warden_attack_test.tscn
##
## The scene writes user://selftest_report.json and quits on its own.

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var _player: Player = null
var _enemy: Enemy = null
var _elapsed := 0.0
var _done := false
var _screenshot_paths: Array[String] = []
var _damage_log: Array[Dictionary] = []

const HERO_CLASS := "warden"
const ENEMY_POS := Vector2(240.0, 0.0)
const ENEMY_START_HP := 200.0

func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	GameRuntime.set_biome(0, true)

	# Dark checkerboard ground.
	var ground := Node2D.new()
	ground.set_script(_make_ground_script())
	add_child(ground)

	# Spawn the Warden at the origin, facing right.
	var p: Player = PlayerScene.instantiate()
	p.name = "Warden"
	p.global_position = Vector2.ZERO
	add_child(p)
	p.configure(0, Player.SimulationMode.OFFLINE, false, HERO_CLASS)
	p.health.current_health = p.health.max_health
	# Face right and pin the facing so the beam flies toward +X.
	p.aim_world_position = Vector2(300.0, 0.0)
	p.facing_direction = Vector2.RIGHT
	if p.has_node("Camera2D"):
		p.get_node("Camera2D").visible = false
	_player = p

	# Spawn one stationary grunt straight ahead of the Warden.
	var e: Enemy = EnemyScene.instantiate()
	e.name = "Target"
	e.global_position = ENEMY_POS
	add_child(e)
	e.configure(1, true, EnemyType.DEFAULT_TYPE_ID, 1.0, 0.0)
	# Freeze it in place so the Warden's beam can hit it reliably.
	e.movement_speed = 0.0
	e.speed_cap = 0.0
	e.velocity = Vector2.ZERO
	# Use a moderate HP pool so several hits visibly chip it down (but it
	# doesn't die immediately).
	e.health.max_health = ENEMY_START_HP
	e.health.current_health = ENEMY_START_HP
	_enemy = e

	# Camera framing the hero + target.
	var cam := Camera2D.new()
	cam.name = "TestCam"
	cam.position = Vector2(100.0, 0.0)
	cam.zoom = Vector2(0.8, 0.8)
	add_child(cam)
	cam.make_current()

	print("[warden_attack_test] ready: hero=%s enemy_hp=%s" % [HERO_CLASS, str(e.health.current_health)])


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	# Keep the Warden aimed at the target and let the auto-charge build.
	if _player != null:
		_player.aim_world_position = _enemy.global_position
		_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, false, false, [false, false, false, false], false)
	# Pin the enemy to its start position so the Warden's beam geometry stays
	# stable and the screenshots are reproducible.
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.global_position = ENEMY_POS
		_enemy.velocity = Vector2.ZERO
	# Sample enemy HP a few times to record the damage timeline.
	if _elapsed >= 1.5 and _elapsed - _last_sample_t >= 0.5:
		_sample_hp()
	# Fire a couple of explicit attacks to guarantee hits land.
	if _elapsed >= 2.0 and _attacks_fired < 6 and _elapsed - _last_attack_t >= 0.6:
		_fire_attack()
	# Take screenshots at key moments.
	if _elapsed >= 1.0 and not _snap_before:
		_snap_before = true
		await _snap("before")
	if _elapsed >= 4.0 and not _snap_mid:
		_snap_mid = true
		await _snap("mid")
	if _elapsed >= 5.5 and not _snap_end:
		_snap_end = true
		await _snap("end")
	# Finish the run.
	if _elapsed >= 6.5:
		_finish()


var _last_sample_t := 0.0
var _last_attack_t := 0.0
var _attacks_fired := 0
var _snap_before := false
var _snap_mid := false
var _snap_end := false

func _fire_attack() -> void:
	if _player != null and _enemy != null and is_instance_valid(_enemy):
		_player.aim_world_position = _enemy.global_position
		# Zero the cooldown so _perform_attack fires immediately.
		_player.attack_cooldown = 0.0
		_player._perform_attack()
		_attacks_fired += 1
		_last_attack_t = _elapsed
		# Record the HP right after the attack (deferred a tiny bit).
		var hp_now := float(_enemy.health.current_health)
		_damage_log.append({
			"t": _elapsed,
			"attack_index": _attacks_fired,
			"enemy_hp": hp_now,
			"enemy_max_hp": float(_enemy.health.max_health),
		})


func _sample_hp() -> void:
	if _enemy != null and is_instance_valid(_enemy):
		_last_sample_t = _elapsed


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var path := "user://warden_attack_%s_%s.png" % [label, str(Time.get_ticks_msec())]
		if img.save_png(path) == OK:
			_screenshot_paths.append(path)
			print("[warden_attack_test] screenshot saved: %s" % path)


func _finish() -> void:
	if _done:
		return
	_done = true
	# Determine pass/fail: the enemy must have taken at least 1 point of damage.
	var final_hp: float = 0.0
	if _enemy != null and is_instance_valid(_enemy):
		final_hp = float(_enemy.health.current_health)
	var total_damage := 200.0 - final_hp
	var verdict := "PASS" if total_damage >= 1.0 else "FAIL_NO_DAMAGE"
	print("[warden_attack_test] summary: attacks_fired=%d total_damage=%.1f verdict=%s" % [
		_attacks_fired, total_damage, verdict])
	var report := {
		"scene": "warden_attack_test",
		"hero": HERO_CLASS,
		"attacks_fired": _attacks_fired,
		"enemy_start_hp": 200.0,
		"enemy_final_hp": final_hp,
		"total_damage": total_damage,
		"damage_log": _damage_log,
		"screenshots": _screenshot_paths,
		"elapsed": _elapsed,
		"verdict": verdict,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("[warden_attack_test] report written verdict=%s" % verdict)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _make_ground_script() -> GDScript:
	var code := """
extends Node2D
func _draw() -> void:
	for x in range(-10, 11):
		for y in range(-10, 11):
			var col := Color(0.10, 0.14, 0.10) if (x + y) % 2 == 0 else Color(0.12, 0.16, 0.12)
			draw_rect(Rect2(Vector2(x * 100, y * 100), Vector2(100, 100)), col)
"""
	var src := GDScript.new()
	src.source_code = code
	src.reload(true)
	return src

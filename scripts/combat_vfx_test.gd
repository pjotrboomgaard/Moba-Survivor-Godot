extends Node2D
## Isolated combat VFX test scene (P1.21).
##
## Verifies that hero combat VFX render correctly in a clean, empty world:
##   - LMB primary attack: projectile/blast visible
##   - RMB secondary: charge + release blast visible
##   - Q ability: themed effect visible
##   - Tobor-specific: turret/mine "throw" animation visible
##
## Usage:
##   powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 \
##     -RequestPath tools/selftest/requests/combat_vfx_isolated.json \
##     -Scene res://scenes/combat_vfx_test/combat_vfx_test.tscn
##
## The request JSON includes "hero" to select which hero to test.

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var test_hero: String = "arclight"
var _player: Player = null
var _creeps: Array[Enemy] = []
var _elapsed := 0.0
var _done := false
var _sequence_started := false
var _screenshot_paths: Array[String] = []
var _active_fx_count := 0

func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	GameRuntime.set_biome(0, true)

	# Read hero from selftest request.
	var req: Dictionary = {}
	if FileAccess.file_exists("user://selftest_request.json"):
		var f := FileAccess.open("user://selftest_request.json", FileAccess.READ)
		if f != null:
			req = JSON.parse_string(f.get_as_text())
			f.close()
	if req != null and req.has("hero"):
		test_hero = str(req["hero"])

	print("COMBAT_VFX_TEST ready: hero=%s" % test_hero)

	# Draw a simple dark ground.
	var ground := Node2D.new()
	ground.set_script(_make_ground_script())
	add_child(ground)

	# Spawn the hero at origin.
	var p: Player = PlayerScene.instantiate()
	p.name = "TestHero"
	p.global_position = Vector2.ZERO
	add_child(p)
	p.configure(0, Player.SimulationMode.OFFLINE, false, test_hero)
	p.health.current_health = p.health.max_health
	if p.has_node("Camera2D"):
		var cam := p.get_node("Camera2D") as Camera2D
		cam.limit_left = -2000
		cam.limit_top = -2000
		cam.limit_right = 2000
		cam.limit_bottom = 2000
	_player = p

	# Spawn 4 creeps in a line ahead of the hero.
	for i in 4:
		var e: Enemy = EnemyScene.instantiate()
		e.name = "TestCreep%d" % i
		e.global_position = Vector2(200.0, -90.0 + 60.0 * i)
		add_child(e)
		e.configure(100 + i, true, EnemyType.DEFAULT_TYPE_ID, 1.0, 0.0)
		e.movement_speed = 0.0
		e.speed_cap = 0.0
		e.velocity = Vector2.ZERO
		# Make creeps invincible so they stay alive for the full test.
		if e.has_node("HealthComponent"):
			var hc: Node = e.get_node("HealthComponent")
			hc.set("max_health", 99999.0)
			hc.set("current_health", 99999.0)
		_creeps.append(e)

	# Camera: frame the hero and the creeps.
	var cam := Camera2D.new()
	cam.name = "TestCam"
	cam.position = Vector2(80.0, 0.0)
	cam.zoom = Vector2(0.5, 0.5)
	add_child(cam)
	cam.make_current()

	# Connect to the hero's ability_cast signal to count VFX spawns.
	if _player.has_signal("ability_cast"):
		_player.ability_cast.connect(_on_ability_cast)


func _on_ability_cast(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	_active_fx_count += 1
	print("COMBAT_VFX_TEST ability_cast: %s style=%d points=%d" % [ability_id, effect_style, points.size()])


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


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var path := "user://combat_vfx_%s_%s.png" % [test_hero, label]
		if img.save_png(path) == OK:
			_screenshot_paths.append(path)
			print("COMBAT_VFX_TEST screenshot saved: %s" % path)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed >= 3.0 and not _sequence_started:
		_sequence_started = true
		_run_test_sequence()


func _run_test_sequence() -> void:
	if _done:
		return
	# Phase 1: aim at creeps and hold LMB for 1.5s to fire multiple projectiles.
	var c0 := _valid_creep(0)
	if c0 == null:
		_finish()
		return
	_player.aim_world_position = c0.global_position
	_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, true, false, [false, false, false, false], false)
	await get_tree().create_timer(1.5).timeout
	await _snap("lmb_blast")

	# Phase 2: charge RMB (hold for 0.8s then release).
	var c1 := _valid_creep(1)
	if c1 == null:
		_finish()
		return
	_player.aim_world_position = c1.global_position
	_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, false, false, [false, false, false, false], true)
	await get_tree().create_timer(0.4).timeout
	await _snap("rmb_charging")
	_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, false, false, [false, false, false, false], false)
	await get_tree().create_timer(0.2).timeout
	await _snap("rmb_release")

	# Phase 3: cast Q ability.
	var c2 := _valid_creep(2)
	_player.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	_player.aim_world_position = c2.global_position if c2 != null else _player.global_position + Vector2(120.0, 0.0)
	await get_tree().create_timer(0.2).timeout
	_player.scripted_tap_ability(0)
	await get_tree().create_timer(0.8).timeout
	await _snap("q_cast")

	# Phase 4: Tobor-specific — cast W (turret) and E (mines) if Tobor.
	if test_hero == "tobor":
		var c3 := _valid_creep(0)
		_player.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
		var aim_t := c3.global_position + Vector2(-100.0, 0.0) if c3 != null else _player.global_position + Vector2(100.0, 0.0)
		_player.aim_world_position = aim_t
		await get_tree().create_timer(0.2).timeout
		_player.scripted_tap_ability(1)  # W = turret
		await get_tree().create_timer(0.5).timeout
		await _snap("tobor_turret_throw")
		_player.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
		var aim_m := c3.global_position + Vector2(-80.0, 0.0) if c3 != null else _player.global_position + Vector2(100.0, 0.0)
		_player.aim_world_position = aim_m
		await get_tree().create_timer(0.2).timeout
		_player.scripted_tap_ability(2)  # E = mines
		await get_tree().create_timer(0.5).timeout
		await _snap("tobor_mines_throw")

	# Wait for all VFX to finish animating.
	await get_tree().create_timer(1.5).timeout

	_finish()


## Return a valid (not freed) creep at index i, or null if gone.
func _valid_creep(i: int) -> Enemy:
	if i < _creeps.size():
		var c := _creeps[i]
		if c != null and is_instance_valid(c):
			return c
	return null


func _finish() -> void:
	if _done:
		return
	_done = true
	print("COMBAT_VFX_TEST summary: hero=%s active_fx_events=%d screenshots=%d" % [test_hero, _active_fx_count, _screenshot_paths.size()])
	var report := {
		"scene": "combat_vfx_test",
		"hero": test_hero,
		"active_fx_events": _active_fx_count,
		"screenshots": _screenshot_paths,
		"elapsed": _elapsed,
		"verdict": "PASS_OK" if _active_fx_count >= 2 else "FAIL_NO_VFX",
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("COMBAT_VFX_TEST report written verdict=%s" % report["verdict"])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

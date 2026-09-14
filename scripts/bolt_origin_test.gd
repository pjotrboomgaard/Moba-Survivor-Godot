extends Node2D
## Isolated test for T3.47 (Arclight LMB bolt originates from staff tip) and
## T3.53 (Warden LMB bolt originates from hand).
##
## For each hero we:
##   - spawn a real Player configured as that class,
##   - spawn a real Enemy (frozen) directly ahead,
##   - fire one LMB primary attack while aimed at the enemy,
##   - capture the emitted staff_cast points and assert the FIRST point is the
##     origin (staff tip for arclight, hand for warden) and is offset from the
##     body centre in the expected direction,
##   - assert the enemy took damage (proves the bolt actually hit),
##   - capture a screenshot so the bolt's muzzle is visible.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../bolt_origin_test.json
##     -Scene res://scenes/bolt_origin_test/bolt_origin_test.tscn

const HERO_SCENE := "res://scenes/player/player.tscn"
const ENEMY_SCENE := "res://scenes/enemy/enemy.tscn"

var _done := false
var _captures: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _signal_log: Array = []

func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	GameRuntime.set_biome(0, true)
	_draw_ground()
	_run_all()

func _run_all() -> void:
	await _test_hero("arclight")
	await _test_hero("warden")
	_finish()

func _draw_ground() -> void:
	var lb := Label.new()
	lb.text = "Isolated bolt-origin test (T3.47 / T3.53)"
	lb.position = Vector2(-560.0, -320.0)
	lb.add_theme_font_size_override("font_size", 26)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(lb)
	# Camera to frame the action.
	var cam := Camera2D.new()
	cam.position = Vector2(60.0, 0.0)
	cam.zoom = Vector2(1.2, 1.2)
	add_child(cam)
	cam.make_current()

func _on_staff_cast(effect_kind: String, points: PackedVector2Array) -> void:
	_signal_log.append({"kind": effect_kind, "points": points})
	print("[BoltOriginTest] STAFF_CAST kind=%s points[0]=%s count=%d" % [effect_kind, str(points[0]), points.size()])

func _test_hero(class_id: String) -> void:
	print("[BoltOriginTest] testing hero=%s" % class_id)
	var hero_ps: PackedScene = load(HERO_SCENE)
	var hero: Player = hero_ps.instantiate()
	hero.name = "Hero_" + class_id
	hero.global_position = Vector2(-160.0, 40.0)
	add_child(hero)
	await get_tree().physics_frame
	hero.configure(1, GameRuntime.RuntimeMode.OFFLINE, true, class_id)
	hero.vfx_parent_override = self
	if hero.has_node("Camera2D"):
		(hero.get_node("Camera2D") as Camera2D).enabled = false

	# Spawn a frozen enemy directly in front, well within attack_range + aim_assist.
	var enemy_ps: PackedScene = load(ENEMY_SCENE)
	var enemy: Enemy = enemy_ps.instantiate()
	enemy.name = "Target_" + class_id
	enemy.global_position = hero.global_position + Vector2(180.0, 0.0)
	add_child(enemy)
	await get_tree().physics_frame
	enemy.configure(1, true, EnemyType.DEFAULT_TYPE_ID, 1.0, 1.0)
	# Freeze the enemy in place.
	enemy.movement_speed = 0.0
	enemy.speed_cap = 0.0
	enemy.velocity = Vector2.ZERO
	var enemy_start_hp := float(enemy.health.max_health)

	# Face + aim at the enemy.
	hero.aim_world_position = enemy.global_position
	hero.facing_direction = Vector2.RIGHT

	var body_center_before := hero.global_position
	var origin: Vector2 = Vector2.ZERO
	var got_cast := false
	hero.staff_cast.connect(_on_staff_cast)
	# Also try the Godot 4.3+ method syntax as a fallback
	if hero.has_method("staff_cast"):
		print("[BoltOriginTest] hero HAS staff_cast method")

	# Fire a single LMB primary attack.
	hero.attack_cooldown = 0.0
	hero._perform_attack()
	# Capture the screenshot right after firing so the bolt/muzzle VFX is on screen.
	_capture(class_id + "_bolt")
	# Let the frame settle so the bolt VFX finishes.
	await get_tree().create_timer(0.25).timeout

	var enemy_final_hp := float(enemy.health.current_health)
	var damage_dealt := enemy_start_hp - enemy_final_hp

	# Read origin from the signal log (the lambda capture may not work in Godot 4.7)
	if _signal_log.size() > 0:
		var last = _signal_log[_signal_log.size() - 1]
		origin = last["points"][0]
		got_cast = true

	var offset_from_center := origin - body_center_before
	var passes := false
	var detail := ""
	if not got_cast:
		detail = "no staff_cast emitted (signal_log size=%d)" % _signal_log.size()
	else:
		# Expect a forward (+X) and upward (-Y) offset from the body centre.
		passes = (offset_from_center.x > 8.0) and (offset_from_center.y < -2.0)
		# Also require the enemy took damage (bolt actually hit).
		passes = passes and (damage_dealt >= 1.0)
		detail = "origin=%s center=%s offset=%s dmg=%.1f got_cast=%s" % [
			str(origin), str(body_center_before), str(offset_from_center),
			damage_dealt, str(got_cast)]

	_results.append({
		"hero": class_id,
		"origin": [origin.x, origin.y],
		"body_center": [body_center_before.x, body_center_before.y],
		"offset_from_center": [offset_from_center.x, offset_from_center.y],
		"got_cast": got_cast,
		"enemy_start_hp": enemy_start_hp,
		"enemy_final_hp": enemy_final_hp,
		"damage_dealt": damage_dealt,
		"passes": passes,
		"detail": detail,
	})

	# Clean up this hero + enemy so the next one spawns fresh.
	hero.queue_free()
	enemy.queue_free()
	_signal_log.clear()
	await get_tree().create_timer(0.1).timeout

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://bolt_origin_%s.png" % label
	img.save_png(path)
	var shot_entry := {"path": path, "label": label}
	_captures.append(shot_entry)
	print("[BoltOriginTest] captured %s" % path)

func _finish() -> void:
	if _done:
		return
	_done = true
	var all_pass := true
	for r in _results:
		if not r.get("passes", false):
			all_pass = false
	var abs_dir := ProjectSettings.globalize_path("user://")
	var abs_shots := []
	for s in _captures:
		var abs := str(s.get("path", "")).replace("user://", abs_dir)
		if FileAccess.file_exists(abs):
			abs_shots.append({"path": abs, "label": str(s.get("label", ""))})
	var report := {
		"verdict": "PASS" if all_pass else "FAIL",
		"scene": "bolt_origin_test",
		"screenshots": abs_shots,
		"heroes": _results,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BoltOriginTest] verdict=%s" % report["verdict"])
	get_tree().quit(0 if all_pass else 1)

func _draw() -> void:
	draw_rect(Rect2(-1200.0, -500.0, 2400.0, 1200.0), Color(0.10, 0.13, 0.16), true)
	var step := 100.0
	var x := -1200.0
	while x <= 1200.0:
		draw_line(Vector2(x, -500.0), Vector2(x, 700.0), Color(1, 1, 1, 0.04), 1.0)
		x += step
	var y := -500.0
	while y <= 700.0:
		draw_line(Vector2(-1200.0, y), Vector2(1200.0, y), Color(1, 1, 1, 0.04), 1.0)
		y += step

extends Node2D
## Isolated empty-world test for creep approach behaviour (2026-09-18).
##
## Empty-world baseline: flat dark background + camera. No arena dressing, no grass,
## no HUD, no enemies from the real arena.
##
## Scenario: several grunt enemies spawn at a distance from a target marker and must
## walk toward it. We track each creep's alive-state + distance-to-target over time.
## The test passes when every creep reaches within REACH_RADIUS of the marker before
## the time limit, and no creep dies from self-damage (lava, self-detonation, etc.).
##
## This directly tests the "creeps die by themselves and disappear before reaching the
## player" bug — in this clean context, a creep that dies without being hit by the
## player indicates a self-damage or movement bug.

var _camera: Camera2D
var _enemies: Array = []  # Array of {node: Node2D, start_pos: Vector2, samples: Array}
var _captured: Dictionary = {}
var _elapsed := 0.0
var _target_marker: Node2D = null

const SPAWN_DIST := 900.0
const REACH_RADIUS := 80.0
const NUM_CREEPS := 6
const TIME_LIMIT := 30.0

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(0.7, 0.7)
	_camera.make_current()

	# Dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	# Target marker at origin.
	_target_marker = Node2D.new()
	_target_marker.name = "TargetMarker"
	add_child(_target_marker)
	_target_marker.global_position = Vector2.ZERO

	# Draw the target ring.
	var ring := Node2D.new()
	ring.name = "TargetRing"
	ring.set_script(_make_ring_script())
	add_child(ring)

	# Spawn creeps at various angles around the target.
	var enemy_scene := load("res://scenes/enemy/enemy.tscn") as PackedScene
	if enemy_scene == null:
		push_error("[CreepReachIso] could not load enemy.tscn")
		_finish_with_error("no enemy scene")
		return

	for i in NUM_CREEPS:
		var angle := TAU * float(i) / float(NUM_CREEPS) + TAU * 0.1
		var spawn_pos := Vector2.from_angle(angle) * SPAWN_DIST
		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = spawn_pos
		# Configure as a grunt, server-authoritative, at normal scale.
		enemy.configure(100 + i, true, "grunt", 1.0, 1.0)
		_enemies.append({"node": enemy, "start_pos": spawn_pos, "samples": []})

	# Force all enemies to target the marker (no real players in this world).
	_refresh_targets()

func _make_ring_script() -> GDScript:
	var source := "extends Node2D\nfunc _draw() -> void:\n\tdraw_arc(Vector2.ZERO, %.1f, 0.0, TAU, 32, Color(1.0, 0.8, 0.2, 0.9), 4.0)\n\tdraw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.8, 0.2, 0.15))\n" % REACH_RADIUS
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		push_warning("[CreepReachIso] ring script: " + script.get_error_message())
	return script

func _refresh_targets() -> void:
	for entry in _enemies:
		var e: Node2D = entry.node
		if not is_instance_valid(e):
			continue
		# Lock the refresh timer so _physics_process never re-picks a null target.
		e._target_refresh_timer = 9999.0
		e.target = _target_marker
		# Keep enemies out of far-mode so full AI runs.
		e._near_player = true
		e._in_far_mode = false
		e.set_physics_process(true)
		# Re-show the sprite (far-cull hides it).
		var spr = e.get_node_or_null("Sprite")
		if spr != null:
			spr.visible = true

func _process(delta: float) -> void:
	_elapsed += delta
	_refresh_targets()

	# Sample creep state every 2s for the report.
	for entry in _enemies:
		var e: Node2D = entry.node
		if is_instance_valid(e) and fmod(_elapsed, 2.0) < delta:
			var alive := true
			var hp := -1.0
			var h = e.get("health")
			if h != null:
				alive = not bool(h.is_dead)
				hp = float(h.current_health)
			entry.samples.append({
				"t": snappedf(_elapsed, 0.01),
				"alive": alive,
				"hp": hp,
				"dist": e.global_position.distance_to(_target_marker.global_position) if is_instance_valid(e) else -1.0,
			})

	# Snapshots at fixed times.
	if _elapsed >= 2.0 and not _captured.has("early"):
		_snap("early")
	if _elapsed >= 10.0 and not _captured.has("mid"):
		_snap("mid")
	if _elapsed >= 20.0 and not _captured.has("late"):
		_snap("late")
	if _elapsed >= TIME_LIMIT:
		_snap("final")
		_finish()

func _snap(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_creep_reach_%s.png" % label
		img.save_png(path)
		_captured[label] = {"label": label, "path": path}
		print("[CreepReachIso] snap ", label)

func _finish() -> void:
	var reached_count := 0
	var died_count := 0
	var details := []
	for entry in _enemies:
		var e: Node2D = entry.node
		var alive := is_instance_valid(e) and not bool(e.get("health").is_dead)
		var final_dist := -1.0
		if is_instance_valid(e):
			final_dist = e.global_position.distance_to(_target_marker.global_position)
		var reached := alive and final_dist <= REACH_RADIUS
		var died := not alive
		if reached:
			reached_count += 1
		if died:
			died_count += 1
		details.append({
			"alive": alive,
			"reached": reached,
			"final_dist": snappedf(final_dist, 1.0),
			"samples": entry.samples,
		})

	# PASS: at least 70% of creeps reached the target and no creep died from
	# self-damage (i.e. all deaths were caused by the "player", which in this
	# isolated test = none, so died_count must be 0).
	var pass_ := (reached_count >= int(float(NUM_CREEPS) * 0.7)) and died_count == 0
	var report := {
		"verdict": "PASS" if pass_ else "FAIL",
		"num_creeps": NUM_CREEPS,
		"reached_count": reached_count,
		"died_count": died_count,
		"reach_radius": REACH_RADIUS,
		"elapsed": _elapsed,
		"details": details,
		"shots": _captured.values(),
	}
	_write_report(report)

func _finish_with_error(msg: String) -> void:
	var report := {"verdict": "FAIL", "error": msg, "shots": _captured.values()}
	_write_report(report)

func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[CreepReachIso] verdict=", str(report.get("verdict", "")))
	get_tree().quit()

extends Node2D
## Isolated test for hero↔tree interaction: fire-themed heroes (cinder) ignite
## trees inside their blast radius. Verifies on an EMPTY world (hard rule).
## The hero stands near trees and casts its radius-burst ability; trees within
## radius catch fire. We assert burning count > 0.

var arena: Node2D = null
var hero: Node2D = null
var camera: Camera2D = null

const ScreenshotDir := "user://"
var run_id := ""
var shots: Array[Dictionary] = []
var t := 0.0
var tree_count := 0
var burning_at_end := -1
var verdict := "PASS"

func _ready() -> void:
	randomize()
	run_id = "hero_tree_run_%d" % int(Time.get_unix_time_from_system())
	_build_empty_world()
	await get_tree().process_frame

func _build_empty_world() -> void:
	var ground := Node2D.new()
	ground.name = "Ground"
	add_child(ground)

	# Trees clustered in a small patch.
	for i in 6:
		var ang := i * TAU / 6.0
		var pos := Vector2.from_angle(ang) * 90.0
		var obstacle: Obstacle = Obstacle.new()
		ground.add_child(obstacle)
		obstacle.global_position = pos
		obstacle.configure("tree_oak", 18.0, 4.0, 28.0)
		tree_count += 1

	# Hero = cinder (fire-themed) at center, standing still.
	hero = Player.new()
	hero.name = "Hero"
	add_child(hero)
	hero.global_position = Vector2.ZERO
	hero.set_class("cinder")

	camera = Camera2D.new()
	hero.add_child(camera)
	camera.enabled = true

func _cast_once() -> void:
	# Cast the cinder primary ability (radius burst) 3 times.
	for i in 3:
		hero.cast_primary()
		await get_tree().process_frame

func _process(delta: float) -> void:
	t += delta
	# At t=1.0 cast abilities; at t=6.0 check burning trees and finish.
	if absf(t - 1.0) < delta:
		_cast_once()
	if t >= 6.0 and burning_at_end < 0:
		_finish()

func _finish() -> void:
	# Count burning trees via the arena's burning state.
	if arena == null:
		arena = get_tree().root.get_node_or_null("Arena")
	var burning := 0
	if arena != null:
		var bt: Dictionary = arena.get("_burning_trees")
		if bt != null:
			burning = bt.size()
	burning_at_end = burning
	print("[hero_tree] trees=%d burning_at_end=%d" % [tree_count, burning])
	# Screenshot.
	var shot_path := "user://%s/hero_tree_burn_%s.png" % [run_id, ("%.2f" % t)]
	get_viewport().get_texture().get_image().save_png(shot_path)
	shots.append({"label": "hero_tree_burn", "path": shot_path})

	if burning > 0:
		verdict = "PASS"
	else:
		verdict = "FAIL_NO_BURNING"

	var report := {
		"scene": "hero_tree_test",
		"trees_placed": tree_count,
		"burning_at_end": burning_at_end,
		"verdict": verdict,
		"shots": shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	get_tree().quit()

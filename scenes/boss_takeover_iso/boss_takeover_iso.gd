extends Node2D
## Isolated boss-takeover test (2026-09-18).
##
## Verifies the boss form mechanics in an empty world:
##   1. Grant boss form to a real Player (with required children).
##   2. Call _boss_form_slam / _boss_form_cross multiple times.
##   3. Verify enemies are killed by the hazards (large-radius AoE).
##   4. Verify trees are ignited/destroyed.
##
## Empty-world baseline: dark background + grid + camera. No arena, no HUD.
##
## Strategy: fire slam repeatedly (3.0s cooldown) + cross (2.6s cooldown)
## over 10 seconds. The center hazard (r=90) kills enemies that close in,
## and the outer ring hazards (at r=270) kill enemies in the far ring.

const PlayerScene: PackedScene = preload("res://scenes/player/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/enemy/enemy.tscn")
const ObstacleScene: PackedScene = preload("res://scenes/arena/obstacle.tscn")
const ArenaHazardScript: GDScript = preload("res://scripts/arena_hazard.gd")

const RUN_SECONDS := 12.0
const TREE_COUNT := 4

var _player: Player = null
var _enemies: Array = []
var _trees: Array = []
var _elapsed := 0.0
var _captured := {}
var _run_dir := ""
var _boss_form_granted := false
var _abilities_fired := false
var _enemies_killed := 0
var _enemies_total := 0
var _fake_arena: Node2D = null

func _ready() -> void:
	_run_dir = "user://boss_takeover_iso_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_build_world()
	print("[BossTakeoverIso] world built: %d enemies, %d trees" % [_enemies_total, TREE_COUNT])

func _build_world() -> void:
	# FakeArena is already a child in the .tscn (inherited from real Arena).
	_fake_arena = $FakeArena
	# Real player with boss form (also in .tscn).
	_player = $Player
	_player.position = Vector2(0, 0)
	_player.active = true
	if not _player.is_in_group("players"):
		_player.add_to_group("players")

	# Grant boss form.
	_player.grant_boss_form("brute")
	_boss_form_granted = true
	print("[BossTakeoverIso] boss form granted")

	# Player marker (visual overlay).
	var pm := Polygon2D.new()
	pm.polygon = PackedVector2Array([Vector2(-25,-25),Vector2(25,-25),Vector2(25,25),Vector2(-25,25)])
	pm.color = Color(0.9, 0.3, 0.2, 0.4)
	pm.position = Vector2(0, 0)
	pm.z_index = 30
	add_child(pm)

	# Spawn enemies: 6 at radius 80 (inside slam center r=90) + 4 at radius 250
	# (near slam outer ring hazards at r=270). Total 12.
	var enemy_types := ["grunt", "grunt", "grunt", "grunt", "grunt", "grunt",
		"brute", "brute", "swarmling", "swarmling", "cinderling", "cinderling"]
	_enemies_total = enemy_types.size()
	for i in enemy_types.size():
		var angle := float(i) / float(enemy_types.size()) * TAU
		# First 6 in close ring, rest in far ring.
		var spawn_radius := 80.0 if i < 6 else 250.0
		var pos := Vector2.RIGHT.rotated(angle) * spawn_radius
		var e: Node2D = EnemyScene.instantiate()
		e.name = "Enemy_%d" % i
		e.position = pos
		add_child(e)
		e.configure(0, true, enemy_types[i])
		e.target = _player
		e.defeated.connect(_on_enemy_defeated)
		_enemies.append(e)

	# Spawn trees in a ring at radius 100 (inside slam tree damage radius ~130).
	for i in TREE_COUNT:
		var angle := float(i) / float(TREE_COUNT) * TAU + TAU * 0.15
		var pos := Vector2.RIGHT.rotated(angle) * 100.0
		var tree: Node2D = ObstacleScene.instantiate()
		tree.name = "Tree_%d" % i
		tree.position = pos
		add_child(tree)
		tree.configure("tree_large", 30.0, 2.0, 4.0)
		tree.add_to_group("obstacles")
		_trees.append(tree)
		# Register in fake arena's obstacles list so damage_trees_in_radius finds them.
		_fake_arena.obstacles.append(tree)

	# Fire boss abilities repeatedly over the run.
	# Slam CD is 3.0s, cross CD is 2.6s.
	_fire_abilities()

func _fire_abilities() -> void:
	# t=1.0: first slam
	await get_tree().create_timer(1.0).timeout
	_player._boss_form_slam()
	print("[BossTakeoverIso] slam #1 at t=1.0s")
	# t=2.0: first cross
	await get_tree().create_timer(1.0).timeout
	_player._boss_form_cross()
	print("[BossTakeoverIso] cross #1 at t=2.0s")
	# t=4.0: second slam
	await get_tree().create_timer(2.0).timeout
	_player._boss_form_slam()
	print("[BossTakeoverIso] slam #2 at t=4.0s")
	# t=5.0: second cross
	await get_tree().create_timer(1.0).timeout
	_player._boss_form_cross()
	print("[BossTakeoverIso] cross #2 at t=5.0s")
	# t=7.0: third slam
	await get_tree().create_timer(2.0).timeout
	_player._boss_form_slam()
	print("[BossTakeoverIso] slam #3 at t=7.0s")
	# t=8.0: third cross
	await get_tree().create_timer(1.0).timeout
	_player._boss_form_cross()
	print("[BossTakeoverIso] cross #3 at t=8.0s")
	_abilities_fired = true

func _on_enemy_defeated(_enemy: Enemy) -> void:
	_enemies_killed += 1
	print("[BossTakeoverIso] enemy defeated (%d/%d)" % [_enemies_killed, _enemies_total])

## Provide the hazard spawn hook that player.gd expects on its parent.
func player_hazard_requested(spec: Dictionary) -> void:
	var hazard: ArenaHazard = ArenaHazardScript.new()
	add_child(hazard)
	hazard.configure(spec)

func _draw() -> void:
	# Dark background.
	draw_rect(Rect2(-600, -400, 1200, 800), Color(0.03, 0.03, 0.06), true)
	# Grid lines.
	for i in range(-6, 7):
		var x := float(i) * 100.0
		draw_line(Vector2(x, -400), Vector2(x, 400), Color(0.1, 0.1, 0.15, 0.5), 1.0)
	for i in range(-4, 5):
		var y := float(i) * 100.0
		draw_line(Vector2(-600, y), Vector2(600, y), Color(0.1, 0.1, 0.15, 0.5), 1.0)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 3.0 and not _captured.has("t3"):
		_captured["t3"] = true
		_capture("boss_t3")
	if _elapsed >= 6.0 and not _captured.has("t6"):
		_captured["t6"] = true
		_capture("boss_t6")
	if _elapsed >= RUN_SECONDS:
		_finish()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "%s/%s.png" % [_run_dir, label]
		img.save_png(path)
		print("[BossTakeoverIso] snap %s -> %s" % [label, path])

func _finish() -> void:
	# Count alive trees.
	var alive_trees := 0
	for t in _trees:
		if is_instance_valid(t) and not (t as Node2D).is_queued_for_deletion():
			alive_trees += 1
	var trees_lost := TREE_COUNT - alive_trees

	# Count ignited trees (via fake arena's burning set).
	var trees_ignited := 0
	var burning: Dictionary = _fake_arena.get("_burning_trees")
	if burning != null:
		trees_ignited = burning.size()

	# Verdict: PASS if boss form killed at least 50% of enemies
	# AND at least one tree was ignited or destroyed.
	var verdict := "PASS"
	if _enemies_killed < int(float(_enemies_total) * 0.5):
		verdict = "FAIL"
	if trees_lost < 1 and trees_ignited < 1:
		verdict = "FAIL"

	var report := {
		"verdict": verdict,
		"scene": "boss_takeover_iso",
		"boss_form_granted": _boss_form_granted,
		"abilities_fired": _abilities_fired,
		"total_enemies": _enemies_total,
		"enemies_killed": _enemies_killed,
		"enemies_alive": _enemies_total - _enemies_killed,
		"total_trees": TREE_COUNT,
		"trees_alive": alive_trees,
		"trees_lost": trees_lost,
		"trees_ignited": trees_ignited,
		"shots": [
			{"label": "t3", "path": "%s/boss_t3.png" % _run_dir},
			{"label": "t6", "path": "%s/boss_t6.png" % _run_dir},
		],
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BossTakeoverIso] SUMMARY verdict=%s killed=%d/%d trees_lost=%d/%d trees_ignited=%d" % [
		verdict, _enemies_killed, _enemies_total, trees_lost, TREE_COUNT, trees_ignited])
	get_tree().quit(0)

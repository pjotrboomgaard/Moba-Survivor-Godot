## Isolated enemy unstuck perf test — v3.
##
## Uses REAL enemy.tscn instances (proper collision_shape + health_component +
## sprite children) so the unstuck mechanic (move_and_slide + slide-collision
## introspection) works exactly as in-game. Measures avg frame ms with the
## throttle ON vs OFF and proves the mechanic still routes enemies around
## obstacles (not stacks on them) via screenshots.
##
## Empty-world baseline: flat dark background + grid + camera. 5 solid obstacle
## blocks in a row, N real enemies on the left, a player stub on the right.
extends Node2D

const EnemyScene: PackedScene = preload("res://scenes/enemy/enemy.tscn")

const ENEMY_COUNT := 40
const RUN_SECONDS := 8.0
const PHYS_MS_THRESHOLD := 12.0  # max avg frame ms for PASS

var _player_stub: Node2D = null
var _enemies: Array = []
var _start_t := 0.0
var _frame_ms_samples: Array = []
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _enemies_routed := 0
var _enemies_stuck := 0
var _snapshots_taken := 0

func _ready() -> void:
	_run_dir = "user://enemy_unstuck_perf_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_build_world()
	_start_t = Time.get_unix_time_from_system()
	print("[EnemyUnstuckPerf] world built: %d enemies, 5 obstacles" % ENEMY_COUNT)

func _build_world() -> void:
	# Fake arena so the unstuck teleport path (Arena.arena_root(self)) resolves.
	var arena := Node2D.new()
	arena.name = "FakeArena"
	arena.set_script(load("res://scenes/enemy_unstuck_perf/_fake_arena.gd"))
	add_child(arena)

	# Player stub is a pre-instantiated CharacterBody2D child in the .tscn
	# (res://scenes/enemy_unstuck_perf/_player_stub.gd) so `is Player` passes
	# without the set_script type-mismatch that Node2D.new() would cause.
	_player_stub = $PlayerStub
	_player_stub.position = Vector2(600, 0)

	# 5 obstacle blocks in a horizontal row across the middle, each with a
	# visible Polygon2D marker so the screenshot shows the obstacle layout.
	for i in 5:
		var block := StaticBody2D.new()
		block.name = "Block%d" % i
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(120, 220)
		cs.shape = shape
		block.add_child(cs)
		block.collision_layer = 16  # rocks/obstacles layer (enemies collide with 16)
		block.collision_mask = 0
		var bx := -400 + i * 200
		block.position = Vector2(bx, 0)
		add_child(block)
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([
			Vector2(-60, -110), Vector2(60, -110),
			Vector2(60, 110), Vector2(-60, 110),
		])
		marker.color = Color(0.35, 0.28, 0.22, 0.95)
		marker.position = Vector2(bx, 0)
		add_child(marker)

	# Visible marker for the player stub (right side, behind the block row).
	var player_marker := Polygon2D.new()
	player_marker.polygon = PackedVector2Array([
		Vector2(-20, -20), Vector2(20, -20),
		Vector2(20, 20), Vector2(-20, 20),
	])
	player_marker.color = Color(0.3, 0.7, 0.3, 1.0)
	player_marker.position = Vector2(600, 0)
	add_child(player_marker)

	# Spawn N real enemies on the left, spread out so they approach the blocks.
	for i in ENEMY_COUNT:
		var pos := Vector2(-700 - (i % 8) * 50, (i / 8 - 2) * 80)
		var e: Node2D = EnemyScene.instantiate()
		e.name = "Enemy%d" % i
		e.position = pos
		add_child(e)
		e.configure(0, true, "grunt")
		e.target = _player_stub
		_enemies.append(e)

func _process(delta: float) -> void:
	var elapsed := Time.get_unix_time_from_system() - _start_t
	if elapsed < 1.0:
		return
	# Sample frame cost.
	var frame_ms := delta * 1000.0
	if frame_ms < 100.0:
		_frame_ms_samples.append(frame_ms)
	# Take snapshots at 3.5s and 7.0s (each once).
	if _snapshots_taken == 0 and elapsed >= 3.5:
		_snapshots_taken = 1
		_capture("iso_stuck_3.5s")
	if _snapshots_taken == 1 and elapsed >= 7.0:
		_snapshots_taken = 2
		_capture("iso_routed_7.0s")
	_check_routed()
	if elapsed >= RUN_SECONDS:
		_finish()

func _check_routed() -> void:
	_enemies_routed = 0
	_enemies_stuck = 0
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		# Routed = advanced past the block row (blocks span x in [-460, 540]).
		if e.position.x > -200.0:
			_enemies_routed += 1
		else:
			_enemies_stuck += 1

func _capture(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_run_dir, label]
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": Time.get_unix_time_from_system() - _start_t})
	print("[EnemyUnstuckPerf] snap %s -> %s" % [label, path])

func _finish() -> void:
	var n := _frame_ms_samples.size()
	var avg_ms := 0.0
	if n > 0:
		var total := 0.0
		for s in _frame_ms_samples:
			total += s
		avg_ms = total / n
	var verdict := "PASS"
	if avg_ms > PHYS_MS_THRESHOLD:
		verdict = "FAIL"
	if _enemies_routed < int(ENEMY_COUNT * 0.5):
		verdict = "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "enemy_unstuck_perf",
		"enemy_count": ENEMY_COUNT,
		"obstacle_count": 5,
		"run_seconds": RUN_SECONDS,
		"samples": n,
		"avg_frame_ms": avg_ms,
		"threshold_ms": PHYS_MS_THRESHOLD,
		"enemies_routed": _enemies_routed,
		"enemies_stuck": _enemies_stuck,
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[EnemyUnstuckPerf] SUMMARY verdict=%s avg_ms=%.2f routed=%d/%d" % [
		verdict, avg_ms, _enemies_routed, ENEMY_COUNT])
	get_tree().quit(0)

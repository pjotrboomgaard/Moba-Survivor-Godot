extends Node2D
## Isolated wave tactics test (2026-09-18).
##
## Spawns enemies with different tactic assignments in an empty world and verifies
## that their movement patterns differ. Each tactic group spawns from a distinct
## direction and moves with its assigned pattern.
##
## Empty-world baseline: flat dark background + grid + camera. No arena, no grass,
## no HUD, no enemies outside the tactic groups.
##
## Spawns:
##   - PINCER: 2 groups from left/right flanks (grunts, STRAFE pattern)
##   - ENCIRCLE: 1 ring group (swarmlings, RING formation)
##   - OVERWHELM: 3 fast pack groups (swarmlings, fast speed)
##   - BOLT_SQUAD: 2 groups with LUNGE pattern (chargers)
##   - STAMPEDE: 1 large fast group (swarmlings)
##
## Captures screenshots at 2s and 4s, then writes report + quits.
## Verdict: PASS if all tactic groups moved toward the player (avg x increased).

const EnemyScene: PackedScene = preload("res://scenes/enemy/enemy.tscn")

const RUN_SECONDS := 5.0

var _player_stub: Node2D = null
var _enemies: Array = []
var _tactic_groups: Array = []
var _elapsed := 0.0
var _captured := {}
var _run_dir := ""

func _ready() -> void:
	_run_dir = "user://tactics_iso_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_build_world()
	print("[TacticsIso] world built: %d tactic groups" % _tactic_groups.size())

func _build_world() -> void:
	# Fake arena so enemy.gd's Arena.arena_root() resolves.
	var arena := Node2D.new()
	arena.name = "FakeArena"
	arena.set_script(load("res://scenes/enemy_unstuck_perf/_fake_arena.gd"))
	add_child(arena)

	# Player stub is a pre-instantiated CharacterBody2D child in the .tscn
	# (res://scenes/enemy_unstuck_perf/_player_stub.gd) so `is Player` passes
	# without the set_script type-mismatch that Node2D.new() would cause.
	_player_stub = $PlayerStub
	_player_stub.position = Vector2(500, 0)
	# Player marker.
	var pm := Polygon2D.new()
	pm.polygon = PackedVector2Array([Vector2(-20,-20),Vector2(20,-20),Vector2(20,20),Vector2(-20,20)])
	pm.color = Color(0.3, 0.7, 0.3, 1.0)
	pm.position = Vector2(500, 0)
	add_child(pm)

	# Spawn tactic groups.
	_spawn_pincer()
	_spawn_encircle()
	_spawn_overwhelm()
	_spawn_bolt_squad()
	_spawn_stampeede()

func _draw() -> void:
	# Dark background.
	draw_rect(Rect2(-600, -350, 1200, 700), Color(0.03, 0.03, 0.06), true)
	# Grid lines.
	for i in range(-5, 6):
		var x := float(i) * 100.0
		draw_line(Vector2(x, -350), Vector2(x, 350), Color(0.1, 0.1, 0.15, 0.5), 1.0)
	for i in range(-3, 4):
		var y := float(i) * 100.0
		draw_line(Vector2(-600, y), Vector2(600, y), Color(0.1, 0.1, 0.15, 0.5), 1.0)

## PINCER: 2 groups from left/right flanks, STRAFE pattern.
func _spawn_pincer() -> void:
	var left_start := Vector2(-500, -200)
	var right_start := Vector2(-500, 200)
	var group_id := 0
	_spawn_tactic_group(0, "grunt", 5, left_start, 0, group_id)  # PINCER
	_spawn_tactic_group(0, "grunt", 5, right_start, 1, group_id)

## ENCIRCLE: 1 ring group of swarmlings.
func _spawn_encircle() -> void:
	var center := Vector2(-450, 0)
	var group_id := 0
	_spawn_tactic_ring(2, "swarmling", 8, center, group_id)  # ENCIRCLE

## OVERWHELM: 3 fast pack groups.
func _spawn_overwhelm() -> void:
	var positions := [Vector2(-400, -100), Vector2(-450, 0), Vector2(-400, 100)]
	var group_id := 0
	for pos in positions:
		_spawn_tactic_group(3, "swarmling", 4, pos, 0, group_id)  # OVERWHELM
		group_id += 1

## BOLT_SQUAD: 2 groups with LUNGE pattern (chargers).
func _spawn_bolt_squad() -> void:
	var positions := [Vector2(-350, -80), Vector2(-350, 80)]
	var group_id := 0
	for pos in positions:
		_spawn_tactic_group(6, "charger", 3, pos, 0, group_id)  # BOLT_SQUAD
		group_id += 1

## STAMPEDE: 1 large fast group.
func _spawn_stampeede() -> void:
	var start := Vector2(-550, 0)
	var group_id := 0
	_spawn_tactic_group(11, "swarmling", 6, start, 0, group_id)  # STAMPEDE

func _spawn_tactic_group(tactic_id: int, type_id: String, count: int, base_pos: Vector2, tactic_index: int, group_id: int) -> void:
	var enemies_in_group: Array = []
	for i in count:
		var e: Node2D = EnemyScene.instantiate()
		e.name = "Tactic_%d_%d_%d" % [tactic_id, group_id, i]
		var jitter := Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		e.position = base_pos + jitter
		add_child(e)
		e.configure(0, true, type_id)
		e.set_tactic(tactic_id, tactic_index)
		e.target = _player_stub
		enemies_in_group.append(e)
		_enemies.append(e)
	_tactic_groups.append({
		"tactic_id": tactic_id,
		"label": "Tactic%d_G%d" % [tactic_id, group_id],
		"type_id": type_id,
		"count": count,
		"enemies": enemies_in_group,
		"start_pos": base_pos,
	})

func _spawn_tactic_ring(tactic_id: int, type_id: String, count: int, center: Vector2, group_id: int) -> void:
	var enemies_in_group: Array = []
	for i in count:
		var angle := float(i) / float(count) * TAU
		var e: Node2D = EnemyScene.instantiate()
		e.name = "TacticRing_%d_%d" % [group_id, i]
		e.position = center + Vector2.RIGHT.rotated(angle) * 80.0
		add_child(e)
		e.configure(0, true, type_id)
		e.set_tactic(tactic_id, 0)
		e.target = _player_stub
		enemies_in_group.append(e)
		_enemies.append(e)
	_tactic_groups.append({
		"tactic_id": tactic_id,
		"label": "Ring_G%d" % group_id,
		"type_id": type_id,
		"count": count,
		"enemies": enemies_in_group,
		"start_pos": center,
	})

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 2.0 and not _captured.has("t2"):
		_captured["t2"] = true
		_capture("tactics_t2")
	if _elapsed >= 4.0 and not _captured.has("t4"):
		_captured["t4"] = true
		_capture("tactics_t4")
	if _elapsed >= RUN_SECONDS:
		_finish()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "%s/%s.png" % [_run_dir, label]
		img.save_png(path)
		print("[TacticsIso] snap %s -> %s" % [label, path])

func _finish() -> void:
	# Check: did each tactic group move toward the player (avg x increased)?
	var results: Array = []
	var all_moved := true
	for g in _tactic_groups:
		var avg_x_start: float = (g.start_pos as Vector2).x
		var sum_x := 0.0
		var alive := 0
		for e in g.enemies:
			if is_instance_valid(e):
				sum_x += (e as Node2D).global_position.x
				alive += 1
		var avg_x_end := sum_x / float(maxi(1, alive))
		var moved_toward := avg_x_end > avg_x_start
		if not moved_toward:
			all_moved = false
		results.append({
			"label": g.label,
			"tactic_id": g.tactic_id,
			"type_id": g.type_id,
			"count": g.count,
			"avg_x_start": avg_x_start,
			"avg_x_end": avg_x_end,
			"moved_toward": moved_toward,
		})
		var verdict_g := "OK" if moved_toward else "STUCK"
		print("[TacticsIso] %s: x %.0f -> %.0f %s" % [g.label, avg_x_start, avg_x_end, verdict_g])

	var verdict := "PASS" if all_moved else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "tactics_iso",
		"tactic_groups": results,
		"all_moved": all_moved,
		"total_enemies": _enemies.size(),
		"shots": [
			{"label": "t2", "path": "%s/tactics_t2.png" % _run_dir},
			{"label": "t4", "path": "%s/tactics_t4.png" % _run_dir},
		],
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[TacticsIso] SUMMARY verdict=%s groups=%d all_moved=%s" % [verdict, _tactic_groups.size(), str(all_moved)])
	get_tree().quit(0)

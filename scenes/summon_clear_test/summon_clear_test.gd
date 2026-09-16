extends Node2D
## Isolated verify for the "old mines/turrets persist into a new solo run" bug.
##
## Root-cause under test: SummonEntity nodes are parented to get_tree().current_scene
## (the Main Node2D) via Player._vfx_parent(). When bootstrap.restart_game() calls
## game.free(), the whole subtree (including all active summons) is freed — BUT the
## Player's `active_summons` array still holds stale references, and more importantly
## the summons keep firing/attacking until their lifetime timer expires. The fix adds
## a cleanup on Player._exit_tree() that frees every summon in active_summons.
##
## This test:
##   1. Spawns a real Player (tobor) + a real turret + a real mine into the tree.
##   2. Counts SummonEntity nodes in the group "summons" before the player is freed.
##   3. Frees the player (simulating bootstrap.restart_game() -> game.free()).
##   4. Waits a frame and re-counts SummonEntity nodes.
##   5. PASS if all summons were freed (count dropped to 0), FAIL if any survived.
##
## Empty world: no grass, no HUD, no arena, no enemies.

const _SUMMON_SCENE := preload("res://scenes/effects/summon_entity.tscn")
const _PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _player: Node2D = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _captured: Dictionary = {}
var _summons_before_free := 0
var _summons_after_free := 0
var _player_freed := false

const CAPTURES: Array = [
	[0.5, "summon_iso_before"],
	[2.5, "summon_iso_after"],
]


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://summon_clear_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# --- Set up a minimal Player with one turret and one mine ---
	var p: Node2D = _PLAYER_SCENE.instantiate()
	p.name = "TestPlayer"
	p.global_position = Vector2.ZERO
	add_child(p)
	p.configure(1, 0, true, "tobor")
	_player = p

	# Spawn a real turret (trigger_radius == 0 -> turret path).
	var turret: Node2D = _SUMMON_SCENE.instantiate()
	turret.name = "TestTurret"
	turret.position = Vector2(80, 0)
	add_child(turret)
	turret.setup("tobor_steam_turret", 1, 60.0, 30.0, 0.32, Color.WHITE)
	p.active_summons.append(turret)

	# Spawn a real mine (trigger_radius > 0 -> mine path).
	var mine: Node2D = _SUMMON_SCENE.instantiate()
	mine.name = "TestMine"
	mine.position = Vector2(-80, 0)
	add_child(mine)
	mine.setup("tobor_spider_mines", 1, 60.0, 40.0, 99.0, Color.WHITE)
	mine.trigger_radius = 28.0
	mine.explosion_radius = 70.0
	mine.arm_delay = 1.15
	p.active_summons.append(mine)

	_count_summons()
	_summons_before_free = _count_group("summons")
	print("SUMMON_CLEAR before_free=%d" % _summons_before_free)


func _count_group(g: String) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(g):
		if is_instance_valid(node):
			n += 1
	return n


func _count_summons() -> void:
	pass # placeholder for clarity


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	# Free the player at t=1.5 to simulate restart_game -> game.free().
	if _elapsed >= 1.5 and not _player_freed:
		_player_freed = true
		_summons_after_free = _count_group("summons")
		if is_instance_valid(_player):
			_player.queue_free()
		print("SUMMON_CLEAR freed player at t=%.2f, summons_in_group=%d" % [_elapsed, _summons_after_free])
	# After the player is freed and a frame has passed, re-count to confirm the
	# summons are actually gone from the tree.
	if _player_freed and _elapsed >= 2.0:
		_summons_after_free = _count_group("summons")
		print("SUMMON_CLEAR after_free_recount=%d" % _summons_after_free)
	if _elapsed > 3.0 and not _done:
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
	print("[SummonClear] snap %s -> %s" % [label, path])
	return path


func _draw() -> void:
	# Empty-world baseline: a neutral dark plane, no grass/HUD/props.
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
	# A subtle crosshair to mark the origin.
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.3, 0.3, 0.4), 1.0)
	draw_line(Vector2(0, -12), Vector2(0, 12), Color(0.3, 0.3, 0.4), 1.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	var expected_after := 0
	var verdict := "PASS" if (_summons_before_free >= 2 and _summons_after_free == expected_after) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "summon_clear_test",
		"summons_before_free": _summons_before_free,
		"summons_after_free": _summons_after_free,
		"expected_after": expected_after,
		"player_freed": _player_freed,
		"captured": _captured.size(),
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("SUMMON_CLEAR SUMMARY verdict=%s before=%d after=%d" % [
		verdict, _summons_before_free, _summons_after_free])
	get_tree().quit(0)

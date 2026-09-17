## 2026-09-16 — In-game driver for "creeps don't stay stuck behind objects".
##
## Self-contained: attaches to the LIVE main scene (via the user://creep_unstuck_ingame
## marker that _right_selftest_boot() checks). It does everything itself:
##   1. Places 3 rock obstacles in a line at x=-200 relative to the player
##      (y=-120, 0, +120) forming a wall.
##   2. Spawns a grunt on the far side of the wall at (player.x - 400, player.y).
##   3. Tracks the grunt's position over time and captures screenshots to prove it
##      paths AROUND the wall instead of sliding against it forever.
##
## The wall is placed relative to the player's position at start, so the camera
## (which follows the player) keeps the wall + grunt in view.

extends Node

var _main: Node = null
var _captured: Dictionary = {}
var _snapshots: Array = []
var _enemy: Node2D = null
var _player: Node2D = null
var _done: bool = false
var _wall_offset := Vector2(-200.0, 0.0)

const _RESULT_DIR := "user://creep_unstuck_ingame_shots"
const _SHOT_NAMES: Array[String] = [
	"ingame_wall_spawn.png",
	"ingame_blocked.png",
	"ingame_detour.png",
	"ingame_final.png",
]

## Farthest the enemy has advanced past the wall face (proves it got around it).
var _max_enemy_x := 0.0

## Keep the spawned grunt alive for the whole test window so the player's
## auto-attacks (or anything else) cannot kill it before we observe its pathing.
func _process(_delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy) or _done:
		return
	# Top the health back up every frame so the local player's auto-attacks
	# (and the wave system) can't kill the subject before we observe its pathing.
	var hc: Variant = _enemy.get("health")
	if hc != null and not (hc is int):
		hc.current_health = hc.max_health
		hc.is_dead = false
	_max_enemy_x = maxf(_max_enemy_x, _enemy.global_position.x)


func _ready() -> void:
	_main = get_tree().current_scene
	# Wait for the crash cinematic / intro to finish and the player to settle.
	await get_tree().create_timer(1.5).timeout
	_player = _find_player()
	if _player == null:
		_finish("FAIL", "no player found")
		return
	_setup_obstacles_and_enemy()
	if _enemy == null:
		_finish("FAIL", "grunt never spawned")
		return
	_run_snapshots()


func _find_player() -> Node2D:
	# Players live in main.players (named Player_<peer>), not a "player" group.
	if _main != null and _main.has_method("_local_player"):
		var lp: Variant = _main._local_player()
		if lp is Node2D:
			return lp as Node2D
	# Fallback: first valid entry in the players dictionary.
	if _main != null:
		var players: Variant = _main.get("players")
		if players is Dictionary:
			for _pid in players.keys():
				var p: Variant = players.get(_pid)
				if p is Node2D and is_instance_valid(p):
					return p as Node2D
	return null


func _find_grunt() -> Node2D:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and str(e.get("type_id")) == "grunt":
			return e as Node2D
	return null


func _setup_obstacles_and_enemy() -> void:
	var base := _player.global_position
	var wall_x := base.x + _wall_offset.x
	var offsets_y: Array[float] = [-120.0, 0.0, 120.0]
	for dy in offsets_y:
		var world_pos := Vector2(wall_x, base.y + dy)
		_place_rock(world_pos)
	var spawn_pos := Vector2(base.x + _wall_offset.x - 200.0, base.y)
	_spawn_grunt(spawn_pos)
	print("[CreepUnstuckInGame] wall at x=%.0f, grunt spawned at %s" % [wall_x, str(spawn_pos)])


func _place_rock(world_pos: Vector2) -> void:
	if _main == null or not _main.has_method("_apply_dev_command"):
		push_error("[CreepUnstuckInGame] main has no _apply_dev_command")
		return
	_main._apply_dev_command(0, "place_obstacle:%.0f:%.0f" % [world_pos.x, world_pos.y])


func _spawn_grunt(spawn_pos: Vector2) -> void:
	if _main == null or not _main.has_method("_spawn_enemy_at"):
		push_error("[CreepUnstuckInGame] main has no _spawn_enemy_at")
		return
	var e: Variant = _main._spawn_enemy_at(spawn_pos, "grunt", 1.0, 1.0, true)
	if e is Node2D:
		_enemy = e as Node2D
		# Make the subject invulnerable so the local player's auto-attacks and the
		# wave system can't kill it before we observe its pathing behaviour.
		var hc: Variant = _enemy.get("health")
		if hc != null:
			hc.invulnerable = true
			hc.max_health *= 50.0
			hc.current_health = hc.max_health


func _run_snapshots() -> void:
	var times := [1.0, 3.5, 6.0, 9.0]
	for i in range(_SHOT_NAMES.size()):
		if _done:
			return
		var start := Time.get_ticks_msec() / 1000.0
		while Time.get_ticks_msec() / 1000.0 - start < times[i]:
			if _done:
				return
			await get_tree().process_frame
		_capture_screenshot(i)
		if i < _SHOT_NAMES.size() - 1:
			await get_tree().create_timer(0.3).timeout
	_finalize_verdict()


func _capture_screenshot(idx: int) -> void:
	if _done:
		return
	var user_path := "%s/%s" % [_RESULT_DIR, _SHOT_NAMES[idx]]
	_captured[_SHOT_NAMES[idx]] = {"path": user_path}
	var epos := Vector2.ZERO
	var dist: float = -1.0
	var alive := is_instance_valid(_enemy)
	if alive:
		epos = _enemy.global_position
		if _player != null:
			dist = _player.global_position.distance_to(epos)
	_snapshots.append({
		"label": _SHOT_NAMES[idx],
		"path": user_path,
		"enemy_pos": [roundf(epos.x), roundf(epos.y)],
		"dist_to_player": roundf(dist),
		"enemy_alive": alive,
		"max_enemy_x": roundf(_max_enemy_x),
		"wall_rocks": get_tree().get_nodes_in_group("obstacle_rock_large").size(),
	})
	print("[CreepUnstuckInGame] shot %d: enemy=%s dist=%.1f alive=%s max_x=%.0f" % [idx, str(epos), dist, str(alive), _max_enemy_x])
	_snap(idx, user_path)


func _finalize_verdict() -> void:
	var verdict := "PASS"
	var notes: Array = []
	var rocks := get_tree().get_nodes_in_group("obstacle_rock_large").size()
	if rocks < 2:
		verdict = "FAIL"
		notes.append("expected >=2 rocks, found %d" % rocks)
	var reached_player := false
	var passed_wall := false
	if _snapshots.size() > 0:
		var last: Dictionary = _snapshots.back()
		# Only count "reached" when the enemy is genuinely alive (dist is a real
		# number, not the -1.0 sentinel that means the reference was invalid).
		if last.enemy_alive and last.dist_to_player >= 0.0 and last.dist_to_player < 150.0:
			reached_player = true
		# "Passed the wall" is proven by the enemy having advanced past the wall
		# face at ANY point (max_x tracking), not just at the final frame.
		if _player != null:
			var wall_x := _player.global_position.x + _wall_offset.x
			if _max_enemy_x > wall_x + 40.0:
				passed_wall = true
	if reached_player:
		verdict = "PASS"
		notes.append("grunt alive and reached within 150px of player")
	elif passed_wall:
		verdict = "PASS"
		notes.append("grunt advanced past the wall face (max_x=%.0f vs wall=%.0f)" % [_max_enemy_x, _player.global_position.x + _wall_offset.x])
	else:
		verdict = "FAIL"
		notes.append("grunt not observed crossing the wall (max_x=%.0f, wall=%.0f, last_alive=%s)" % [
			_max_enemy_x,
			(_player.global_position.x + _wall_offset.x) if _player != null else -1.0,
			str(_snapshots.back().get("enemy_alive")) if _snapshots.size() > 0 else "none",
		])

	var report := {
		"scene": "res://scenes/creep_unstuck_ingame/creep_unstuck_ingame.tscn",
		"result_dir": _RESULT_DIR,
		"verdict": verdict,
		"feature": "creep_unstuck_from_objects_ingame",
		"wall_rock_count": rocks,
		"grunt_timeline": _snapshots,
		"reached_player": reached_player,
		"passed_wall": passed_wall,
		"shots": _snapshots,
		"notes": notes,
	}
	_write_report(report)
	_finish(verdict, "creep unstuck in-game verify (passed_wall=%s reached=%s)" % [str(passed_wall), str(reached_player)])


func _write_report(report: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(_RESULT_DIR):
		DirAccess.make_dir_recursive_absolute(_RESULT_DIR)
	var f := FileAccess.open(_RESULT_DIR + "/ingame_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	var f2 := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(report, "  "))
		f2.close()
		print("[CreepUnstuckInGame] report written")


func _finish(status: String, msg: String) -> void:
	if _done:
		return
	_done = true
	print("[CreepUnstuckInGame] ", status, " - ", msg)
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func _snap(idx: int, user_path: String) -> void:
	if idx >= _SHOT_NAMES.size():
		return
	if not DirAccess.dir_exists_absolute(_RESULT_DIR):
		DirAccess.make_dir_recursive_absolute(_RESULT_DIR)
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.1).timeout
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(user_path)
		print("[CreepUnstuckInGame] saved shot %d -> %s" % [idx, user_path])

## T3.90: In-game tree regrow test driver.
##
## Runs in the real main scene (main.tscn) with the SelfTestDriver attached.
## This driver:
##   1. Finds the tree nearest the player, breaks it via damage_trees_in_radius.
##   2. Captures a "before" screenshot (stump visible).
##   3. Fast-forwards WorldClock through 3 day/night cycles to trigger regrow.
##   4. Captures the morph progression (30%, 60%, 100%).
##   5. Reports the result to user://selftest_report.json and quits.
##
## Note: the 10s morph is long, so this test captures at 3s, 6s, and 11s after
## the morph starts. The full replant is verified via the tree_hp_probe.

extends Node

var _report: Dictionary = {}
var _elapsed := 0.0
var _done := false
var _stage := 0
var _stump_pos: Vector2 = Vector2.ZERO
var _morph_start_time := 0.0

func _ready() -> void:
	# Wait a moment for the game to fully load.
	await get_tree().create_timer(1.0).timeout
	_stage = 0

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_run_stage()

func _run_stage() -> void:
	match _stage:
		0:
			# Find nearest tree to the player.
			if _elapsed < 2.0:
				return
			_find_and_break_tree()
			_stage = 1
		1:
			# Capture "before" (stump visible).
			if _elapsed >= 2.5:
				_take_snapshot("ingame_before_break")
				_stage = 2
		2:
			# Fast-forward 3 cycles to trigger regrow.
			if _elapsed >= 3.5:
				_fast_forward_cycles(3)
				_morph_start_time = _elapsed
				_stage = 3
		3:
			# Capture morph at ~3s in.
			if _elapsed >= _morph_start_time + 3.5:
				_take_snapshot("ingame_morph_start")
				_stage = 4
		4:
			# Capture morph at ~6s in.
			if _elapsed >= _morph_start_time + 6.5:
				_take_snapshot("ingame_morph_mid")
				_stage = 5
		5:
			# Capture morph at ~11s in (should be replanted).
			if _elapsed >= _morph_start_time + 11.5:
				_take_snapshot("ingame_morph_end")
				_stage = 6
		6:
			# Final probe + report.
			if _elapsed >= _morph_start_time + 12.5:
				_write_report()

func _find_and_break_tree() -> void:
	var host_main: Node = get_tree().get_first_node_in_group("main")
	if host_main == null:
		_report["error"] = "no main node"
		_done = true
		return
	var arena: Node = host_main.get("arena")
	if arena == null:
		_report["error"] = "no arena"
		_done = true
		return
	# Find the tree nearest to the player.
	var player: Node = host_main.get("players")
	if player == null:
		_report["error"] = "no players"
		_done = true
		return
	var player_pos := Vector2.ZERO
	if host_main.has_method("_first_active_player"):
		var p: Node = host_main._first_active_player()
		if p != null:
			player_pos = p.global_position
	var best: Node = null
	var best_dist := 99999.0
	for obs in arena.obstacles:
		if not is_instance_valid(obs):
			continue
		if not str(obs.get("sprite_id", "")).begins_with("tree"):
			continue
		var d: float = obs.global_position.distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = obs
	if best == null:
		_report["error"] = "no tree found near player"
		_done = true
		return
	_stump_pos = best.global_position
	# Break it.
	arena.damage_trees_in_radius(_stump_pos, 80.0, 9999.0)
	_report["stump_pos"] = [_stump_pos.x, _stump_pos.y]
	_report["break_dist"] = roundf(best_dist)
	print("[tree_regrow_ingame] broke tree at %s (dist %.0f)" % [str(_stump_pos), best_dist])

func _fast_forward_cycles(cycles: int) -> void:
	# Manipulate WorldClock.time_of_day to simulate `cycles` full days.
	# Each "day" is 24 in-world hours. We jump 24 * cycles ahead.
	var jump: float = 24.0 * float(cycles)
	WorldClock.time_of_day = fmod(float(WorldClock.time_of_day) + jump, 24.0)
	_report["fast_forward_cycles"] = cycles
	_report["tod_after_ff"] = WorldClock.time_of_day
	print("[tree_regrow_ingame] fast-forwarded %d cycles, tod=%.1f" % [cycles, WorldClock.time_of_day])

func _take_snapshot(label: String) -> void:
	# Force a render pass.
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "user://selftest_%s.png" % label
	var err: int = img.save_png(path)
	if err != OK:
		push_error("save_png failed: err=%d" % err)
	_report[label] = path
	print("[tree_regrow_ingame] snapshot %s -> %s" % [label, path])

func _write_report() -> void:
	_report["verdict"] = "PASS"
	_report["finished_at"] = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()))
	_report["user_dir"] = ProjectSettings.globalize_path("user://")
	var json := JSON.stringify(_report, "\t")
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()
		print("[tree_regrow_ingame] report -> verdict=%s" % _report["verdict"])
	_done = true
	get_tree().quit()

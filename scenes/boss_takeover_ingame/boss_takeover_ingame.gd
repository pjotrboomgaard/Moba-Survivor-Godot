extends Node2D
## In-game boss takeover test (2026-09-18).
##
## Launched as a SEPARATE scene (via run_selftest.ps1 -Scene) that boots the
## real main scene and then observes boss form mechanics in-game:
##   1. The selftest driver grants boss form to the local player at t=0.5s.
##   2. This node observes the boss form state, captures screenshots, and checks
##      that trees are being ignited and enemies are being killed.
##   3. Writes user://selftest_report.json when done.

const RUN_SECONDS := 15.0

var _elapsed := 0.0
var _captured := {}
var _run_dir := ""
var _main: Node = null
var _boss_form_seen := false
var _boss_type := ""
var _max_burning_trees := 0
var _enemy_counts: Array = []
var _finish_reported := false

func _ready() -> void:
	_run_dir = "user://boss_takeover_ingame_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[BossTakeoverIngame] started, run_dir=%s" % _run_dir)
	# Wait one frame for the main scene to settle, then find the Main node.
	await get_tree().process_frame
	_find_main()

func _find_main() -> void:
	for n in get_tree().root.get_children():
		if n.name == "Main" or (n.has_method("_local_player")):
			_main = n
			break
	if _main == null:
		# Try finding by group or by node type.
		var candidates := get_tree().root.get_children()
		for c in candidates:
			if c.has_method("_local_player"):
				_main = c
				break
	print("[BossTakeoverIngame] found main: %s" % (str(_main.name) if _main != null else "null"))

func _process(delta: float) -> void:
	if _finish_reported:
		return
	_elapsed += delta

	# Track boss form state.
	if _main != null and _main.has_method("_local_player"):
		var local = _main._local_player()
		if local != null and local.has_method("is_in_boss_form") and local.is_in_boss_form():
			_boss_form_seen = true
			if _boss_type.is_empty():
				_boss_type = str(local.boss_form_type_id)

	# Track burning trees.
	var arena := get_tree().get_first_node_in_group("arena")
	if arena != null:
		var burning = arena.get("_burning_trees")
		if burning != null:
			var count := (burning as Dictionary).size()
			if count > _max_burning_trees:
				_max_burning_trees = count

	# Track enemy count.
	var enemies := get_tree().get_nodes_in_group("enemies")
	_enemy_counts.append(enemies.size())

	# Screenshots.
	if _elapsed >= 1.5 and not _captured.has("t1"):
		_captured["t1"] = true
		_capture("ingame_before")
	if _elapsed >= 4.0 and not _captured.has("t4"):
		_captured["t4"] = true
		_capture("boss_form_active")
	if _elapsed >= 8.0 and not _captured.has("t8"):
		_captured["t8"] = true
		_capture("boss_fighting")
	if _elapsed >= 12.0 and not _captured.has("t12"):
		_captured["t12"] = true
		_capture("boss_after")

	if _elapsed >= RUN_SECONDS:
		_finish()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "%s/%s.png" % [_run_dir, label]
		img.save_png(path)
		print("[BossTakeoverIngame] snap %s -> %s" % [label, path])

func _finish() -> void:
	if _finish_reported:
		return
	_finish_reported = true

	var enemies_at_start := 0
	var enemies_at_end := 0
	if _enemy_counts.size() > 0:
		enemies_at_start = int(_enemy_counts[0])
		enemies_at_end = int(_enemy_counts[_enemy_counts.size() - 1])
	var enemies_dead := maxi(0, enemies_at_start - enemies_at_end)

	# Verdict: PASS if boss form was seen AND (trees ignited OR enemies killed).
	var verdict := "PASS"
	if not _boss_form_seen:
		verdict = "FAIL"
	if _max_burning_trees < 1 and enemies_dead < 1:
		verdict = "FAIL"

	var report := {
		"verdict": verdict,
		"scene": "boss_takeover_ingame",
		"boss_form_seen": _boss_form_seen,
		"boss_type": _boss_type,
		"max_burning_trees": _max_burning_trees,
		"enemies_at_start": enemies_at_start,
		"enemies_at_end": enemies_at_end,
		"enemies_dead": enemies_dead,
		"shots": [
			{"label": "before", "path": "%s/ingame_before.png" % _run_dir},
			{"label": "boss_active", "path": "%s/boss_form_active.png" % _run_dir},
			{"label": "fighting", "path": "%s/boss_fighting.png" % _run_dir},
			{"label": "after", "path": "%s/boss_after.png" % _run_dir},
		],
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BossTakeoverIngame] SUMMARY verdict=%s boss=%s type=%s burning=%d enemies_dead=%d" % [
		verdict, str(_boss_form_seen), _boss_type, _max_burning_trees, enemies_dead])
	get_tree().quit(0)

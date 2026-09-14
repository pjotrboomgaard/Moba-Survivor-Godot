extends Node2D
## Isolated test: tree HP mechanic (T3.75).
##
## Spawns one of each tree type on a flat field, then drives
## arena.damage_trees_in_radius() to exercise:
##   1. Intact tree (baseline)
##   2. Shake on a light AoE hit
##   3. Breaking (fall + fade) once HP <= 0
##   4. Stump remains + collision disabled (no longer blocks pathing)
##
## Uses a state machine (no nested awaits) so each phase captures exactly once.
## Writes user://selftest_report.json and quits.

const OBSTACLE_SCENE: PackedScene = preload("res://scenes/arena/obstacle.tscn")

var _arena: Node2D = null
var _trees: Array[Obstacle] = []
var _tree_positions: Array[Vector2] = []
var _run_dir := ""
var _elapsed := 0.0
var _done := false
var _shots: Array = []
## Monotonic phase index; advances once per captured phase.
var _phase := 0
const PHASE_INTACT := 0
const PHASE_SHAKE := 1
const PHASE_BREAKING := 2
const PHASE_STUMP := 3
const PHASE_DONE := 4

const TREE_TYPES: Array[String] = ["tree_oak", "tree_pine", "tree_cypress"]
const PIXEL_ZOOM := 4.0
const X_SPOTS: Array[float] = [-280.0, 0.0, 280.0]

## Phase boundaries (seconds). Each phase captures one screenshot on its entry.
const T_INTACT := 0.6
const T_SHAKE := 1.2      # light AoE hit lands here; shake visible
const T_SHAKE_CAPTURE := 1.4
const T_BREAK := 2.0      # heavy AoE lands here; fall begins
const T_BREAKING_CAPTURE := 2.6  # mid-fall (break ~0.6s into 1.6s fall)
const T_STUMP_CAPTURE := 4.2     # post-break (fall done at 3.6s), stumps only
const T_FINISH := 4.8

func _ready() -> void:
	_run_dir = "user://tree_hp_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	_arena = load("res://scripts/arena.gd").new()
	_arena.name = "Arena"
	add_child(_arena)

	for i in TREE_TYPES.size():
		var pos := Vector2(X_SPOTS[i], 0.0)
		var ob := OBSTACLE_SCENE.instantiate() as Obstacle
		ob.global_position = pos
		_arena.add_child(ob)
		ob.configure(TREE_TYPES[i], 18.0, PIXEL_ZOOM, 28.0)
		ob.add_to_group("obstacles")
		_arena.register_obstacle(ob)
		_trees.append(ob)
		_tree_positions.append(pos)

	print("[TreeHP] ready, %d trees: %s" % [_trees.size(), str(TREE_TYPES)])


func _process(delta: float) -> void:
	_elapsed += delta

	# Intact baseline.
	if _elapsed >= T_INTACT and _phase == PHASE_INTACT:
		_capture("intact")
		_phase = PHASE_SHAKE

	# Light AoE: shake but no break.
	if _elapsed >= T_SHAKE and _phase == PHASE_SHAKE and not _light_hit_done:
		for pos in _tree_positions:
			_arena.damage_trees_in_radius(pos, 60.0, 40.0)
		_light_hit_done = true

	# Capture the shake a moment after the hit.
	if _elapsed >= T_SHAKE_CAPTURE and _phase == PHASE_SHAKE:
		_capture("shake")
		_phase = PHASE_BREAKING

	# Heavy AoE: breaks all trees -> fall begins.
	if _elapsed >= T_BREAK and _phase == PHASE_BREAKING and not _heavy_hit_done:
		for pos in _tree_positions:
			_arena.damage_trees_in_radius(pos, 60.0, 400.0)
		_heavy_hit_done = true

	# Mid-fall capture.
	if _elapsed >= T_BREAKING_CAPTURE and _phase == PHASE_BREAKING:
		_capture("breaking")
		var rot_report := []
		for o in _trees:
			if is_instance_valid(o):
				rot_report.append(round(o.rotation * 1000.0) / 1000.0)
		_break_rotation = rot_report
		_phase = PHASE_STUMP

	# Post-break: stumps remain, collision off.
	if _elapsed >= T_STUMP_CAPTURE and _phase == PHASE_STUMP:
		_capture("stump")
		_phase = PHASE_DONE

	if _elapsed >= T_FINISH:
		_finish()


var _light_hit_done := false
var _heavy_hit_done := false
var _break_rotation: Array = []


func _capture(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/tree_%s.png" % [_run_dir, label]
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": _elapsed})
	print("[TreeHP] snap %s t=%.2f -> %s" % [label, _elapsed, path])


func _finish() -> void:
	if _done:
		return
	_done = true
	# Verify: all trees broken, collision disabled on every surviving obstacle.
	var all_broken := true
	var collision_states: Array = []
	for i in _trees.size():
		var o: Obstacle = _trees[i]
		var valid := is_instance_valid(o)
		var disabled := (not valid) or o.collision.disabled
		if not disabled:
			all_broken = false
		collision_states.append("removed" if not valid else ("disabled" if o.collision.disabled else "enabled"))

	var hp_remaining: Array = []
	for pos in _tree_positions:
		hp_remaining.append(_arena.tree_hp_at(pos))

	var verdict := "PASS" if (all_broken and _shots.size() >= 4) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "tree_hp_test",
		"trees_spawned": _trees.size(),
		"tree_types": TREE_TYPES,
		"all_broken": all_broken,
		"collision_states": collision_states,
		"hp_remaining": hp_remaining,
		"break_rotation_rad": _break_rotation,
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[TreeHP] SUMMARY verdict=%s all_broken=%s collision=%s shots=%d" % [
		verdict, str(all_broken), str(collision_states), _shots.size()])
	get_tree().quit(0)

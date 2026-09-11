extends Node2D
## Isolated fire-tree (T3.14) test scene. Self-contained:
##
##   1. Draws an empty flat world (dark ground + grid) with a tight cluster of 5
##      trees.
##   2. On _ready ignites the central tree via the fire-tree logic.
##   3. Captures screenshots at fixed world-times:
##        - t=0.6  : one tree burning
##        - t=4.5  : fire spread to a neighbour
##        - t=9.5  : a tree burned out to a charred stump
##   4. Writes user://selftest_report.json with verdict + counts, then quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/fire_tree_test.json
##      -Scene res://scenes/fire_tree_test/fire_tree_test.tscn
##
## The fire/spread/burn-out logic mirrors arena.gd's ignited_trees implementation
## (kept local here so the test is fully isolated from the full arena scene).

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

## A tree in this test: { "id": int, "pos": Vector2, "sprite": String,
##                         "state": 0=alive 1=burning 2=dead, "burn_time": float,
##                         "has_spread": bool }
var trees: Array[Dictionary] = []
## Parallel burning state keyed by tree id (mirrors arena.burning_trees).
var burning: Dictionary = {}
const FIRE_DPS := 5.0
const SPREAD_AFTER := 3.5
const SPREAD_RADIUS := 70.0
const BURNOUT_TIME := 7.5

## Capture schedule: [world_time, label]
const CAPTURES: Array = [
	[0.6, "t0_one_burning"],
	[4.5, "t4_spread"],
	[9.5, "t8_burned_out"],
]
var _captured := {}
var _trees_ignited := 0
var _dead_stumps := 0


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://fire_tree_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_build_trees()
	# Ignite the central tree.
	_ignite_tree(trees[0].id)
	print("FIRE_TREE_TEST ready: %d trees, central tree ignited" % trees.size())


func _build_trees() -> void:
	# 5 trees clustered: one centre + 4 around it, within SPREAD_RADIUS.
	var offs: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-SPREAD_RADIUS * 0.8, 0),
		Vector2(SPREAD_RADIUS * 0.8, 0),
		Vector2(0, -SPREAD_RADIUS * 0.8),
		Vector2(0, SPREAD_RADIUS * 0.7),
	]
	var ids := ["tree_oak", "tree_pine", "tree_fir", "tree_pine", "tree_oak"]
	for i in offs.size():
		trees.append({
			"id": i,
			"pos": offs[i],
			"sprite": ids[i],
			"state": 0,
			"burn_time": 0.0,
			"has_spread": false,
		})


func _process(delta: float) -> void:
	_elapsed += delta
	_update_fire(delta)
	_capture_due()
	# Hard stop so the harness never hangs.
	if _elapsed > 13.0 and not _done:
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
	print("[FireTree] snap %s -> %s" % [label, path])
	return path


## ---- Fire-tree logic (mirrors arena.gd) ----

func _ignite_tree(tree_id: int) -> void:
	for t in trees:
		if int(t.id) == tree_id:
			if int(t.state) != 0:
				return
			t.state = 1
			t.burn_time = 0.0
			burning[tree_id] = { "burn_time": 0.0, "pos": t.pos }
			_trees_ignited += 1
			print("[FireTree] ignited tree %d at %s" % [tree_id, str(t.pos)])
			queue_redraw()
			return


func _update_fire(delta: float) -> void:
	for t in trees:
		if int(t.state) != 1:
			continue
		t.burn_time = float(t.burn_time) + delta
		# Fire spread: after SPREAD_AFTER seconds, ignite the nearest alive tree
		# within SPREAD_RADIUS (chain reaction). Each tree spreads at most once.
		if t.burn_time >= SPREAD_AFTER and not bool(t.has_spread):
			_spread_from(t)
		# Burn out: after BURNOUT_TIME, become a dead stump.
		if t.burn_time >= BURNOUT_TIME:
			t.state = 2
			burning.erase(t.id)
			_dead_stumps += 1
			print("[FireTree] tree %d burned out to stump" % [t.id])
			queue_redraw()


func _spread_from(t: Dictionary) -> void:
	# Find the nearest alive tree within radius.
	var src_pos: Vector2 = t.pos
	var best_id := -1
	var best_dist := INF
	for o in trees:
		if o == t or int(o.state) != 0:
			continue
		var d := src_pos.distance_to(o.pos)
		if d <= SPREAD_RADIUS and d < best_dist:
			best_dist = d
			best_id = int(o.id)
	t.has_spread = true
	if best_id >= 0:
		_ignite_tree(best_id)


## ---- Drawing ----

func _draw() -> void:
	_draw_ground()
	# Dead stumps under live trees.
	for t in trees:
		if int(t.state) == 2:
			_draw_dead_tree(t)
	# Live + burning trees.
	for t in trees:
		if int(t.state) == 1:
			_draw_tree(t, true, float(t.burn_time))
		elif int(t.state) == 0:
			_draw_tree(t, false, 0.0)


func _draw_ground() -> void:
	var half := Vector2(500.0, 500.0)
	draw_rect(Rect2(-half, half * 2.0), Color(0.10, 0.15, 0.10), true)
	var step := 100.0
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(1, 1, 1, 0.05), 2.0)
		y += step


func _draw_tree(t: Dictionary, burning_now: bool, burn_time: float) -> void:
	var pos: Vector2 = t.pos
	var tex := SpriteLibrary.texture_for(str(t.sprite))
	if tex == null:
		# Fallback: simple pixel tree so the test still renders.
		_draw_fallback_tree(pos, burning_now, burn_time)
		return
	var zoom := Obstacle.tree_display_zoom(4.0, tex)
	var size := Vector2(tex.get_width(), tex.get_height()) * zoom
	var rect := Rect2(pos - size * 0.5, size)
	if burning_now:
		var tint := Color(1.0, 0.85, 0.6, 1.0)
		draw_texture_rect(tex, rect, false, tint)
		_draw_flames(pos, size, burn_time)
	else:
		draw_texture_rect(tex, rect, false)


func _draw_fallback_tree(pos: Vector2, burning_now: bool, burn_time: float) -> void:
	# Trunk.
	draw_rect(Rect2(pos.x - 6, pos.y - 40, 12, 44), Color(0.35, 0.22, 0.12))
	# Canopy.
	var canopy_col := Color(0.18, 0.45, 0.20)
	if burning_now:
		canopy_col = Color(0.30, 0.40, 0.15)
	draw_circle(pos + Vector2(0, -60), 34, canopy_col)
	draw_circle(pos + Vector2(-14, -50), 22, canopy_col)
	draw_circle(pos + Vector2(14, -52), 22, canopy_col)
	if burning_now:
		_draw_flames(pos, Vector2(90, 90), burn_time)


func _draw_flames(pos: Vector2, size: Vector2, burn_time: float) -> void:
	# 2-3 frame flicker via time-based jitter. Layers of orange/yellow circles.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(burn_time * 12.0)
	var base_y := pos.y - size.y * 0.35
	var cols: Array[Color] = [
		Color(1.0, 0.45, 0.05, 0.85),
		Color(1.0, 0.65, 0.10, 0.80),
		Color(1.0, 0.85, 0.25, 0.90),
	]
	for i in 7:
		var jitter := rng.randf_range(-6.0, 6.0)
		var fx := pos.x + jitter + sin(burn_time * 10.0 + i) * 4.0
		var fy := base_y - rng.randf_range(0.0, 26.0)
		var r := rng.randf_range(8.0, 16.0) * (1.0 + 0.2 * sin(burn_time * 14.0 + i))
		draw_circle(Vector2(fx, fy), r, cols[i % cols.size()])
	# Bright core.
	draw_circle(Vector2(pos.x, base_y + 4), 10.0, Color(1.0, 0.9, 0.4, 0.9))


func _draw_dead_tree(t: Dictionary) -> void:
	var pos: Vector2 = t.pos
	# Charred trunk silhouette: dark grey/brown.
	var trunk := Color(0.12, 0.09, 0.06)
	draw_rect(Rect2(pos.x - 5, pos.y - 34, 10, 36), trunk)
	# A few broken branches.
	draw_line(Vector2(pos.x, pos.y - 20), Vector2(pos.x - 12, pos.y - 30), trunk, 4.0)
	draw_line(Vector2(pos.x, pos.y - 14), Vector2(pos.x + 10, pos.y - 24), trunk, 3.0)
	# Charred base glow fading out.
	draw_circle(pos, 8.0, Color(0.4, 0.15, 0.05, 0.4))


## ---- Report ----

func _finish() -> void:
	if _done:
		return
	_done = true
	_dead_stumps = _count_stumps()
	_write_report()
	print("FIRE_TREE_TEST SUMMARY: ignited=%d dead_stumps=%d" % [_trees_ignited, _dead_stumps])
	get_tree().quit(0)


func _count_stumps() -> int:
	var n := 0
	for t in trees:
		if int(t.state) == 2:
			n += 1
	return n


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var verdict := "PASS"
	if _trees_ignited < 2:
		verdict = "FAIL"
	if _dead_stumps < 1:
		verdict = "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "fire_tree_test",
		"trees_ignited": _trees_ignited,
		"dead_stumps": _dead_stumps,
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

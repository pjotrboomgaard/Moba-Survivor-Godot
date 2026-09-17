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
##                         "last_spread_at": float }
var trees: Array[Dictionary] = []
## Parallel burning state keyed by tree id (mirrors arena.burning_trees).
var burning: Dictionary = {}
const FIRE_DPS := 5.0
const FIRST_SPREAD_AFTER := 3.5
const REPEAT_SPREAD_EVERY := 4.0
const SPREAD_RADIUS := 70.0
const BURNOUT_TIME := 7.5

## Capture schedule: [world_time, label] — spread now happens repeatedly, so we
## capture a later frame where a 3rd tree has caught too.
const CAPTURES: Array = [
	[0.6, "t0_one_burning"],
	[4.0, "t4_first_spread"],
	[7.5, "t7_second_spread"],
	[10.5, "t10_burned_out"],
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
			"last_spread_at": -1.0,
		})


func _process(delta: float) -> void:
	_elapsed += delta
	_update_fire(delta)
	_capture_due()
	# Hard stop so the harness never hangs.
	if _elapsed > 12.0 and not _done:
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
		# Fire spread (mirrors arena.gd 2026-09-17 slow repeated spread): first
		# attempt after FIRST_SPREAD_AFTER, then every REPEAT_SPREAD_EVERY until
		# every in-radius neighbour is already burning or the tree burns out.
		var last_spread: float = float(t.last_spread_at)
		var min_interval: float = FIRST_SPREAD_AFTER if last_spread < 0.0 else REPEAT_SPREAD_EVERY
		if float(t.burn_time) - last_spread >= min_interval:
			t.last_spread_at = float(t.burn_time)
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
	# Spread multiple small pure-flame tiles across the tree canopy so the fire
	# reads as "burning around the tree" rather than one centered blob on top.
	# Each flame gets its own stable position + a per-flame animation phase offset
	# so they flicker independently. Positions seeded from tree position so they
	# stay put frame-to-frame (no jitter).
	var flame_count := 5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31 + pos.y * 57)
	var flame_offsets: Array[Vector2] = []
	for i in flame_count:
		var fx := rng.randf_range(-28.0, 28.0)
		var fy := rng.randf_range(-size.y * 0.85, -size.y * 0.45)
		flame_offsets.append(Vector2(fx, fy))
	var tw := 12.0
	var th := 16.0
	for i in flame_count:
		var foff := flame_offsets[i]
		var frame_idx := int(burn_time * 8.0 + i * 2.1) % 3
		var frame_tex: Texture2D = SpriteLibrary.texture_for("fire_frame_%d" % frame_idx)
		if frame_tex == null:
			continue
		var pulse := 1.0 + 0.18 * sin(burn_time * 6.28318 * 1.4 + i * 2.09)
		var scale := 1.9 * pulse
		var fx := pos.x + foff.x
		var fy := pos.y + foff.y
		var w := tw * scale
		var h := th * scale
		draw_texture_rect(
			frame_tex,
			Rect2(fx - w * 0.5, fy - h * 0.85, w, h),
			false
		)
	# Embers drifting up — a few, varied, swaying.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = int(pos.x * 31 + pos.y * 57) + 100
	for i in 6:
		var drift_speed: float = 20.0 + (i % 3) * 8.0
		var rise := fposmod(burn_time * drift_speed + float(i) * 7.0, 28.0)
		var ey: float = pos.y - size.y * 0.65 - rng2.randf_range(0.0, 40.0) - rise
		var sway := sin(burn_time * 5.0 + i * 1.3) * 8.0
		var ex: float = pos.x + rng2.randf_range(-30.0, 30.0) + sway
		var er: float = 1.5 + (i % 4) * 0.7
		var ea: float = 0.45 + 0.3 * sin(burn_time * 8.0 + i)
		draw_circle(Vector2(ex, ey), er, Color(1.0, 0.7, 0.2, maxf(0.2, ea)))


func _draw_dead_tree(t: Dictionary) -> void:
	var pos: Vector2 = t.pos
	# T3.14: use pixel-art dead_tree_stump sprite if available.
	var tex := SpriteLibrary.texture_for("dead_tree_stump")
	if tex != null:
		var scale_factor := 1.8
		var tw := tex.get_width() * scale_factor
		var th := tex.get_height() * scale_factor
		draw_texture_rect(tex, Rect2(pos.x - tw * 0.5, pos.y - th, tw, th), false)
	else:
		# Fallback: procedural charred trunk.
		var trunk := Color(0.12, 0.09, 0.06)
		draw_rect(Rect2(pos.x - 5, pos.y - 34, 10, 36), trunk)
		draw_line(Vector2(pos.x, pos.y - 20), Vector2(pos.x - 12, pos.y - 30), trunk, 4.0)
		draw_line(Vector2(pos.x, pos.y - 14), Vector2(pos.x + 10, pos.y - 24), trunk, 3.0)
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
	# Repeated spread: the central tree should chain-ignite 2+ more neighbours
	# over the ~10s window, so we expect at least 3 ignited total.
	if _trees_ignited < 3:
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

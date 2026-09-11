extends Node2D
## Isolated storm (T3.13) test scene. Self-contained:
##
##   1. Draws an empty flat world with a few trees.
##   2. Spawns a biome_weather overlay in storm mode (dense rain + dark veil).
##   3. On _ready forces a storm: schedules a few lightning strikes at fixed
##      timings. Each strike: warning reticle -> jagged bolt -> white flash ->
##      impact target resolution (tree on fire / scorch) -> thunder SFX.
##   4. Captures screenshots at fixed world-times, writes a report, quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/storm_test.json
##      -Scene res://scenes/storm_test/storm_test.tscn
##
## The lightning-bolt + target-resolution + biome-tint logic mirrors arena.gd's
## storm implementation. Kept local so the test is fully isolated.

const _BIOME_WEATHER := preload("res://scripts/biome_weather.gd")

var _camera: Camera2D
var _weather: Node2D = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

const STORM_WARNING_LEAD := 0.5
const STORM_STRIKE_DAMAGE := 28.0

## Trees: { "pos": Vector2, "sprite": String, "burning": bool, "burn_time": float }
var trees: Array[Dictionary] = []
## Active strikes: { "pos": Vector2, "age": float, "state": 0=warn 1=impact }
var strikes: Array[Dictionary] = []
## Impact effects: { "pos": Vector2, "age": float, "kind": "scorch"/"tree_fire"/"splash" }
var impacts: Array[Dictionary] = []
## Flash (0..1) drives full-screen white flash.
var _flash := 0.0

const WARNING_RADIUS := 44.0
const TREE_HIT_RADIUS := 40.0
const SCORCH_RADIUS := 34.0

## Strike schedule: [strike_time, position] — the first strikes target trees
## so we can observe a tree catching fire.
const STRIKES: Array = [
	[0.9, Vector2(-120.0, -40.0)],   # near tree 0
	[2.2, Vector2(120.0, 60.0)],     # near tree 1
	[3.6, Vector2(0.0, 0.0)],        # ground (scorch)
	[5.0, Vector2(-40.0, -160.0)],   # near tree 3
]

const CAPTURES: Array = [
	[0.4, "storm_start"],     # darkening + heavy rain, no bolt yet
	[1.05, "strike_bolt"],     # mid-storm: warning reticle + bolt + tree on fire
	[2.6, "multi_impact"],     # several impacts: scorch + burning trees
	[6.5, "storm_end"],        # storm fading, aftermath
]
var _captured := {}
var _strikes_fired := 0
var _trees_burned := 0
var _thunder_played := false


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://storm_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_build_trees()
	_spawn_weather()
	print("STORM_TEST ready: %d trees, storm forced, %d strikes scheduled" % [trees.size(), STRIKES.size()])


func _build_trees() -> void:
	var ids := ["tree_oak", "tree_pine", "tree_fir", "tree_pine", "tree_oak", "tree_willow"]
	var spots: Array[Vector2] = [
		Vector2(-120.0, -40.0),
		Vector2(120.0, 60.0),
		Vector2(180.0, -120.0),
		Vector2(-40.0, -160.0),
		Vector2(60.0, 180.0),
		Vector2(-200.0, 140.0),
	]
	for i in ids.size():
		trees.append({ "pos": spots[i], "sprite": ids[i], "burning": false, "burn_time": 0.0 })


func _spawn_weather() -> void:
	_weather = _BIOME_WEATHER.new()
	add_child(_weather)
	_weather.set_rain_active(true)
	_weather.set_storm_active(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_schedule_strikes()
	_update_strikes(delta)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()
	_capture_due()
	if _elapsed > 9.0 and not _done:
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
	print("[Storm] snap %s -> %s" % [label, path])
	return path


func _schedule_strikes() -> void:
	for s in STRIKES:
		var t: float = float(s[0])
		var pos: Vector2 = s[1]
		# Fire the strike exactly when we reach t - WARNING_LEAD so it warns then hits.
		if _elapsed >= t - STORM_WARNING_LEAD and not _strike_in_progress(t, pos):
			strikes.append({ "pos": pos, "age": 0.0, "state": 0, "fire_at": t })
			_strikes_fired += 1
			print("[Storm] strike scheduled at %s" % str(pos))


func _strike_in_progress(t: float, pos: Vector2) -> bool:
	for s in strikes:
		var sp: Vector2 = s.pos
		if absf(float(s.fire_at) - t) < 0.05 and sp.distance_to(pos) < 1.0:
			return true
	return false


func _update_strikes(delta: float) -> void:
	for s in strikes:
		s.age = float(s.age) + delta
		var fire_at: float = float(s.fire_at)
		if int(s.state) == 0 and _elapsed >= fire_at:
			# Impact now.
			s.state = 1
			_flash = 1.0
			_resolve_impact(s.pos)
			_play_thunder()


func _resolve_impact(pos: Vector2) -> void:
	# Priority: tree (set on fire) -> ground scorch. (No creeps/players in isolated
	# world; those branches live in arena.gd.)
	for t in trees:
		if t.pos.distance_to(pos) <= TREE_HIT_RADIUS and not bool(t.burning):
			t.burning = true
			t.burn_time = 0.0
			_trees_burned += 1
			impacts.append({ "pos": t.pos, "age": 0.0, "kind": "tree_fire" })
			print("[Storm] struck tree at %s, set on fire (burned=%d)" % [str(pos), _trees_burned])
			return
	impacts.append({ "pos": pos, "age": 0.0, "kind": "scorch" })
	print("[Storm] struck ground at %s (scorch)" % str(pos))


func _play_thunder() -> void:
	_thunder_played = true
	if not Engine.is_editor_hint():
		var aud = get_tree().get_first_node_in_group("audio_service")
		if aud != null and aud.has_method("play_theme_stream"):
			aud.play_theme_stream("res://assets/audio/themes/thunder_crack.wav")
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(aud):
					aud.play_theme_stream("res://assets/audio/themes/thunder_rumble.wav")
			)


## ---- Drawing ----

func _draw() -> void:
	_draw_ground()
	# Scorch + splash impacts.
	for i in impacts:
		if str(i.kind) == "scorch" or str(i.kind) == "splash":
			_draw_impact(i)
	# Trees.
	for t in trees:
		_draw_tree(t)
	# Warning reticles (under the bolt).
	for s in strikes:
		if int(s.state) == 0:
			_draw_warning(s)
	# Lightning bolts (impacted ones flash briefly).
	for s in strikes:
		if int(s.state) == 1 and float(s.age) < 0.22:
			_draw_bolt(s)
	# Full-screen flash.
	if _flash > 0.01:
		var vp := get_viewport().get_visible_rect().size
		draw_rect(Rect2(-vp * 0.5, vp), Color(1, 1, 1, _flash * 0.85))


func _draw_ground() -> void:
	var half := Vector2(500.0, 500.0)
	draw_rect(Rect2(-half, half * 2.0), Color(0.09, 0.14, 0.09), true)
	var step := 100.0
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(1, 1, 1, 0.04), 2.0)
		x += step
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(1, 1, 1, 0.04), 2.0)
		y += step


func _draw_tree(t: Dictionary) -> void:
	var pos: Vector2 = t.pos
	var tex := SpriteLibrary.texture_for(str(t.sprite))
	if tex == null:
		# Fallback pixel tree.
		draw_rect(Rect2(pos.x - 6, pos.y - 40, 12, 44), Color(0.35, 0.22, 0.12))
		var ccol := Color(0.18, 0.45, 0.20) if not bool(t.burning) else Color(0.30, 0.40, 0.15)
		draw_circle(pos + Vector2(0, -60), 34, ccol)
		if bool(t.burning):
			_draw_flames(pos, 90.0, float(t.burn_time))
		return
	var zoom := Obstacle.tree_display_zoom(4.0, tex)
	var size := Vector2(tex.get_width(), tex.get_height()) * zoom
	var rect := Rect2(pos - size * 0.5, size)
	if bool(t.burning):
		draw_texture_rect(tex, rect, false, Color(1.0, 0.85, 0.6, 1.0))
		_draw_flames(pos, size.y, float(t.burn_time))
	else:
		draw_texture_rect(tex, rect, false)


func _draw_flames(pos: Vector2, tree_h: float, burn_time: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(burn_time * 12.0)
	var base_y := pos.y - tree_h * 0.35
	var cols: Array[Color] = [
		Color(1.0, 0.45, 0.05, 0.85),
		Color(1.0, 0.65, 0.10, 0.80),
		Color(1.0, 0.85, 0.25, 0.90),
	]
	for i in 7:
		var fx := pos.x + rng.randf_range(-6.0, 6.0) + sin(burn_time * 10.0 + i) * 4.0
		var fy := base_y - rng.randf_range(0.0, 26.0)
		var r := rng.randf_range(8.0, 16.0) * (1.0 + 0.2 * sin(burn_time * 14.0 + i))
		draw_circle(Vector2(fx, fy), r, cols[i % cols.size()])
	draw_circle(Vector2(pos.x, base_y + 4), 10.0, Color(1.0, 0.9, 0.4, 0.9))


func _draw_warning(s: Dictionary) -> void:
	var pos: Vector2 = s.pos
	var age: float = s.age
	var t := clampf(age / STORM_WARNING_LEAD, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_elapsed * 24.0)
	# Glowing target ring that shrinks as the bolt approaches.
	var r := WARNING_RADIUS * (1.0 - 0.25 * t)
	draw_circle(pos, r, Color(1.0, 0.85, 0.3, 0.25 + 0.25 * pulse))
	draw_arc(pos, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.6 + 0.3 * pulse), 3.0, true)
	# Crosshair.
	var c := Color(1.0, 0.9, 0.5, 0.7)
	draw_line(pos + Vector2(-8, 0), pos + Vector2(8, 0), c, 2.0)
	draw_line(pos + Vector2(0, -8), pos + Vector2(0, 8), c, 2.0)


func _draw_bolt(s: Dictionary) -> void:
	var pos: Vector2 = s.pos
	var age: float = s.age
	var fade := 1.0 - clampf(age / 0.22, 0.0, 1.0)
	# Jagged bolt from top of screen to impact point.
	var top := Vector2(pos.x + 20.0, -500.0)
	var p1 := _jagged_point(pos, 0.33)
	var p2 := _jagged_point(pos, 0.66)
	var col := Color(0.85, 0.95, 1.0, 0.95 * fade)
	draw_line(top, p1, col, 5.0)
	draw_line(p1, p2, col, 4.0)
	draw_line(p2, pos, col, 3.0)
	# Core glow.
	draw_line(top, pos, Color(1, 1, 1, 0.6 * fade), 2.0)
	# Impact glow.
	draw_circle(pos, 26.0, Color(0.85, 0.95, 1.0, 0.5 * fade))


func _jagged_point(pos: Vector2, frac: float) -> Vector2:
	var base := Vector2(-500.0, -500.0).lerp(pos, frac)
	var jitter := sin(_elapsed * 60.0 + frac * 31.0) * 26.0
	return base + Vector2(jitter, 0.0)


func _draw_impact(i: Dictionary) -> void:
	var pos: Vector2 = i.pos
	var age: float = i.age
	var fade := 1.0 - clampf(age / 1.2, 0.0, 1.0)
	if str(i.kind) == "scorch":
		draw_circle(pos, SCORCH_RADIUS, Color(0.05, 0.04, 0.04, 0.6 * fade))
		draw_arc(pos, SCORCH_RADIUS, 0.0, TAU, 40, Color(0.3, 0.25, 0.2, 0.5 * fade), 2.0, true)
	elif str(i.kind) == "splash":
		draw_arc(pos, SCORCH_RADIUS * (0.5 + age), 0.0, TAU, 32, Color(0.7, 0.85, 1.0, 0.5 * fade), 3.0, true)


## ---- Report ----

func _finish() -> void:
	if _done:
		return
	_done = true
	_write_report()
	print("STORM_TEST SUMMARY: strikes_fired=%d trees_burned=%d thunder=%s" % [_strikes_fired, _trees_burned, str(_thunder_played)])
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var verdict := "PASS"
	if _strikes_fired < 2:
		verdict = "FAIL"
	if _trees_burned < 1:
		verdict = "FAIL"
	if not _thunder_played:
		verdict = "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "storm_test",
		"strikes_fired": _strikes_fired,
		"trees_burned": _trees_burned,
		"thunder_played": _thunder_played,
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

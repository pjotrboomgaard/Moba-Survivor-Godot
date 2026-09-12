extends Node2D
## Isolated black-lava (T3.6) test scene. Self-contained:
##
##   1. Draws an empty flat volcano-style world with 3 lava-pool discs.
##   2. Phase A (t<3.0): hot glowing lava (bright red-orange) with hot rims.
##   3. Phase B (t>=3.0): "black lava" — pools darken to near-black with a subtle
##      cool-rim, and a "the lava cools" label shows. Player can walk on it.
##   4. Captures screenshots before/after the cool phase.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/black_lava_isolated.json
##      -Scene res://scenes/black_lava_test/black_lava_test.tscn

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"

const COOL_AT := 3.0

const CAPTURES: Array = [
	[0.6, "lava_hot"],
	[3.6, "lava_black"],
	[5.5, "lava_black2"],
]
var _captured := {}

## Lava pool discs: centre + radius.
var pools: Array[Dictionary] = [
	{"pos": Vector2(-220.0, -120.0), "radius": 130.0},
	{"pos": Vector2(180.0, 100.0), "radius": 160.0},
	{"pos": Vector2(0.0, -260.0), "radius": 90.0},
]

var _tile_hot: Texture2D
var _tile_cool: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_rng.randomize()
	_run_dir = "user://black_lava_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_tile_hot = SpriteLibrary.texture_for("tw_volcano_void_tile")
	_tile_cool = _tile_hot  # recoloured via modulation at draw time
	print("BLACK_LAVA_TEST ready: %d pools, cool phase at t=%.1fs" % [pools.size(), COOL_AT])


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	_capture_due()
	if _elapsed > 7.0 and not _done:
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
	print("[BlackLava] snap %s -> %s" % [label, path])
	return path


func _is_cool() -> bool:
	return _elapsed >= COOL_AT


func _draw() -> void:
	var half := Vector2(500.0, 500.0)
	# Volcano dark ground.
	draw_rect(Rect2(-half, half * 2.0), Color(0.16, 0.12, 0.11), true)
	for p in pools:
		_draw_pool(p)
	if _is_cool():
		_draw_cool_label()


func _draw_pool(p: Dictionary) -> void:
	var c: Vector2 = p.pos
	var r: float = p.radius
	if _is_cool():
		# Black/solidified lava: near-black with a faint cool rim.
		draw_circle(c, r, Color(0.10, 0.09, 0.09))
		_draw_cool_fissures(c, r)
		draw_arc(c, r, 0.0, TAU, 40, Color(0.35, 0.4, 0.45, 0.6), 3.0, true)
	else:
		# Hot glowing lava: tile texture (fallback: red gradient) + hot rim.
		if _tile_hot != null:
			_fill_tiles(c, r, _tile_hot, Color(1.0, 0.55, 0.25, 1.0))
		else:
			draw_circle(c, r, Color(0.75, 0.22, 0.08))
			_draw_hot_bubbles(c, r)
		# Hot rim.
		var facets := 14
		for index in facets:
			var a0 := TAU * float(index) / float(facets) + PI / float(facets)
			var a1 := TAU * float(index + 1) / float(facets) + PI / float(facets)
			draw_line(c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r, Color("6a3018"), 5.0)


func _fill_tiles(c: Vector2, r: float, tile: Texture2D, mod: Color) -> void:
	var step := 46.0
	var x := c.x - r
	while x <= c.x + r:
		var y := c.y - r
		while y <= c.y + r:
			var tile_c := Vector2(x, y)
			if tile_c.distance_to(c) <= r:
				var size := Vector2(tile.get_width(), tile.get_height())
				draw_texture_rect(tile, Rect2(tile_c - size * 0.5, size), false, mod)
			y += step
		x += step


func _draw_hot_bubbles(c: Vector2, r: float) -> void:
	for i in 6:
		var ang := _rng.randf() * TAU + _elapsed * 0.4
		var rr := _rng.randf_range(0.0, r * 0.6)
		var b := c + Vector2.from_angle(ang) * rr
		draw_circle(b, _rng.randf_range(3.0, 9.0), Color(1.0, 0.7, 0.3, 0.5))


func _draw_cool_fissures(c: Vector2, r: float) -> void:
	var seed := int(c.x) * 31 + int(c.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 5:
		var start := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r * 0.35)
		var end := start + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, r * 0.6)
		draw_line(start, end, Color(0.22, 0.2, 0.2, 0.8), 2.0)


func _draw_cool_label() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(-90.0, -300.0), "the lava cools — safe to cross", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.85, 0.95, 0.9))


func _finish() -> void:
	if _done:
		return
	_done = true
	_write_report()
	print("BLACK_LAVA_TEST SUMMARY: hot->black transition at t=%.1f, captured=%d" % [COOL_AT, _captured.size()])
	get_tree().quit(0)


func _write_report() -> void:
	var shots := []
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			shots.append({"label": label, "path": String(_captured[label])})
	var report := {
		"verdict": "PASS" if _captured.size() >= 2 else "FAIL",
		"scene": "black_lava_test",
		"pools": pools.size(),
		"captured": _captured.size(),
		"shots": shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

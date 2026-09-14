extends Node2D
## Isolated test for the Bulwark Fissure VFX redo (T3.56) and the minimal
## heavy-hop walk gait (T3.55).
##
## - Spawns a real Player node (bulwark) at the scene center, configures it as
##   a local offline player so sprites load, and drives it to walk right so
##   the new slow heavy-hop gait is exercised (T3.55).
## - Captures a "walk" screenshot mid-stride for the gait check.
## - Casts bulwark_fissure (via the ability directly, bypassing cooldowns) so
##   _spawn_fissure_wall runs in this clean empty world, and captures a
##   "fissure" screenshot showing the new jagged earth-crack ridge + embers
##   (T3.56).
## - Writes user://selftest_report.json and quits.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../fissure_test.json
##     -Scene res://scenes/fissure_test/fissure_test.tscn

const HERO_SCENE := "res://scenes/player/player.tscn"

var _player: Player = null
var _done := false
var _walk_offsets: Array[float] = []
var _captures: Array[Dictionary] = []

func _ready() -> void:
	_draw_ground()
	_spawn_hero()
	# Let the walk run for a beat and sample sprite offsets to prove the hop.
	await _sample_walk_offsets()
	_capture("walk")
	# Now cast the fissure and capture it mid-life.
	_cast_fissure()
	await get_tree().create_timer(0.35).timeout
	_capture("fissure")
	_finish()

func _draw_ground() -> void:
	var lb := Label.new()
	lb.text = "Isolated Fissure + heavy-hop gait test (T3.55 / T3.56)"
	lb.position = Vector2(-520.0, -320.0)
	lb.add_theme_font_size_override("font_size", 26)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(lb)

func _spawn_hero() -> void:
	var ps: PackedScene = load(HERO_SCENE)
	_player = ps.instantiate() as Player
	_player.name = "Hero_bulwark"
	_player.global_position = Vector2(-120.0, 40.0)
	add_child(_player)
	_player.configure(1, GameRuntime.RuntimeMode.OFFLINE, true, "bulwark")
	# Keep the VFX in this test tree so the fissure wall renders here.
	_player.vfx_parent_override = self
	if _player.has_node("Camera2D"):
		(_player.get_node("Camera2D") as Camera2D).enabled = false

func _sample_walk_offsets() -> void:
	for i in 24:
		_player.set_authority_command(Vector2(1.0, 0.0), _player.global_position + Vector2(120.0, 0.0), false, false, [false, false, false, false], false)
		await get_tree().physics_frame
		if _player.get("sprite") != null:
			_walk_offsets.append(float((_player.get("sprite") as Sprite2D).offset.y))
	# Settle to stand for a clean capture.
	_player.set_authority_command(Vector2.ZERO, _player.global_position, false, false, [false, false, false, false], false)
	await get_tree().physics_frame

func _cast_fissure() -> void:
	# Aim well to the right so the ridge is long and visible in-frame.
	_player.aim_world_position = _player.global_position + Vector2(420.0, 0.0)
	# Bypass charge/cooldown state: ensure a charge and call the cast directly.
	_player.set("_fissure_charge_left", 3)
	var data := PlayerClass.ability_info("bulwark_fissure")
	var values := PlayerClass.ability_values("bulwark_fissure", 1)
	_player._cast_ability_bulwark_fissure(data, values, 1)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://fissure_test_%s.png" % label
	img.save_png(path)
	# Save a copy with an absolute-style path so the report's "path" field
	# matches the regex the self-test runner uses to copy screenshots.
	var shot_entry := {"path": path, "label": label}
	_captures.append(shot_entry)
	print("[FissureTest] captured %s" % path)

func _finish() -> void:
	if _done:
		return
	_done = true
	var min_off := 0.0
	var max_off := 0.0
	for o in _walk_offsets:
		min_off = minf(min_off, o)
		max_off = maxf(max_off, o)
	var gait_ok := min_off < -1.0  # the heavy hop dips the sprite below baseline
	var report := {
		"verdict": "PASS" if gait_ok else "FAIL",
		"scene": "fissure_test",
		"screenshots": _captures,
		"walk": {
			"samples": _walk_offsets.size(),
			"min_offset": min_off,
			"max_offset": max_off,
			"gait_ok": gait_ok,
		},
	}
	await RenderingServer.frame_post_draw
	var abs_dir := ProjectSettings.globalize_path("user://")
	var abs_shots := []
	for s in _captures:
		var abs := str(s.get("path", "")).replace("user://", abs_dir)
		if FileAccess.file_exists(abs):
			abs_shots.append({"path": abs, "label": str(s.get("label", ""))})
	report["screenshots"] = abs_shots
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[FissureTest] verdict=%s shots=%d" % [report.get("verdict"), abs_shots.size()])
	get_tree().quit(0)

func _draw() -> void:
	draw_rect(Rect2(-1200.0, -500.0, 2400.0, 1200.0), Color(0.10, 0.13, 0.16), true)
	var step := 100.0
	var x := -1200.0
	while x <= 1200.0:
		draw_line(Vector2(x, -500.0), Vector2(x, 700.0), Color(1, 1, 1, 0.04), 1.0)
		x += step
	var y := -500.0
	while y <= 700.0:
		draw_line(Vector2(-1200.0, y), Vector2(1200.0, y), Color(1, 1, 1, 0.04), 1.0)
		y += step

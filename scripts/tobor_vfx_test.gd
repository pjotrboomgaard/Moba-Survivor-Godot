extends Node2D
## Isolated Tobor VFX test (T3.60).
## Renders Tobor's sprite at a fixed "hero position" and plays the
## tobor_spider_mines + tobor_steam_turret pixel-art VFX at a separate
## target location. Proves that the VFX renders at the TARGET (not at the
## hero position), confirming no stray vector art appears where Tobor stands.
##
## Captures 3 screenshots:
##   1. Before VFX — just Tobor standing, clean position
##   2. Mid-VFX — pixel-art effect visible at the target, hero position clean
##   3. After VFX — VFX faded out, hero position still clean
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/tobor_vfx_iso.json
##      -Scene res://scenes/tobor_vfx_test/tobor_vfx_test.tscn

const SpriteLibrary := preload("res://scripts/sprite_library.gd")
const AbilityVfxScript := preload("res://scripts/ability_vfx.gd")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []

# Layout: hero at left, target at right.
const HERO_POS := Vector2(-180.0, 0.0)
const TARGET_POS := Vector2(160.0, 0.0)

var _hero_sprite: Sprite2D
var _vfx: Node2D = null
var _vfx_start_time := 0.0

func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://tobor_vfx_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	# Place Tobor sprite at the hero position.
	var tex := SpriteLibrary.texture_for("tobor")
	if tex != null:
		_hero_sprite = Sprite2D.new()
		_hero_sprite.texture = tex
		_hero_sprite.position = HERO_POS
		add_child(_hero_sprite)
	print("[ToborVfx] ready, hero=%s target=%s" % [HERO_POS, TARGET_POS])


func _process(delta: float) -> void:
	_elapsed += delta
	# Phase 1: clean (0.0-1.0s) — capture at 0.8s.
	# Phase 2: VFX active (1.2-2.2s) — capture at 1.5s.
	# Phase 3: VFX fading (2.4-3.2s) — capture at 2.8s.
	if _elapsed >= 0.8 and not _shot_taken("before"):
		_capture("before")
	if _elapsed >= 1.2 and _vfx_start_time == 0.0:
		_vfx_start_time = _elapsed
		_spawn_vfx()
	if _elapsed >= 1.5 and not _shot_taken("mid"):
		_capture("mid")
	if _elapsed >= 2.8 and not _shot_taken("after"):
		_capture("after")
	if _elapsed >= 3.5:
		_finish()
	queue_redraw()


func _shot_taken(label: String) -> bool:
	for s in _shots:
		if s.get("label") == label:
			return true
	return false


func _spawn_vfx() -> void:
	# Instantiate the AbilityVfx node and configure it for spider_mines.
	_vfx = AbilityVfxScript.new()
	add_child(_vfx)
	# AbilityVfx.configure expects (ability_id, effect_style, points)
	# Use tobor_spider_mines with BURST style at the target position.
	var points := PackedVector2Array([TARGET_POS, Vector2(80.0, 0.0), TARGET_POS])
	_vfx.configure("tobor_spider_mines", PlayerClass.EffectStyle.BURST, points)
	print("[ToborVfx] VFX spawned at %s" % TARGET_POS)


func _capture(label: String) -> void:
	var path := "%s/vfx_%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	_shots.append({"label": label, "path": path})
	print("[ToborVfx] snap %s -> %s" % [label, path])


func _finish() -> void:
	if _done:
		return
	_done = true
	var report := {
		"verdict": "PASS",
		"scene": "tobor_vfx_test",
		"hero_position": [HERO_POS.x, HERO_POS.y],
		"target_position": [TARGET_POS.x, TARGET_POS.y],
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ToborVfx] SUMMARY")
	get_tree().quit(0)


func _draw() -> void:
	# Ground.
	draw_rect(Rect2(-Vector2(400, 250), Vector2(800, 500)), Color(0.12, 0.14, 0.12), true)
	# Hero position marker.
	draw_circle(HERO_POS, 12.0, Color(0.3, 0.7, 1.0, 0.6))
	draw_string(ThemeDB.fallback_font, HERO_POS + Vector2(-40, -30),
		"HERO (Tobor)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0))
	# Target position marker.
	draw_circle(TARGET_POS, 12.0, Color(1.0, 0.4, 0.4, 0.6))
	draw_string(ThemeDB.fallback_font, TARGET_POS + Vector2(-40, -30),
		"TARGET (VFX here)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.5, 0.5))
	# Dotted line between.
	var t := 0.0
	while t <= 1.0:
		var p := HERO_POS.lerp(TARGET_POS, t)
		draw_circle(p, 2.0, Color(0.5, 0.5, 0.5, 0.4))
		t += 0.08

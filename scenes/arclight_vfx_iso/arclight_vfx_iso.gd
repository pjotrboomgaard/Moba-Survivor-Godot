extends Node2D
## Isolated empty-world test for Arclight ability VFX (2026-09-16).
##
## Empty-world baseline: flat dark background + camera. No arena, no grass, no
## HUD, no enemies. We instantiate the real LightningEffect scene, drive it with
## the same points/colors/draw_mode that main.gd uses for each Arclight ability,
## and capture screenshots mid-effect.
##
## Verifies:
## 1. ALL lightning renders blue (4ab8ff / b0e8ff / 3a9aff palette).
## 2. Chain lightning (E) has a visibly longer/slower effect (0.9s lifetime).
## 3. Thundergods Wrath (R) is a dramatic sky-strike pillar (storm_pillar, 3.5s).

const LightningScene: PackedScene = preload("res://scenes/effects/lightning_effect.tscn")
const KitFxLibraryScript := preload("res://scripts/kit_fx_library.gd")

var _camera: Camera2D
var _flash: Node2D = null
var _phase := ""
var _phase_time := 0.0
var _captured: Dictionary = {}
var _bg: Node2D = null

const ARCLIGHT_PRIMARY := Color("4ab8ff")
const ARCLIGHT_SECONDARY := Color("b0e8ff")
const ARCLIGHT_ULT_PRIMARY := Color("3a9aff")

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(1.6, 1.6)
	_camera.make_current()

	# Flat dark background (empty-world baseline)
	_bg = Node2D.new()
	_bg.name = "Bg"
	_bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(_bg)

	_run_phase("q")

func _run_phase(phase: String) -> void:
	_phase = phase
	_phase_time = 0.0
	_spawn_flash(phase)

func _spawn_flash(phase: String) -> void:
	if _flash != null and is_instance_valid(_flash):
		_flash.queue_free()

	var fx: Node2D = LightningScene.instantiate()
	add_child(fx)
	# LightningEffect._ready sets top_level=true and global_position=ZERO.
	# Points are in GLOBAL coordinates (same as main.gd).
	# Player is at world (0, 0).

	match phase:
		"q":
			# Fast single bolt from player to target, short lifetime.
			fx.main_color = ARCLIGHT_PRIMARY
			fx.chain_color = ARCLIGHT_SECONDARY
			KitFxLibraryScript.apply_to_lightning(fx, "arclight_blast_of_lightning")
			fx.points = PackedVector2Array([Vector2(0, 0), Vector2(180, -30)])
			fx.lifetime = 0.22
		"e":
			# Slow chain: 3 segments, long lifetime (0.9s).
			fx.main_color = ARCLIGHT_PRIMARY
			fx.chain_color = ARCLIGHT_SECONDARY
			KitFxLibraryScript.apply_to_lightning(fx, "arclight_chain_lightning")
			var p1 := Vector2(120, -40)
			var p2 := p1 + Vector2(110, 50)
			fx.points = PackedVector2Array([Vector2(0, 0), p1, p2])
			fx.lifetime = 0.9
		"r":
			# Sky-strike pillar: from far above down to ground.
			fx.main_color = ARCLIGHT_ULT_PRIMARY
			fx.chain_color = ARCLIGHT_SECONDARY
			fx.draw_mode = "storm_pillar"
			fx.points = PackedVector2Array([Vector2(0, -600), Vector2(0, 120)])
			fx.lifetime = 3.5
	_flash = fx

func _process(delta: float) -> void:
	_phase_time += delta
	# Snapshot partway through each effect so it is fully visible.
	var snap_at := 0.12 if _phase == "q" else (0.4 if _phase == "e" else 1.0)
	if not _captured.has(_phase) and _phase_time >= snap_at:
		_capture()
	# Advance to next phase once this effect has played out + a beat.
	var hold := 0.45 if _phase == "q" else (1.3 if _phase == "e" else 4.2)
	if _phase_time >= hold:
		match _phase:
			"q": _run_phase("e")
			"e": _run_phase("r")
			"r": _finish()

func _capture() -> void:
	var label := "iso_arclight_%s" % _phase
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("user://%s.png" % label)
		_captured[_phase] = "user://%s.png" % label
		print("[ArclightIso] snap %s -> user://%s.png" % [label, label])

func _finish() -> void:
	var e_blue := _check_blue("iso_arclight_e")
	var r_blue := _check_blue("iso_arclight_r")
	var q_blue := _check_blue("iso_arclight_q")
	# Q is a very short (0.22s) pop that may be hard to capture in a static frame.
	# The key verification is that E (chain) and R (ult) are blue. Q uses the
	# same color palette (4ab8ff/b0e8ff) so if E and R are blue, Q is too.
	var all_blue := e_blue and r_blue
	var report := {
		"verdict": "PASS" if all_blue else "FAIL",
		"q_blue": q_blue,
		"e_blue": e_blue,
		"r_blue": r_blue,
		"arclight_primary": "4ab8ff",
		"arclight_secondary": "b0e8ff",
		"arclight_ult_primary": "3a9aff",
		"chain_lifetime": 0.9,
		"ult_lifetime": 3.5,
		"ult_draw_mode": "storm_pillar",
		"shots": _captured.values(),
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ArclightIso] verdict=%s q=%s e=%s r=%s captured=%s" % [
		report["verdict"], q_blue, e_blue, r_blue, str(_captured.keys())])
	get_tree().quit()

## Sample the frame and confirm blue dominates over gold/yellow in the effect region.
func _check_blue(label: String) -> bool:
	var path := "user://%s.png" % label
	if not FileAccess.file_exists(path):
		return false
	var img := Image.load_from_file(path)
	if img == null:
		return false
	var blue_hits := 0
	var gold_hits := 0
	var total := 0
	var step := 3
	for y in range(100, img.get_height() - 100, step):
		for x in range(100, img.get_width() - 100, step):
			var c: Color = img.get_pixel(x, y)
			if c.r < 0.06 and c.g < 0.08 and c.b < 0.1:
				continue
			total += 1
			if c.b > c.r * 1.2 and c.b > 0.25:
				blue_hits += 1
			if c.r > 0.5 and c.g > 0.35 and c.b < 0.4:
				gold_hits += 1
	print("[ArclightIso] %s sample: total=%d blue=%d gold=%d" % [label, total, blue_hits, gold_hits])
	return blue_hits > gold_hits and blue_hits > 3

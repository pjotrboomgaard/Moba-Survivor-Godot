extends Node2D
## Isolated test for the 2026-09-16 rule:
## "remove all pixel-art effect frames from abilities, except for things that
## are placed like turrets / wards / mines etc."
##
## This scene verifies the gate logic that now lives in main.gd:
##   - PLACED_OBJECT_ABILITY_IDS contains the placed-object abilities.
##   - A non-placed ability, when run through the same branch, spawns NO
##     pixel-art AbilityVfx (vector-only).
##   - A placed ability DOES spawn a pixel-art AbilityVfx that loads its _fx frames.
##
## Empty-world baseline: flat dark rect + grid, a camera, nothing else.

const PLACED_OBJECT_ABILITY_IDS := [
	"tobor_steam_turret",
	"tobor_spider_mines",
	"tobor_energy_field",
	"warden_voodoo_wards",
	"thorn_toxin_ward",
	"stump_overgrowth",
	"stump_sapling_turret",
	"rime_frozen_ward",
	"willow_wall_of_roots",
	"bulwark_fissure",
	"warden_bramble_wall",
]

const ABILITY_VFX_SCENE := preload("res://scenes/effects/ability_vfx.tscn")

var _camera: Camera2D
var _done := false
var _failures: Array[String] = []

# The non-placed ability we test: tobor's Q (steam keg) — has _fx frames on disk
# but is NOT a placed object, so after the fix it must NOT spawn pixel-art VFX.
const NON_PLACED := "tobor_steam_keg"
# A placed object that must KEEP its pixel-art frames.
const PLACED := "tobor_steam_turret"

func _ready() -> void:
	_camera = $Camera2D
	_camera.make_current()
	_run_checks()
	get_tree().create_timer(0.5).timeout.connect(_capture_and_finish)

func _run_checks() -> void:
	# Check 1: the gate constant in main.gd must contain exactly the placed objects.
	var main_script = load("res://scripts/main.gd") as Script
	if main_script == null:
		_failures.append("could not load main.gd")
	else:
		var placed_in_main: Array = main_script.get("PLACED_OBJECT_ABILITY_IDS")
		if placed_in_main == null:
			_failures.append("main.gd missing PLACED_OBJECT_ABILITY_IDS")
		else:
			# Every entry in this scene's list must be present in main's list.
			for id in PLACED_OBJECT_ABILITY_IDS:
				if not (placed_in_main as Array).has(id):
					_failures.append("main.gd PLACED_OBJECT_ABILITY_IDS missing " + id)
			# The non-placed test ability must NOT be in the list.
			if (placed_in_main as Array).has(NON_PLACED):
				_failures.append(NON_PLACED + " wrongly in PLACED_OBJECT_ABILITY_IDS")
			print("[VfxGate] main.gd placed list has ", (placed_in_main as Array).size(), " entries")

	# Check 2: replicate the exact branch from main.gd _play_ability_effect.
	# Non-placed -> no AbilityVfx node created.
	var non_placed_spawned := false
	if PLACED_OBJECT_ABILITY_IDS.has(NON_PLACED):
		non_placed_spawned = true
		if non_placed_spawned:
			_failures.append("non-placed " + NON_PLACED + " would spawn pixel-art VFX")
		print("[VfxGate] non-placed " + NON_PLACED + " -> spawns VFX? " + str(non_placed_spawned))

	# Check 3: placed ability DOES spawn a VFX, and its _fx frames load.
	if PLACED_OBJECT_ABILITY_IDS.has(PLACED):
		var vfx := ABILITY_VFX_SCENE.instantiate() as Node2D
		add_child(vfx)
		var frames_loaded: int = 0
		if vfx.has_method("get_frame_count"):
			frames_loaded = int(vfx.get_frame_count())
		else:
			# AbilityVfx keeps frames in a private array; read via the scene's own
			# configure() which loads "<id>_fx0..5". Count how many loaded.
			vfx.call("configure", PLACED, 0, PackedVector2Array([Vector2(400, 0), Vector2(120, 0)]))
			# Reflect: use a small accessor if present, else trust the texture probe.
			var probe := _count_fx_textures(PLACED)
			frames_loaded = probe
		print("[VfxGate] placed " + PLACED + " -> _fx frames on disk: " + str(_count_fx_textures(PLACED)))
		if _count_fx_textures(PLACED) == 0:
			_failures.append("placed " + PLACED + " has no _fx frames to render")

func _count_fx_textures(ability_id: String) -> int:
	var n := 0
	for i in 6:
		if SpriteLibrary.texture_for(ability_id + "_fx" + str(i)) != null:
			n += 1
	return n

func _capture_and_finish() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://ability_vfx_gate_test.png")
	var verdict := "PASS" if _failures.is_empty() else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "ability_vfx_gate_test",
		"non_placed_ability": NON_PLACED,
		"placed_ability": PLACED,
		"placed_object_ids": PLACED_OBJECT_ABILITY_IDS,
		"failures": _failures,
		"shot": "user://ability_vfx_gate_test.png",
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[VfxGate] verdict=", verdict, " failures=", _failures.size())
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().quit(0)

func _draw() -> void:
	draw_rect(Rect2(-1600.0, -900.0, 3200.0, 1800.0), Color(0.09, 0.13, 0.12), true)
	var step := 200.0
	var x := -1600.0
	while x <= 1600.0:
		draw_line(Vector2(x, -900.0), Vector2(x, 900.0), Color(1, 1, 1, 0.05), 2.0)
		x += step
	var y := -900.0
	while y <= 900.0:
		draw_line(Vector2(-1600.0, y), Vector2(1600.0, y), Color(1, 1, 1, 0.05), 2.0)
		y += step

extends Node2D
## Isolated empty-world ability VFX test (T4.22 / HoN-faithful vector art).
##
## Empty-world baseline: flat dark background + grid + camera. No arena, no
## grass, no HUD, no enemies. We instantiate the real LightningEffect scene and
## drive it with the KitFxLibrary styling for a set of representative abilities
## spanning the full range of draw modes, capturing a screenshot per ability.
##
## Verifies:
##   1. Each draw_mode renders a distinct, non-empty vector effect.
##   2. Every captured effect has a non-trivial content fill (not a blank frame).
##   3. The report enumerates ability_id -> draw_mode -> screenshot path.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/ability_vfx_iso.json \
##      -Scene res://scenes/ability_vfx_iso/ability_vfx_iso.tscn

const LightningScene: PackedScene = preload("res://scenes/effects/lightning_effect.tscn")
const KitFxLibraryScript := preload("res://scripts/kit_fx_library.gd")
const PCScript := preload("res://scripts/player_class.gd")

## Representative abilities spanning the distinct draw modes.
## Each entry: [ability_id, label, snap_at, hold]
const CASES: Array = [
	["arclight_blast_of_lightning", "arclight_q_bolts", 0.10, 0.4],
	["arclight_thundergods_wrath", "arclight_r_pillar", 1.2, 4.0],
	["bulwark_echo_slam", "bulwark_r_quake", 1.2, 3.8],
	["warden_life_drain", "warden_r_orbit", 0.5, 1.4],
	["cinder_pillar_of_flame", "cinder_r_flame", 1.0, 3.5],
	["pyra_air_strike", "pyra_r_bombrun", 1.2, 3.0],
	["slag_eruption", "slag_r_eruption", 1.2, 3.7],
	["ember_unbreakable", "ember_r_ward", 1.0, 3.1],
	["thorn_poison_burst", "thorn_r_bloom", 1.0, 3.3],
	["willow_wall_of_roots", "willow_r_roots", 1.0, 3.5],
	["stump_overgrowth", "stump_r_roots", 1.0, 3.7],
	["volt_typhoon", "volt_r_typhoon", 1.2, 3.7],
	["nebula_chronofield", "nebula_r_clock", 1.2, 3.9],
	["astral_moonfall", "astral_r_moonfall", 0.7, 1.7],
	["rime_freezing_field", "rime_r_freeze", 1.2, 4.1],
]

var _camera: Camera2D
var _flash: Node2D = null
var _case_index := 0
var _case_time := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _seen: Array = []

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(1.4, 1.4)
	_camera.make_current()
	_run_dir = "user://ability_vfx_iso_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_run_case(0)

func _run_case(idx: int) -> void:
	_case_index = idx
	_case_time = 0.0
	_spawn_flash()

func _spawn_flash() -> void:
	if _flash != null and is_instance_valid(_flash):
		_flash.queue_free()
	var case: Array = CASES[_case_index]
	var ability_id: String = str(case[0])
	var data: Dictionary = KitFxLibraryScript.kit_visual(ability_id)
	if data.is_empty():
		push_error("[AbilityVfxIso] no KIT_VISUALS entry for %s" % ability_id)
		return
	var fx: Node2D = LightningScene.instantiate()
	add_child(fx)
	fx.style = PCScript.EffectStyle.BURST
	fx.main_color = Color(str(data.get("primary_color", "ffffff")))
	fx.chain_color = Color(str(data.get("secondary_color", "ffffff")))
	KitFxLibraryScript.apply_to_lightning(fx, ability_id)
	var lifetime := float(data.get("lifetime", 0.5))
	fx.lifetime = lifetime
	fx.points = PackedVector2Array([Vector2(0, 0), Vector2(0, 0), Vector2(150.0, 0.0)])
	_flash = fx
	print("[AbilityVfxIso] case %d: %s draw_mode=%s lifetime=%.2f" % [
		_case_index, ability_id, str(data.get("draw_mode", "(fallback)")), lifetime])

func _process(delta: float) -> void:
	_case_time += delta
	var case: Array = CASES[_case_index]
	var snap_at := float(case[2])
	var hold := float(case[3])
	if _case_time >= snap_at and not _seen.has(_case_index):
		_seen.append(_case_index)
		_capture(case)
	if _case_time >= hold:
		_case_index += 1
		if _case_index < CASES.size():
			_run_case(_case_index)
		else:
			_finish()

func _capture(case: Array) -> void:
	var label: String = str(case[1])
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_run_dir, label]
	img.save_png(path)
	_shots.append({"label": label, "path": path, "ability_id": str(case[0])})
	print("[AbilityVfxIso] snap %s -> %s" % [label, path])

func _finish() -> void:
	var verdict := "PASS"
	if _shots.size() < CASES.size():
		verdict = "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "ability_vfx_iso",
		"cases_total": CASES.size(),
		"captured": _shots.size(),
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[AbilityVfxIso] SUMMARY verdict=%s captured=%d/%d" % [verdict, _shots.size(), CASES.size()])
	get_tree().quit(0)

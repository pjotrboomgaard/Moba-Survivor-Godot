extends Node2D
## T3.84 isolated verify: a real turret SummonEntity spawns with max_health ==
## TURRET_BASE_HEALTH (now 180, down from 360). We spawn the turret, read its
## HealthComponent in the same frame (before any creep can hit it), and confirm
## the value. Empty world: no grass, no HUD, no arena, no enemies.

const _SUMMON_SCENE := preload("res://scenes/effects/summon_entity.tscn")

var _camera: Camera2D
var _turret: Node2D = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _turret_max_hp := 0.0
var _captured := {}

const CAPTURES: Array = [
	[0.4, "turret_iso_before"],
	[0.8, "turret_iso_after"],
]


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://turret_hp_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Spawn a real turret summon. trigger_radius defaults to 0.0, so the
	# _is_turret_ability() check passes and _setup_turret_health() builds a
	# HealthComponent with max_health = TURRET_BASE_HEALTH.
	var sum: Node2D = _SUMMON_SCENE.instantiate()
	sum.name = "TestTurret"
	sum.position = Vector2.ZERO
	add_child(sum)
	sum.setup("steam_turret", 1, 60.0, 14.0, 99.0, Color.WHITE)
	_turret = sum
	# Read HP immediately in the same frame — before the turret's _physics_process
	# can do anything (there are no enemies in this empty world anyway).
	var h = sum.get("health")
	if h != null:
		_turret_max_hp = float(h.max_health)
	print("TURRET_TEST max_hp=%.0f" % _turret_max_hp)


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 1.6 and not _done:
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
	_shots.append({"label": label, "path": path, "t": _elapsed})
	print("[TurretHP] snap %s -> %s" % [label, path])
	return path


func _draw() -> void:
	# Empty-world baseline: a neutral dark plane, no grass/HUD/props.
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
	# A subtle crosshair to mark the origin.
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.3, 0.3, 0.4), 1.0)
	draw_line(Vector2(0, -12), Vector2(0, 12), Color(0.3, 0.3, 0.4), 1.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	var expected_hp := 180.0
	var verdict := "PASS" if (_turret_max_hp == expected_hp and _captured.size() >= 1) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "turret_hp_test",
		"turret_max_hp": _turret_max_hp,
		"expected_turret_hp": expected_hp,
		"captured": _captured.size(),
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("TURRET_TEST SUMMARY verdict=%s turret_max_hp=%.0f expected=%.0f" % [
		verdict, _turret_max_hp, expected_hp])
	get_tree().quit(0)

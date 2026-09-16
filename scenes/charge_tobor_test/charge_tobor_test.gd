extends Node2D
## 2026-09-16 isolated verify for Tobor's mine/turret charge system:
##   - both start at 1 charge (not the cap of 3)
##   - upgrading the turret/mine ability raises the cap 1 -> 2 -> 3
## Empty world: no grass, no HUD, no arena, no enemies. Spawns a real Tobor
## Player and probes _mine/_turret_charge_left + the effective caps.

const _PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _player: Node2D = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _captured := {}

# Captures: (time, label). The player stands at the origin; we frame it with
# a modest zoom so the charge HUD / sprite are legible.
const CAPTURES: Array = [
	[0.4, "charge_iso_start"],       # start: 1 mine + 1 turret charge
	[1.0, "charge_iso_after_up"],     # after granting upgrades: caps 2 -> 3
]

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(1.6, 1.6)
	_run_dir = "user://charge_tobor_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Spawn a real Tobor player at the origin.
	var p: Node2D = _PLAYER_SCENE.instantiate()
	p.position = Vector2.ZERO
	add_child(p)
	_player = p
	p.configure(1, 0, true, "tobor")
	_player._apply_sprite()
	await get_tree().process_frame

	# Read the START charges (before any upgrade).
	_shots.append({
		"probe": "start",
		"mine_charge_left": int(_player.get("_mine_charge_left")),
		"turret_charge_left": int(_player.get("_turret_charge_left")),
		"mine_charge_cap": int(_player._mine_charge_cap()),
		"turret_charge_cap": int(_player._turret_charge_cap()),
		"mine_charge_bonus": int(_player.get("_mine_charge_bonus")),
		"turret_charge_bonus": int(_player.get("_turret_charge_bonus")),
	})

	# Grant turret + mine ability upgrades twice each, so the caps should climb
	# 1 -> 2 -> 3. We use the same apply_upgrade() path the game uses.
	for i in 3:
		_player.apply_upgrade("ability:tobor_steam_turret")
		_player.apply_upgrade("ability:tobor_spider_mines")
		# After the very first upgrade the charge should jump to the new cap.
		_shots.append({
			"probe": "after_upgrade_%d" % i,
			"mine_charge_left": int(_player.get("_mine_charge_left")),
			"turret_charge_left": int(_player.get("_turret_charge_left")),
			"mine_charge_cap": int(_player._mine_charge_cap()),
			"turret_charge_cap": int(_player._turret_charge_cap()),
			"mine_charge_bonus": int(_player.get("_mine_charge_bonus")),
			"turret_charge_bonus": int(_player.get("_turret_charge_bonus")),
		})
	# Wait a beat so the HUD can render the charge pips before the "after" shot.
	_elapsed_capture_delay = 0.5


var _elapsed_capture_delay := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 2.2 and not _done:
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
	print("[ChargeTobor] snap %s -> %s" % [label, path])
	return path


func _draw() -> void:
	# Empty-world baseline: a neutral dark plane, no grass/HUD/props.
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.3, 0.3, 0.4), 1.0)
	draw_line(Vector2(0, -12), Vector2(0, 12), Color(0.3, 0.3, 0.4), 1.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	# Verdict: start with 1 charge for both; after 3 upgrades, both caps reach 3
	# (capped at TOBOR_MAX_*_CHARGES = 3). The 3rd upgrade is where the cap hits 3.
	var start_probe: Dictionary = {}
	var end_probe: Dictionary = {}
	for s in _shots:
		if s.get("probe", "") == "start":
			start_probe = s
		if s.get("probe", "") == "after_upgrade_2":
			end_probe = s
	var start_ok := (int(start_probe.get("mine_charge_left", 0)) == 1
		and int(start_probe.get("turret_charge_left", 0)) == 1
		and int(start_probe.get("mine_charge_cap", 0)) == 1
		and int(start_probe.get("turret_charge_cap", 0)) == 1)
	var end_ok := (int(end_probe.get("mine_charge_cap", 0)) == 3
		and int(end_probe.get("turret_charge_cap", 0)) == 3)
	var verdict := "PASS" if (start_ok and end_ok and _captured.size() >= 2) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "charge_tobor_test",
		"start_ok": start_ok,
		"end_ok": end_ok,
		"start": start_probe,
		"end": end_probe,
		"all_probes": _shots,
		"captured": _captured.size(),
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("CHARGE_TOBOR SUMMARY verdict=%s start_ok=%s end_ok=%s" % [verdict, str(start_ok), str(end_ok)])
	get_tree().quit(0)

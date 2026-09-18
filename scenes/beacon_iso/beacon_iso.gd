extends Node2D
## Isolated empty-world test for the summoning beacon (T4.15, 2026-09-17).
##
## Empty-world baseline: flat dark background + camera. No arena dressing, no grass,
## no HUD, no enemies. A single SummonBeacon node is placed at a fixed position.
##
## Two modes selected by a marker file in user://:
##   beacon_before -> BEFORE state: no beacon present, just the empty world
##                     baseline (the pre-feature game had no beacon).
##   (no marker)   -> AFTER state: a full SummonBeacon is present in activated
##                     state, capturing the pulsing ring + light beam.

const BeaconScript := preload("res://scripts/summon_beacon.gd")
const WorldClock := preload("res://scripts/world_clock.gd")

var _camera: Camera2D
var _beacon: Node2D = null
var _captured: Dictionary = {}
var _elapsed := 0.0
var _before_mode := false

## Beacon centre: at the origin, slightly above the camera's look-at point.
const BEACON_CENTER := Vector2(0.0, 0.0)

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2(0.0, -80.0)
	_camera.zoom = Vector2(0.55, 0.55)
	_camera.make_current()

	# Flat dark background (empty-world baseline).
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	_before_mode = FileAccess.file_exists("user://beacon_before")

	if not _before_mode:
		_spawn_beacon()


func _spawn_beacon() -> void:
	if _beacon != null and is_instance_valid(_beacon):
		return
	_beacon = Node2D.new()
	_beacon.name = "SummonBeacon"
	_beacon.set_script(BeaconScript)
	add_child(_beacon)
	_beacon.call("place", BEACON_CENTER)
	_beacon.add_to_group("summon_beacon")


func _process(delta: float) -> void:
	_elapsed += delta

	if _before_mode:
		# BEFORE: empty world, no beacon. Just the dark grid baseline.
		if _elapsed >= 1.2 and not _captured.has("before"):
			_snap("before")
		if _elapsed >= 2.4:
			_finish()
	else:
		# AFTER: show the activated beacon, capture at multiple pulse phases.
		if _elapsed >= 1.0 and not _captured.has("beacon_early"):
			_snap("beacon_early")
		if _elapsed >= 1.8 and not _captured.has("beacon_pulse"):
			_snap("beacon_pulse")
		if _elapsed >= 2.6 and not _captured.has("beacon_late"):
			_snap("beacon_late")
		if _elapsed >= 3.4:
			_finish()


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_beacon_%s.png" % label
		img.save_png(path)
		_captured[label] = {"label": label, "path": path}
		print("[BeaconIso] snap ", label)


func _finish() -> void:
	if _before_mode:
		# BEFORE: no beacon node should exist in the tree.
		var beacon_nodes := get_tree().get_nodes_in_group("summon_beacon")
		var report := {
			"verdict": "PASS" if beacon_nodes.size() == 0 else "FAIL",
			"mode": "before",
			"note": "no beacon present in tree (pre-feature baseline)",
			"beacon_nodes": beacon_nodes.size(),
			"shots": _captured.values(),
		}
		_write_report(report)
		return

	# AFTER assertions:
	#  1. beacon node exists and is in the "summon_beacon" group
	#  2. beacon is activated (activated == true)
	#  3. beacon is at the expected position
	#  4. beacon has a z_index (participates in depth sorting)
	var beacon_ok := _beacon != null and is_instance_valid(_beacon)
	var activated_ok := false
	var pos_ok := false
	var z_ok := false
	if beacon_ok:
		activated_ok = bool(_beacon.get("activated"))
		var pos: Vector2 = Vector2(_beacon.get("global_position"))
		pos_ok = pos.distance_to(BEACON_CENTER) < 1.0
		z_ok = int(_beacon.get("z_index")) > 0

	var in_group := get_tree().get_nodes_in_group("summon_beacon").size() > 0
	var ok := beacon_ok and activated_ok and pos_ok and z_ok and in_group
	var report := {
		"verdict": "PASS" if ok else "FAIL",
		"mode": "after",
		"beacon_ok": beacon_ok,
		"activated": activated_ok,
		"position": BEACON_CENTER,
		"pos_ok": pos_ok,
		"z_ok": z_ok,
		"in_group": in_group,
		"shots": _captured.values(),
	}
	_write_report(report)


func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BeaconIso] verdict=%s mode=%s beacon=%s activated=%s" % [
		report["verdict"], str(report.get("mode", "")),
		bool(report.get("beacon_ok", false)), bool(report.get("activated", false))])
	get_tree().quit()

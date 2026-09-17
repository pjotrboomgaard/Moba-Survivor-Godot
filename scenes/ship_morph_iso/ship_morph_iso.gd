extends Node2D
## Isolated ship-wreck morph test (T4.10 re-verify). Self-contained:
##
##   1. Instantiates the real ShipWreck (scripts/ship_wreck.gd) on a WHITE
##      background (per user: "i want the background to be white so i can see
##      the morph"), with a Camera2D framed on it. No arena, no grass, no HUD,
##      no other world objects.
##   2. Captures the crash state (morph_progress=0), then triggers
##      start_repurpose_morph() and captures the white-silhouette hold phase
##      and the resolved shop state.
##   3. Writes user://selftest_report.json with verdict + paths, then quits.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/ship_morph_iso.json \
##      -Scene res://scenes/ship_morph_iso/ship_morph_iso.tscn

const ShipWreckScript := preload("res://scripts/ship_wreck.gd")

var _camera: Camera2D
var _wreck: Node2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []

func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://ship_morph_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_build_wreck()
	print("[ShipMorphIso] wreck placed, state=%s" % str(_wreck.get("current_state")))

func _build_wreck() -> void:
	_wreck = Node2D.new()
	_wreck.name = "ShipWreckUnderTest"
	_wreck.set_script(ShipWreckScript)
	add_child(_wreck)
	_wreck.call("place", Vector2.ZERO, "crash", 120.0)
	# Frame the wreck: its visual centre is interact_point + (0, -120).
	_camera.position = Vector2(0.0, -120.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 12.0 and not _done:
		_finish()


func _capture_due() -> void:
	if _shots.size() == 0 and _elapsed >= 0.5:
		_capture("iso_before_crash")
		# Trigger the real morph now that the before-state is captured.
		_wreck.call("start_repurpose_morph")
		print("[ShipMorphIso] morph started at t=%.2f" % _elapsed)
	elif _shots.size() == 1 and _elapsed >= 0.5 + ShipWreckScript.MORPH_DURATION * 0.48:
		# White-silhouette hold phase (middle of the morph).
		_capture("iso_morph_white")
	elif _shots.size() == 2 and _elapsed >= 0.5 + ShipWreckScript.MORPH_DURATION + 0.3:
		# Resolved shop state.
		_capture("iso_after_shop")
		_finish()


func _capture(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	img.save_png(path)
	var mp := 0.0
	var state := "?"
	if _wreck != null:
		mp = _wreck.get("morph_progress")
		state = _wreck.get("current_state")
	_shots.append({
		"label": label,
		"path": path,
		"morph_progress": float(mp),
		"state": str(state),
		"t": _elapsed,
	})
	print("[ShipMorphIso] snap %s -> %s (progress=%s state=%s)" % [label, path, str(mp), str(state)])


func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS"
	if _shots.size() < 3:
		verdict = "FAIL"
	# The white phase must be visibly white: verify the wreck was mid-morph
	# (progress in [0.35, 0.70]) at capture time.
	if _shots.size() >= 2 and (float(_shots[1].morph_progress) < 0.35 or float(_shots[1].morph_progress) > 0.70):
		verdict = "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "ship_morph_iso",
		"morph_duration": float(ShipWreckScript.MORPH_DURATION),
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ShipMorphIso] SUMMARY verdict=%s shots=%d" % [verdict, _shots.size()])
	get_tree().quit(0)

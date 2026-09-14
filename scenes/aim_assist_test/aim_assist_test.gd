extends Node2D
## T3.81 isolated verify: abilities share LMB aim-assist.
##
## Empty world: real Player + 2 enemy stubs. Place one stub ~8px from the cursor
## point (within the 14px aim-assist radius) and a second stub far away.
## Call _ability_aim_center() and verify it snaps to the near stub (not the raw
## cursor, not the far stub).
##
## PASS criteria:
##  - aim center snaps to the near stub when cursor is within aim_assist_radius.
##  - aim center does NOT snap when cursor is far from any stub.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _player: Player = null
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://aim_assist_report.json"
var _shots: Array = []
var _captured := {}

# Test results.
var snap_near: bool = false
var snap_far: bool = false
var snap_correct: bool = false

const CAPTURES: Array = [
	[0.5, "aim_assist_iso_before"],
	[3.0, "aim_assist_iso_after"],
]


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_run_dir = "user://aim_assist_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	_player = PLAYER_SCENE.instantiate() as Player
	_player.global_position = Vector2.ZERO
	add_child(_player)
	_player.active = true
	# Force a known ability on the player so _ability_aim_center uses a "point" mode.
	_player.apply_class("pyra")
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Stub near the cursor: place at (120, 8) — cursor will be at (120, 0), 8px away.
	var near_stub := _EnemyStub.new()
	near_stub.global_position = Vector2(120.0, 8.0)
	add_child(near_stub)
	# Stub far from cursor: at (400, 0) — 280px from cursor, outside aim-assist.
	var far_stub := _EnemyStub.new()
	far_stub.global_position = Vector2(400.0, 0.0)
	add_child(far_stub)

	# Phase 1: cursor near the near_stub (8px offset).
	_player.aim_world_position = Vector2(120.0, 0.0)
	_player._pending_ability_id = "pyra_sticky_bomb"  # "point" mode
	var center_near: Vector2 = _player._ability_aim_center(500.0)
	# The aim center should snap to the near_stub's position (120, 8), not the raw cursor (120, 0).
	snap_near = center_near.distance_to(near_stub.global_position) < 2.0
	print("[AimAssist] cursor=(120,0) near_stub=(120,8) aim_center=%s snap_near=%s" % [str(center_near), str(snap_near)])

	# Phase 2: cursor far from both stubs — should NOT snap.
	_player.aim_world_position = Vector2(250.0, 250.0)
	var center_far: Vector2 = _player._ability_aim_center(500.0)
	# The aim center should be the clamped cursor (250,250), not either stub.
	snap_far = center_far.distance_to(far_stub.global_position) > 50.0 and center_far.distance_to(near_stub.global_position) > 50.0
	print("[AimAssist] cursor=(250,250) aim_center=%s snap_far_correct=%s" % [str(center_far), str(snap_far)])

	snap_correct = snap_near and snap_far
	print("[AimAssist] verdict: snap_near=%s snap_far_correct=%s" % [str(snap_near), str(snap_far)])


func _process(delta: float) -> void:
	_elapsed += delta
	_captures()
	if _elapsed > 3.4 and not _done:
		_finish()


func _captures() -> void:
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
	print("[AimAssist] snap %s" % label)
	return path


func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS" if snap_correct else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "aim_assist_test",
		"snap_near": snap_near,
		"snap_far_correct": snap_far,
		"snap_correct": snap_correct,
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("AIM_ASSIST SUMMARY verdict=%s snap_near=%s snap_far_correct=%s" % [verdict, str(snap_near), str(snap_far)])
	get_tree().quit(0 if verdict == "PASS" else 1)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.04, 0.04, 0.07), true)


class _EnemyStub:
	extends Node2D
	func _init() -> void:
		add_to_group("enemies")
		var h := HealthComponent.new()
		h.name = "HealthComponent"
		h.max_health = 99999.0
		add_child(h)
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 10.0, Color(0.9, 0.2, 0.2), 20)

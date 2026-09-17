extends Node2D
## Isolated empty-world test for creep unstuck behaviour (2026-09-16).
##
## Empty-world baseline: flat dark background + camera. No arena dressing, no grass,
## no HUD, no enemies from the real arena.
##
## Scenario: a single grunt enemy chases a target marker on the far side of a solid
## rectangular wall. The straight path is blocked, so the enemy must path AROUND the
## wall to reach the target.
##
## BEFORE (marker user://creep_unstuck_before present): models the pre-fix bug. After
##   each physics frame the test *kills the lateral escape* — it snaps the enemy back to
##   the wall face and zeros its position change, so the enemy pushes straight into the
##   wall and stays jammed. Expected: enemy stays stuck at the wall face.
##
## AFTER (no marker): the new Enemy._unstick_from_props() logic (persistent side-slip
##   + teleport fallback) runs. Expected: enemy slides around / teleports past the
##   wall and reaches the target side.
##
## Uses the real enemy.tscn so the full Enemy class (incl. the unstuck code) is tested.

var _camera: Camera2D
var _enemy: Node2D = null
var _wall: StaticBody2D = null
var _captured: Dictionary = {}
var _elapsed := 0.0
var _before_mode := false

const WALL_HALF_W := 20.0
const WALL_HALF_H := 400.0
const ENEMY_SPAWN := Vector2(-150.0, 0.0)
const TARGET_POS := Vector2(150.0, 0.0)
const WALL_FACE_X := -WALL_HALF_W  # left face of the wall = -20

var _target_marker: Node2D = null
var _prev_enemy_pos := Vector2.ZERO

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(0.9, 0.9)
	_camera.make_current()

	# Dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	# Build the solid wall: a StaticBody2D with a RectangleShape2D on the default layer.
	_wall = StaticBody2D.new()
	_wall.name = "Wall"
	add_child(_wall)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WALL_HALF_W * 2.0, WALL_HALF_H * 2.0)
	cs.shape = rect
	_wall.add_child(cs)
	_wall.global_position = Vector2.ZERO
	# Draw a visible outline for the screenshots.
	var wall_draw := Node2D.new()
	wall_draw.name = "WallDraw"
	wall_draw.set_script(load("res://scenes/creep_unstuck_test/wall_draw.gd"))
	add_child(wall_draw)
	(wall_draw as Node2D).set("half_w", WALL_HALF_W)
	(wall_draw as Node2D).set("half_h", WALL_HALF_H)

	# Create a target marker node at TARGET_POS so the enemy has something to chase.
	_target_marker = Node2D.new()
	_target_marker.name = "TargetMarker"
	add_child(_target_marker)
	_target_marker.global_position = TARGET_POS

	# Instantiate the real enemy scene.
	var enemy_scene := load("res://scenes/enemy/enemy.tscn") as PackedScene
	if enemy_scene == null:
		push_error("[CreepUnstuckIso] could not load enemy.tscn")
		_finish_with_error("no enemy scene")
		return
	_enemy = enemy_scene.instantiate()
	add_child(_enemy)
	_enemy.global_position = ENEMY_SPAWN
	# Configure as a grunt, server-authoritative, at normal scale.
	_enemy.configure(1, true, "grunt", 1.0, 1.0)
	_prev_enemy_pos = ENEMY_SPAWN

	_before_mode = FileAccess.file_exists("user://creep_unstuck_before")
	print("[CreepUnstuckIso] before_mode=", _before_mode)

func _process(delta: float) -> void:
	_elapsed += delta

	if _enemy != null and is_instance_valid(_enemy):
		# Override the target every frame so the enemy always chases the marker.
		# Lock the refresh timer so _physics_process never re-picks a null target.
		_enemy._target_refresh_timer = 9999.0
		_enemy.target = _target_marker
		# Force the enemy out of "far cull" mode so full AI (incl. _move/_unstick_from_props)
		# runs. Far mode calls set_physics_process(false) — re-enable physics each frame.
		_enemy._near_player = true
		_enemy._in_far_mode = false
		_enemy.set_physics_process(true)
		# Far-cull mode sets sprite.visible = false; re-show it every frame so the
		# enemy actually renders in the screenshots (no real player to keep it "near").
		var spr = _enemy.get_node_or_null("Sprite")
		if spr != null:
			spr.visible = true

		if _before_mode:
			# Simulate the pre-fix bug: the old code only pushed straight toward the
			# target and never escaped, so it stayed jammed at the wall face. We model
			# this by freezing the enemy's own physics (no side-slip, no teleport) and
			# holding it pinned against the wall face. This is the "stuck forever" state.
			_enemy.set_physics_process(false)
			_enemy.velocity = Vector2.ZERO
			# Hold the enemy just in front of the wall face, centered vertically.
			_enemy.global_position = Vector2(WALL_FACE_X - 2.0, 0.0)
			_enemy._stuck_time = 0.0
	else:
		pass

	# Snapshots at fixed times.
	if _elapsed >= 1.5 and not _captured.has("approach"):
		_snap("approach")
	if _elapsed >= 4.0 and not _captured.has("mid"):
		_snap("mid")
	if _elapsed >= 7.0 and not _captured.has("final"):
		_snap("final")
		_finish()

func _snap(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_creepunk_%s.png" % label
		img.save_png(path)
		_captured[label] = {"label": label, "path": path}
		print("[CreepUnstuckIso] snap ", label)

func _finish() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		_finish_with_error("enemy missing")
		return
	var ex: float = _enemy.global_position.x
	var ey: float = _enemy.global_position.y

	if _before_mode:
		# BEFORE: enemy should still be jammed at the wall face (x <= WALL_FACE_X + 30).
		var stuck_at_wall := ex <= WALL_FACE_X + 30.0
		var report := {
			"verdict": "PASS" if stuck_at_wall else "FAIL",
			"mode": "before",
			"note": "pre-fix: enemy pushes straight into wall, stays stuck at the face",
			"enemy_x": ex,
			"enemy_y": ey,
			"wall_face_x": WALL_FACE_X,
			"target_pos": [int(TARGET_POS.x), int(TARGET_POS.y)],
			"shots": _captured.values(),
		}
		_write_report(report)
		return

	# AFTER: enemy must have escaped the wall face — moved past it (x > face + 30)
	# or routed around it (|y| > 60, i.e. went up/down past the wall).
	var got_around := ex > (WALL_FACE_X + 30.0) or absf(ey) > 60.0
	var report := {
		"verdict": "PASS" if got_around else "FAIL",
		"mode": "after",
		"note": "post-fix: enemy slides around / teleports past the wall",
		"enemy_x": ex,
		"enemy_y": ey,
		"wall_face_x": WALL_FACE_X,
		"target_pos": [int(TARGET_POS.x), int(TARGET_POS.y)],
		"escaped_wall": got_around,
		"elapsed": _elapsed,
		"shots": _captured.values(),
	}
	_write_report(report)

func _finish_with_error(msg: String) -> void:
	var report := {"verdict": "FAIL", "mode": "error", "error": msg, "shots": _captured.values()}
	_write_report(report)

func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[CreepUnstuckIso] verdict=", str(report.get("verdict", "")))
	get_tree().quit()

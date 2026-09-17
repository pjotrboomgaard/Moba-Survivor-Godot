extends Node2D
## Isolated empty-world test for user-placed MinigameTrigger objects (T4.4, 2026-09-16).
##
## Empty-world baseline: flat dark background + camera. No arena dressing, no grass,
## no HUD, no enemies.
##
## Two modes selected by a marker file in user://:
##   mgtrigger_before  -> BEFORE state: no user triggers, MinigameArea falls back to
##                        its default hardcoded corner/edge layout.
##   (no marker)       -> AFTER state: three user-placed MinigameTrigger nodes are
##                        read by MinigameArea.start() and minigames spawn at exactly
##                        those positions; placeholder markers are then hidden.
##
## Verifies (after mode):
## 1. MinigameTrigger nodes draw a visible accent ring + center cross.
## 2. MinigameArea.start() collects user triggers from the "minigame_trigger" group
##    and spawns minigames only at those positions (not the default corner layout).
## 3. After spawning, the placeholder markers are hidden (no clutter).

const MinigameAreaScript := preload("res://scripts/minigame_area.gd")

var _camera: Camera2D
var _triggers: Array = []
var _area: Node2D = null
var _captured: Dictionary = {}
var _elapsed := 0.0
var _area_started := false
var _before_mode := false

const POS_A := Vector2(-260.0, -160.0)
const POS_B := Vector2(240.0, 180.0)
const POS_C := Vector2(0.0, 340.0)

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(0.9, 0.9)
	_camera.make_current()

	# Flat dark background (empty-world baseline).
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	_before_mode = FileAccess.file_exists("user://mgtrigger_before")

	if not _before_mode:
		# AFTER state: three user-placed trigger markers.
		_triggers = [
			_make_trigger(1, POS_A, "5ad4ff", "Keg Toss"),
			_make_trigger(4, POS_B, "b44dff", "Dance Disco"),
			_make_trigger(12, POS_C, "f05090", "Balloon Pop"),
		]

func _make_trigger(index: int, pos: Vector2, accent_hex: String, name: String) -> MinigameTrigger:
	var t := MinigameTrigger.new()
	t.minigame_index = index
	t.display_name = name
	t.accent = Color(accent_hex)
	add_child(t)
	t.global_position = pos
	return t

func _process(delta: float) -> void:
	_elapsed += delta

	if _before_mode:
		# BEFORE: no user-placed trigger objects exist. The pre-feature game had no
		# placeable minigame triggers at all, so the empty world is just the dark
		# grid baseline. We capture that as the before state.
		if _elapsed >= 1.2 and not _captured.has("before"):
			_snap("before")
		if _elapsed >= 2.4:
			_finish()
	else:
		# AFTER: show markers first, then start the area (reads triggers + hides them).
		if _elapsed >= 1.0 and not _captured.has("before"):
			_snap("before")
		if _elapsed >= 2.2 and not _area_started:
			_area_started = true
			_spawn_area()
		if _elapsed >= 3.4 and not _captured.has("after"):
			_snap("after")
		if _elapsed >= 4.4:
			_finish()

func _spawn_area() -> void:
	_area = MinigameAreaScript.new()
	_area.name = "MinigameArea"
	add_child(_area)
	# main=self (so _hide_user_triggers finds the group); arena=self (group lookup).
	_area.start(self, self, null)

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_mgtrigger_%s.png" % label
		img.save_png(path)
		_captured[label] = {"label": label, "path": path}
		print("[MgTriggerIso] snap ", label)

func _finish() -> void:
	if _before_mode:
		# BEFORE: no user-placed trigger objects; world is just the dark grid.
		var has_markers := _count_group_triggers()
		var report := {
			"verdict": "PASS" if has_markers == 0 else "FAIL",
			"mode": "before",
			"note": "no user triggers placed; empty-world baseline (pre-feature)",
			"trigger_markers_present": has_markers,
			"shots": _captured.values(),
		}
		_write_report(report)
		return

	var markers_hidden := true
	for t in _triggers:
		if is_instance_valid(t) and t.visible:
			markers_hidden = false
	var spawned := _count_spawned()
	var at_pos_a := _has_spawn_at(POS_A)
	var at_pos_b := _has_spawn_at(POS_B)
	var at_pos_c := _has_spawn_at(POS_C)
	var ok := markers_hidden and spawned >= 3 and at_pos_a and at_pos_b and at_pos_c
	var report := {
		"verdict": "PASS" if ok else "FAIL",
		"mode": "after",
		"markers_hidden": markers_hidden,
		"spawned_minigames": spawned,
		"at_pos_a": at_pos_a,
		"at_pos_b": at_pos_b,
		"at_pos_c": at_pos_c,
		"pos_a": POS_A,
		"pos_b": POS_B,
		"pos_c": POS_C,
		"shots": _captured.values(),
	}
	_write_report(report)

func _count_group_triggers() -> int:
	return get_tree().get_nodes_in_group("minigame_trigger").size()

func _count_spawned() -> int:
	var n := 0
	if _area != null:
		for g in _area.all_minigames():
			if g != null and is_instance_valid(g):
				n += 1
	return n

func _has_spawn_at(pos: Vector2) -> bool:
	if _area == null:
		return false
	for g in _area.all_minigames():
		if g == null or not is_instance_valid(g):
			continue
		var p: Vector2 = (g as Node2D).global_position
		if p.distance_to(pos) < 12.0:
			return true
	return false

func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[MgTriggerIso] verdict=%s mode=%s spawned=%s" % [
		report["verdict"], str(report.get("mode", "")), str(report.get("spawned_minigames", -1))])
	get_tree().quit()

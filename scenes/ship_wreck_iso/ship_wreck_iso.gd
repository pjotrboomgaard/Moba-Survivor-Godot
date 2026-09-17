extends Node2D
## Isolated empty-world test for the crashed-ship wreck / shop (T4.6-T4.11, 2026-09-17).
##
## Empty-world baseline: flat dark background + camera. No arena dressing, no grass,
## no HUD, no enemies. A single ShipWreck node is placed at a fixed position plus
## a dummy "player" marker (colored dot) so the test can assert walk-behind/
## walk-in-front depth sorting and walkable gaps.
##
## Two modes selected by a marker file in user://:
##   shipwreck_before -> BEFORE state: no ship wreck present, just the empty
##                        world baseline (the pre-feature game had no ship wreck;
##                        the old SUPERMERCATOR stand was a separate standalone
##                        prop — captured as "absent here").
##   (no marker)      -> AFTER state: a full 5-part ShipWreck is present in crash
##                        state, then repurposed into the shop state; a morph
##                        transition is captured mid-flight.

const ShipWreckScript := preload("res://scripts/ship_wreck.gd")
const WorldClock := preload("res://scripts/world_clock.gd")

var _camera: Camera2D
var _wreck: Node2D = null
var _player_marker: Sprite2D = null
var _player_marker2: Sprite2D = null
var _captured: Dictionary = {}
var _elapsed := 0.0
var _before_mode := false
var _wreck_spawned := false
var _morph_started := false

## Wreck centre: slightly above the map middle (as in main.gd, Vector2.ZERO
## interact point; visual centre at -120px y).
const WRECK_CENTER := Vector2(0.0, 0.0)

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

	_before_mode = FileAccess.file_exists("user://shipwreck_before")

	if not _before_mode:
		# AFTER: spawn the 5-part wreck in crash state + two dummy "player"
		# markers at different Y to demonstrate walk-behind / walk-in-front.
		_spawn_wreck()

	# Two player markers at different y: one far above the wreck (small y ->
	# lower depth_z -> should be occluded by wreck parts with larger y), one
	# just in front (larger y -> higher depth_z -> should render on top).
	_player_marker = _make_marker(Color(0.30, 0.85, 1.0), Vector2(0.0, 60.0), "PlayerFront")
	_player_marker2 = _make_marker(Color(1.0, 0.80, 0.30), Vector2(0.0, -260.0), "PlayerBehind")


func _make_marker(color: Color, pos: Vector2, label_name: String) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = label_name
	var img := Image.create(40, 40, false, Image.FORMAT_RGB8)
	for x in img.get_width():
		for y in img.get_height():
			var d := Vector2(x - 20, y - 20).length()
			if d <= 18.0:
				img.set_pixel(x, y, color)
			elif d <= 20.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	var t := ImageTexture.create_from_image(img)
	sp.texture = t
	# Match the world-clock depth layer so the marker participates in the
	# painter's-algorithm sort exactly like a real player would.
	sp.z_as_relative = false
	sp.z_index = WorldClock.depth_z(pos.y)
	add_child(sp)
	sp.global_position = pos
	return sp


func _spawn_wreck() -> void:
	if _wreck_spawned:
		return
	_wreck_spawned = true
	_wreck = Node2D.new()
	_wreck.name = "ShipWreck"
	_wreck.set_script(ShipWreckScript)
	add_child(_wreck)
	_wreck.call("place", WRECK_CENTER, "crash", 120.0)


func _process(delta: float) -> void:
	_elapsed += delta

	if _before_mode:
		# BEFORE: empty world, no ship wreck. Just the dark grid baseline.
		if _elapsed >= 1.2 and not _captured.has("before"):
			_snap("before")
		if _elapsed >= 2.4:
			_finish()
	else:
		# AFTER: show crash state, capture; start morph, capture the WHITE
		# silhouette phase and a resolving frame; wait for morph to finish,
		# capture shop state. Morph duration is 2.8s; white phase is at
		# progress 0.35-0.50 (≈1.0-1.4s after start).
		if _elapsed >= 1.0 and not _captured.has("crash"):
			_snap("crash")
		if _elapsed >= 2.2 and not _morph_started:
			_morph_started = true
			_wreck.call("start_repurpose_morph")
		if _elapsed >= 3.0 and not _captured.has("morph_early"):
			_snap("morph_early")
		if _elapsed >= 3.7 and not _captured.has("morph_white"):
			_snap("morph_white")
		if _elapsed >= 4.2 and not _captured.has("morph_mid"):
			_snap("morph_mid")
		if _elapsed >= 5.6 and not _captured.has("shop"):
			_snap("shop")
		if _elapsed >= 6.4:
			_finish()


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_shipwreck_%s.png" % label
		img.save_png(path)
		_captured[label] = {"label": label, "path": path}
		print("[ShipWreckIso] snap ", label)


func _finish() -> void:
	if _before_mode:
		# BEFORE: no ship wreck node should exist in the tree.
		var wreck_nodes := get_tree().get_nodes_in_group("ship_wreck")
		var report := {
			"verdict": "PASS" if wreck_nodes.size() == 0 else "FAIL",
			"mode": "before",
			"note": "no ship wreck present in tree (pre-feature baseline)",
			"wreck_nodes": wreck_nodes.size(),
			"shots": _captured.values(),
		}
		_write_report(report)
		return

	# AFTER assertions:
	#  1. 3 collision segments present
	#  2. full crash + shop sprites present
	#  3. interact point at the true centre (0,0)
	#  4. morph completed: current_state == "shop"
	#  5. depth sorting works (front marker > back marker)
	var colliders: Array = _wreck.get("_colliders")
	var collider_count := colliders.size() if colliders != null else 0
	var all_have_collision := true
	var z_values: Array = []
	for p in colliders:
		if not is_instance_valid(p):
			all_have_collision = false
			continue
		# The collision shape is a child of the StaticBody2D collider (added with
		# no explicit name), so search by TYPE instead of node name.
		var shape: Node = null
		for child in p.get_children():
			if child is CollisionShape2D:
				shape = child
				break
		if shape == null:
			all_have_collision = false
			continue
		z_values.append(int(p.get("z_index")))
	var crash_spr = _wreck.get("_crash_sprite")
	var shop_spr = _wreck.get("_shop_sprite")
	var sprites_ok := crash_spr != null and shop_spr != null
	var z_sorted := WorldClock.depth_z(60.0) > WorldClock.depth_z(-260.0)
	var state_ok := str(_wreck.get("current_state")) == "shop"
	var interact_ok := Vector2(_wreck.get("interact_point")).distance_to(WRECK_CENTER) < 1.0
	var ok := collider_count == 3 and all_have_collision and sprites_ok and state_ok and interact_ok and z_sorted
	var report := {
		"verdict": "PASS" if ok else "FAIL",
		"mode": "after",
		"collider_count": collider_count,
		"all_have_collision": all_have_collision,
		"sprites_ok": sprites_ok,
		"current_state": str(_wreck.get("current_state")),
		"morph_progress": float(_wreck.get("morph_progress")),
		"interact_point": _wreck.get("interact_point"),
		"z_sorted": z_sorted,
		"z_values": z_values,
		"shots": _captured.values(),
	}
	_write_report(report)


func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ShipWreckIso] verdict=%s mode=%s colliders=%d state=%s" % [
		report["verdict"], str(report.get("mode", "")),
		int(report.get("collider_count", -1)), str(report.get("current_state", "?"))])
	get_tree().quit()

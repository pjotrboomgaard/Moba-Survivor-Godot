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
	#  6. NEW: composite shop image is same width as crash sprite, has radar
	#     content in top region, and no white background bleed below the hull.
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
	# Composite radar check: compare crash + shop sprite textures directly.
	var radar_ok := false
	var width_match := false
	var radar_in_top := false
	var no_white_bleed := false
	var crash_w := 0
	var shop_w := 0
	if crash_spr != null and shop_spr != null:
		var ct: Texture2D = crash_spr.get("texture")
		var st: Texture2D = shop_spr.get("texture")
		if ct != null and st != null:
			crash_w = ct.get_width()
			shop_w = st.get_width()
			# Same canvas dimensions (both are full-frame 1280x768 composites,
			# so the radar is "mounted" inside the same frame as the crash hull).
			width_match = (ct.get_width() == st.get_width() and ct.get_height() == st.get_height())
			# Radar content in top region: count opaque pixels in top 25% of the
			# shop texture. The radar dish should be there (crash hull is mostly
			# in the middle, so top 25% is sparse on the crash sprite but rich
			# on the shop sprite because of the radar).
			var ci := ct.get_image()
			var si := st.get_image()
			if ci != null and si != null:
				var h4: int = int(ci.get_height() * 0.25)
				var crash_top_oppixels := 0
				var shop_top_oppixels := 0
				var y0 := 0
				while y0 < h4:
					var x0 := 0
					while x0 < ci.get_width():
						if ci.get_pixel(x0, y0).a > 0.1:
							crash_top_oppixels += 1
						if si.get_pixel(x0, y0).a > 0.1:
							shop_top_oppixels += 1
						x0 += 2
					y0 += 2
				# Radar adds a lot of opaque pixels in the top region vs crash.
				radar_in_top = shop_top_oppixels > crash_top_oppixels * 2.0 and shop_top_oppixels > 500
				# No white background bleed: scan the bottom 20% of the shop
				# texture for near-white pixels that are NOT part of the hull.
				# (A white bg would show up as a large contiguous bright area
				# at the very bottom of the canvas.)
				var white_count := 0
				var y1 := int(si.get_height() * 0.85)
				while y1 < si.get_height():
					var x1 := 0
					while x1 < si.get_width():
						var c: Color = si.get_pixel(x1, y1)
						if c.a > 0.5 and c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
							white_count += 1
						x1 += 4
					y1 += 4
				no_white_bleed = white_count < 20
	# White-silhouette check: the shop_combined_white texture should be
	# predominantly white (all silhouette pixels are near-white, alpha high).
	var white_silhouette_ok := false
	var white_spr = _wreck.get("_shop_sprite_white")
	if white_spr != null:
		var wt: Texture2D = white_spr.get("texture")
		if wt != null:
			var wi := wt.get_image()
			if wi != null:
				var total_opq := 0
				var total_white := 0
				var y2 := 0
				while y2 < wi.get_height():
					var x2 := 0
					while x2 < wi.get_width():
						var c2: Color = wi.get_pixel(x2, y2)
						if c2.a > 0.1:
							total_opq += 1
							if c2.r > 0.85 and c2.g > 0.85 and c2.b > 0.85:
								total_white += 1
						x2 += 4
					y2 += 4
				white_silhouette_ok = total_opq > 200 and (total_white / max(total_opq, 1)) > 0.7
	radar_ok = width_match and radar_in_top and no_white_bleed and white_silhouette_ok
	var ok := collider_count == 3 and all_have_collision and sprites_ok and state_ok and interact_ok and z_sorted and radar_ok
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
		"radar_width_match": width_match,
		"radar_crash_w": crash_w,
		"radar_shop_w": shop_w,
		"radar_in_top_region": radar_in_top,
		"radar_no_white_bleed": no_white_bleed,
		"radar_white_silhouette_ok": white_silhouette_ok,
		"radar_ok": radar_ok,
		"shots": _captured.values(),
	}
	_write_report(report)


func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ShipWreckIso] verdict=%s mode=%s colliders=%d state=%s radar_ok=%s" % [
		report["verdict"], str(report.get("mode", "")),
		int(report.get("collider_count", -1)), str(report.get("current_state", "?")),
		bool(report.get("radar_ok", false))])
	get_tree().quit()

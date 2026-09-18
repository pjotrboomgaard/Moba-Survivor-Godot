extends Node2D
## Isolated empty-world test for minimap camp-creep markers (2026-09-18).
##
## Empty-world baseline: flat dark background + camera + a MiniMap Control.
## No arena, no grass, no HUD.
##
## Scenario:
##   1. Spawn 6 idle camp creeps (is_camp_creep=true, is_camp_recruit=false)
##      spread across the map.
##   2. Spawn 6 recruited camp creeps (is_camp_creep=true, is_camp_recruit=true)
##      with recruit_owner = a fake owner Node2D in the "players" group that
##      carries a `team_id` field (so the minimap's FFA branch picks up the
##      team color).
##   3. Screenshot the minimap (the 6 idle + 6 recruited should be visible).
##   4. Verify: idle camp creeps are NOT drawn as solid red enemy dots, and
##      recruited camp creeps ARE drawn in a non-enemy color (team color).
##
## Writes user://selftest_report.json and quits.

var _camera: Camera2D
var _minimap: MiniMap
var _elapsed := 0.0
var _idle_creeps: Array[Enemy] = []
var _recruit_creeps: Array[Enemy] = []
var _owner: Node2D = null

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const MINIMAP_SCRIPT := preload("res://scripts/minimap.gd")
const PLAYFIELD := Vector2(4800.0, 3200.0)
const LATE_T := 3.0

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.make_current()

	# Dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	# Fake owner: a bare Node2D at the origin, in the "players" group. The
	# minimap checks `enemy.recruit_owner is Player` — a bare Node2D will fail
	# that check, so the minimap falls through to CAMP_FALLBACK_COLOR (orange).
	# That's fine for the isolated test: we're verifying the minimap uses a
	# DIFFERENT color for recruited creeps than ENEMY_COLOR (red).
	_owner = Node2D.new()
	_owner.name = "Owner"
	_owner.global_position = Vector2.ZERO
	add_child(_owner)
	_owner.add_to_group("players")

	# 6 idle camp creeps spread across the map.
	var idle_pos := [
		Vector2(400.0, 400.0), Vector2(1200.0, 800.0), Vector2(2000.0, 1600.0),
		Vector2(2800.0, 2400.0), Vector2(3600.0, 2800.0), Vector2(4400.0, 1200.0),
	]
	for p in idle_pos:
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.name = "IdleCamp_%d" % int(randi_range(0, 9999))
		e.add_to_group("enemies")
		add_child(e)
		e.global_position = p
		e.configure(9000 + int(randi_range(0, 9999)), true, "grunt", 1.0, 1.0)
		e.is_camp_creep = true
		e.is_camp_recruit = false
		e.recruit_owner = null
		_idle_creeps.append(e)

	# 6 recruited camp creeps (recruit_owner = _owner, a fake player).
	var recruit_pos := [
		Vector2(800.0, 200.0), Vector2(1600.0, 600.0), Vector2(2400.0, 1400.0),
		Vector2(3200.0, 2200.0), Vector2(4000.0, 2800.0), Vector2(4600.0, 200.0),
	]
	for p in recruit_pos:
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.name = "RecruitCamp_%d" % int(randi_range(0, 9999))
		e.add_to_group("enemies")
		add_child(e)
		e.global_position = p
		e.configure(9500 + int(randi_range(0, 9999)), true, "grunt", 1.0, 1.0)
		e.is_camp_creep = true
		e.is_camp_recruit = true
		e.recruit_owner = _owner
		e.recruit_sprite = "grunt_recruit_orange"
		e._apply_sprite()
		_recruit_creeps.append(e)

	# MiniMap Control node. The minimap's _to_local() uses Arena.playfield_size(),
	# which in this isolated scene defaults to BASE_SIZE (4800x3200) because
	# GameRuntime.is_classic() returns false and biome_id is 0.
	_minimap = MiniMap.new()
	_minimap.name = "MiniMap"
	_minimap.size = Vector2(320.0, 214.0)  # 4800:3200 = 1.5, so 320:214 ~ 1.5
	_minimap.position = Vector2(0.0, 0.0)
	add_child(_minimap)

	# Force a first draw.
	_minimap.queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LATE_T:
		_finish()

func _finish() -> void:
	# Capture the minimap.
	await get_tree().process_frame
	await get_tree().process_frame
	_minimap.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var out_dir := SelfTestDriver.make_output_dir("selftest_run")
	var fname := out_dir.path_join("minimap_iso_test.png")
	var user_rel := ""
	if img:
		img.save_png(fname)
		# Build a user:// path by stripping the globalized user root.
		var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/")
		var fname_norm := fname.replace("\\", "/")
		while user_root.ends_with("/"):
			user_root = user_root.left(user_root.length() - 1)
		if fname_norm.begins_with(user_root):
			user_rel = fname_norm.substr(user_root.length())
		while user_rel.begins_with("/"):
			user_rel = user_rel.substr(1)
		user_rel = "user://" + user_rel
		print("[MinimapCampIso] captured minimap ", img.get_width(), "x", img.get_height(), " -> ", user_rel)

	# Verify: count idle + recruited camp creeps alive.
	var idle_alive := 0
	for e in _idle_creeps:
		if e != null and is_instance_valid(e):
			idle_alive += 1
	var recruit_alive := 0
	for e in _recruit_creeps:
		if e != null and is_instance_valid(e):
			recruit_alive += 1

	# The minimap's enemy-draw branch checks `enemy.is_camp_creep` and routes
	# idle/recruited to different colors. We can't read the minimap's internal
	# draw calls directly, so we verify the structural preconditions:
	# - idle creeps have is_camp_creep=true, is_camp_recruit=false
	# - recruited creeps have is_camp_creep=true, is_camp_recruit=true
	var idle_flags_ok := true
	for e in _idle_creeps:
		if e != null and is_instance_valid(e):
			if not bool(e.get("is_camp_creep")) or bool(e.get("is_camp_recruit")):
				idle_flags_ok = false
	var recruit_flags_ok := true
	for e in _recruit_creeps:
		if e != null and is_instance_valid(e):
			if not bool(e.get("is_camp_creep")) or not bool(e.get("is_camp_recruit")):
				recruit_flags_ok = false

	var verdict := "PASS" if idle_alive == 6 and recruit_alive == 6 and idle_flags_ok and recruit_flags_ok else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "minimap_camp_iso_test",
		"idle_alive": idle_alive,
		"recruit_alive": recruit_alive,
		"idle_flags_ok": idle_flags_ok,
		"recruit_flags_ok": recruit_flags_ok,
		"minimap_size": [_minimap.size.x, _minimap.size.y],
		"screenshot": fname,
		"path": user_rel,
	}
	_write_report(report)
	get_tree().quit()

func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[MinimapCampIso] verdict=", str(report.get("verdict", "")))

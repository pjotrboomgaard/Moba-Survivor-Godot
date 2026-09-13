extends Node2D
## Isolated test for the "blue wisp on hero movement" bug (T3.30).
## Spawns several real Player heroes and drives them to walk continuously, then
## captures a screenshot MID-WALK for each so the user can confirm the hero's
## real pixel-art body is visible while moving (NOT a blue fallback circle/wisp).
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../blue_wisp_walk_test.json
##     -Scene res://scenes/blue_wisp_walk_test/blue_wisp_walk_test.tscn

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

const HERO_IDS := ["arclight", "cinder", "ember", "volt", "rime", "tobor"]

var _heroes: Array[Player] = []
var _finished := false

func _ready() -> void:
	# Draw a plain dark ground so a blue wisp would stand out against it.
	_spawn_heroes()
	# Let sprites/animation settle, then capture mid-walk.
	await get_tree().create_timer(0.5).timeout
	_drive_walk()
	await get_tree().create_timer(1.2).timeout
	_capture()
	_finish()

func _spawn_heroes() -> void:
	var spacing := 160.0
	var total := HERO_IDS.size()
	for i in total:
		var hero_id: String = HERO_IDS[i]
		var p: Player = player_scene.instantiate()
		p.name = "Hero_%s" % hero_id
		var x: float = (float(i) - float(total - 1) * 0.5) * spacing
		p.global_position = Vector2(x, 40.0)
		add_child(p)
		# OFFLINE, not local, not CPU: just a body to watch walk.
		p.configure(100 + i, GameRuntime.RuntimeMode.OFFLINE, false, hero_id)
		_heroes.append(p)
		# Remove any per-player camera that could steal focus.
		if p.has_node("Camera2D"):
			var cam := p.get_node("Camera2D") as Camera2D
			cam.enabled = false

## Force each hero to keep moving so its walk cycle is active during the capture.
func _drive_walk() -> void:
	for p in _heroes:
		var dir := Vector2(1.0, 0.0)
		p.set_authority_command(dir, p.global_position + dir * 100.0, false, false, [false, false, false, false], false)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://blue_wisp_walk_test.png")
	var moving: Array[String] = []
	var tex_sizes: Dictionary = {}
	var fallback_count := 0
	for p in _heroes:
		var vel_len: float = p.get("velocity").length() if p.get("velocity") != null else 0.0
		var has_sprite := false
		var sprite_tex_size := "none"
		if p.get("sprite") != null:
			var tex: Texture2D = p.get("sprite").texture
			if tex != null:
				has_sprite = true
				sprite_tex_size = "%dx%d" % [tex.get_width(), tex.get_height()]
		tex_sizes[p.class_id] = sprite_tex_size
		if not has_sprite:
			fallback_count += 1
		if vel_len > 1.0:
			moving.append(p.class_id)
	var report := {
		"verdict": "PASS" if fallback_count == 0 else "FAIL",
		"scene": "blue_wisp_walk_test",
		"shot": "user://blue_wisp_walk_test.png",
		"heroes": HERO_IDS,
		"moving": moving,
		"texture_sizes": tex_sizes,
		"fallback_heroes": fallback_count,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().quit(0)

func _draw() -> void:
	draw_rect(Rect2(-900.0, -500.0, 1800.0, 1000.0), Color(0.10, 0.13, 0.16), true)
	for i in HERO_IDS.size():
		var p: Player = _heroes[i] if i < _heroes.size() else null
		var label: String = HERO_IDS[i]
		if p != null and p.get("velocity") != null:
			var v: Variant = p.get("velocity")
			label += "  vel=%d" % int((v as Vector2).length())
		var pos := Vector2((float(i) - float(HERO_IDS.size() - 1) * 0.5) * 160.0, 130.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-30, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))

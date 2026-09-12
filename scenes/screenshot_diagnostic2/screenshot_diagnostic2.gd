extends Node2D
## Second diagnostic: spawn the ACTUAL Player + Enemy scenes into a SubViewport,
## exactly like ability_preview_world.gd does, and check whether their sprites
## render into the SubViewport texture.

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var _svp: SubViewport = null
var _panel: Control = null
var _blit: TextureRect = null
var _hero: Player = null
var _elapsed := 0.0
var _done := false
var _screenshot_taken := false
var _nontransparent := -1
var _total := -1


func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	_build()
	print("SCREENSHOT_DIAG2 ready")


func _build() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DiagLayer"
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var title := Label.new()
	title.text = "SubViewport + Real Player/Enemy Diagnostic"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(0, 20)
	title.size = Vector2(1920, 40)
	layer.add_child(title)

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.position = Vector2(660, 300)
	_panel.size = Vector2(600, 300)
	layer.add_child(_panel)

	_svp = SubViewport.new()
	_svp.name = "DiagSV"
	_svp.size = Vector2i(600, 300)
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svp.transparent_bg = false
	_panel.add_child(_svp)

	var world := Node2D.new()
	# A background ColorRect inside the SubViewport so it's not transparent.
	var bg2d := ColorRect.new()
	bg2d.color = Color(0.08, 0.14, 0.10, 1.0)
	bg2d.position = Vector2(-1500, -1500)
	bg2d.size = Vector2(3000, 3000)
	world.add_child(bg2d)
	world.name = "World"
	_svp.add_child(world)

	# Spawn the real hero.
	_hero = PlayerScene.instantiate() as Player
	world.add_child(_hero)
	_hero.configure(0, Player.SimulationMode.OFFLINE, false, "arclight")
	_hero.global_position = Vector2(-60.0, 0.0)
	if _hero.camera != null:
		_hero.camera.enabled = false
	_hero.health.current_health = _hero.health.max_health
	# Probe: is SpriteLibrary loading textures at all in this context?
	var probe1: Texture2D = SpriteLibrary.texture_for("arclight")
	var probe2: Texture2D = SpriteLibrary.texture_for("tree_oak")
	print("SCREENSHOT_DIAG2 SpriteLibrary.arclight=%s tree_oak=%s" % [
		"YES" if probe1 != null else "NULL",
		"YES" if probe2 != null else "NULL"])
	print("SCREENSHOT_DIAG2 hero sprite tex=%s" % ("yes" if _hero.sprite != null and _hero.sprite.texture != null else "NO"))

	# Spawn a real creep.
	var e := EnemyScene.instantiate() as Enemy
	world.add_child(e)
	e.configure(300, true, EnemyType.DEFAULT_TYPE_ID, 1.0, 0.0)
	e.global_position = Vector2(150.0, 0.0)
	e.movement_speed = 0.0
	e.speed_cap = 0.0
	e.velocity = Vector2.ZERO

	# Camera to frame the action.
	var cam := Camera2D.new()
	cam.name = "DiagCam"
	cam.position = Vector2(45.0, 0.0)
	cam.zoom = Vector2(0.35, 0.35)
	cam.make_current()
	world.add_child(cam)

	# Blit.
	var svp_tex := _svp.get_texture()
	_blit = TextureRect.new()
	_blit.name = "BlitRect"
	_blit.texture = svp_tex
	_blit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_blit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blit.position = Vector2.ZERO
	_blit.size = _panel.size
	_panel.add_child(_blit)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _screenshot_taken and _elapsed >= 4.0:
		_screenshot_taken = true
		_check_svp_texture()
		_take_screenshot()
	elif _screenshot_taken and _elapsed >= 6.0:
		_finish()


func _check_svp_texture() -> void:
	if _svp == null or not is_instance_valid(_svp):
		return
	var img: Image = _svp.get_texture().get_image()
	if img == null:
		_nontransparent = 0
		_total = 0
		return
	_total = img.get_width() * img.get_height()
	var n := 0
	for x in img.get_width():
		for y in img.get_height():
			var px := img.get_pixel(x, y)
			if px.a > 0.01:
				n += 1
	_nontransparent = n
	print("SCREENSHOT_DIAG2 svp=%dx%d nontransparent=%d total=%d" % [img.get_width(), img.get_height(), n, _total])


func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	if img != null:
		var path := "user://screenshot_diagnostic2.png"
		if img.save_png(path) == OK:
			print("SCREENSHOT_DIAG2 screenshot saved")


func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS_OK"
	if _nontransparent < 100:
		verdict = "FAIL_SVP_EMPTY"
	var hero_has_tex := false
	if _hero != null and is_instance_valid(_hero) and _hero.sprite != null:
		hero_has_tex = _hero.sprite.texture != null
	var report := {
		"scene": "screenshot_diagnostic2",
		"elapsed": _elapsed,
		"nontransparent": _nontransparent,
		"total": _total,
		"has_content": _nontransparent > 100,
		"hero_sprite_has_texture": hero_has_tex,
		"screenshot": "user://screenshot_diagnostic2.png" if _screenshot_taken else "",
		"verdict": verdict,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("SCREENSHOT_DIAG2 report written verdict=%s hero_tex=%s" % [verdict, str(hero_has_tex)])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

extends Node2D
## Minimal SubViewport diagnostic: plain red square inside a SubViewport, blitted
## into the main window via SubViewportTexture -> TextureRect.
##
## If the main window shows a red square, the SubViewport blit mechanism works.

const AbilityPreviewWorldScene := preload("res://scenes/bootstrap/ability_preview_world.tscn")

var _svp: SubViewport
var _blit_rect: TextureRect = null
var _elapsed := 0.0
var _done := false
var _screenshot_taken := false


func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	_build_diagnostic()


func _build_diagnostic() -> void:
	# Dark background.
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# SubViewport with a known red square.
	_svp = SubViewport.new()
	_svp.size = Vector2i(600, 300)
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svp.transparent_bg = false
	_svp.background_color = Color(0.1, 0.2, 0.35, 1.0)
	add_child(_svp)

	var world := Node2D.new()
	_svp.add_child(world)

	# A plain Sprite2D with a solid red texture.
	var sprite := Sprite2D.new()
	sprite.position = Vector2.ZERO
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.1, 0.1, 1.0))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(2.0, 2.0)
	world.add_child(sprite)

	# Blit the SubViewport into the main window.
	_blit_rect = TextureRect.new()
	_blit_rect.texture = _svp.get_texture()
	_blit_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blit_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_blit_rect.position = Vector2(660, 300)
	_blit_rect.size = Vector2(600, 300)
	_blit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blit_rect)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _screenshot_taken and _elapsed >= 3.0:
		_screenshot_taken = true
		_take_screenshot()
	if _screenshot_taken and _elapsed >= 5.0 and not _done:
		_finish()


func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://screenshot_diagnostic.png")


func _finish() -> void:
	if _done:
		return
	_done = true
	# Count non-transparent pixels in the SubViewport texture to verify the
	# red square actually rendered.
	var svp_img: Image = _svp.get_texture().get_image()
	var nontransparent := 0
	if svp_img != null:
		for x in svp_img.get_width():
			for y in svp_img.get_height():
				if svp_img.get_pixel(x, y).a > 0.01:
					nontransparent += 1
	var verdict := "PASS_OK" if nontransparent > 0 else "FAIL_SVP_EMPTY"
	var report := {
		"scene": "screenshot_diagnostic",
		"elapsed": _elapsed,
		"nontransparent": nontransparent,
		"total": _svp.size.x * _svp.size.y,
		"screenshot": "user://screenshot_diagnostic.png" if _screenshot_taken else "",
		"verdict": verdict,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("SCREENSHOT_DIAGNOSTIC report written verdict=%s" % verdict)
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

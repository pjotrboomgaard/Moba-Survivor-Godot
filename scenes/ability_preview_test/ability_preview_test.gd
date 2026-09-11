extends Node2D
## Ability Preview Test Screen (P2.2a)
##
## Dedicated empty scene that displays ability previews for ALL heroes in a
## grid layout, on top of everything (highest CanvasLayer). Used to verify
## every hero's LMB/Q abilities render correctly before placing them in the
## main menu.
##
## Usage: launched via selftest with -Scene scenes/ability_preview_test/ability_preview_test.tscn

const AbilityPreviewWorldScene := preload("res://scenes/bootstrap/ability_preview_world.tscn")

var _canvas_layer: CanvasLayer = null
var _preview_grid: GridContainer = null
var _elapsed := 0.0
var _done := false
var _preview_count := 0
var _screenshot_taken := false

func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	_build_ui()
	_populate_previews()
	print("ABILITY_PREVIEW_TEST ready: %d heroes, %d previews" % [PlayerClass.CLASSES.size(), _preview_count])

func _build_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "PreviewTestLayer"
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(bg)

	var title := Label.new()
	title.text = "Ability Preview Test - All Heroes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	title.position = Vector2(0, 10)
	title.size = Vector2(1920, 40)
	_canvas_layer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 55)
	scroll.size = Vector2(1880, 1060)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_canvas_layer.add_child(scroll)

	_preview_grid = GridContainer.new()
	_preview_grid.columns = 4
	_preview_grid.name = "PreviewGrid"
	scroll.add_child(_preview_grid)
	# GridContainer inside ScrollContainer needs its own size
	_preview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var status := Label.new()
	status.name = "StatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	status.position = Vector2(0, 1120)
	status.size = Vector2(1920, 30)
	_canvas_layer.add_child(status)

func _populate_previews() -> void:
	if _preview_grid == null:
		return
	for class_data in PlayerClass.CLASSES:
		var class_id: String = str(class_data.get("id", ""))
		var hero_name: String = str(class_data.get("name", class_id))
		var effect_color: Color = Color(str(class_data.get("effect_color", "ffffff")))

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(460, 300)
		_preview_grid.add_child(card)

		var vbox := VBoxContainer.new()
		card.add_child(vbox)

		var name_label := Label.new()
		name_label.text = "%s  (%s)" % [hero_name, class_id]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", effect_color)
		vbox.add_child(name_label)

		vbox.add_child(_make_label("LMB - Primary"))
		var lmb: Control = AbilityPreviewWorldScene.instantiate()
		vbox.add_child(lmb)
		lmb.custom_minimum_size = Vector2(440, 120)
		_preview_count += 1
		_start_preview(lmb, class_id, -1)

		var q_id: String = str(class_data.get("kit_q", ""))
		if q_id != "":
			vbox.add_child(_make_label("Q - " + _ability_name(q_id)))
			var q: Control = AbilityPreviewWorldScene.instantiate()
			vbox.add_child(q)
			q.custom_minimum_size = Vector2(440, 120)
			_preview_count += 1
			_start_preview(q, class_id, 0)

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _start_preview(preview: Control, class_id: String, slot: int) -> void:
	# Defer one frame so the SubViewport is in the tree.
	call_deferred("_deferred_start", preview, class_id, slot)

func _deferred_start(preview: Control, class_id: String, slot: int) -> void:
	if is_instance_valid(preview):
		if preview.has_method("reload"):
			preview.reload(class_id, slot)
		if preview.has_method("start"):
			preview.start()

func _ability_name(ability_id: String) -> String:
	var info: Dictionary = PlayerClass.ability_info(ability_id)
	if info.has("name"):
		return str(info.get("name", ability_id))
	return ability_id

func _process(_delta: float) -> void:
	_elapsed += _delta
	# Capture a screenshot at t=8s once previews have rendered.
	if not _screenshot_taken and _elapsed >= 8.0:
		_screenshot_taken = true
		_take_screenshot()
	if Input.is_key_pressed(KEY_ESCAPE):
		_finish()
	elif _elapsed >= 30.0:
		_finish()

func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	if img != null:
		var path := "user://ability_preview_test.png"
		if img.save_png(path) == OK:
			print("ABILITY_PREVIEW_TEST screenshot saved: %s" % path)

func _finish() -> void:
	if _done:
		return
	_done = true
	print("ABILITY_PREVIEW_TEST finishing at t=%.1f previews=%d" % [_elapsed, _preview_count])
	var report := {
		"scene": "ability_preview_test",
		"elapsed": _elapsed,
		"hero_count": PlayerClass.CLASSES.size(),
		"preview_count": _preview_count,
		"screenshot": "user://ability_preview_test.png" if _screenshot_taken else "",
		"verdict": "PASS_OK" if _preview_count >= 16 else "FAIL_LOW_PREVIEWS",
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("ABILITY_PREVIEW_TEST report written")
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

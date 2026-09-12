extends Control
## Focused test: verify that when the ability preview casts Tobor's W (turret) and
## E (mines) inside its SubViewport, the resulting SummonEntity lands in the
## SubViewport's World (i.e. vfx_parent_override is honored), so the menu preview
## actually shows the thrown turret/mine instead of spawning it offscreen in the
## main menu scene.
##
## Tracks the maximum summon count seen in the viewport AND in the main scene
## across multiple frames, so a brief summon that spawns+expires still counts.
##
## Usage:
##   powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 \
##     -RequestPath tools/selftest/requests/preview_summon_test.json \
##     -Scene res://scenes/preview_summon_test/preview_summon_test.tscn

const AbilityPreviewWorldScene := preload("res://scenes/bootstrap/ability_preview_world.tscn")

var _world_root := Control.new()
var _previews: Array[AbilityPreviewWorld] = []
var _elapsed := 0.0
var _done := false
var _screenshots: Array[String] = []
var _max_viewport := 0
var _max_scene := 0


func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_world_root = Control.new()
	add_child(_world_root)

	# One preview: Tobor W (turret, slot 1).
	for i in 2:
		var pv: AbilityPreviewWorld = AbilityPreviewWorldScene.instantiate()
		pv.position = Vector2(0.0, 0.0) + Vector2(0.0, 40.0 * i)
		pv.size = Vector2(700.0, 400.0)
		_world_root.add_child(pv)
		pv.custom_minimum_size = Vector2(700.0, 400.0)
		_previews.append(pv)

	await get_tree().process_frame
	# Force both previews onto Tobor's W slot (turret) first.
	for pv in _previews:
		if pv.has_method("reload"):
			pv.reload("tobor", 1)
	# Switch to E slot (mines) after a short delay.
	call_deferred("_call_deferred_slot_switch")

	var status := Label.new()
	status.text = "PREVIEW SUMMON TEST - Tobor W/E (tracking max summon count)"
	status.add_theme_font_size_override("font_size", 22)
	status.position = Vector2(0, 680)
	status.size = Vector2(1920, 30)
	add_child(status)


func _call_deferred_slot_switch() -> void:
	await get_tree().create_timer(2.5).timeout
	for pv in _previews:
		if pv.has_method("reload"):
			pv.reload("tobor", 2)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	# Sample every ~0.3s to catch brief summons.
	if fmod(_elapsed, 0.3) < delta:
		var counts := _count_summons()
		_max_viewport = max(_max_viewport, counts[0])
		_max_scene = max(_max_scene, counts[1])
	# Capture screenshots at key moments: during turret cast, during mines cast.
	if _elapsed >= 1.2 and not _screenshots.has("t1.2"):
		_take_screenshot("t1_2")
		_screenshots.append("t1_2")
	if _elapsed >= 3.7 and not _screenshots.has("t3_7"):
		_take_screenshot("t3_7")
		_screenshots.append("t3_7")
	if _elapsed >= 5.5:
		_finish()


func _count_summons() -> Array:
	var in_viewport := 0
	var in_scene := 0
	for pv in _previews:
		var world: Node = pv.get("_world")
		if world == null:
			continue
		for child in world.get_children():
			if child.get_class() == "Node2D" and child.get_script() and child.get_script().resource_name.find("summon_entity") >= 0:
				in_viewport += 1
	var scene_root := get_tree().current_scene
	if scene_root != null:
		for child in scene_root.get_children():
			if child.get_script() and child.get_script().resource_name.find("summon_entity") >= 0:
				in_scene += 1
	return [in_viewport, in_scene]


func _take_screenshot(tag: String) -> void:
	# Defer to next frame so the cast VFX is on screen.
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var path := "user://preview_summon_%s.png" % tag
		if img.save_png(path) == OK:
			print("PREVIEW_SUMMON_TEST screenshot: %s" % path)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("PREVIEW_SUMMON_TEST max_viewport=%d max_scene=%d" % [_max_viewport, _max_scene])
	var verdict := "PASS_OK" if _max_viewport > 0 and _max_scene == 0 else "FAIL_SUMMON_WRONG_PARENT"
	var report := {
		"scene": "preview_summon_test",
		"elapsed": _elapsed,
		"max_summon_in_viewport": _max_viewport,
		"max_summon_in_scene": _max_scene,
		"screenshots": _screenshots,
		"verdict": verdict,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("PREVIEW_SUMMON_TEST report written verdict=%s vp=%d sc=%d" % [verdict, _max_viewport, _max_scene])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

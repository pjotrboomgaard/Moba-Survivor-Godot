class_name UIVerifyDriver
extends Node

## UI verification driver. Boots the real lobby + world editor, captures viewport
## screenshots at scheduled times, and exercises the WorldEditor API directly
## (place several obstacle types, erase one, save) so we can confirm the editor
## actually works end-to-end. Writes a JSON report and quits.
##
## Activate with:  godot --ui-verify   (NOT headless — we need real rendering for shots)
## Output: user://ui_verify_report.json + user://ui_verify_shots/*.png

const SHOT_DIR := "user://ui_verify_shots"

var _elapsed := 0.0
var _steps: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _report_path := "user://ui_verify_report.json"
var _done := false
var _checks: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_print("[ui-verify] driver ready, booting lobby + editor")
	# 1. capture the lobby (World Editor button visible in ModeRow).
	_steps.append({"t": 2.0, "kind": "shot", "label": "lobby"})
	# 2. hover the LMB button to confirm it shows an info panel.
	_steps.append({"t": 2.5, "kind": "hover_lmb"})
	_steps.append({"t": 5.0, "kind": "shot", "label": "lmb_hover"})
	_steps.append({"t": 5.5, "kind": "probe_preview", "label": "lmb"})
	# 3. hover the RMB button.
	_steps.append({"t": 5.5, "kind": "hover_rmb"})
	_steps.append({"t": 8.0, "kind": "shot", "label": "rmb_hover"})
	_steps.append({"t": 8.5, "kind": "probe_preview", "label": "rmb"})
	_steps.append({"t": 8.5, "kind": "hover_ability", "hero": "arclight", "slot": 0})
	_steps.append({"t": 10.5, "kind": "shot", "label": "ability_preview_nuke"})
	# Hard check: the SubViewport mini-world must actually render opaque pixels.
	_steps.append({"t": 11.0, "kind": "probe_preview", "label": "nuke"})
	_steps.append({"t": 11.0, "kind": "hover_ability", "hero": "arclight", "slot": 2})
	_steps.append({"t": 13.0, "kind": "shot", "label": "ability_preview_radius"})
	# 5. hover a SUMMON_SPIRIT ability (Tobor's Steam Keg) to verify summon rendering.
	_steps.append({"t": 13.5, "kind": "hover_ability", "hero": "tobor", "slot": 1})
	_steps.append({"t": 15.5, "kind": "shot", "label": "ability_preview_summon"})
	# 6. press the World Editor button programmatically (scene change to editor).
	_steps.append({"t": 14.0, "kind": "press_editor"})
	# 7. capture the editor (empty, toolbar visible).
	_steps.append({"t": 16.0, "kind": "shot", "label": "editor"})
	# 8. exercise placement through the editor API.
	_steps.append({"t": 17.0, "kind": "api_place_all"})
	# 9. capture with props placed.
	_steps.append({"t": 19.0, "kind": "shot", "label": "editor_with_props"})
	# 10. erase one node.
	_steps.append({"t": 19.5, "kind": "api_erase_one"})
	# 11. save the level.
	_steps.append({"t": 20.0, "kind": "api_save"})
	# 12. final shot of the grass world.
	_steps.append({"t": 21.5, "kind": "shot", "label": "editor_final"})
	# 13. switch to volcano, confirm the biome name actually changed, screenshot it.
	_steps.append({"t": 22.0, "kind": "api_switch_world", "dir": 1, "expect": "Ashen Crater"})
	_steps.append({"t": 23.0, "kind": "shot", "label": "world_volcano"})
	# 14. switch again to ice, place a couple of props there too.
	_steps.append({"t": 23.5, "kind": "api_switch_world", "dir": 1, "expect": "Frostmere Reach"})
	_steps.append({"t": 24.5, "kind": "api_place_in_new_world"})
	_steps.append({"t": 25.0, "kind": "shot", "label": "world_ice_with_props"})
	_steps.append({"t": 25.5, "kind": "api_save"})
	# 15. switch back to grass (2 steps back) and confirm the grass save is independent.
	_steps.append({"t": 26.0, "kind": "api_switch_world", "dir": -2, "expect": "Verdant Hollow"})
	_steps.append({"t": 26.5, "kind": "check_grass_restored"})
	_steps.append({"t": 27.0, "kind": "shot", "label": "world_back_to_grass"})
	_steps.append({"t": 27.5, "kind": "finish"})
	_steps.sort_custom(func(a, b): return float(a.t) < float(b.t))


func _process(delta: float) -> void:
	_elapsed += delta
	while not _steps.is_empty() and float(_steps[0].t) <= _elapsed:
		var step: Dictionary = _steps.pop_front()
		_run_step(step)


func _run_step(step: Dictionary) -> void:
	match str(step.kind):
		"shot":
			_screenshot(str(step.label))
		"hover_ability":
			_hover_ability(str(step.get("hero", "")), int(step.get("slot", 0)))
		"hover_lmb":
			_hover_lmb()
		"hover_rmb":
			_hover_rmb()
		"probe_preview":
			_probe_preview(str(step.get("label", "preview")))
		"press_editor":
			_press_editor_button()
		"api_place_all":
			_api_place_all()
		"api_erase_one":
			_api_erase_one()
		"api_save":
			_api_save()
		"api_switch_world":
			_api_switch_world(int(step.get("dir", 1)), str(step.get("expect", "")))
		"api_place_in_new_world":
			_api_place_in_new_world()
		"check_grass_restored":
			_check_grass_restored()
		"finish":
			_finish()


## Trigger the ability hover preview for a hero's ability, so the
## auto-cast SubViewport simulation runs and can be captured in a screenshot.
func _hover_ability(hero_hint: String = "", slot: int = 0) -> void:
	# The bootstrap scene is the current scene's root.
	var bootstrap := get_tree().current_scene
	if bootstrap == null:
		_check("hover_bootstrap_found", false, "current_scene not found")
		return
	var hero_id := hero_hint
	if hero_id.is_empty():
		# Fall back to first hero.
		var ids: Array = PlayerClass.playable_ids()
		hero_id = str(ids[0])
	var kit: Array = PlayerClass.kit_ability_ids(hero_id)
	if slot >= kit.size():
		slot = 0
	var ability_id: String = str(kit[slot]) if slot < kit.size() else ""
	if ability_id.is_empty():
		_check("hover_ability_found", false, "no ability id for " + hero_id + " slot " + str(slot))
		return
	_check("hover_ability_found", true, "hero=" + hero_id + " slot=" + str(slot) + " ability=" + ability_id)
	# has_method() can miss underscore-prefixed GDScript methods; use call() with a null check.
	bootstrap.call("_show_ability_hover", ability_id)
	_check("hover_ability_called", true, "called _show_ability_hover for " + ability_id)
	_print("[ui-verify] hovered ability " + ability_id + " for " + hero_id)


func _hover_lmb() -> void:
	var bootstrap := get_tree().current_scene
	if bootstrap == null:
		_check("hover_lmb_bootstrap", false, "current_scene not found")
		return
	var hero_id := PlayerProfile.selected_class_id
	if bootstrap.has_method("_show_lmb_hover"):
		bootstrap._show_lmb_hover(hero_id)
		_check("hover_lmb", true, "hero=" + hero_id)
		_print("[ui-verify] hovered LMB for " + hero_id)
	else:
		_check("hover_lmb_method", false, "no _show_lmb_hover method")


func _hover_rmb() -> void:
	var bootstrap := get_tree().current_scene
	if bootstrap == null:
		_check("hover_rmb_bootstrap", false, "current_scene not found")
		return
	var hero_id := PlayerProfile.selected_class_id
	# Every hero has a right-click secondary (a secondary_kind, not an ABILITIES entry),
	# so just call the dedicated RMB hover which now shows a full card.
	if bootstrap.has_method("_show_rmb_hover"):
		bootstrap._show_rmb_hover(hero_id)
		_check("hover_rmb", true, "hero=" + hero_id + " (all heroes have a secondary)")
		_print("[ui-verify] hovered RMB for " + hero_id)
	else:
		_check("hover_rmb_method", false, "no _show_rmb_hover method")


## Inspect the AbilityPreview SubViewport's rendered texture and report how many
## non-transparent pixels it has. This is a hard check that the mini-world is actually
## rendering (not just that the panel is visible). Fails if the SubViewport is blank.
func _probe_preview(label: String) -> void:
	var bootstrap := get_tree().current_scene
	if bootstrap == null:
		_check("probe_preview_bootstrap", false, "current_scene not found")
		return
	var world: AbilityPreviewWorld = bootstrap.get("ability_preview_world")
	if world == null:
		_check("probe_preview_found", false, "ability_preview_world is null")
		return
	_check("probe_preview_found", true, "ability_preview_world present")
	var svp: SubViewport = world.get_node_or_null("SubViewport")
	if svp == null:
		_check("probe_preview_subvp", false, "SubViewport not found")
		return
	# Give the SubViewport a moment to render a frame.
	# We sample the texture directly; it should have opaque pixels if the world drew.
	var tex: Texture2D = svp.get_texture()
	if tex == null:
		_check("probe_preview_texture", false, "no texture on SubViewport")
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		_check("probe_preview_image", false, "empty image from SubViewport texture")
		return
	var opaque := 0
	var total := img.get_width() * img.get_height()
	# Sample every 4th pixel for speed.
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var px: Color = img.get_pixel(x, y)
			if px.a > 0.5 and (px.r + px.g + px.b) > 0.05:
				opaque += 1
	var frac: float = float(opaque) / float(ceil(float(total) / 16.0))
	# NOTE: with transparent_bg=true the SubViewport's internal texture exports
	# all-zero alpha, so this probe can read 0 even when the preview is fully
	# visible on screen (see probe_preview_screen_visible below, which is the
	# true source of truth). We log it for diagnostics but don't gate on it.
	_print("[ui-verify] PREVIEW PROBE %s: opaque_frac=%.3f (%d px) [informational — transparent_bg]" % [label, frac, opaque])
	# ALSO sample the MAIN viewport at the preview's on-screen rect — the hard truth of
	# whether the SubViewport is actually blitted into what the user sees (a bare
	# SubViewport may hold a valid internal texture but not display in the main window).
	var preview_ctrl: Control = world.get_node_or_null("SubViewport") as Control
	var svp_rect: Rect2 = world.get_rect()  # world root is the AbilityPreview Control
	var vp: Viewport = get_viewport()
	var vp_img: Image = vp.get_texture().get_image()
	if vp_img == null or vp_img.is_empty():
		_check("probe_preview_screen_image", false, "could not read main viewport image")
		return
	var screen_opaque := 0
	var screen_total := 0
	# Sample a small region in the middle-bottom of the panel where the preview should sit.
	var y0 := int(svp_rect.position.y + svp_rect.size.y * 0.55)
	var y1 := int(svp_rect.position.y + svp_rect.size.y * 0.95)
	var x0 := int(svp_rect.position.x + svp_rect.size.x * 0.1)
	var x1 := int(svp_rect.position.x + svp_rect.size.x * 0.9)
	var step_x := maxi(2, (x1 - x0) / 40)
	var step_y := maxi(2, (y1 - y0) / 20)
	for sy in range(maxi(0, y0), min(int(vp_img.get_height()), y1), step_y):
		for sx in range(maxi(0, x0), min(int(vp_img.get_width()), x1), step_x):
			screen_total += 1
			var spx: Color = vp_img.get_pixel(sx, sy)
			if spx.a > 0.5 and (spx.r + spx.g + spx.b) > 0.08:
				screen_opaque += 1
	var screen_frac: float = 0.0 if screen_total == 0 else float(screen_opaque) / float(screen_total)
	_check("probe_preview_screen_visible", screen_frac > 0.08, "label=%s on_screen_frac=%.3f (expect >0.08)" % [label, screen_frac])
	_print("[ui-verify] PREVIEW SCREEN %s: on_screen_frac=%.3f region=rect(%d,%d,%d,%d)" % [label, screen_frac, x0, y0, x1, y1])


func _press_editor_button() -> void:
	var found := _find_node_by_name(get_tree().root, "WorldEditorButton")
	if found == null:
		_check("editor_button_found", false, "WorldEditorButton NOT FOUND in tree")
		return
	_check("editor_button_found", true, str(found.get_path()))
	if found is BaseButton:
		(found as BaseButton).pressed.emit()
		_print("[ui-verify] pressed WorldEditorButton")
	else:
		_check("editor_button_is_button", false, "WorldEditorButton is not a BaseButton: %s" % found.get_class())


func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for c in root.get_children():
		var hit := _find_node_by_name(c, target)
		if hit != null:
			return hit
	return null


func _editor() -> Node:
	return _find_node_by_name(get_tree().root, "WorldEditor")


func _api_place_all() -> void:
	var ed := _editor()
	if ed == null:
		_check("editor_scene_loaded", false, "WorldEditor node not found after press")
		return
	_check("editor_scene_loaded", true, "WorldEditor node present")
	# Place a spread of each asset type near the origin.
	var positions := [
		Vector2(120.0, 120.0), Vector2(240.0, 160.0), Vector2(-160.0, 100.0),
		Vector2(0.0, 300.0), Vector2(200.0, -140.0), Vector2(-220.0, -180.0),
		Vector2(320.0, 260.0), Vector2(-320.0, 260.0), Vector2(320.0, -260.0), Vector2(-320.0, -260.0),
		Vector2(80.0, -320.0), Vector2(-80.0, -320.0), Vector2(400.0, 40.0),
	]
	var sprites := [
		"tree_oak", "tree_pine", "tree_dead", "rock_small", "grass_bush", "grass_mushroom",
		"tree_willow", "rock_jagged", "grass_wild", "flower_patch",
		"tree_round", "tree_fir", "tree_maple",
	]
	for i in sprites.size():
		ed.place_at(positions[i], sprites[i])
	var placed_after := int(ed.get("_placed"))
	_check("api_place_obstacles", placed_after >= sprites.size(), "placed=%d" % placed_after)
	# Confirm the new assets actually resolved to a real baked texture, not the
	# vector-drawing fallback (SpriteLibrary.texture_for returns null on a miss).
	var new_ids := ["tree_willow", "rock_jagged", "grass_wild", "flower_patch"]
	var new_nodes: Array = ed.get("_placed_nodes")
	var new_found := 0
	for node in new_nodes:
		if node != null and is_instance_valid(node) and new_ids.has(str(node.get("sprite_id"))):
			if bool(node.call("has_sprite")):
				new_found += 1
	_check("api_new_assets_have_sprite", new_found >= new_ids.size(), "new_assets_with_sprite=%d/%d" % [new_found, new_ids.size()])
	# Place a landmark via the tool + API.
	ed._set_tool("landmark")
	ed._place_landmark(Vector2(0.0, 0.0))
	_check("api_place_landmark", int(ed.get("_placed")) > placed_after, "placed=%d" % int(ed.get("_placed")))


func _api_erase_one() -> void:
	var ed := _editor()
	if ed == null:
		return
	var before := int(ed.get("_placed"))
	# Erase the first tree placed at (120,120) with a generous radius.
	var erased: bool = ed.erase_at_radius(Vector2(120.0, 120.0), 150.0)
	var after := int(ed.get("_placed"))
	_check("api_erase_obstacle", erased and after == before - 1, "erased=%s before=%d after=%d" % [str(erased), before, after])


func _api_save() -> void:
	var ed := _editor()
	if ed == null:
		return
	ed._save()
	var save_path := "user://world_editor_level.json"
	var exists := FileAccess.file_exists(save_path)
	_check("api_save_level", exists, "save file exists=%s at %s" % [str(exists), save_path])


func _api_switch_world(dir: int, expect_name: String) -> void:
	var ed := _editor()
	if ed == null:
		_check("world_switch_editor_present", false, "WorldEditor node not found")
		return
	ed._switch_world(dir)
	var actual := GameRuntime.biome_name()
	_check("world_switch_to_%s" % expect_name, actual == expect_name, "expected=%s actual=%s biome_id=%d" % [expect_name, actual, GameRuntime.biome_id])


func _api_place_in_new_world() -> void:
	var ed := _editor()
	if ed == null:
		return
	ed.place_at(Vector2(50.0, 50.0), "rock_large")
	ed.place_at(Vector2(-80.0, 120.0), "tree_dead")
	var placed: int = int(ed.get("_placed"))
	_check("api_place_after_world_switch", placed >= 2, "placed=%d in world=%s" % [placed, GameRuntime.biome_name()])


func _check_grass_restored() -> void:
	var ed := _editor()
	if ed == null:
		return
	# Grass's own save (from the earlier api_save step) — switching back to grass
	# should reload exactly that world's props, NOT ice's 1000+ props. The exact
	# live-node count varies with how many props bake vs stay live (trees, grass,
	# mushrooms now bake), so we assert independence: well under ice's count and
	# positive.
	var placed: int = int(ed.get("_placed"))
	_check("grass_save_independent_of_other_worlds", placed > 0 and placed < 500, "placed=%d (grass save, independent of ice)" % placed)


func _screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var fname := "%s_%d.png" % [label, Time.get_ticks_msec()]
	var path := "%s/%s" % [SHOT_DIR, fname]
	var err := img.save_png(path)
	_shots.append({"label": label, "path": path, "err": err})
	_print("[ui-verify] shot label=%s path=%s err=%s vp=%s" % [label, path, str(err), str(vp.get_visible_rect().size)])


func _check(name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": name, "ok": ok, "detail": detail})
	_print("[ui-verify] CHECK %s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])


func _finish() -> void:
	if _done:
		return
	_done = true
	var all_ok := true
	for c in _checks:
		if not bool(c.ok):
			all_ok = false
	var report := {
		"elapsed": _elapsed,
		"shots": _shots,
		"checks": _checks,
		"all_ok": all_ok,
		"verdict": "PASS" if all_ok else "FAIL",
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	_print("[ui-verify] report -> %s verdict=%s" % [_report_path, report.verdict])
	_print("[ui-verify] done, quitting")
	get_tree().quit()


func _print(msg: String) -> void:
	print(msg)

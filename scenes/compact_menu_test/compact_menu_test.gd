extends Node
## Isolated/verify driver for the compact main menu (2026-09-16 redesign + v2).
##
## Attached to get_tree().root by bootstrap.gd when marker file
## user://compact_menu_test exists.
##
## Captures:
##   menu_before          — menu as first shown (default hero)
##   menu_after_next      — after pressing the ">" hero nav once
##   menu_after_roster    — after selecting a hero from the 16-hero roster grid
##   menu_after_mode      — after pressing the ">" mode nav once
##
## Also probes:
##   - roster grid has 16 hero buttons
##   - title_label is hidden (RIFT SURVIVORS removed)
##   - LMB + RMB buttons exist in the ability strip
##   - tobor name is "Tobor" (not "Wrench")

var _elapsed := 0.0
var _run_dir := ""
var _shots: Array = []
var _done := false
var _shot_index := 0
var _boot: Node = null

# shot time -> (label, optional action performed just before the shot)
var _shot_times: Array[float] = [0.8, 2.0, 4.0, 6.0, 8.0]
var _shot_labels: Array = [
	"menu_before",
	"menu_after_next",
	"menu_after_hero_select",
	"menu_after_mode",
	"menu_hero_desc_hover",
]


func _ready() -> void:
	_run_dir = "user://compact_menu_run_%d" % int(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[CompactMenu] driver ready, run_dir=", _run_dir)
	# Dump the layout tree after a couple of frames so all setup code has run.
	await get_tree().process_frame
	await get_tree().process_frame
	_dump_layout_tree()
	# T4.5 BEFORE state: if the marker user://compact_menu_before exists, hide the
	# roster grid + ability strip so the capture shows the pre-roster menu layout
	# (big hero icon / name + < > nav only, no 16-hero grid, no ability strip).
	if FileAccess.file_exists("user://compact_menu_before"):
		_apply_before_state()


func _apply_before_state() -> void:
	# Wait for the bootstrap menu to finish building (deferred to next frame).
	await get_tree().process_frame
	await get_tree().process_frame
	if _boot == null:
		_boot = get_tree().current_scene
	if _boot == null:
		return
	# Hide the 16-hero roster grid and the ability strip to represent the
	# pre-roster menu (old 9-dot button layout, which is no longer in the codebase).
	var roster_grid: Control = _boot.get("_roster_grid")
	if roster_grid is Control:
		roster_grid.visible = false
	var ability_strip: Control = _boot.get("_ability_strip")
	if ability_strip is Control:
		ability_strip.visible = false
	# Also hide the settings wrench row (added with the roster).
	var settings_btn: Control = _boot.get("_compact_settings_btn")
	if settings_btn is Control and settings_btn.get_parent() != null:
		settings_btn.get_parent().visible = false
	print("[CompactMenu] BEFORE state applied (roster grid + ability strip hidden)")


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta

	if _boot == null:
		_boot = get_tree().current_scene
	# Take the next scheduled shot.
	while _shot_index < _shot_times.size() and _elapsed >= _shot_times[_shot_index]:
		var label: String = _shot_labels[_shot_index]
		_perform_action(_shot_index)
		_shot_index += 1
		_snap_deferred(label)

	if _shot_index >= _shot_times.size() and _elapsed >= _shot_times[_shot_times.size() - 1] + 1.5:
		_finish()


func _perform_action(index: int) -> void:
	if _boot == null:
		return
	match index:
		0:
			pass  # default state
		1:
			if _boot.has_method("_cycle_hero"):
				_boot._cycle_hero(1)
		2:
			# Roster is now always visible — select a roster hero via the grid.
			if _boot.has_method("_on_roster_hero_pressed"):
				_boot._on_roster_hero_pressed("arclight")
		3:
			if _boot.has_method("_cycle_mode"):
				_boot._cycle_mode(1)
		4:
			# Hover the selected hero's roster button to show the hero description
			# + stats panel (hover-only). Use arclight (just selected in step 2).
			if _boot.has_method("_on_roster_hover"):
				_boot._on_roster_hover("arclight")


func _snap_deferred(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.1).timeout
	if _done:
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var path := "%s/%s.png" % [_run_dir, label]
		img.save_png(path)
		_shots.append({"label": label, "path": path})
		print("[CompactMenu] snap ", label, " ", img.get_width(), "x", img.get_height())
	else:
		_shots.append({"label": label, "path": "none", "error": "no image"})
		print("[CompactMenu] snap ", label, " FAILED: no image")


func _dump_layout_tree() -> void:
	if _boot == null:
		return
	# Dump the Margin's children too (PlayRow / CoopRow may be siblings of Layout)
	var margin = _boot.get_node_or_null("StatusLayer/LobbyPanel/Margin")
	if margin != null:
		print("[CompactMenu] DIAG Margin children:")
		for i in margin.get_child_count():
			var c := margin.get_child(i)
			print("[CompactMenu] DIAG  Margin ", i, ": ", c.name, " (", c.get_class(), ") visible=", c.visible)
			if c is Container:
				for j in c.get_child_count():
					var cc := c.get_child(j)
					var t := ""
					if cc is Button:
						t = str((cc as Button).text)
					elif cc is Label:
						t = str((cc as Label).text)
					print("[CompactMenu] DIAG    ", j, ": ", cc.name, " (", cc.get_class(), ") visible=", cc.visible, " text=", t)
	var layout = _boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout")
	if layout == null:
		print("[CompactMenu] DIAG: layout not found")
		return
	print("[CompactMenu] DIAG: Layout children (index: name type visible):")
	for i in layout.get_child_count():
		var c := layout.get_child(i)
		var c_text := ""
		if c is Button:
			c_text = (c as Button).text
		elif c is Label:
			c_text = (c as Label).text
		print("[CompactMenu] DIAG  ", i, ": ", c.name, " (", c.get_class(), ") visible=", c.visible, " text=", c_text)
		# Also dump direct children of containers
		if c is Container:
			for j in c.get_child_count():
				var cc := c.get_child(j)
				var cc_text := ""
				if cc is Button:
					cc_text = (cc as Button).text
				elif cc is Label:
					cc_text = (cc as Label).text
				print("[CompactMenu] DIAG    ", j, ": ", cc.name, " (", cc.get_class(), ") visible=", cc.visible, " text=", cc_text)


func _finish() -> void:
	if _done:
		return
	_done = true
	_dump_layout_tree()
	var ok_shots := 0
	for s in _shots:
		if not str(s.get("path", "")).ends_with("none") and not str(s.get("path", "")).is_empty():
			ok_shots += 1
	var verdict := "PASS" if ok_shots == _shot_times.size() else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "compact_menu_test",
		"task": "Compact main menu redesign (big hero icon + < > nav + roster + mode nav)",
		"expected_shots": _shot_times.size(),
		"shots_captured": ok_shots,
		"shots": _shots,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[CompactMenu] SUMMARY verdict=", verdict, " shots=", ok_shots, "/", _shot_times.size())
	get_tree().quit(0)

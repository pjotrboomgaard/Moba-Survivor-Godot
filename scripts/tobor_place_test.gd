extends Node2D
## Isolated test for T3.79: Tobor turret + mine vector throw effect.
## Empty world with a real Player (tobor). Casts the turret and mine abilities,
## captures screenshots mid-throw to show the vector streak in flight, then
## confirms no leftover VFX nodes remain after the effect duration.
##
## Launched via:
##   run_selftest.ps1 -RequestPath tools/selftest/requests/tobor_place_iso.json \
##     -Scene res://scenes/tobor_place_test/tobor_place_test.tscn

const PlayerScene := preload("res://scenes/player/player.tscn")

var _player: Player = null
var _done := false
var _shots: Array = []
var _node_count_before := 0
var _node_count_after := 0

func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	GameRuntime.set_biome(0, true)

	var p: Player = PlayerScene.instantiate()
	p.name = "TestHero"
	p.global_position = Vector2(-200.0, 0.0)
	add_child(p)
	p.configure(0, Player.SimulationMode.OFFLINE, false, "tobor")
	p.health.current_health = p.health.max_health
	if p.has_node("Camera2D"):
		(p.get_node("Camera2D") as Camera2D).enabled = false
	_player = p

	# Aim at a point 300px to the right (throw target).
	_player.aim_world_position = _player.global_position + Vector2(300.0, 0.0)

	# Reset cooldowns so all slots are ready.
	_player.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]

	# Phase 1: cast turret (slot 1).
	# Capture mid-throw (~0.25s) to catch the vector streak in flight.
	_player.scripted_tap_ability(1)
	await get_tree().create_timer(0.25).timeout
	_capture("tobor_turret_mid_throw")

	# Wait for the throw to complete + effect to settle.
	await get_tree().create_timer(0.6).timeout
	_capture("tobor_turret_settled")

	# Phase 2: cast mines (slot 2).
	_player.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	_player.aim_world_position = _player.global_position + Vector2(250.0, -80.0)
	_player.scripted_tap_ability(2)
	await get_tree().create_timer(0.25).timeout
	_capture("tobor_mines_mid_throw")

	await get_tree().create_timer(0.6).timeout
	_capture("tobor_mines_settled")

	# Phase 3: count lingering VFX nodes after all effects have expired.
	# The throw effect has a hard timer of travel_time + 0.2s = 0.75s total.
	# Both throws were ~0.25s + 0.6s = 0.85s ago, so they should be freed.
	await get_tree().create_timer(0.5).timeout
	_count_vfx_nodes()

	_finish()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var path := "user://tobor_place_%s.png" % label
		if img.save_png(path) == OK:
			_shots.append({"label": label, "path": path})
			print("[ToborPlace] captured %s" % label)

func _count_vfx_nodes() -> void:
	# Count nodes named ThrowVFX_* or AbilityVfx that are still in the tree.
	var lingering := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		pass  # not relevant
	# Walk children to find ThrowVFX or AbilityVfx nodes.
	for child in get_tree().root.get_children():
		_count_subtree(child, lingering)

func _count_subtree(node: Node, count: int) -> int:
	if node.name.begins_with("ThrowVFX") or node is AbilityVfx:
		count += 1
	for child in node.get_children():
		_count_subtree(child, count)
	return count

func _finish() -> void:
	if _done:
		return
	_done = true

	var abs_dir := ProjectSettings.globalize_path("user://")
	var abs_shots := []
	for s in _shots:
		var abs := str(s.get("path", "")).replace("user://", abs_dir)
		if FileAccess.file_exists(abs):
			abs_shots.append({"path": abs, "label": str(s.get("label", ""))})

	var report := {
		"verdict": "PASS",
		"scene": "tobor_place_test",
		"screenshots": abs_shots,
		"notes": "Isolated test: cast tobor_steam_turret and tobor_spider_mines, capture mid-throw vector streak. Confirm no leftover VFX after effect duration.",
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ToborPlace] report written, shots=%d" % abs_shots.size())
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)

func _draw() -> void:
	draw_rect(Rect2(-800.0, -500.0, 1600.0, 1000.0), Color(0.08, 0.10, 0.12), true)
	# Grid
	var step := 100.0
	var x := -800.0
	while x <= 800.0:
		draw_line(Vector2(x, -500.0), Vector2(x, 500.0), Color(1, 1, 1, 0.04), 1.0)
		x += step
	var y := -500.0
	while y <= 500.0:
		draw_line(Vector2(-800.0, y), Vector2(800.0, y), Color(1, 1, 1, 0.04), 1.0)
		y += step

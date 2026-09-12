extends Node2D
## Isolated test for the world-editor "load loads map but stays in same biome" bug.
##
## The fix in WorldEditor._load_named_map() calls GameRuntime.set_biome(map_biome_id, true)
## followed by arena.dress_from_runtime_biome() when the loaded map's biome differs from
## the current one. This test exercises that exact call sequence against a live Arena and
## verifies the arena actually re-themes (world_id changes to the new biome's world).

const ArenaScene := preload("res://scenes/arena/arena.tscn")

var _arena: Arena = null
var _done := false
var _world_before := -1
var _world_after := -1
var _hazards_after := 0


func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE
	# Boot in grass (biome 0 = VERDANT_WILDS).
	GameRuntime.set_biome(0, false)
	_arena = ArenaScene.instantiate() as Arena
	add_child(_arena)
	_arena.dress_from_runtime_biome()
	await get_tree().process_frame
	await get_tree().process_frame
	_world_before = int(_arena.get("_world_id"))
	print("LOAD_BIOME_TEST world_before=%d (expected VERDANT_WILDS=%d)" % [_world_before, Arena.World.VERDANT_WILDS])

	# Simulate: user loaded the ice (biome 2) map while in grass.
	# This is exactly what the fixed _load_named_map does.
	GameRuntime.set_biome(2, true)
	_arena.dress_from_runtime_biome()
	await get_tree().process_frame
	await get_tree().process_frame
	_world_after = int(_arena.get("_world_id"))
	# Ice biome has hazard zones (ice water gaps). Grass does not.
	var hazards: Array = _arena.get("hazard_zones")
	_hazards_after = hazards.size() if hazards != null else 0
	print("LOAD_BIOME_TEST world_after=%d (expected STORM_COURT=%d) hazards=%d" % [
		_world_after, Arena.World.STORM_COURT, _hazards_after])

	_take_screenshot()
	await get_tree().create_timer(0.5).timeout
	_finish()


func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	if img != null:
		img.save_png("user://load_biome_test.png")


func _finish() -> void:
	if _done:
		return
	_done = true
	var biome_switched := _world_before != _world_after
	var correct_world := _world_after == Arena.World.STORM_COURT
	var verdict := "PASS_OK" if (biome_switched and correct_world) else "FAIL_BIOME_NOT_SWITCHED"
	var report := {
		"scene": "load_biome_test",
		"world_before": _world_before,
		"world_after": _world_after,
		"expected_world": Arena.World.STORM_COURT,
		"biome_switched": biome_switched,
		"correct_world": correct_world,
		"hazards_after": _hazards_after,
		"screenshot": "user://load_biome_test.png",
		"verdict": verdict,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("LOAD_BIOME_TEST report written verdict=%s before=%d after=%d" % [verdict, _world_before, _world_after])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

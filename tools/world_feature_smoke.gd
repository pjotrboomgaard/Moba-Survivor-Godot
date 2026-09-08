extends Node

## Headless check that each animated prop loops, and that play maps do not
## auto-stamp trees or scenery. Run:
## godot --headless --path . res://tools/world_feature_smoke.tscn -- --pjotr

const WorldFeatureScript := preload("res://scripts/world_feature.gd")
const WorldFeatureArtScript := preload("res://scripts/world_feature_art.gd")

func _ready() -> void:
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	var failed := 0
	for feature_id in WorldFeatureArtScript.ALL_IDS:
		var feature := WorldFeatureScript.new()
		add_child(feature)
		feature.configure(str(feature_id))
		await get_tree().process_frame
		if not feature.has_frames():
			printerr("FAIL %s missing frames" % feature_id)
			failed += 1
			feature.queue_free()
			continue
		var start_sig: int = feature.texture_signature()
		var start_frame: int = feature.frame_index
		feature._process(0.51)
		var mid_sig: int = feature.texture_signature()
		if feature.frame_index == start_frame or mid_sig == start_sig:
			printerr("FAIL %s did not advance after 0.51s" % feature_id)
			failed += 1
		else:
			print("PASS %s animated frame %d -> %d" % [feature_id, start_frame, feature.frame_index])
		feature.queue_free()
	for biome in 5:
		GameRuntime.set_biome(biome, true)
		var packed: PackedScene = load("res://scenes/arena/arena.tscn")
		var arena: Arena = packed.instantiate()
		add_child(arena)
		await get_tree().process_frame
		await get_tree().process_frame
		var found := get_tree().get_nodes_in_group("world_feature")
		if not found.is_empty():
			printerr("FAIL biome %d auto-spawned %d world features" % [biome, found.size()])
			failed += 1
		var auto_trees := 0
		var rocks := 0
		for obstacle in arena.obstacles:
			if obstacle == null:
				continue
			if str(obstacle.sprite_id).begins_with("tree"):
				auto_trees += 1
			elif str(obstacle.sprite_id).begins_with("rock") or str(obstacle.sprite_id) == "spire":
				rocks += 1
		if auto_trees != 0:
			printerr("FAIL biome %d auto-planted %d trees" % [biome, auto_trees])
			failed += 1
		else:
			print("PASS biome %d has %d small rocks and no trees/features" % [biome, rocks])
		arena.queue_free()
		await get_tree().process_frame
	if failed > 0:
		printerr("world_feature_smoke failed: %d" % failed)
		get_tree().quit(1)
		return
	print("world_feature_smoke ok")
	get_tree().quit(0)

extends Node

## Headless check that the world editor palette is grouped by world, placing works,
## and that the editor does not auto-scatter trees. Run:
## godot --headless --path . res://tools/editor_palette_smoke.tscn -- --pjotr

const WorldFeatureArtScript := preload("res://scripts/world_feature_art.gd")

func _ready() -> void:
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	var packed: PackedScene = load("res://scenes/world_editor/world_editor.tscn")
	var editor: WorldEditor = packed.instantiate()
	add_child(editor)
	await get_tree().process_frame
	await get_tree().process_frame
	var failed := 0
	var arena := editor.arena as Arena
	var auto_trees := 0
	if arena != null:
		for obstacle in arena.obstacles:
			if obstacle != null and str(obstacle.sprite_id).begins_with("tree"):
				auto_trees += 1
	if auto_trees != 0:
		printerr("FAIL editor auto-planted %d trees" % auto_trees)
		failed += 1
	else:
		print("PASS editor starts without auto trees")
	var names: PackedStringArray = PackedStringArray()
	for biome in 5:
		names.append(str(WorldEditor.world_kit(biome).get("name", "")))
	print("world kits: %s" % ", ".join(names))
	if editor._palette_list == null:
		printerr("FAIL missing palette list")
		failed += 1
	else:
		var headers: PackedStringArray = PackedStringArray()
		for child in editor._palette_list.get_children():
			if child is VBoxContainer:
				var header := child.get_child(0) as Label
				if header != null:
					headers.append(header.text)
		for expected in ["Rocks", "Grass", "Volcano", "Ice", "Factory", "Docks"]:
			if not headers.has(expected):
				printerr("FAIL palette missing world section %s (have %s)" % [expected, ", ".join(headers)])
				failed += 1
		if failed == 0:
			print("PASS palette divided by world: %s" % ", ".join(headers))
	var grass_trees: Array = WorldEditor.world_kit(0).get("trees", [])
	var x := 0.0
	for sprite_id in grass_trees:
		editor.place_at(Vector2(x, 80.0), str(sprite_id))
		x += 90.0
	var placed_trees := 0
	for node in editor._placed_nodes:
		if node is Obstacle and (node as Obstacle).has_sprite() and str(node.sprite_id).begins_with("tree"):
			placed_trees += 1
	if placed_trees != grass_trees.size():
		printerr("FAIL placed grass trees %d/%d" % [placed_trees, grass_trees.size()])
		failed += 1
	else:
		print("PASS placed %d grass trees" % placed_trees)
	editor.place_at(Vector2(0.0, 220.0), "grass_waterfall")
	var placed_features := 0
	for node in editor._placed_nodes:
		if node != null and node.is_in_group("world_feature"):
			placed_features += 1
	if placed_features < 1:
		printerr("FAIL could not place animated prop")
		failed += 1
	else:
		print("PASS placed animated prop from grass kit")
	for biome in [1, 2, 3, 4]:
		GameRuntime.set_biome(biome, true)
		if arena != null:
			arena.dress_from_runtime_biome()
		editor._rebuild_palette()
		var kit: Dictionary = WorldEditor.world_kit(biome)
		var preview_id := str((kit.get("anim", ["grass_waterfall"]) as Array)[0])
		if WorldFeatureArtScript.preview_texture(preview_id) == null:
			printerr("FAIL biome %s missing animated preview" % kit.get("name"))
			failed += 1
		var lush := SpriteLibrary.texture_for("grass_lush")
		var meadow := SpriteLibrary.texture_for("grass_meadow")
		var dirt := SpriteLibrary.texture_for("dirt_tile")
		var ground := SpriteLibrary.texture_for("grass_tile")
		if lush == null or meadow == null or dirt == null or ground == null:
			printerr("FAIL biome %s missing zone tiles" % GameRuntime.biome_key())
			failed += 1
		else:
			print("PASS biome %s kit=%s zone tiles ok" % [GameRuntime.biome_key(), kit.get("name")])
	if failed > 0:
		printerr("editor_palette_smoke failed: %d" % failed)
		get_tree().quit(1)
		return
	print("editor_palette_smoke ok")
	get_tree().quit(0)

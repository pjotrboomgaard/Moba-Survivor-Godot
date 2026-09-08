extends Node

## Windowed capture of animated props and the tree collection.
## godot --path . res://tools/world_feature_capture.tscn -- --pjotr

const OUT_DIR := "res://tools/selftest/results/world_features"
const Art := preload("res://scripts/world_feature_art.gd")
const WorldFeatureScript := preload("res://scripts/world_feature.gd")

func _ready() -> void:
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	GameRuntime.set_biome(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for feature_id in Art.ALL_IDS:
		var feature := WorldFeatureScript.new()
		add_child(feature)
		feature.configure(str(feature_id))
		await get_tree().process_frame
		if not feature.has_frames():
			printerr("FAIL %s missing frames" % feature_id)
			failed += 1
		else:
			_save_texture_frames(str(feature_id), feature)
			var start: int = feature.texture_signature()
			feature._process(0.51)
			if feature.texture_signature() == start:
				printerr("FAIL %s did not animate" % feature_id)
				failed += 1
			else:
				print("PASS %s animated" % feature_id)
		feature.queue_free()
	await _capture_grid("tree_collection", _tree_sprites(), Vector2(220.0, 260.0), 4, Vector2(4.3, 4.3))
	await _capture_ingame_trees()
	await _capture_grid("animated_props", _prop_sprites(), Vector2(280.0, 300.0), 5, Vector2(6.0, 6.0))
	if failed > 0:
		printerr("world_feature_capture failed: %d" % failed)
		get_tree().quit(1)
		return
	print("world_feature_capture ok")
	get_tree().quit(0)


func _tree_sprites() -> Array:
	var out: Array = []
	for sprite_id in WorldEditor.TREES:
		var sprite := Sprite2D.new()
		sprite.texture = SpriteLibrary.texture_for(str(sprite_id))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		if sprite.texture != null:
			sprite.scale = Vector2.ONE * Obstacle.tree_display_zoom(4.0, sprite.texture)
		out.append(sprite)
	return out


func _prop_sprites() -> Array:
	var out: Array = []
	for feature_id in Art.ALL_IDS:
		var sprite := Sprite2D.new()
		sprite.texture = Art.preview_texture(str(feature_id))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		out.append(sprite)
	return out


func _capture_ingame_trees() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var bg := Polygon2D.new()
	bg.color = Color(0.18, 0.28, 0.16, 1.0)
	bg.polygon = PackedVector2Array([
		Vector2(-80, -40), Vector2(980, -40), Vector2(980, 420), Vector2(-80, 420),
	])
	holder.add_child(bg)
	var packed: PackedScene = load("res://scenes/arena/obstacle.tscn")
	var ids := ["tree_oak", "tree_pine", "tree_fir", "tree_willow", "tree_maple", "grass_wild", "flower_patch"]
	var x := 80.0
	for sprite_id in ids:
		var obstacle: Obstacle = packed.instantiate()
		holder.add_child(obstacle)
		obstacle.position = Vector2(x, 280.0)
		var spec: Dictionary = WorldEditor.OBSTACLE_SPEC.get(sprite_id, {"radius": 18.0, "lift": 0.0})
		obstacle.configure(str(sprite_id), float(spec.get("radius", 18.0)), 4.0, float(spec.get("lift", 0.0)))
		x += 140.0
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.position = Vector2(460.0, 200.0)
	camera.zoom = Vector2(1.15, 1.15)
	holder.add_child(camera)
	camera.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_save_view("ingame_trees")
	# Close crop so texel density is obvious.
	camera.position = Vector2(80.0, 200.0)
	camera.zoom = Vector2(2.4, 2.4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_save_view("ingame_oak_close")
	var oak_tex := SpriteLibrary.texture_for("tree_oak")
	if oak_tex != null:
		var oak_img := oak_tex.get_image()
		if oak_img != null:
			var scaled := oak_img.duplicate()
			scaled.resize(oak_img.get_width() * 10, oak_img.get_height() * 10, Image.INTERPOLATE_NEAREST)
			scaled.save_png("%s/tree_oak_native_x10.png" % OUT_DIR)
			print("oak native %dx%d" % [oak_img.get_width(), oak_img.get_height()])
	var tuft := SpriteLibrary.texture_for("grass_wild")
	if tuft != null:
		var tuft_img := tuft.get_image()
		if tuft_img != null:
			var scaled_t := tuft_img.duplicate()
			scaled_t.resize(tuft_img.get_width() * 10, tuft_img.get_height() * 10, Image.INTERPOLATE_NEAREST)
			scaled_t.save_png("%s/grass_wild_native_x10.png" % OUT_DIR)
			print("grass_wild native %dx%d" % [tuft_img.get_width(), tuft_img.get_height()])
	holder.queue_free()
	await get_tree().process_frame


func _capture_grid(stem: String, sprites: Array, cell: Vector2, columns: int, zoom: Vector2) -> void:
	var holder := Node2D.new()
	add_child(holder)
	var bg := Polygon2D.new()
	bg.color = Color(0.08, 0.09, 0.10, 1.0)
	var rows := int(ceili(float(sprites.size()) / float(columns)))
	var width := cell.x * float(columns)
	var height := cell.y * float(rows)
	bg.polygon = PackedVector2Array([
		Vector2(-40, -40), Vector2(width + 40, -40),
		Vector2(width + 40, height + 40), Vector2(-40, height + 40),
	])
	holder.add_child(bg)
	for index in sprites.size():
		var sprite: Sprite2D = sprites[index]
		sprite.scale = zoom
		sprite.position = Vector2(
			cell.x * float(index % columns) + cell.x * 0.5,
			cell.y * float(index / columns) + cell.y * 0.5
		)
		holder.add_child(sprite)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.position = Vector2(width * 0.5, height * 0.5)
	camera.zoom = Vector2(1.05, 1.05)
	holder.add_child(camera)
	camera.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_save_view(stem)
	holder.queue_free()
	await get_tree().process_frame


func _save_texture_frames(feature_id: String, feature: Node) -> void:
	var frames: Array = feature._frames
	for index in frames.size():
		var texture: Texture2D = frames[index]
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null:
			continue
		var scaled := image.duplicate()
		scaled.resize(image.get_width() * 8, image.get_height() * 8, Image.INTERPOLATE_NEAREST)
		var path := "%s/%s_tex_f%d.png" % [OUT_DIR, feature_id, index]
		scaled.save_png(path)


func _save_view(stem: String) -> String:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, stem]
	image.save_png(path)
	print("wrote %s size=%s" % [ProjectSettings.globalize_path(path), str(image.get_size())])
	return path

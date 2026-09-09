extends Node

## Standalone sprite generator for splitter_small and splitter_tiny.
## Run as: godot --headless --path . -s tools/gen_splitter_sprites.gd

func _ready() -> void:
	print("[GEN] Starting splitter sprite generation...")
	var art := SpriteArt
	var sprites := art.all_sprites()
	print("[GEN] Total sprites in catalog: ", sprites.size())
	var out_dir := "res://assets/sprites"
	for name in ["splitter_small", "splitter_tiny"]:
		if not sprites.has(name):
			printerr("[GEN] MISSING from all_sprites: ", name)
			continue
		var sprite: Dictionary = sprites[name]
		var rows: Array = sprite.rows
		var palette: Dictionary = sprite.palette
		var size := rows.size()
		print("[GEN] Generating ", name, " (", size, "x", size, ")")
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in size:
			var row: String = rows[y]
			for x in size:
				var character := row[x]
				if character == ".":
					continue
				var color := Color(str(palette[character]))
				image.set_pixel(x, y, color)
		var path := out_dir + "/" + name + ".png"
		var result := image.save_png(path)
		if result == OK:
			print("[GEN] WROTE: ", path)
		else:
			printerr("[GEN] FAILED: ", path, " error=", result)
	print("[GEN] Done. Quitting.")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	var art := load("res://tools/sprite_art.gd")
	var sprites := art.all_sprites()
	var out_dir := "res://assets/sprites"
	for name in ["splitter_small", "splitter_tiny"]:
		if not sprites.has(name):
			printerr("MISSING: " + name)
			continue
		var sprite: Dictionary = sprites[name]
		var rows: Array = sprite.rows
		var palette: Dictionary = sprite.palette
		var size := rows.size()
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in size:
			var row: String = rows[y]
			for x in size:
				var character := row[x]
				if character == ".":
					continue
				image.set_pixel(x, y, Color(str(palette[character])))
		var path := out_dir + "/" + name + ".png"
		var result := image.save_png(path)
		if result == OK:
			print("WROTE: " + path + " (" + str(size) + "x" + str(size) + ")")
		else:
			printerr("FAILED: " + path + " (error " + str(result) + ")")
	get_tree().quit(0)

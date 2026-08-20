extends Node

## Bakes the hand-authored grids in SpriteArt into PNG files.
## Run with: godot --headless --path . res://tools/sprite_forge.tscn


func _ready() -> void:
	var errors := SpriteArt.validation_errors()
	if not errors.is_empty():
		for error in errors:
			printerr("Bad sprite: %s" % error)
		get_tree().quit(1)
		return

	if not DirAccess.dir_exists_absolute(SpriteArt.OUTPUT_DIRECTORY):
		var make_result := DirAccess.make_dir_recursive_absolute(SpriteArt.OUTPUT_DIRECTORY)
		if make_result != OK:
			printerr("Could not create %s" % SpriteArt.OUTPUT_DIRECTORY)
			get_tree().quit(1)
			return

	var sprites := SpriteArt.all_sprites()
	var written := 0
	for sprite_name in sprites:
		if _write_sprite(str(sprite_name), sprites[sprite_name]):
			written += 1
		else:
			get_tree().quit(1)
			return

	_write_contact_sheet(sprites)
	print("Forged %d sprites into %s" % [written, SpriteArt.OUTPUT_DIRECTORY])
	get_tree().quit(0)


## A scaled-up sheet of everything, purely so the art can be eyeballed at once.
func _write_contact_sheet(sprites: Dictionary) -> void:
	## Must stay >= the largest sprite grid (ability VFX frames run up to 48x48) — a smaller
	## CELL makes inset below go negative and set_pixel starts writing outside the sheet.
	const CELL := 48
	const ZOOM := 4
	const COLUMNS := 6
	var rows := ceili(float(sprites.size()) / float(COLUMNS))
	var sheet := Image.create(COLUMNS * CELL * ZOOM, rows * CELL * ZOOM, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101725"))

	var index := 0
	for sprite_name in sprites:
		var sprite: Dictionary = sprites[sprite_name]
		var art: Array = sprite.rows
		var palette: Dictionary = sprite.palette
		var size: int = art.size()
		var cell_x := (index % COLUMNS) * CELL * ZOOM
		var cell_y := (index / COLUMNS) * CELL * ZOOM
		var inset := maxi(0, (CELL - size) * ZOOM / 2)
		for y in size:
			var row: String = art[y]
			for x in size:
				var character := row[x]
				if character == ".":
					continue
				var color := Color(str(palette[character]))
				for zoom_y in ZOOM:
					for zoom_x in ZOOM:
						sheet.set_pixel(cell_x + inset + x * ZOOM + zoom_x, cell_y + inset + y * ZOOM + zoom_y, color)
		index += 1

	sheet.save_png("%s/_contact_sheet.png" % SpriteArt.OUTPUT_DIRECTORY)


func _write_sprite(sprite_name: String, sprite: Dictionary) -> bool:
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

	var path := "%s/%s.png" % [SpriteArt.OUTPUT_DIRECTORY, sprite_name]
	var result := image.save_png(path)
	if result != OK:
		printerr("Could not write %s" % path)
		return false
	return true

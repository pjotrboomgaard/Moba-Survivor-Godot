extends SceneTree

func _init() -> void:
	var art = load("res://tools/sprite_art.gd")
	var errors = art.validation_errors()
	if errors.is_empty():
		print("No sprite validation errors")
	else:
		for e in errors:
			printerr("Bad: " + str(e))
	var all = art.all_sprites()
	print("Total sprites: " + str(all.size()))
	if all.has("splitter_small"):
		print("splitter_small: OK, " + str(all["splitter_small"].rows.size()) + " rows")
	else:
		printerr("splitter_small: MISSING")
	if all.has("splitter_tiny"):
		print("splitter_tiny: OK, " + str(all["splitter_tiny"].rows.size()) + " rows")
	else:
		printerr("splitter_tiny: MISSING")
	quit()

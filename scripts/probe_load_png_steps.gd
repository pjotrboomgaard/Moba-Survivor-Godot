extends SceneTree

# Replicates SpriteLibrary._load_png step-by-step for the directional sprites,
# printing exactly which branch fires and what sizes come out, so we can see
# where arclight/bulwark diverge from warden.

func _init() -> void:
	var dir := "res://assets/sprites"
	for name in ["arclight_right", "bulwark_right", "warden_right", "arclight", "bulwark", "warden"]:
		var path := "%s/%s.png" % [dir, name]
		print("[probe] ===== %s =====" % name)
		print("[probe]   ResourceLoader.exists=%s" % str(ResourceLoader.exists(path)))
		var imported: Texture2D = load(path) as Texture2D
		if imported != null:
			print("[probe]   load() -> %dx%d resource_path=%s" % [imported.get_width(), imported.get_height(), imported.resource_path])
		else:
			print("[probe]   load() -> null")
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			print("[probe]   FileAccess bytes_len=%d" % bytes.size())
			var image := Image.new()
			var err := image.load_png_from_buffer(bytes)
			if err == OK:
				print("[probe]   load_png_from_buffer -> %dx%d" % [image.get_width(), image.get_height()])
				if imported != null:
					var sizes_match := imported.get_width() == image.get_width() and imported.get_height() == image.get_height()
					print("[probe]   sizes_match(imported vs disk)=%s  => returns %s" % [
						str(sizes_match),
						"imported(load)" if sizes_match else "ImageTexture(disk re-read)"
					])
			else:
				print("[probe]   load_png_from_buffer FAILED err=%d" % err)
		else:
			print("[probe]   FileAccess.file_exists=false")
	quit(0)

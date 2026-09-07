extends SceneTree

## Crops a rectangular region out of a source PNG and saves it as its own PNG.
## Used to pull a single sprite cell out of a multi-sprite reference sheet before
## running it through asset_pipeline.gd.
##
## Run: godot --headless --path . --script res://tools/asset_crop.gd -- <input_png> <output_png> <x> <y> <w> <h> [scale]
## `scale` (optional, default 1) nearest-neighbor upscales the crop after cutting it,
## which is useful for previewing a tiny source cell at a readable size.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		printerr("Usage: godot --headless --path . --script res://tools/asset_crop.gd -- <input_png> <output_png> <x> <y> <w> <h> [scale]")
		quit(1)
		return

	var input_path: String = args[0]
	var output_path: String = args[1]
	var x: int = int(args[2])
	var y: int = int(args[3])
	var w: int = int(args[4])
	var h: int = int(args[5])
	var scale: int = 1
	if args.size() >= 7:
		scale = max(1, int(args[6]))

	var src := Image.new()
	var err: int = src.load(input_path)
	if err != OK:
		printerr("ERROR: could not load '%s' (error %d)" % [input_path, err])
		quit(1)
		return

	var sw: int = src.get_width()
	var sh: int = src.get_height()
	print("=== ASSET CROP ===")
	print("  Input:  %s (%dx%d)" % [input_path, sw, sh])
	print("  Region: x=%d y=%d w=%d h=%d" % [x, y, w, h])

	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in range(h):
		for px in range(w):
			var sx: int = x + px
			var sy: int = y + py
			if sx >= 0 and sx < sw and sy >= 0 and sy < sh:
				out.set_pixel(px, py, src.get_pixel(sx, sy))

	if scale > 1:
		var scaled := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
		for py in range(h * scale):
			for px in range(w * scale):
				scaled.set_pixel(px, py, out.get_pixel(px / scale, py / scale))
		out = scaled

	var parent := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	var save_err: int = out.save_png(output_path)
	if save_err != OK:
		printerr("ERROR: failed to save %s (error %d)" % [output_path, save_err])
		quit(1)
		return
	print("  Output: %s (%dx%d)" % [output_path, out.get_width(), out.get_height()])
	print("  CROP OK")
	quit(0)

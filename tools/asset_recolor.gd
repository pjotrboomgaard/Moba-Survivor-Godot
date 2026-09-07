extends SceneTree

## Remaps a quantized pixel-art PNG onto a different (biome-themed) color palette
## while preserving its shape/shading structure and alpha channel.
##
## Run: godot --headless --path . --script res://tools/asset_recolor.gd -- <input_png> <output_png> <hex1,hex2,...>
##
## The source image's distinct colors are ranked by luminance (dark -> light).
## The comma-separated target hex list is ranked by luminance the same way.
## Each source color is then remapped to the target color at the proportionally
## equivalent luminance rank, so a dark outline stays the darkest tone, the
## brightest highlight stays the brightest tone, etc. — the same trick the
## project's existing tools/tobor_world_art.gd palette swaps rely on, just
## applied to an arbitrary already-baked PNG instead of a hand-authored row grid.

const WEIGHT_R: float = 0.2989
const WEIGHT_G: float = 0.5870
const WEIGHT_B: float = 0.1140


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("Usage: godot --headless --path . --script res://tools/asset_recolor.gd -- <input_png> <output_png> <hex1,hex2,...>")
		quit(1)
		return

	var input_path: String = args[0]
	var output_path: String = args[1]
	var hex_list: PackedStringArray = args[2].split(",")

	var src := Image.new()
	var err: int = src.load(input_path)
	if err != OK:
		printerr("ERROR: could not load '%s' (error %d)" % [input_path, err])
		quit(1)
		return

	var target_colors: Array = []
	for h in hex_list:
		var clean: String = h.strip_edges().lstrip("#")
		if clean.is_empty():
			continue
		target_colors.append(Color.html(clean))
	target_colors.sort_custom(func(a, b): return _luma(a) < _luma(b))
	if target_colors.is_empty():
		printerr("ERROR: no target colors parsed from '%s'" % args[2])
		quit(1)
		return

	var w: int = src.get_width()
	var h: int = src.get_height()

	# Collect distinct source colors (8-bit rounded, ignoring alpha) present in
	# non-fully-transparent pixels.
	var seen := {}
	for y in range(h):
		for x in range(w):
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var key: String = "%02X%02X%02X" % [int(c.r * 255.0 + 0.5), int(c.g * 255.0 + 0.5), int(c.b * 255.0 + 0.5)]
			if not seen.has(key):
				seen[key] = c

	var source_keys: Array = seen.keys()
	source_keys.sort_custom(func(a, b): return _luma(seen[a]) < _luma(seen[b]))

	var remap := {}
	var n_src: int = source_keys.size()
	var n_dst: int = target_colors.size()
	for i in range(n_src):
		var t_index: int = 0
		if n_src > 1:
			t_index = int(round(float(i) * float(n_dst - 1) / float(n_src - 1)))
		remap[source_keys[i]] = target_colors[clampi(t_index, 0, n_dst - 1)]

	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.001:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var key: String = "%02X%02X%02X" % [int(c.r * 255.0 + 0.5), int(c.g * 255.0 + 0.5), int(c.b * 255.0 + 0.5)]
			var new_c: Color = remap.get(key, c)
			out.set_pixel(x, y, Color(new_c.r, new_c.g, new_c.b, c.a))

	var parent := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	var save_err: int = out.save_png(output_path)
	if save_err != OK:
		printerr("ERROR: failed to save %s (error %d)" % [output_path, save_err])
		quit(1)
		return

	print("=== ASSET RECOLOR ===")
	print("  Input:   %s" % input_path)
	print("  Output:  %s" % output_path)
	print("  Source colors: %d  Target palette: %d" % [n_src, n_dst])
	print("  RECOLOR OK")
	quit(0)


func _luma(c: Color) -> float:
	return WEIGHT_R * c.r + WEIGHT_G * c.g + WEIGHT_B * c.b

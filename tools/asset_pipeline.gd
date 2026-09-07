extends SceneTree

## Pixel-art downscale + palette-quantize pipeline.
## Run: godot --headless --path . res://tools/asset_pipeline.gd <input_png> <output_png> [target_size] [palette_size]
##
## Takes a high-res pixel-art PNG, downsamples it to a target square grid
## (default 16x16) via box-average, then quantizes it to a palette of N
## dominant colors (default 8) with a small k-means loop. Writes the
## quantized image, a side-by-side comparison image, and prints the
## extracted palette with per-color usage counts.

const DEFAULT_TARGET_SIZE: int = 16
const DEFAULT_PALETTE_SIZE: int = 8
const KMEANS_ITERATIONS: int = 10


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var input_path: String = ""
	var output_path: String = ""
	var target_size: int = DEFAULT_TARGET_SIZE
	var palette_size: int = DEFAULT_PALETTE_SIZE

	if args.size() >= 2:
		input_path = args[0]
		output_path = args[1]
		if args.size() >= 3:
			target_size = int(args[2])
		if args.size() >= 4:
			palette_size = int(args[3])
	else:
		printerr("Usage: godot --headless --path . res://tools/asset_pipeline.gd <input_png> <output_png> [target_size] [palette_size]")
		quit(1)
		return

	var input_img: Image = _load_image(input_path)
	if input_img.is_empty():
		quit(1)
		return

	print("=== ASSET PIPELINE ===")
	print("  Input:      %s" % input_path)
	print("  Output:     %s" % output_path)
	print("  Source:     %dx%d" % [input_img.get_width(), input_img.get_height()])
	print("  Target:     %dx%d" % [target_size, target_size])
	print("  Palette:    %d colors" % palette_size)
	print("")

	var downscaled: Image = _box_average_downscale(input_img, target_size)
	var quantized: Image = _quantize(downscaled, palette_size)

	# Save quantized output
	var out_dir := _ensure_parent_dir(output_path)
	var err: int = quantized.save_png(output_path)
	if err != OK:
		printerr("ERROR: failed to save %s (error %d)" % [output_path, err])
		quit(1)
		return
	print("  Quantized -> %s" % output_path)

	# Side-by-side comparison: original (left) | quantized (right)
	var compare_path := output_path.get_basename() + "_compare.png"
	var compare_img: Image = _make_comparison(input_img, quantized)
	if compare_img.save_png(compare_path) == OK:
		print("  Compare   -> %s" % compare_path)

	# Palette report — derived from the quantized image's actual stored (8-bit
	# rounded) pixels rather than the pre-rounding float centroids, so the
	# reported hex values and usage counts always match what got saved.
	var usage := _count_palette_usage(quantized)
	var hex_keys: Array = usage.keys()
	hex_keys.sort_custom(func(a, b): return usage[a] > usage[b])
	print("")
	print("  Extracted palette (%d colors):" % hex_keys.size())
	for i in range(hex_keys.size()):
		var hex: String = hex_keys[i]
		print("    [%d] #%s   used %d px" % [i, hex, usage[hex]])
	print("")
	print("  PIPELINE OK")
	print("")

	quit(0)


func _load_image(path: String) -> Image:
	var img := Image.new()
	var err: int = img.load(path)
	if err != OK:
		printerr("ERROR: could not load '%s' (error %d)" % [path, err])
		return Image.new()
	return img


func _ensure_parent_dir(file_path: String) -> String:
	var parent := file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	return parent


## Downscale to target_size x target_size using a box average (area-average
## over the source region that maps to each target pixel). Preserves the
## source aspect by letterboxing to a square first.
func _box_average_downscale(src: Image, target: int) -> Image:
	var sw: int = src.get_width()
	var sh: int = src.get_height()
	# Fit into a square without distortion (center-crop the larger axis)
	var crop_w: int = min(sw, sh)
	var crop_h: int = crop_w
	var off_x: int = (sw - crop_w) / 2
	var off_y: int = (sh - crop_h) / 2

	var out := Image.create(target, target, false, Image.FORMAT_RGBA8)

	for ty in range(target):
		for tx in range(target):
			# Map target cell to source pixel region
			var x0: int = off_x + int(float(tx) * crop_w / float(target))
			var y0: int = off_y + int(float(ty) * crop_h / float(target))
			var x1: int = off_x + int(float(tx + 1) * crop_w / float(target))
			var y1: int = off_y + int(float(ty + 1) * crop_h / float(target))
			if x1 <= x0:
				x1 = x0 + 1
			if y1 <= y0:
				y1 = y0 + 1

			var acc_r: float = 0.0
			var acc_g: float = 0.0
			var acc_b: float = 0.0
			var acc_a: float = 0.0
			var count: int = 0
			for py in range(y0, y1):
				for px in range(x0, x1):
					if px >= sw or py >= sh:
						continue
					var c: Color = src.get_pixel(px, py)
					acc_r += c.r
					acc_g += c.g
					acc_b += c.b
					acc_a += c.a
					count += 1

			if count > 0:
				out.set_pixel(tx, ty, Color(acc_r / count, acc_g / count, acc_b / count, acc_a / count))
	return out


## Quantize the image to `n_colors` palette entries with a small k-means
## (10 iterations), seeded by a coarse color-bucket sampling.
func _quantize(img: Image, n_colors: int) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()

	# Collect all pixel colors (opaque or semi-opaque) as flat arrays
	var n: int = w * h
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	var bs := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	rs.resize(n)
	gs.resize(n)
	bs.resize(n)
	alphas.resize(n)
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			var c: Color = img.get_pixel(x, y)
			rs[i] = c.r
			gs[i] = c.g
			bs[i] = c.b
			alphas[i] = c.a

	var centroids: Array = _init_centroids(rs, gs, bs, n_colors)

	for _iter in range(KMEANS_ITERATIONS):
		# Assignment
		var sums_r := PackedFloat32Array()
		var sums_g := PackedFloat32Array()
		var sums_b := PackedFloat32Array()
		var counts := PackedInt32Array()
		sums_r.resize(centroids.size())
		sums_g.resize(centroids.size())
		sums_b.resize(centroids.size())
		counts.resize(centroids.size())
		for i in range(n):
			var best: int = 0
			var best_d: float = INF
			for ci in range(centroids.size()):
				var c0: Vector3 = centroids[ci]
				var dr: float = rs[i] - c0.x
				var dg: float = gs[i] - c0.y
				var db: float = bs[i] - c0.z
				var d: float = dr * dr + dg * dg + db * db
				if d < best_d:
					best_d = d
					best = ci
			sums_r[best] += rs[i]
			sums_g[best] += gs[i]
			sums_b[best] += bs[i]
			counts[best] += 1

		# Update; seed empty clusters from the farthest unassigned pixel
		for ci in range(centroids.size()):
			if counts[ci] > 0:
				centroids[ci] = Vector3(sums_r[ci] / counts[ci], sums_g[ci] / counts[ci], sums_b[ci] / counts[ci])
			else:
				centroids[ci] = _farthest_seed(centroids, rs, gs, bs)

	# Final assignment into a palette image
	var palette: PackedColorArray = PackedColorArray()
	for c0 in centroids:
		var col: Color = Color(clampf(c0.x, 0.0, 1.0), clampf(c0.y, 0.0, 1.0), clampf(c0.z, 0.0, 1.0), 1.0)
		palette.append(col)

	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			var best: int = 0
			var best_d: float = INF
			for ci in range(palette.size()):
				var c0: Color = palette[ci]
				var dr: float = rs[i] - c0.r
				var dg: float = gs[i] - c0.g
				var db: float = bs[i] - c0.b
				var d: float = dr * dr + dg * dg + db * db
				if d < best_d:
					best_d = d
					best = ci
			out.set_pixel(x, y, Color(palette[best].r, palette[best].g, palette[best].b, alphas[i]))
	return out


## Seed centroids by sampling the color space into a 4x4x4 grid and picking
## the most populous cells.
func _init_centroids(rs: PackedFloat32Array, gs: PackedFloat32Array, bs: PackedFloat32Array, n_colors: int) -> Array:
	var n: int = rs.size()
	var cells := {}
	var order: Array = []
	for i in range(n):
		var key: Vector3i = Vector3i(int(rs[i] * 3.999), int(gs[i] * 3.999), int(bs[i] * 3.999))
		if not cells.has(key):
			cells[key] = []
			order.append(key)
		cells[key].append(i)

	# Sort cells by population (descending) and take the most populated
	order.sort_custom(func(a, b): return cells[a].size() > cells[b].size())

	var centroids: Array = []
	for key in order:
		if centroids.size() >= n_colors:
			break
		var members: Array = cells[key]
		var ar: float = 0.0
		var ag: float = 0.0
		var ab: float = 0.0
		for idx in members:
			ar += rs[idx]
			ag += gs[idx]
			ab += bs[idx]
		var m: int = members.size()
		centroids.append(Vector3(ar / m, ag / m, ab / m))

	# Fill remaining centroids with deterministic jitter if not enough cells
	var idx: int = 0
	while centroids.size() < n_colors:
		var c: Vector3 = Vector3(
			fposmod(float(idx * 2654435761), 1024.0) / 1023.0,
			fposmod(float((idx + 1) * 2246822519), 1024.0) / 1023.0,
			fposmod(float((idx + 2) * 3266489917), 1024.0) / 1023.0
		)
		centroids.append(c)
		idx += 1
	return centroids


## Pick the pixel farthest from the current centroids to reseed an empty one.
func _farthest_seed(centroids: Array, rs: PackedFloat32Array, gs: PackedFloat32Array, bs: PackedFloat32Array) -> Vector3:
	var n: int = rs.size()
	var step: int = max(1, n / 512)
	var best: int = 0
	var best_d: float = -1.0
	for i in range(0, n, step):
		var min_d: float = INF
		for c0 in centroids:
			var dr: float = rs[i] - c0.x
			var dg: float = gs[i] - c0.y
			var db: float = bs[i] - c0.z
			var d: float = dr * dr + dg * dg + db * db
			if d < min_d:
				min_d = d
		if min_d > best_d:
			best_d = min_d
			best = i
	return Vector3(rs[best], gs[best], bs[best])


## Counts distinct colors actually present in the image, keyed by their
## realized 8-bit hex value (post RGBA8-format rounding).
func _count_palette_usage(img: Image) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var usage := {}
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var key: String = "%02X%02X%02X" % [int(c.r * 255.0 + 0.5), int(c.g * 255.0 + 0.5), int(c.b * 255.0 + 0.5)]
			usage[key] = usage.get(key, 0) + 1
	return usage


func _make_comparison(original: Image, quantized: Image) -> Image:
	# Scale original to match quantized dimensions for a clean side-by-side
	var qw: int = quantized.get_width()
	var qh: int = quantized.get_height()
	var orig_s := original.duplicate() as Image
	orig_s.resize(qw, qh, Image.INTERPOLATE_BILINEAR)

	var gap: int = 2
	var total_w: int = qw + gap + qw
	var out := Image.create(total_w, qh, false, Image.FORMAT_RGBA8)
	for y in range(qh):
		for x in range(total_w):
			var c: Color = Color(0.15, 0.15, 0.18, 1.0)
			if x < qw:
				c = orig_s.get_pixel(x, y)
			elif x >= qw + gap:
				c = quantized.get_pixel(x - qw - gap, y)
			out.set_pixel(x, y, c)
	return out

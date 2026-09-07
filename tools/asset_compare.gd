extends SceneTree

## Asset similarity comparator.
## Run: godot --headless --path . res://tools/asset_compare.gd <source_png> <game_asset_png> [threshold]
##
## Compares two PNG images pixel-by-pixel after rescaling the source to the
## game asset's dimensions (nearest-neighbor). Outputs a JSON report to
## tools/selftest/results/asset_compare.json and a human-readable summary.
## Exits 0 if perceptual similarity >= threshold, 1 otherwise.

const WEIGHT_R: float = 0.2989
const WEIGHT_G: float = 0.5870
const WEIGHT_B: float = 0.1140
const DEFAULT_THRESHOLD: float = 0.70
const DEFAULT_TOLERANCE: float = 0.30
const BLOCK_SIZE: int = 4
const RESULTS_PATH: String = "res://tools/selftest/results/asset_compare.json"
const SQRT_3: float = 1.7320508075688772


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	# args are everything after the script path
	var source_path: String = ""
	var game_path: String = ""
	var threshold: float = DEFAULT_THRESHOLD
	var tolerance: float = DEFAULT_TOLERANCE

	if args.size() >= 2:
		source_path = args[0]
		game_path = args[1]
		if args.size() >= 3:
			threshold = float(args[2])
		if args.size() >= 4:
			tolerance = float(args[3])
	else:
		printerr("Usage: godot --headless --path . res://tools/asset_compare.gd <source_png> <game_asset_png> [threshold] [tolerance]")
		printerr("  source_png      - reference image to compare against (web/original)")
		printerr("  game_asset_png  - in-game baked asset to check")
		printerr("  threshold       - min perceptual similarity to pass (default 0.70)")
		printerr("  tolerance       - normalized per-pixel distance for 'within tolerance' (default 0.30)")
		quit(1)
		return

	var source_img: Image = _load_image(source_path)
	var game_img: Image = _load_image(game_path)

	if source_img.is_empty() or game_img.is_empty():
		printerr("ERROR: Could not load both images.")
		quit(1)
		return

	# Rescale source to match game asset dimensions (nearest-neighbor)
	var target_size := game_img.get_size()
	var source_rescaled: Image = source_img.duplicate() as Image
	source_rescaled.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)

	# Compute metrics
	var result: Dictionary = _compute_metrics(source_rescaled, game_img, tolerance)
	result["source_path"] = source_path
	result["game_path"] = game_path
	result["source_original_size"] = [source_img.get_width(), source_img.get_height()]
	result["game_size"] = [game_img.get_width(), game_img.get_height()]
	result["threshold"] = threshold
	result["tolerance"] = tolerance

	# Write JSON report
	_write_report(result)

	# Print human summary
	_print_summary(result, threshold)

	var passed: bool = result["perceptual_similarity"] >= threshold
	quit(0 if passed else 1)


func _load_image(path: String) -> Image:
	var img := Image.new()
	var err: int = img.load(path)
	if err != OK:
		printerr("ERROR: Failed to load image '%s' (error code %d)" % [path, err])
		return Image.new()
	return img


func _compute_metrics(a: Image, b: Image, tolerance: float) -> Dictionary:
	var w: int = a.get_width()
	var h: int = a.get_height()
	var pixel_count: int = w * h

	var mad_r: float = 0.0
	var mad_g: float = 0.0
	var mad_b: float = 0.0
	var perceptual_sum: float = 0.0
	var within_tolerance_count: int = 0

	for y in range(h):
		for x in range(w):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)

			var dr: float = absf(ca.r - cb.r)
			var dg: float = absf(ca.g - cb.g)
			var db: float = absf(ca.b - cb.b)

			mad_r += dr
			mad_g += dg
			mad_b += db

			# Perceptual difference (weighted)
			var pd: float = absf(WEIGHT_R * dr + WEIGHT_G * dg + WEIGHT_B * db)
			perceptual_sum += pd

			# Normalized Euclidean distance in RGB (0..sqrt(3))
			var dist: float = sqrt(dr * dr + dg * dg + db * db) / SQRT_3
			if dist <= tolerance:
				within_tolerance_count += 1

	var mad_overall: float = (mad_r + mad_g + mad_b) / (3.0 * pixel_count)
	var perceptual_similarity: float = 1.0 - perceptual_sum / float(pixel_count)
	var within_tolerance_pct: float = float(within_tolerance_count) / float(pixel_count)

	# Structural check: downsampled 4x4 block averages
	var block_mad: float = _compute_block_mad(a, b)

	return {
		"mad_red": mad_r / float(pixel_count),
		"mad_green": mad_g / float(pixel_count),
		"mad_blue": mad_b / float(pixel_count),
		"mad_overall": mad_overall,
		"perceptual_similarity": perceptual_similarity,
		"within_tolerance_pct": within_tolerance_pct,
		"block_mad": block_mad,
		"pixel_count": pixel_count,
	}


func _compute_block_mad(a: Image, b: Image) -> float:
	var w: int = a.get_width()
	var h: int = a.get_height()
	var block_w: int = maxf(1.0, float(w) / float(BLOCK_SIZE))
	var block_h: int = maxf(1.0, float(h) / float(BLOCK_SIZE))

	var blocks_x: int = int(ceil(float(w) / block_w))
	var blocks_y: int = int(ceil(float(h) / block_h))

	var total_blocks: int = blocks_x * blocks_y
	var mad_sum: float = 0.0

	for by in range(blocks_y):
		for bx in range(blocks_x):
			var x0: int = int(bx * block_w)
			var y0: int = int(by * block_h)
			var x1: int = min(int(x0 + block_w), w)
			var y1: int = min(int(y0 + block_h), h)

			var sum_a := Vector3(0, 0, 0)
			var sum_b := Vector3(0, 0, 0)
			var count: int = 0

			for py in range(y0, y1):
				for px in range(x0, x1):
					var ca: Color = a.get_pixel(px, py)
					var cb: Color = b.get_pixel(px, py)
					sum_a += Vector3(ca.r, ca.g, ca.b)
					sum_b += Vector3(cb.r, cb.g, cb.b)
					count += 1

			if count > 0:
				var avg_a := sum_a / float(count)
				var avg_b := sum_b / float(count)
				mad_sum += (avg_a - avg_b).length()

	return mad_sum / float(total_blocks) if total_blocks > 0 else 0.0


func _write_report(result: Dictionary) -> void:
	var dir := "res://tools/selftest/results"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var json_str: String = JSON.stringify(result, "\t")
	var f := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
		print("  JSON report -> ", RESULTS_PATH)
	else:
		printerr("  WARNING: Could not write report to ", RESULTS_PATH)


func _print_summary(result: Dictionary, threshold: float) -> void:
	print("")
	print("=== ASSET COMPARISON ===")
	print("  Source:            %s" % result.get("source_path", ""))
	print("  Game asset:        %s" % result.get("game_path", ""))
	print("  Source size:       %s" % str(result.get("source_original_size", [])))
	print("  Game size:         %s" % str(result.get("game_size", [])))
	print("")
	print("  MAD (R/G/B/avg):   %.4f / %.4f / %.4f / %.4f" % [
		result["mad_red"], result["mad_green"], result["mad_blue"], result["mad_overall"]
	])
	print("  Perceptual sim:    %.4f  (threshold %.4f)" % [result["perceptual_similarity"], threshold])
	print("  Within tolerance:  %.1f%%" % (result["within_tolerance_pct"] * 100.0))
	print("  Block MAD:         %.4f" % result["block_mad"])
	print("")

	var passed: bool = result["perceptual_similarity"] >= threshold
	if passed:
		print("  RESULT: PASS (similarity %.4f >= %.4f)" % [result["perceptual_similarity"], threshold])
	else:
		print("  RESULT: FAIL (similarity %.4f < %.4f)" % [result["perceptual_similarity"], threshold])
	print("")

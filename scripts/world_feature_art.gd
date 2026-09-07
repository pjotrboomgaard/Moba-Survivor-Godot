class_name WorldFeatureArt
extends RefCounted

## Slow scenery loops (2 FPS). Frames are built at runtime so biome landmarks
## do not depend on a sprite-forge import pass.

const ALL_IDS: PackedStringArray = [
	"grass_waterfall", "grass_campfire", "grass_pond",
	"volcano_plume", "lava_fall", "ember_crack",
	"ice_geyser", "ice_fall", "aurora_spire",
	"factory_stack", "spark_coil", "warning_lamp",
	"docks_wave", "lighthouse", "dock_lantern",
]

const LABELS := {
	"grass_waterfall": "Waterfall",
	"grass_campfire": "Campfire",
	"grass_pond": "Lily pond",
	"volcano_plume": "Volcano",
	"lava_fall": "Lava fall",
	"ember_crack": "Ember crack",
	"ice_geyser": "Geyser",
	"ice_fall": "Ice fall",
	"aurora_spire": "Aurora",
	"factory_stack": "Smokestack",
	"spark_coil": "Spark coil",
	"warning_lamp": "Lamp",
	"docks_wave": "Waves",
	"lighthouse": "Lighthouse",
	"dock_lantern": "Lantern",
}

static var _preview_cache: Dictionary = {}


static func is_feature(feature_id: String) -> bool:
	return ALL_IDS.has(feature_id)


static func feature_ids_for_biome(biome_id: int) -> PackedStringArray:
	match biome_id:
		1:
			return PackedStringArray(["volcano_plume", "lava_fall", "ember_crack"])
		2:
			return PackedStringArray(["ice_geyser", "ice_fall", "aurora_spire"])
		3:
			return PackedStringArray(["factory_stack", "spark_coil", "warning_lamp"])
		4:
			return PackedStringArray(["docks_wave", "lighthouse", "dock_lantern"])
		_:
			return PackedStringArray(["grass_waterfall", "grass_campfire", "grass_pond"])


static func frames_for(feature_id: String) -> Array[Texture2D]:
	var spec := _spec(feature_id)
	var out: Array[Texture2D] = []
	for rows in spec.frames:
		out.append(SpriteLibrary.texture_from_rows(rows, spec.palette))
	return out


static func zoom_for(feature_id: String) -> float:
	# Spec zooms were tuned for 24px frames. Painters are 48px now; scale so
	# world size matches the old footprint and texels stay finer, not blown up.
	return float(_spec(feature_id).get("zoom", 10.0)) * 0.5


static func preview_texture(feature_id: String) -> Texture2D:
	if _preview_cache.has(feature_id):
		return _preview_cache[feature_id]
	var frames := frames_for(feature_id)
	var tex: Texture2D = frames[0] if not frames.is_empty() else null
	_preview_cache[feature_id] = tex
	return tex


static func _spec(feature_id: String) -> Dictionary:
	match feature_id:
		"grass_campfire":
			return {"palette": _CAMP, "frames": _campfire_frames(), "zoom": 9.0}
		"grass_pond":
			return {"palette": _GRASS, "frames": _pond_frames(), "zoom": 10.0}
		"volcano_plume":
			return {"palette": _VOLCANO, "frames": _volcano_frames(), "zoom": 13.0}
		"lava_fall":
			return {"palette": _VOLCANO, "frames": _lava_fall_frames(), "zoom": 11.0}
		"ember_crack":
			return {"palette": _VOLCANO, "frames": _ember_frames(), "zoom": 9.0}
		"ice_geyser":
			return {"palette": _ICE, "frames": _geyser_frames(), "zoom": 12.0}
		"ice_fall":
			return {"palette": _ICE, "frames": _ice_fall_frames(), "zoom": 11.0}
		"aurora_spire":
			return {"palette": _AURORA, "frames": _aurora_frames(), "zoom": 12.0}
		"factory_stack":
			return {"palette": _FACTORY, "frames": _stack_frames(), "zoom": 12.0}
		"spark_coil":
			return {"palette": _FACTORY, "frames": _coil_frames(), "zoom": 10.0}
		"warning_lamp":
			return {"palette": _FACTORY, "frames": _lamp_frames(), "zoom": 9.0}
		"docks_wave":
			return {"palette": _DOCKS, "frames": _wave_frames(), "zoom": 12.0}
		"lighthouse":
			return {"palette": _DOCKS, "frames": _lighthouse_frames(), "zoom": 13.0}
		"dock_lantern":
			return {"palette": _DOCKS, "frames": _lantern_frames(), "zoom": 9.0}
		_:
			return {"palette": _GRASS, "frames": _waterfall_frames(), "zoom": 12.0}


const _GRASS := {
	"r": "3a3228", "s": "5a4c3e", "d": "2a241c",
	"w": "4a8ab8", "l": "8ec8e8", "f": "d8f0f8",
	"g": "3a6130", "p": "2f4f26",
}
const _CAMP := {
	"r": "5a3a22", "s": "3a2818", "d": "1a120c",
	"w": "e85a2a", "l": "ffe14a", "f": "fff6d0",
	"g": "3a6130", "p": "2f4f26",
}
const _VOLCANO := {
	"r": "2a1612", "s": "3d2218", "d": "1a0c08",
	"w": "c43018", "l": "e85a2a", "f": "ffe14a",
	"g": "4a2014", "p": "ff7a29",
}
const _ICE := {
	"r": "8ab0c8", "s": "c8dcec", "d": "5a7088",
	"w": "7fd4ff", "l": "d0e8f6", "f": "ffffff",
	"g": "9cbcd4", "p": "e8f6ff",
}
const _AURORA := {
	"r": "6a88a8", "s": "c8dcec", "d": "3a5068",
	"w": "7ff0c8", "l": "c8a0ff", "f": "ffffff",
	"g": "9cbcd4", "p": "e8f6ff",
}
const _FACTORY := {
	"r": "2c3038", "s": "3e4650", "d": "1a1e24",
	"w": "8b95a1", "l": "dfe6f2", "f": "2bbfbe",
	"g": "5a6270", "p": "e85a2a",
}
const _DOCKS := {
	"r": "6b4a1a", "s": "8a6230", "d": "3a2a10",
	"w": "2f8fb0", "l": "7fd4ff", "f": "dfe6f2",
	"g": "c9a227", "p": "4f8fe0",
}


static func _waterfall_frames() -> Array:
	return _phase_frames(_waterfall_pixel)


static func _waterfall_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y < 10:
		var lip := 16 - int(y * 0.7)
		if abs(x - cx) <= lip:
			if y <= 2:
				return "r"
			if y <= 5:
				return "s" if posmod(x, 3) == 0 else "r"
			return "s"
		return "g" if abs(x - cx) <= lip + 3 and y > 6 else "."
	if y < 14:
		if abs(x - cx) <= 10:
			return "d" if abs(x - cx) <= 6 else "r"
		return "g" if abs(x - cx) <= 16 else "."
	if y >= 40:
		if abs(x - cx) <= 18:
			var foam := posmod(x + phase * 2, 4)
			if y == 40:
				return "f" if foam == 0 else "l"
			if foam == 0:
				return "f"
			return "p" if foam == 1 else "g"
		return "g" if abs(x - cx) <= 22 else "."
	# twin rivulets with spray
	var left := x >= 14 and x <= 21
	var right := x >= 26 and x <= 33
	if left or right:
		var stream := posmod(x + y + phase, 4)
		if stream == 0:
			return "f"
		if stream == 1:
			return "l"
		if abs(x - 17) <= 1 or abs(x - 30) <= 1:
			return "w"
		return "w" if posmod(y + phase, 3) else "l"
	if x == 13 or x == 22 or x == 25 or x == 34:
		return "s" if posmod(y, 2) == 0 else "r"
	if y > 36 and abs(x - cx) <= 20:
		return "g"
	if (x <= 10 or x >= 38) and y > 20 and posmod(x + y, 5) == 0:
		return "g"
	return "."


static func _campfire_frames() -> Array:
	return _phase_frames(_campfire_pixel)


static func _campfire_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y >= 40:
		if abs(x - cx) <= 10:
			return "r" if posmod(x, 2) == 0 else "s"
		return "g" if abs(x - cx) <= 14 else "."
	if y >= 38 and abs(x - cx) <= 8:
		return "d"
	# crossed logs
	if y >= 36 and y <= 37 and abs(x - cx) <= 7:
		return "s" if posmod(x + y, 2) == 0 else "r"
	var flame_h := 10 + phase * 2
	var tip := 36 - flame_h
	if y >= tip and y < 36:
		var t := float(36 - y) / float(max(1, flame_h))
		var half := 1 + int((1.0 - t) * 4.0)
		if abs(x - cx) <= half:
			if y == tip:
				return "f"
			if abs(x - cx) == 0:
				return "f" if posmod(y + phase, 2) == 0 else "l"
			if abs(x - cx) == half:
				return "w"
			return "l" if posmod(x + y + phase, 2) == 0 else "w"
	# sparks
	if y == tip - 1 - posmod(phase, 2) and abs(x - cx) == 2 + phase:
		return "f"
	return "."


static func _pond_frames() -> Array:
	return _phase_frames(_pond_pixel)


static func _pond_pixel(x: int, y: int, phase: int) -> String:
	var dx := x - 24
	var dy := y - 26
	var dist: int = absi(dx) + absi(dy)
	if dist > 18:
		if dist <= 22 and y > 20:
			return "g" if posmod(x + y, 3) else "p"
		return "."
	if dist >= 16:
		return "p"
	if dist == 8 + posmod(phase, 4) or dist == 12 + posmod(phase + 1, 3):
		return "f"
	# lily pads
	if (dx == -6 and dy == -2) or (dx == 8 and dy == 4) or (dx == -2 and dy == 6):
		return "g"
	if (dx == -5 and dy == -2) or (dx == 7 and dy == 4):
		return "p"
	if posmod(x + y * 2 + phase, 7) == 0:
		return "f"
	return "l" if posmod(x + y + phase, 3) == 0 else "w"


static func _volcano_frames() -> Array:
	return _phase_frames(_volcano_pixel)


static func _volcano_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	var cone_top := 22
	var plume_h := 6 + phase * 2
	if y < cone_top:
		var column := 1 + int(y > cone_top - 4) + int(y > cone_top - 8)
		if y >= cone_top - plume_h and abs(x - cx) <= column:
			if y <= cone_top - plume_h + 1:
				return "f"
			if abs(x - cx) == column:
				return "w"
			return "l" if posmod(x + y + phase, 2) == 0 else "w"
		# drifting ash
		if y < cone_top - 2 and posmod(x + y * 3 + phase, 17) == 0 and abs(x - cx) < 10:
			return "l"
		return "."
	var spread := 4 + int(float(y - cone_top) * 0.9)
	if abs(x - cx) > spread:
		return "."
	if abs(x - cx) >= spread - 2:
		return "d" if posmod(y, 2) == 0 else "r"
	if y > 40:
		return "r" if posmod(x, 3) else "d"
	if y <= cone_top + 2 and abs(x - cx) <= 4:
		return "p" if posmod(x + phase, 2) == 0 else "f"
	if posmod(x + y, 5) == 0:
		return "s"
	if posmod(x * 2 + y, 7) == 0:
		return "d"
	return "r"


static func _lava_fall_frames() -> Array:
	return _phase_frames(_lava_fall_pixel)


static func _lava_fall_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y < 12:
		if abs(x - cx) <= 14 - int(y / 2):
			return "d" if y > 4 else "r"
		return "."
	if y >= 40:
		if abs(x - cx) <= 16:
			var pool := posmod(x + phase * 2, 3)
			if pool == 0:
				return "p"
			if pool == 1:
				return "f"
			return "w"
		return "."
	if x >= 18 and x <= 29:
		var stream := posmod(x + y + phase, 4)
		if stream == 0:
			return "f"
		if stream == 1:
			return "l"
		if stream == 2:
			return "p"
		return "w"
	if x == 16 or x == 17 or x == 30 or x == 31:
		return "s" if posmod(y, 2) == 0 else "d"
	if abs(x - cx) <= 20 and y > 36:
		return "r"
	return "."


static func _ember_frames() -> Array:
	return _phase_frames(_ember_pixel)


static func _ember_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y < 24:
		var spark_y := 16 - phase * 2
		if y >= spark_y and y < 24 and abs(x - cx) <= 1 + int(y > 20):
			if y == spark_y:
				return "f"
			return "l" if posmod(y + phase, 2) == 0 else "w"
		if y == spark_y - 2 and abs(x - cx) == 3:
			return "f"
		return "."
	if abs(x - cx) <= 12 and y >= 28:
		if abs(x - cx) <= 2:
			return "f" if posmod(y + phase, 2) == 0 else "l"
		if abs(x - cx) <= 5:
			return "w" if posmod(x, 2) == 0 else "p"
		if abs(x - cx) <= 8:
			return "d" if y >= 36 else "r"
		return "r" if y >= 40 else "."
	return "."


static func _geyser_frames() -> Array:
	return _phase_frames(_geyser_pixel)


static func _geyser_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	var mound := 32
	var jet := 8 + phase * 4
	if y >= mound:
		if abs(x - cx) <= 10:
			if abs(x - cx) <= 4:
				return "s" if posmod(x + y, 3) else "l"
			if abs(x - cx) <= 7:
				return "r"
			return "d"
		return "."
	if y >= mound - jet and abs(x - cx) <= 1 + int(y > mound - 6) + int(y > mound - 3):
		if y <= mound - jet + 1:
			return "f"
		return "l" if posmod(y + phase, 2) == 0 else "w"
	if y >= mound - 4 and abs(x - cx) <= 6:
		return "p"
	# mist
	if y < mound - jet and abs(x - cx) <= 8 and posmod(x + y + phase, 9) == 0:
		return "f"
	return "."


static func _ice_fall_frames() -> Array:
	return _phase_frames(_ice_fall_pixel)


static func _ice_fall_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y < 12:
		if abs(x - cx) <= 16 - y:
			return "s" if y > 2 else "r"
		return "."
	if y >= 40:
		if abs(x - cx) <= 16:
			return "p" if posmod(x + phase, 2) == 0 else "g"
		return "."
	# icicle columns
	if x == 20 or x == 21 or x == 26 or x == 27:
		if y == 14 + posmod(phase + x, 6):
			return "f"
		if y > 16:
			return "l" if posmod(y + phase, 2) == 0 else "w"
	if x == 18 or x == 29:
		return "s" if y > 18 else "."
	if abs(x - cx) <= 12:
		if abs(x - cx) >= 10:
			return "d"
		if posmod(x + y, 11) == 0:
			return "l"
		return "."
	return "."


static func _aurora_frames() -> Array:
	return _phase_frames(_aurora_pixel)


static func _aurora_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y >= 36:
		if abs(x - cx) <= 6:
			return "d" if abs(x - cx) >= 4 else "s"
		return "."
	if abs(x - cx) > 4:
		if y < 16 and abs(x - cx) <= 8 + posmod(phase, 3) and posmod(x + y + phase, 5) == 0:
			return "l" if posmod(phase, 2) == 0 else "w"
		return "."
	if y < 8:
		return "f" if posmod(x + phase, 3) == 0 else "l"
	var band := posmod(y + phase * 2, 6)
	if band == 0:
		return "w"
	if band == 1 or band == 2:
		return "l"
	if band == 3:
		return "f"
	return "s"


static func _stack_frames() -> Array:
	return _phase_frames(_stack_pixel)


static func _stack_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y >= 20 and abs(x - cx) <= 6:
		if abs(x - cx) >= 5:
			return "d"
		if posmod(y, 4) == 0:
			return "f"
		if posmod(y, 4) == 1:
			return "g"
		return "s" if posmod(x, 2) == 0 else "r"
	if y >= 20:
		return "."
	var puff_y := posmod(phase * 3 + (24 - y), 12)
	if puff_y < 6 and abs(x - cx) <= 3 + puff_y:
		if puff_y <= 1:
			return "f"
		if puff_y <= 3:
			return "l" if posmod(x + phase, 2) == 0 else "w"
		return "w" if posmod(x, 3) else "l"
	return "."


static func _coil_frames() -> Array:
	return _phase_frames(_coil_pixel)


static func _coil_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y >= 32 and abs(x - cx) <= 8:
		if y >= 40:
			return "d"
		return "s" if abs(x - cx) <= 5 else "g"
	if abs(x - cx) <= 4 and y >= 16 and y < 32:
		if abs(x - cx) == 4:
			return "g"
		if posmod(y, 3) == 0:
			return "f"
		if posmod(y, 3) == 1:
			return "l"
		return "r"
	var spark_y := 12 + posmod(phase * 3, 14)
	if y == spark_y and abs(x - cx) <= 2 + phase:
		return "p" if abs(x - cx) == 0 else "l"
	if y == spark_y - 1 and abs(x - cx) <= 1:
		return "f"
	if y == spark_y + 1 and abs(x - cx) == 0:
		return "w"
	return "."


static func _lamp_frames() -> Array:
	return _phase_frames(_lamp_pixel)


static func _lamp_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y >= 36 and abs(x - cx) <= 4:
		return "d" if abs(x - cx) <= 2 else "g"
	if abs(x - cx) <= 1 and y >= 16 and y < 36:
		return "s" if x == cx else "g"
	if y >= 8 and y <= 15 and abs(x - cx) <= 4:
		if abs(x - cx) == 4 or y == 8 or y == 15:
			return "g"
		if phase % 2 == 0:
			if abs(x - cx) <= 1:
				return "f"
			return "l"
		return "w" if abs(x - cx) <= 2 else "l"
	if y == 7 and abs(x - cx) <= 1:
		return "r"
	return "."


static func _wave_frames() -> Array:
	return _phase_frames(_wave_pixel)


static func _wave_pixel(x: int, y: int, phase: int) -> String:
	if y < 16:
		if abs(x - 24) <= 2 and y > 4:
			return "s" if y < 14 else "r"
		if y == 15 and abs(x - 24) <= 4:
			return "r"
		if y == 14 and abs(x - 24) <= 3:
			return "d"
		return "."
	var crest := 24 + int(sin(float(x + phase * 4) * 0.28) * 4.0)
	if y == crest:
		return "f"
	if y == crest + 1:
		return "l"
	if y > crest:
		if posmod(x + y + phase, 5) == 0:
			return "f"
		if posmod(x + y + phase, 3) == 0:
			return "l"
		return "w"
	if y == 16 and (x == 20 or x == 28):
		return "g"
	return "."


static func _lighthouse_frames() -> Array:
	return _phase_frames(_lighthouse_pixel)


static func _lighthouse_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24
	if y >= 40:
		if abs(x - cx) <= 10:
			return "d" if abs(x - cx) >= 7 else "r"
		return "."
	if abs(x - cx) > 4:
		if y >= 12 and y <= 16:
			var beam := 6 + phase * 2
			if x > cx and x <= cx + beam and phase % 2 == 0:
				return "f" if x < cx + beam - 1 else "l"
			if x < cx and x >= cx - beam and phase % 2 == 1:
				return "f" if x > cx - beam + 1 else "l"
		return "."
	if y < 8:
		return "g" if y > 2 else "p"
	if y >= 10 and y <= 16:
		if abs(x - cx) == 4:
			return "d"
		return "f" if posmod(phase, 2) == int(x > cx) else "s"
	if abs(x - cx) == 4:
		return "d"
	if posmod(y, 4) == 0:
		return "r"
	if posmod(y, 4) == 1:
		return "g"
	return "s"


static func _lantern_frames() -> Array:
	return _phase_frames(_lantern_pixel)


static func _lantern_pixel(x: int, y: int, phase: int) -> String:
	var cx := 24 + (2 if phase >= 2 else 0) - (2 if phase == 1 else 0)
	if y < 12:
		if abs(x - 24) <= 1:
			return "s" if y > 4 else "g"
		return "."
	if y == 12 and abs(x - cx) <= 2:
		return "r"
	if y >= 14 and y <= 24 and abs(x - cx) <= 4:
		if abs(x - cx) == 4 or y == 14 or y == 24:
			return "d"
		if phase % 2 == 0:
			return "g" if abs(x - cx) <= 1 else "f"
		return "f" if abs(x - cx) <= 2 else "l"
	if y == 26 and abs(x - cx) <= 2:
		return "r"
	if y == 13 and abs(x - cx) <= 3:
		return "s"
	return "."


static func _phase_frames(painter: Callable) -> Array:
	var frames: Array = []
	for phase in 4:
		var rows: Array = []
		for y in 48:
			var row := ""
			for x in 48:
				row += str(painter.call(x, y, phase))
			rows.append(row)
		frames.append(rows)
	return frames

class_name AbilityArt
extends RefCounted

## Builds 16×16 ability icons and 6-frame cast animations. Each ability_id gets its own
## signature overlay on top of the archetype base plus a pulsing composite of its unique icon.

const ICON_SIZE := 16
const VFX_SIZE := 48
const VFX_FRAMES := 6

static var _cache: Dictionary = {}


static func all_sprites() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for ability_id in SpriteArt.ABILITY_ICON_ROWS.keys():
		var palette := _palette_for(str(ability_id))
		var icon_rows := _unique_icon(str(ability_id), SpriteArt.ABILITY_ICON_ROWS[ability_id], palette)
		_cache[str(ability_id)] = {"rows": icon_rows, "palette": palette}
		var archetype := int(PlayerClass.ability_info(str(ability_id)).get("archetype", PlayerClass.Archetype.NUKE_BOLT))
		for frame_index in VFX_FRAMES:
			var fx_name := "%s_fx%d" % [ability_id, frame_index]
			_cache[fx_name] = {
				"rows": _vfx_frame(archetype, frame_index, str(ability_id), icon_rows),
				"palette": palette,
			}
	return _cache


static func _palette_for(ability_id: String) -> Dictionary:
	var base: Dictionary = SpriteArt.ABILITY_ICON_PALETTES[ability_id]
	var palette := base.duplicate()
	palette["a"] = _accent_for(ability_id)
	palette["h"] = "ffffff"
	palette["e"] = _ember_for(ability_id)
	return palette


static func _accent_for(ability_id: String) -> String:
	if ability_id.begins_with("arclight"):
		return "ffe066"
	if ability_id.begins_with("bulwark"):
		return "ff8a3d"
	if ability_id.begins_with("warden"):
		return "d9ff8a"
	if ability_id.begins_with("frostbinder"):
		return "c8f0ff"
	return "ffffff"


static func _ember_for(ability_id: String) -> String:
	if ability_id.begins_with("arclight"):
		return "9fd4ff"
	if ability_id.begins_with("bulwark"):
		return "ffcc88"
	if ability_id.begins_with("warden"):
		return "b8ffb0"
	if ability_id.begins_with("frostbinder"):
		return "ffffff"
	return "ffffff"


static func _hash(ability_id: String) -> int:
	var value := 0
	for index in ability_id.length():
		value = (value * 31 + ability_id.unicode_at(index)) & 0x7fffffff
	return value


static func _unique_icon(ability_id: String, base_rows: Array, palette: Dictionary) -> Array[String]:
	var rows := _scale_2x(base_rows)
	var hash := _hash(ability_id)
	for marker_index in 8:
		var x := 1 + (hash + marker_index * 17) % (ICON_SIZE - 2)
		var y := 1 + (hash + marker_index * 29) % (ICON_SIZE - 2)
		if rows[y][x] == ".":
			rows[y] = _set_pixel(rows[y], x, "a" if marker_index % 2 == 0 else "e")
		else:
			rows[y] = _set_pixel(rows[y], x, "h")
	var corner_x := ICON_SIZE - 2 - (hash % 3)
	var corner_y := ICON_SIZE - 2 - ((hash / 3) % 3)
	rows[corner_y] = _set_pixel(rows[corner_y], corner_x, "a")
	if corner_x > 1:
		rows[corner_y] = _set_pixel(rows[corner_y], corner_x - 1, "h")
	return rows


static func _scale_2x(base_rows: Array) -> Array[String]:
	var size := base_rows.size()
	var scaled: Array[String] = []
	for y in size * 2:
		var row := ""
		var source_y: int = y / 2
		var source_row: String = base_rows[source_y]
		for x in size * 2:
			var source_x: int = x / 2
			var pixel: String = source_row[source_x]
			row += pixel if pixel != "." else "."
		scaled.append(row)
	return scaled


static func _set_pixel(row: String, x: int, pixel: String) -> String:
	return row.substr(0, x) + pixel + row.substr(x + 1)


static func _blank(size: int) -> Array[String]:
	var rows: Array[String] = []
	for _y in size:
		var row := ""
		for _x in size:
			row += "."
		rows.append(row)
	return rows


static func _plot(rows: Array[String], x: int, y: int, pixel: String) -> void:
	if x < 0 or y < 0 or y >= rows.size() or x >= rows[y].length():
		return
	rows[y] = _set_pixel(rows[y], x, pixel)


static func _vfx_frame(archetype: int, frame_index: int, ability_id: String, icon_rows: Array[String]) -> Array[String]:
	var rows := _blank(VFX_SIZE)
	var hash := _hash(ability_id)
	var center := Vector2(VFX_SIZE * 0.5, VFX_SIZE * 0.5)
	var progress := float(frame_index + 1) / float(VFX_FRAMES)
	var scale := 1.55
	var spin := float(hash % 360) * 0.0174533
	match archetype:
		PlayerClass.Archetype.NUKE_BOLT:
			_draw_ring(rows, center, (7.0 + progress * 16.0) * scale, hash, spin)
		PlayerClass.Archetype.CONE_BURST:
			_draw_cone(rows, center, progress * scale, hash, spin)
		PlayerClass.Archetype.RADIUS_BURST:
			_draw_ring(rows, center, (8.0 + progress * 18.0) * scale, hash, spin)
		PlayerClass.Archetype.CHAIN_NUKE:
			_draw_ring(rows, center, (6.0 + progress * 14.0) * scale, hash, spin)
			_draw_chain(rows, center, progress * scale, hash)
		PlayerClass.Archetype.DASH_STRIKE:
			_draw_streak(rows, center, progress, hash, true, spin)
		PlayerClass.Archetype.BLINK:
			_draw_diamond(rows, center, 4.0 + progress * 10.0, hash, spin)
		PlayerClass.Archetype.SELF_HEAL:
			_draw_cross(rows, center, 4.0 + progress * 9.0, hash, spin)
		PlayerClass.Archetype.AOE_HEAL:
			_draw_ring(rows, center, 4.0 + progress * 12.0, hash, spin)
			_draw_cross(rows, center, 3.0 + progress * 6.0, hash, spin + 0.4)
		PlayerClass.Archetype.SHIELD_BURST:
			_draw_shield(rows, center, 5.0 + progress * 10.0, hash, spin)
		PlayerClass.Archetype.BUFF_SELF:
			_draw_arrows_up(rows, center, progress, hash)
		PlayerClass.Archetype.PUSH_PULL_BURST:
			_draw_push_pull(rows, center, progress, hash)
	_draw_signature(rows, ability_id, center, progress, hash, spin)
	_draw_sparks(rows, center, progress, hash)
	_blit_icon(rows, icon_rows, center, 0.55 + progress * 0.65, frame_index, hash)
	return rows


static func _signature_motif(ability_id: String) -> String:
	var tail := ability_id.split("_", true, 1)[1] if ability_id.contains("_") else ability_id
	if tail.contains("storm") or tail.contains("nova") or tail.contains("zero"):
		return "storm"
	if tail.contains("chain") or tail.contains("volley") or tail.contains("overcharge"):
		return "chain"
	if tail.contains("cone") or tail.contains("cleave") or tail.contains("glacial") or tail.contains("flash"):
		return "cone"
	if tail.contains("step") or (tail.contains("charge") and not tail.contains("overcharge")):
		return "teleport"
	if tail.contains("mending") or tail.contains("bloom") or tail.contains("warcry"):
		return "heal"
	if tail.contains("fortify") or tail.contains("ward") or tail.contains("permafrost"):
		return "shield"
	if tail.contains("repulsor") or tail.contains("vortex") or tail.contains("provoke") or tail.contains("bramble"):
		return "push"
	if tail.contains("freeze") or tail.contains("mark") or tail.contains("sunder") or tail.contains("shatter"):
		return "shatter"
	if tail.contains("siphon") or tail.contains("drain"):
		return "drain"
	if tail.contains("track") or tail.contains("entangle"):
		return "mark"
	if tail.contains("overclock") or tail.contains("clarity") or tail.contains("retribution") or tail.contains("stand") or tail.contains("choir"):
		return "buff"
	if tail.contains("slam") or tail.contains("grasp"):
		return "slam"
	if tail.contains("bolt") or tail.contains("spike") or tail.contains("lash") or tail.contains("wrath"):
		return "bolt"
	return ["spark", "burst", "ring", "star", "wave", "pulse"][_hash(ability_id) % 6]


static func _draw_signature(rows: Array[String], ability_id: String, center: Vector2, progress: float, hash: int, spin: float) -> void:
	match _signature_motif(ability_id):
		"storm":
			for ray in 10 + hash % 4:
				var angle := spin + float(ray) / 12.0 * TAU
				for step in int(6.0 + progress * 14.0):
					_plot(rows, int(center.x + cos(angle) * float(step)), int(center.y + sin(angle) * float(step)), "e" if step % 2 == 0 else "f")
		"chain":
			for branch in 3:
				var offset := float(branch - 1) * 7.0
				for step in int(4.0 + progress * 10.0):
					_plot(rows, int(center.x + offset + float(step)), int(center.y + sin(float(step) * 0.8 + spin) * 4.0), "h")
					_plot(rows, int(center.x - offset - float(step)), int(center.y + cos(float(step) * 0.8 + spin) * 4.0), "f")
		"cone":
			for lane in 5:
				for step in int(5.0 + progress * 12.0):
					_plot(rows, int(center.x + float(step)), int(center.y + float(lane - 2) * (1.0 + progress * 2.0)), "e")
		"teleport":
			for corner in 4:
				var angle := spin + float(corner) * TAU * 0.25
				var dist := 8.0 + progress * 10.0
				_plot(rows, int(center.x + cos(angle) * dist), int(center.y + sin(angle) * dist), "h")
				_plot(rows, int(center.x + cos(angle) * dist * 0.5), int(center.y + sin(angle) * dist * 0.5), "a")
		"heal":
			for petal in 6:
				var angle := spin + float(petal) / 6.0 * TAU
				for step in int(3.0 + progress * 8.0):
					_plot(rows, int(center.x + cos(angle) * float(step)), int(center.y + sin(angle) * float(step)), "a")
		"shield":
			_draw_shield(rows, center, 6.0 + progress * 8.0, hash, spin + 0.2)
		"push":
			for direction in 4:
				var angle := spin + float(direction) * TAU * 0.25
				for step in int(2.0 + progress * 9.0):
					_plot(rows, int(center.x + cos(angle) * float(step)), int(center.y + sin(angle) * float(step)), "e")
		"shatter":
			for shard in 8 + hash % 3:
				var angle := spin + float(shard) * 0.9
				_plot(rows, int(center.x + cos(angle) * (6.0 + progress * 10.0)), int(center.y + sin(angle) * (6.0 + progress * 10.0)), "h")
		"drain":
			for spiral_step in int(8.0 + progress * 16.0):
				var angle := spin + float(spiral_step) * 0.55
				var radius := 14.0 - float(spiral_step) * 0.45
				_plot(rows, int(center.x + cos(angle) * radius), int(center.y + sin(angle) * radius), "a")
		"mark":
			for ring_step in int(6.0 + progress * 8.0):
				_plot(rows, int(center.x + float(ring_step)), int(center.y), "h")
				_plot(rows, int(center.x), int(center.y + float(ring_step)), "h")
				_plot(rows, int(center.x - float(ring_step)), int(center.y), "f")
				_plot(rows, int(center.x), int(center.y - float(ring_step)), "f")
		"buff":
			for arrow in 4:
				var base_x := int(center.x - 6.0 + float(arrow) * 4.0)
				var tip_y := int(center.y - 4.0 - progress * 8.0 - float(arrow))
				_plot(rows, base_x, tip_y, "h")
				_plot(rows, base_x - 1, tip_y + 1, "a")
				_plot(rows, base_x + 1, tip_y + 1, "a")
		"slam":
			for wave_y in int(4.0 + progress * 10.0):
				for wave_x in range(-wave_y, wave_y + 1):
					_plot(rows, int(center.x + float(wave_x)), int(center.y + float(wave_y)), "f")
		"bolt":
			for fork in 3:
				var angle := spin - 0.4 + float(fork) * 0.4
				for step in int(5.0 + progress * 12.0):
					_plot(rows, int(center.x + cos(angle) * float(step)), int(center.y + sin(angle) * float(step) + sin(float(step) * 0.7) * 2.0), "h" if fork == 1 else "f")
		"spark":
			for spark_index in 12 + hash % 5:
				var angle := spin + float(spark_index) * 0.7
				var dist := 4.0 + progress * 14.0 + float(spark_index % 3)
				_plot(rows, int(center.x + cos(angle) * dist), int(center.y + sin(angle) * dist), "h")
		"burst":
			_draw_ring(rows, center, 5.0 + progress * 12.0, hash, spin)
		"ring":
			_draw_ring(rows, center, 8.0 + progress * 14.0, hash, spin + 0.5)
			_draw_ring(rows, center, 3.0 + progress * 8.0, hash, spin)
		"star":
			for arm in 5:
				var angle := spin + float(arm) / 5.0 * TAU
				for step in int(3.0 + progress * 10.0):
					_plot(rows, int(center.x + cos(angle) * float(step)), int(center.y + sin(angle) * float(step)), "a")
		"wave":
			for x in VFX_SIZE:
				var wave_y := int(center.y + sin(float(x) * 0.35 + spin + progress * 4.0) * (2.0 + progress * 6.0))
				_plot(rows, x, wave_y, "e")
		"pulse":
			_draw_cross(rows, center, 2.0 + progress * 7.0, hash, spin)
			_draw_ring(rows, center, 4.0 + progress * 11.0, hash, spin)


static func _draw_sparks(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	for spark_index in 10 + hash % 6:
		var angle := float(spark_index * 37 + hash) * 0.11
		var dist := 6.0 + progress * float(10 + spark_index % 7)
		var pixel := "h" if spark_index % 3 == 0 else ("a" if spark_index % 2 == 0 else "e")
		_plot(rows, int(center.x + cos(angle) * dist), int(center.y + sin(angle) * dist), pixel)


static func _blit_icon(rows: Array[String], icon_rows: Array[String], center: Vector2, scale: float, frame_index: int, hash: int) -> void:
	var icon_size := icon_rows.size()
	var half := icon_size * scale * 0.5
	var wobble := sin(float(frame_index + 1) * 1.2 + float(hash % 10)) * 1.5
	for y in icon_size:
		for x in icon_size:
			var pixel: String = icon_rows[y][x]
			if pixel == ".":
				continue
			var target_x := int(center.x + (float(x) - icon_size * 0.5) * scale + wobble)
			var target_y := int(center.y + (float(y) - icon_size * 0.5) * scale - wobble * 0.5)
			_plot(rows, target_x, target_y, pixel)
			if scale > 0.8:
				_plot(rows, target_x + 1, target_y, pixel)


static func _draw_streak(rows: Array[String], center: Vector2, progress: float, hash: int, thick: bool, spin: float) -> void:
	var length := int(6.0 + progress * 16.0)
	for step in length:
		var x := int(center.x + cos(spin) * float(step))
		var y := int(center.y + sin(spin) * float(step))
		_plot(rows, x, y, "f")
		_plot(rows, x, y - 1, "l")
		if thick:
			_plot(rows, x, y + 1, "l")
			_plot(rows, x + 1, y, "e")


static func _draw_cone(rows: Array[String], center: Vector2, progress: float, hash: int, spin: float) -> void:
	var spread := 3.0 + progress * 12.0
	for step in int(6.0 + progress * 14.0):
		for offset in range(-int(spread), int(spread) + 1):
			var px := center.x + cos(spin) * float(step) - sin(spin) * float(offset)
			var py := center.y + sin(spin) * float(step) + cos(spin) * float(offset)
			_plot(rows, int(px), int(py), "f" if abs(offset) <= 1 else "l")


static func _draw_ring(rows: Array[String], center: Vector2, radius: float, hash: int, spin: float = 0.0) -> void:
	for y in VFX_SIZE:
		for x in VFX_SIZE:
			var offset := Vector2(x, y) - center
			var rotated_x := offset.x * cos(spin) - offset.y * sin(spin)
			var dist := Vector2(rotated_x, offset.y).length()
			if absf(dist - radius) <= 1.35:
				_plot(rows, x, y, "f" if int(x + y + hash) % 3 == 0 else "l")


static func _draw_chain(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	_plot(rows, int(center.x - 6.0), int(center.y), "h")
	_plot(rows, int(center.x + 6.0), int(center.y), "h")
	for step in int(3.0 + progress * 10.0):
		_plot(rows, int(center.x - 6.0 + float(step)), int(center.y + float(step % 3 - 1)), "f")
		_plot(rows, int(center.x + 6.0 - float(step)), int(center.y - float(step % 3 - 1)), "l")


static func _draw_diamond(rows: Array[String], center: Vector2, radius: float, hash: int, spin: float) -> void:
	for y in VFX_SIZE:
		for x in VFX_SIZE:
			var offset := Vector2(x, y) - center
			var rotated := Vector2(
				offset.x * cos(spin) - offset.y * sin(spin),
				offset.x * sin(spin) + offset.y * cos(spin)
			)
			var dist := absf(rotated.x) + absf(rotated.y)
			if dist <= radius:
				_plot(rows, x, y, "l" if dist > radius - 1.8 else "h")


static func _draw_cross(rows: Array[String], center: Vector2, arm: float, hash: int, spin: float) -> void:
	for offset in range(-int(arm), int(arm) + 1):
		var along := Vector2(float(offset), 0.0)
		var across := Vector2(0.0, float(offset))
		for vector: Vector2 in [along, across]:
			var rotated := Vector2(
				vector.x * cos(spin) - vector.y * sin(spin),
				vector.x * sin(spin) + vector.y * cos(spin)
			)
			_plot(rows, int(center.x + rotated.x), int(center.y + rotated.y), "f")
	_plot(rows, int(center.x), int(center.y), "h")


static func _draw_shield(rows: Array[String], center: Vector2, radius: float, hash: int, spin: float) -> void:
	for y in VFX_SIZE:
		for x in VFX_SIZE:
			var offset := Vector2(x, y) - center
			var rotated_x := offset.x * cos(spin) - offset.y * sin(spin)
			var dy := offset.y
			if dy >= -radius and dy <= radius * 0.65 and absf(rotated_x) <= radius - dy * 0.35:
				_plot(rows, x, y, "f" if absf(rotated_x) < radius - 2.5 else "l")


static func _draw_arrows_up(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	for arrow_index in 4:
		var base_x := int(center.x - 8.0 + float(arrow_index) * 5.0)
		var tip_y := int(center.y - 3.0 - progress * 10.0 - float(arrow_index))
		_plot(rows, base_x, tip_y, "h")
		_plot(rows, base_x - 1, tip_y + 1, "f")
		_plot(rows, base_x + 1, tip_y + 1, "f")
		_plot(rows, base_x, tip_y + 2, "a")


static func _draw_push_pull(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	var push_out := hash % 2 == 0
	var distance := 3.0 + progress * 11.0
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var tip: Vector2 = center + direction * distance * (1.0 if push_out else -1.0)
		_plot(rows, int(tip.x), int(tip.y), "h")
		_plot(rows, int(tip.x - direction.y), int(tip.y - direction.x), "f")
		_plot(rows, int(tip.x + direction.y), int(tip.y + direction.x), "f")

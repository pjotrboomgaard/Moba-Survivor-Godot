class_name AbilityArt
extends RefCounted

## Builds the 16×16 ability icons and 4-frame cast animations from the 8×8 archetype
## silhouettes in SpriteArt, then stamps each ability with a unique signature so no two
## icons look identical even when they share an archetype shape.

const ICON_SIZE := 16
const VFX_SIZE := 32
const VFX_FRAMES := 4

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
				"rows": _vfx_frame(archetype, frame_index, str(ability_id)),
				"palette": palette,
			}
	return _cache


static func _palette_for(ability_id: String) -> Dictionary:
	var base: Dictionary = SpriteArt.ABILITY_ICON_PALETTES[ability_id]
	var palette := base.duplicate()
	palette["a"] = _accent_for(ability_id)
	palette["h"] = "ffffff"
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


static func _hash(ability_id: String) -> int:
	var value := 0
	for index in ability_id.length():
		value = (value * 31 + ability_id.unicode_at(index)) & 0x7fffffff
	return value


static func _unique_icon(ability_id: String, base_rows: Array, palette: Dictionary) -> Array[String]:
	var rows := _scale_2x(base_rows)
	var hash := _hash(ability_id)
	for marker_index in 6:
		var x := 1 + (hash + marker_index * 17) % (ICON_SIZE - 2)
		var y := 1 + (hash + marker_index * 29) % (ICON_SIZE - 2)
		if rows[y][x] == ".":
			rows[y] = _set_pixel(rows[y], x, "a" if marker_index % 2 == 0 else "h")
		else:
			rows[y] = _set_pixel(rows[y], x, "h")
	# A tiny rank-gem corner so every ability reads as its own card art.
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


static func _vfx_frame(archetype: int, frame_index: int, ability_id: String) -> Array[String]:
	var rows := _blank(VFX_SIZE)
	var hash := _hash(ability_id)
	var center := Vector2(VFX_SIZE * 0.5, VFX_SIZE * 0.5)
	var progress := float(frame_index + 1) / float(VFX_FRAMES)
	var scale := 1.35
	match archetype:
		PlayerClass.Archetype.NUKE_BOLT:
			_draw_ring(rows, center, (5.0 + progress * 12.0) * scale, hash)
		PlayerClass.Archetype.CONE_BURST:
			_draw_cone(rows, center, progress * scale, hash)
		PlayerClass.Archetype.RADIUS_BURST:
			_draw_ring(rows, center, (6.0 + progress * 14.0) * scale, hash)
		PlayerClass.Archetype.CHAIN_NUKE:
			_draw_ring(rows, center, (5.0 + progress * 11.0) * scale, hash)
			_draw_chain(rows, center, progress * scale, hash)
		PlayerClass.Archetype.DASH_STRIKE:
			_draw_streak(rows, center, progress, hash, true)
		PlayerClass.Archetype.BLINK:
			_draw_diamond(rows, center, 3.0 + progress * 7.0, hash)
		PlayerClass.Archetype.SELF_HEAL:
			_draw_cross(rows, center, 3.0 + progress * 6.0, hash)
		PlayerClass.Archetype.AOE_HEAL:
			_draw_ring(rows, center, 3.0 + progress * 8.0, hash)
			_draw_cross(rows, center, 2.0 + progress * 4.0, hash)
		PlayerClass.Archetype.SHIELD_BURST:
			_draw_shield(rows, center, 4.0 + progress * 7.0, hash)
		PlayerClass.Archetype.BUFF_SELF:
			_draw_arrows_up(rows, center, progress, hash)
		PlayerClass.Archetype.PUSH_PULL_BURST:
			_draw_push_pull(rows, center, progress, hash)
	return rows


static func _draw_streak(rows: Array[String], center: Vector2, progress: float, hash: int, thick: bool = false) -> void:
	var length := int(4.0 + progress * 10.0)
	var angle_offset := float(hash % 360) * 0.01
	for step in length:
		var x := int(center.x + cos(angle_offset) * float(step))
		var y := int(center.y + sin(angle_offset) * float(step))
		_plot(rows, x, y, "f")
		_plot(rows, x, y - 1, "l")
		if thick:
			_plot(rows, x, y + 1, "l")


static func _draw_cone(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	var spread := 2.0 + progress * 8.0
	for step in int(4.0 + progress * 10.0):
		for offset in range(-int(spread), int(spread) + 1):
			_plot(rows, int(center.x + float(step)), int(center.y + float(offset)), "f" if abs(offset) <= 1 else "l")


static func _draw_ring(rows: Array[String], center: Vector2, radius: float, hash: int) -> void:
	for y in VFX_SIZE:
		for x in VFX_SIZE:
			var dist := Vector2(x, y).distance_to(center)
			if absf(dist - radius) <= 1.2:
				_plot(rows, x, y, "f" if int(x + y + hash) % 3 == 0 else "l")


static func _draw_chain(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	_plot(rows, int(center.x - 4.0), int(center.y), "h")
	_plot(rows, int(center.x + 4.0), int(center.y), "h")
	for step in int(2.0 + progress * 6.0):
		_plot(rows, int(center.x - 4.0 + float(step)), int(center.y + float(step % 2)), "f")
		_plot(rows, int(center.x + 4.0 - float(step)), int(center.y - float(step % 2)), "l")


static func _draw_diamond(rows: Array[String], center: Vector2, radius: float, hash: int) -> void:
	for y in VFX_SIZE:
		for x in VFX_SIZE:
			var dist := absf(x - center.x) + absf(y - center.y)
			if dist <= radius:
				_plot(rows, x, y, "l" if dist > radius - 1.5 else "h")


static func _draw_cross(rows: Array[String], center: Vector2, arm: float, hash: int) -> void:
	for offset in range(-int(arm), int(arm) + 1):
		_plot(rows, int(center.x + float(offset)), int(center.y), "f")
		_plot(rows, int(center.x), int(center.y + float(offset)), "f")
	_plot(rows, int(center.x), int(center.y), "h")


static func _draw_shield(rows: Array[String], center: Vector2, radius: float, hash: int) -> void:
	for y in VFX_SIZE:
		for x in VFX_SIZE:
			var dx := absf(x - center.x)
			var dy := y - center.y
			if dy >= -radius and dy <= radius * 0.6 and dx <= radius - dy * 0.35:
				_plot(rows, x, y, "f" if dx < radius - 2.0 else "l")


static func _draw_arrows_up(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	for arrow_index in 3:
		var base_x := int(center.x - 4.0 + float(arrow_index) * 4.0)
		var tip_y := int(center.y - 2.0 - progress * 6.0 - float(arrow_index))
		_plot(rows, base_x, tip_y, "h")
		_plot(rows, base_x - 1, tip_y + 1, "f")
		_plot(rows, base_x + 1, tip_y + 1, "f")
		_plot(rows, base_x, tip_y + 2, "l")


static func _draw_push_pull(rows: Array[String], center: Vector2, progress: float, hash: int) -> void:
	var push_out := hash % 2 == 0
	var distance := 2.0 + progress * 7.0
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var tip: Vector2 = center + direction * distance * (1.0 if push_out else -1.0)
		_plot(rows, int(tip.x), int(tip.y), "h")
		_plot(rows, int(tip.x - direction.y), int(tip.y - direction.x), "f")
		_plot(rows, int(tip.x + direction.y), int(tip.y + direction.x), "f")

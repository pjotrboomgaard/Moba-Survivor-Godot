class_name ToborBody
extends RefCounted

## Hand-authored pixel pawn, same method as SpriteArt: character grids + palette.
## "." is transparent. No photo extract, so no paper halo or shoulder holes.

const CANVAS_W := 32
const CANVAS_H := 32
const BODY_PIXEL_WIDTH := 24
const MENU_ACTION_PATH := "res://assets/ui/tobor_menu_bg.png"
const MENU_ACTION_FALLBACK := "res://assets/ui/tobor_menu_action.png"
const ICON_PATH := "res://assets/sprites/tobor_icon_%s.png"

## Wings and jetpack sit behind the cone on front/side; on the back they cover it.
const GEAR_BEHIND := {
	"front": ["sjaal", "romp"],
	"back": [],
	"left": ["sjaal", "romp"],
	"right": ["sjaal", "romp"],
}
const GEAR_AHEAD := {
	"front": ["antenne", "armen", "benen", "hoverboard", "sirene"],
	"back": ["antenne", "armen", "benen", "romp", "sjaal", "hoverboard", "sirene"],
	"left": ["antenne", "armen", "benen", "hoverboard", "sirene"],
	"right": ["antenne", "armen", "benen", "hoverboard", "sirene"],
}

static var _cache: Dictionary = {}

const PALETTE := {
	"o": "0b1018",
	"w": "e8e8e8",
	"u": "c8c8c8",
	"s": "9c9c9c",
	"m": "5a5a5a",
	"n": "e05a28",
	"r": "c44820",
	"t": "dc3c2e",
	"i": "f2b090",
	"y": "ffe14a",
	"e": "f5c542",
	"k": "1a1a1a",
	"b": "2bbfbe",
	"d": "3a4656",
	"f": "4f8fe0",
	"c": "6b4a2c",
	"h": "c9a227",
	"a": "a8b4c0",
	"p": "b02820",
	"q": "2a3038",
	"z": "121018",
	"v": "241810",
	"x": "3a2010",
	"l": "ffa090",
}

const PART_SLOTS: Array[Dictionary] = [
	{"id": "sirene", "slot": "crown"},
	{"id": "antenne", "slot": "side"},
	{"id": "sjaal", "slot": "neck"},
	{"id": "romp", "slot": "torso"},
	{"id": "armen", "slot": "arms"},
	{"id": "benen", "slot": "legs"},
	{"id": "hoverboard", "slot": "base"},
]


static func flags_from(shop_stacks: Dictionary) -> Dictionary:
	var flags := {}
	for part in PART_SLOTS:
		flags[str(part.id)] = int(shop_stacks.get(str(part.id), 0)) > 0
	return flags


static func cache_key(shop_stacks: Dictionary, walk_frame: int = 0, facing: String = "front") -> String:
	var flags := flags_from(shop_stacks)
	var bits := ""
	for part in PART_SLOTS:
		bits += "1" if flags[str(part.id)] else "0"
	return "tobor_%s_%s_%d" % [facing, bits, walk_frame]


static func scale_for_body(radius: float) -> Vector2:
	return Vector2.ONE * ((radius * 2.0) / float(BODY_PIXEL_WIDTH))


static func compose(shop_stacks: Dictionary, walk_frame: int = 0, facing: String = "front") -> Texture2D:
	var view := facing if facing == "back" or facing == "left" or facing == "right" else "front"
	var key := cache_key(shop_stacks, walk_frame, view)
	if _cache.has(key):
		return _cache[key]
	var rows := _assemble(flags_from(shop_stacks), view, walk_frame)
	var texture := _texture_from_rows(rows, PALETTE)
	_cache[key] = texture
	return texture


static func _assemble(flags: Dictionary, facing: String, walk_frame: int) -> Array[String]:
	var rows := _blank()
	for item_id in GEAR_BEHIND.get(facing, []):
		if flags.get(item_id, false):
			_stamp_gear(rows, str(item_id), facing, walk_frame)
	_blit(rows, _canvas(_pawn(facing)), 0, 0)
	for item_id in GEAR_AHEAD.get(facing, []):
		if flags.get(item_id, false):
			_stamp_gear(rows, str(item_id), facing, walk_frame)
	return rows


static func _pawn(facing: String) -> Array:
	match facing:
		"back":
			return PAWN_BACK
		"left":
			return PAWN_LEFT
		"right":
			return _mirror(PAWN_LEFT)
		_:
			return PAWN_FRONT


static func part_icon(item_id: String) -> Texture2D:
	var key := "tobor_icon32_%s" % item_id
	if _cache.has(key):
		return _cache[key]
	var icon_path := ICON_PATH % item_id
	if ResourceLoader.exists(icon_path):
		var loaded := load(icon_path) as Texture2D
		if loaded != null:
			_cache[key] = loaded
			return loaded
	var rows: Array = []
	match item_id:
		"sirene":
			rows = ["..tttt..", ".tllttt.", ".tptttt.", "...ss..."]
		"antenne":
			rows = ["nn....nn", "nm....mn", "n......n"]
		"sjaal":
			rows = [".ww..ww.", "wuu..uuw"]
		"romp":
			rows = [".ss.ss.", ".mm.mm.", ".ye.ey."]
		"armen":
			rows = ["nn....nn", "nm....mn"]
		"benen":
			rows = ["n..n..n", ".n.n.n."]
		"hoverboard":
			rows = [".sffffs.", "offffffo"]
		_:
			return null
	var texture := _texture_from_rows(rows, PALETTE)
	_cache[key] = texture
	return texture


static func menu_backdrop() -> Texture2D:
	const KEY := "tobor_menu_bg"
	if _cache.has(KEY):
		return _cache[KEY]
	for path in [MENU_ACTION_PATH, MENU_ACTION_FALLBACK]:
		if ResourceLoader.exists(path):
			var loaded := load(path) as Texture2D
			if loaded != null:
				_cache[KEY] = loaded
				return loaded
	return compose({"sirene": 1, "antenne": 1, "armen": 1, "benen": 1})


static func _blank() -> Array[String]:
	var lines: Array[String] = []
	for _i in CANVAS_H:
		lines.append(_row(""))
	return lines


static func _canvas(stamp: Array) -> Array[String]:
	var lines: Array[String] = []
	for line in stamp:
		lines.append(_row(str(line)))
	while lines.size() < CANVAS_H:
		lines.append(_row(""))
	return lines.slice(0, CANVAS_H)


static func _row(text: String) -> String:
	var row := text
	while row.length() < CANVAS_W:
		row += "."
	return row.substr(0, CANVAS_W)


static func _mirror(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for raw in rows:
		var row := _row(str(raw))
		var rev := ""
		for i in range(row.length() - 1, -1, -1):
			rev += row[i]
		out.append(rev)
	return out


static func _blit(lines: Array[String], stamp: Array, origin_x: int, origin_y: int) -> void:
	for j in stamp.size():
		var stamp_row := str(stamp[j])
		for i in stamp_row.length():
			if stamp_row[i] == ".":
				continue
			_poke(lines, origin_y + j, origin_x + i, stamp_row[i])


static func _poke(lines: Array[String], y: int, x: int, stamp: String) -> void:
	if y < 0 or y >= lines.size() or stamp.is_empty():
		return
	var row := lines[y]
	for i in stamp.length():
		var px := x + i
		if px < 0 or px >= row.length() or stamp[i] == ".":
			continue
		row = row.substr(0, px) + stamp[i] + row.substr(px + 1)
	lines[y] = row


static func _image_from_rows(rows: Array, palette: Dictionary) -> Image:
	var height: int = rows.size()
	var width: int = str(rows[0]).length() if height > 0 else 0
	var image := Image.create(maxi(1, width), maxi(1, height), false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in height:
		var row := str(rows[y])
		for x in mini(width, row.length()):
			var character := row[x]
			if character == "." or not palette.has(character):
				continue
			image.set_pixel(x, y, Color(str(palette[character])))
	return image


static func _texture_from_rows(rows: Array, palette: Dictionary) -> Texture2D:
	return ImageTexture.create_from_image(_image_from_rows(rows, palette))


static func _wobble(walk_frame: int) -> int:
	if walk_frame == 1:
		return -1
	if walk_frame == 2:
		return 1
	return 0


static func _stamp_gear(lines: Array[String], item_id: String, facing: String, walk_frame: int) -> void:
	var wobble := _wobble(walk_frame)
	match item_id:
		"sjaal":
			if facing == "left":
				_blit(lines, WING_SIDE, 20, 10)
			elif facing == "right":
				_blit(lines, _mirror(WING_SIDE), 0, 10)
			else:
				_blit(lines, WING_LEFT, 0, 10)
				_blit(lines, WING_RIGHT, 22, 10)
		"romp":
			if facing == "back":
				_blit(lines, JET_BACK, 11, 12)
			elif facing == "left":
				_blit(lines, JET_SIDE, 19, 13)
			elif facing == "right":
				_blit(lines, _mirror(JET_SIDE), 8, 13)
			else:
				_blit(lines, JET_NUB, 5, 13)
				_blit(lines, JET_NUB, 24, 13)
		"antenne":
			if facing == "left":
				_blit(lines, MECH_ARM, 0, 12)
			elif facing == "right":
				_blit(lines, _mirror(MECH_ARM), 25, 12)
			else:
				_blit(lines, MECH_ARM, 0, 12)
				_blit(lines, _mirror(MECH_ARM), 25, 12)
		"armen":
			if facing == "left":
				_blit(lines, CANNON, 0, 14)
			elif facing == "right":
				_blit(lines, _mirror(CANNON), 25, 14)
			else:
				_blit(lines, CANNON, 0, 14)
				_blit(lines, _mirror(CANNON), 25, 14)
		"benen":
			_blit(lines, TENTACLE, 1 + wobble, 18)
			_blit(lines, _mirror(TENTACLE), 26 - wobble, 18)
		"hoverboard":
			_blit(lines, BOARD, 7 + wobble, 26)
		"sirene":
			_blit(lines, SIREN_GLOW, 12, 0)
			if facing == "left":
				_blit(lines, SIREN_LAMP, 10, 12)
			elif facing == "right":
				_blit(lines, SIREN_LAMP, 20, 12)
			else:
				_blit(lines, SIREN_LAMP, 22, 11)


## Traffic-cone pawn from ref image/content_capped_resolution (3).webp:
## red siren, stepped grey neck, white face, orange shoulders + skirt, stubby feet.
const PAWN_FRONT: Array[String] = [
	"..............tttt..............",
	".............tllttt.............",
	".............tltttt.............",
	".............tltttt.............",
	".............ttttttt............",
	".............ttttttt............",
	"............suuusmmm............",
	"............suuusmmm............",
	"............suuusmmmm...........",
	"...........ssuussmmmm...........",
	"...........ssussssmmm...........",
	"...........wwwwwwwsss...........",
	"..........wwwwwwwwwss...........",
	".....nnnnwwwwwwwwwwsssnnn.......",
	"....nnnnwwwkkwwwwkksssnnnn......",
	"....nnnnwwwkkwwwwkksssnnnn......",
	"....nnnnwwwwwwwwwwwsssnnnn......",
	"....nnnnwwwwiiiiiwssssnnnn......",
	".....mmmwwwwwwwwwwwsssmmm.......",
	".....smnnnnnnnnnnnnnnrrrmms.....",
	".....smnnnnnnnnnnnnnnrrrmms.....",
	".....smnnnnnnnnnnnnnnnrrrms.....",
	".....knnnnnnnnnnnnnnnnrrrkk.....",
	".....knnnnnnnnnnnnnnnnrrrkk.....",
	"..........kkkkk..kkkkk..........",
	"..........kkkkk..kkkkk..........",
	"..........kkkkk..kkkkk..........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

const PAWN_BACK: Array[String] = [
	"..............tttt..............",
	".............tllttt.............",
	".............tltttt.............",
	".............tltttt.............",
	".............ttttttt............",
	".............ttttttt............",
	"............suuusmmm............",
	"............suuusmmm............",
	"............suuusmmmm...........",
	"...........ssuussmmmm...........",
	"...........ssussssmmm...........",
	"...........wwwwwwwsss...........",
	"..........wwwwwwwwwss...........",
	".....nnnnwwwwwwwwwwsssnnn.......",
	"....nnnnwwwwwwwwwwwsssnnnn......",
	"....nnnnwwwwwwwwwwwsssnnnn......",
	"....nnnnwwwwwwwwwwwsssnnnn......",
	"....nnnnwwwwwwwwwwwssssnnnn.....",
	".....mmmwwwwwwwwwwwsssmmm.......",
	".....smnnnnnnnnnnnnnnrrrmms.....",
	".....smnnnnnnnnnnnnnnrrrmms.....",
	".....smnnnnnnnnnnnnnnnrrrms.....",
	".....knnnnnnnnnnnnnnnnrrrkk.....",
	".....knnnnnnnnnnnnnnnnrrrkk.....",
	"..........kkkkk..kkkkk..........",
	"..........kkkkk..kkkkk..........",
	"..........kkkkk..kkkkk..........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

const PAWN_LEFT: Array[String] = [
	"............ttttttt.............",
	"...........ttllttttt............",
	"...........ttltttttt............",
	"...........ttltttttt............",
	"...........tttttttttt...........",
	"...........tttttttttt...........",
	"..........sssuussssmmm..........",
	"..........sssuussssmmm..........",
	".........ssuuuussssmmm..........",
	"........sssuuusssssmmmm.........",
	"........ssusssssssssmmm.........",
	"........wwwwwwwwwwssss..........",
	".......wwwwwwwwwwwsss...........",
	".......wwkwwwwwssnnnnn..........",
	".......wkkwwwwwssnnnnn..........",
	"......wwwkwwwwssnnnnnn..........",
	".....iwwwwwwwwssnnnnnn..........",
	".....wwwwwwwwwsssmmmmm..........",
	".....nnnnnnnnnnnmmmmrr..........",
	".....nnnnnnnnnnnmmmmrr..........",
	".....nnnnnnnnnnnmmmmrr..........",
	"....nnnnnnnnnnnnkkkrrr..........",
	"....nnnnnnnnnnnnkkkrrr..........",
	"..........kkkkkkkkk.............",
	"..........kkkkkkkkk.............",
	"..........kkkkkkkkk.............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

const WING_LEFT: Array[String] = [
	"....wwwww.",
	"...wuuuuw.",
	"..wuuuuuw.",
	".wwuuuuw..",
	"wuuusw....",
	".wssw.....",
	"..wsw.....",
]
const WING_RIGHT: Array[String] = [
	".wwwww....",
	".wuuuuw...",
	".wuuuuuw..",
	"..wuuuww.",
	"....wsuuuw",
	".....wssw.",
	".....wsw..",
]
const WING_SIDE: Array[String] = [
	".wwwwww.",
	"wwuuuuww",
	".wuuuuw.",
	"..wssw..",
	"...ws...",
]
const JET_BACK: Array[String] = [
	"ss......ss",
	"smm....mms",
	"smm....mms",
	"smye..eyms",
	"smnn..nnms",
	".snn..nns.",
]
const JET_SIDE: Array[String] = [
	"sssss",
	"smmms",
	"smmye",
	"smnnn",
	"..nn.",
]
const JET_NUB: Array[String] = [
	"sss",
	"smy",
	"snn",
]
const MECH_ARM: Array[String] = [
	"....nnn",
	"...nmmn",
	"..nmmmn",
	".nmmmmn",
	"nmmk.mn",
	"nm...n.",
	"n....n.",
]
const CANNON: Array[String] = [
	"nnnnnnn",
	"nmmmmkn",
	"nmmmknn",
	"nnnnnnn",
]
const TENTACLE: Array[String] = [
	"n....",
	".nn..",
	"n..n.",
	".n..n",
	"..nn.",
	".n..n",
]
const BOARD: Array[String] = [
	"..sfffffffffffs..",
	".kffffffffffffffk",
	"..offfffffffffo..",
]
const SIREN_GLOW: Array[String] = [
	"..yyyy..",
	".ylylyl.",
	"..yyyy..",
]
const SIREN_LAMP: Array[String] = [
	"ny",
	"yn",
]

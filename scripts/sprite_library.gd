class_name SpriteLibrary
extends RefCounted

## Loads the pixel art baked by tools/sprite_forge.tscn.
## Anything missing simply returns null so the game falls back to its vector
## drawing and still runs on a fresh checkout that has not forged art yet.

const SPRITE_DIRECTORY := "res://assets/sprites"

static var _cache: Dictionary = {}


static func texture_for(sprite_name: String) -> Texture2D:
	if sprite_name.is_empty():
		return null
	var keyed := _skinned_name(sprite_name)
	if _cache.has(keyed):
		return _cache[keyed]
	var texture := _load_png(keyed)
	if texture == null and keyed.begins_with("tw_") and keyed != "tw_%s" % sprite_name:
		texture = _load_png("tw_%s" % sprite_name)
	if texture == null and keyed != sprite_name:
		texture = _load_png(sprite_name)
	_cache[keyed] = texture
	return texture


const TERRAIN_SPRITES := [
	"grass_tile",
	"grass_tuft",
	"grass_flower",
	"grass_bloom",
	"rock_small",
	"rock_large",
	"boulder",
	"spire",
	"shop_stand",
	"void_tile",
]


static func _skinned_name(sprite_name: String) -> String:
	if not GameRuntime.uses_biomes():
		return sprite_name
	var biome := GameRuntime.biome_key()
	if biome.is_empty():
		return sprite_name
	if TERRAIN_SPRITES.has(sprite_name) or EnemyType.is_valid_id(sprite_name):
		return "tw_%s_%s" % [biome, sprite_name]
	return sprite_name


static func _load_png(sprite_name: String) -> Texture2D:
	var path := "%s/%s.png" % [SPRITE_DIRECTORY, sprite_name]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Scale that makes a square sprite cover the given world radius.
static func scale_for_radius(texture: Texture2D, radius: float) -> Vector2:
	if texture == null or texture.get_width() <= 0:
		return Vector2.ONE
	var factor := (radius * 2.0) / float(texture.get_width())
	return Vector2(factor, factor)


static func has_cache(key: String) -> bool:
	return _cache.has(key)


static func cached(key: String) -> Texture2D:
	return _cache.get(key) as Texture2D


static func store_cache(key: String, texture: Texture2D) -> void:
	_cache[key] = texture


static func texture_from_rows(rows: Array, palette: Dictionary) -> Texture2D:
	if rows.is_empty():
		return null
	var height: int = rows.size()
	var width: int = str(rows[0]).length()
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in height:
		var row := str(rows[y])
		for x in mini(width, row.length()):
			var character := row[x]
			if character == "." or not palette.has(character):
				continue
			image.set_pixel(x, y, Color(str(palette[character])))
	return ImageTexture.create_from_image(image)


const _ToborArt := preload("res://scripts/tobor_body.gd")


static func compose_tobor(shop_stacks: Dictionary, walk_frame: int = 0, facing: String = "front") -> Texture2D:
	return _ToborArt.compose(shop_stacks, walk_frame, facing)


static func tobor_scale(radius: float) -> Vector2:
	return _ToborArt.scale_for_body(radius)


static func item_icon(item_id: String) -> Texture2D:
	var icon: Texture2D = _ToborArt.part_icon(item_id)
	if icon != null:
		return icon
	return texture_for(item_id)


static func tobor_menu_backdrop() -> Texture2D:
	return menu_backdrop_for("tobor")


static func menu_backdrop_for(class_id: String) -> Texture2D:
	var key := "menu_bg_%s" % class_id
	if _cache.has(key):
		return _cache[key]
	var class_data := PlayerClass.by_id(class_id)
	var path := str(class_data.get("menu_bg", "res://assets/ui/tobor_menu_bg.png"))
	var texture := _load_menu_image(path)
	if texture == null:
		texture = _ToborArt.menu_backdrop()
	_cache[key] = texture
	return texture


static func _load_menu_image(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path) as Texture2D
		if loaded != null:
			return loaded
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


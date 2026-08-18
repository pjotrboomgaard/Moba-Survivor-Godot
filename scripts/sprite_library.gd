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
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var path := "%s/%s.png" % [SPRITE_DIRECTORY, sprite_name]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[sprite_name] = texture
	return texture


## Scale that makes a square sprite cover the given world radius.
static func scale_for_radius(texture: Texture2D, radius: float) -> Vector2:
	if texture == null or texture.get_width() <= 0:
		return Vector2.ONE
	var factor := (radius * 2.0) / float(texture.get_width())
	return Vector2(factor, factor)

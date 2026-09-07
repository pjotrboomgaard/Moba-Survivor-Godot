class_name WorldFeature
extends Node2D

## Decorative biome scenery. Loops at 2 frames per second so it reads as a
## slow pixel-art prop, not a VFX strobe.

const FRAME_RATE := 2.0
const Art := preload("res://scripts/world_feature_art.gd")

var feature_id := "grass_waterfall"
var sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _clock := 0.0
var frame_index := 0


func configure(next_id: String) -> void:
	feature_id = next_id
	_frames = Art.frames_for(feature_id)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = 6
		add_child(sprite)
	var zoom := Art.zoom_for(feature_id)
	sprite.scale = Vector2(zoom, zoom)
	sprite.centered = true
	add_to_group("world_feature")
	_clock = 0.0
	frame_index = 0
	_apply_frame()


func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_clock += delta * FRAME_RATE
	var next := int(_clock) % _frames.size()
	if next != frame_index:
		frame_index = next
		_apply_frame()


func _apply_frame() -> void:
	if sprite != null and frame_index >= 0 and frame_index < _frames.size():
		sprite.texture = _frames[frame_index]


func has_frames() -> bool:
	return _frames.size() >= 2 and sprite != null and sprite.texture != null


func texture_signature() -> int:
	if sprite == null or sprite.texture == null:
		return 0
	var image := sprite.texture.get_image()
	if image == null:
		return 0
	var hash_value := 0
	for y in mini(image.get_height(), 48):
		for x in mini(image.get_width(), 48):
			var color := image.get_pixel(x, y)
			hash_value = (hash_value * 33) + int(color.r8) + int(color.g8) * 13 + int(color.b8) * 17 + int(color.a8)
	return hash_value

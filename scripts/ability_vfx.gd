class_name AbilityVfx
extends Node2D

const FRAME_DURATION := 0.05
const PIXEL_ZOOM := 3.0

var _frames: Array[Texture2D] = []
var _frame_index := 0
var _elapsed := 0.0


func configure(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	for frame_index in 4:
		var texture := SpriteLibrary.texture_for("%s_fx%d" % [ability_id, frame_index])
		if texture != null:
			_frames.append(texture)
	if points.is_empty():
		return
	global_position = points[0]
	if effect_style == PlayerClass.EffectStyle.BOLT and points.size() >= 2:
		rotation = points[0].angle_to_point(points[1])
	z_index = 20
	queue_redraw()


func _process(delta: float) -> void:
	if _frames.is_empty():
		queue_free()
		return
	_elapsed += delta
	while _elapsed >= FRAME_DURATION and _frame_index < _frames.size() - 1:
		_elapsed -= FRAME_DURATION
		_frame_index += 1
	queue_redraw()
	if _frame_index >= _frames.size() - 1 and _elapsed >= FRAME_DURATION:
		queue_free()


func _draw() -> void:
	if _frames.is_empty():
		return
	var texture := _frames[_frame_index]
	var size := Vector2(texture.get_width(), texture.get_height()) * PIXEL_ZOOM
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false)

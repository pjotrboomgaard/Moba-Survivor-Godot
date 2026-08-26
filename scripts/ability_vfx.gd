class_name AbilityVfx
extends Node2D

const FRAME_DURATION := 0.06
const BASE_PIXEL_ZOOM := 6.0
const VFX_FRAME_COUNT := 6

var _frames: Array[Texture2D] = []
var _frame_index := 0
var _elapsed := 0.0
var _pixel_zoom := BASE_PIXEL_ZOOM
var _ring_radius := 0.0
var _style := PlayerClass.EffectStyle.BURST


func configure(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	_style = effect_style
	for frame_index in VFX_FRAME_COUNT:
		var texture := SpriteLibrary.texture_for("%s_fx%d" % [ability_id, frame_index])
		if texture != null:
			_frames.append(texture)
	if points.is_empty():
		return
	global_position = points[0]
	if points.size() >= 2:
		_ring_radius = points[1].x
		_pixel_zoom = BASE_PIXEL_ZOOM * clampf(_ring_radius / 120.0, 1.5, 4.2)
	if effect_style == PlayerClass.EffectStyle.BOLT and points.size() >= 2:
		rotation = points[0].angle_to_point(points[1])
	elif effect_style == PlayerClass.EffectStyle.ARC and points.size() >= 3:
		rotation = points[0].angle_to_point(points[2])
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
	if _ring_radius > 0.0 and _style != PlayerClass.EffectStyle.ARC:
		var pulse := 0.35 + float(_frame_index + 1) / float(_frames.size()) * 0.45
		draw_circle(Vector2.ZERO, _ring_radius * pulse, Color(1.0, 1.0, 1.0, 0.12))
		draw_arc(Vector2.ZERO, _ring_radius * pulse, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.24), 5.0, true)
	var texture := _frames[_frame_index]
	var size := Vector2(texture.get_width(), texture.get_height()) * _pixel_zoom
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false)

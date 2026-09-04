extends Node2D

## Flattened leftover of a killed minion. Stays a few seconds, then fades out.

const LINGER_SECONDS := 2.7
const FADE_SECONDS := 0.85

var _age := 0.0
var _fill := Color("7a3a3a")
var _outline := Color("4a2424")
var _radius := 14.0
var _has_sprite := false


func setup_from(host: Node2D) -> void:
	global_position = host.global_position
	rotation = host.rotation + (PI * 0.5 if randf() > 0.5 else -PI * 0.5)
	z_index = -2
	z_as_relative = false
	_fill = Color(host.get("fill_color"), 0.9).darkened(0.35)
	_outline = Color(host.get("outline_color"), 0.75).darkened(0.4)
	_radius = maxf(8.0, float(host.get("body_radius")))
	var sprite := host.get("sprite") as Sprite2D
	if sprite != null and is_instance_valid(sprite) and sprite.texture != null:
		var body := Sprite2D.new()
		body.texture = sprite.texture
		body.texture_filter = sprite.texture_filter
		body.scale = sprite.scale * Vector2(1.0, 0.62)
		body.offset = sprite.offset
		body.modulate = Color(0.42, 0.38, 0.4, 0.92)
		add_child(body)
		_has_sprite = true
	modulate = Color(0.78, 0.72, 0.72, 1.0)


func _ready() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LINGER_SECONDS:
		var fade := clampf(1.0 - (_age - LINGER_SECONDS) / FADE_SECONDS, 0.0, 1.0)
		modulate.a = fade
		if fade <= 0.02:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if _has_sprite:
		return
	var squash := Vector2(_radius * 1.15, _radius * 0.42)
	_draw_blob(Vector2.ZERO, squash, _fill)
	_draw_blob(Vector2.ZERO, squash, _outline, false, 2.0)


func _draw_blob(center: Vector2, radii: Vector2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	var points := PackedVector2Array()
	var steps := 18
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, width, true)

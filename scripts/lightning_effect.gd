class_name LightningEffect
extends Node2D

@export var lifetime := 0.16
@export var main_color := Color("8eeeff")
@export var chain_color := Color("b990ff")

var points := PackedVector2Array()
var elapsed := 0.0
var flicker_seed := 0


func _ready() -> void:
	flicker_seed = randi()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var effect_alpha := 1.0 - elapsed / lifetime
	for segment_index in range(points.size() - 1):
		var color := main_color if segment_index == 0 else chain_color
		color.a *= effect_alpha
		_draw_bolt(
			points[segment_index],
			points[segment_index + 1],
			color,
			4.0 if segment_index == 0 else 2.4,
			segment_index,
			effect_alpha
		)


func _draw_bolt(start: Vector2, finish: Vector2, color: Color, width: float, segment_index: int, effect_alpha: float) -> void:
	var bolt := PackedVector2Array([start])
	var distance := start.distance_to(finish)
	var steps := maxi(3, ceili(distance / 32.0))
	var normal := start.direction_to(finish).orthogonal()
	for index in range(1, steps):
		var progress := float(index) / float(steps)
		var center := start.lerp(finish, progress)
		var noise := sin(float(flicker_seed + segment_index * 31 + index * 17)) * 8.0
		bolt.append(center + normal * noise)
	bolt.append(finish)
	draw_polyline(bolt, Color(color, color.a * 0.22), width + 7.0, true)
	draw_polyline(bolt, color, width, true)
	draw_polyline(bolt, Color(0.92, 0.99, 1.0, effect_alpha), maxf(1.0, width * 0.35), true)

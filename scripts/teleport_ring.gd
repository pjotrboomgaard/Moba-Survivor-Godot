extends Node2D

## Quick expanding ring FX for teleport events.

var color: Color = Color("7ec8ff")
var t := 0.0
const LIFE := 0.4

func _init(colour: Color = Color("7ec8ff")) -> void:
	color = colour
	z_index = 30
	z_as_relative = true

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := t / LIFE
	var r := 12.0 + p * 70.0
	var a := (1.0 - p) * 0.7
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color.r, color.g, color.b, a), 2.5, true)
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 24, Color(color.r, color.g, color.b, a * 0.5), 1.5, true)
	draw_circle(Vector2.ZERO, 4.0, Color(color.r, color.g, color.b, a * 0.6))

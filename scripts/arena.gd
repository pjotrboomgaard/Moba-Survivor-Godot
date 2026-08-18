extends Node2D

const ARENA_SIZE := Vector2(2400.0, 1600.0)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-ARENA_SIZE * 0.5, ARENA_SIZE)
	draw_rect(rect, Color("111827"), true)
	var grid_color := Color(0.15, 0.20, 0.29, 0.7)
	for x in range(-1200, 1201, 100):
		draw_line(Vector2(x, -800), Vector2(x, 800), grid_color, 1.0)
	for y in range(-800, 801, 100):
		draw_line(Vector2(-1200, y), Vector2(1200, y), grid_color, 1.0)
	draw_rect(rect, Color("4b6388"), false, 8.0)


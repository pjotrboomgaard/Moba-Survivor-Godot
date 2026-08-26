class_name WorldFlash
extends Node2D

## Full-map white wipe. Sits above the arena and below players so Tobor stays visible.


func _ready() -> void:
	z_index = 8
	visible = false
	modulate.a = 0.0


func _draw() -> void:
	draw_rect(Rect2(Vector2(-4000, -3000), Vector2(8000, 6000)), Color.WHITE, true)

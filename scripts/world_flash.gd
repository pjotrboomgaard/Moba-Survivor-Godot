class_name WorldFlash
extends Node2D

## Full-map colored wipe. Sits above the arena and below players so Tobor stays visible.
## Quick wave-bump flashes use the default white; the mission-warp beat (main.gd's
## _play_mission_warp) switches this to black for a bigger, distinct "traveling" beat.

var flash_color := Color.WHITE


func _ready() -> void:
	z_index = 8
	visible = false
	modulate.a = 0.0


func set_flash_color(color: Color) -> void:
	flash_color = color
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-4000, -3000), Vector2(8000, 6000)), flash_color, true)

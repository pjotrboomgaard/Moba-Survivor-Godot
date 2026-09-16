extends Node2D

func _draw() -> void:
	# Flat dark background — empty-world baseline
	draw_rect(Rect2(-400, -400, 800, 800), Color(0.06, 0.07, 0.10, 1.0))
	# Subtle grid for spatial reference
	var grid_color := Color(0.12, 0.14, 0.20, 0.4)
	for i in range(-3, 4):
		var pos := i * 100.0
		draw_line(Vector2(pos, -300), Vector2(pos, 300), grid_color, 1.0)
		draw_line(Vector2(-300, pos), Vector2(300, pos), grid_color, 1.0)
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-150, -200), "ARCLIGHT VFX ISOLATED TEST", HORIZONTAL_ALIGNMENT_LEFT, 300, 14, Color(0.6, 0.7, 0.9, 0.6))

extends Node2D
## Wall outline drawing for the creep unstuck isolated test.
var half_w := 20.0
var half_h := 200.0

func _draw() -> void:
	var c := Color(0.7, 0.4, 0.2, 0.9)
	# Fill
	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), Color(0.45, 0.28, 0.15, 0.85))
	# Outline
	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), c, false, 3.0)

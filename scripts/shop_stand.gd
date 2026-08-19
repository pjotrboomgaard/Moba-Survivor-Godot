extends Node2D

## Purely decorative + a landmark for main.gd's proximity check (Arena.SHOP_STAND_POSITION) —
## the actual shop UI is the existing HUD panel, opened/closed by main.gd when a player walks
## within range. Kept as plain vector art rather than pixel art so it doesn't need a
## sprite_forge pass, and reads fine in Classic mode too if it's ever enabled there.

const WIDTH := 96.0
const HEIGHT := 64.0
const ROOF_COLOR := Color("ffcb3d")
const ROOF_OUTLINE := Color("ffe9a8")
const POST_COLOR := Color("6b4a1a")


func _draw() -> void:
	var half := WIDTH * 0.5
	# Posts.
	draw_line(Vector2(-half + 8.0, 0.0), Vector2(-half + 8.0, HEIGHT), POST_COLOR, 6.0)
	draw_line(Vector2(half - 8.0, 0.0), Vector2(half - 8.0, HEIGHT), POST_COLOR, 6.0)
	# Awning.
	var roof := PackedVector2Array([
		Vector2(-half, 0.0),
		Vector2(half, 0.0),
		Vector2(half - 10.0, -28.0),
		Vector2(-half + 10.0, -28.0),
	])
	draw_colored_polygon(roof, ROOF_COLOR)
	draw_polyline(roof + PackedVector2Array([roof[0]]), ROOF_OUTLINE, 3.0)
	# Counter.
	draw_rect(Rect2(Vector2(-half + 4.0, HEIGHT - 14.0), Vector2(WIDTH - 8.0, 14.0)), POST_COLOR)
	# Coin.
	draw_circle(Vector2.ZERO, 12.0, ROOF_COLOR)
	draw_circle(Vector2.ZERO, 12.0, ROOF_OUTLINE, false, 2.0)

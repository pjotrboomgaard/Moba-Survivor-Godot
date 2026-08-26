class_name Obstacle
extends StaticBody2D

## A rock the party and the horde both have to walk around. The sprite is lifted
## above its collision circle so the rock reads as sticking up out of the grass.

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var body_radius := 30.0


func configure(sprite_name: String, radius: float, pixel_zoom: float, lift_pixels: float) -> void:
	body_radius = radius
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle

	sprite.texture = SpriteLibrary.texture_for(sprite_name)
	sprite.scale = Vector2(pixel_zoom, pixel_zoom)
	sprite.offset = Vector2(0.0, -lift_pixels)
	queue_redraw()


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func _draw() -> void:
	# A soft contact shadow so the rock does not float on the grass.
	var shadow := Color(0.03, 0.06, 0.03, 0.35)
	if GameRuntime.uses_biomes() and GameRuntime.biome_id != 0:
		shadow = Color(0.06, 0.03, 0.02, 0.45)
	draw_circle(Vector2(0.0, body_radius * 0.16), body_radius * 0.95, shadow)
	if not has_sprite():
		draw_circle(Vector2.ZERO, body_radius, Color("5b6675"))

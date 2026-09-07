class_name Obstacle
extends StaticBody2D

## A rock the party and the horde both have to walk around. The sprite is lifted
## above its collision circle so the rock reads as sticking up out of the grass.

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var body_radius := 30.0
var sprite_id := ""


func configure(sprite_name: String, radius: float, pixel_zoom: float, lift_pixels: float) -> void:
	sprite_id = sprite_name
	body_radius = radius
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle

	sprite.texture = SpriteLibrary.texture_for(sprite_name)
	var zoom := pixel_zoom
	if sprite_name.begins_with("tree"):
		zoom = pixel_zoom * 2.15
		lift_pixels *= 1.8
	sprite.scale = Vector2(zoom, zoom)
	sprite.offset = Vector2(0.0, -lift_pixels)
	z_as_relative = false
	z_index = 12 if sprite_name.begins_with("tree") else 8
	queue_redraw()


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func _draw() -> void:
	# Tight oval under the prop — a full gray disc reads as a rock even when the sprite loaded.
	var shadow := Color(0.04, 0.07, 0.03, 0.28)
	if GameRuntime.uses_biomes() and GameRuntime.biome_id != 0:
		shadow = Color(0.06, 0.03, 0.02, 0.32)
	var shadow_w := body_radius * 0.62
	var shadow_h := body_radius * 0.28
	draw_set_transform(Vector2(0.0, body_radius * 0.22), 0.0, Vector2(1.0, shadow_h / maxf(shadow_w, 1.0)))
	draw_circle(Vector2.ZERO, shadow_w, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

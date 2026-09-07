class_name Obstacle
extends StaticBody2D

## A rock the party and the horde both have to walk around. The sprite is lifted
## above its collision circle so the rock reads as sticking up out of the grass.

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

## Dedicated bit (distinct from the default collision_layer=16 every obstacle already has
## for movement blocking) so a fog-of-war line-of-sight raycast can query "is there a TREE
## between these two points" without also stopping at rocks/grass, and without a hit on a
## closer rock masking a farther tree that's the one actually relevant to vision.
const VISION_BLOCKER_LAYER := 32

var body_radius := 30.0
var sprite_id := ""


func configure(sprite_name: String, radius: float, pixel_zoom: float, lift_pixels: float) -> void:
	sprite_id = sprite_name
	body_radius = radius
	var circle := CircleShape2D.new()
	circle.radius = maxf(0.1, radius)
	collision.shape = circle
	var decorative := radius < 1.0
	collision.disabled = decorative
	if decorative:
		collision_layer = 0
		collision_mask = 0

	sprite.texture = SpriteLibrary.texture_for(sprite_name)
	var is_tree := sprite_name.contains("tree")
	var zoom := display_zoom(sprite_name, pixel_zoom, sprite.texture)
	sprite.scale = Vector2(zoom, zoom)
	# Offset is in texture pixels, then multiplied by scale. Pin the trunk/foot
	# to the collision origin so large native trees stay planted on the click.
	if is_tree and sprite.texture != null:
		sprite.offset = Vector2(0.0, -float(sprite.texture.get_height()) * 0.5)
	else:
		sprite.offset = Vector2(0.0, -lift_pixels)
	z_as_relative = false
	if sprite != null:
		sprite.z_as_relative = false
	if is_floor_cover(sprite_name):
		z_index = 1
	elif decorative:
		# Below landmark pads (z 2) so tufts/flowers never paint over shrines.
		z_index = 1
	else:
		z_index = 12 if is_tree else 8
	if is_tree:
		# Trees hide units behind them via LOS raycasts. They do not cast 2D-light umbras.
		collision_layer |= VISION_BLOCKER_LAYER
	queue_redraw()


func is_vision_blocker() -> bool:
	return sprite_id.contains("tree")


static func tree_display_zoom(pixel_zoom: float, texture: Texture2D) -> float:
	var native := 16.0
	if texture != null:
		native = float(maxi(1, texture.get_width()))
	return pixel_zoom * 2.15 * (16.0 / native)


## World scale for a prop. Kenney mushrooms/bushes shipped at 32px and were
## drawn at the same zoom as 8px tufts, so they read as huge. Shrink those to
## a tuft-adjacent footprint; trees keep their dedicated size helper.
static func display_zoom(sprite_name: String, pixel_zoom: float, texture: Texture2D) -> float:
	if sprite_name.contains("tree"):
		return tree_display_zoom(pixel_zoom, texture)
	var native := 16.0
	if texture != null:
		native = float(maxi(1, texture.get_width()))
	if sprite_name.contains("mushroom"):
		return pixel_zoom * (10.0 / native)
	if sprite_name.contains("bush") and native > 16.0:
		return pixel_zoom * (14.0 / native)
	return pixel_zoom


static func is_floor_cover(sprite_name: String) -> bool:
	return sprite_name == "grass_lush" or sprite_name == "grass_meadow" or sprite_name == "dirt_tile"


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null

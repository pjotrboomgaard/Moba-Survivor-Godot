class_name Obstacle
extends StaticBody2D

const WorldClock := preload("res://scripts/world_clock.gd")

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
var _shadow: Sprite2D = null
var _shadow_rev := -1


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
		sprite.z_as_relative = true
	if is_floor_cover(sprite_name):
		z_index = 1
	elif decorative:
		# Below landmark pads (z 2) so tufts/flowers never paint over shrines.
		z_index = 1
	elif is_tree:
		z_index = WorldClock.depth_z(global_position.y)
	else:
		z_index = 8
	if is_tree:
		# Trees hide units behind them via LOS raycasts. They do not cast 2D-light umbras.
		collision_layer |= VISION_BLOCKER_LAYER
		set_process(false)
	else:
		# Small non-tree objects (rocks, crates, etc.) get a subtle ground shadow.
		if not decorative and body_radius >= 1.0:
			_ensure_small_shadow(zoom, lift_pixels)
		set_process(false)
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


func _ensure_small_shadow(zoom: float, lift_pixels: float) -> void:
	if _shadow != null:
		return
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.z_as_relative = false
	_shadow.z_index = -1
	var radius_px := int(maxf(4.0, body_radius * zoom * 0.85))
	var w := maxi(4, radius_px)
	var h := maxi(2, int(radius_px * 0.5))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w * 0.5, h * 0.5)
	for y in h:
		for x in w:
			var d := Vector2(x - center.x, y - center.y).length()
			var alpha := 0.0
			if d < w * 0.35:
				alpha = 1.0
			elif d < w * 0.5:
				alpha = 1.0 - (d - w * 0.35) / (w * 0.15)
			img.set_pixel(x, y, Color(0, 0, 0, alpha * 0.45))
	_shadow.texture = ImageTexture.create_from_image(img)
	_shadow.position = Vector2(0.0, lift_pixels * 0.35)
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.22)
	add_child(_shadow)


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null

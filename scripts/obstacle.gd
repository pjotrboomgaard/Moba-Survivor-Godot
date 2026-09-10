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
var _is_tree_shadow := false
var _shadow_img: Image = null

## Sprite ID prefixes that should stay bright and glow at night (counteracting the
## dark blue ambient). Lava, fire, powerlines, and similar emissive assets.
const GLOW_AT_NIGHT_PREFIXES: Array[String] = [
	"lava", "fire", "flame", "ember", "magma", "furnace", "forge",
	"powerline", "power", "cable", "wire", "neon", "sign",
	"lamp", "light", "glow", "led", "spark", "circuit", "pipe",
]
## How strongly to counteract the night ambient. 1.0 = full counteract (stays at
## day brightness), >1.0 = slightly brighter than day at night (true glow).
const GLOW_COMPENSATE := 1.15
var _glow_at_night := false

## Shared shadow textures keyed by sprite_id. Every tree of the same type uses
## the same silhouette Image/Texture — built once, copied for all trees of that
## type. This avoids re-running the O(pixels) silhouette extraction per obstacle.
static var _shared_shadow_cache: Dictionary = {}
## Shared rock/blob shadow textures keyed by an approximate radius bucket.
static var _shared_rock_shadow_cache: Dictionary = {}


func configure(sprite_name: String, radius: float, pixel_zoom: float, lift_pixels: float) -> void:
	sprite_id = sprite_name
	body_radius = radius
	_glow_at_night = _is_glow_eligible(sprite_name)
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
	# Town buildings are drawn straight (no tilt) so they read as placed houses
	# rather than random spinning blocks. Each style has its own pixel art, so the
	# variety comes from the art, not from rotation.
	if sprite_name.begins_with("town_"):
		sprite.rotation = 0.0
		sprite.offset = Vector2(0.0, -lift_pixels * 0.6)
		z_index = WorldClock.depth_z(global_position.y) + 4
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
		# Pure painter's algorithm by base y: a unit standing *behind* the tree
		# (smaller y) renders in front of it? No — larger y renders on top, so a
		# unit with a larger y (in front of the tree) paints over the canopy, and
		# a unit with a smaller y (behind) is covered. This matches the requested
		# front/behind rule without a magic bias that mis-sorted the canopy.
		z_index = WorldClock.depth_z(global_position.y)
	else:
		# Rocks and other solid obstacles use the same painter's-algorithm depth
		# sort as trees, so the player can walk BEHIND them (they get occluded
		# when the player is on the near side) and in FRONT of them when on the
		# far side. Previously they used a fixed z=8, which put them permanently
		# in the background and broke the front/behind rule (Task: rocks behave
		# like trees).
		z_index = WorldClock.depth_z(global_position.y)
	if is_tree:
		# Trees hide units behind them via LOS raycasts. They do not cast 2D-light umbras,
		# but they cast a rotating canopy shadow that follows the sun and fits the trunk.
		collision_layer |= VISION_BLOCKER_LAYER
		_ensure_shadow(zoom, is_tree)
		# Always keep processing so the shadow appears the moment the sun
		# alpha becomes positive (obstacles can spawn before the first
		# WorldClock.tick() in some launch paths).
		set_process(true)
	else:
		# Small non-tree objects (rocks, crates, etc.) get a rotating ground shadow
		# that fits their footprint and swings with the sun.
		if not decorative and body_radius >= 1.0:
			_ensure_shadow(zoom, is_tree)
			set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	# Only rebuild the shadow when the sun actually moved (revision changed).
	if _shadow_rev == WorldClock.revision:
		return
	if WorldClock.shadow_alpha <= 0.0:
		set_process(false)
		_update_shadow_rotation()
		_refresh_glow()
		return
	_update_shadow()
	_refresh_glow()


## At night, the CanvasModulate darkens the whole scene with WorldClock.ambient
## (a dark blue tint). Glow-eligible sprites (lava, fire, powerlines, etc.)
## counteract this by boosting their own modulate so they stay bright — and even
## glow slightly above day brightness. The ambient color is applied uniformly, so
## dividing the sprite's modulate by ambient restores full brightness; multiplying
## by GLOW_COMPENSATE on top makes them emit light relative to the dark surroundings.
func _refresh_glow() -> void:
	if sprite == null:
		return
	if not _glow_at_night:
		sprite.modulate = Color.WHITE
		return
	if WorldClock.is_night and WorldClock.ambient != Color.WHITE:
		# Counteract the ambient darkening + add a glow boost.
		var r := GLOW_COMPENSATE / maxf(0.01, WorldClock.ambient.r)
		var g := GLOW_COMPENSATE / maxf(0.01, WorldClock.ambient.g)
		var b := GLOW_COMPENSATE / maxf(0.01, WorldClock.ambient.b)
		sprite.modulate = Color(minf(r, 2.5), minf(g, 2.5), minf(b, 2.5), 1.0)
	else:
		sprite.modulate = Color.WHITE


func _update_shadow_rotation() -> void:
	if _shadow == null:
		return
	var dir := WorldClock.sun_dir
	# Shadow points away from the sun. At dawn the sun is low in the east
	# (small +x), so the shadow points west (-x) and is long. At noon the sun
	# is high (dir ~ (0.0, 1.0)), so the shadow points straight down (-y) and
	# is short. At dusk the sun is low in the west, shadow points east.
	var shadow_dir := -dir
	var angle := shadow_dir.angle()
	if _is_tree_shadow:
		# Ground projection of the tree's own silhouette.
		#
		# The shadow texture is a 1:1 copy of the tree: trunk at the texture
		# bottom (local +Y), canopy at the top (local -Y). A real tree's shadow
		# on the ground is NOT as long as the tree — it's the canopy's footprint
		# lying flat, stretching with how low the sun is. So we:
		#   1. rotate so the canopy end (local -Y) points away from the sun
		#      (along shadow_dir), i.e. the tree "falls" that way with its trunk
		#      base planted at the obstacle origin;
		#   2. scale it down to a ground-appropriate length (not full tree
		#      height) and flatten it perpendicular to the fall so it reads as a
		#      projection lying on the grass;
		#   3. place the trunk root (local +Y end) at the tree base so the
		#      shadow grows out from the trunk instead of floating beside it.
		_shadow.rotation = angle + PI / 2.0
		var tree_scale := sprite.scale if sprite != null else Vector2.ONE
		var stretch := WorldClock.shadow_stretch
		# Shadow length = fraction of the on-screen tree height that grows when
		# the sun drops. 0.55x at noon (short), up to ~0.9x at dawn/dusk.
		var length_factor := 0.55 + 0.35 * stretch
		# Flatten perpendicular to the fall (local X after rotation) so the
		# canopy reads as lying on the ground rather than standing upright.
		var flatten := 0.62
		_shadow.scale = tree_scale * Vector2(flatten, length_factor)
		# Anchor the trunk end at the tree base. The texture center is at the
		# sprite origin; after rotation the trunk end sits `len/2` back along
		# shadow_dir. Placing the sprite center `len/2` forward along shadow_dir
		# makes the trunk root land exactly on the obstacle origin.
		var tree_h := 0.0
		if _shadow_img != null:
			tree_h = _shadow_img.get_height() * tree_scale.y
		var shadow_len := tree_h * length_factor
		_shadow.position = shadow_dir * (shadow_len * 0.5)
	else:
		# Rocks keep a small fixed base offset so their blob stays under the rock.
		var off := body_radius * 0.22
		_shadow.position = shadow_dir * off
		_shadow.scale = Vector2.ONE
	_shadow.modulate = Color(0.0, 0.0, 0.0, WorldClock.shadow_alpha)


func _update_shadow() -> void:
	_shadow_rev = WorldClock.revision
	_update_shadow_rotation()


func _ensure_shadow(zoom: float, is_tree: bool) -> void:
	if _shadow != null:
		return
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	# Keep the shadow one unit below the obstacle sprite but still above the
	# arena ground so it is actually visible (absolute -1 was hidden behind the
	# ground layer).
	_shadow.z_as_relative = true
	_shadow.z_index = -1
	_is_tree_shadow = is_tree
	_build_shadow_texture(zoom)
	_update_shadow_rotation()
	add_child(_shadow)


func _build_shadow_texture(zoom: float) -> void:
	# Shape-fit the shadow: trees derive their silhouette from the actual
	# sprite texture (trunk-to-canopy pixels become a dark ground shape),
	# rocks are smaller rounder blobs. Both caches are shared across obstacles
	# of the same type so the O(pixels) silhouette work only runs once.
	if _is_tree_shadow:
		var key := "tree:" + sprite_id
		var cached: Image = _shared_shadow_cache.get(key) as Image
		if cached == null:
			var tex := sprite.texture if sprite != null else null
			var src := tex.get_image() if tex != null else null
			var radius_px := int(maxf(4.0, body_radius * zoom * 0.9))
			if src == null:
				# Build the generic fallback into a temp and store it so every
				# tree of this type shares the same result.
				_build_fallback_tree_img(radius_px)
				cached = _shadow_img
				_shadow_img = null
			else:
				cached = _silhouette_from_image(src)
			_shared_shadow_cache[key] = cached
		_shadow_img = cached
		_shadow.texture = ImageTexture.create_from_image(_shadow_img)
	else:
		# Rocks: small rounder blobs that read as a cast shadow at the base.
		# Bucket the pixel size so similar rocks share a single texture.
		var radius_px := int(maxf(4.0, body_radius * zoom * 0.9))
		var bucket := int(radius_px / 2.0)
		var key := "rock:%d" % bucket
		var cached: Image = _shared_rock_shadow_cache.get(key) as Image
		if cached == null:
			var w := maxi(8, int(radius_px * 0.72))
			var h := maxi(6, int(radius_px * 0.45))
			var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			var center := Vector2(w * 0.5, h * 0.5)
			for y in h:
				for x in w:
					var px := Vector2(x - center.x, y - center.y)
					var nd := Vector2(px.x / (w * 0.5), px.y / (h * 0.5))
					var d := nd.length()
					var alpha := 0.0
					if d < 0.55:
						alpha = 1.0
					elif d < 1.0:
						alpha = 1.0 - (d - 0.55) / 0.45
					img.set_pixel(x, y, Color(0, 0, 0, alpha * 0.95))
			cached = img
			_shared_rock_shadow_cache[key] = cached
		_shadow_img = cached
		_shadow.texture = ImageTexture.create_from_image(_shadow_img)


## Derive a 1:1 dark silhouette from a source Image. Every pixel whose alpha
## exceeds 0.4 becomes a dark shadow pixel; everything else stays transparent.
func _silhouette_from_image(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a > 0.4:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.55))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return img


## Fallback generic tapered-ellipse tree shadow (used only if the sprite
## texture can't be read via get_image()). Builds the result into _shadow_img.
func _build_fallback_tree_img(radius_px: int) -> void:
	var w := maxi(8, int(radius_px * 1.6))
	var h := maxi(6, int(radius_px * 1.0))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w) * 0.5
	for y in h:
		var t := float(y) / float(h)
		var half_w := (w * 0.5) * (1.0 - t * 0.85)
		if t < 0.4:
			half_w *= 1.15
		for x in w:
			var dx := absf(float(x) - cx)
			var alpha := 0.0
			if dx < half_w * 0.7:
				alpha = 1.0
			elif dx < half_w:
				alpha = 1.0 - (dx - half_w * 0.7) / (half_w * 0.3)
			if t > 0.85:
				alpha *= (1.0 - t) / 0.15
			if alpha > 0.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha * 0.85))
	_shadow_img = img


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
	# Town buildings: render noticeably larger than the 32px art implies so the
	# settlement reads as bigger houses (was feeling small at pixel_zoom 4).
	if sprite_name.begins_with("town_"):
		return pixel_zoom * 1.8
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

## True for sprite ids that represent emissive/glowing assets which should stay
## bright (and glow) at night: lava, fire, powerlines, neon signs, etc.
static func _is_glow_eligible(sprite_name: String) -> bool:
	for prefix in GLOW_AT_NIGHT_PREFIXES:
		if sprite_name.contains(prefix):
			return true
	return false


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
			img.set_pixel(x, y, Color(0, 0, 0, alpha * 0.75))
	_shadow.texture = ImageTexture.create_from_image(img)
	_shadow.position = Vector2(0.0, lift_pixels * 0.35)
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.22)
	add_child(_shadow)


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null

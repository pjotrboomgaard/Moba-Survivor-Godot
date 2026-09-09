extends Node2D

## Tiny flat pixel-art corpse left at a killed creep's position.
## Stays LINGER_SECONDS, then fades over FADE_SECONDS, then frees itself.
## Belongs to the "corpses" group so main.gd can enforce the live-corpse cap.

const LINGER_SECONDS := 30.0
const FADE_SECONDS := 2.0

var _age := 0.0
var _sprite: Sprite2D = null
var _fading := false


func _ready() -> void:
	add_to_group("corpses")


## Sets the corpse's appearance from the killed enemy's sprite.
## Produces a unique "flattened dead pixel" version of that enemy: the live sprite
## image is reused but squashed flat, darkened/desaturated, with dead X-eyes.
func configure(texture: Texture2D, base_scale: Vector2, tint: Color) -> void:
	if texture == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = _build_corpse_image(texture, tint)
	_sprite.z_as_relative = false
	# Flat + wide: squash vertically (lying down) and shrink to ~0.6 of the live
	# enemy. The vertical squash is what reads as "flattened / dead".
	_sprite.scale = base_scale * Vector2(0.62, 0.62 * 0.42)
	add_child(_sprite)
	# A dead body lies at a random angle.
	rotation = randf() * TAU
	# Render just above the ground so it's visible (the depth-z system puts the
	# ground at z=0; units sit at z>=500). Corpses must sit *above* the ground
	# texture but *below* live units, so use a low positive z.
	z_index = 12
	z_as_relative = false


## Take the enemy's live pixel-art texture and turn it into a flattened, dead
## version: darken + desaturate every pixel, flatten the image vertically so it
## reads as "lying down", and stamp two dead X-eye pixels on the upper third so
## it's unmistakably a corpse of that specific enemy.
func _build_corpse_image(src: Texture2D, tint: Color) -> ImageTexture:
	var img: Image = src.get_image()
	if img == null:
		return src
	var w := img.get_width()
	var h := img.get_height()
	# Flatten vertically: new height is ~55% of the original, sampling from the
	# top half so the head/eyes survive the squish.
	var new_h := maxi(4, int(round(float(h) * 0.55)))
	var flat := Image.create(w, new_h, false, Image.FORMAT_RGBA8)
	for y in new_h:
		for x in w:
			# Sample from upper portion of the source to preserve head detail.
			var sy := int(round(float(y) / float(new_h) * float(h * 0.6)))
			sy = clampi(sy, 0, h - 1)
			var c: Color = img.get_pixel(x, sy)
			if c.a < 0.1:
				flat.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Desaturate + darken, but keep more of the original color for visual detail.
			var grey: float = c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			# Blend: 60% desaturated grey, 40% original color → reads as "colored but dead".
			var out := Color(c.r, c.g, c.b, c.a).lerp(Color(grey * 0.65, grey * 0.6, grey * 0.55, c.a), 0.5)
			out = out.lerp(tint, 0.3)
			# Slight darkening at the bottom (like blood pooling on the ground).
			if y > new_h * 0.7:
				out = out.lerp(Color(0.15, 0.05, 0.05, c.a), 0.25)
			flat.set_pixel(x, y, out)
	# Stamp two dead X-eyes in the upper-center third of the corpse.
	var eye_y := maxi(1, new_h / 3)
	var cx := w / 2
	var eye_dx := maxi(1, int(w * 0.16))
	var s := maxi(1, mini(2, w / 8))
	for dx in [-eye_dx, eye_dx]:
		for i in s:
			for j in s:
				var px: int = cx + dx + i - j
				var py: int = eye_y + abs(i - j)
				if px >= 0 and px < w and py >= 0 and py < new_h:
					flat.set_pixel(px, py, Color(0.1, 0.08, 0.1, 0.95))
	return ImageTexture.create_from_image(flat)


func _process(delta: float) -> void:
	_age += delta
	if not _fading and _age >= LINGER_SECONDS:
		_fading = true
	if _fading:
		var fade_progress := clampf((_age - LINGER_SECONDS) / FADE_SECONDS, 0.0, 1.0)
		modulate.a = 1.0 - fade_progress
		if fade_progress >= 1.0:
			queue_free()

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
func configure(texture: Texture2D, base_scale: Vector2, _tint: Color) -> void:
	if texture == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	# Flat + tiny: squash vertically and shrink to ~0.55 of the live enemy.
	_sprite.scale = base_scale * Vector2(0.55, 0.55 * 0.6)
	# Darkened/desaturated so it reads as a dead body.
	_sprite.modulate = Color(0.45, 0.45, 0.45, 1.0)
	add_child(_sprite)
	# A dead body lies at a random angle.
	rotation = randf() * TAU
	# Render on the ground, below enemies.
	z_index = -2
	z_as_relative = false


func _process(delta: float) -> void:
	_age += delta
	if not _fading and _age >= LINGER_SECONDS:
		_fading = true
	if _fading:
		var fade_progress := clampf((_age - LINGER_SECONDS) / FADE_SECONDS, 0.0, 1.0)
		modulate.a = 1.0 - fade_progress
		if fade_progress >= 1.0:
			queue_free()

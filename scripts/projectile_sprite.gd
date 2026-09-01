class_name ProjectileSprite
extends Node2D

## Lightweight rolling/lobbed projectile visual for ability casts (keg roll, etc.).
## Uses the ability icon PNG as its sprite, tweens from `from_global` to `to_global`
## over `travel_time` seconds, spins around its own axis, then calls `on_landed`.

signal landed(projectile: ProjectileSprite)

var on_landed: Callable
var from_global: Vector2 = Vector2.ZERO
var to_global: Vector2 = Vector2.ZERO
var travel_time: float = 0.35
var arc_height: float = 36.0
var spin_speed: float = 540.0

@onready var _sprite: Sprite2D = $Sprite2D
var _elapsed: float = 0.0
var _landed_called := false


func setup(p_ability_id: String, p_from: Vector2, p_to: Vector2, p_travel_time: float, p_arc_height: float = 36.0) -> void:
	from_global = p_from
	to_global = p_to
	travel_time = p_travel_time
	arc_height = p_arc_height
	global_position = p_from
	var texture := SpriteLibrary.texture_for(p_ability_id)
	if texture != null:
		_sprite_node().texture = texture
		_sprite_node().scale = Vector2(2.5, 2.5)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / travel_time, 0.0, 1.0)
	var ground := from_global.lerp(to_global, t)
	var parabola := -arc_height * 4.0 * t * (1.0 - t)  # peak mid-flight
	global_position = ground + Vector2(0.0, parabola)
	_sprite_node().rotation_degrees += spin_speed * delta
	if t >= 1.0 and not _landed_called:
		_landed_called = true
		landed.emit(self)
		if on_landed.is_valid():
			on_landed.call(self)
		queue_free()


func _sprite_node() -> Sprite2D:
	return _sprite if is_instance_valid(_sprite) else get_node("Sprite2D") as Sprite2D

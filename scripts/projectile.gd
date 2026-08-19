class_name SurvivorProjectile
extends Area2D

const PLAYER_LAYER := 2
const ENEMY_LAYER := 4
const WORLD_LAYER := 1

const SPRITE_RADIUS := 9.0

@export var speed: float = 650.0
@export var lifetime: float = 1.5

@onready var sprite: Sprite2D = $Sprite

var direction := Vector2.RIGHT
var damage: float = 10.0
var target_group := "enemies"
var fill_color := Color("ffd35a")
var is_cosmetic := false
var sprite_name := "spark"


func _ready() -> void:
	_apply_sprite()
	queue_redraw()


func configure(next_direction: Vector2, next_damage: float, next_speed: float, hostile: bool, cosmetic: bool, next_sprite_name: String = "") -> void:
	direction = next_direction.normalized()
	damage = next_damage
	speed = next_speed
	is_cosmetic = cosmetic
	if hostile:
		target_group = "players"
		fill_color = Color("c58aff")
		collision_mask = WORLD_LAYER | PLAYER_LAYER
		sprite_name = "spit"
	else:
		target_group = "enemies"
		fill_color = Color("ffd35a")
		collision_mask = WORLD_LAYER | ENEMY_LAYER
		sprite_name = "spark"
	if not next_sprite_name.is_empty():
		sprite_name = next_sprite_name
	if is_cosmetic:
		monitoring = false
		monitorable = false
	_apply_sprite()
	queue_redraw()


func _apply_sprite() -> void:
	if sprite == null:
		return
	sprite.texture = SpriteLibrary.texture_for(sprite_name)
	sprite.scale = SpriteLibrary.scale_for_radius(sprite.texture, SPRITE_RADIUS)
	sprite.rotation = direction.angle() + PI * 0.5


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if is_cosmetic:
		return
	if body.is_in_group("obstacles"):
		queue_free()
		return
	if not body.is_in_group(target_group):
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.take_damage(damage)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, SPRITE_RADIUS, Color(fill_color, 0.22))
	if not has_sprite():
		draw_circle(Vector2.ZERO, 6.0, fill_color)

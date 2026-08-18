class_name SurvivorProjectile
extends Area2D

@export var speed: float = 650.0
@export var lifetime: float = 1.5
var direction := Vector2.RIGHT
var damage: float = 10.0


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.take_damage(damage)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color("ffd35a"))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.72, 0.2, 0.25))


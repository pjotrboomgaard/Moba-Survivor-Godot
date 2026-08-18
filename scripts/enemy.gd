class_name Enemy
extends CharacterBody2D

signal defeated(enemy: Enemy)

@export var movement_speed := 105.0
@export var contact_damage := 10.0
@export var attack_interval := 0.8
@export var attack_distance := 40.0
@export var xp_value := 10

@onready var health: HealthComponent = $HealthComponent

var network_id := 0
var server_authoritative := true
var target: Node2D
var attack_cooldown := 0.0
var network_target_position := Vector2.ZERO


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	network_target_position = global_position
	queue_redraw()


func configure(next_network_id: int, authoritative: bool) -> void:
	network_id = next_network_id
	server_authoritative = authoritative
	network_target_position = global_position


func _physics_process(delta: float) -> void:
	if not server_authoritative:
		global_position = global_position.lerp(network_target_position, clampf(delta * 12.0, 0.0, 1.0))
		return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	target = _find_nearest_player()
	if target == null:
		velocity = Vector2.ZERO
		return

	var distance := global_position.distance_to(target.global_position)
	if distance > attack_distance:
		velocity = global_position.direction_to(target.global_position) * movement_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_attack_target()


func apply_network_state(state: Dictionary) -> void:
	network_target_position = state.get("position", global_position)
	health.set_network_state(
		state.get("health", health.current_health),
		state.get("max_health", health.max_health)
	)


func snapshot() -> Dictionary:
	return {
		"id": network_id,
		"position": global_position,
		"health": health.current_health,
		"max_health": health.max_health,
	}


func is_damageable() -> bool:
	return server_authoritative and not health.is_dead


func _find_nearest_player() -> Node2D:
	var nearest: Node2D
	var nearest_distance_sq := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player or not candidate.active:
			continue
		var distance_sq: float = global_position.distance_squared_to(candidate.global_position)
		if distance_sq < nearest_distance_sq:
			nearest = candidate
			nearest_distance_sq = distance_sq
	return nearest


func _attack_target() -> void:
	if attack_cooldown > 0.0 or target == null:
		return
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if target_health != null:
		target_health.take_damage(contact_damage)
		attack_cooldown = attack_interval


func _on_damaged(_amount: float) -> void:
	if not server_authoritative:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.04)
	tween.tween_property(self, "modulate", Color("ff5d5d"), 0.1)


func _on_died() -> void:
	if not server_authoritative:
		return
	remove_from_group("enemies")
	set_physics_process(false)
	defeated.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 17.0, Color("ff5d5d"))
	draw_circle(Vector2.ZERO, 17.0, Color("ffb0a9"), false, 3.0)

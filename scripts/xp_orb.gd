class_name XPOrb
extends Area2D

@export var xp_value := 10
@export var attraction_radius := 105.0
@export var attraction_speed := 350.0
@export var pickup_distance := 24.0

var network_id := 0
var server_authoritative := true
var network_target_position := Vector2.ZERO


func _ready() -> void:
	network_target_position = global_position
	queue_redraw()


func configure(next_network_id: int, authoritative: bool) -> void:
	network_id = next_network_id
	server_authoritative = authoritative
	network_target_position = global_position


func _physics_process(delta: float) -> void:
	if not server_authoritative:
		global_position = global_position.lerp(network_target_position, clampf(delta * 14.0, 0.0, 1.0))
		return

	var target := _nearest_player()
	if target == null:
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= pickup_distance:
		target.add_xp(xp_value)
		queue_free()
	elif distance <= attraction_radius:
		global_position = global_position.move_toward(target.global_position, attraction_speed * delta)


func apply_network_state(state: Dictionary) -> void:
	network_target_position = state.get("position", global_position)
	xp_value = state.get("value", xp_value)


func snapshot() -> Dictionary:
	return {
		"id": network_id,
		"position": global_position,
		"value": xp_value,
	}


func _nearest_player() -> Player:
	var nearest: Player
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Player and candidate.active:
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
	return nearest


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(0.31, 0.96, 0.62, 0.18))
	draw_circle(Vector2.ZERO, 5.0, Color("50f59e"))

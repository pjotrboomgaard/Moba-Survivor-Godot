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
var enemy_kind := "grunt"
var visual_radius := 17.0
var target: Node2D
var attack_cooldown := 0.0
var network_target_position := Vector2.ZERO


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	network_target_position = global_position
	queue_redraw()


func configure(next_network_id: int, authoritative: bool, kind: String = "grunt", difficulty: float = 1.0) -> void:
	network_id = next_network_id
	server_authoritative = authoritative
	enemy_kind = kind
	_apply_profile(kind, difficulty)
	network_target_position = global_position
	queue_redraw()


func _apply_profile(kind: String, difficulty: float) -> void:
	var profile := {
		"speed": 105.0,
		"damage": 10.0,
		"health": 30.0,
		"xp": 10,
		"radius": 17.0,
	}
	match kind:
		"swift":
			profile = {"speed": 172.0, "damage": 7.0, "health": 21.0, "xp": 12, "radius": 13.0}
		"brute":
			profile = {"speed": 67.0, "damage": 17.0, "health": 96.0, "xp": 30, "radius": 26.0}
		"elite":
			profile = {"speed": 92.0, "damage": 19.0, "health": 156.0, "xp": 50, "radius": 31.0}
	movement_speed = float(profile.speed) * minf(1.35, 1.0 + (difficulty - 1.0) * 0.12)
	contact_damage = float(profile.damage) * difficulty
	xp_value = roundi(float(profile.xp) * minf(1.75, difficulty))
	visual_radius = float(profile.radius)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		var circle := collision.shape.duplicate() as CircleShape2D
		circle.radius = visual_radius
		collision.shape = circle
	health.max_health = float(profile.health) * difficulty
	health.current_health = health.max_health
	health.is_dead = false


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
	var next_kind := str(state.get("kind", enemy_kind))
	if next_kind != enemy_kind:
		enemy_kind = next_kind
		_apply_profile(enemy_kind, 1.0)
		queue_redraw()
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
		"kind": enemy_kind,
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
	tween.tween_property(self, "modulate", Color("ff8a8a"), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)


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
	match enemy_kind:
		"swift":
			var diamond := PackedVector2Array([
				Vector2(0.0, -visual_radius), Vector2(visual_radius, 0.0),
				Vector2(0.0, visual_radius), Vector2(-visual_radius, 0.0),
			])
			draw_colored_polygon(diamond, Color("ff9d4d"))
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("ffd49a"), 3.0)
		"brute":
			draw_rect(Rect2(Vector2.ONE * -visual_radius, Vector2.ONE * visual_radius * 2.0), Color("9d4edd"), true)
			draw_rect(Rect2(Vector2.ONE * -visual_radius, Vector2.ONE * visual_radius * 2.0), Color("dfb6ff"), false, 4.0)
		"elite":
			var hexagon := PackedVector2Array()
			for index in range(6):
				hexagon.append(Vector2.RIGHT.rotated(TAU * float(index) / 6.0) * visual_radius)
			draw_colored_polygon(hexagon, Color("ff3f77"))
			draw_polyline(PackedVector2Array([hexagon[0], hexagon[1], hexagon[2], hexagon[3], hexagon[4], hexagon[5], hexagon[0]]), Color("ffd0dc"), 4.0)
			draw_circle(Vector2.ZERO, visual_radius * 0.42, Color("ffe66d"))
		_:
			draw_circle(Vector2.ZERO, visual_radius, Color("ff5d5d"))
			draw_circle(Vector2.ZERO, visual_radius, Color("ffb0a9"), false, 3.0)

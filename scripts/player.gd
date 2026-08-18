class_name Player
extends CharacterBody2D

signal player_died(peer_id: int)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal level_reached(level: int)
signal staff_cast(points: PackedVector2Array)

enum SimulationMode {
	OFFLINE,
	AUTHORITY,
	PROXY,
}

@export var movement_speed := 300.0
@export var attack_interval := 0.7
@export var weapon_damage := 18.0
@export var attack_range := 620.0
@export var aim_assist_radius := 82.0
@export var chain_count := 1
@export var chain_range := 190.0
@export_range(0.1, 1.0, 0.05) var chain_damage_multiplier := 0.65

@onready var health: HealthComponent = $HealthComponent
@onready var world_health_bar: WorldHealthBar = $WorldHealthBar
@onready var camera: Camera2D = $Camera2D

var owner_peer_id := 1
var simulation_mode := SimulationMode.OFFLINE
var is_local_player := true
var active := true
var facing_direction := Vector2.RIGHT
var aim_world_position := Vector2.RIGHT * 100.0
var current_xp := 0
var level := 1
var xp_required := 40

var attack_cooldown := 0.0
var command_move := Vector2.ZERO
var command_aim := Vector2.RIGHT * 100.0
var command_attack := false
var network_target_position := Vector2.ZERO


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	world_health_bar.bind_health(health)
	xp_changed.emit(current_xp, xp_required, level)
	queue_redraw()


func configure(peer_id: int, mode: int, local_player: bool) -> void:
	owner_peer_id = peer_id
	simulation_mode = mode
	is_local_player = local_player
	camera.enabled = local_player and not GameRuntime.is_dedicated_server()
	world_health_bar.visible = not GameRuntime.is_dedicated_server()
	network_target_position = global_position


func set_authority_command(move_input: Vector2, aim_position: Vector2, attack_held: bool) -> void:
	command_move = move_input.limit_length(1.0)
	command_aim = aim_position
	command_attack = attack_held


func apply_network_state(state: Dictionary) -> void:
	network_target_position = state.get("position", global_position)
	facing_direction = state.get("facing", facing_direction)
	aim_world_position = state.get("aim", aim_world_position)
	active = state.get("active", active)
	current_xp = state.get("xp", current_xp)
	xp_required = state.get("xp_required", xp_required)
	level = state.get("level", level)
	health.set_network_state(
		state.get("health", health.current_health),
		state.get("max_health", health.max_health)
	)
	xp_changed.emit(current_xp, xp_required, level)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if simulation_mode == SimulationMode.PROXY:
		global_position = global_position.lerp(network_target_position, clampf(delta * 14.0, 0.0, 1.0))
		return

	if not active:
		velocity = Vector2.ZERO
		return

	var move_input := command_move
	var attack_held := command_attack
	if simulation_mode == SimulationMode.OFFLINE:
		move_input = InputService.movement_vector()
		command_aim = InputService.aim_world_position(self)
		attack_held = InputService.primary_attack_held()

	aim_world_position = command_aim
	var aim_direction := global_position.direction_to(aim_world_position)
	if aim_direction.length_squared() > 0.0:
		facing_direction = aim_direction

	velocity = move_input * movement_speed
	move_and_slide()

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_held and attack_cooldown <= 0.0:
		_cast_arc_staff()
		attack_cooldown = attack_interval
	queue_redraw()


func _cast_arc_staff() -> void:
	var primary := _find_primary_target()
	var points := PackedVector2Array([global_position])
	if primary == null:
		points.append(global_position + facing_direction * minf(attack_range, 180.0))
		staff_cast.emit(points)
		return

	var struck: Array[Node2D] = [primary]
	points.append(primary.global_position)
	_damage_enemy(primary, weapon_damage)
	var previous := primary

	for chain_index in chain_count:
		var next_target := _find_chain_target(previous, struck)
		if next_target == null:
			break
		struck.append(next_target)
		points.append(next_target.global_position)
		var chain_damage := weapon_damage * pow(chain_damage_multiplier, chain_index + 1)
		_damage_enemy(next_target, chain_damage)
		previous = next_target

	staff_cast.emit(points)


func _find_primary_target() -> Node2D:
	var segment_end := global_position + facing_direction * attack_range
	var best_target: Node2D
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate.has_method("is_damageable") and not candidate.is_damageable():
			continue
		var candidate_position: Vector2 = candidate.global_position
		var projected := Geometry2D.get_closest_point_to_segment(candidate_position, global_position, segment_end)
		var distance_to_beam := candidate_position.distance_to(projected)
		var forward_distance := global_position.distance_to(projected)
		if distance_to_beam > aim_assist_radius or forward_distance > attack_range:
			continue
		var score := distance_to_beam * 4.0 + forward_distance * 0.05
		if score < best_score:
			best_score = score
			best_target = candidate
	return best_target


func _find_chain_target(origin: Node2D, excluded: Array[Node2D]) -> Node2D:
	var nearest: Node2D
	var nearest_distance_sq := chain_range * chain_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D or candidate in excluded:
			continue
		if candidate.has_method("is_damageable") and not candidate.is_damageable():
			continue
		var distance_sq: float = origin.global_position.distance_squared_to(candidate.global_position)
		if distance_sq < nearest_distance_sq:
			nearest = candidate
			nearest_distance_sq = distance_sq
	return nearest


func _damage_enemy(target: Node2D, amount: float) -> void:
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if target_health != null:
		target_health.take_damage(amount)


func add_xp(amount: int) -> void:
	if simulation_mode == SimulationMode.PROXY or amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_required:
		current_xp -= xp_required
		level += 1
		xp_required = roundi(xp_required * 1.35)
		xp_changed.emit(current_xp, xp_required, level)
		level_reached.emit(level)
	xp_changed.emit(current_xp, xp_required, level)


func apply_upgrade(upgrade_id: String) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	match upgrade_id:
		"rapid": attack_interval = maxf(0.18, attack_interval * 0.82)
		"heavy": weapon_damage += 8.0
		"chain": chain_count += 1
		"boots": movement_speed += 35.0
		"vitality":
			health.max_health += 25.0
			health.current_health = minf(health.max_health, health.current_health + 25.0)
			health.health_changed.emit(health.current_health, health.max_health)


func snapshot() -> Dictionary:
	return {
		"peer_id": owner_peer_id,
		"position": global_position,
		"facing": facing_direction,
		"aim": aim_world_position,
		"active": active,
		"health": health.current_health,
		"max_health": health.max_health,
		"xp": current_xp,
		"xp_required": xp_required,
		"level": level,
	}


func _on_damaged(_amount: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color("ff7777"), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func _on_died() -> void:
	active = false
	modulate = Color(0.35, 0.35, 0.4, 1.0)
	player_died.emit(owner_peer_id)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color("45a3ff"))
	draw_circle(Vector2.ZERO, 18.0, Color("bce2ff"), false, 3.0)
	draw_line(Vector2.ZERO, facing_direction * 28.0, Color("d8efff"), 4.0)
	draw_circle(facing_direction * 29.0, 4.5, Color("77dfff"))

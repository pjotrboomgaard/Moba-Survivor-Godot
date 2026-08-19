class_name Player
extends CharacterBody2D

signal player_died(peer_id: int)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal level_reached(level: int)
signal staff_cast(points: PackedVector2Array)
signal stats_changed(stats: Dictionary)
signal combat_number(world_position: Vector2, value: float, kind: String, critical: bool)

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
@export var main_bolt_count := 1
@export_range(0.0, 1.0, 0.01) var critical_chance := 0.05
@export_range(1.0, 5.0, 0.05) var critical_multiplier := 2.0
@export_range(0.0, 0.5, 0.005) var lifesteal := 0.0
@export var health_regeneration := 0.0
@export var pickup_radius_bonus := 0.0

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
var cast_flash := 0.0
var regeneration_accumulator := 0.0
var command_move := Vector2.ZERO
var command_aim := Vector2.RIGHT * 100.0
var command_attack := false
var network_target_position := Vector2.ZERO
var upgrade_ranks: Dictionary = {}


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	world_health_bar.bind_health(health)
	xp_changed.emit(current_xp, xp_required, level)
	stats_changed.emit(combat_stats())
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
	upgrade_ranks = state.get("upgrade_ranks", upgrade_ranks).duplicate()
	var received_stats: Dictionary = state.get("stats", {})
	if not received_stats.is_empty():
		_apply_network_stats(received_stats)
	health.set_network_state(
		state.get("health", health.current_health),
		state.get("max_health", health.max_health)
	)
	xp_changed.emit(current_xp, xp_required, level)
	stats_changed.emit(combat_stats())
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
	cast_flash = maxf(0.0, cast_flash - delta * 5.5)
	regeneration_accumulator += delta
	if health_regeneration > 0.0 and regeneration_accumulator >= 1.0:
		var regeneration_ticks := floori(regeneration_accumulator)
		regeneration_accumulator -= float(regeneration_ticks)
		var missing_health := health.max_health - health.current_health
		var healed := minf(missing_health, health_regeneration * regeneration_ticks)
		if healed > 0.0:
			health.heal(healed)
			combat_number.emit(global_position, healed, "heal", false)
	if attack_held and attack_cooldown <= 0.0:
		_cast_arc_staff()
		attack_cooldown = attack_interval
	queue_redraw()


func _cast_arc_staff() -> void:
	cast_flash = 1.0
	var used_primary_targets: Array[Node2D] = []
	var cast_any_target := false
	for bolt_index in main_bolt_count:
		var primary := _find_primary_target(used_primary_targets)
		if primary == null:
			continue
		cast_any_target = true
		used_primary_targets.append(primary)
		var struck: Array[Node2D] = [primary]
		var points := PackedVector2Array([global_position, primary.global_position])
		_strike_enemy(primary, weapon_damage)
		var previous := primary

		for chain_index in chain_count:
			var next_target := _find_chain_target(previous, struck)
			if next_target == null:
				break
			struck.append(next_target)
			points.append(next_target.global_position)
			var chain_damage := weapon_damage * pow(chain_damage_multiplier, chain_index + 1)
			_strike_enemy(next_target, chain_damage)
			previous = next_target

		staff_cast.emit(points)

	if not cast_any_target:
		var miss_points := PackedVector2Array([
			global_position,
			global_position + facing_direction * minf(attack_range, 180.0),
		])
		staff_cast.emit(miss_points)


func _find_primary_target(excluded: Array[Node2D] = []) -> Node2D:
	var segment_end := global_position + facing_direction * attack_range
	var best_target: Node2D
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate in excluded:
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


func _strike_enemy(target: Node2D, amount: float) -> void:
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if target_health != null:
		var critical := randf() < critical_chance
		var final_damage := amount * (critical_multiplier if critical else 1.0)
		target_health.take_damage(final_damage)
		combat_number.emit(target.global_position, final_damage, "damage", critical)
		if lifesteal > 0.0:
			var missing_health := health.max_health - health.current_health
			var healed := minf(missing_health, final_damage * lifesteal)
			if healed > 0.0:
				health.heal(healed)
				combat_number.emit(global_position, healed, "heal", false)


func add_xp(amount: int) -> void:
	if simulation_mode == SimulationMode.PROXY or amount <= 0:
		return
	current_xp += amount
	combat_number.emit(global_position, amount, "xp", false)
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
	if not can_upgrade(upgrade_id):
		return
	match upgrade_id:
		"rapid": attack_interval = maxf(0.18, attack_interval * 0.82)
		"heavy": weapon_damage += 8.0
		"chain": chain_count = mini(6, chain_count + 1)
		"split": main_bolt_count = mini(2, main_bolt_count + 1)
		"chain_range": chain_range = minf(330.0, chain_range + 35.0)
		"crit_chance": critical_chance = minf(0.60, critical_chance + 0.08)
		"crit_power": critical_multiplier = minf(3.5, critical_multiplier + 0.35)
		"boots": movement_speed += 35.0
		"regeneration": health_regeneration = minf(3.0, health_regeneration + 0.6)
		"lifesteal": lifesteal = minf(0.12, lifesteal + 0.03)
		"magnet": pickup_radius_bonus = minf(240.0, pickup_radius_bonus + 45.0)
		"vitality":
			health.max_health += 25.0
			health.current_health = minf(health.max_health, health.current_health + 25.0)
			health.health_changed.emit(health.current_health, health.max_health)
	upgrade_ranks[upgrade_id] = int(upgrade_ranks.get(upgrade_id, 0)) + 1
	stats_changed.emit(combat_stats())


func can_upgrade(upgrade_id: String) -> bool:
	var rank := int(upgrade_ranks.get(upgrade_id, 0))
	var maximum_rank := 8
	match upgrade_id:
		"split": maximum_rank = 1
		"chain": maximum_rank = 5
		"chain_range", "crit_chance", "crit_power", "regeneration", "lifesteal", "magnet": maximum_rank = 5
	return rank < maximum_rank


func upgrade_rank(upgrade_id: String) -> int:
	return int(upgrade_ranks.get(upgrade_id, 0))


func combat_stats() -> Dictionary:
	return {
		"movement_speed": movement_speed,
		"weapon_damage": weapon_damage,
		"casts_per_second": 1.0 / attack_interval,
		"critical_chance": critical_chance,
		"critical_multiplier": critical_multiplier,
		"chains": chain_count,
		"chain_range": chain_range,
		"main_bolts": main_bolt_count,
		"regeneration": health_regeneration,
		"lifesteal": lifesteal,
		"pickup_radius": 105.0 + pickup_radius_bonus,
	}


func xp_pickup_radius() -> float:
	return 105.0 + pickup_radius_bonus


func dev_add_levels(amount: int) -> void:
	if simulation_mode == SimulationMode.PROXY or amount <= 0:
		return
	level += amount
	xp_required = roundi(40.0 * pow(1.35, level - 1))
	current_xp = 0
	xp_changed.emit(current_xp, xp_required, level)


func set_invulnerable(enabled: bool) -> void:
	health.invulnerable = enabled
	stats_changed.emit(combat_stats())


func _apply_network_stats(stats: Dictionary) -> void:
	movement_speed = float(stats.get("movement_speed", movement_speed))
	weapon_damage = float(stats.get("weapon_damage", weapon_damage))
	var casts_per_second := float(stats.get("casts_per_second", 1.0 / attack_interval))
	attack_interval = 1.0 / maxf(0.01, casts_per_second)
	critical_chance = float(stats.get("critical_chance", critical_chance))
	critical_multiplier = float(stats.get("critical_multiplier", critical_multiplier))
	chain_count = int(stats.get("chains", chain_count))
	chain_range = float(stats.get("chain_range", chain_range))
	main_bolt_count = int(stats.get("main_bolts", main_bolt_count))
	health_regeneration = float(stats.get("regeneration", health_regeneration))
	lifesteal = float(stats.get("lifesteal", lifesteal))
	pickup_radius_bonus = float(stats.get("pickup_radius", xp_pickup_radius())) - 105.0


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
		"stats": combat_stats(),
		"upgrade_ranks": upgrade_ranks.duplicate(),
	}


func _on_damaged(amount: float) -> void:
	combat_number.emit(global_position, amount, "taken", false)
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
	var side := facing_direction.orthogonal()
	var staff_base := facing_direction * 12.0 + side * 11.0
	var staff_tip := facing_direction * 43.0 + side * 11.0
	draw_line(staff_base, staff_tip, Color("7b5a45"), 5.0, true)
	draw_line(staff_base, staff_tip, Color("d8b38e"), 1.5, true)
	for coil_index in range(3):
		var coil_center := staff_tip - facing_direction * float(coil_index * 5)
		var coil_radius := 5.5 - float(coil_index) * 0.9
		draw_circle(coil_center, coil_radius, Color("65dcff"), false, 2.0)
	if cast_flash > 0.0:
		draw_circle(staff_tip, 10.0 + cast_flash * 8.0, Color(0.35, 0.9, 1.0, cast_flash * 0.28))
		draw_circle(staff_tip, 4.0 + cast_flash * 2.0, Color("e8fcff"))

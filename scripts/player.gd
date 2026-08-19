class_name Player
extends CharacterBody2D

signal player_died(peer_id: int)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal gold_changed(gold: int)
signal level_reached(level: int)
signal staff_cast(effect_kind: String, points: PackedVector2Array)

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

const BODY_RADIUS := 18.0

@onready var health: HealthComponent = $HealthComponent
@onready var world_health_bar: WorldHealthBar = $WorldHealthBar
@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite

var class_id := PlayerClass.DEFAULT_CLASS_ID
var weapon_kind: PlayerClass.Weapon = PlayerClass.Weapon.CHAIN_BOLT
var damage_type: PlayerClass.DamageType = PlayerClass.DamageType.LIGHTNING
var body_color := Color("45a3ff")
var accent_color := Color("bce2ff")
var taunt_weight := 1.0

var support_heal_per_second := PlayerClass.SUPPORT_HEAL_PER_SECOND
var support_damage_bonus := PlayerClass.SUPPORT_DAMAGE_BONUS
var frost_burst_radius := PlayerClass.FROST_BURST_RADIUS
var frost_slow_factor := PlayerClass.FROST_SLOW_FACTOR
var frost_slow_duration := PlayerClass.FROST_SLOW_DURATION

var damage_dealt_multiplier := 1.0
var buff_timer := 0.0

var owner_peer_id := 1
var simulation_mode := SimulationMode.OFFLINE
var is_local_player := true
var active := true
var facing_direction := Vector2.RIGHT
var aim_world_position := Vector2.RIGHT * 100.0
var current_xp := 0
var level := 1
var xp_required := 40
var gold := 0
var gold_multiplier := 1.0
var shop_stacks: Dictionary = {}

const SPRINT_DURATION := 1.5
const SPRINT_COOLDOWN := 9.0
const SPRINT_SPEED_BONUS := 0.9
const EMBER_RADIUS := 140.0

var thorns_ratio := 0.0
var lifesteal_ratio := 0.0
var health_regen_per_second := 0.0
var resistance_pierce := 0.0
var ember_damage_per_second := 0.0
var hit_slow_factor := 1.0
var hit_slow_duration := 1.0
var pickup_radius_bonus := 0.0
var aegis_charges := 0
var aegis_charges_left := 0
var sprint_timer := 0.0
var sprint_cooldown := 0.0
var command_ability := false

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


func configure(peer_id: int, mode: int, local_player: bool, next_class_id: String = PlayerClass.DEFAULT_CLASS_ID) -> void:
	owner_peer_id = peer_id
	simulation_mode = mode
	is_local_player = local_player
	camera.enabled = local_player and not GameRuntime.is_dedicated_server()
	world_health_bar.visible = not GameRuntime.is_dedicated_server()
	network_target_position = global_position
	apply_class(next_class_id)


func apply_class(next_class_id: String) -> void:
	class_id = PlayerClass.sanitize_id(next_class_id)
	var class_data := PlayerClass.by_id(class_id)
	weapon_kind = class_data.weapon
	damage_type = class_data.damage_type
	body_color = Color(class_data.body_color)
	accent_color = Color(class_data.accent_color)
	movement_speed = class_data.movement_speed
	attack_interval = class_data.attack_interval
	weapon_damage = class_data.weapon_damage
	attack_range = class_data.attack_range
	aim_assist_radius = class_data.aim_assist_radius
	chain_count = class_data.chain_count
	chain_range = class_data.chain_range
	taunt_weight = class_data.taunt_weight
	health.damage_taken_multiplier = class_data.damage_taken_multiplier
	health.max_health = class_data.max_health
	health.current_health = class_data.max_health
	health.is_dead = false
	health.health_changed.emit(health.current_health, health.max_health)
	_apply_sprite()
	queue_redraw()


func _apply_sprite() -> void:
	if sprite == null:
		return
	sprite.texture = SpriteLibrary.texture_for(class_id)
	sprite.scale = SpriteLibrary.scale_for_radius(sprite.texture, BODY_RADIUS * 1.35)


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func set_authority_command(move_input: Vector2, aim_position: Vector2, attack_held: bool, ability_held: bool = false) -> void:
	command_move = move_input.limit_length(1.0)
	command_aim = aim_position
	command_attack = attack_held
	command_ability = ability_held


func apply_network_state(state: Dictionary) -> void:
	var state_class_id := str(state.get("class_id", class_id))
	if state_class_id != class_id:
		apply_class(state_class_id)
	network_target_position = state.get("position", global_position)
	facing_direction = state.get("facing", facing_direction)
	aim_world_position = state.get("aim", aim_world_position)
	active = state.get("active", active)
	current_xp = state.get("xp", current_xp)
	xp_required = state.get("xp_required", xp_required)
	level = state.get("level", level)
	buff_timer = 0.4 if state.get("buffed", false) else 0.0
	gold = state.get("gold", gold)
	shop_stacks = state.get("shop_stacks", shop_stacks)
	sprint_cooldown = state.get("dash_cooldown", sprint_cooldown)
	sprint_timer = state.get("dash_active", 0.0)
	gold_changed.emit(gold)
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
	var ability_held := command_ability
	if simulation_mode == SimulationMode.OFFLINE:
		move_input = InputService.movement_vector()
		command_aim = InputService.aim_world_position(self)
		attack_held = InputService.primary_attack_held()
		ability_held = InputService.ability_held()

	aim_world_position = command_aim
	var aim_direction := global_position.direction_to(aim_world_position)
	if aim_direction.length_squared() > 0.0:
		facing_direction = aim_direction

	_update_sprint(delta, ability_held)
	var speed := movement_speed
	if sprint_timer > 0.0:
		speed *= 1.0 + SPRINT_SPEED_BONUS
	velocity = move_input * speed
	move_and_slide()

	_update_buff(delta)
	_update_items(delta)
	if weapon_kind == PlayerClass.Weapon.MENDING_BOLT:
		_apply_support_aura(delta)

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_held and attack_cooldown <= 0.0:
		_perform_attack()
		attack_cooldown = attack_interval
	queue_redraw()


func _update_sprint(delta: float, ability_held: bool) -> void:
	sprint_timer = maxf(0.0, sprint_timer - delta)
	sprint_cooldown = maxf(0.0, sprint_cooldown - delta)
	if ability_held and has_active_item() and sprint_timer <= 0.0 and sprint_cooldown <= 0.0:
		sprint_timer = SPRINT_DURATION
		sprint_cooldown = SPRINT_COOLDOWN + SPRINT_DURATION
		AudioService.play("dash")


func _update_items(delta: float) -> void:
	if health_regen_per_second > 0.0:
		health.heal(health_regen_per_second * delta)
	if ember_damage_per_second <= 0.0:
		return
	for target in _enemies_in_radius(global_position, EMBER_RADIUS):
		var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(ember_damage_per_second * delta, self)


func _update_buff(delta: float) -> void:
	if buff_timer <= 0.0:
		damage_dealt_multiplier = 1.0
		return
	buff_timer = maxf(0.0, buff_timer - delta)
	if buff_timer <= 0.0:
		damage_dealt_multiplier = 1.0


func receive_support_buff(bonus: float) -> void:
	damage_dealt_multiplier = 1.0 + bonus
	buff_timer = 0.4


func _apply_support_aura(delta: float) -> void:
	var radius_sq := PlayerClass.SUPPORT_AURA_RADIUS * PlayerClass.SUPPORT_AURA_RADIUS
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var ally := candidate as Player
		if not ally.active or ally.health.is_dead:
			continue
		if global_position.distance_squared_to(ally.global_position) > radius_sq:
			continue
		var heal_rate := support_heal_per_second if ally != self else support_heal_per_second * 0.5
		ally.health.heal(heal_rate * delta)
		ally.receive_support_buff(support_damage_bonus)


func _perform_attack() -> void:
	match weapon_kind:
		PlayerClass.Weapon.CHAIN_BOLT:
			_cast_chain_bolt()
		PlayerClass.Weapon.CONE_SLAM:
			_cast_cone_slam()
		PlayerClass.Weapon.MENDING_BOLT:
			_cast_mending_bolt()
		PlayerClass.Weapon.FROST_SHARD:
			_cast_frost_shard()


func _cast_chain_bolt() -> void:
	var primary := _find_primary_target()
	var points := PackedVector2Array([global_position])
	if primary == null:
		points.append(global_position + facing_direction * minf(attack_range, 180.0))
		staff_cast.emit(class_id, points)
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

	staff_cast.emit(class_id, points)


func _cast_cone_slam() -> void:
	var half_angle := deg_to_rad(PlayerClass.CONE_HALF_ANGLE_DEGREES)
	for target in _enemies_in_radius(global_position, attack_range):
		var to_target := global_position.direction_to(target.global_position)
		if to_target.length_squared() > 0.0 and absf(facing_direction.angle_to(to_target)) > half_angle:
			continue
		_damage_enemy(target, weapon_damage)
	staff_cast.emit(class_id, PackedVector2Array([global_position, Vector2(attack_range, 0.0)]))


func _cast_mending_bolt() -> void:
	var primary := _find_primary_target()
	var points := PackedVector2Array([global_position])
	if primary == null:
		points.append(global_position + facing_direction * minf(attack_range, 180.0))
	else:
		points.append(primary.global_position)
		_damage_enemy(primary, weapon_damage)
	staff_cast.emit(class_id, points)


func _cast_frost_shard() -> void:
	var primary := _find_primary_target()
	var burst_center := primary.global_position if primary != null else global_position + facing_direction * minf(attack_range, 260.0)
	for target in _enemies_in_radius(burst_center, frost_burst_radius):
		_damage_enemy(target, weapon_damage)
		if target.has_method("apply_slow"):
			target.apply_slow(frost_slow_factor, frost_slow_duration)
	staff_cast.emit(class_id, PackedVector2Array([burst_center, Vector2(frost_burst_radius, 0.0)]))


func _enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var radius_sq := radius * radius
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate.has_method("is_damageable") and not candidate.is_damageable():
			continue
		if center.distance_squared_to((candidate as Node2D).global_position) <= radius_sq:
			found.append(candidate as Node2D)
	return found


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
	if target_health == null:
		return
	var resistance := 1.0
	if target.has_method("damage_multiplier_for"):
		resistance = target.damage_multiplier_for(damage_type)
	# Rending Prism only cuts into resistance, it never trims a weakness bonus.
	if resistance < 1.0 and resistance_pierce > 0.0:
		resistance = lerpf(resistance, 1.0, resistance_pierce)
	var dealt := amount * damage_dealt_multiplier * resistance
	target_health.take_damage(dealt, self)
	if lifesteal_ratio > 0.0:
		health.heal(dealt * lifesteal_ratio)
	if hit_slow_factor < 1.0 and target.has_method("apply_slow"):
		target.apply_slow(hit_slow_factor, hit_slow_duration)


func add_gold(amount: int) -> void:
	if simulation_mode == SimulationMode.PROXY or amount <= 0:
		return
	gold += int(round(float(amount) * gold_multiplier))
	gold_changed.emit(gold)


func stacks_of(item_id: String) -> int:
	return int(shop_stacks.get(item_id, 0))


func can_afford(item_id: String) -> bool:
	return not ShopCatalog.is_sold_out(item_id, stacks_of(item_id)) \
		and gold >= ShopCatalog.price_for(item_id, stacks_of(item_id))


## Server-side purchase. Returns false when the player cannot have it.
func buy(item_id: String) -> bool:
	if simulation_mode == SimulationMode.PROXY or not ShopCatalog.is_valid_id(item_id):
		return false
	if not can_afford(item_id):
		return false
	gold -= ShopCatalog.price_for(item_id, stacks_of(item_id))
	shop_stacks[item_id] = stacks_of(item_id) + 1
	_apply_shop_item(item_id)
	gold_changed.emit(gold)
	return true


func _apply_shop_item(item_id: String) -> void:
	match item_id:
		"carapace": thorns_ratio += 0.25
		"bloodfang": lifesteal_ratio += 0.08
		"pendant": health_regen_per_second += 1.5
		"prism": resistance_pierce = minf(0.8, resistance_pierce + 0.2)
		"ember": ember_damage_per_second += 6.0
		"lodestone": pickup_radius_bonus += 0.6
		"frostbite": hit_slow_factor = maxf(0.4, hit_slow_factor - 0.2)
		"phase_boots": sprint_cooldown = 0.0
		"aegis":
			aegis_charges += 1
			aegis_charges_left = aegis_charges


func has_active_item() -> bool:
	return stacks_of(ShopCatalog.ACTIVE_ITEM_ID) > 0


func is_sprinting() -> bool:
	return sprint_timer > 0.0


## Aegis Sigil. Recharges when the next wave begins.
func try_cheat_death() -> bool:
	if simulation_mode == SimulationMode.PROXY or aegis_charges_left <= 0:
		return false
	aegis_charges_left -= 1
	health.current_health = health.max_health * 0.35
	return true


func refresh_wave_items() -> void:
	aegis_charges_left = aegis_charges


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
		"plating": health.damage_taken_multiplier = maxf(0.35, health.damage_taken_multiplier - 0.08)
		"reach": attack_range += 35.0
		"flow": support_heal_per_second += 1.5
		"choir": support_damage_bonus += 0.06
		"depth":
			frost_slow_factor = maxf(0.25, frost_slow_factor - 0.08)
			frost_slow_duration += 0.5
		"shatter": frost_burst_radius += 35.0
		"vitality":
			health.max_health += 25.0
			health.current_health = minf(health.max_health, health.current_health + 25.0)
			health.health_changed.emit(health.current_health, health.max_health)


func snapshot() -> Dictionary:
	return {
		"peer_id": owner_peer_id,
		"class_id": class_id,
		"position": global_position,
		"facing": facing_direction,
		"aim": aim_world_position,
		"active": active,
		"buffed": buff_timer > 0.0,
		"health": health.current_health,
		"max_health": health.max_health,
		"xp": current_xp,
		"xp_required": xp_required,
		"level": level,
		"gold": gold,
		"shop_stacks": shop_stacks,
		"dash_cooldown": sprint_cooldown,
		"dash_active": sprint_timer,
	}


func _on_damaged(amount: float) -> void:
	AudioService.play("hit")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color("ff7777"), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	_reflect_damage(amount)


func _reflect_damage(amount: float) -> void:
	if simulation_mode == SimulationMode.PROXY or thorns_ratio <= 0.0:
		return
	var attacker := health.last_damage_source as Enemy
	if attacker == null or not is_instance_valid(attacker) or attacker.health.is_dead:
		return
	attacker.health.take_damage(amount * thorns_ratio)


func _on_died() -> void:
	active = false
	modulate = Color(0.35, 0.35, 0.4, 1.0)
	player_died.emit(owner_peer_id)


func _draw() -> void:
	if buff_timer > 0.0:
		draw_circle(Vector2.ZERO, 26.0, Color(0.47, 0.83, 0.51, 0.28))
	if not has_sprite():
		draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
		draw_circle(Vector2.ZERO, BODY_RADIUS, accent_color, false, 3.0)
	draw_line(facing_direction * 20.0, facing_direction * 30.0, accent_color, 4.0)
	draw_circle(facing_direction * 32.0, 4.5, accent_color)

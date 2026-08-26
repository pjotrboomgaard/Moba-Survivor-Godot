class_name Player
extends CharacterBody2D

signal player_died(peer_id: int)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal gold_changed(gold: int)
signal level_reached(level: int)
signal staff_cast(effect_kind: String, points: PackedVector2Array)
signal ability_cast(ability_id: String, effect_style: int, points: PackedVector2Array)
signal secondary_fx(class_id: String, style: int, points: PackedVector2Array)
signal support_wall_spawned(points: PackedVector2Array, duration: float, color: Color)

enum SimulationMode {
	OFFLINE,
	AUTHORITY,
	PROXY,
	CPU,
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
const FACING_CLASS_IDS := ["arclight", "bulwark", "warden"]
const WORLD_LAYER := 1
const ENEMY_LAYER := 4
const OBSTACLE_LAYER := 16

@onready var health: HealthComponent = $HealthComponent
@onready var world_health_bar: WorldHealthBar = $WorldHealthBar
@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite
@onready var shop_hint: Node2D = get_node_or_null("ShopHint")

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
var blast_radius := PlayerClass.BLAST_RADIUS
var blast_pulses := 1
var cone_half_angle_degrees := PlayerClass.CONE_HALF_ANGLE_DEGREES
var secondary_kind := "repulse"
var secondary_cooldown := 0.0
var secondary_cooldown_max := PlayerClass.SECONDARY_COOLDOWN
var command_secondary := false
var _secondary_was_held := false
var _drawing_wall := false
var _wall_points := PackedVector2Array()
var _wall_draw_age := 0.0

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
var _tobor_walk_phase := 0.0
var _tobor_facing := "front"
var _hover_phase := 0.0
var hovering := false
var _shake_time := 0.0
var _shake_amp := 0.0

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
var knockback_strength := 0.0
var pickup_radius_bonus := 0.0
var jetpack_slam := 0.0
var skate_speed_bonus := 0.0
var grab_radius := 0.0
var _jump_cooldown := 0.0
var _jump_t := -1.0
var _grab_timer := 0.0
var aegis_charges := 0
var aegis_charges_left := 0
var sprint_timer := 0.0
var sprint_cooldown := 0.0
var command_ability := false

var attack_cooldown := 0.0
var command_move := Vector2.ZERO
var command_aim := Vector2.RIGHT * 100.0
var command_attack := false
var command_ability_slots: Array = [false, false, false, false]
var _casting_ability_id := ""
var network_target_position := Vector2.ZERO

## Hero abilities (see PlayerClass.ABILITIES). Each entry is {"id": String, "rank": int};
## the index into known_abilities is also the ability's slot (ability_1..ability_4, and the
## matching index into ability_cooldowns).
var known_abilities: Array[Dictionary] = []
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Temporary stat buff from a BUFF_SELF ability (Overclock, Last Stand, Chilling Clarity, ...).
## Read alongside the permanent stats wherever they're consumed, and cleared on expiry.
var ability_buff_timer := 0.0
var ability_buff_stats: Dictionary = {}
var _ability_damage_taken_factor := 1.0


var _normal_collision_mask := 0
var cpu_lock_target: Node2D
var cpu_lock_timer := 0.0
var cpu_smoothed_move := Vector2.ZERO


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	world_health_bar.bind_health(health)
	xp_changed.emit(current_xp, xp_required, level)
	_normal_collision_mask = collision_mask
	set_shop_hint_visible(false)
	queue_redraw()


func set_shop_hint_visible(show: bool) -> void:
	if shop_hint != null:
		shop_hint.visible = show and is_local_player


func _process(delta: float) -> void:
	if camera != null and _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		if _shake_time <= 0.0:
			camera.offset = Vector2.ZERO
		else:
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amp
	if shop_hint == null or not shop_hint.visible:
		return
	shop_hint.position.y = sin(Time.get_ticks_msec() * 0.008) * 6.0


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
	blast_radius = float(class_data.get("blast_radius", 0.0))
	blast_pulses = 1
	cone_half_angle_degrees = float(class_data.get("cone_half_angle_degrees", PlayerClass.CONE_HALF_ANGLE_DEGREES))
	secondary_kind = str(class_data.get("secondary", "repulse"))
	secondary_cooldown = 0.0
	secondary_cooldown_max = float(class_data.get("secondary_cooldown", PlayerClass.SECONDARY_COOLDOWN))
	_drawing_wall = false
	_wall_points = PackedVector2Array()
	taunt_weight = class_data.taunt_weight
	hovering = bool(class_data.get("hovering", false))
	_tobor_facing = "front"
	_apply_locomotion()
	if world_health_bar != null:
		world_health_bar.set_identity_color(Color(str(class_data.get("health_bar_color", class_data.accent_color))))
	health.damage_taken_multiplier = class_data.damage_taken_multiplier
	health.max_health = class_data.max_health
	health.current_health = class_data.max_health
	health.is_dead = false
	health.health_changed.emit(health.current_health, health.max_health)
	_apply_sprite()
	queue_redraw()


## Classic mode stays on the plain vector look (see arena.gd's grid background), so it never
## picks up pixel art here either.
func _apply_sprite() -> void:
	if sprite == null:
		return
	if class_id == "tobor":
		sprite.centered = true
		_paint_tobor_sprite()
		return
	sprite.centered = true
	sprite.flip_h = false
	sprite.rotation = 0.0
	sprite.offset = Vector2.ZERO
	sprite.texture = _facing_texture()
	sprite.scale = _hero_sprite_scale()
	if hovering:
		sprite.offset = Vector2(0.0, -10.0)


func _facing_texture() -> Texture2D:
	if not FACING_CLASS_IDS.has(class_id) or _tobor_facing == "front":
		return SpriteLibrary.texture_for(class_id)
	var named := "%s_%s" % [class_id, _tobor_facing]
	var texture := SpriteLibrary.texture_for(named)
	return texture if texture != null else SpriteLibrary.texture_for(class_id)


func _apply_locomotion() -> void:
	z_index = 26 if hovering else 20
	_normal_collision_mask = WORLD_LAYER | ENEMY_LAYER
	if not hovering:
		_normal_collision_mask |= OBSTACLE_LAYER
	if sprint_timer <= 0.0:
		collision_mask = _normal_collision_mask


## Dedicated front/back/left/right sprites. No spin, no flip_h.
func _update_tobor_visual(delta: float, move_input: Vector2) -> void:
	if sprite == null:
		return
	var moving := move_input.length_squared() > 0.04
	if moving:
		if absf(move_input.y) > absf(move_input.x):
			_tobor_facing = "back" if move_input.y < 0.0 else "front"
		else:
			_tobor_facing = "left" if move_input.x < 0.0 else "right"
	if class_id == "tobor":
		if moving:
			_tobor_walk_phase += delta * 8.0
		else:
			_tobor_walk_phase = 0.0
		_paint_tobor_sprite()
		return
	if not FACING_CLASS_IDS.has(class_id):
		return
	_paint_hero_facing()
	_update_gait(delta, moving)


func _hero_sprite_scale() -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ONE
	if FACING_CLASS_IDS.has(class_id):
		return SpriteLibrary.scale_for_radius(sprite.texture, BODY_RADIUS * 2.2)
	if sprite.texture.get_width() >= 32:
		return SpriteLibrary.tobor_scale(BODY_RADIUS * 1.45)
	return SpriteLibrary.scale_for_radius(sprite.texture, BODY_RADIUS * 1.45)


func _paint_hero_facing() -> void:
	if sprite == null:
		return
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.texture = _facing_texture()
	sprite.scale = _hero_sprite_scale()


## Arclight: tiny hop. Bulwark: slow heavy stomp. Warden stays on the hover bob.
func _update_gait(delta: float, moving: bool) -> void:
	if hovering or sprite == null:
		return
	if moving:
		_tobor_walk_phase += delta * (9.0 if class_id == "arclight" else 5.2)
	else:
		_tobor_walk_phase = 0.0
	var hop := 0.0
	var tilt := 0.0
	var squash := 1.0
	if class_id == "arclight" and moving:
		hop = -sin(fmod(_tobor_walk_phase, 1.0) * PI) * 4.0
	elif class_id == "bulwark" and moving:
		var cycle := fmod(_tobor_walk_phase, 1.0)
		if cycle < 0.38:
			var lift := sin((cycle / 0.38) * PI)
			hop = -5.0 * lift
			squash = 1.0 - 0.05 * lift
		else:
			var land := (cycle - 0.38) / 0.62
			hop = 2.4 * (1.0 - land)
			squash = 1.0 + (0.1 if land < 0.22 else 0.0)
		tilt = sin(cycle * TAU) * 0.05
	sprite.offset = Vector2(0.0, hop)
	sprite.rotation = tilt
	var base := _hero_sprite_scale()
	sprite.scale = Vector2(base.x * (2.0 - squash), base.y * squash)
	_place_health_bar(hop)


func _place_health_bar(hop: float) -> void:
	if world_health_bar == null or sprite == null or sprite.texture == null:
		return
	var h := sprite.texture.get_height() * sprite.scale.y
	world_health_bar.position = Vector2(-30.0, -h * 0.5 - 8.0 + hop)


func _paint_tobor_sprite() -> void:
	if sprite == null:
		return
	var walk_frame := 0
	var hop := 0.0
	if skate_speed_bonus <= 0.0 and _tobor_walk_phase > 0.0:
		walk_frame = 1 + int(floor(_tobor_walk_phase)) % 2
		hop = -sin(fmod(_tobor_walk_phase, 1.0) * PI) * 10.0
	if _jump_t >= 0.0:
		var arc := sin(clampf(_jump_t, 0.0, 1.0) * PI)
		hop -= 18.0 * arc
		if stacks_of("sjaal") > 0:
			hop -= 8.0 * arc
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.texture = SpriteLibrary.compose_tobor(shop_stacks, walk_frame, _tobor_facing)
	sprite.centered = true
	sprite.offset = Vector2(0.0, hop)
	sprite.scale = SpriteLibrary.tobor_scale(BODY_RADIUS * 1.45)
	_place_health_bar(hop)


func is_cpu() -> bool:
	return simulation_mode == SimulationMode.CPU


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func set_authority_command(move_input: Vector2, aim_position: Vector2, attack_held: bool, ability_held: bool = false, ability_slots_held: Array = [false, false, false, false], secondary_held: bool = false) -> void:
	command_move = move_input.limit_length(1.0)
	command_aim = aim_position
	command_attack = attack_held
	command_ability = ability_held
	command_ability_slots = ability_slots_held
	command_secondary = secondary_held


func apply_camera_limits(half: Vector2) -> void:
	if camera == null:
		return
	camera.limit_left = int(-half.x)
	camera.limit_top = int(-half.y)
	camera.limit_right = int(half.x)
	camera.limit_bottom = int(half.y)


func shake_camera(amplitude: float, duration: float) -> void:
	if camera == null or not is_local_player:
		return
	_shake_amp = amplitude
	_shake_time = duration


func apply_network_state(state: Dictionary) -> void:
	var state_class_id := str(state.get("class_id", class_id))
	if state_class_id != class_id:
		apply_class(state_class_id)
	network_target_position = state.get("position", global_position)
	facing_direction = state.get("facing", facing_direction)
	aim_world_position = state.get("aim", aim_world_position)
	var was_active := active
	active = state.get("active", active)
	if active != was_active:
		modulate = Color.WHITE if active else Color(0.35, 0.35, 0.4, 1.0)
	current_xp = state.get("xp", current_xp)
	xp_required = state.get("xp_required", xp_required)
	level = state.get("level", level)
	buff_timer = 0.4 if state.get("buffed", false) else 0.0
	gold = state.get("gold", gold)
	shop_stacks = state.get("shop_stacks", shop_stacks)
	_jump_t = float(state.get("jump_t", _jump_t))
	sprint_cooldown = state.get("dash_cooldown", sprint_cooldown)
	sprint_timer = state.get("dash_active", 0.0)
	known_abilities = state.get("known_abilities", known_abilities)
	ability_cooldowns = state.get("ability_cooldowns", ability_cooldowns)
	secondary_cooldown = float(state.get("secondary_cooldown", secondary_cooldown))
	secondary_cooldown_max = float(state.get("secondary_cooldown_max", secondary_cooldown_max))
	_apply_sprite()
	gold_changed.emit(gold)
	health.set_network_state(
		state.get("health", health.current_health),
		state.get("max_health", health.max_health)
	)
	xp_changed.emit(current_xp, xp_required, level)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if simulation_mode == SimulationMode.PROXY:
		var to_net := network_target_position - global_position
		global_position = global_position.lerp(network_target_position, clampf(delta * 14.0, 0.0, 1.0))
		_update_tobor_visual(delta, to_net)
		_update_hover_visual(delta)
		_refresh_secondary_bar()
		return

	if not active:
		velocity = Vector2.ZERO
		return

	var move_input := command_move
	var attack_held := command_attack
	var ability_held := command_ability
	var ability_slots_held := command_ability_slots
	var secondary_held := command_secondary
	if simulation_mode == SimulationMode.CPU:
		var cpu := CpuBrain.think(self, delta)
		move_input = (cpu.move as Vector2).limit_length(1.0)
		command_aim = cpu.aim
		attack_held = bool(cpu.attack)
		ability_held = bool(cpu.ability)
		ability_slots_held = cpu.ability_slots
		secondary_held = bool(cpu.get("secondary", false))
	elif simulation_mode == SimulationMode.OFFLINE:
		move_input = InputService.movement_vector()
		command_aim = InputService.aim_world_position(self)
		attack_held = InputService.primary_attack_held()
		ability_held = InputService.ability_held()
		secondary_held = InputService.secondary_attack_held()
		ability_slots_held = [
			InputService.ability_slot_held(0), InputService.ability_slot_held(1),
			InputService.ability_slot_held(2), InputService.ability_slot_held(3),
		]

	aim_world_position = command_aim
	var aim_direction := global_position.direction_to(aim_world_position)
	if aim_direction.length_squared() > 0.0:
		facing_direction = aim_direction

	_update_sprint(delta, ability_held)
	_update_ability_buff(delta)
	health.tick_shield(delta)
	_update_ability_slots(delta, ability_slots_held)
	_update_secondary(delta, secondary_held)
	_refresh_secondary_bar()
	var speed := movement_speed * float(ability_buff_stats.get("movement_speed_mult", 1.0))
	if sprint_timer > 0.0:
		speed *= 1.0 + SPRINT_SPEED_BONUS
	speed *= 1.0 + skate_speed_bonus
	velocity = move_input * speed
	move_and_slide()
	_update_tobor_visual(delta, move_input)
	_update_hover_visual(delta)

	_update_buff(delta)
	_update_items(delta)
	if weapon_kind == PlayerClass.Weapon.MENDING_BOLT:
		_apply_support_aura(delta)

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_held and attack_cooldown <= 0.0:
		_perform_attack()
		attack_cooldown = attack_interval * float(ability_buff_stats.get("attack_interval_mult", 1.0))
	queue_redraw()


func _update_hover_visual(delta: float) -> void:
	if not hovering or sprite == null or class_id == "tobor":
		return
	_hover_phase += delta * 4.2
	var bob := sin(_hover_phase) * 3.5
	sprite.offset = Vector2(0.0, -10.0 + bob)
	if world_health_bar != null and sprite.texture != null:
		var h := sprite.texture.get_height() * sprite.scale.y
		world_health_bar.position = Vector2(-30.0, -h * 0.5 - 14.0 + bob)


func _update_sprint(delta: float, ability_held: bool) -> void:
	var was_sprinting := sprint_timer > 0.0
	sprint_timer = maxf(0.0, sprint_timer - delta)
	sprint_cooldown = maxf(0.0, sprint_cooldown - delta)
	if ability_held and has_active_item() and sprint_timer <= 0.0 and sprint_cooldown <= 0.0:
		sprint_timer = SPRINT_DURATION
		sprint_cooldown = SPRINT_COOLDOWN + SPRINT_DURATION
		AudioService.play("dash")
	## Phase Boots: the sprint genuinely phases through units and obstacles now, not just a
	## speed boost — collision is off for the whole burst and restored the instant it ends.
	if sprint_timer > 0.0 and not was_sprinting:
		collision_mask = 0
	elif sprint_timer <= 0.0 and was_sprinting:
		collision_mask = _normal_collision_mask


func _update_items(delta: float) -> void:
	if health_regen_per_second > 0.0:
		health.heal(health_regen_per_second * delta)
	_update_jetpack(delta)
	_update_grab(delta)
	if ember_damage_per_second <= 0.0:
		return
	for target in _enemies_in_radius(global_position, EMBER_RADIUS):
		var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(ember_damage_per_second * delta, self)


func _update_jetpack(delta: float) -> void:
	if jetpack_slam <= 0.0:
		_jump_t = -1.0
		return
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if _jump_t < 0.0:
		if _jump_cooldown <= 0.0:
			_jump_t = 0.0
			_jump_cooldown = 2.0 if stacks_of("sjaal") <= 0 else 2.4
		return
	var duration := 0.55 if stacks_of("sjaal") <= 0 else 0.85
	_jump_t += delta / duration
	if _jump_t >= 1.0:
		_jump_t = -1.0
		_land_slam()


func _land_slam() -> void:
	for target in _enemies_in_radius(global_position, 120.0):
		var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(jetpack_slam, self)
		if target.has_method("apply_knockback"):
			target.apply_knockback(global_position.direction_to(target.global_position) * 280.0)
	AudioService.play("explosion")


func _update_grab(delta: float) -> void:
	if grab_radius <= 0.0:
		return
	_grab_timer = maxf(0.0, _grab_timer - delta)
	if _grab_timer > 0.0:
		return
	_grab_timer = 0.85
	for target in _enemies_in_radius(global_position, grab_radius):
		if target.has_method("apply_knockback"):
			var inward := target.global_position.direction_to(global_position) * 220.0
			target.apply_knockback(inward)
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("xp_orbs"):
		if not is_instance_valid(node):
			continue
		if global_position.distance_to(node.global_position) <= grab_radius:
			node.global_position = node.global_position.lerp(global_position, 0.45)


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


## --- Hero abilities -------------------------------------------------------------------

func learn_ability(ability_id: String) -> void:
	if simulation_mode == SimulationMode.PROXY or known_abilities.size() >= PlayerClass.MAX_KNOWN_ABILITIES:
		return
	for entry in known_abilities:
		if entry.id == ability_id:
			return
	known_abilities.append({"id": ability_id, "rank": 1})
	ability_cooldowns[known_abilities.size() - 1] = 0.0


func upgrade_ability(ability_id: String) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	for entry in known_abilities:
		if entry.id == ability_id:
			entry.rank = mini(PlayerClass.MAX_ABILITY_RANK, int(entry.rank) + 1)
			return


## Very long runs can exhaust every ability offer (4 known, all maxed); this flat, choice-free
## bump keeps a level-up meaningful instead of stalling on an empty screen.
func apply_fallback_bonus() -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	health.max_health += PlayerClass.FALLBACK_UPGRADE_HEALTH_BONUS
	health.current_health = minf(health.max_health, health.current_health + PlayerClass.FALLBACK_UPGRADE_HEALTH_BONUS)
	health.health_changed.emit(health.current_health, health.max_health)


func _update_ability_slots(delta: float, slots_held: Array) -> void:
	if known_abilities.is_empty():
		return
	for slot in known_abilities.size():
		ability_cooldowns[slot] = maxf(0.0, ability_cooldowns[slot] - delta)
	for slot in known_abilities.size():
		if slot < slots_held.size() and bool(slots_held[slot]) and ability_cooldowns[slot] <= 0.0:
			_cast_known_ability(slot)


func _cast_known_ability(slot: int) -> void:
	var entry := known_abilities[slot]
	var ability_id := str(entry.id)
	var data := PlayerClass.ability_info(ability_id)
	if data.is_empty():
		return
	var values := PlayerClass.ability_values(ability_id, int(entry.rank))
	_casting_ability_id = ability_id
	ability_cooldowns[slot] = values.cooldown
	match int(data.archetype):
		PlayerClass.Archetype.NUKE_BOLT:
			_cast_ability_nuke_bolt(data, values)
		PlayerClass.Archetype.CONE_BURST:
			_cast_ability_cone_burst(data, values)
		PlayerClass.Archetype.RADIUS_BURST:
			_cast_ability_radius_burst(data, values)
		PlayerClass.Archetype.CHAIN_NUKE:
			_cast_ability_chain_nuke(data, values)
		PlayerClass.Archetype.DASH_STRIKE:
			_cast_ability_dash_strike(data, values)
		PlayerClass.Archetype.BLINK:
			_cast_ability_blink(data, values)
		PlayerClass.Archetype.SELF_HEAL:
			_cast_ability_self_heal(data, values)
		PlayerClass.Archetype.AOE_HEAL:
			_cast_ability_aoe_heal(data, values)
		PlayerClass.Archetype.SHIELD_BURST:
			_cast_ability_shield_burst(data, values)
		PlayerClass.Archetype.BUFF_SELF:
			_cast_ability_buff_self(data, values)
		PlayerClass.Archetype.PUSH_PULL_BURST:
			_cast_ability_push_pull_burst(data, values)


func _emit_ability_cast(points: PackedVector2Array) -> void:
	var style := PlayerClass.EffectStyle.BURST
	var data := PlayerClass.ability_info(_casting_ability_id)
	if not data.is_empty():
		match int(data.archetype):
			PlayerClass.Archetype.NUKE_BOLT, PlayerClass.Archetype.CHAIN_NUKE:
				style = PlayerClass.EffectStyle.BOLT
			PlayerClass.Archetype.CONE_BURST:
				style = PlayerClass.EffectStyle.ARC
			PlayerClass.Archetype.AOE_HEAL, PlayerClass.Archetype.BUFF_SELF:
				style = PlayerClass.EffectStyle.WAVE
	ability_cast.emit(_casting_ability_id, style, points)


## Shared "the ability's primary hit landed on this enemy" handling: base damage plus
## whatever on-hit modifiers the ability carries (slow/stun/mark/lifesteal).
func _apply_ability_hit(target: Node2D, data: Dictionary, values: Dictionary) -> void:
	_damage_enemy(target, values.power)
	if data.has("stun_on_hit") and target.has_method("apply_slow"):
		target.apply_slow(0.1, float(data.stun_on_hit.duration))
	if data.has("slow_on_hit") and target.has_method("apply_slow"):
		target.apply_slow(float(data.slow_on_hit.factor), float(data.slow_on_hit.duration))
	if data.has("mark_on_hit") and target.has_method("apply_mark"):
		target.apply_mark(float(data.mark_on_hit.bonus_pct), float(data.mark_on_hit.duration))
	if data.has("lifesteal_pct"):
		health.heal(values.power * float(data.lifesteal_pct))


func _nearest_enemy_in_range(range_limit: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance_sq := range_limit * range_limit
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate.has_method("is_damageable") and not candidate.is_damageable():
			continue
		var distance_sq: float = global_position.distance_squared_to((candidate as Node2D).global_position)
		if distance_sq <= nearest_distance_sq:
			nearest = candidate
			nearest_distance_sq = distance_sq
	return nearest


func _find_ability_chain_target(origin: Node2D, excluded: Array[Node2D], range_limit: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance_sq := range_limit * range_limit
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


func _cast_ability_nuke_bolt(data: Dictionary, values: Dictionary) -> void:
	var center := _ability_aim_center(values.range)
	for target in _enemies_in_radius(center, values.radius):
		_apply_ability_hit(target, data, values)
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.radius, 0.0)]))


func _ability_aim_center(max_range: float) -> Vector2:
	var target := _nearest_enemy_in_range(max_range)
	if target != null:
		return target.global_position
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	return global_position + direction * minf(max_range, 220.0)


func _cast_ability_cone_burst(data: Dictionary, values: Dictionary) -> void:
	var half_angle := deg_to_rad(PlayerClass.ABILITY_CONE_HALF_ANGLE_DEGREES)
	for target in _enemies_in_radius(global_position, values.radius):
		var to_target := global_position.direction_to(target.global_position)
		if to_target.length_squared() > 0.0 and absf(facing_direction.angle_to(to_target)) > half_angle:
			continue
		_apply_ability_hit(target, data, values)
	_emit_ability_cast(PackedVector2Array([
		global_position,
		Vector2(values.radius, PlayerClass.ABILITY_CONE_HALF_ANGLE_DEGREES),
		global_position + facing_direction * values.radius,
	]))


func _cast_ability_radius_burst(data: Dictionary, values: Dictionary) -> void:
	var center := global_position
	if values.range > 0.0:
		var travel := minf(values.range, global_position.distance_to(aim_world_position))
		center = global_position + global_position.direction_to(aim_world_position) * travel
	for target in _enemies_in_radius(center, values.radius):
		_apply_ability_hit(target, data, values)
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.radius, 0.0)]))


func _cast_ability_chain_nuke(data: Dictionary, values: Dictionary) -> void:
	var primary := _nearest_enemy_in_range(values.range)
	var centers: Array[Vector2] = []
	if primary == null:
		centers.append(_ability_aim_center(values.range))
	else:
		centers.append(primary.global_position)
	var struck: Array[Node2D] = []
	var chain_origin: Node2D = primary if primary != null else self
	var chain_range := float(data.get("chain_range", 200.0))
	for _chain_index in int(values.chain_count):
		var next_target := _find_ability_chain_target(chain_origin, struck, chain_range)
		if next_target == null:
			break
		centers.append(next_target.global_position)
		chain_origin = next_target
	for center in centers:
		for target in _enemies_in_radius(center, values.radius):
			if target in struck:
				continue
			struck.append(target)
			_apply_ability_hit(target, data, values)
	var vfx_center := centers[0] if not centers.is_empty() else global_position
	_emit_ability_cast(PackedVector2Array([vfx_center, Vector2(values.radius, 0.0)]))


## Approximates "everything the dash passes through" as a capsule around the midpoint of the
## line — cheap, and close enough at these dash lengths without needing swept collision.
func _cast_ability_dash_strike(data: Dictionary, values: Dictionary) -> void:
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	var origin := global_position
	var destination := origin + direction * float(values.dash_distance)
	var midpoint := origin.lerp(destination, 0.5)
	var hit_radius := float(values.dash_distance) * 0.5 + float(values.radius)
	for target in _enemies_in_radius(midpoint, hit_radius):
		_apply_ability_hit(target, data, values)
	global_position = destination
	_emit_ability_cast(PackedVector2Array([origin, Vector2(values.dash_distance, 0.0)]))


func _cast_ability_blink(_data: Dictionary, values: Dictionary) -> void:
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	global_position += direction * values.dash_distance
	for target in _enemies_in_radius(global_position, values.radius):
		_apply_ability_hit(target, _data, values)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(values.radius, 0.0)]))


func _cast_ability_self_heal(data: Dictionary, values: Dictionary) -> void:
	health.heal(values.power)
	for target in _enemies_in_radius(global_position, values.radius):
		_apply_ability_hit(target, data, values)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(values.radius, 0.0)]))


func _cast_ability_aoe_heal(_data: Dictionary, values: Dictionary) -> void:
	var radius_sq := float(values.radius) * float(values.radius)
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var ally := candidate as Player
		if not ally.active or ally.health.is_dead:
			continue
		if global_position.distance_squared_to(ally.global_position) > radius_sq:
			continue
		ally.health.heal(values.power)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(values.radius, 0.0)]))


func _cast_ability_shield_burst(data: Dictionary, values: Dictionary) -> void:
	var scope := str(data.get("target_scope", "self"))
	if scope == "self":
		health.add_shield(values.power, values.duration)
	else:
		var radius_sq := float(values.radius) * float(values.radius)
		for candidate in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(candidate) or not candidate is Player:
				continue
			var ally := candidate as Player
			if not ally.active or ally.health.is_dead:
				continue
			if global_position.distance_squared_to(ally.global_position) > radius_sq:
				continue
			ally.health.add_shield(values.power, values.duration)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(values.radius if scope != "self" else values.radius, 0.0)]))


func _cast_ability_buff_self(data: Dictionary, values: Dictionary) -> void:
	var stats: Dictionary = data.get("buff_stats", {})
	var scope := str(data.get("target_scope", "self"))
	if scope == "self":
		_apply_ability_buff(stats, values.duration)
		for target in _enemies_in_radius(global_position, values.radius):
			if target.has_method("apply_slow"):
				target.apply_slow(0.75, 1.0)
	else:
		var radius_sq := float(values.radius) * float(values.radius)
		for candidate in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(candidate) or not candidate is Player:
				continue
			var ally := candidate as Player
			if not ally.active or ally.health.is_dead:
				continue
			if global_position.distance_squared_to(ally.global_position) > radius_sq:
				continue
			ally._apply_ability_buff(stats, values.duration)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(values.radius, 0.0)]))


## power > 0 pulls enemies toward the caster, power < 0 knocks them away.
func _cast_ability_push_pull_burst(_data: Dictionary, values: Dictionary) -> void:
	var center := global_position
	var strength := float(values.power)
	for target in _enemies_in_radius(center, values.radius):
		if not target.has_method("apply_knockback"):
			continue
		var away_direction := center.direction_to(target.global_position)
		if away_direction.length_squared() <= 0.0:
			away_direction = Vector2.RIGHT
		var impulse_direction := away_direction if strength < 0.0 else -away_direction
		target.apply_knockback(impulse_direction * absf(strength))
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.radius, 0.0)]))


func _apply_ability_buff(stats: Dictionary, duration: float) -> void:
	_clear_ability_buff()
	ability_buff_stats = stats
	ability_buff_timer = duration
	if stats.has("damage_taken_mult"):
		_ability_damage_taken_factor = float(stats.damage_taken_mult)
		health.damage_taken_multiplier *= _ability_damage_taken_factor


func _clear_ability_buff() -> void:
	if _ability_damage_taken_factor != 1.0:
		health.damage_taken_multiplier /= _ability_damage_taken_factor
		_ability_damage_taken_factor = 1.0
	ability_buff_stats = {}
	ability_buff_timer = 0.0


func _update_ability_buff(delta: float) -> void:
	if ability_buff_timer <= 0.0:
		return
	ability_buff_timer = maxf(0.0, ability_buff_timer - delta)
	if ability_buff_timer <= 0.0:
		_clear_ability_buff()


func _refresh_secondary_bar() -> void:
	if world_health_bar != null:
		world_health_bar.set_secondary_cooldown(secondary_cooldown, secondary_cooldown_max)


func _update_secondary(delta: float, held: bool) -> void:
	secondary_cooldown = maxf(0.0, secondary_cooldown - delta)
	var just_pressed := held and not _secondary_was_held
	var just_released := (not held) and _secondary_was_held
	_secondary_was_held = held
	if secondary_kind == "wall" and simulation_mode != SimulationMode.CPU:
		if just_pressed and secondary_cooldown <= 0.0:
			_drawing_wall = true
			_wall_draw_age = 0.0
			_wall_points = PackedVector2Array([global_position])
		if _drawing_wall:
			_wall_draw_age += delta
			_append_wall_point(aim_world_position)
			if just_released or _wall_draw_age >= 2.0 or _wall_length() >= PlayerClass.WALL_MAX_LENGTH:
				_commit_wall()
		return
	if just_pressed and secondary_cooldown <= 0.0:
		_cast_secondary()


func _append_wall_point(point: Vector2) -> void:
	if _wall_points.is_empty():
		_wall_points.append(point)
		return
	if _wall_points[_wall_points.size() - 1].distance_to(point) < 18.0:
		return
	if _wall_length() + _wall_points[_wall_points.size() - 1].distance_to(point) > PlayerClass.WALL_MAX_LENGTH:
		return
	_wall_points.append(point)


func _wall_length() -> float:
	var total := 0.0
	for index in range(_wall_points.size() - 1):
		total += _wall_points[index].distance_to(_wall_points[index + 1])
	return total


func _commit_wall() -> void:
	_drawing_wall = false
	var points := _wall_points.duplicate()
	_wall_points = PackedVector2Array()
	if points.size() < 2:
		var facing := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
		var origin := global_position + facing * 36.0
		var across := facing.orthogonal()
		points = PackedVector2Array([origin - across * 90.0, origin + across * 90.0])
	_spawn_support_wall(points)
	_pulse_allies(global_position, PlayerClass.SECONDARY_RADIUS, PlayerClass.SECONDARY_HEAL * 0.6, 22.0)
	_start_secondary_cooldown()


func _cast_secondary() -> void:
	match secondary_kind:
		"wall":
			_commit_wall()
			return
		"repulse":
			_cast_secondary_repulse()
		"freeze":
			_cast_secondary_freeze()
		"volt_mend":
			_cast_secondary_volt_mend()
		"rime_ward":
			_cast_secondary_rime_ward()
		_:
			_cast_secondary_volt_mend()
	_start_secondary_cooldown()


func _start_secondary_cooldown() -> void:
	secondary_cooldown = secondary_cooldown_max
	_refresh_secondary_bar()


func _secondary_center() -> Vector2:
	var travel := minf(PlayerClass.SECONDARY_RADIUS, global_position.distance_to(aim_world_position))
	if travel <= 8.0:
		return global_position + facing_direction * 48.0
	return global_position + global_position.direction_to(aim_world_position) * travel


func _cast_secondary_repulse() -> void:
	var center := _secondary_center()
	for target in _enemies_in_radius(center, PlayerClass.SECONDARY_RADIUS):
		_damage_enemy(target, PlayerClass.SECONDARY_DAMAGE)
		if target.has_method("apply_knockback"):
			var away := center.direction_to(target.global_position)
			if away.length_squared() <= 0.0:
				away = facing_direction
			target.apply_knockback(away * 640.0)
	_pulse_allies(center, PlayerClass.SECONDARY_RADIUS, PlayerClass.SECONDARY_HEAL, 28.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BLAST, PackedVector2Array([global_position, center, Vector2(PlayerClass.SECONDARY_RADIUS, 0.0)]))


func _cast_secondary_freeze() -> void:
	var center := _secondary_center()
	for target in _enemies_in_radius(center, PlayerClass.SECONDARY_RADIUS):
		_damage_enemy(target, PlayerClass.SECONDARY_DAMAGE * 0.7)
		if target.has_method("apply_slow"):
			target.apply_slow(0.12, 2.6)
	_pulse_allies(center, PlayerClass.SECONDARY_RADIUS, PlayerClass.SECONDARY_HEAL, 0.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([center, Vector2(PlayerClass.SECONDARY_RADIUS, 0.0)]))


func _cast_secondary_volt_mend() -> void:
	var center := _secondary_center()
	for target in _enemies_in_radius(center, PlayerClass.SECONDARY_RADIUS):
		_damage_enemy(target, PlayerClass.SECONDARY_DAMAGE)
		if target.has_method("apply_knockback"):
			var away := center.direction_to(target.global_position)
			if away.length_squared() <= 0.0:
				away = facing_direction
			target.apply_knockback(away * 560.0)
	_pulse_allies(center, PlayerClass.SECONDARY_RADIUS, PlayerClass.SECONDARY_HEAL, 0.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BLAST, PackedVector2Array([global_position, center, Vector2(PlayerClass.SECONDARY_RADIUS, 0.0)]))


func _cast_secondary_rime_ward() -> void:
	var center := _secondary_center()
	for target in _enemies_in_radius(center, PlayerClass.SECONDARY_RADIUS):
		_damage_enemy(target, PlayerClass.SECONDARY_DAMAGE * 0.75)
		if target.has_method("apply_slow"):
			target.apply_slow(0.4, 2.2)
	_pulse_allies(center, PlayerClass.SECONDARY_RADIUS, PlayerClass.SECONDARY_HEAL * 0.7, 40.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([center, Vector2(PlayerClass.SECONDARY_RADIUS, 0.0)]))


func _pulse_allies(center: Vector2, radius: float, heal_amount: float, shield_amount: float) -> void:
	for ally in _allies_in_radius(center, radius):
		if heal_amount > 0.0:
			ally.health.heal(heal_amount)
		if shield_amount > 0.0:
			ally.health.add_shield(shield_amount, 3.0)


func _allies_in_radius(center: Vector2, radius: float) -> Array[Player]:
	var found: Array[Player] = []
	if not is_inside_tree():
		return found
	var radius_sq := radius * radius
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var ally := candidate as Player
		if not ally.active or ally.health.is_dead:
			continue
		if center.distance_squared_to(ally.global_position) <= radius_sq:
			found.append(ally)
	return found


func _spawn_support_wall(points: PackedVector2Array) -> void:
	if simulation_mode == SimulationMode.PROXY or points.size() < 2:
		return
	var wall := SupportWall.new()
	var parent := get_parent()
	if parent != null:
		parent.add_child(wall)
	else:
		add_child(wall)
	wall.configure(points, PlayerClass.WALL_DURATION, self, accent_color)
	support_wall_spawned.emit(points, PlayerClass.WALL_DURATION, accent_color)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.ARC, PackedVector2Array([
		points[0],
		Vector2(PlayerClass.WALL_THICKNESS, PlayerClass.CONE_HALF_ANGLE_DEGREES),
		points[points.size() - 1],
	]))


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
		PlayerClass.Weapon.ENERGY_BLAST:
			_cast_energy_blast()


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
	var half_angle := deg_to_rad(cone_half_angle_degrees)
	for target in _enemies_in_radius(global_position, attack_range):
		var to_target := global_position.direction_to(target.global_position)
		if to_target.length_squared() > 0.0 and absf(facing_direction.angle_to(to_target)) > half_angle:
			continue
		_damage_enemy(target, weapon_damage)
	staff_cast.emit(class_id, PackedVector2Array([
		global_position,
		Vector2(attack_range, cone_half_angle_degrees),
		global_position + facing_direction * attack_range,
	]))


func _cast_energy_blast() -> void:
	var primary := _find_primary_target()
	var impact := primary.global_position if primary != null else global_position + facing_direction * minf(attack_range, 280.0)
	for pulse_index in maxi(1, blast_pulses):
		var pulse_damage := weapon_damage if pulse_index == 0 else weapon_damage * PlayerClass.BLAST_AFTERSHOCK_DAMAGE
		for target in _enemies_in_radius(impact, blast_radius):
			_damage_enemy(target, pulse_damage)
	staff_cast.emit(class_id, PackedVector2Array([
		global_position,
		impact,
		Vector2(blast_radius, 0.0),
	]))


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
	if target.has_method("vulnerability_multiplier"):
		resistance *= target.vulnerability_multiplier()
	var ability_damage_mult := float(ability_buff_stats.get("damage_dealt_mult", 1.0))
	var dealt := amount * damage_dealt_multiplier * ability_damage_mult * resistance
	target_health.take_damage(dealt, self)
	if lifesteal_ratio > 0.0:
		health.heal(dealt * lifesteal_ratio)
	if hit_slow_factor < 1.0 and target.has_method("apply_slow"):
		target.apply_slow(hit_slow_factor, hit_slow_duration)
	if knockback_strength > 0.0 and target.has_method("apply_knockback"):
		target.apply_knockback(global_position.direction_to(target.global_position) * knockback_strength)


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
	if not ShopCatalog.available_for(item_id, class_id):
		return false
	if not can_afford(item_id):
		return false
	gold -= ShopCatalog.price_for(item_id, stacks_of(item_id))
	shop_stacks[item_id] = stacks_of(item_id) + 1
	_apply_shop_item(item_id)
	gold_changed.emit(gold)
	return true


func _apply_shop_item(item_id: String) -> void:
	var item := ShopCatalog.by_id(item_id)
	thorns_ratio += float(item.get("thorns_ratio", 0.0))
	lifesteal_ratio += float(item.get("lifesteal_ratio", 0.0))
	health_regen_per_second += float(item.get("health_regen_per_second", 0.0))
	resistance_pierce += float(item.get("resistance_pierce", 0.0))
	ember_damage_per_second += float(item.get("ember_damage_per_second", 0.0))
	knockback_strength += float(item.get("knockback_strength", 0.0))
	pickup_radius_bonus += float(item.get("pickup_radius_bonus", 0.0))
	jetpack_slam += float(item.get("jetpack_slam", 0.0))
	skate_speed_bonus += float(item.get("skate_speed_bonus", 0.0))
	grab_radius = maxf(grab_radius, float(item.get("grab_radius", 0.0)))
	if item.has("hit_slow_factor"):
		hit_slow_factor = minf(hit_slow_factor, float(item.hit_slow_factor))
		hit_slow_duration = maxf(hit_slow_duration, float(item.get("hit_slow_duration", 1.0)))
	if item_id == ShopCatalog.ACTIVE_ITEM_ID:
		sprint_cooldown = 0.0
	_apply_sprite()


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


## Dev menu only: same per-level bookkeeping as add_xp, without spending XP, so it queues
## one upgrade choice per level like a normal level-up chain would.
func dev_add_levels(count: int) -> void:
	if simulation_mode == SimulationMode.PROXY or count <= 0:
		return
	for _index in count:
		level += 1
		xp_required = roundi(xp_required * 1.35)
		xp_changed.emit(current_xp, xp_required, level)
		level_reached.emit(level)


func set_invulnerable(value: bool) -> void:
	health.invulnerable = value


func apply_upgrade(upgrade_id: String) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	match upgrade_id:
		"rapid", "rime": attack_interval = maxf(0.18, attack_interval * 0.82)
		"heavy": weapon_damage += 8.0
		"chain": chain_count += 1
		"volt": chain_range += 40.0
		"blast": blast_radius += 40.0
		"aftershock": blast_pulses += 1
		"boots": movement_speed += 35.0
		"plating": health.damage_taken_multiplier = maxf(0.35, health.damage_taken_multiplier - 0.08)
		"reach": attack_range += 35.0
		"sweep": cone_half_angle_degrees += PlayerClass.SWEEP_DEGREES
		"flow": support_heal_per_second += 1.5
		"choir": support_damage_bonus += 0.06
		"lash": attack_range += 60.0
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
		"jump_t": _jump_t,
		"dash_cooldown": sprint_cooldown,
		"dash_active": sprint_timer,
		"known_abilities": known_abilities,
		"ability_cooldowns": ability_cooldowns,
		"secondary_cooldown": secondary_cooldown,
		"secondary_cooldown_max": secondary_cooldown_max,
	}


func _on_damaged(amount: float) -> void:
	AudioService.play("hurt")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color("ff7777"), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	CombatText.spawn(get_parent(), global_position + Vector2(randf_range(-9.0, 9.0), -30.0), amount)
	_reflect_damage(amount)


func _reflect_damage(amount: float) -> void:
	var total_ratio := thorns_ratio + float(ability_buff_stats.get("reflect_pct", 0.0))
	if simulation_mode == SimulationMode.PROXY or total_ratio <= 0.0:
		return
	var attacker := health.last_damage_source as Enemy
	if attacker == null or not is_instance_valid(attacker) or attacker.health.is_dead:
		return
	attacker.health.take_damage(amount * total_ratio)


func _on_died() -> void:
	active = false
	modulate = Color(0.35, 0.35, 0.4, 1.0)
	AudioService.play("player_down")
	player_died.emit(owner_peer_id)


## Server-side only: a teammate stood still next to this downed player for long enough
## (see main.gd's revive tracking).
func revive() -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	active = true
	modulate = Color.WHITE
	health.is_dead = false
	health.current_health = health.max_health * 0.5
	health.health_changed.emit(health.current_health, health.max_health)
	AudioService.play("revive")


func _draw() -> void:
	if hovering:
		draw_circle(Vector2(0.0, 18.0), 14.0, Color(0.05, 0.12, 0.08, 0.35))
	if _drawing_wall and _wall_points.size() >= 1:
		var local_wall := PackedVector2Array()
		for point in _wall_points:
			local_wall.append(to_local(point))
		local_wall.append(to_local(aim_world_position))
		if local_wall.size() >= 2:
			draw_polyline(local_wall, Color(accent_color, 0.85), 8.0, true)
	if not has_sprite():
		draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
		draw_circle(Vector2.ZERO, BODY_RADIUS, accent_color, false, 3.0)
		draw_line(facing_direction * 20.0, facing_direction * 30.0, accent_color, 4.0)
		draw_circle(facing_direction * 32.0, 4.5, accent_color)

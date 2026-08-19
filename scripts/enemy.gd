class_name Enemy
extends CharacterBody2D

signal defeated(enemy: Enemy)
signal projectile_fired(origin: Vector2, direction: Vector2, damage: float, speed: float, sprite_name: String)
signal spawn_requested(type_id: String, origin: Vector2, count: int)
signal exploded(origin: Vector2, radius: float, damage: float)

const SEPARATION_RANGE := 62.0
const SEPARATION_STRENGTH := 130.0
const CombatTextScene: PackedScene = preload("res://scenes/effects/combat_text.tscn")

@export var movement_speed := 100.0
@export var contact_damage := 6.0
@export var attack_interval := 1.0
@export var attack_distance := 40.0
@export var xp_value := 10
@export var gold_value := 3

@onready var health: HealthComponent = $HealthComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite

var type_id := EnemyType.DEFAULT_TYPE_ID
var behaviour: EnemyType.Behaviour = EnemyType.Behaviour.MELEE
var body_radius := 17.0
var fill_color := Color("ff5d5d")
var outline_color := Color("ffb0a9")
var taunt_immune := false
var flying := false
var is_boss := false
var preferred_distance := 0.0
var projectile_damage := 0.0
var projectile_speed := 0.0
var projectile_count := 1
var projectile_sprite := "spit"
var aura_radius := 0.0
var aura_heal_per_second := 0.0
var explode_damage := 0.0
var explode_radius := 0.0
var death_spawn_id := ""
var death_spawn_count := 0
var summon_id := ""
var summon_count := 0
var summon_interval := 0.0
var charge_speed := 0.0
var charge_windup := 0.0
var charge_duration := 0.0
var separation_weight := 1.0

var network_id := 0
var server_authoritative := true
var target: Node2D
var attack_cooldown := 0.0
var network_target_position := Vector2.ZERO
var slow_factor := 1.0
var slow_timer := 0.0
var aura_pulse := 0.0
var summon_timer := 0.0
var charge_state_timer := 0.0
var charging := false
var winding_up := false
var charge_direction := Vector2.RIGHT
var has_exploded := false


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	network_target_position = global_position
	queue_redraw()


func configure(next_network_id: int, authoritative: bool, next_type_id: String = EnemyType.DEFAULT_TYPE_ID, health_multiplier: float = 1.0, speed_multiplier: float = 1.0) -> void:
	network_id = next_network_id
	server_authoritative = authoritative
	network_target_position = global_position
	apply_type(next_type_id, health_multiplier, speed_multiplier)


func apply_type(next_type_id: String, health_multiplier: float = 1.0, speed_multiplier: float = 1.0) -> void:
	type_id = EnemyType.sanitize_id(next_type_id)
	behaviour = EnemyType.field(type_id, "behaviour")
	body_radius = float(EnemyType.field(type_id, "radius"))
	fill_color = Color(str(EnemyType.field(type_id, "fill_color")))
	outline_color = Color(str(EnemyType.field(type_id, "outline_color")))
	movement_speed = float(EnemyType.field(type_id, "movement_speed")) * maxf(0.1, speed_multiplier)
	gold_value = int(EnemyType.field(type_id, "gold_value"))
	contact_damage = float(EnemyType.field(type_id, "contact_damage"))
	attack_interval = float(EnemyType.field(type_id, "attack_interval"))
	attack_distance = float(EnemyType.field(type_id, "attack_distance"))
	xp_value = int(EnemyType.field(type_id, "xp_value"))
	taunt_immune = bool(EnemyType.field(type_id, "taunt_immune"))
	flying = bool(EnemyType.field(type_id, "flying"))
	is_boss = bool(EnemyType.field(type_id, "is_boss"))
	preferred_distance = float(EnemyType.field(type_id, "preferred_distance"))
	projectile_damage = float(EnemyType.field(type_id, "projectile_damage"))
	projectile_speed = float(EnemyType.field(type_id, "projectile_speed"))
	projectile_count = int(EnemyType.field(type_id, "projectile_count"))
	projectile_sprite = str(EnemyType.field(type_id, "projectile_sprite"))
	aura_radius = float(EnemyType.field(type_id, "aura_radius"))
	aura_heal_per_second = float(EnemyType.field(type_id, "aura_heal_per_second"))
	explode_damage = float(EnemyType.field(type_id, "explode_damage"))
	explode_radius = float(EnemyType.field(type_id, "explode_radius"))
	death_spawn_id = str(EnemyType.field(type_id, "death_spawn_id"))
	death_spawn_count = int(EnemyType.field(type_id, "death_spawn_count"))
	summon_id = str(EnemyType.field(type_id, "summon_id"))
	summon_count = int(EnemyType.field(type_id, "summon_count"))
	summon_interval = float(EnemyType.field(type_id, "summon_interval"))
	charge_speed = float(EnemyType.field(type_id, "charge_speed"))
	charge_windup = float(EnemyType.field(type_id, "charge_windup"))
	charge_duration = float(EnemyType.field(type_id, "charge_duration"))
	separation_weight = float(EnemyType.field(type_id, "separation_weight"))
	summon_timer = summon_interval

	var shape := CircleShape2D.new()
	shape.radius = body_radius
	collision_shape.shape = shape
	# Fliers pass over the arena and everything walking in it.
	collision_mask = 0 if flying else 7

	health.max_health = float(EnemyType.field(type_id, "max_health")) * maxf(1.0, health_multiplier)
	health.current_health = health.max_health
	health.is_dead = false
	health.health_changed.emit(health.current_health, health.max_health)
	_apply_sprite()
	queue_redraw()


## Classic mode stays on the plain vector look (see arena.gd's grid background), so it never
## picks up pixel art here either.
func _apply_sprite() -> void:
	if sprite == null or GameRuntime.is_classic():
		return
	sprite.texture = SpriteLibrary.texture_for(type_id)
	sprite.scale = SpriteLibrary.scale_for_radius(sprite.texture, body_radius * 1.25)


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func damage_multiplier_for(damage_type: int) -> float:
	return EnemyType.damage_multiplier(type_id, damage_type)


func _physics_process(delta: float) -> void:
	if not server_authoritative:
		global_position = global_position.lerp(network_target_position, clampf(delta * 12.0, 0.0, 1.0))
		if aura_radius > 0.0 or winding_up:
			aura_pulse += delta
			queue_redraw()
		return

	_update_slow(delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	target = _find_nearest_player()
	if target == null:
		velocity = Vector2.ZERO
		return

	if aura_heal_per_second > 0.0:
		_apply_healing_aura(delta)
	if summon_count > 0 and summon_interval > 0.0:
		_update_summoning(delta)

	match behaviour:
		EnemyType.Behaviour.RANGED:
			_process_ranged()
		EnemyType.Behaviour.SUPPORT:
			_process_support()
		EnemyType.Behaviour.CHARGER:
			_process_charger(delta)
		_:
			_process_melee()


func _move(direction_velocity: Vector2) -> void:
	velocity = direction_velocity + _separation_offset()
	if flying:
		global_position += velocity * get_physics_process_delta_time()
	else:
		move_and_slide()


func _separation_offset() -> Vector2:
	if separation_weight <= 0.0:
		return Vector2.ZERO
	var push := Vector2.ZERO
	var range_sq := SEPARATION_RANGE * SEPARATION_RANGE
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate == self or not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var offset: Vector2 = global_position - (candidate as Node2D).global_position
		var distance_sq := offset.length_squared()
		if distance_sq <= 0.01 or distance_sq > range_sq:
			continue
		push += offset.normalized() * (1.0 - sqrt(distance_sq) / SEPARATION_RANGE)
	if push == Vector2.ZERO:
		return Vector2.ZERO
	return push.limit_length(2.0) * SEPARATION_STRENGTH / maxf(0.3, separation_weight)


func _process_melee() -> void:
	var distance := global_position.distance_to(target.global_position)
	if explode_damage > 0.0 and distance <= attack_distance:
		_explode()
		return
	if distance > attack_distance:
		_move(global_position.direction_to(target.global_position) * movement_speed * slow_factor)
	else:
		velocity = Vector2.ZERO
		_attack_target()


func _process_ranged() -> void:
	_hold_preferred_distance()
	if global_position.distance_to(target.global_position) <= attack_distance:
		_fire_projectile()


func _process_support() -> void:
	_hold_preferred_distance()


func _process_charger(delta: float) -> void:
	if charging:
		charge_state_timer -= delta
		_move(charge_direction * charge_speed * slow_factor)
		if _try_contact_damage():
			charging = false
			charge_state_timer = 0.0
		elif charge_state_timer <= 0.0:
			charging = false
		return

	if winding_up:
		charge_state_timer -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		if charge_state_timer <= 0.0:
			winding_up = false
			charging = true
			charge_state_timer = charge_duration
			charge_direction = global_position.direction_to(target.global_position)
		return

	var distance := global_position.distance_to(target.global_position)
	if distance <= charge_speed * charge_duration * 0.8 and distance > attack_distance:
		winding_up = true
		charge_state_timer = charge_windup
		velocity = Vector2.ZERO
		queue_redraw()
		AudioService.play("charge")
		return

	_process_melee()


func _try_contact_damage() -> bool:
	if target == null or contact_damage <= 0.0 or attack_cooldown > 0.0:
		return false
	if global_position.distance_to(target.global_position) > attack_distance + body_radius:
		return false
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if target_health == null:
		return false
	target_health.take_damage(contact_damage, self)
	attack_cooldown = attack_interval
	return true


func _hold_preferred_distance() -> void:
	var distance := global_position.distance_to(target.global_position)
	var to_target := global_position.direction_to(target.global_position)
	if distance > preferred_distance + 60.0:
		_move(to_target * movement_speed * slow_factor)
	elif distance < preferred_distance - 60.0:
		_move(-to_target * movement_speed * slow_factor)
	else:
		_move(Vector2.ZERO)


func _fire_projectile() -> void:
	if attack_cooldown > 0.0 or projectile_damage <= 0.0:
		return
	attack_cooldown = attack_interval
	var base_direction := global_position.direction_to(target.global_position)
	var spread := deg_to_rad(9.0)
	var start := -spread * float(projectile_count - 1) * 0.5
	for index in maxi(1, projectile_count):
		var direction := base_direction.rotated(start + spread * float(index))
		projectile_fired.emit(global_position, direction, projectile_damage, projectile_speed, projectile_sprite)


func _update_summoning(delta: float) -> void:
	summon_timer = maxf(0.0, summon_timer - delta)
	if summon_timer > 0.0:
		return
	summon_timer = summon_interval
	spawn_requested.emit(summon_id, global_position, summon_count)


func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	exploded.emit(global_position, explode_radius, explode_damage)
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var victim := candidate as Player
		if not victim.active:
			continue
		if global_position.distance_to(victim.global_position) > explode_radius:
			continue
		var victim_health := victim.get_node_or_null("HealthComponent") as HealthComponent
		if victim_health != null:
			victim_health.take_damage(explode_damage, self)
	health.take_damage(health.max_health * 10.0)


func _apply_healing_aura(delta: float) -> void:
	var radius_sq := aura_radius * aura_radius
	aura_pulse += delta
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or candidate == self or not candidate is Enemy:
			continue
		var ally := candidate as Enemy
		if ally.health.is_dead:
			continue
		if global_position.distance_squared_to(ally.global_position) <= radius_sq:
			ally.health.heal(aura_heal_per_second * delta)
	queue_redraw()


func apply_slow(next_slow_factor: float, duration: float) -> void:
	if not server_authoritative:
		return
	slow_factor = minf(slow_factor, clampf(next_slow_factor, 0.1, 1.0))
	slow_timer = maxf(slow_timer, duration)
	queue_redraw()


func _update_slow(delta: float) -> void:
	if slow_timer <= 0.0:
		return
	slow_timer = maxf(0.0, slow_timer - delta)
	if slow_timer <= 0.0:
		slow_factor = 1.0
		queue_redraw()


func is_slowed() -> bool:
	return slow_timer > 0.0


func apply_network_state(state: Dictionary) -> void:
	var state_type_id := EnemyType.sanitize_id(str(state.get("type_id", type_id)))
	if state_type_id != type_id:
		apply_type(state_type_id)
	network_target_position = state.get("position", global_position)
	var next_slowed: bool = state.get("slowed", false)
	if (slow_timer > 0.0) != next_slowed:
		queue_redraw()
	slow_timer = 1.0 if next_slowed else 0.0
	var next_winding: bool = state.get("winding", false)
	if next_winding != winding_up:
		winding_up = next_winding
		queue_redraw()
		if next_winding:
			AudioService.play("charge")
	health.set_network_state(
		state.get("health", health.current_health),
		state.get("max_health", health.max_health)
	)


func snapshot() -> Dictionary:
	return {
		"id": network_id,
		"type_id": type_id,
		"position": global_position,
		"health": health.current_health,
		"max_health": health.max_health,
		"slowed": slow_timer > 0.0,
		"winding": winding_up,
	}


func is_damageable() -> bool:
	return server_authoritative and not health.is_dead


func _find_nearest_player() -> Node2D:
	var nearest: Node2D
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player or not candidate.active:
			continue
		var player := candidate as Player
		var weight := 1.0 if taunt_immune else player.taunt_weight
		var score: float = global_position.distance_squared_to(player.global_position) * weight
		if score < best_score:
			nearest = player
			best_score = score
	return nearest


func _attack_target() -> void:
	if attack_cooldown > 0.0 or target == null or contact_damage <= 0.0:
		return
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if target_health != null:
		target_health.take_damage(contact_damage, self)
		attack_cooldown = attack_interval


func _on_damaged(amount: float) -> void:
	AudioService.play("hit")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	var text := CombatTextScene.instantiate() as CombatText
	text.global_position = global_position + Vector2(randf_range(-9.0, 9.0), -body_radius - 6.0)
	get_parent().add_child(text)
	text.setup(amount)


func _on_died() -> void:
	if not server_authoritative:
		return
	remove_from_group("enemies")
	set_physics_process(false)
	if not death_spawn_id.is_empty() and death_spawn_count > 0:
		spawn_requested.emit(death_spawn_id, global_position, death_spawn_count)
	defeated.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var fill := fill_color
	var outline := outline_color
	if slow_timer > 0.0:
		fill = fill.lerp(Color("6fb7ff"), 0.45)
		outline = outline.lerp(Color("d3ecff"), 0.6)

	if aura_radius > 0.0:
		var pulse := 0.5 + 0.5 * sin(aura_pulse * 3.0)
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, Color(fill_color, 0.12 + 0.1 * pulse), 3.0, true)

	if flying:
		draw_circle(Vector2(0.0, body_radius * 1.05), body_radius * 0.8, Color(0.0, 0.0, 0.0, 0.28))

	if winding_up:
		draw_circle(Vector2.ZERO, body_radius * 1.6, Color(outline_color, 0.3))

	if is_boss:
		draw_arc(Vector2.ZERO, body_radius * 1.2, 0.0, TAU, 48, Color(outline, 0.7), 3.0, true)

	if has_sprite():
		if slow_timer > 0.0:
			sprite.modulate = Color("9fd8ff")
		else:
			sprite.modulate = Color.WHITE
		return

	draw_circle(Vector2.ZERO, body_radius, fill)
	draw_circle(Vector2.ZERO, body_radius, outline, false, 3.0)
	if behaviour == EnemyType.Behaviour.RANGED:
		draw_circle(Vector2.ZERO, body_radius * 0.4, outline)
	elif explode_damage > 0.0:
		draw_line(Vector2(-body_radius * 0.45, -body_radius * 0.45), Vector2(body_radius * 0.45, body_radius * 0.45), outline, 2.5)
		draw_line(Vector2(body_radius * 0.45, -body_radius * 0.45), Vector2(-body_radius * 0.45, body_radius * 0.45), outline, 2.5)
	elif taunt_immune:
		draw_line(Vector2(-body_radius * 0.5, 0.0), Vector2(body_radius * 0.5, 0.0), outline, 2.5)
		draw_line(Vector2(0.0, -body_radius * 0.5), Vector2(0.0, body_radius * 0.5), outline, 2.5)

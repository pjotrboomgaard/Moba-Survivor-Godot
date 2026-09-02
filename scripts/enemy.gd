class_name Enemy
extends CharacterBody2D

signal defeated(enemy: Enemy)
signal projectile_fired(origin: Vector2, direction: Vector2, damage: float, speed: float, sprite_name: String)
signal spawn_requested(type_id: String, origin: Vector2, count: int)
signal exploded(origin: Vector2, radius: float, damage: float)
signal arena_hazard_requested(spec: Dictionary)
signal boss_phase_changed(phase: int)

const SEPARATION_RANGE := 62.0
const SEPARATION_STRENGTH := 130.0
const KNOCKBACK_DECAY := 720.0

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
var dash_interval := 0.0
## Lurker-style camouflage: faded while approaching, snaps to fully visible once it commits
## to its windup (see winding_up below) so the ambush still telegraphs fairly.
var stealth_alpha := 1.0
var separation_weight := 1.0

var network_id := 0
var server_authoritative := true
var target: Node2D
var attack_cooldown := 0.0
var network_target_position := Vector2.ZERO
var slow_factor := 1.0
var slow_timer := 0.0
## HoN-style hard root: while > 0 movement stops (attacks/abilities still allowed).
var movement_lock_timer := 0.0
var aura_pulse := 0.0
var summon_timer := 0.0
var speed_ramp := 0.0
var speed_cap := 0.0
var charge_state_timer := 0.0
var charging := false
var winding_up := false
var charge_direction := Vector2.RIGHT
var has_exploded := false
var dash_timer := 0.0
var knockback_velocity := Vector2.ZERO
## Hero "mark" abilities (Track, Sunder, Frostbite Mark, ...): extra damage taken from every
## source while it lasts, on top of the normal per-damage-type resistance.
var vulnerability_bonus := 0.0
var _frozen_visual := false
var vulnerability_timer := 0.0
var boss_phase := 1
var pattern_cooldown := 1.1
var slam_shots_left := 0
var slam_shot_gap := 0.0
var _base_projectile_count := 1

## Terrain-hazard / lava-dunk state. Flying enemies skim over pools; grounded ones take
## the full dunk when a knockback arc drops them inside lava. Scramble slows the crawl
## back out, and `_lava_dunked_this_flight` keeps one knockback from multi-dunking on
## frame boundaries (a shove still re-dunks once they land again).
var hazard_escapes_left := 0
var scrambling_out := 0.0
var _lava_burn_tick := 0.0
var _lava_burn_seconds := 0.0
var _was_knocked := false
var _lava_dunked_this_flight := false
var _arena: Arena = null
const LAVA_DUNK_BURN_DPS := 22.0
const LAVA_DUNK_BURN_DURATION := 4.0
const LAVA_SCRAMBLE_SPEED_MULT := 0.45
const KNOCKBACK_FLIGHT_THRESHOLD := 60.0


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
	speed_cap = movement_speed * 4.0
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
	_base_projectile_count = projectile_count
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
	dash_interval = float(EnemyType.field(type_id, "dash_interval"))
	dash_timer = dash_interval * 0.5
	stealth_alpha = float(EnemyType.field(type_id, "stealth_alpha"))
	separation_weight = float(EnemyType.field(type_id, "separation_weight"))
	summon_timer = summon_interval

	var shape := CircleShape2D.new()
	shape.radius = body_radius
	collision_shape.shape = shape
	# Fliers pass over rocks and walkers. Grounded units still bounce off walls, players and rocks.
	collision_mask = 0 if flying else (1 | 2 | 4 | 16)

	health.max_health = float(EnemyType.field(type_id, "max_health")) * maxf(1.0, health_multiplier)
	health.current_health = health.max_health
	health.is_dead = false
	health.health_changed.emit(health.current_health, health.max_health)
	_apply_biome_combat()
	_apply_sprite()
	queue_redraw()


## Classic mode stays on the plain vector look (see arena.gd's grid background), so it never
## picks up pixel art here either.
func _apply_sprite() -> void:
	if sprite == null or GameRuntime.is_classic():
		return
	sprite.texture = SpriteLibrary.texture_for(type_id)
	var visual_radius := body_radius * (1.55 if is_boss else 1.25)
	sprite.scale = SpriteLibrary.scale_for_radius(sprite.texture, visual_radius)


func refresh_biome_look() -> void:
	_apply_sprite()
	queue_redraw()


func _apply_biome_combat() -> void:
	var mods := EnemyType.biome_multipliers()
	if mods.is_empty():
		return
	movement_speed *= float(mods.get("speed", 1.0))
	if flying:
		movement_speed *= float(mods.get("flying_speed", 1.0))
	contact_damage *= float(mods.get("contact", 1.0))
	attack_interval *= float(mods.get("attack_interval", 1.0))
	attack_distance *= float(mods.get("attack_distance", 1.0))
	preferred_distance *= float(mods.get("preferred_distance", 1.0))
	projectile_speed *= float(mods.get("projectile_speed", 1.0))
	projectile_damage *= float(mods.get("projectile_damage", 1.0))
	explode_radius *= float(mods.get("explode_radius", 1.0))
	gold_value += int(mods.get("gold", 0))
	health.max_health *= float(mods.get("health", 1.0))
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func set_frozen_visual(on: bool) -> void:
	_frozen_visual = on
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate = Color("6ad4ff") if on else Color.WHITE
	modulate = Color(0.72, 0.93, 1.0, 1.0) if on else Color.WHITE
	queue_redraw()


func damage_multiplier_for(damage_type: int) -> float:
	return EnemyType.damage_multiplier(type_id, damage_type)


func _physics_process(delta: float) -> void:
	if stealth_alpha < 1.0:
		modulate.a = 1.0 if winding_up else stealth_alpha
	if not server_authoritative:
		global_position = global_position.lerp(network_target_position, clampf(delta * 12.0, 0.0, 1.0))
		if aura_radius > 0.0 or winding_up or is_boss:
			aura_pulse += delta
			queue_redraw()
		return

	if knockback_velocity.length_squared() > 1.0:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		if knockback_velocity.length() > KNOCKBACK_FLIGHT_THRESHOLD:
			_was_knocked = true
	elif _was_knocked:
		# Just landed from a knockback arc — check if we ended up in lava.
		_was_knocked = false
		_on_knockback_landed()

	_update_lava_burn(delta)
	_update_standing_lava(delta)
	if scrambling_out > 0.0:
		scrambling_out = maxf(0.0, scrambling_out - delta)
		if scrambling_out <= 0.0:
			queue_redraw()

	_update_slow(delta)
	_update_vulnerability(delta)
	if speed_ramp > 0.0:
		movement_speed = minf(speed_cap, movement_speed + speed_ramp * delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	target = _find_nearest_player()
	if target == null:
		velocity = Vector2.ZERO
		return

	if aura_heal_per_second > 0.0 and not is_boss:
		_apply_healing_aura(delta)
	if summon_count > 0 and summon_interval > 0.0:
		_update_summoning(delta)

	if is_boss:
		_process_boss_fight(delta)
		return

	if dash_interval > 0.0 and _process_boss_dash(delta):
		return

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
	var dir := direction_velocity
	if scrambling_out > 0.0:
		dir *= LAVA_SCRAMBLE_SPEED_MULT
	velocity = dir + _separation_offset()
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


## A periodic lunge layered on top of a boss's normal behaviour (melee/ranged), so bosses stay
## threatening instead of being kited forever. Reuses the same windup/charge state as the
## CHARGER behaviour above — safe since no boss actually has that behaviour, so the vars are
## otherwise unused for them. Returns true while it owns this frame's movement.
func _process_boss_dash(delta: float) -> bool:
	if charging:
		charge_state_timer -= delta
		_move(charge_direction * charge_speed * slow_factor)
		if _try_contact_damage() or charge_state_timer <= 0.0:
			charging = false
			dash_timer = dash_interval
		return true

	if winding_up:
		charge_state_timer -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		if charge_state_timer <= 0.0:
			winding_up = false
			charging = true
			charge_state_timer = charge_duration
			charge_direction = global_position.direction_to(target.global_position)
		return true

	dash_timer -= delta
	if dash_timer <= 0.0:
		winding_up = true
		charge_state_timer = charge_windup
		velocity = Vector2.ZERO
		queue_redraw()
		AudioService.play("charge")
		return true
	return false


func _process_boss_fight(delta: float) -> void:
	_update_boss_phase()
	aura_pulse += delta
	queue_redraw()
	if boss_phase >= 2:
		_apply_boss_storm_field(delta)
	if target == null:
		velocity = Vector2.ZERO
		return
	if charging or winding_up:
		_process_boss_dash(delta)
		return
	if slam_shots_left > 0:
		slam_shot_gap -= delta
		_boss_idle_move()
		if slam_shot_gap <= 0.0:
			_emit_player_slam()
			slam_shots_left -= 1
			slam_shot_gap = 0.42 if boss_phase < 3 else 0.32
		return
	pattern_cooldown = maxf(0.0, pattern_cooldown - delta)
	_boss_idle_move()
	if behaviour == EnemyType.Behaviour.RANGED and global_position.distance_to(target.global_position) <= attack_distance:
		_fire_projectile()
	elif behaviour != EnemyType.Behaviour.RANGED and global_position.distance_to(target.global_position) <= attack_distance:
		_attack_target()
	if pattern_cooldown <= 0.0:
		_begin_boss_pattern()


func _update_boss_phase() -> void:
	if health.max_health <= 0.0:
		return
	var pct := health.current_health / health.max_health
	var next := 1
	if pct <= 0.33:
		next = 3
	elif pct <= 0.66:
		next = 2
	if next == boss_phase:
		return
	boss_phase = next
	pattern_cooldown = 0.4
	winding_up = false
	charging = false
	boss_phase_changed.emit(boss_phase)
	AudioService.play("boss_alert")


func _boss_idle_move() -> void:
	if behaviour == EnemyType.Behaviour.RANGED:
		_hold_preferred_distance()
	else:
		_move(global_position.direction_to(target.global_position) * movement_speed * slow_factor)


func _begin_boss_pattern() -> void:
	var pattern := _pick_boss_pattern()
	var strike_damage := contact_damage if contact_damage > 0.0 else projectile_damage * 1.6
	strike_damage *= 0.85 + 0.2 * float(boss_phase)
	match pattern:
		"dash":
			winding_up = true
			charge_state_timer = charge_windup * (0.75 if boss_phase >= 3 else 1.0)
			pattern_cooldown = maxf(1.35, dash_interval / float(boss_phase + 1))
			AudioService.play("charge")
		"slam":
			slam_shots_left = 1 + boss_phase
			slam_shot_gap = 0.0
			pattern_cooldown = 1.85 - 0.18 * float(boss_phase - 1)
		"shockwave":
			_emit_hazard({
				"kind": "ring",
				"origin": global_position,
				"max_radius": 1500.0,
				"width": 86.0 + 10.0 * float(boss_phase),
				"telegraph": 1.05,
				"active": 1.15,
				"damage": strike_damage,
				"color": str(outline_color.to_html(false)),
			})
			pattern_cooldown = 2.15 - 0.22 * float(boss_phase - 1)
		"cross":
			_emit_cross_lines(strike_damage)
			pattern_cooldown = 2.05 - 0.2 * float(boss_phase - 1)
		"storm":
			slam_shots_left = 2 + boss_phase * 2
			slam_shot_gap = 0.0
			_emit_cross_lines(strike_damage)
			pattern_cooldown = 1.7
		"volley":
			projectile_count = _base_projectile_count + boss_phase * 3
			_fire_projectile()
			projectile_count = _base_projectile_count
			pattern_cooldown = 1.25


func _pick_boss_pattern() -> String:
	var pool: Array[String] = ["slam", "slam", "dash"]
	if type_id == "stormcaller":
		pool = ["slam", "slam", "volley"]
	if boss_phase >= 2:
		pool.append("shockwave")
		pool.append("cross")
		pool.append("slam")
	if boss_phase >= 3:
		pool.append("storm")
		pool.append("cross")
		pool.append("slam")
	return pool[randi() % pool.size()]


func _emit_player_slam() -> void:
	if target == null:
		return
	var slam_damage := 10.0 + 2.0 * float(boss_phase)
	var aim := target.global_position
	var count := 4 + boss_phase
	var telegraph := 1.28
	var blast := 72.0 + 4.0 * float(boss_phase)
	# Ring around the player with a gap so standing still is punished but a sidestep
	# through a lane only eats one circle, not a stacked one-shot.
	var ring := blast + 96.0
	_emit_hazard({
		"kind": "circle",
		"origin": aim,
		"radius": blast,
		"telegraph": telegraph,
		"active": 0.28,
		"damage": slam_damage,
		"color": str(fill_color.to_html(false)),
	})
	for index in count:
		var offset := Vector2.RIGHT.rotated(TAU * float(index) / float(count) + float(boss_phase) * 0.27) * ring
		_emit_hazard({
			"kind": "circle",
			"origin": aim + offset,
			"radius": blast,
			"telegraph": telegraph,
			"active": 0.28,
			"damage": slam_damage,
			"color": str(fill_color.to_html(false)),
		})


func _emit_cross_lines(strike_damage: float) -> void:
	var toward := 0.0 if target == null else global_position.direction_to(target.global_position).angle()
	var angles: Array[float] = [toward, toward + PI * 0.5]
	if boss_phase >= 3:
		angles.append(toward + PI * 0.25)
		angles.append(toward - PI * 0.25)
	for angle in angles:
		_emit_hazard({
			"kind": "line",
			"origin": global_position,
			"angle": angle,
			"length": 3600.0,
			"width": 74.0 + 8.0 * float(boss_phase),
			"telegraph": 0.95,
			"active": 0.32,
			"damage": strike_damage,
			"color": str(outline_color.to_html(false)),
		})


func _emit_hazard(spec: Dictionary) -> void:
	arena_hazard_requested.emit(spec)


func _apply_boss_storm_field(delta: float) -> void:
	if aura_radius <= 0.0 or aura_heal_per_second <= 0.0:
		return
	var radius_sq := aura_radius * aura_radius
	var tick := aura_heal_per_second * (0.65 + 0.35 * float(boss_phase)) * delta
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.health.is_dead:
			continue
		if global_position.distance_squared_to(player.global_position) <= radius_sq:
			player.health.take_damage(tick, self)


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
	if is_boss:
		summon_interval = maxf(0.65, summon_interval * 0.94)


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


## HoN Treant Entangle-style root: movement is fully stopped for `duration` seconds.
## Uses the slow machinery with a zero-factor floor so it plays nicely with existing
## slow HUD/redraw code and multi-source stacking (longest duration wins).
func apply_movement_lock(duration: float) -> void:
	if not server_authoritative:
		return
	movement_lock_timer = maxf(movement_lock_timer, duration)
	# Mirror into the slow system at the absolute floor so existing `_move` code paths
	# that multiply by `slow_factor` stop dead. Unlike `apply_slow` this is not clamped
	# to 0.1 — a true HoN root is movement = 0.
	slow_factor = 0.0
	slow_timer = maxf(slow_timer, duration)
	queue_redraw()


func apply_knockback(impulse: Vector2) -> void:
	if not server_authoritative:
		return
	knockback_velocity += impulse
	# Once we're flying fast, the landing check will fire when velocity decays below the
	# threshold — that carries the "dunked" flag back to false so a fresh flight can
	# re-trigger the burst after the scramble's done.
	if knockback_velocity.length() > KNOCKBACK_FLIGHT_THRESHOLD:
		_lava_dunked_this_flight = false


## Knockback arc ended. If the drop point sits inside a lava pool, the enemy takes a big
## burst + burn DoT, gets tagged scrambling_out (slowed crawl) for a few seconds, and
## remains dunk-eligible the next time a shove lands them in a pool.
func _on_knockback_landed() -> void:
	if _arena == null:
		_arena = Arena.arena_root(self)
		if _arena == null:
			return
	if flying:
		return  # Fliers skim over lava; they never dunk.
	var hazard := _arena.hazard_at(global_position)
	if hazard.is_empty():
		return
	if str(hazard.get("type", "")) != "lava":
		return
	if _lava_dunked_this_flight:
		return
	_lava_dunked_this_flight = true
	var burst := float(hazard.get("dunk_burst", 60.0))
	if burst > 0.0:
		health.take_damage(burst, self)
	# Burn DoT ticks regardless of whether the burst killed; kill signal will clean up.
	_lava_burn_seconds = maxf(_lava_burn_seconds, LAVA_DUNK_BURN_DURATION)
	_lava_burn_tick = 0.0
	scrambling_out = maxf(scrambling_out, float(hazard.get("scramble_seconds", 2.5)))
	AudioService.play("hit")
	queue_redraw()  # Scramble tint in _draw picks this up next frame.


## While the burn DoT ticks, chip at health continuously (server-authoritative only).
func _update_lava_burn(delta: float) -> void:
	if _lava_burn_seconds <= 0.0:
		return
	_lava_burn_seconds = maxf(0.0, _lava_burn_seconds - delta)
	_lava_burn_tick += delta
	# Tick every 0.25s so number pops read nicely instead of a constant blur.
	if _lava_burn_tick >= 0.25:
		health.take_damage(LAVA_DUNK_BURN_DPS * _lava_burn_tick, self)
		_lava_burn_tick = 0.0


## Grounded fodder standing in a lava basin take the zone's enemy DoT. Bosses and fliers
## skip the standing tick — bosses own the crater, fliers skim the lip.
func _update_standing_lava(delta: float) -> void:
	if flying or is_boss or health.is_dead:
		return
	if _arena == null:
		_arena = Arena.arena_root(self)
		if _arena == null:
			return
	var hazard := _arena.hazard_at(global_position)
	if hazard.is_empty() or str(hazard.get("type", "")) != "lava":
		return
	var dot := float(hazard.get("enemy_dot", 0.0))
	if dot <= 0.0:
		return
	health.take_damage(dot * delta, self)


func apply_mark(bonus_pct: float, duration: float) -> void:
	if not server_authoritative:
		return
	vulnerability_bonus = maxf(vulnerability_bonus, bonus_pct)
	vulnerability_timer = maxf(vulnerability_timer, duration)


func vulnerability_multiplier() -> float:
	return 1.0 + vulnerability_bonus


func _update_slow(delta: float) -> void:
	if movement_lock_timer > 0.0:
		movement_lock_timer = maxf(0.0, movement_lock_timer - delta)
	if slow_timer <= 0.0:
		return
	slow_timer = maxf(0.0, slow_timer - delta)
	if slow_timer <= 0.0:
		slow_factor = 1.0
		queue_redraw()


func _update_vulnerability(delta: float) -> void:
	if vulnerability_timer <= 0.0:
		return
	vulnerability_timer = maxf(0.0, vulnerability_timer - delta)
	if vulnerability_timer <= 0.0:
		vulnerability_bonus = 0.0


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
	boss_phase = int(state.get("boss_phase", boss_phase))


func snapshot() -> Dictionary:
	return {
		"id": network_id,
		"type_id": type_id,
		"position": global_position,
		"health": health.current_health,
		"max_health": health.max_health,
		"slowed": slow_timer > 0.0,
		"winding": winding_up,
		"boss_phase": boss_phase,
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
	CombatText.spawn(get_parent(), global_position + Vector2(randf_range(-9.0, 9.0), -body_radius - 6.0), amount)


func _on_died() -> void:
	if not server_authoritative:
		return
	_lava_burn_seconds = 0.0
	scrambling_out = 0.0
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
	elif scrambling_out > 0.0:
		fill = fill.lerp(Color("ff7a29"), 0.45)
		outline = outline.lerp(Color("ffd36b"), 0.5)

	if aura_radius > 0.0:
		var pulse := 0.5 + 0.5 * sin(aura_pulse * 3.0)
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, Color(fill_color, 0.12 + 0.1 * pulse), 3.0, true)

	if flying:
		draw_circle(Vector2(0.0, body_radius * 1.05), body_radius * 0.8, Color(0.0, 0.0, 0.0, 0.28))

	if winding_up:
		draw_circle(Vector2.ZERO, body_radius * 1.6, Color(outline_color, 0.3))

	if is_boss:
		var glow := 0.55 + 0.45 * sin(aura_pulse * 4.5)
		draw_arc(Vector2.ZERO, body_radius * 1.35, 0.0, TAU, 56, Color(outline, 0.75 + 0.2 * glow), 5.0, true)
		if boss_phase >= 2:
			draw_arc(Vector2.ZERO, body_radius * 2.15, 0.0, TAU, 56, Color(fill, 0.28 + 0.16 * glow), 8.0, true)
		if boss_phase >= 3:
			draw_circle(Vector2.ZERO, body_radius * 3.1, Color(fill, 0.09 + 0.05 * glow))

	if has_sprite():
		if _frozen_visual:
			sprite.modulate = Color("6ad4ff")
		elif scrambling_out > 0.0:
			# Fresh out of the lava — scorched smoking tint until the crawl-out finishes.
			sprite.modulate = Color("ff9a55")
		elif slow_timer > 0.0:
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

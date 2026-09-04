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
## Phase Cloak wander: no target acquired because every nearby player is cloaked.
const WANDER_TURN_MIN := 1.1
const WANDER_TURN_MAX := 2.4
const WANDER_SPEED_MULT := 0.55
## Boss patterned hazards (slams, cross lines, shockwaves) are tuned for a group that can
## split up and eat a few hazards each. A solo player has nobody to share that burst with,
## so scale it down when it's really one squishy target facing the boss alone.
const SOLO_BOSS_HAZARD_DAMAGE_MULT := 0.6
## pattern_cooldown's declared default (1.1) is the same for every boss regardless of party
## size, so a solo player — who just landed on a fresh wave, possibly still mid-shop or
## walking back from a landmark — gets under a second and a half before the boss's first
## attack pattern fires. A live solo run on the wave-10 boss went from full HP to a
## landmark-triggered near-death inside 9 seconds of wave start, then died a few seconds
## after that save. Give solo an actual opening beat to close distance / get oriented
## before the first pattern; co-op keeps the tighter default since allies can split the
## opening aggro.
const BOSS_INTRO_COOLDOWN_SOLO := 3.5

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
var team_id := ""
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
## Blink-attacker (cinderling/ripcurrent) — see EnemyType's teleport_interval field.
var teleport_interval := 0.0
var teleport_range := 140.0
var _teleport_timer := 0.0
## Grow-in-place (iceball/sparkbot) — see EnemyType's growth_aggro_seconds field.
var growth_aggro_seconds := 0.0
var growth_max_mult := 1.0
var _growth_age := 0.0
var _growth_base_radius := 0.0
var _growth_base_health := 0.0
var _growth_base_contact_damage := 0.0
var _growth_base_captured := false
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
## Venom DoT (Thorn Poison Spray). Distinct from slow-blue / freeze-cyan.
var poison_timer := 0.0
var poison_dps := 0.0
var _poison_source: Node = null
var _poison_tick_accum := 0.0
## Electrocute overlay while caught in Energy Field (or similar shock slows).
var shocked_timer := 0.0
const POISON_TICK := 0.4
var wander_timer := 0.0
var wander_direction := Vector2.ZERO
var aura_pulse := 0.0
var summon_timer := 0.0
var speed_ramp := 0.0
var speed_cap := 0.0
var charge_state_timer := 0.0
var charging := false
var winding_up := false
var charge_direction := Vector2.RIGHT
var has_exploded := false
## Separate throttle on the ice boss's "ice_shift" pattern — see _pick_boss_pattern.
var _ice_shift_cooldown := 0.0
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
	teleport_interval = float(EnemyType.field(type_id, "teleport_interval"))
	teleport_range = float(EnemyType.field(type_id, "teleport_range"))
	_teleport_timer = teleport_interval * 0.5
	growth_aggro_seconds = float(EnemyType.field(type_id, "growth_aggro_seconds"))
	growth_max_mult = float(EnemyType.field(type_id, "growth_max_mult"))
	_growth_age = 0.0
	_growth_base_captured = false
	if is_boss and _solo_boss_fight():
		pattern_cooldown = BOSS_INTRO_COOLDOWN_SOLO
	stealth_alpha = float(EnemyType.field(type_id, "stealth_alpha"))
	if GameRuntime.uses_biomes() and GameRuntime.biome_id == 2 and not flying:
		if type_id == "lurker" or type_id == "stalker":
			stealth_alpha = 0.22
		elif type_id == "grunt" or type_id == "swarmling":
			stealth_alpha = 0.35
	separation_weight = float(EnemyType.field(type_id, "separation_weight"))
	summon_timer = summon_interval

	var shape := CircleShape2D.new()
	shape.radius = body_radius
	collision_shape.shape = shape
	# Fliers pass over rocks, walkers and the void. Grounded units still bounce off walls,
	# players, rocks, and the void (split onto its own layer — see Arena.VOID_LAYER).
	# Bosses skip rocks + the void too: a big-radius body wedging against a rock or
	# failing to cross a narrow ice-floe land bridge mid-fight reads as a bug, not
	# difficulty, so they only ever respect the outer walls and other bodies.
	if flying:
		collision_mask = 0
	elif is_boss:
		collision_mask = 1 | 2 | 4
	else:
		collision_mask = 1 | 2 | 4 | 16 | Arena.VOID_LAYER

	health.max_health = float(EnemyType.field(type_id, "max_health")) * maxf(1.0, health_multiplier)
	health.current_health = health.max_health
	health.is_dead = false
	health.health_changed.emit(health.current_health, health.max_health)
	_apply_biome_combat()
	_apply_sprite()
	queue_redraw()


func apply_wave_growth(wave: int) -> void:
	if is_boss:
		return
	var grow := clampf(1.0 + 0.016 * float(maxi(0, wave - 1)), 1.0, 1.32)
	if is_equal_approx(grow, 1.0):
		return
	body_radius *= grow
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = body_radius
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
	_apply_boss_biome_theme()
	_apply_sprite()
	queue_redraw()


## Boss body sprites already reskin per biome (tw_<biome>_ravager.png etc. — see
## SpriteLibrary._skinned_name), but fill_color/outline_color are still the boss's base
## EnemyType palette, and every attack telegraph (slam rings, cross-line lasers,
## shockwaves — see _emit_player_slam/_emit_cross_lines/_emit_hazard) is drawn from those
## two colors. So the reskinned body still threw the exact same-colored attack in every
## world. Retint to the world's palette so a volcano boss throws fire, an ice boss frost.
const BOSS_BIOME_PALETTE := {
	0: {"fill": "8fd66b", "outline": "e8ffd0"},
	1: {"fill": "ff6a2e", "outline": "ffd08a"},
	2: {"fill": "5fd0ff", "outline": "eafcff"},
	3: {"fill": "ffcf4a", "outline": "fff2c0"},
	4: {"fill": "3ad0c0", "outline": "d0fff5"},
}


func _apply_boss_biome_theme() -> void:
	if not is_boss or not GameRuntime.uses_biomes() or GameRuntime.is_classic():
		return
	var palette: Dictionary = BOSS_BIOME_PALETTE.get(GameRuntime.biome_id, {})
	if palette.is_empty():
		return
	fill_color = Color(str(palette.get("fill", fill_color.to_html(false))))
	outline_color = Color(str(palette.get("outline", outline_color.to_html(false))))


func _apply_biome_combat() -> void:
	_apply_boss_biome_theme()
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
	_update_poison(delta)
	_update_shock(delta)
	_update_vulnerability(delta)
	if speed_ramp > 0.0:
		movement_speed = minf(speed_cap, movement_speed + speed_ramp * delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if growth_aggro_seconds > 0.0:
		_update_growth(delta)
		if _is_still_growing():
			# Not a threat yet — wanders like an unaggroed target instead of chasing, so
			# the player can choose to kill it small or let it grow into a real problem.
			_process_wander(delta)
			return
	target = _find_nearest_player()
	if target == null:
		if _any_player_cloaked():
			_process_wander(delta)
		else:
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

	if teleport_interval > 0.0 and _process_teleport(delta):
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


## Blink to a random spot teleport_range out from the target instead of walking there.
## Returns true the frame it actually blinks (caller skips normal movement that frame).
func _process_teleport(delta: float) -> bool:
	_teleport_timer -= delta
	if _teleport_timer > 0.0:
		return false
	_teleport_timer = teleport_interval
	if target == null:
		return false
	var dest := target.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * teleport_range
	if _arena == null:
		_arena = Arena.arena_root(self)
	if _arena != null:
		dest = _arena.free_position_near(dest, body_radius + 4.0)
	global_position = dest
	queue_redraw()
	return true


## Ramps body_radius/max_health/contact_damage from 1x to growth_max_mult over
## growth_aggro_seconds, preserving the current HP fraction so a mid-growth hit still
## matters instead of being topped off by the next tick's max_health bump.
func _update_growth(delta: float) -> void:
	if not _growth_base_captured:
		_growth_base_radius = body_radius
		_growth_base_health = health.max_health
		_growth_base_contact_damage = contact_damage
		_growth_base_captured = true
	if _growth_age >= growth_aggro_seconds:
		return
	_growth_age = minf(growth_aggro_seconds, _growth_age + delta)
	var mult := lerpf(1.0, growth_max_mult, _growth_age / growth_aggro_seconds)
	var hp_frac := health.current_health / maxf(1.0, health.max_health)
	body_radius = _growth_base_radius * mult
	contact_damage = _growth_base_contact_damage * mult
	health.max_health = _growth_base_health * mult
	health.current_health = clampf(health.max_health * hp_frac, 1.0, health.max_health)
	health.health_changed.emit(health.current_health, health.max_health)
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = body_radius
	_apply_sprite()
	queue_redraw()


func _is_still_growing() -> bool:
	return _growth_age < growth_aggro_seconds


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


func _process_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0 or wander_direction == Vector2.ZERO:
		wander_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		wander_timer = randf_range(WANDER_TURN_MIN, WANDER_TURN_MAX)
	_move(wander_direction * movement_speed * WANDER_SPEED_MULT * slow_factor)


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
			AudioService.play("dash")
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
	_ice_shift_cooldown = maxf(0.0, _ice_shift_cooldown - delta)
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


## True only for real solo play (no CPU-filled allies, exactly one live player) — mirrors the
## solo detection main.gd already uses to scale enemy contact damage, but here it's read
## straight off the scene tree since Enemy has no wave_director reference.
func _solo_boss_fight() -> bool:
	if not is_boss or GameRuntime.fill_cpu_allies:
		return false
	return get_tree().get_nodes_in_group("players").size() <= 1


func _begin_boss_pattern() -> void:
	var pattern := _pick_boss_pattern()
	var strike_damage := contact_damage if contact_damage > 0.0 else projectile_damage * 1.6
	strike_damage *= 0.85 + 0.2 * float(boss_phase)
	if _solo_boss_fight():
		strike_damage *= SOLO_BOSS_HAZARD_DAMAGE_MULT
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
			# Storm already stacks a full slam volley on top of cross lines, so it doesn't
			# also need more slam shots than the plain "slam" pattern gets — doubling both
			# axes at once was stacking too many simultaneous hazards for one solo target
			# to have any dodge lane through.
			slam_shots_left = 1 + boss_phase
			slam_shot_gap = 0.0
			_emit_cross_lines(strike_damage)
			pattern_cooldown = 1.7
		"volley":
			projectile_count = _base_projectile_count + boss_phase * 3
			_fire_projectile()
			projectile_count = _base_projectile_count
			pattern_cooldown = 1.25
		"flame_bloom":
			_emit_flame_bloom(strike_damage)
			pattern_cooldown = 2.0 - 0.15 * float(boss_phase - 1)
		"ice_shift":
			_emit_ice_shift(strike_damage)
			pattern_cooldown = 1.3 - 0.1 * float(boss_phase - 1)
			# Own cooldown on top of pattern_cooldown — the pool gate in _pick_boss_pattern
			# already skips offering "ice_shift" while this is up, so the boss reliably
			# closes back in and fights normally between blinks instead of chain-teleporting.
			_ice_shift_cooldown = 5.5


## Both boss ids (ravager/stormcaller) rotate through every biome by wave number alone
## (see EnemyType.boss_for_wave) — biome_id, not type_id, is what should color the fight,
## so a wave-10 boss on volcano throws fire and the same boss on ice moves like ice.
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
	match GameRuntime.biome_id:
		1:
			# Fire: expanding bloom hazards instead of the plain instant-size slam.
			pool.append("flame_bloom")
			pool.append("flame_bloom")
			if boss_phase >= 2:
				pool.append("flame_bloom")
		2:
			# Ice: the boss itself keeps relocating instead of standing and slamming — but
			# only when _ice_shift_cooldown has actually elapsed (see _emit_ice_shift). A
			# live test got stuck on a wave-10 boss for 100+ seconds because this could be
			# picked back-to-back every ~1.2s pattern cycle, teleporting far enough away
			# each time that neither the bot nor a real player could ever close the gap.
			if _ice_shift_cooldown <= 0.0:
				pool.append("ice_shift")
	return pool[randi() % pool.size()]


func _emit_player_slam() -> void:
	if target == null:
		return
	var slam_damage := 10.0 + 2.0 * float(boss_phase)
	if _solo_boss_fight():
		slam_damage *= SOLO_BOSS_HAZARD_DAMAGE_MULT
	var aim := target.global_position
	var count := mini(4 + boss_phase, 6)
	var telegraph := 1.42
	var blast := 62.0 + 3.0 * float(boss_phase)
	# Keep a walkable lane between every pair of circles (and between the center
	# slam and the ring) so the dodge path reads at a glance, not as a packed blob.
	var lane := 90.0
	var ring := blast * 2.0 + lane
	var spread := sin(PI / float(maxi(count, 2)))
	if spread > 0.08:
		ring = maxf(ring, (blast + lane * 0.5) / spread)
	_emit_hazard({
		"kind": "circle",
		"origin": aim,
		"radius": blast,
		"telegraph": telegraph,
		"active": 0.28,
		"damage": slam_damage,
		"color": str(fill_color.to_html(false)),
		"sfx": "explosion",
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
			"length": 7200.0,
			"width": 74.0 + 8.0 * float(boss_phase),
			"telegraph": 0.95,
			"active": 0.32,
			"damage": strike_damage,
			"color": str(outline_color.to_html(false)),
		})


## Volcano boss signature: one or two circles that start small (barely a warning dot) and
## visibly inflate to a big "combust" radius across the active window instead of the plain
## slam's instant full size — a real dodge read (run before it finishes swelling) instead
## of just another same-sized circle.
func _emit_flame_bloom(strike_damage: float) -> void:
	if target == null:
		return
	# A live solo run lost 1.0 -> 0.36 HP over ~26s of steady attrition to a fire boss —
	# the 1.35x "combust" multiplier was just running hot on top of strike_damage already
	# being phase/solo-scaled. Trimmed, and phase 2+'s second bloom no longer stacks its
	# own full multiplier on top of the count itself effectively doubling total output.
	var count := 2 if boss_phase >= 2 else 1
	for index in count:
		var aim := target.global_position
		if index > 0:
			aim += Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 160.0
		_emit_hazard({
			"kind": "circle",
			"origin": aim,
			"radius": 220.0 + 26.0 * float(boss_phase),
			"grow_from": 36.0,
			"telegraph": 0.35,
			"active": 1.7,
			"damage": strike_damage * (1.1 if count == 1 else 0.75),
			"color": str(fill_color.to_html(false)),
			"sfx": "explosion",
		})


## Ice boss signature: blinks to a new spot near the target instead of standing and slamming
## in place, then cracks a frost ring outward from the arrival point — the fight itself
## keeps relocating instead of the player always knowing where the next hit lands from.
func _emit_ice_shift(strike_damage: float) -> void:
	if target == null:
		return
	# Close enough that the player is still in the fight after the blink, not a full sprint
	# away — the point is unpredictable positioning, not making the boss unreachable.
	var dest := target.global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(130.0, 210.0)
	if _arena == null:
		_arena = Arena.arena_root(self)
	if _arena != null:
		dest = _arena.free_position_near(dest, body_radius + 8.0)
	global_position = dest
	queue_redraw()
	_emit_hazard({
		"kind": "ring",
		"origin": global_position,
		"max_radius": 240.0 + 20.0 * float(boss_phase),
		"width": 44.0,
		"telegraph": 0.3,
		"active": 0.45,
		"damage": strike_damage * 0.85,
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
			AudioService.play("dash")
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
	# _begin_boss_pattern's strike/slam damage already gets SOLO_BOSS_HAZARD_DAMAGE_MULT, but
	# this plain per-attack_interval volley didn't — for a ranged boss like Stormcaller (7
	# projectiles every 0.9s) that's the actual continuous damage source, not the patterns,
	# and a live solo run died to it in a near-identical ~17s window regardless of the
	# pattern-side fix. Same reduction, same reasoning: nobody to split this aggro with solo.
	var dmg := projectile_damage
	if _solo_boss_fight():
		dmg *= SOLO_BOSS_HAZARD_DAMAGE_MULT
	var base_direction := global_position.direction_to(target.global_position)
	var spread := deg_to_rad(9.0)
	var start := -spread * float(projectile_count - 1) * 0.5
	for index in maxi(1, projectile_count):
		var direction := base_direction.rotated(start + spread * float(index))
		projectile_fired.emit(global_position, direction, dmg, projectile_speed, projectile_sprite)


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


func apply_poison(dps: float, duration: float, source: Node = null) -> void:
	if not server_authoritative:
		return
	poison_dps = maxf(poison_dps, maxf(dps, 0.0))
	poison_timer = maxf(poison_timer, duration)
	if source != null:
		_poison_source = source
	queue_redraw()


func apply_shock(duration: float) -> void:
	if not server_authoritative:
		return
	shocked_timer = maxf(shocked_timer, duration)
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


## Snap every timed status this enemy is carrying back to "expired" right now, instead of
## letting them keep counting down. Needed after a freeze_time landmark: it calls
## apply_movement_lock/apply_mark for `duration` seconds and then disables this enemy's
## _process/_physics_process for that same `duration` — but slow_timer/movement_lock_timer/
## vulnerability_timer only ever tick down inside _physics_process (_update_slow /
## _update_vulnerability), so while processing is off they sit frozen at their starting
## value instead of expiring. Re-enabling processing afterward then makes them count down
## a *second* full duration before movement actually frees up — silently doubling how long
## the enemy stays rooted past the landmark's advertised freeze length. Call this right
## after processing resumes so the root/mark end exactly when the freeze visually ends.
func clear_movement_lock() -> void:
	movement_lock_timer = 0.0
	slow_timer = 0.0
	slow_factor = 1.0
	vulnerability_timer = 0.0
	vulnerability_bonus = 0.0
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
	elif shocked_timer > 0.0:
		queue_redraw()


func _update_poison(delta: float) -> void:
	if poison_timer <= 0.0:
		return
	poison_timer = maxf(0.0, poison_timer - delta)
	if server_authoritative:
		_poison_tick_accum += delta
		while _poison_tick_accum >= POISON_TICK:
			_poison_tick_accum -= POISON_TICK
			if health != null and not health.is_dead:
				health.take_damage(poison_dps * POISON_TICK, _poison_source)
	if poison_timer <= 0.0:
		poison_dps = 0.0
		_poison_tick_accum = 0.0
		_poison_source = null
	queue_redraw()


func _update_shock(delta: float) -> void:
	if shocked_timer <= 0.0:
		return
	shocked_timer = maxf(0.0, shocked_timer - delta)
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
	var next_poisoned: bool = state.get("poisoned", false)
	if (poison_timer > 0.0) != next_poisoned:
		queue_redraw()
	poison_timer = 1.0 if next_poisoned else 0.0
	var next_shocked: bool = state.get("shocked", false)
	if (shocked_timer > 0.0) != next_shocked:
		queue_redraw()
	shocked_timer = 1.0 if next_shocked else 0.0
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
		"poisoned": poison_timer > 0.0,
		"shocked": shocked_timer > 0.0,
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
		if player.is_phase_cloaked():
			continue
		var weight := 1.0 if taunt_immune else player.taunt_weight
		var score: float = global_position.distance_squared_to(player.global_position) * weight
		if score < best_score:
			nearest = player
			best_score = score
	return nearest


## True when every player in range is phase-cloaked, so a null target should wander
## instead of freezing in place (see apply_phase_cloak / _process_wander).
func _any_player_cloaked() -> bool:
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Player and (candidate as Player).is_phase_cloaked():
			return true
	return false


func _attack_target() -> void:
	if attack_cooldown > 0.0 or target == null or contact_damage <= 0.0:
		return
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	if target_health != null:
		# Same SOLO_BOSS_HAZARD_DAMAGE_MULT reasoning as _fire_projectile(): a melee boss's
		# plain per-attack_interval hit is a continuous damage source the pattern-only
		# reduction never touched.
		var dmg := contact_damage
		if _solo_boss_fight():
			dmg *= SOLO_BOSS_HAZARD_DAMAGE_MULT
		target_health.take_damage(dmg, self)
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
	if poison_timer > 0.0:
		fill = fill.lerp(Color("5ad43a"), 0.55)
		outline = outline.lerp(Color("c8ff6a"), 0.7)
	elif shocked_timer > 0.0 or slow_timer > 0.0:
		var shock_pulse := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.018)
		fill = fill.lerp(Color("3a9dff"), 0.55 + 0.2 * shock_pulse)
		outline = outline.lerp(Color("d3ecff"), 0.75)
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
		elif poison_timer > 0.0:
			sprite.modulate = Color("6ee05c")
		elif scrambling_out > 0.0:
			# Fresh out of the lava — scorched smoking tint until the crawl-out finishes.
			sprite.modulate = Color("ff9a55")
		elif shocked_timer > 0.0:
			var flicker := 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.04)
			sprite.modulate = Color("5ab8ff") * Color(flicker, flicker, 1.0, 1.0)
		elif slow_timer > 0.0:
			sprite.modulate = Color("6fbfff")
		else:
			sprite.modulate = Color.WHITE
		_draw_status_overlays()
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
	_draw_status_overlays()


func _draw_status_overlays() -> void:
	var t := float(Time.get_ticks_msec()) * 0.001
	if poison_timer > 0.0:
		var venom := Color(Color("7dff3a"), 0.45)
		var drip := Color(Color("c8ff6a"), 0.7)
		for i in 4:
			var a := TAU * float(i) / 4.0 + t * 1.4
			var cloud := Vector2.from_angle(a) * (body_radius * 0.85)
			draw_circle(cloud + Vector2(0.0, sin(t * 5.0 + float(i)) * 3.0), 4.5, venom)
			draw_line(cloud, cloud + Vector2(0.0, 7.0 + 4.0 * sin(t * 6.0 + float(i))), drip, 1.4)
	if shocked_timer > 0.0 or (slow_timer > 0.0 and shocked_timer > 0.0):
		var spark := Color(Color("d3f6ff"), 0.85)
		var bolt := Color(Color("5ab8ff"), 0.75)
		for i in 5:
			var a := TAU * float(i) / 5.0 + t * 11.0
			var jag := 0.7 + 0.3 * sin(t * 28.0 + float(i) * 3.1)
			var inner := Vector2.from_angle(a) * (body_radius * 0.35)
			var outer := Vector2.from_angle(a + 0.18 * sin(t * 20.0 + float(i))) * (body_radius * (0.95 + 0.25 * jag))
			draw_line(inner, outer, spark if i % 2 == 0 else bolt, 1.6)
	elif slow_timer > 0.0:
		var rim := Color(Color("7ec8ff"), 0.45)
		draw_arc(Vector2.ZERO, body_radius * 1.15, 0.0, TAU, 20, rim, 2.0, true)

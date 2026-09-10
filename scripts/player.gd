class_name Player
extends CharacterBody2D

const WorldClock := preload("res://scripts/world_clock.gd")
const UpgradeCatalog := preload("res://scripts/upgrade_catalog.gd")

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

const CompanionDroneScript := preload("res://scripts/companion_drone.gd")
const SPAWN_SHIELD_SCRIPT := preload("res://scripts/spawn_shield_fx.gd")
const BODY_RADIUS := 18.0
const PLAYER_KNOCKBACK_DECAY := 1650.0
const FACING_CLASS_IDS := ["arclight", "bulwark", "warden", "cinder", "pyra", "slag", "ember", "thorn", "willow", "stump", "sage", "volt", "nebula", "astral", "rime"]
## Global in-game hero-sprite scale boost (Part 1: heroes felt ~25% small). HUD/menu untouched.
const HERO_SCALE_BOOST := 1.25
const WORLD_LAYER := 1
const ENEMY_LAYER := 4
const OBSTACLE_LAYER := 16

@onready var health: HealthComponent = $HealthComponent
@onready var world_health_bar: WorldHealthBar = $WorldHealthBar
@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite
@onready var shop_hint: Node2D = get_node_or_null("ShopHint")

## Fog-of-war vision radius for the local player's RTS veil -- see FogOfWar.
const VISION_RADIUS := 700.0

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
## Hold-to-charge for the RMB secondary: how long RMB has been held this windup.
## Releasing at full charge boosts damage/area + unlocks the secondary effect.
var secondary_charge := 0.0
## Seconds of hold needed to reach a fully-boosted secondary.
const SECONDARY_CHARGE_MAX := 1.4
## Maximum damage multiplier at full charge (1.0 tap -> 3.0 fully charged).
## Base is strong by default; holding 3x longer gives 3x damage.
const SECONDARY_CHARGE_DAMAGE_MULT_MAX := 3.0
## Maximum radius/area multiplier at full charge (1.0 tap -> 3.0 fully charged).
const SECONDARY_CHARGE_RADIUS_MULT_MAX := 3.0
var command_secondary := false
var _secondary_was_held := false
var _drawing_wall := false
var _wall_points := PackedVector2Array()
var _wall_draw_age := 0.0

var damage_dealt_multiplier := 1.0
var buff_timer := 0.0

var owner_peer_id := 1
## Rift Clash team of this hero; empty in co-op. Synced via snapshot.
var team_id := ""
var simulation_mode := SimulationMode.OFFLINE
var is_local_player := true
var _arena: Arena = null
var active := true
## Freezes movement/abilities without touching `active` (the downed/dead state) — used for
## the mission-warp beat in main.gd so the player stands still behind the black screen
## instead of wandering off while the arena rebuilds underneath them.
var movement_locked := false
## Base camera zoom captured on _ready so boss-form revert can restore the
## resolution-appropriate zoom (set on the Camera2D in the scene) instead of
## a hardcoded value.
var _base_camera_zoom := Vector2.ONE
var facing_direction := Vector2.RIGHT
var aim_world_position := Vector2.RIGHT * 100.0
var current_xp := 0
var level := 1
## First level is a handful of grunt orbs; later levels stretch so wave 20 still has picks left.
const BASE_XP_REQUIRED := 80
const XP_GROWTH := 1.17
var xp_required := BASE_XP_REQUIRED
var gold := 0
var gold_multiplier := 1.0
var taken_upgrades: Array[String] = []
## Maps level (int) → list of upgrade ids taken at that level. Used by the HUD to
## display the build progression at the bottom of the screen.
var level_upgrades: Dictionary = {}
var extra_shots := 0
var extra_projectiles := 0
var double_blast_chance := 0.0
var crit_chance := 0.0
var crit_mult := 2.0
var xp_gain_mult := 1.0
var pulse_interval := 0.0
var pulse_timer := 0.0
var pulse_radius := 160.0
var last_death_gold_lost := 0
var shop_stacks: Dictionary = {}
var _tobor_walk_phase := 0.0
var _tobor_facing := "front"
## Walk-cycle frame (0 = stand, 1..3 = stepping) shared by every hero sprite.
var _walk_cycle_phase := 0
var _hover_phase := 0.0
var hovering := false
## True while an ability is armed and waiting for a confirm press/click — see TARGETED_ABILITIES.
var aim_indicator_visible := false
var _shake_time := 0.0
## Synergy bonuses (extra stats granted when a synergy pair is completed).
var _companion_damage_bonus := 0.0
var _kill_heal_amount := 0.0
var _move_heal_per_second := 0.0
## Synergy keys already granted (each synergy fires only once).
var _granted_synergies: Dictionary = {}
## Boss-takeover state (FFA & solo): when this player defeats the wave boss, they
## temporarily "become the boss" — boosted speed/damage, boss-form attacks on
## hotkeys, and (FFA) creeps won't target them. They revert when killed by a
## rival (FFA) or after the timer / on death (solo).
var in_boss_form := false
var boss_form_type_id := ""
var boss_form_timer := 0.0
var boss_form_hero_kills := 0
## Boss-form ability cooldowns (independent from the hero kit). Mirrors the
## boss pattern pacing so the taken-over hero feels like the boss.
var _boss_slam_cd := 0.0
var _boss_cross_cd := 0.0
var _boss_volley_cd := 0.0
const BOSS_FORM_DURATION := 45.0
const BOSS_FORM_SPEED_MULT := 1.45
const BOSS_FORM_DAMAGE_MULT := 1.8
const BOSS_FORM_MAX_HEALTH_BONUS := 120.0
const BOSS_FORM_CAMERA_ZOOM := 0.5
const BOSS_FORM_HERO_KILLS_REQUIRED := 3
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
## Hoverboard: C-jump over rocks and lava. Gaps are walkable for everyone (5%/s burn).
var water_walk := false
var board_jump := false
var grab_radius := 0.0
var _jump_cooldown := 0.0
var _jump_t := -1.0
var _energy_fields: Array[Dictionary] = []
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
## Self-test driver latch: once it injects a slot press, OFFLINE input stops overriding the
## externally-set command slots so scripted casts land. Cleared by `clear_external_command()`.
var _external_command_latched := false

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
## Source of truth for permanent damage-taken changes (class base + "plating" stacks).
## health.damage_taken_multiplier = base_damage_taken_multiplier * _ability_damage_taken_factor
## always — keeping these separate instead of mutating health.damage_taken_multiplier
## directly from both a permanent item AND a temporary ability buff at the same time,
## which could corrupt it toward near-zero (effectively unkillable) if a "plating" pickup
## landed while a damage_taken_mult ability buff was active, since clearing that buff would
## then divide out the wrong (already-modified-by-plating) value instead of the pre-buff one.
var base_damage_taken_multiplier := 1.0
## Phase Cloak landmark buff: while > 0, Enemy._find_nearest_player() skips this
## player when picking a target.
var phase_cloak_timer := 0.0
var crowd_slow_factor := 1.0
var crowd_slow_timer := 0.0
var _secondary_move_mult := 1.0
var _secondary_move_timer := 0.0
var _secondary_dr_mult := 1.0
var _secondary_dr_timer := 0.0
var _secondary_invuln_timer := 0.0


var _normal_collision_mask := 0
var cpu_lock_target: Node2D
var cpu_lock_timer := 0.0
var cpu_smoothed_move := Vector2.ZERO
var _ffa_think_timer := 0.0
var _ffa_last_think := {}
var hero_kills := 0
var creep_kills := 0
var pvp_invuln_timer := 0.0
var knockback_velocity := Vector2.ZERO
var ffa_respawn_left := 0.0
var _spawn_shield: Node2D
var _respawn_label: Label
var attack_charge := 0.0
var _shot_charge := 0.0
var _charge_lock_impact := Vector2.ZERO
var _charge_firing := false
var _attack_held_prev := false
var charge_rate_mult := 1.0


func _ready() -> void:
	if camera != null:
		_base_camera_zoom = camera.zoom
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	world_health_bar.bind_health(health)
	xp_changed.emit(current_xp, xp_required, level)
	_normal_collision_mask = collision_mask
	set_shop_hint_visible(false)
	_ensure_spawn_shield()
	_ensure_respawn_label()
	queue_redraw()


func set_shop_hint_visible(show: bool) -> void:
	if shop_hint == null:
		return
	shop_hint.visible = show and is_local_player
	var arrow := shop_hint.get_node_or_null("Arrow")
	if arrow != null:
		arrow.visible = false


func _process(_delta: float) -> void:
	if camera != null and _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - _delta)
		if _shake_time <= 0.0:
			camera.offset = Vector2.ZERO
		else:
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amp
	_refresh_respawn_label()
	_tick_boss_form(_delta)
	if shop_hint != null and shop_hint.visible:
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
	# Base attack is twice as quick by default (attack_interval halved). This is
	# the single authoritative point: every hero inherits it, and the per-class
	# attack_interval values stay as their base for stat/ability scaling.
	attack_interval = class_data.attack_interval * 0.5
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
	apply_team_identity()
	base_damage_taken_multiplier = class_data.damage_taken_multiplier
	health.damage_taken_multiplier = base_damage_taken_multiplier
	health.hit_invulnerability_window = 0.15
	health.max_health = class_data.max_health
	if GameRuntime.is_ffa():
		health.max_health *= GameRuntime.FFA_HEALTH_MULT
	health.current_health = health.max_health
	health.is_dead = false
	health.health_changed.emit(health.current_health, health.max_health)
	_apply_kit_abilities()
	_apply_sprite()
	queue_redraw()


## ---- Boss-form (takeover) state -----------------------------------------------------------

func is_in_boss_form() -> bool:
	return in_boss_form


## Grant boss-form: boosted stats, boss-tinted sprite, creeps won't target us (FFA).
## Called by main.gd when this player defeats the wave boss.
func grant_boss_form(boss_type_id: String) -> void:
	if in_boss_form:
		# Refresh timer, don't stack.
		boss_form_timer = BOSS_FORM_DURATION
		return
	in_boss_form = true
	boss_form_type_id = boss_type_id
	boss_form_timer = BOSS_FORM_DURATION
	boss_form_hero_kills = 0
	# Stat boosts.
	movement_speed *= BOSS_FORM_SPEED_MULT
	weapon_damage *= BOSS_FORM_DAMAGE_MULT
	_add_max_health(BOSS_FORM_MAX_HEALTH_BONUS)
	# Visual: tint toward the boss colour, zoom out camera to see more of the arena
	# so the player can unleash boss-scale attacks.
	if sprite != null:
		sprite.modulate = Color(1.4, 0.6, 0.4)
		# Boss-form pulse ring.
		if world_health_bar != null:
			world_health_bar.set_identity_color(Color("ff4444"))
	if camera != null and is_local_player:
		camera.zoom = Vector2(BOSS_FORM_CAMERA_ZOOM, BOSS_FORM_CAMERA_ZOOM)
	queue_redraw()


## Revert boss-form: restore original stats, sprite colour.
func revert_boss_form() -> void:
	if not in_boss_form:
		return
	in_boss_form = false
	boss_form_timer = 0.0
	boss_form_hero_kills = 0
	# Restore base stats (re-apply class data for the core stats).
	var class_data := PlayerClass.by_id(class_id)
	movement_speed = class_data.movement_speed
	weapon_damage = class_data.weapon_damage
	attack_interval = class_data.attack_interval * 0.5
	# Note: max_health is NOT reverted (permanent gain), just noted.
	if sprite != null:
		sprite.modulate = Color.WHITE
		if world_health_bar != null:
			world_health_bar.set_identity_color(Color(str(class_data.get("health_bar_color", class_data.accent_color))))
	# Restore camera zoom to the resolution-appropriate base zoom (set on the
	# Camera2D in the scene), not a hardcoded 1.0 which is too close at the
	# new 2880x1800 default.
	if camera != null and is_local_player:
		camera.zoom = _base_camera_zoom
	boss_form_type_id = ""
	queue_redraw()


## Tick the boss-form timer and its three attack cooldowns (called from _process).
func _tick_boss_form(delta: float) -> void:
	if not in_boss_form:
		return
	boss_form_timer -= delta
	_boss_slam_cd = maxf(0.0, _boss_slam_cd - delta)
	_boss_cross_cd = maxf(0.0, _boss_cross_cd - delta)
	_boss_volley_cd = maxf(0.0, _boss_volley_cd - delta)
	if boss_form_timer <= 0.0:
		revert_boss_form()


## Boss-form ability A (slot Q): Ring Slam — undodgeable shockwave circles around
## the player, mirroring the boss's "slam" pattern. Cooldown mirrors the boss.
func _boss_form_slam() -> void:
	if not in_boss_form or _boss_slam_cd > 0.0:
		return
	_boss_slam_cd = 3.0
	var arena_root := get_parent()
	if arena_root == null:
		return
	var dmg := weapon_damage * 2.5
	var radius := 90.0 + 8.0 * _boss_form_phase()
	var ring := radius * 2.0 + 90.0
	var count := 4
	var offset_dir := randf() * TAU
	for index in count:
		var offset := Vector2.RIGHT.rotated(TAU * float(index) / float(count) + offset_dir) * ring
		_emit_boss_form_hazard("circle", global_position + offset, radius, 1.1, 0.28, dmg, Color("ff5533"))
	_emit_boss_form_hazard("circle", global_position, radius, 0.9, 0.28, dmg, Color("ff5533"))


## Boss-form ability B (slot E): Cross Lines — directional hazard lines that sweep
## through the arena, mirroring the boss's "cross" pattern.
func _boss_form_cross() -> void:
	if not in_boss_form or _boss_cross_cd > 0.0:
		return
	_boss_cross_cd = 2.6
	var dmg := weapon_damage * 2.0
	var toward := facing_direction.angle()
	var angles: Array[float] = [toward, toward + PI * 0.5]
	for angle in angles:
		var dir := Vector2.RIGHT.rotated(angle)
		_emit_boss_form_hazard_line(dir, 1.1, 0.28, dmg, Color("ffaa33"))


## Boss-form ability C (slot R): Volley — fires a ring of projectiles in many
## directions, mirroring the boss's "volley" pattern.
func _boss_form_volley() -> void:
	if not in_boss_form or _boss_volley_cd > 0.0:
		return
	_boss_volley_cd = 3.5
	var arena_root := get_parent()
	if arena_root == null or not arena_root.has_method("spawn_player_projectile"):
		return
	var count := 10 + 3 * _boss_form_phase()
	var offset_dir := randf() * TAU
	for index in count:
		var dir := Vector2.RIGHT.rotated(TAU * float(index) / float(count) + offset_dir)
		arena_root.call("spawn_player_projectile", global_position, dir, self)


func _is_slot_held(slots_held: Array, slot: int) -> bool:
	return slot < slots_held.size() and bool(slots_held[slot])


func _boss_form_phase() -> int:
	# Higher phase (more damage/coverage) as the boss-form timer runs down, so the
	# taken-over hero gets *more* powerful the longer they hold the form.
	var frac := 1.0 - boss_form_timer / BOSS_FORM_DURATION
	if frac < 0.34:
		return 1
	if frac < 0.67:
		return 2
	return 3


## Emit a boss-style area hazard through the main scene's hazard system.
func _emit_boss_form_hazard(kind: String, origin: Vector2, radius: float, telegraph: float, active: float, damage: float, color: Color) -> void:
	var main_root := get_parent()
	if main_root == null or not main_root.has_method("player_hazard_requested"):
		return
	main_root.call("player_hazard_requested", {
		"kind": kind,
		"origin": origin,
		"radius": radius,
		"telegraph": telegraph,
		"active": active,
		"damage": damage,
		"color": str(color.to_html(false)),
	})


## Emit a boss-style line hazard.
func _emit_boss_form_hazard_line(direction: Vector2, telegraph: float, active: float, damage: float, color: Color) -> void:
	var main_root := get_parent()
	if main_root == null or not main_root.has_method("player_hazard_requested"):
		return
	main_root.call("player_hazard_requested", {
		"kind": "line",
		"origin": global_position,
		"direction": direction,
		"telegraph": telegraph,
		"active": active,
		"damage": damage,
		"color": str(color.to_html(false)),
	})


## Increment the hero-kill counter while in boss form (FFA). Returns true if the
## threshold has been reached (caller should revert).
func boss_form_register_hero_kill() -> bool:
	boss_form_hero_kills += 1
	if boss_form_hero_kills >= BOSS_FORM_HERO_KILLS_REQUIRED:
		return true
	return false


## Start every hero with the loadout the player pre-picked in the menu: 3 regular slots from
## PlayerProfile.loadout_for, and the ultimate only once that hero's first-run wave milestone
## banked it (maybe_unlock_ult). Slot 4 stays empty until then; the run's mid-draft can fill it.
func _apply_kit_abilities() -> void:
	known_abilities.clear()
	var cooldowns: Array[float] = []
	var loadout: Array[String] = PlayerProfile.loadout_for(class_id)
	for slot_index in mini(loadout.size(), PlayerClass.MAX_KNOWN_ABILITIES):
		var ability_id := String(loadout[slot_index])
		if ability_id.is_empty() or not PlayerClass.ABILITIES.has(ability_id):
			continue
		# Ability-unlock system: the hero starts with ONLY their primary slot (index 0,
		# "Q") usable. Every other slot exists but is locked (rank 0) and is unlocked via
		# a level-up "unlock" offer. Rank 0 means "known but not yet unlocked".
		var start_rank := 1 if slot_index == 0 else 0
		known_abilities.append({"id": ability_id, "rank": start_rank})
		cooldowns.append(0.0)
	# Classic mode keeps the legacy full kit (no unlock gating) so it matches its
	# simpler design; only the modern modes gate behind the unlock flow.
	if GameRuntime.is_classic():
		for entry in known_abilities:
			entry.rank = maxi(1, int(entry.rank))
	ability_cooldowns = cooldowns


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
	if not FACING_CLASS_IDS.has(class_id):
		return SpriteLibrary.texture_for(class_id)
	var base_name := class_id if _tobor_facing == "front" else "%s_%s" % [class_id, _tobor_facing]
	# Walk frames are authored as "<facing>_w1..3"; frame 0 is the standing base sprite.
	if _walk_cycle_phase > 0:
		var walk_texture := SpriteLibrary.texture_for("%s_w%d" % [base_name, _walk_cycle_phase])
		if walk_texture != null:
			return walk_texture
	if _tobor_facing == "front":
		return SpriteLibrary.texture_for(class_id)
	var texture := SpriteLibrary.texture_for(base_name)
	return texture if texture != null else SpriteLibrary.texture_for(class_id)


func _apply_locomotion() -> void:
	_refresh_sort_z()
	_normal_collision_mask = WORLD_LAYER | ENEMY_LAYER
	if _jump_t < 0.0 and not hovering:
		_normal_collision_mask |= OBSTACLE_LAYER
	if sprint_timer <= 0.0:
		collision_mask = _normal_collision_mask


func _refresh_sort_z() -> void:
	z_as_relative = false
	z_index = WorldClock.depth_z(global_position.y, 40 if _jump_t >= 0.0 else (8 if hovering else 2))


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
	# 4-frame walk cycle shared by every hero: phase steps 0→1→2→3→0 while moving, frozen at 0 standing.
	if moving:
		_tobor_walk_phase += delta * 7.0
	else:
		_tobor_walk_phase = 0.0
	_walk_cycle_phase = int(_tobor_walk_phase) % 4 if moving else 0
	_paint_hero_facing()
	_update_gait(delta, moving)


func _hero_sprite_scale() -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ONE
	var boost := HERO_SCALE_BOOST
	if class_id == "arclight" or class_id == "bulwark" or class_id == "warden":
		boost *= 1.125
	elif class_id != "tobor":
		boost *= 1.25
	if FACING_CLASS_IDS.has(class_id):
		return SpriteLibrary.scale_for_radius(sprite.texture, BODY_RADIUS * 2.2 * boost)
	if sprite.texture.get_width() >= 32:
		return SpriteLibrary.tobor_scale(BODY_RADIUS * 1.45 * boost)
	return SpriteLibrary.scale_for_radius(sprite.texture, BODY_RADIUS * 1.45 * boost)


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
		hop -= 28.0 * arc
		if stacks_of("sjaal") > 0:
			hop -= 12.0 * arc
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.texture = SpriteLibrary.compose_tobor(shop_stacks, walk_frame, _tobor_facing)
	sprite.centered = true
	sprite.offset = Vector2(0.0, hop)
	sprite.scale = SpriteLibrary.tobor_scale(BODY_RADIUS * 1.45 * HERO_SCALE_BOOST)
	_place_health_bar(hop)


func is_cpu() -> bool:
	return simulation_mode == SimulationMode.CPU


func is_pvp_protected() -> bool:
	return pvp_invuln_timer > 0.0


func apply_knockback(impulse: Vector2) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	knockback_velocity += impulse


func apply_slow(next_slow_factor: float, duration: float) -> void:
	crowd_slow_factor = minf(crowd_slow_factor if crowd_slow_timer > 0.0 else 1.0, clampf(next_slow_factor, 0.12, 1.0))
	crowd_slow_timer = maxf(crowd_slow_timer, duration)


func apply_team_identity() -> void:
	if not GameRuntime.is_ffa() or team_id == "":
		return
	var color := RiftClashManager.team_color(team_id)
	accent_color = color
	if world_health_bar != null:
		world_health_bar.set_identity_color(color)
		world_health_bar.set_shield_color(color.lightened(0.22))
		world_health_bar.show_local_indicators(is_local_player)


func grant_pvp_spawn_protection() -> void:
	pvp_invuln_timer = GameRuntime.FFA_PVP_INVULN_SECONDS
	_ensure_spawn_shield()
	_refresh_pvp_modulate()


func _ensure_spawn_shield() -> void:
	if _spawn_shield != null and is_instance_valid(_spawn_shield):
		return
	_spawn_shield = SPAWN_SHIELD_SCRIPT.new() as Node2D
	_spawn_shield.name = "SpawnShield"
	_spawn_shield.z_index = 32
	add_child(_spawn_shield)


func set_ffa_respawn(seconds: float) -> void:
	ffa_respawn_left = maxf(0.0, seconds)
	_refresh_respawn_label()


func _ensure_respawn_label() -> void:
	if _respawn_label != null and is_instance_valid(_respawn_label):
		return
	_respawn_label = Label.new()
	_respawn_label.name = "RespawnCounter"
	_respawn_label.z_index = 40
	_respawn_label.top_level = true
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_respawn_label.add_theme_font_size_override("font_size", 28)
	_respawn_label.add_theme_color_override("font_color", Color("ffe56a"))
	_respawn_label.add_theme_color_override("font_outline_color", Color("1a1208"))
	_respawn_label.add_theme_constant_override("outline_size", 10)
	_respawn_label.custom_minimum_size = Vector2(56, 36)
	_respawn_label.visible = false
	add_child(_respawn_label)


func _refresh_respawn_label() -> void:
	_ensure_respawn_label()
	var show := GameRuntime.is_ffa() and not active and ffa_respawn_left > 0.05
	_respawn_label.visible = show
	if world_health_bar != null:
		world_health_bar.visible = active and not GameRuntime.is_dedicated_server()
	if not show:
		return
	_respawn_label.text = str(ceili(ffa_respawn_left))
	_respawn_label.global_position = global_position + Vector2(-28.0, -86.0)


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func set_authority_command(move_input: Vector2, aim_position: Vector2, attack_held: bool, ability_held: bool = false, ability_slots_held: Array = [false, false, false, false], secondary_held: bool = false) -> void:
	command_move = move_input.limit_length(1.0)
	command_aim = aim_position
	command_attack = attack_held
	command_ability = ability_held
	command_ability_slots = ability_slots_held
	command_secondary = secondary_held
	# Self-test / scripted input: latch so OFFLINE polling cannot overwrite walk or hold-still.
	_external_command_latched = true


## Self-test / scripted AI: same rising-edge tap a player would send on ability_1..4.
## Bypasses InputService so casts still land while movement is latched.
func scripted_tap_ability(slot: int) -> void:
	_arm_or_confirm_ability(slot)


## Re-arm input polling for real keyboard/mouse again (self-test driver calls this when it
## wants the player back under human control, e.g. after a scripted sequence ends).
func clear_external_command() -> void:
	_external_command_latched = false


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
	var state_team := str(state.get("team_id", team_id))
	if state_team != team_id:
		team_id = state_team
	hero_kills = int(state.get("hero_kills", hero_kills))
	pvp_invuln_timer = float(state.get("pvp_invuln", pvp_invuln_timer))
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
	if pvp_invuln_timer > 0.0:
		pvp_invuln_timer = maxf(0.0, pvp_invuln_timer - delta)
		_refresh_pvp_modulate()
	if simulation_mode == SimulationMode.PROXY:
		var to_net := network_target_position - global_position
		global_position = global_position.lerp(network_target_position, clampf(delta * 14.0, 0.0, 1.0))
		_update_tobor_visual(delta, to_net)
		_update_hover_visual(delta)
		_refresh_secondary_bar()
		_refresh_sort_z()
		return

	if not active or movement_locked:
		velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
		_reset_attack_charge()
		_tick_cooldowns(delta)
		sprint_cooldown = maxf(0.0, sprint_cooldown - delta)
		_refresh_secondary_bar()
		_refresh_respawn_label()
		return

	var move_input := command_move
	var attack_held := command_attack
	var ability_held := command_ability
	var ability_slots_held := command_ability_slots
	var secondary_held := command_secondary
	var jump_pressed := false
	if simulation_mode == SimulationMode.CPU:
		var cpu := CpuBrain.think(self, delta)
		move_input = (cpu.move as Vector2).limit_length(1.0)
		command_aim = cpu.aim
		attack_held = bool(cpu.attack)
		ability_held = bool(cpu.ability)
		ability_slots_held = cpu.ability_slots
		secondary_held = bool(cpu.get("secondary", false))
		jump_pressed = bool(cpu.get("jump", false))
	elif simulation_mode == SimulationMode.OFFLINE and not _external_command_latched:
		move_input = InputService.movement_vector()
		command_aim = InputService.aim_world_position(self)
		attack_held = InputService.primary_attack_held()
		ability_held = InputService.ability_held()
		secondary_held = InputService.secondary_attack_held()
		jump_pressed = InputService.jump_pressed()
		ability_slots_held = [
			InputService.ability_slot_held(0), InputService.ability_slot_held(1),
			InputService.ability_slot_held(2), InputService.ability_slot_held(3),
		]

	aim_world_position = command_aim
	var aim_direction := global_position.direction_to(aim_world_position)
	if aim_direction.length_squared() > 0.0:
		facing_direction = aim_direction

	_update_sprint(delta, ability_held)
	_update_jump(delta, jump_pressed)
	_update_energy_fields(delta)
	_update_ability_buff(delta)
	_update_phase_cloak(delta)
	_tick_secondary_effects(delta)
	health.tick_shield(delta)
	health.tick_hit_invulnerability(delta)
	_update_ability_slots(delta, ability_slots_held)
	_update_secondary(delta, secondary_held)
	_refresh_secondary_bar()
	_update_hazard(delta)
	var speed := movement_speed * float(ability_buff_stats.get("movement_speed_mult", 1.0)) * _secondary_move_mult
	if crowd_slow_timer > 0.0:
		speed *= crowd_slow_factor
	if sprint_timer > 0.0:
		speed *= 1.0 + SPRINT_SPEED_BONUS + maxf(0.0, float(stacks_of(ShopCatalog.ACTIVE_ITEM_ID) - 1) * 0.12)
	speed *= 1.0 + skate_speed_bonus
	if _in_water_hazard:
		speed *= WATER_CROSSING_SPEED_MULT
	velocity = move_input * speed + knockback_velocity
	move_and_slide()
	_refresh_sort_z()
	# Synergy "Skirmisher": healing while moving (movement = safety = life).
	if _move_heal_per_second > 0.0 and velocity.length_squared() > 400.0 and not health.is_dead:
		health.current_health = minf(health.max_health, health.current_health + _move_heal_per_second * delta)
		health.health_changed.emit(health.current_health, health.max_health)
	_tick_pulse_blast(delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, PLAYER_KNOCKBACK_DECAY * delta)
	_update_tobor_visual(delta, move_input)
	_update_hover_visual(delta)
	_apply_jump_visual()

	_update_buff(delta)
	_update_items(delta)
	if weapon_kind == PlayerClass.Weapon.MENDING_BOLT:
		_apply_support_aura(delta)

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_update_attack_charge(delta, attack_held)
	queue_redraw()


func _reset_attack_charge() -> void:
	attack_charge = 0.0
	_shot_charge = 0.0
	_charge_firing = false
	_attack_held_prev = false


func _charge_t() -> float:
	return clampf(attack_charge / PlayerClass.ATTACK_CHARGE_MAX, 0.0, 1.0)


func _charge_size_mult(t: float = -1.0) -> float:
	if t < 0.0:
		t = _shot_charge
	return lerpf(1.0, PlayerClass.ATTACK_CHARGE_SIZE, t)


func _charge_damage_mult(t: float = -1.0) -> float:
	if t < 0.0:
		t = _shot_charge
	# Early tap is a weak poke; waiting for a full auto-charge is the real hit.
	return lerpf(0.42, PlayerClass.ATTACK_CHARGE_DAMAGE, t)


func _update_attack_charge(delta: float, held: bool) -> void:
	# Auto-charge LMB: the charge builds continuously between shots (no hold needed).
	# A full auto-charge delivers the biggest damage + the biggest hit radius. A quick
	# tap mid-charge is still strong — the base multiplier at 0 charge is not a "weak
	# poke", so not waiting for a full charge is never punishing.
	if _charge_firing:
		_attack_held_prev = held
		return
	if attack_cooldown > 0.0:
		_attack_held_prev = held
		return
	# Charge builds on its own, capped at the hero's max.
	attack_charge = minf(PlayerClass.ATTACK_CHARGE_MAX, attack_charge + delta * charge_rate_mult)
	_attack_held_prev = held
	if held:
		_release_charged_attack()


func _release_charged_attack() -> void:
	_shot_charge = _charge_t()
	attack_charge = 0.0
	_charge_lock_impact = _charge_aim_point()
	var delay := lerpf(PlayerClass.ATTACK_TAP_DELAY, PlayerClass.ATTACK_FULL_DELAY, _shot_charge)
	if delay <= PlayerClass.ATTACK_TAP_DELAY + 0.001:
		_fire_charged_attack()
		return
	_charge_firing = true
	_register_pending_hazard(_charge_lock_impact, _charge_preview_radius(_shot_charge), delay, "blast")
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_fire_charged_attack()
	)


func _fire_charged_attack() -> void:
	_charge_firing = false
	_perform_attack()
	attack_cooldown = attack_interval * float(ability_buff_stats.get("attack_interval_mult", 1.0))
	_shot_charge = 0.0
	_charge_lock_impact = Vector2.ZERO


func _charge_aim_point() -> Vector2:
	if weapon_kind == PlayerClass.Weapon.CONE_SLAM:
		return global_position + facing_direction * attack_range * 0.55
	var primary := _find_primary_pvp_target()
	if primary != null:
		return primary.global_position
	if weapon_kind == PlayerClass.Weapon.ENERGY_BLAST:
		var blast_target := _find_primary_target()
		if blast_target != null:
			return blast_target.global_position
	var reach := minf(attack_range, 280.0)
	if weapon_kind == PlayerClass.Weapon.ENERGY_BLAST:
		reach = minf(attack_range, 280.0)
	return global_position + facing_direction * reach


func _charge_preview_radius(t: float) -> float:
	var size := _charge_size_mult(t)
	match weapon_kind:
		PlayerClass.Weapon.ENERGY_BLAST:
			return blast_radius * size
		PlayerClass.Weapon.FROST_SHARD:
			return frost_burst_radius * size
		PlayerClass.Weapon.CONE_SLAM:
			return attack_range * size
		_:
			return lerpf(16.0, 52.0, t)


func _weapon_hit(target: Node2D, base_damage: float) -> void:
	var crit := crit_chance > 0.0 and randf() < crit_chance
	var damage := base_damage * (crit_mult if crit else 1.0)
	if target is Player and GameRuntime.is_ffa():
		var rival := target as Player
		if rival.is_pvp_protected() or rival.team_id == team_id:
			return
		var taken := maxf(rival.health.damage_taken_multiplier, 0.05)
		var amount := rival.health.max_health / (GameRuntime.FFA_PVP_SHOTS_TO_KILL * taken)
		amount *= _charge_damage_mult()
		if crit:
			amount *= crit_mult
		rival.health.take_damage(amount, self)
		return
	var tap := PlayerClass.SHARED_WEAPON_TAP
	var ratio := damage / maxf(weapon_damage, 1.0)
	_damage_enemy(target, tap * ratio * _charge_damage_mult())


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
	if ability_held and has_active_item() and sprint_timer <= 0.0 and sprint_cooldown <= 0.0 and not can_board_jump():
		sprint_timer = sprint_burst_duration()
		sprint_cooldown = sprint_cycle_length()
		SoundDirector.play("dash", global_position)
	## Phase Boots: the sprint genuinely phases through units and obstacles now, not just a
	## speed boost — collision is off for the whole burst and restored the instant it ends.
	if sprint_timer > 0.0 and not was_sprinting:
		collision_mask = 0
	elif sprint_timer <= 0.0 and was_sprinting:
		collision_mask = _normal_collision_mask


func _update_items(delta: float) -> void:
	if health_regen_per_second > 0.0:
		health.heal(health_regen_per_second * delta)
	_update_grab(delta)
	if ember_damage_per_second <= 0.0:
		return
	for target in _enemies_in_radius(global_position, EMBER_RADIUS):
		var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(ember_damage_per_second * delta, self)


func can_board_jump() -> bool:
	return board_jump or stacks_of("hoverboard") > 0


func _jump_hang() -> float:
	var hang := 0.62
	var wings := stacks_of("sjaal")
	if wings > 0:
		hang = 0.92 + 0.12 * float(wings - 1)
	return hang


func _apply_jump_visual() -> void:
	if sprite == null or _jump_t < 0.0 or class_id == "tobor":
		return
	var arc := sin(clampf(_jump_t, 0.0, 1.0) * PI)
	var hop := -32.0 * arc
	if stacks_of("sjaal") > 0:
		hop -= 14.0 * arc
	sprite.offset = Vector2(sprite.offset.x, hop)
	_place_health_bar(hop)


func _update_jump(delta: float, want_jump: bool) -> void:
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if _jump_t >= 0.0:
		_jump_t += delta / _jump_hang()
		if _jump_t >= 1.0:
			_finish_jump()
		return
	if can_board_jump():
		if want_jump and _jump_cooldown <= 0.0:
			_start_jump()
		return
	if jetpack_slam <= 0.0:
		return
	if _jump_cooldown <= 0.0:
		_start_jump()
		_jump_cooldown = 2.0 if stacks_of("sjaal") <= 0 else 2.4


func _start_jump() -> void:
	_jump_t = 0.0
	_jump_cooldown = 0.28
	collision_mask = WORLD_LAYER
	_apply_locomotion()


func _finish_jump() -> void:
	_jump_t = -1.0
	_apply_locomotion()
	if jetpack_slam > 0.0:
		_land_slam()
	if _arena == null:
		_arena = Arena.arena_root(self)
	if _arena != null:
		for obstacle in _arena.obstacles:
			if not is_instance_valid(obstacle):
				continue
			if global_position.distance_to(obstacle.global_position) < obstacle.body_radius + BODY_RADIUS:
				global_position = _arena.free_position_near(global_position, BODY_RADIUS + 8.0)
				break


func _update_jetpack(_delta: float) -> void:
	pass


func _land_slam() -> void:
	for target in _enemies_in_radius(global_position, 120.0):
		var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(jetpack_slam, self)
		if target.has_method("apply_knockback"):
			target.apply_knockback(global_position.direction_to(target.global_position) * 280.0)
	SoundDirector.play("explosion", global_position)


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
		if not _is_support_target(ally):
			continue
		if global_position.distance_squared_to(ally.global_position) > radius_sq:
			continue
		var heal_rate := support_heal_per_second if ally != self else support_heal_per_second * 0.5
		ally.health.heal(heal_rate * delta)
		ally.receive_support_buff(support_damage_bonus)


## Warden heals and shield bursts must never prop up an enemy team in Rift Clash.
func _is_support_target(other: Player) -> bool:
	if not GameRuntime.is_rift_clash() or team_id == "":
		return true
	return other.team_id == team_id


## --- Hero abilities -------------------------------------------------------------------

func learn_ability(ability_id: String) -> void:
	if simulation_mode == SimulationMode.PROXY or known_abilities.size() >= PlayerClass.MAX_KNOWN_ABILITIES:
		return
	for entry in known_abilities:
		if entry.id == ability_id:
			return
	known_abilities.append({"id": ability_id, "rank": 1})
	# Grow the typed cooldown array alongside known_abilities (kit-less heroes start empty).
	while ability_cooldowns.size() < known_abilities.size():
		ability_cooldowns.append(0.0)


## Ability-unlock system: ids of abilities the hero holds but has not yet unlocked
## (rank 0). Empty means the full kit is available.
func locked_ability_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in known_abilities:
		if int(entry.rank) < 1:
			out.append(str(entry.id))
	return out


## True while any ability slot is still locked (rank 0).
func has_locked_abilities() -> bool:
	return not locked_ability_ids().is_empty()


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


## Heroes whose kit uses two-stage targeting: tap ability key once to "arm" with an aim
## indicator, tap again (or click) to confirm the cast at the aim point/vector/area.
## HoN-style skilled casts — Keg lobbed to a point, Energy Field thrown to a point, etc.
## Anything NOT in this list is instant-cast on press (the old behavior).
const TARGETED_ABILITIES := {
	# --- Robot (Iron Foundry) -------------------------------------------------------------
	"tobor_steam_keg": "point",
	"tobor_steam_turret": "instant",
	"tobor_spider_mines": "point",
	"tobor_energy_field": "point",
	"arclight_blast_of_lightning": "unit",
	"arclight_chain_lightning": "unit",
	"arclight_electric_field": "point",
	"arclight_thundergods_wrath": "instant",
	"bulwark_fissure": "point",
	"bulwark_heavyweight": "instant",
	"bulwark_enrage": "instant",
	"bulwark_echo_slam": "instant",
	"warden_tongue_tied": "unit",
	"warden_voodoo_wards": "point",
	"warden_cursed_ground": "point",
	"warden_life_drain": "unit",
	# --- Caldera ------------------------------------------------------------------------------
	"cinder_whirling_flame": "vector",
	"cinder_fiery_assault": "instant",
	"cinder_blazing_strike": "point",
	"cinder_blazing_pillar": "point",
	"pyra_sticky_bomb": "point",
	"pyra_boom_dust": "instant",
	"pyra_bombardment": "point",
	"pyra_air_strike": "point",
	"slag_steam_bath": "instant",
	"slag_volcanic_touch": "instant",
	"slag_lava_surge": "vector",
	"slag_eruption": "instant",
	"ember_entangle": "point",
	"ember_healing_wave": "instant",
	"ember_storm_cloud": "point",
	"ember_unbreakable": "instant",
	# --- Wilds ---------------------------------------------------------------------------------
	"thorn_poison_spray": "vector",
	"thorn_toxin_ward": "point",
	"thorn_toxicity": "instant",
	"thorn_poison_burst": "instant",
	"willow_swift_strike": "instant",
	"willow_forsaken_shot": "vector",
	"willow_volley": "vector",
	"willow_wall_of_roots": "point",
	"stump_natures_rally": "instant",
	"stump_camouflage": "instant",
	"stump_natures_veil": "point",
	"stump_overgrowth": "point",
	"sage_grace": "instant",
	"sage_volatile_pod": "point",
	"sage_nymphoras_kiss": "unit",
	"sage_charm": "unit",
	# --- Storm Court ---------------------------------------------------------------------------
	"volt_gust": "vector",
	"volt_wind_shield": "instant",
	"volt_wind_control": "unit",
	"volt_typhoon": "instant",
	"nebula_time_shift": "instant",
	"nebula_curse_of_ages": "unit",
	"nebula_rewind": "instant",
	"nebula_chronofield": "instant",
	"astral_essence_link": "point",
	"astral_ward_of_light": "instant",
	"astral_spirit_bond": "unit",
	"astral_as_one": "instant",
	"rime_ice_imprisonment": "unit",
	"rime_chilling_touch": "instant",
	"rime_glacier_blast": "instant",
	"rime_freezing_field": "instant",
}

var _pending_ability_slot := -1
var _pending_ability_id := ""


func _arm_or_confirm_ability(slot: int) -> void:
	if slot < 0 or slot >= known_abilities.size():
		return
	var entry := known_abilities[slot]
	var ability_id := str(entry.id)
	if ability_cooldowns[slot] > 0.0:
		return
	if not TARGETED_ABILITIES.has(ability_id):
		_cast_known_ability(slot)
		return
	var mode := str(TARGETED_ABILITIES[ability_id])
	if mode == "instant":
		_cast_known_ability(slot)
		return
	if _pending_ability_slot == slot:
		# Tap-twice confirms: cast at the current aim.
		if mode == "unit" and _nearest_enemy_in_range(_unit_target_range_for(ability_id)) == null:
			# Stay armed; need an actual target.
			return
		_cast_known_ability(slot)
		_pending_ability_slot = -1
		_pending_ability_id = ""
	else:
		# Arm the ability: lock it in, chill other inputs' cooldown spam, draw an indicator.
		_pending_ability_slot = slot
		_pending_ability_id = ability_id
		aim_indicator_visible = true
		queue_redraw()


func _unit_target_range_for(_ability_id: String) -> float:
	var data := PlayerClass.ability_info(_ability_id)
	var values := PlayerClass.ability_values(_ability_id, 1)
	return float(values.get("range", 540.0)) if not data.is_empty() else 540.0


var _slots_held_prev: Array[bool] = [false, false, false, false]


func _tick_cooldowns(delta: float) -> void:
	for slot in ability_cooldowns.size():
		ability_cooldowns[slot] = maxf(0.0, ability_cooldowns[slot] - delta)
	secondary_cooldown = maxf(0.0, secondary_cooldown - delta)


func _update_ability_slots(delta: float, slots_held: Array) -> void:
	# Boss-form override: while in boss form, slots Q/E/R fire boss-style
	# attacks (slam / cross / volley) instead of the hero kit. This lets the
	# taken-over hero unleash the full boss arsenal on hotkeys.
	if in_boss_form:
		if _is_slot_held(slots_held, 0):
			_boss_form_slam()
		if _is_slot_held(slots_held, 1):
			_boss_form_cross()
		if _is_slot_held(slots_held, 2):
			_boss_form_volley()
		_tick_cooldowns(delta)
		return
	if known_abilities.is_empty():
		_tick_cooldowns(delta)
		return
	_tick_cooldowns(delta)
	for slot in known_abilities.size():
		if slot >= slots_held.size():
			continue
		# Ability-unlock gating: a locked slot (rank 0) cannot be cast. It is
		# unlocked via a level-up "unlock" offer which bumps the rank to 1.
		if int(known_abilities[slot].rank) < 1:
			if slot < _slots_held_prev.size():
				_slots_held_prev[slot] = bool(slots_held[slot])
			continue
		var held := bool(slots_held[slot])
		var was_held := slot < _slots_held_prev.size() and _slots_held_prev[slot]
		if held and ability_cooldowns[slot] <= 0.0:
			if simulation_mode == SimulationMode.CPU:
				_cast_known_ability(slot)
			elif not was_held:
				_arm_or_confirm_ability(slot)
		if slot < _slots_held_prev.size():
			_slots_held_prev[slot] = held


func _cast_known_ability(slot: int) -> void:
	var entry := known_abilities[slot]
	var ability_id := str(entry.id)
	var data := PlayerClass.ability_info(ability_id)
	if data.is_empty():
		return
	var values := PlayerClass.ability_values(ability_id, int(entry.rank))
	_casting_ability_id = ability_id
	ability_cooldowns[slot] = values.cooldown
	# Clear any armed two-stage state — cast is now committed.
	_pending_ability_slot = -1
	_pending_ability_id = ""
	aim_indicator_visible = false
	# Wrench's HoN-inspired machinery is a bespoke kit — handle the four cast functions
	# explicitly before the generic archetype table. These use richer plumbing (two-stage
	# projectile throws, multi-mine scatter, zone control) than a bare archetype entry would.
	match ability_id:
		"tobor_steam_keg":
			_cast_ability_wrench_keg(data, values, int(entry.rank))
			return
		"tobor_steam_turret":
			_cast_ability_wrench_turret(data, values, int(entry.rank))
			return
		"tobor_spider_mines":
			_cast_ability_wrench_mines(data, values, int(entry.rank))
			return
		"tobor_energy_field":
			_cast_ability_wrench_field(data, values, int(entry.rank))
			return
		# --- Q kits (HoN-inspired bespoke routes) ------------------------------------------
		"arclight_blast_of_lightning":
			_cast_ability_arclight_blast(data, values, int(entry.rank))
			return
		"bulwark_fissure":
			_cast_ability_bulwark_fissure(data, values, int(entry.rank))
			return
		"warden_tongue_tied":
			_cast_ability_warden_tongue_tied(data, values, int(entry.rank))
			return
		"cinder_dragon_fire":
			_cast_ability_cinder_dragon_fire(data, values, int(entry.rank))
			return
		"pyra_sticky_bomb":
			_cast_ability_pyra_sticky_bomb(data, values, int(entry.rank))
			return
		"slag_steam_bath":
			_cast_ability_slag_steam_bath(data, values, int(entry.rank))
			return
		"ember_entangle":
			_cast_ability_ember_entangle(data, values, int(entry.rank))
			return
		"thorn_poison_spray":
			_cast_ability_thorn_poison_spray(data, values, int(entry.rank))
			return
		"willow_swift_strike":
			_cast_ability_willow_swift_strike(data, values, int(entry.rank))
			return
		"stump_natures_rally":
			_cast_ability_stump_natures_rally(data, values, int(entry.rank))
			return
		"sage_grace":
			_cast_ability_sage_grace(data, values, int(entry.rank))
			return
		"volt_gust":
			_cast_ability_volt_gust(data, values, int(entry.rank))
			return
		"nebula_time_shift":
			_cast_ability_nebula_time_shift(data, values, int(entry.rank))
			return
		"astral_essence_link":
			_cast_ability_astral_essence_link(data, values, int(entry.rank))
			return
		"rime_ice_imprisonment":
			_cast_ability_rime_ice_imprisonment(data, values, int(entry.rank))
			return
		# --- E kits -------------------------------------------------------------------------
		"arclight_chain_lightning":
			_cast_ability_arclight_chain_lightning(data, values, int(entry.rank))
			return
		"bulwark_heavyweight":
			_cast_ability_bulwark_heavyweight(data, values, int(entry.rank))
			return
		"warden_voodoo_wards":
			_cast_ability_warden_voodoo_wards(data, values, int(entry.rank))
			return
		"cinder_fiery_assault":
			_cast_ability_cinder_fiery_assault(data, values, int(entry.rank))
			return
		"pyra_boom_dust":
			_cast_ability_pyra_boom_dust(data, values, int(entry.rank))
			return
		"slag_volcanic_touch":
			_cast_ability_slag_volcanic_touch(data, values, int(entry.rank))
			return
		"ember_healing_wave":
			_cast_ability_ember_healing_wave(data, values, int(entry.rank))
			return
		"thorn_toxin_ward":
			_cast_ability_thorn_toxin_ward(data, values, int(entry.rank))
			return
		"willow_forsaken_shot":
			_cast_ability_willow_forsaken_shot(data, values, int(entry.rank))
			return
		"stump_camouflage":
			_cast_ability_stump_camouflage(data, values, int(entry.rank))
			return
		"sage_volatile_pod":
			_cast_ability_sage_volatile_pod(data, values, int(entry.rank))
			return
		"volt_wind_shield":
			_cast_ability_volt_wind_shield(data, values, int(entry.rank))
			return
		"nebula_curse_of_ages":
			_cast_ability_nebula_curse_of_ages(data, values, int(entry.rank))
			return
		"astral_ward_of_light":
			_cast_ability_astral_guardian_angel(data, values, int(entry.rank))
			return
		"rime_chilling_touch":
			_cast_ability_rime_chilling_touch(data, values, int(entry.rank))
			return
		# --- R kits (ultimates) -------------------------------------------------------------
		"arclight_thundergods_wrath":
			_cast_ability_arclight_thundergods_wrath(data, values, int(entry.rank))
			return
		"bulwark_echo_slam":
			_cast_ability_bulwark_echo_slam(data, values, int(entry.rank))
			return
		"warden_life_drain":
			_cast_ability_warden_life_drain(data, values, int(entry.rank))
			return
		"cinder_pillar_of_flame":
			_cast_ability_cinder_pillar_of_flame(data, values, int(entry.rank))
			return
		"pyra_air_strike":
			_cast_ability_pyra_air_strike(data, values, int(entry.rank))
			return
		"slag_eruption":
			_cast_ability_slag_eruption(data, values, int(entry.rank))
			return
		"ember_unbreakable":
			_cast_ability_ember_unbreakable(data, values, int(entry.rank))
			return
		"thorn_poison_burst":
			_cast_ability_thorn_poison_burst(data, values, int(entry.rank))
			return
		"willow_wall_of_roots":
			_cast_ability_willow_strangling_vines(data, values, int(entry.rank))
			return
		"stump_overgrowth":
			_cast_ability_stump_overgrowth(data, values, int(entry.rank))
			return
		"sage_charm":
			_cast_ability_sage_charm(data, values, int(entry.rank))
			return
		"volt_typhoon":
			_cast_ability_volt_typhoon(data, values, int(entry.rank))
			return
		"nebula_chronofield":
			_cast_ability_nebula_chronofield(data, values, int(entry.rank))
			return
		"astral_as_one":
			_cast_ability_astral_as_one(data, values, int(entry.rank))
			return
		"rime_freezing_field":
			_cast_ability_rime_freezing_field(data, values, int(entry.rank))
			return
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
		PlayerClass.Archetype.STORM_PULL:
			_cast_ability_storm_pull(data, values)
		PlayerClass.Archetype.ZONE_CHANNEL:
			_cast_ability_zone_channel(data, values)
		PlayerClass.Archetype.SUMMON_SPIRIT:
			_cast_ability_summon_spirit(data, values)
		PlayerClass.Archetype.SLAM_TAUNT:
			_cast_ability_slam_taunt(data, values)
		PlayerClass.Archetype.BLINK_STRIKE:
			_cast_ability_blink_strike(data, values)
		PlayerClass.Archetype.PIT_SLOW:
			_cast_ability_pit_slow(data, values)
		PlayerClass.Archetype.ATTACK_FURY:
			_cast_ability_attack_fury(data, values)


## Helpers ------------------------------------------------------------------------

## (Every damageable enemy in a radius is already helper'd below — used by all new "ground zone" casts.)
func _cast_ability_storm_pull(data: Dictionary, values: Dictionary) -> void:
	var reach := float(values.get("range", 420.0))
	# Pollywog-style Tongue Tied grabs the unit closest to the aim point; the default pull
	# (Gale Cyclone, Entangle) still reaches for the farthest enemy in range.
	var want_closest := bool(data.get("pull_closest", false))
	var best: Node2D = null
	var best_dist := -1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var n := enemy as Node2D
		var dist := global_position.distance_to(n.global_position)
		if dist > reach:
			continue
		if want_closest:
			if best == null or dist < best_dist:
				best = n
				best_dist = dist
		elif dist > best_dist:
			best = n
			best_dist = dist
	if best == null:
		# Emit even on whiffed pulls so coverage tools record the cast; aim-indicator
		# feedback loop reads `ability_cast` to know a slot actually fired.
		_emit_ability_cast(PackedVector2Array([global_position, global_position + facing_direction * reach]))
		return
	best.knockback_velocity = (global_position - best.global_position).normalized() * 1400.0
	_apply_ability_hit(best, data, values)
	_emit_ability_cast(PackedVector2Array([global_position, best.global_position]))


## Invoker-style zone: brief self-lock then a big ground patch detonates at your feet.
func _cast_ability_zone_channel(data: Dictionary, values: Dictionary) -> void:
	print("[zc] ENTER id=%s" % str(data.get("_id", "?")))
	sprint_cooldown = maxf(sprint_cooldown, 0.45)
	var center := global_position + facing_direction * 80.0
	print("[zc] pre-loop")
	for hurt in _enemies_in_radius(center, float(values.get("radius", 240.0))):
		_apply_ability_hit(hurt, data, values)
	print("[zc] post-loop")
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.get("radius", 240.0), 0.0)]))
	print("[zc] post-emit")


## Engineer-style summon: anchors a real turret/ward/wisp on the field that shoots
## enemies for the duration. Caps at MAX_ACTIVE_SUMMONS; oldest expiry.
const SummonEntityScene: PackedScene = preload("res://scenes/effects/summon_entity.tscn")
## Voodoo Wards drops a 4-ward ring, so the cap has to leave room for the full circle plus
## one spare turret; oldest expiry still trims single-turret spam.
const MAX_ACTIVE_SUMMONS := 6
var active_summons: Array[SummonEntity] = []

## Wrench's Spider Mines — proximity satchel charges planted on the field that detonate when
## an enemy steps inside their trigger radius. Long-lived field control; capped like summons.
## (Removed the hard total cap — Tobor can keep laying mines indefinitely; the ability
## cooldown is the only pacing gate. The constant is kept at a high number so the
## `clampi` call still works but never bites.)
const WRENCH_MAX_MINES := 999

## Turrets (Steam Turret) are now damageable and targetable, so a full field of them is a
## real resource. We still keep a soft cap on simultaneous turrets to avoid perf issues,
## but it's much higher than before so Tobor can stack several at once.
const MAX_ACTIVE_TURRETS := 12


func _cast_ability_summon_spirit(data: Dictionary, values: Dictionary) -> void:
	# Place at aim point (clamped to a sane throw distance) — the player picks where the turret
	# actually roots itself. Falls back to a small forward hop if aim is unreliable.
	var forward := global_position + facing_direction * 36.0
	var target := aim_world_position
	if target.distance_to(global_position) > 340.0:
		target = global_position + (target - global_position).normalized() * 340.0
	if target.distance_squared_to(global_position) < 200.0:
		target = forward
	# Pollywog Priest's Voodoo Wards plant a ring of totems around the focus; single-turret
	# summons (Steam Turret, Toxin Ward, Essence Link) drop just the one anchor at `target`.
	var count := maxi(1, int(data.get("summon_count", 1)))
	var ring_radius := 46.0
	for index in count:
		var offset := Vector2.ZERO
		if count > 1:
			var angle := TAU * float(index) / float(count) - PI * 0.5
			offset = Vector2(cos(angle), sin(angle)) * ring_radius
		_spawn_summon(data, values, target + offset)
	# Coverage tooling listens on ability_cast — the placement marker still displays via
	# the summon itself, but the slot needs to register as cast in the report. Emit a
	# placement marker at the focus point so the signal reflects where the wards landed.
	_emit_ability_cast(PackedVector2Array([global_position, target]))


func _spawn_summon(data: Dictionary, values: Dictionary, position: Vector2) -> void:
	var sum := SummonEntityScene.instantiate() as SummonEntity
	var hero := PlayerClass.by_id(class_id)
	sum.setup(
		_casting_ability_id,
		multiplayer.get_unique_id() if has_node("/root/NetworkService") else 0,
		float(values.get("power", 8.0)),
		float(values.get("duration", 4.0)),
		0.32,
		Color(str(hero.get("effect_color", "#ffffff")))
	)
	sum.owner_damage_type = int(damage_type)
	sum.position = position
	sum.expired.connect(_on_summon_expired)
	get_tree().current_scene.add_child(sum)
	active_summons.append(sum)
	# Enforce the cap: expire the oldest one if the caster already has a full set out.
	# Turret-style summons get a much higher ceiling (MAX_ACTIVE_TURRETS) so Tobor can
	# build up a battery of turrets; other summons keep the shared MAX_ACTIVE_SUMMONS.
	var cap := MAX_ACTIVE_TURRETS if sum.is_turret else MAX_ACTIVE_SUMMONS
	while active_summons.size() > cap:
		var oldest: SummonEntity = active_summons.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _on_summon_expired(entity: SummonEntity) -> void:
	active_summons.erase(entity)


## --- Wrench (HoN Engineer-inspired) kit ----------------------------------------------

## Steam Keg: HoN Engineer two-stage Q. Arm, then throw a visible keg to the click point.
## After a short fuse it detonates with knockback. Residual steam is a brief puff — not
## Energy Field's persistent containment ring. One ability_cast (throw telegraph) only;
## a second emit used Vector2(radius, fuse) as a BLAST impact and painted a screen-sized ring.
func _cast_ability_wrench_keg(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var throw_range := float(data.get("keg_range", maxf(float(values.range), 460.0)))
	var origin := global_position
	var center := _ability_aim_center(throw_range)
	var radius := float(values.radius)
	var fuse := maxf(float(data.get("fuse_delay", 0.55)), 0.15)
	var keg := _spawn_ability_projectile(_casting_ability_id, origin, center, fuse * 0.82, 58.0, true)
	_spawn_keg_warning_ring(center, radius, fuse)
	_register_pending_hazard(center, radius, fuse, "keg")
	var keg_id := _casting_ability_id
	get_tree().create_timer(fuse).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var boom_at := center
		if keg != null and is_instance_valid(keg):
			boom_at = keg.global_position
			keg.queue_free()
		_detonate_wrench_keg(data, values, boom_at, radius)
		_spawn_steam_cloud(boom_at, radius * 0.55, 1.2)
		if not keg_id.is_empty():
			ability_cast.emit(keg_id, PlayerClass.EffectStyle.BLAST, PackedVector2Array([
				boom_at,
				boom_at,
				Vector2(radius, 0.0),
			]))
	)


## The keg's pressure-wave: pops every enemy inside away from the centre (HoN Steam Keg's
## signature shove), then applies the payload (damage + stun) via the shared hit route.
func _detonate_wrench_keg(data: Dictionary, values: Dictionary, center: Vector2, radius: float) -> void:
	_spawn_keg_blast_wave(center, radius)
	var kick := absf(float(data.get("knockback_on_hit", 380.0)))
	for enemy in _pvp_hosts_in_radius(center, radius):
		_knock_away_from(enemy, center, kick)
		_apply_ability_hit(enemy, data, values)
	# Self-cast keg is an escape shove — never self-damage.
	if global_position.distance_to(center) <= radius + BODY_RADIUS:
		_knock_away_from(self, center, maxf(kick * 2.35, 860.0))


## Brief ring flash ahead of the blast so the fuse reads as HoN's "get out of the circle"
## timing window.
func _spawn_keg_warning_ring(center: Vector2, radius: float, duration: float, color: Color = Color(1.0, 0.72, 0.3, 0.9)) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ring := Line2D.new()
	ring.default_color = color
	ring.width = 5.0
	ring.z_index = 23
	scene_root.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(ring):
			return
		_fill_circle_line(ring, center, lerpf(18.0, radius, t))
		ring.default_color.a = 0.35 + 0.55 * t
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)


func _register_pending_hazard(center: Vector2, radius: float, duration: float, kind: String) -> void:
	if not is_inside_tree():
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var marker := Node2D.new()
	scene_root.add_child(marker)
	marker.global_position = center
	marker.add_to_group("pending_blasts")
	marker.set_meta("radius", radius)
	marker.set_meta("kind", kind)
	marker.set_meta("owner_id", get_instance_id())
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(marker):
			marker.queue_free()
	)


func _knock_away_from(target: Node2D, center: Vector2, kick: float) -> void:
	var away := center.direction_to(target.global_position)
	if away.length_squared() <= 0.0001:
		if target == self:
			away = -facing_direction
		if away.length_squared() <= 0.0001:
			away = Vector2.LEFT
	if target.has_method("apply_knockback"):
		target.apply_knockback(away * kick)
	elif "knockback_velocity" in target:
		target.knockback_velocity = away * kick


## Detonation: a filled shockwave that grows out of the keg.
func _spawn_keg_blast_wave(center: Vector2, radius: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var holder := Node2D.new()
	holder.z_index = 24
	scene_root.add_child(holder)
	var fill := Line2D.new()
	fill.closed = true
	fill.width = 18.0
	fill.default_color = Color(1.0, 0.55, 0.18, 0.85)
	var rim := Line2D.new()
	rim.closed = true
	rim.width = 8.0
	rim.default_color = Color(1.0, 0.92, 0.55, 1.0)
	holder.add_child(fill)
	holder.add_child(rim)
	var life := 0.42
	var tw := holder.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(holder):
			return
		var r := lerpf(10.0, radius * 1.15, t)
		_fill_circle_line(fill, center, r)
		_fill_circle_line(rim, center, r)
		fill.width = lerpf(22.0, 6.0, t)
		rim.width = lerpf(10.0, 3.0, t)
		holder.modulate.a = 1.0 - t * 0.82
	, 0.0, 1.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(holder.queue_free)


func _fill_circle_line(ring: Line2D, center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	var steps := 40
	for k in steps:
		var a := TAU * float(k) / float(steps)
		points.append(center + Vector2.from_angle(a) * radius)
	ring.points = points


## Aftermath: a brief superheated puff (not Energy Field's hex containment pulse).
func _spawn_steam_cloud(center: Vector2, radius: float, duration: float) -> void:
	_spawn_steam_puff(center, radius, duration)
	var tick_interval := 0.4
	var tick_power := 12.0
	var tick_count := maxi(int(floor(duration / tick_interval)), 1)
	get_tree().create_timer(tick_interval).timeout.connect(
		_steam_cloud_tick.bind(center, radius, tick_power, tick_interval, tick_count)
	)


## Soft fire/steam wisps — concentric fading rings, no hex walls or lightning cracks.
func _spawn_steam_puff(center: Vector2, radius: float, duration: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var steam := Color(1.0, 0.55, 0.22, 0.75)
	for i in 2:
		var ring := Line2D.new()
		ring.default_color = steam
		ring.width = 3.0 if i == 0 else 2.0
		ring.z_index = 22
		var ring_radius := radius * (1.0 if i == 0 else 0.55)
		var points := PackedVector2Array()
		for k in 24:
			var a := TAU * float(k) / 24.0
			points.append(center + Vector2(cos(a), sin(a)) * ring_radius)
		points.append(points[0])
		ring.points = points
		scene_root.add_child(ring)
		var tw := ring.create_tween()
		tw.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(ring.queue_free)


func _steam_cloud_tick(center: Vector2, radius: float, tick_power: float, tick_interval: float, ticks_left: int) -> void:
	if not is_inside_tree() or ticks_left <= 0:
		return
	for enemy in _enemies_in_radius(center, radius):
		_damage_enemy(enemy, tick_power)
	var remaining := ticks_left - 1
	if remaining > 0:
		get_tree().create_timer(tick_interval).timeout.connect(
			_steam_cloud_tick.bind(center, radius, tick_power, tick_interval, remaining)
		)


## Steam Turret: place an auto-firing steam turret at the aim point (within range).
## The turret chips nearby enemies for its lifetime. Placeable in-game — aim with the
## cursor; bots place it between themselves and the nearest enemies.
func _cast_ability_wrench_turret(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var landing := _ability_aim_center(values.range)
	_spawn_summon(data, values, landing)
	SoundDirector.play_ability("tobor_steam_turret", global_position)
	_emit_ability_cast(PackedVector2Array([global_position, landing]))


## Spider Mines: scatter a small clutch of proximity mines around the cursor. Each anchors
## where it lands and detonates on contact — field denial, not a direct nuke.
func _cast_ability_wrench_mines(data: Dictionary, values: Dictionary, rank: int) -> void:
	var mine_count := clampi(int(data.get("mine_count", 2)) + rank - 1, 1, WRENCH_MAX_MINES)
	var scatter_radius := float(data.get("scatter_radius", 70.0))
	var arm_range := maxf(float(values.range), 1200.0)
	var center := _ability_aim_center(arm_range)
	var snap := _nearest_enemy_in_range(arm_range)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate is Enemy and (candidate as Enemy).is_boss and global_position.distance_to((candidate as Node2D).global_position) <= arm_range:
			snap = candidate
			break
	if snap != null:
		center = snap.global_position
	for index in mine_count:
		var point := center
		if mine_count > 1:
			var angle := TAU * float(index) / float(mine_count) + _rand_range_float(0.0, 0.6)
			var dist := _rand_range_float(scatter_radius * 0.35, scatter_radius)
			point = center + Vector2(cos(angle), sin(angle)) * dist
		_spawn_wrench_mine(data, values, point)
	_emit_ability_cast(PackedVector2Array([center, Vector2(scatter_radius, 0.0)]))


func _spawn_wrench_mine(data: Dictionary, values: Dictionary, position: Vector2) -> void:
	var sum := SummonEntityScene.instantiate() as SummonEntity
	var hero := PlayerClass.by_id(class_id)
	sum.setup(
		_casting_ability_id,
		multiplayer.get_unique_id() if has_node("/root/NetworkService") else 0,
		float(values.get("power", 60.0)),
		float(values.get("duration", 40.0)),
		99.0,
		Color(str(hero.get("effect_color", "#ffffff")))
	)
	sum.range = 0.0
	sum.owner_damage_type = int(damage_type)
	sum.position = position
	# Arm first, then proximity fuse: walking onto an armed mine pops it — planting on a pack does not.
	sum.trigger_radius = float(data.get("trigger_radius", 28.0))
	sum.explosion_radius = float(data.get("explosion_radius", 70.0))
	sum.arm_delay = float(data.get("arm_delay", 1.15))
	sum.boss_damage_mult = float(data.get("boss_damage_mult", 4.5))
	sum.heal_on_explode = 0.0
	sum.owner_player = self
	# Mines crawl toward the nearest enemy instead of sitting still.
	sum.seek_speed = float(data.get("seek_speed", 0.0))
	sum.seek_range = float(data.get("seek_range", 260.0))
	sum._arm_timer = sum.arm_delay
	sum.expired.connect(_on_summon_expired)
	get_tree().current_scene.add_child(sum)
	SoundDirector.play_ability("tobor_spider_mines", global_position)
	active_summons.append(sum)
	# No hard cap on total active mines — the ability cooldown is the only pacing gate.
	# WRENCH_MAX_MINES is now a very high number so this effectively never trims.
	while active_summons.size() > WRENCH_MAX_MINES:
		var oldest: SummonEntity = active_summons.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Energy Field: two-stage HoN ultimate. Throws a crackling containment field at the picked
## point — enemies caught inside keep taking steam damage and move at a crawl while it's up.
func _cast_ability_wrench_field(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.range), 420.0)
	var center := _ability_aim_center(reach)
	# The slow is the field's defining debuff — lean on it hard, HoN-style.
	var slow_factor := 0.45
	var slow_duration := 4.0
	if data.has("slow_on_hit"):
		slow_factor = float(data.slow_on_hit.get("factor", slow_factor))
		slow_duration = float(data.slow_on_hit.get("duration", slow_duration))
	var radius := float(values.radius)
	# Opening burst: everyone caught in the field when it lands takes the first tick + slow.
	for enemy in _enemies_in_radius(center, radius):
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_factor, slow_duration)
		if enemy.has_method("apply_shock"):
			enemy.apply_shock(slow_duration)
		_apply_ability_hit(enemy, data, values)
	# Keep the zone painted for the slow's run so the field reads as a persistent hazard.
	var zone_duration := maxf(float(values.get("duration", 0.0)), maxf(slow_duration, 1.0))
	_spawn_ability_zone_pulse(center, radius, clampf(zone_duration, 1.5, 12.0))
	_energy_fields.append({
		"center": center,
		"radius": radius,
		"life": clampf(zone_duration, 1.5, 12.0),
		"tick": 0.12,
		"slow_factor": slow_factor,
		"data": data,
		"values": values,
		"on_rim": {},
	})
	_emit_ability_cast(PackedVector2Array([center, Vector2(radius, 0.0)]))


## Small jitter helper for mine scatter — slight spread so the clutch doesn't overlap.
func _rand_range_float(low: float, high: float) -> float:
	return low + randf() * (high - low)


## --- Non-Wrench Q kits (HoN-inspired bespoke routes) ---------------------------------------

## Arclight's Blast of Lightning: point-targeted high single-target strike. HoN Thunderbringer
## style — one bolt from the heavens, no splash, no chain. Heavy impact reads as a NUKE_BOLT
## on the target's position so the damage feel matches the visual focus.
func _cast_ability_arclight_blast(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.range), 480.0)
	var target := _nearest_enemy_in_range(reach)
	var center := target.global_position if target != null else _ability_aim_center(reach)
	var strike := data.duplicate()
	strike["_arclight_radius_override"] = true
	var vsingle := values.duplicate()
	vsingle.radius = 72.0
	for enemy in _enemies_in_radius(center, vsingle.radius):
		_apply_ability_hit(enemy, strike, vsingle)
	_emit_ability_cast(PackedVector2Array([center, Vector2(vsingle.radius, 0.0)]))


## Bulwark's Fissure: Earthshaker-style linear wall. HoN's Fissure raises a jagged ridge of
## earth along a straight line that blocks pathing for ~8 s, damaging + stunning everything
## standing on the crack. We spawn a row of impassable segments (collision layer 16, matching
## arena obstacles) backed by a fading ridge visual, then stun everything near the line.
const FISSURE_WALL_SEGMENTS := 5
const FISSURE_WALL_DURATION := 5.0
const FISSURE_STUN_DURATION := 1.5
const FISSURE_HIT_RADIUS := 60.0

func _cast_ability_bulwark_fissure(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	var wall_length := maxf(float(data.get("wall_length", 340.0)), 220.0)
	var wall_duration := maxf(float(data.get("wall_duration", FISSURE_WALL_DURATION)), 2.0)
	var wall_segments := maxi(int(data.get("wall_segments", FISSURE_WALL_SEGMENTS)), 3)
	var stun_duration := maxf(float(data.get("stun_on_hit", {}).get("duration", FISSURE_STUN_DURATION)), 0.6)
	var hit_radius := maxf(float(values.get("radius", FISSURE_HIT_RADIUS)), 30.0)
	var endpoint := origin + direction * wall_length

	# Stun + damage everything along the wall line (capsule around the segment).
	var midpoint := origin.lerp(endpoint, 0.5)
	var capsule_radius := wall_length * 0.5 + hit_radius
	for enemy in _enemies_in_radius(midpoint, capsule_radius):
		# Narrow to enemies actually near the wall band, not the full capsule sweep.
		var rel: Vector2 = (enemy as Node2D).global_position - origin
		var along := rel.dot(direction)
		if along < -hit_radius * 0.5 or along > wall_length + hit_radius * 0.5:
			continue
		var perpendicular: Vector2 = rel - direction * along
		if perpendicular.length() > hit_radius:
			continue
		_apply_ability_hit(enemy, data, values)

	_spawn_fissure_wall(origin, direction, wall_length, wall_segments, wall_duration)
	_emit_ability_cast(PackedVector2Array([origin, endpoint, Vector2(hit_radius, wall_duration)]))


## Raises a physical ridge: a row of short-lived StaticBody2D segments on collision layer 16
## (matching arena obstacles) that enemies can't path through. Heroes are on a different
## collision mask, so they walk through as HoN intends; the caster never moves. Fades out
## near death so it visually crumbles instead of popping.
func _spawn_fissure_wall(origin: Vector2, direction: Vector2, length: float, segments: int, duration: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var wall_root := Node2D.new()
	wall_root.name = "FissureWall"
	wall_root.z_index = 6
	scene_root.add_child(wall_root)

	# Visual ridge: jagged bright line with a hot core, so you can read where the earth split.
	var ridge := Line2D.new()
	ridge.default_color = Color(1.0, 0.82, 0.45, 0.9)
	ridge.width = 10.0
	ridge.z_index = 24
	ridge.add_point(origin)
	ridge.add_point(origin + direction * length)
	wall_root.add_child(ridge)
	var core := Line2D.new()
	core.default_color = Color(1.0, 0.97, 0.88, 0.95)
	core.width = 2.5
	core.z_index = 25
	core.add_point(origin)
	core.add_point(origin + direction * length)
	wall_root.add_child(core)

	# Impassable segments: small StaticBody2D discs along the line, collision layer 16 —
	# arenas already treat 16 as "blocks ground movement". No script needed; plain physics.
	var segment_spacing := length / float(segments)
	var segment_radius := maxf(segment_spacing * 0.72, 20.0)
	for index in segments:
		var segment := StaticBody2D.new()
		segment.collision_layer = 16
		segment.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = segment_radius
		shape.shape = circle
		segment.add_child(shape)
		segment.global_position = origin + direction * (segment_spacing * (float(index) + 0.5))
		wall_root.add_child(segment)

	# TTL: fade the visual over the last 0.8 s, then free the whole wall after `duration`.
	var fade := ridge.create_tween()
	fade.tween_interval(maxf(duration - 0.8, 0.2))
	fade.tween_property(ridge, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.parallel().tween_property(core, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	get_tree().create_timer(duration).timeout.connect(wall_root.queue_free)


## Warden's Tongue Tied: Pollywog Priest's signature pull. Lashes out and yanks the CLOSeST
## enemy toward the caster. STORM_PULL with pull_closest routing. HoN's Tongue Tied always
## grabbed the nearest hostile — never the farthest one.
func _cast_ability_warden_tongue_tied(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var t := data.duplicate()
	t["pull_closest"] = true
	_cast_ability_storm_pull(t, values)


## Cinder's Dragon Fire: burst of flame from the mouth in a cone. Ember's kit's dragon form.
## CONE_BURST with a built-in burn tick after the flash, so targets keep smouldering after
## the fire passes. Uses `burn_on_hit` if present in data.
func _cast_ability_cinder_dragon_fire(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_cone_burst(data, values)
	# Burn-on-hit data: if the ability carries burn_on_hit, apply an extra delayed tick so the
	# scorched targets keep taking fire damage after the cone clears.
	if data.has("burn_on_hit"):
		var burn: Dictionary = data.burn_on_hit
		var tick_power := float(burn.get("power", values.power * 0.35))
		var duration := float(burn.get("duration", 3.0))
		var half_angle := deg_to_rad(PlayerClass.ABILITY_CONE_HALF_ANGLE_DEGREES)
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			for target in _enemies_in_radius(origin, float(values.radius) * 0.7):
				var to_t := origin.direction_to(target.global_position)
				if to_t.length_squared() > 0.0 and absf(facing_direction.angle_to(to_t)) > half_angle:
					continue
				_damage_enemy(target, tick_power * (duration / 3.0))
		)


## Pyra's Sticky Bomb: HoN Bombardier's signature trap. Lobs an adhesive bomb that clings
## to the ground at the aim point, arms, then waits. When an enemy wanders inside
## `trigger_radius` it detonates, dealing `power` across `explosion_radius` and popping
## everything inside away from the blast. If nothing trips it within `summon_lifetime`
## seconds it bursts on its own.
func _cast_ability_pyra_sticky_bomb(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	var forward := origin + facing_direction * 40.0
	var target := aim_world_position
	if target.distance_to(origin) > 340.0:
		target = origin + (target - origin).normalized() * 340.0
	if target.distance_squared_to(origin) < 200.0:
		target = forward
	var sum := SummonEntityScene.instantiate() as SummonEntity
	var hero := PlayerClass.by_id(class_id)
	sum.setup(
		_casting_ability_id,
		multiplayer.get_unique_id() if has_node("/root/NetworkService") else 0,
		float(values.get("power", 75.0)),
		# HoN's Sticky Bomb lives ~10 s; pull the fuse from data so rank/kind tweaks can stretch it.
		maxf(float(data.get("summon_lifetime", 10.0)), 4.0),
		99.0,
		Color(str(hero.get("effect_color", "#ffffff")))
	)
	sum.range = 0.0
	sum.owner_damage_type = int(damage_type)
	sum.position = target
	# HoN Sticky Bomb trigger ring is generous — you step into it deliberately or not at all.
	sum.trigger_radius = maxf(float(data.get("trigger_radius", 60.0)), 20.0)
	# Blast is wider than the trigger ring so a single mine catches the pack chasing it.
	sum.explosion_radius = maxf(float(data.get("explosion_radius", 100.0)), sum.trigger_radius)
	# Pop everything inside the blast away from the centre so the trap reads like a shell burst.
	sum.explosion_knockback = 260.0
	sum.expired.connect(_on_summon_expired)
	get_tree().current_scene.add_child(sum)
	SoundDirector.play_ability("pyra_sticky_bomb", global_position)
	active_summons.append(sum)
	while active_summons.size() > MAX_ACTIVE_SUMMONS:
		var oldest: SummonEntity = active_summons.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_emit_ability_cast(PackedVector2Array([origin, target]))


## Slag Steam Bath: Magmus's signature AoE slow-field. Vents a cloud of superheated steam
## around the caster — everyone inside takes softening pulses and a moving-buff. Data's
## buff_stats carry the actual tank boost; we add on a scorch DoT around the cast area.
func _cast_ability_slag_steam_bath(data: Dictionary, values: Dictionary, rank: int) -> void:
	_cast_ability_buff_self(data, values)
	# Vent a ring of scalding steam that lingers — softens enemies who step inside.
	var cloud_radius := maxf(float(values.get("radius", 0.0)), 200.0)
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(global_position, cloud_radius):
			if target.has_method("apply_slow"):
				target.apply_slow(0.55, 2.0 + rank * 0.2)
			_damage_enemy(target, float(values.get("power", 25.0)) * 0.4)
	)


## Ember's Entangle: HoN Treant/Keeper root. Every enemy inside the aimed area is held in
## place (movement = 0) for the full duration; damage is a token amount, not the point. The
## root data is in `root_on_hit` on the ability entry, and `_apply_ability_hit` routes it
## through `apply_movement_lock` on the enemy.
func _cast_ability_ember_entangle(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.get("range", 560.0)), 380.0)
	var center := _ability_aim_center(reach)
	var radius := maxf(float(values.get("radius", 0.0)), 180.0)
	var root_duration := maxf(float(data.get("root_on_hit", {}).get("duration", 2.5)), 1.5)
	for enemy in _enemies_in_radius(center, radius):
		_apply_ability_hit(enemy, data, values)
	_spawn_ability_zone_pulse(center, radius, maxf(root_duration, 2.0))
	_emit_ability_cast(PackedVector2Array([center, Vector2(radius, 0.0)]))


## Thorn's Poison Spray: hosed cone of toxin in front of the caster. The spray spreads fast
## and leaves every caught target with a lingering poison tick — Slither's Venom Spray.
func _cast_ability_thorn_poison_spray(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_cone_burst(data, values)


## Willow's Swift Strike: Forsaken Archer's blink-quick dash through the enemy line. The
## dash is longer than most players expect (HoN's Swift Strike covers a huge arc), and every
## enemy passed through takes the hit. Uses a forward-biased destination.
func _cast_ability_willow_swift_strike(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var strike_range := maxf(float(values.get("dash_distance", 320.0)), 280.0)
	var origin := global_position
	var destination := origin + facing_direction * strike_range
	var midpoint := origin.lerp(destination, 0.5)
	var hit_radius := strike_range * 0.5 + maxf(float(values.get("radius", 60.0)), 40.0)
	for enemy in _enemies_in_radius(midpoint, hit_radius):
		_apply_ability_hit(enemy, data, values)
	global_position = destination
	_emit_ability_cast(PackedVector2Array([origin, destination, Vector2(48.0, 0.0)]))


## Stump's Nature's Rally: Keeper's rallying call for the whole party. Applies the buff to
## every ally in the radius — not just the caster — so the tank actually READS as a tank-
## support hybrid that shares its bark-hard skin.
func _cast_ability_stump_natures_rally(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var rally := data.duplicate()
	rally["target_scope"] = "allies"
	rally["radius"] = maxf(float(rally.get("radius", 0.0)), 300.0)
	_cast_ability_buff_self(rally, values)


## Sage's Grace: Nymphora's burst of speed for the whole party. Straight BUFF_SELF—
## but with target_scope forced to allies, since Nymphora's grace always embraces the grove
## as a whole. Speed is the defining stat; the cooldown is intentionally short.
func _cast_ability_sage_grace(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var grace := data.duplicate()
	grace["target_scope"] = "allies"
	grace["buff_stats"] = {
		"movement_speed_mult": float(data.get("buff_stats", {}).get("movement_speed_mult", 1.25)),
		"damage_dealt_mult": float(data.get("buff_stats", {}).get("damage_dealt_mult", 1.1)),
	}
	_cast_ability_buff_self(grace, values)


## Volt's Gust: Zephyr's signature push. A forward cone of hard wind that knocks enemies
## flat — reuses PUSH_PULL_BURST (negative power = push) but wrapped in a vector so the
## direction is aim-controlled instead of self-centred.
func _cast_ability_volt_gust(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	# Gust pushes enemies away — negative power = outward push per PUSH_PULL_BURST semantics.
	var gust := data.duplicate()
	gust["power_base"] = -absf(float(data.get("power_base", 300.0)))
	gust["power_per_rank"] = -absf(float(data.get("power_per_rank", 35.0)))
	gust["slow_on_hit"] = {"factor": 0.6, "duration": 1.8}
	var gust_radius := maxf(float(values.get("radius", 0.0)), 200.0)
	var center := global_position + direction * 20.0
	for target in _enemies_in_radius(center, gust_radius):
		if not target.has_method("apply_knockback"):
			continue
		var away := center.direction_to(target.global_position)
		if away.length_squared() <= 0.0:
			away = direction
		var strength := absf(float(values.get("power", 300.0)))
		target.apply_knockback(away * strength)
		_arm_hazard_escape(target)
		if target.has_method("apply_slow"):
			target.apply_slow(0.6, 1.8)
		_damage_enemy(target, values.power)
	_emit_ability_cast(PackedVector2Array([center, Vector2(gust_radius, 0.0)]))
	_spawn_ability_zone_pulse(center, gust_radius, 1.2)


## Nebula's Time Shift: Chronos's blink through the time stream. Blink forward, then sweep
## a burst of pure chronal energy behind you. Chronos always favoured offence over defence.
func _cast_ability_nebula_time_shift(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	var burst_radius := maxf(float(values.get("radius", 140.0)), 120.0)
	var origin := global_position
	global_position += direction * float(values.get("dash_distance", 420.0))
	# Swap the hit for a time-blast instead of standard blink damage.
	for target in _enemies_in_radius(global_position, burst_radius):
		_damage_enemy(target, values.power)
		if target.has_method("apply_slow"):
			target.apply_slow(0.45, 2.5)
	# TELEPORT style: [origin, destination, Vector2(ring_radius, 0)]
	_emit_ability_cast(PackedVector2Array([origin, global_position, Vector2(burst_radius * 0.6, 0.0)]))


## Astral's Essence Link: Empath's signature. Heals every ally in radius — and links them:
## every healed ally takes a share of the highest-healed ally's missing health as a bonus.
## This forces party-synergy rather than individual sustain.
func _cast_ability_astral_essence_link(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var link_radius := float(values.get("radius", 300.0))
	var allies := _allies_in_radius(global_position, link_radius)
	# Find the most-missing-health ratio so the link carries weight.
	var max_deficit_ratio := 0.0
	for ally in allies:
		var deficit := (ally.health.max_health - ally.health.current_health) / maxf(ally.health.max_health, 1.0)
		max_deficit_ratio = maxf(max_deficit_ratio, deficit)
	var bonus := float(values.power) * max_deficit_ratio * 0.4
	for ally in allies:
		ally.health.heal(float(values.power) + bonus)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(link_radius, 0.0)]))


## Rime's Ice Imprisonment: Glacius's signature. Picks one enemy and locks it inside a
## block of ice — a clean unit-target root. Other enemies nearby feel the freeze splash.
func _cast_ability_rime_ice_imprisonment(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.get("range", 540.0)), 400.0)
	var target := _nearest_enemy_in_range(reach)
	if target == null:
		return
	# Ice Imprisonment: hard-freeze the target with a long lingering slow.
	if target.has_method("apply_slow"):
		target.apply_slow(0.25, 3.5)
	# Splash chill to nearby enemies too — Glacius's ice always spreads.
	for enemy in _enemies_in_radius(target.global_position, 140.0):
		if enemy == target:
			continue
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(0.55, 1.5)
		_damage_enemy(enemy, values.power * 0.5)
	_damage_enemy(target, values.power)
	_emit_ability_cast(PackedVector2Array([target.global_position, Vector2(60.0, 0.0)]))


## --- Non-Wrench E kits (HoN-inspired bespoke routes) ----------------------------------------

## Arclight's Chain Lightning: Thunderbringer's bouncing bolt. Long reach with huge chain
## hops — Arc Lightning reimagined. The cast always leads with the PRIMARY target and lets
## the chain find its own way from there, no random-leap-ahead weirdness.
func _cast_ability_arclight_chain_lightning(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var chain := data.duplicate()
	chain["chain_range"] = maxf(float(data.get("chain_range", 240.0)), 260.0)
	chain["chain_count"] = maxi(int(data.get("chain_count", 5)), 4)
	_cast_ability_chain_nuke(chain, values)


## Bulwark's Heavyweight: Behemoth's heavyweight swing — attack frenzy with DRAMATICALLY
## enhanced power. Forces the double-hit buff and stretches the window so the tank feels
## like a tank actually hitting something.
func _cast_ability_bulwark_heavyweight(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var fury := data.duplicate()
	fury["buff_stats"] = {
		"attack_interval_mult": 0.55,
		"damage_dealt_mult": 1.35,
		"movement_speed_mult": 1.15,
	}
	_cast_ability_attack_fury(fury, values)


## Warden's Voodoo Wards: Pollywog Priest's signature. Drops a RING of venom-spitting
## totems around the focus area. Four wards, each firing at the nearest enemy.
func _cast_ability_warden_voodoo_wards(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var wards := data.duplicate()
	wards["summon_count"] = 4
	wards["duration"] = maxf(float(wards.get("duration", 18.0)), 16.0)
	# Small ring radius so the wards fan out around the aim point like a real priest circle.
	var v := values.duplicate()
	v.radius = maxf(float(values.get("radius", 0.0)), 60.0)
	_cast_ability_summon_spirit(wards, v)


## Cinder's Fiery Assault: a ring of fire DETONATING around the caster. The ground keeps
## burning after the flash — the classic Ember spirit detonation.
func _cast_ability_cinder_fiery_assault(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_radius_burst(data, values)
	var ring_radius := float(values.get("radius", 220.0))
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(origin, ring_radius * 0.65):
			_damage_enemy(target, float(values.get("power", 32.0)) * 0.4)
			if target.has_method("apply_slow"):
				target.apply_slow(0.65, 1.5)
	)


## Pyra's Boom Dust: shake loose a cloud of explosive dust that coats every enemy in the
## radius. The blast hits immediately, then a second micro-pulse detonates the settled dust.
func _cast_ability_pyra_boom_dust(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_radius_burst(data, values)
	var ring_radius := maxf(float(values.get("radius", 240.0)), 180.0)
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(origin, ring_radius):
			_damage_enemy(target, float(values.get("power", 38.0)) * 0.35)
			if target.has_method("apply_slow"):
				target.apply_slow(0.7, 1.2)
	)


## Slag's Volcanic Touch: Magmus's AoE burn aura. Casts the push-pull instantly, but also
## leaves a scalding ring where the caster stood for a moment.
func _cast_ability_slag_volcanic_touch(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_push_pull_burst(data, values)
	# Burn afterimage where the caster stood — volcanic touch lingers.
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(origin, 180.0):
			_damage_enemy(target, float(values.get("power", 55.0)) * 0.3)
			if target.has_method("apply_slow"):
				target.apply_slow(0.6, 1.5)
	)


## Ember's Healing Wave: Demented Shaman's genuine party heal. Every ally touched by the
## wave gets a direct mend — no splitting, no tricks. Just the warm wave of the grove.
func _cast_ability_ember_healing_wave(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_aoe_heal(data, values)


## Thorn's Toxin Ward: plant a venom-spitting ward that shoots anything that wanders close.
## Slither's signature — a single resilient turret with a long duration.
func _cast_ability_thorn_toxin_ward(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var ward := data.duplicate()
	ward["summon_count"] = 1
	ward["duration"] = maxf(float(ward.get("duration", 18.0)), 20.0)
	_cast_ability_summon_spirit(ward, values)


## Willow's Forsaken Shot: a single perfect arrow that crosses the WHOLE field, piercing
## everything in its path. Forsaken Archer's legendary one-shot — reads as a long nuke
## with a wider effective radius and no chain.
func _cast_ability_willow_forsaken_shot(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var v := values.duplicate()
	v.radius = 60.0
	var shot := data.duplicate()
	shot["_forsaken_shot"] = true
	var reach := maxf(float(values.get("range", 700.0)), 600.0)
	var primary := _nearest_enemy_in_range(reach)
	var center := primary.global_position if primary != null else _ability_aim_center(reach)
	_spawn_ability_projectile(_casting_ability_id, global_position, center)
	for target in _enemies_in_radius(center, v.radius):
		_apply_ability_hit(target, shot, v)
	_emit_ability_cast(PackedVector2Array([center, Vector2(v.radius, 0.0)]))


## Stump's Camouflage: Keeper's ability to settle unnoticed. Makes the hero such poor news
## that enemies actually stumble past — layered slow + damage-taken buff in one cast.
func _cast_ability_stump_camouflage(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_buff_self(data, values)
	# Nearby enemies moving through the undergrowth get tripped up.
	for enemy in _enemies_in_radius(global_position, 220.0):
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(0.65, 2.0)


## Sage's Volatile Pod: Nymphora's lobbed seed pod. Point-target throw, detonates on impact
## with a hefty radial slap. A signature Nuke with a strong arc.
func _cast_ability_sage_volatile_pod(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.get("range", 600.0)), 420.0)
	var center := _ability_aim_center(reach)
	_spawn_ability_projectile(_casting_ability_id, global_position, center)
	var radius := maxf(float(values.get("radius", 0.0)), 80.0)
	for enemy in _enemies_in_radius(center, radius):
		_apply_ability_hit(enemy, data, values)
	_emit_ability_cast(PackedVector2Array([center, Vector2(radius, 0.0)]))


## Volt's Wind Shield: party-wide wall of rushing air thrown just ahead of the caster.
## Shares its power across allies rather than the caster alone.
func _cast_ability_volt_wind_shield(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_shield_burst(data, values)


## Nebula's Curse of Ages: Chronos's heavy curse — every enemy in the blast feels the full
## weight of time pressing down. Wide area, slow, hefty damage, and a heavy slow that stacks
## with the base data's slow.
func _cast_ability_nebula_curse_of_ages(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var curse := data.duplicate()
	# Curse must always slow — that's the mechanic's CORE. If data has no slow, add it.
	if not curse.has("slow_on_hit"):
		curse["slow_on_hit"] = {"factor": 0.45, "duration": 3.0}
	# Add a secondary tick after the main blast: the aging effect keeps wearing them down.
	var curse_power := float(values.power) * 0.35
	var radius := float(values.get("radius", 280.0))
	_cast_ability_radius_burst(curse, values)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(global_position, radius * 0.65):
			_damage_enemy(target, curse_power)
			if target.has_method("apply_slow"):
				target.apply_slow(0.6, 1.8)
	)


## Astral's Guardian Angel: Empath's signature. High shield share for the whole party and a
## generous heal thrown in. Protects what matters most.
func _cast_ability_astral_guardian_angel(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var radius := maxf(float(values.get("radius", 280.0)), 220.0)
	for ally in _allies_in_radius(global_position, radius):
		ally.health.add_shield(float(values.power), maxf(float(values.get("duration", 6.0)), 3.0))
		ally.health.heal(float(values.power) * 0.35)
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(radius, 0.0)]))


## Rime's Chilling Touch: Glacius's focus — a stone-cold buff that turns the caster's movement
## and attacks into pure precision. A clean attack-speed buff with no side effects.
func _cast_ability_rime_chilling_touch(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_buff_self(data, values)


## --- Non-Wrench R kits (ultimates, HoN-flavoured) ---------------------------------------------

## Arclight's Thundergod's Wrath: the sky itself breaks open. Every enemy in the arena gets
## a bolt dropped directly on it — no save, no hiding.
func _cast_ability_arclight_thundergods_wrath(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var strike := data.duplicate()
	strike["global"] = true
	strike["stun_on_hit"] = {"duration": 0.5}
	_cast_ability_radius_burst(strike, values)


## Bulwark's Echo Slam: the arena RINGS for every enemy hit. Self-centred slam with a
## reverb — the more enemies in the ring, the more the ground echoes.
func _cast_ability_bulwark_echo_slam(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var hit_count := _enemies_in_radius(global_position, float(values.radius)).size()
	_cast_ability_radius_burst(data, values)
	# Echo Slam's echo: every enemy hit answers with another ring.
	for index in range(mini(hit_count, 4)):
		get_tree().create_timer(0.15 * index + 0.2).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			for enemy in _enemies_in_radius(global_position, float(values.radius) * 0.6):
				_damage_enemy(enemy, values.power * 0.2)
		)


## Warden's Life Drain: Pollywog Priest's ultimate rite. Siphons a single enemy dry --
## pulling its health straight into the caster.
func _cast_ability_warden_life_drain(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.get("range", 560.0)), 400.0)
	var target := _nearest_enemy_in_range(reach)
	if target == null:
		return
	_damage_enemy(target, values.power)
	health.heal(values.power)
	if target.has_method("apply_slow"):
		target.apply_slow(0.45, 2.5)
	_emit_ability_cast(PackedVector2Array([target.global_position, Vector2(48.0, 0.0)]))


## Cinder's Pillar of Flame: Ember Spirit's towering column that incinerates everything
## inside. Long duration zone that keeps ticking while enemies stand in it.
func _cast_ability_cinder_pillar_of_flame(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.get("range", 0.0)), 400.0)
	var center := _ability_aim_center(reach)
	_cast_ability_zone_channel(data, values)
	_spawn_ability_zone_pulse(center, float(values.get("radius", 240.0)), maxf(float(values.get("duration", 4.0)), 3.0))
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(center, float(values.radius) * 0.7):
			_damage_enemy(target, float(values.get("power", 22.0)) * 0.5)
			if target.has_method("apply_slow"):
				target.apply_slow(0.65, 1.0)
	)


## Pyra's Air Strike: Bombardier's ordnance called from above (artillery). Paint the ring,
## scream down, detonate. The sky_strike data path handles the shell already.
func _cast_ability_pyra_air_strike(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_radius_burst(data, values)


## Slag's Eruption: Magmus's volcanic tantrum. Blows the ground apart around the caster with
## a heavy knockback + lingering burn zone.
func _cast_ability_slag_eruption(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_zone_channel(data, values)
	# Eruption's signature knockback — everything inside gets flung away from the caster.
	for enemy in _enemies_in_radius(origin, float(values.get("radius", 320.0))):
		if enemy.has_method("apply_knockback"):
			var away := origin.direction_to(enemy.global_position)
			if away.length_squared() <= 0.0:
				away = Vector2.RIGHT
			enemy.apply_knockback(away * 400.0)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(origin, float(values.radius) * 0.6):
			_damage_enemy(target, float(values.get("power", 80.0)) * 0.35)
	)


## Ember's Unbreakable: Demented Shaman's ultimate. Nothing gets through — pure defensive
## zenith: the caster turns into an old oak.
func _cast_ability_ember_unbreakable(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var ultimate := data.duplicate()
	ultimate["buff_stats"] = {
		"damage_taken_mult": 0.4,
		"movement_speed_mult": 0.85,
	}
	_cast_ability_buff_self(ultimate, values)


## Thorn's Poison Burst: Slither's grand toxic bloom — every poison pocket in the area
## detonates at once.
func _cast_ability_thorn_poison_burst(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_radius_burst(data, values)
	# Lingering toxic bloom keeps ticking after the flash.
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(global_position, float(values.radius) * 0.6):
			_damage_enemy(target, float(values.get("power", 70.0)) * 0.3)
			if target.has_method("apply_slow"):
				target.apply_slow(0.6, 1.5)
	)


## Willow's Strangling Vines: Forsaken Archer's choke zone — roots snap shut and whip every
## enemy in the radius.
func _cast_ability_willow_strangling_vines(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var reach := maxf(float(values.get("range", 480.0)), 340.0)
	var center := _ability_aim_center(reach)
	var radius := maxf(float(values.get("radius", 240.0)), 180.0)
	for enemy in _enemies_in_radius(center, radius):
		_apply_ability_hit(enemy, data, values)
	_emit_ability_cast(PackedVector2Array([center, Vector2(radius, 0.0)]))
	_spawn_ability_zone_pulse(center, radius, 1.5)


## Stump's Overgrowth: the forest reclaims the arena. Chokes and rebels every hostile inside.
func _cast_ability_stump_overgrowth(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_zone_channel(data, values)
	print("[player] stump_overgrowth post-channel frame=%d" % Engine.get_process_frames())
	# Overgrowth roots enemies inside while the forest eats them.
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(origin, float(values.radius) * 0.7):
			_damage_enemy(target, float(values.get("power", 30.0)) * 0.5)
			if target.has_method("apply_slow"):
				target.apply_slow(0.45, 2.5)
	)


## Sage's Charm: Nymphora's siren song. Enemies find themselves unwillingly drawn toward the
## caster — their boots betray them.
func _cast_ability_sage_charm(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var center := global_position
	var radius := maxf(float(values.get("radius", 220.0)), 180.0)
	for target in _enemies_in_radius(center, radius):
		if not target.has_method("apply_knockback"):
			continue
		var inward := (center - target.global_position).normalized()
		target.apply_knockback(inward * 200.0)
		_arm_hazard_escape(target)
		if target.has_method("apply_slow"):
			target.apply_slow(0.65, 1.2)
		_damage_enemy(target, values.power)
	_emit_ability_cast(PackedVector2Array([center, Vector2(radius, 0.0)]))
	_spawn_ability_zone_pulse(center, radius, 1.5)


## Volt's Typhoon: Zephyr's grand spiral. A slow-moving tornado that locks everything inside
## while it spins.
func _cast_ability_volt_typhoon(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var center := _ability_aim_center(maxf(float(values.get("range", 0.0)), 380.0))
	_cast_ability_zone_channel(data, values)
	# Typhoon drags caught enemies toward its eye.
	for enemy in _enemies_in_radius(center, float(values.get("radius", 380.0))):
		if enemy.has_method("apply_knockback"):
			var inward := (center - enemy.global_position).normalized()
			enemy.apply_knockback(inward * 120.0)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		for target in _enemies_in_radius(center, float(values.radius) * 0.6):
			_damage_enemy(target, float(values.get("power", 60.0)) * 0.4)
	)


## Nebula's Chronofield: Chronos's time-stop. All enemies caught inside are frozen solid
## while the field is up.
func _cast_ability_nebula_chronofield(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var origin := global_position
	_cast_ability_zone_channel(data, values)
	# Chronofield roots caught enemies — time stands still.
	for enemy in _enemies_in_radius(origin, float(values.get("radius", 380.0))):
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(0.3, 2.5)


## Astral's As One: Empath's ultimate — pour your courage into the party. Massive heal AND
## shield for everyone in the radius.
func _cast_ability_astral_as_one(data: Dictionary, values: Dictionary, _rank: int) -> void:
	var radius := maxf(float(values.get("radius", 300.0)), 220.0)
	for ally in _allies_in_radius(global_position, radius):
		ally.health.heal(float(values.power) * 0.7)
		ally.health.add_shield(float(values.power) * 0.5, maxf(float(values.get("duration", 6.0)), 4.0))
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(radius, 0.0)]))


## Rime's Freezing Field: Glacius's absolute-zero zone. Blankets the arena in a killing cold
## that freezes everything inside solid.
func _cast_ability_rime_freezing_field(data: Dictionary, values: Dictionary, _rank: int) -> void:
	_cast_ability_zone_channel(data, values)
	_spawn_ability_zone_pulse(global_position, float(values.get("radius", 400.0)), maxf(float(values.get("duration", 5.0)), 4.0))
	# Absolute cold: lock enemies inside while the field is up.
	for enemy in _enemies_in_radius(global_position, float(values.get("radius", 400.0))):
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(0.35, 2.8)


## Smooth point-to-point dash: tween global_position from the current spot to
## `destination` over `duration` seconds. Very fast (snappy) but continuous — no
## fade-out/fade-in teleport of the sprite. Cancels any previous dash tween so
## rapid-cast dashes don't fight each other.
var _dash_tween: Tween = null

func _dash_to(destination: Vector2, duration: float = 0.14) -> void:
	if _dash_tween != null and _dash_tween.is_valid():
		_dash_tween.kill()
	_dash_tween = create_tween()
	# Shortest plausible time so it always "happens fast" but reads as a move.
	_dash_tween.tween_property(self, "global_position", destination, duration)


## Riki-style Teleport Strike: pop behind the nearest enemy and hit them hard.
func _cast_ability_blink_strike(data: Dictionary, values: Dictionary) -> void:
	var reach := float(values.get("range", 360.0))
	var nearest := _nearest_enemy_in_range(reach)
	if nearest == null:
		return
	var origin := global_position
	var landing := nearest.global_position + (global_position - nearest.global_position).normalized() * 18.0
	_dash_to(landing, 0.12)
	_apply_ability_hit(nearest, data, values)
	_emit_ability_cast(PackedVector2Array([origin, landing, Vector2(48.0, 0.0)]))


## Winter Wyvern's cold curse — self-centered ring that hits everything inside once and
## leaves its slow/stun riding on the same power payload the rest of the kit uses.
func _cast_ability_pit_slow(data: Dictionary, values: Dictionary) -> void:
	var radius := float(values.get("radius", 240.0))
	for enemy in _enemies_in_radius(global_position, radius):
		_apply_ability_hit(enemy, data, values)
	_emit_ability_cast(PackedVector2Array([global_position - Vector2(0.0, 10.0), Vector2(radius, 0.0)]))


## Naga carry fantasy: briefly overclock the attack loop so auto-hits pop off.
func _cast_ability_attack_fury(data: Dictionary, values: Dictionary) -> void:
	ability_buff_timer = maxf(ability_buff_timer, float(values.get("duration", 5.0)))
	ability_buff_stats = data.get("buff_stats", {
		"attack_interval_mult": 0.55,
		"damage_dealt_mult": 1.25,
		"movement_speed_mult": 1.1,
	})
	# No FX helper for raw fury procs; pulse a small self-centred flash so coverage tools
	# and in-game "did the press connect?" reads stay consistent with the rest of the kit.
	_emit_ability_cast(PackedVector2Array([global_position, Vector2(120.0, 0.0)]))


## Axe-style Berserker's Call: leap-slam, then force every enemy in radius onto you.
func _cast_ability_slam_taunt(data: Dictionary, values: Dictionary) -> void:
	var hop := float(values.get("dash_distance", 220.0))
	global_position += facing_direction * hop
	# Vector from each enemy back to the landing point, scaled up — pulls them onto the caster.
	var drag := absf(float(values.get("power", 220.0)))
	var radius := float(values.get("radius", 260.0))
	for enemy in _enemies_in_radius(global_position, radius):
		enemy.knockback_velocity = (global_position - enemy.global_position).normalized() * drag
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(0.1, 1.0)
	_emit_ability_cast(PackedVector2Array([global_position - Vector2(0.0, 12.0), global_position]))


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
			PlayerClass.Archetype.DASH_STRIKE, PlayerClass.Archetype.BLINK_STRIKE:
				# Teleport/dash abilities get the themed blink visual: vanish ring at
				# origin, motion streak along the travel path, appear ring at destination.
				style = PlayerClass.EffectStyle.TELEPORT
	ability_cast.emit(_casting_ability_id, style, points)


## Shared "the ability's primary hit landed on this enemy" handling: base damage plus
## whatever on-hit modifiers the ability carries (slow/stun/mark/poison).
func _apply_ability_hit(target: Node2D, data: Dictionary, values: Dictionary) -> void:
	_damage_enemy(target, values.power)
	if data.has("stun_on_hit") and target.has_method("apply_slow"):
		target.apply_slow(0.1, float(data.stun_on_hit.duration))
	if data.has("slow_on_hit") and target.has_method("apply_slow"):
		target.apply_slow(float(data.slow_on_hit.factor), float(data.slow_on_hit.duration))
	# HoN Treant Entangle-style true root: movement = 0 (distinct from a slow).
	if data.has("root_on_hit"):
		var root_duration := float(data.root_on_hit.get("duration", 1.5))
		if target.has_method("apply_movement_lock"):
			target.apply_movement_lock(root_duration)
		elif target.has_method("apply_slow"):
			target.apply_slow(0.1, root_duration)
	if data.has("mark_on_hit") and target.has_method("apply_mark"):
		target.apply_mark(float(data.mark_on_hit.bonus_pct), float(data.mark_on_hit.duration))
	if data.has("poison_on_hit") and target.has_method("apply_poison"):
		var poison: Dictionary = data.poison_on_hit
		var dps := float(poison.get("dps", poison.get("power", 8.0)))
		target.apply_poison(dps, float(poison.get("duration", 3.5)), self)


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


const ProjectileSpriteScene: PackedScene = preload("res://scenes/effects/projectile_sprite.tscn")
const ZonePulseScene: PackedScene = preload("res://scenes/effects/zone_pulse.tscn")

func _cast_ability_nuke_bolt(data: Dictionary, values: Dictionary) -> void:
	var center := _ability_aim_center(values.range)
	# Keg-style nukes lob a visible projectile that explodes on impact. The damage still
	# happens immediately (so reactions feel snappy in tests), but the on-screen read is
	# "I threw a thing and it exploded", not "random blast appeared somewhere".
	if _ability_id_has_projectile(_casting_ability_id):
		_spawn_ability_projectile(_casting_ability_id, global_position, center)
	for target in _enemies_in_radius(center, values.radius):
		_apply_ability_hit(target, data, values)
	# Keg-flavoured displacement: fling every enemy inside the blast away from the centre.
	if data.has("knockback_on_hit"):
		var kick := float(data.get("knockback_on_hit", 0.0))
		for target in _enemies_in_radius(center, values.radius):
			if not is_instance_valid(target):
				continue
			var push_dir := center.direction_to(target.global_position)
			if push_dir.length_squared() <= 0.0:
				push_dir = Vector2.RIGHT
			if target.has_method("apply_knockback"):
				target.apply_knockback(push_dir * kick)
			else:
				target.knockback_velocity = push_dir * kick
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.radius, 0.0)]))


## Projectile-worthy nukes: anything tagged with `projectile_lob` in its ability data.
static func _ability_id_has_projectile(ability_id: String) -> bool:
	var info := PlayerClass.ability_info(ability_id)
	return bool(info.get("projectile_lob", false))


## Spawn a friendly lobbed projectile. Purely visual; doesn't deal damage itself.
func _spawn_ability_projectile(ability_id: String, from_position: Vector2, to_position: Vector2, travel_time: float = 0.32, arc_height: float = 42.0, persist: bool = false) -> ProjectileSprite:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	var projectile := ProjectileSpriteScene.instantiate() as ProjectileSprite
	scene_root.add_child(projectile)
	projectile.persist_on_land = persist
	projectile.setup(ability_id, from_position, to_position, travel_time, arc_height)
	return projectile


## Persistent pulsing zone for ultimates that carry a slow/stun on-hit. The fx burst is
## ~0.4s; this keeps the ring visible for the slow duration so you can actually read it.
func _spawn_ability_zone_pulse(position: Vector2, radius: float, duration: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var zone := ZonePulseScene.instantiate() as ZonePulse
	scene_root.add_child(zone)
	var hero := PlayerClass.by_id(class_id)
	zone.setup(
		position,
		radius,
		maxf(duration, 0.9),
		Color(str(hero.get("effect_color", "#ffffff"))),
		Color(str(hero.get("effect_secondary", "#ffffff")))
	)


## Hex-wall electrocution: enemies crossing or lingering on the rim get shocked again.
func _update_energy_fields(delta: float) -> void:
	var index := 0
	while index < _energy_fields.size():
		var field: Dictionary = _energy_fields[index]
		field.life = float(field.life) - delta
		field.tick = float(field.tick) - delta
		if float(field.life) <= 0.0:
			_energy_fields.remove_at(index)
			continue
		if float(field.tick) <= 0.0:
			field.tick = 0.14
			_tick_energy_field_rim(field)
		_energy_fields[index] = field
		index += 1


func _tick_energy_field_rim(field: Dictionary) -> void:
	var center: Vector2 = field.center
	var radius := float(field.radius)
	var inner := radius * 0.58
	var outer := radius * 1.22
	var seen: Dictionary = field.on_rim
	var data: Dictionary = field.data
	var values: Dictionary = field.values
	var slow_factor := float(field.slow_factor)
	for enemy in _enemies_in_radius(center, outer):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var dist := center.distance_to((enemy as Node2D).global_position)
		# Only shock enemies actually ON the visible rim ring (between inner and outer),
		# not enemies lingering just outside the field boundary.
		var on_rim := dist >= inner and dist <= outer
		var id := (enemy as Node).get_instance_id()
		var was_on_rim := bool(seen.get(id, false))
		if on_rim:
			if enemy.has_method("apply_shock"):
				enemy.apply_shock(1.4)
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_factor, 1.2)
			var tick_values := values.duplicate()
			tick_values.power = float(values.get("power", 12.0)) * (0.55 if was_on_rim else 0.9)
			_apply_ability_hit(enemy, data, tick_values)
			seen[id] = true
		else:
			seen[id] = false
	field.on_rim = seen


func _ability_aim_center(max_range: float) -> Vector2:
	# Point/vector kit casts throw to the cursor even after _cast_known_ability clears
	# _pending_ability_id — otherwise confirm would snap to the nearest enemy.
	var mode := str(TARGETED_ABILITIES.get(_casting_ability_id, ""))
	if not _pending_ability_id.is_empty() or mode == "point" or mode == "vector":
		var clamp_dir := global_position.direction_to(aim_world_position)
		if clamp_dir.length_squared() <= 0.0:
			clamp_dir = facing_direction
		var dist := global_position.distance_to(aim_world_position)
		return global_position + clamp_dir * minf(dist, max_range)
	var target := _nearest_enemy_in_range(max_range)
	if target != null:
		return target.global_position
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	return global_position + direction * minf(max_range, global_position.distance_to(aim_world_position))


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
	# Global ults (Thundergod's Wrath) strike EVERY live enemy in the arena — a bolt per
	# target instead of a self-centred ring. Covers the whole arena regardless of proximity.
	if bool(data.get("global", false)):
		var struck := 0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or not enemy is Node2D:
				continue
			if enemy.has_method("is_damageable") and not enemy.is_damageable():
				continue
			_apply_ability_hit(enemy as Node2D, data, values)
			_emit_ability_cast(PackedVector2Array([(enemy as Node2D).global_position, Vector2(values.radius, 0.0)]))
			struck += 1
		if struck == 0:
			_emit_ability_cast(PackedVector2Array([global_position, Vector2(values.radius, 0.0)]))
		return
	var center := global_position
	if values.range > 0.0:
		var travel := minf(values.range, global_position.distance_to(aim_world_position))
		center = global_position + global_position.direction_to(aim_world_position) * travel
	# Artillery-style sky strike: paint the mark, ordnance screams down after a short fuse,
	# then the whole zone detonates at once. Non-sky strikes land instantly as before.
	if bool(data.get("sky_strike", false)):
		_spawn_sky_strike(data, values, center, float(data.get("sky_delay", 0.6)))
		return
	for target in _enemies_in_radius(center, values.radius):
		_apply_ability_hit(target, data, values)
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.radius, 0.0)]))


## Artillery Barrage: paint the target ring instantly, then the shell drops from above and
## the ring detonates. The telegraph stays on the ground for the full fuse so everyone can
## see exactly where the shell is about to land.
func _spawn_sky_strike(data: Dictionary, values: Dictionary, center: Vector2, fuse: float) -> void:
	_spawn_ability_zone_pulse(center, values.radius, fuse + 0.4)
	var captured := values.duplicate()
	captured["_sky_center"] = center
	var delay := maxf(0.05, fuse)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		_on_sky_strike_land(data, captured)
	)


func _on_sky_strike_land(data: Dictionary, values: Dictionary) -> void:
	if not is_inside_tree():
		return
	var center: Vector2 = values.get("_sky_center", global_position)
	# The shell itself: a fast-falling lob visual from above the arena so the blast clearly
	# originates "from the sky" rather than from the caster.
	_spawn_ability_projectile(_casting_ability_id, center + Vector2(0.0, -values.radius * 1.6), center)
	for target in _enemies_in_radius(center, float(values.radius)):
		_apply_ability_hit(target, data, values)
	_emit_ability_cast(PackedVector2Array([center, Vector2(float(values.radius), 0.0)]))


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
	# Smooth dash: move the sprite continuously (very fast) instead of instant teleport.
	_dash_to(destination, 0.14)
	# points: [origin, destination, Vector2(ring_radius, 0)] for the TELEPORT style.
	_emit_ability_cast(PackedVector2Array([origin, destination, Vector2(float(values.radius) * 0.9, 0.0)]))
	# Dragon Fire: the dash scorches a lingering trail of flame along the whole path.
	if bool(data.get("fire_trail", false)):
		_spawn_fire_trail(origin, destination, float(values.power) * 0.35)


## Cinder's Dragon Fire leaves a burning strip along the dash line. The trail ticks damage
## onto anything still standing in it a moment later, reading as "the path keeps burning".
func _spawn_fire_trail(origin: Vector2, destination: Vector2, tick_power: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var length := origin.distance_to(destination)
	if length <= 1.0:
		return
	var trail := Line2D.new()
	trail.default_color = Color(1.0, 0.55, 0.15, 0.0)
	trail.width = 14.0
	trail.add_point(origin)
	trail.add_point(destination)
	trail.z_index = 24
	scene_root.add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "default_color:a", 0.8, 0.08)
	tween.tween_interval(0.5)
	tween.tween_property(trail, "default_color:a", 0.0, 0.5)
	tween.tween_callback(trail.queue_free)
	# Lingering burn tick along the strip once the flash settles.
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var mid := origin.lerp(destination, 0.5)
		var hit_radius := origin.distance_to(destination) * 0.5 + 26.0
		for target in _enemies_in_radius(mid, hit_radius):
			_damage_enemy(target, tick_power))


func _cast_ability_blink(_data: Dictionary, values: Dictionary) -> void:
	var direction := global_position.direction_to(aim_world_position)
	if direction.length_squared() <= 0.0:
		direction = facing_direction
	var origin := global_position
	var destination := origin + direction * values.dash_distance
	_dash_to(destination, 0.14)
	# Hit is registered at destination (the tween moves the sprite; the hit is instant).
	for target in _enemies_in_radius(destination, values.radius):
		_apply_ability_hit(target, _data, values)
	# points: [origin, destination, Vector2(ring_radius, 0)] for the TELEPORT style.
	_emit_ability_cast(PackedVector2Array([origin, destination, Vector2(float(values.radius) * 0.9, 0.0)]))


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
		if not _is_support_target(ally):
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
			if not _is_support_target(ally):
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
func _cast_ability_push_pull_burst(data: Dictionary, values: Dictionary) -> void:
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
		_arm_hazard_escape(target)
	# Apply slow/stun from the data so big zone-ults (Energy Field, Shatter Nova, etc.)
	# actually lock people in place while the field is up.
	for target in _enemies_in_radius(center, values.radius):
		if data.has("slow_on_hit") and target.has_method("apply_slow"):
			target.apply_slow(float(data.slow_on_hit.factor), float(data.slow_on_hit.duration))
		if data.has("stun_on_hit") and target.has_method("apply_slow"):
			target.apply_slow(0.1, float(data.stun_on_hit.duration))
		_damage_enemy(target, values.power)
	_emit_ability_cast(PackedVector2Array([center, Vector2(values.radius, 0.0)]))
	# Leave a visible zone: the fx burst is ~0.4s, but the field itself persists for the
	# slow's full duration — Energy Field 8s, Arena Chill 3s, etc.
	if data.has("slow_on_hit") or data.has("stun_on_hit"):
		var zone_duration := 0.0
		if data.has("slow_on_hit"):
			zone_duration = maxf(zone_duration, float(data.slow_on_hit.duration))
		if data.has("stun_on_hit"):
			zone_duration = maxf(zone_duration + 0.8, float(data.stun_on_hit.duration))
		_spawn_ability_zone_pulse(center, values.radius, clampf(zone_duration, 1.5, 12.0))


## Shoving an enemy near the arena's hazard gives it a couple of chances to crawl back out —
## the dunk burst still lands first, so a well-aimed shove is lethal but not an instant delete.
func _arm_hazard_escape(target: Node2D) -> void:
	if target is Enemy and not target.flying:
		target.hazard_escapes_left = mini(target.hazard_escapes_left + 1, 2)


## Hover heroes skim over the lava on purpose, but the heat still licks at them —
## half-rate DoT while hovering, full DoT while grounded. 0.5s grace after exit so a
## jitter-heavy crossing doesn't double-ping the first tick on re-entry.
const HAZARD_GRACE_SECONDS := 0.5
var _hazard_grace_timer := 0.0
var _hazard_inside := false
## True only while the current hazard tick is the water-crossing one (not lava) — gates
## the movement slow so it never touches the unrelated lava-dunk mechanic.
var _in_water_hazard := false
## Water-crossing (Hoverboard): percent-of-max-health drain instead of a flat DPS — the
## flat 8/s read as "too little" regardless of hero HP; scaling off max_health means it
## stays a real risk for the tankiest hero too, not just the squishiest, and a mild slow.
## "little bit" per the design ask on the slow, not a hard stop, since the item's whole
## point is that the void is now crossable at all — just don't loiter in it.
const WATER_HAZARD_PERCENT_PER_SECOND := 0.05
const LAVA_HAZARD_PERCENT_PER_SECOND := 0.05
const WATER_CROSSING_SPEED_MULT := 0.85

func _update_hazard(delta: float) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	if _jump_t >= 0.0:
		if _hazard_inside:
			_hazard_inside = false
			_in_water_hazard = false
			_hazard_visual_off()
		return
	if _arena == null:
		_arena = Arena.arena_root(self)
		if _arena == null:
			return
	var hazard := _arena.hazard_at(global_position)
	if hazard.is_empty() and _arena.is_in_void(global_position):
		if _arena.is_lava_void():
			hazard = {"type": "lava", "percent_per_second": LAVA_HAZARD_PERCENT_PER_SECOND}
		else:
			hazard = {"type": "water", "percent_per_second": WATER_HAZARD_PERCENT_PER_SECOND}
	if hazard.is_empty():
		if _hazard_inside:
			_hazard_inside = false
			_in_water_hazard = false
			_hazard_grace_timer = HAZARD_GRACE_SECONDS
			_hazard_visual_off()
		else:
			_hazard_grace_timer = maxf(0.0, _hazard_grace_timer - delta)
		return

	# Inside an active hazard this frame.
	if _hazard_inside:
		# Already inside — keep ticking on every physics frame after grace.
		if _hazard_grace_timer > 0.0:
			_hazard_grace_timer = maxf(0.0, _hazard_grace_timer - delta)
			return
		_apply_hazard_tick(hazard, delta)
	else:
		if _hazard_grace_timer > 0.0:
			# Re-entered during grace — skip this frame, keep countdown.
			_hazard_grace_timer = maxf(0.0, _hazard_grace_timer - delta)
			return
		_hazard_inside = true
		_in_water_hazard = str(hazard.get("type", "lava")) == "water"
		_hazard_visual_on(str(hazard.get("type", "lava")))
		_apply_hazard_tick(hazard, delta)


func _apply_hazard_tick(hazard: Dictionary, delta: float) -> void:
	var dps := float(hazard.get("player_dot", 14.0))
	if str(hazard.get("type", "lava")) != "water" and not hazard.has("percent_per_second"):
		# Lava/slag pools authored with only a flat tick still scale with max HP so
		# a late-run tank cannot camp the bowl.
		dps = health.max_health * LAVA_HAZARD_PERCENT_PER_SECOND
	if hazard.has("percent_per_second"):
		dps = health.max_health * float(hazard.percent_per_second)
	if hovering:
		dps *= Arena.HAZARD_HOVER_REDUCTION
	if dps <= 0.0:
		return
	health.take_damage(dps * delta, self)


func _hazard_visual_on(_hazard_type: String) -> void:
	if sprite == null:
		return
	sprite.modulate = Color(0.75, 0.95, 1.45, 1.0) if _hazard_type == "water" else Color(1.45, 0.85, 0.65, 1.0)


func _hazard_visual_off() -> void:
	if sprite != null:
		sprite.modulate = Color.WHITE


func _apply_ability_buff(stats: Dictionary, duration: float) -> void:
	_clear_ability_buff()
	ability_buff_stats = stats
	ability_buff_timer = duration
	if stats.has("damage_taken_mult"):
		_ability_damage_taken_factor = float(stats.damage_taken_mult)
	_refresh_taken_mult()


func _clear_ability_buff() -> void:
	if _ability_damage_taken_factor != 1.0:
		_ability_damage_taken_factor = 1.0
		_refresh_taken_mult()
	ability_buff_stats = {}
	ability_buff_timer = 0.0


func _update_ability_buff(delta: float) -> void:
	if ability_buff_timer <= 0.0:
		return
	ability_buff_timer = maxf(0.0, ability_buff_timer - delta)
	if ability_buff_timer <= 0.0:
		_clear_ability_buff()


func apply_phase_cloak(duration: float) -> void:
	phase_cloak_timer = maxf(phase_cloak_timer, duration)
	if sprite != null:
		sprite.modulate.a = 0.55


func is_phase_cloaked() -> bool:
	return phase_cloak_timer > 0.0


func _update_phase_cloak(delta: float) -> void:
	if phase_cloak_timer <= 0.0:
		return
	phase_cloak_timer = maxf(0.0, phase_cloak_timer - delta)
	if phase_cloak_timer <= 0.0 and sprite != null:
		sprite.modulate.a = 1.0


func _refresh_secondary_bar() -> void:
	if world_health_bar == null:
		return
	if not is_local_player:
		world_health_bar.show_local_indicators(false)
		return
	world_health_bar.set_secondary_cooldown(secondary_cooldown, secondary_cooldown_max)
	# Show the hold-charge bar under the health bar while RMB is winding up.
	var charging := simulation_mode != SimulationMode.CPU and secondary_cooldown <= 0.0 and secondary_charge > 0.0 and secondary_kind != "wall"
	world_health_bar.set_secondary_charge(_secondary_charge_t() if charging else 0.0)


func _update_secondary(delta: float, held: bool) -> void:
	# Cooldown ticks in _tick_cooldowns so it still runs while dead.
	# CPUs fire the secondary instantly at full strength (no hold charge) so bots
	# keep using their kit without a long wind-up.
	if simulation_mode == SimulationMode.CPU:
		_secondary_was_held = held
		if held and secondary_cooldown <= 0.0:
			secondary_charge = 0.0
			_cast_secondary()
			_refresh_secondary_bar()
		return
	var just_pressed := held and not _secondary_was_held
	var just_released := (not held) and _secondary_was_held
	_secondary_was_held = held
	# The wall is a draw-to-place spell: it uses the same hold-charge, but the charge
	# grows the max drawable length (bigger wall the longer you hold) and boosts the
	# heal pulse. It does NOT fire on a release tap like the burst secondaries.
	if secondary_kind == "wall" and simulation_mode != SimulationMode.CPU:
		if just_pressed and secondary_cooldown <= 0.0:
			_drawing_wall = true
			_wall_draw_age = 0.0
			secondary_charge = 0.0
			_wall_points = PackedVector2Array([global_position])
		if _drawing_wall:
			_wall_draw_age += delta
			_append_wall_point(aim_world_position)
			# Longer hold = longer wall + stronger heal on commit.
			secondary_charge = minf(SECONDARY_CHARGE_MAX, secondary_charge + delta)
			if just_released or _wall_draw_age >= 2.0 or _wall_length() >= PlayerClass.WALL_MAX_LENGTH * _sec_radius_mult():
				_commit_wall()
				secondary_charge = 0.0
		_refresh_secondary_bar()
		return
	# Hold-to-charge: while RMB is held and off cooldown, the wind-up bar fills.
	# Releasing fires the secondary with a damage/area bonus scaled by the charge.
	if just_pressed and secondary_cooldown <= 0.0:
		secondary_charge = 0.0
	elif just_released and secondary_cooldown <= 0.0 and not _drawing_wall:
		# Release fires the charged secondary. Reset the wind-up after casting.
		_cast_secondary()
		secondary_charge = 0.0
		_refresh_secondary_bar()
	# Tick the charge forward while actively charging.
	if _secondary_was_held and secondary_cooldown <= 0.0:
		secondary_charge = minf(SECONDARY_CHARGE_MAX, secondary_charge + delta)
	_refresh_secondary_bar()


func _append_wall_point(point: Vector2) -> void:
	if _wall_points.is_empty():
		_wall_points.append(point)
		return
	if _wall_points[_wall_points.size() - 1].distance_to(point) < 18.0:
		return
	if _wall_length() + _wall_points[_wall_points.size() - 1].distance_to(point) > PlayerClass.WALL_MAX_LENGTH * _sec_radius_mult():
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
	var charge_t := _secondary_charge_t()
	# Bigger wall + stronger heal pulse the longer it was charged.
	var wall_radius := 90.0 * _sec_radius_mult()
	if points.size() < 2:
		var facing := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
		var origin := global_position + facing * 36.0
		var across := facing.orthogonal()
		points = PackedVector2Array([origin - across * wall_radius, origin + across * wall_radius])
	_spawn_support_wall(points)
	_pulse_allies(global_position, PlayerClass.SECONDARY_RADIUS * _sec_radius_mult(), PlayerClass.SECONDARY_HEAL * 0.6 * _sec_effect_mult(), 22.0)
	secondary_charge = 0.0
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
		"vine_tangle":
			_cast_secondary_vine_tangle()
		"ice_block":
			_cast_secondary_ice_block()
		"heat_burst":
			_cast_secondary_heat_burst()
		"blast_jump":
			_cast_secondary_blast_jump()
		"magma_armor":
			_cast_secondary_magma_armor()
		"cinder_veil":
			_cast_secondary_cinder_veil()
		"bramble_snare":
			_cast_secondary_bramble_snare()
		"windstep":
			_cast_secondary_windstep()
		"oak_bark":
			_cast_secondary_oak_bark()
		"bloom_mend":
			_cast_secondary_bloom_mend()
		"gale_gust":
			_cast_secondary_gale_gust()
		"time_skip":
			_cast_secondary_time_skip()
		"ward_light":
			_cast_secondary_ward_light()
		"glacial_nova":
			_cast_secondary_glacial_nova()
		_:
			_cast_secondary_repulse()
	_start_secondary_cooldown()


func _start_secondary_cooldown() -> void:
	secondary_cooldown = secondary_cooldown_max
	_refresh_secondary_bar()


func _secondary_center() -> Vector2:
	var dist := global_position.distance_to(aim_world_position)
	if dist <= 48.0:
		return global_position
	var travel := minf(PlayerClass.SECONDARY_RADIUS, dist)
	return global_position + global_position.direction_to(aim_world_position) * travel


## 0..1 fraction of the RMB charge currently banked (before it resets on release).
func _secondary_charge_t() -> float:
	return clampf(secondary_charge / SECONDARY_CHARGE_MAX, 0.0, 1.0)


## Damage multiplier at the current charge: 1.0 on a quick tap, up to
## SECONDARY_CHARGE_DAMAGE_MULT_MAX at full charge.
func _sec_dmg() -> float:
	return PlayerClass.SECONDARY_DAMAGE * lerpf(1.0, SECONDARY_CHARGE_DAMAGE_MULT_MAX, _secondary_charge_t())


## Radius/area multiplier at the current charge: 1.0 on tap, up to
## SECONDARY_CHARGE_RADIUS_MULT_MAX at full charge.
func _sec_radius_mult() -> float:
	return lerpf(1.0, SECONDARY_CHARGE_RADIUS_MULT_MAX, _secondary_charge_t())


## Effect/duration multiplier at the current charge — the "second effect" ramps
## up in strength (longer/stronger slow, bigger heal, higher shield) as you hold.
func _sec_effect_mult() -> float:
	return 1.0 + _secondary_charge_t() * 0.9


func _cast_secondary_repulse() -> void:
	var center := _secondary_center()
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	var dmg := _sec_dmg()
	for target in _pvp_hosts_in_radius(center, radius):
		_damage_enemy(target, dmg)
		_knock_away_from(target, center, 640.0 * _sec_radius_mult())
	if global_position.distance_to(center) <= radius + BODY_RADIUS:
		_knock_away_from(self, center, 920.0)
	_pulse_allies(center, radius, PlayerClass.SECONDARY_HEAL, 28.0 * _sec_effect_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BLAST, PackedVector2Array([global_position, center, Vector2(radius, 0.0)]))


func _cast_secondary_freeze() -> void:
	var center := _secondary_center()
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	for target in _enemies_in_radius(center, radius):
		_damage_enemy(target, _sec_dmg() * 0.7)
		if target.has_method("apply_slow"):
			target.apply_slow(0.12, 2.6 * _sec_effect_mult())
	_pulse_allies(center, radius, PlayerClass.SECONDARY_HEAL, 0.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([center, Vector2(radius, 0.0)]))


func _cast_secondary_volt_mend() -> void:
	var center := _secondary_center()
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	for target in _enemies_in_radius(center, radius):
		_damage_enemy(target, _sec_dmg())
		if target.has_method("apply_knockback"):
			var away := center.direction_to(target.global_position)
			if away.length_squared() <= 0.0:
				away = facing_direction
			target.apply_knockback(away * 560.0 * _sec_radius_mult())
	_pulse_allies(center, radius, PlayerClass.SECONDARY_HEAL, 0.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BLAST, PackedVector2Array([global_position, center, Vector2(radius, 0.0)]))


func _cast_secondary_rime_ward() -> void:
	var center := _secondary_center()
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	for target in _enemies_in_radius(center, radius):
		_damage_enemy(target, _sec_dmg() * 0.75)
		if target.has_method("apply_slow"):
			target.apply_slow(0.4, 2.2 * _sec_effect_mult())
	_pulse_allies(center, radius, PlayerClass.SECONDARY_HEAL * 0.7, 40.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([center, Vector2(radius, 0.0)]))


func _cast_secondary_vine_tangle() -> void:
	var center := global_position
	var radius := PlayerClass.SECONDARY_RADIUS * 0.92 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(center, radius):
		_damage_enemy(target, _sec_dmg() * 0.55)
		if target.has_method("apply_slow"):
			target.apply_slow(0.14, 2.8 * _sec_effect_mult())
		_knock_away_from(target, center, 220.0 * _sec_radius_mult())
	_pulse_allies(center, radius, PlayerClass.SECONDARY_HEAL * 0.45, 0.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.WAVE, PackedVector2Array([center, Vector2(radius, 0.0)]))


func _cast_secondary_ice_block() -> void:
	_secondary_invuln_timer = 1.05 * _sec_effect_mult()
	health.invulnerable = true
	var radius := PlayerClass.SECONDARY_RADIUS * 0.7 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(global_position, radius):
		if target.has_method("apply_slow"):
			target.apply_slow(0.22, 1.8 * _sec_effect_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([global_position, Vector2(radius, 0.0)]))


func _cast_secondary_heat_burst() -> void:
	var dir := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
	var reach := 240.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_cone(global_position, dir, reach, 42.0):
		_damage_enemy(target, _sec_dmg())
		_knock_away_from(target, global_position, 780.0 * _sec_radius_mult())
	_secondary_move_mult = 1.28
	_secondary_move_timer = 1.6 * _sec_effect_mult()
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.ARC, PackedVector2Array([global_position, global_position + dir * reach]))


func _cast_secondary_blast_jump() -> void:
	var away := -facing_direction
	if away.length_squared() <= 0.0:
		away = Vector2.LEFT
	var radius := 150.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(global_position, radius):
		_damage_enemy(target, _sec_dmg() * 0.85)
		_knock_away_from(target, global_position, 820.0 * _sec_radius_mult())
	var origin := global_position
	global_position += away * (210.0 * _sec_radius_mult())
	apply_knockback(away * 380.0 * _sec_radius_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.TELEPORT, PackedVector2Array([origin, global_position, Vector2(52.0, 0.0)]))


func _cast_secondary_magma_armor() -> void:
	health.add_shield(48.0 * _sec_effect_mult(), 3.4 * _sec_effect_mult())
	var radius := 150.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(global_position, radius):
		if target.has_method("apply_slow"):
			target.apply_slow(0.45, 1.6 * _sec_effect_mult())
		_knock_away_from(target, global_position, 360.0 * _sec_radius_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([global_position, Vector2(radius, 0.0)]))


func _cast_secondary_cinder_veil() -> void:
	apply_phase_cloak(2.2 * _sec_effect_mult())
	health.heal(PlayerClass.SECONDARY_HEAL * 0.7 * _sec_effect_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([global_position, Vector2(80.0 * _sec_radius_mult(), 0.0)]))


func _cast_secondary_bramble_snare() -> void:
	var center := _secondary_center()
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(center, radius):
		_damage_enemy(target, _sec_dmg() * 0.5)
		if target.has_method("apply_slow"):
			target.apply_slow(0.16, 3.0 * _sec_effect_mult())
		if target.has_method("apply_poison"):
			target.apply_poison(4.0 * _sec_effect_mult(), 2.5, self)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([center, Vector2(radius, 0.0)]))


func _cast_secondary_windstep() -> void:
	var dir := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
	var from := global_position
	var dest := from + dir * (240.0 * _sec_radius_mult())
	_dash_to(dest, 0.12)
	var radius := 90.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(from.lerp(dest, 0.5), radius):
		if target.has_method("apply_slow"):
			target.apply_slow(0.4, 1.4 * _sec_effect_mult())
	_secondary_move_mult = 1.22
	_secondary_move_timer = 1.2 * _sec_effect_mult()
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.TELEPORT, PackedVector2Array([from, global_position, Vector2(44.0, 0.0)]))


func _cast_secondary_oak_bark() -> void:
	_secondary_dr_mult = 0.55
	_secondary_dr_timer = 2.6 * _sec_effect_mult()
	_refresh_taken_mult()
	var radius := 130.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(global_position, radius):
		_knock_away_from(target, global_position, 480.0 * _sec_radius_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([global_position, Vector2(radius, 0.0)]))


func _cast_secondary_bloom_mend() -> void:
	var radius := PlayerClass.SECONDARY_RADIUS * 1.15 * _sec_radius_mult()
	_pulse_allies(global_position, radius, PlayerClass.SECONDARY_HEAL * 1.35 * _sec_effect_mult(), 18.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.WAVE, PackedVector2Array([global_position, Vector2(radius, 0.0)]))


func _cast_secondary_gale_gust() -> void:
	var dir := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
	var reach := 280.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_cone(global_position, dir, reach, 38.0):
		_damage_enemy(target, _sec_dmg() * 0.6)
		_knock_away_from(target, global_position, 980.0 * _sec_radius_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.ARC, PackedVector2Array([global_position, global_position + dir * reach]))


func _cast_secondary_time_skip() -> void:
	var origin := global_position
	var dir := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
	var radius := 140.0 * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(origin, radius):
		if target.has_method("apply_slow"):
			target.apply_slow(0.35, 1.8 * _sec_effect_mult())
	global_position += dir * (260.0 * _sec_radius_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.TELEPORT, PackedVector2Array([origin, global_position, Vector2(48.0, 0.0)]))


func _cast_secondary_ward_light() -> void:
	var radius := PlayerClass.SECONDARY_RADIUS * 1.2 * _sec_radius_mult()
	_pulse_allies(global_position, radius, PlayerClass.SECONDARY_HEAL * 0.4 * _sec_effect_mult(), 52.0)
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([global_position, Vector2(radius, 0.0)]))


func _cast_secondary_glacial_nova() -> void:
	var center := global_position
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	for target in _pvp_hosts_in_radius(center, radius):
		_damage_enemy(target, _sec_dmg() * 0.65)
		if target.has_method("apply_slow"):
			target.apply_slow(0.12, 2.8 * _sec_effect_mult())
	secondary_fx.emit(class_id, PlayerClass.EffectStyle.BURST, PackedVector2Array([center, Vector2(radius, 0.0)]))


func _pvp_hosts_in_cone(origin: Vector2, direction: Vector2, reach: float, half_angle_deg: float) -> Array[Node2D]:
	var dir := direction.normalized()
	var found: Array[Node2D] = []
	var limit := deg_to_rad(half_angle_deg)
	for target in _pvp_hosts_in_radius(origin, reach):
		var to := origin.direction_to(target.global_position)
		if to.length_squared() <= 0.0001 or absf(dir.angle_to(to)) <= limit:
			found.append(target)
	return found


func _tick_secondary_effects(delta: float) -> void:
	if crowd_slow_timer > 0.0:
		crowd_slow_timer = maxf(0.0, crowd_slow_timer - delta)
		if crowd_slow_timer <= 0.0:
			crowd_slow_factor = 1.0
	if _secondary_move_timer > 0.0:
		_secondary_move_timer = maxf(0.0, _secondary_move_timer - delta)
		if _secondary_move_timer <= 0.0:
			_secondary_move_mult = 1.0
	if _secondary_dr_timer > 0.0:
		_secondary_dr_timer = maxf(0.0, _secondary_dr_timer - delta)
		if _secondary_dr_timer <= 0.0:
			_secondary_dr_mult = 1.0
			_refresh_taken_mult()
	if _secondary_invuln_timer > 0.0:
		_secondary_invuln_timer = maxf(0.0, _secondary_invuln_timer - delta)
		if _secondary_invuln_timer <= 0.0:
			health.invulnerable = false


func _refresh_taken_mult() -> void:
	health.damage_taken_multiplier = base_damage_taken_multiplier * _ability_damage_taken_factor * _secondary_dr_mult


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
		if not _is_support_target(ally):
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
	_fire_weapon_once()
	if double_blast_chance > 0.0 and randf() < double_blast_chance:
		_fire_weapon_once()
	_spawn_extra_projectiles()


func _fire_weapon_once() -> void:
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


func _spawn_extra_projectiles() -> void:
	var extra := extra_projectiles
	if extra <= 0:
		extra = extra_shots
	if extra <= 0:
		return
	var parent := get_parent()
	if parent == null or not parent.has_method("spawn_player_projectile"):
		return
	for index in extra:
		var spread := 0.0 if extra == 1 else lerpf(-0.28, 0.28, float(index) / float(extra - 1))
		var direction := facing_direction.rotated(spread)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		parent.call("spawn_player_projectile", global_position, direction.normalized(), self)


func _tick_pulse_blast(delta: float) -> void:
	if pulse_interval <= 0.0:
		return
	pulse_timer += delta
	if pulse_timer < pulse_interval:
		return
	pulse_timer = 0.0
	for target in _pvp_hosts_in_radius(global_position, pulse_radius):
		_weapon_hit(target, weapon_damage)
	staff_cast.emit(class_id, PackedVector2Array([
		global_position,
		global_position,
		Vector2(pulse_radius, 0.0),
	]))


func _cast_chain_bolt() -> void:
	var extra_hops := int(round(float(PlayerClass.ATTACK_CHARGE_EXTRA_BOUNCES) * _shot_charge))
	var hops := chain_count + extra_hops
	var saved_range := chain_range
	chain_range = maxf(chain_range, 48.0) * _charge_size_mult()
	var primary := _find_primary_pvp_target()
	var points := PackedVector2Array([global_position])
	if primary == null:
		points.append(_charge_lock_impact if _charge_lock_impact != Vector2.ZERO else global_position + facing_direction * minf(attack_range, 180.0))
		staff_cast.emit(class_id, points)
		chain_range = saved_range
		return

	var struck: Array[Node2D] = [primary]
	points.append(primary.global_position)
	_weapon_hit(primary, weapon_damage)
	var previous := primary

	for chain_index in hops:
		var next_target := _find_chain_pvp_target(previous, struck)
		if next_target == null:
			break
		struck.append(next_target)
		points.append(next_target.global_position)
		var chain_damage := weapon_damage * pow(chain_damage_multiplier, chain_index + 1)
		_weapon_hit(next_target, chain_damage)
		previous = next_target

	chain_range = saved_range
	staff_cast.emit(class_id, points)


func _cast_cone_slam() -> void:
	var size := _charge_size_mult()
	var reach := attack_range * size
	var half_deg := cone_half_angle_degrees * size
	var half_angle := deg_to_rad(half_deg)
	for target in _pvp_hosts_in_radius(global_position, reach):
		var to_target := global_position.direction_to(target.global_position)
		if to_target.length_squared() > 0.0 and absf(facing_direction.angle_to(to_target)) > half_angle:
			continue
		_weapon_hit(target, weapon_damage)
	staff_cast.emit(class_id, PackedVector2Array([
		global_position,
		Vector2(reach, half_deg),
		global_position + facing_direction * reach,
	]))


func _cast_energy_blast() -> void:
	var impact := _charge_lock_impact if _charge_lock_impact != Vector2.ZERO else _charge_aim_point()
	_detonate_energy_blast(impact)


func _detonate_energy_blast(impact: Vector2) -> void:
	var radius := blast_radius * _charge_size_mult()
	for pulse_index in maxi(1, blast_pulses):
		var pulse_damage := weapon_damage if pulse_index == 0 else weapon_damage * PlayerClass.BLAST_AFTERSHOCK_DAMAGE
		for target in _pvp_hosts_in_radius(impact, radius):
			if pulse_index == 0:
				_weapon_hit(target, weapon_damage)
			else:
				_weapon_hit(target, pulse_damage)
	staff_cast.emit(class_id, PackedVector2Array([
		global_position,
		impact,
		Vector2(radius, 0.0),
	]))


func _cast_mending_bolt() -> void:
	var primary := _find_primary_pvp_target()
	if primary == null:
		primary = _find_primary_target()
	var points := PackedVector2Array([global_position])
	var impact := _charge_lock_impact if _charge_lock_impact != Vector2.ZERO else (primary.global_position if primary != null else global_position + facing_direction * minf(attack_range, 180.0))
	if primary == null:
		points.append(impact)
	else:
		points.append(primary.global_position)
		_weapon_hit(primary, weapon_damage)
	var extra := int(round(lerpf(0.0, 4.0, _shot_charge)))
	if extra > 0 and primary != null:
		var struck: Array[Node2D] = [primary]
		var saved_range := chain_range
		chain_range = 90.0 * _charge_size_mult()
		var previous := primary
		for _i in extra:
			var next_target := _find_chain_pvp_target(previous, struck)
			if next_target == null:
				break
			struck.append(next_target)
			points.append(next_target.global_position)
			_weapon_hit(next_target, weapon_damage * 0.7)
			previous = next_target
		chain_range = saved_range
	if _shot_charge > 0.12:
		var heal_r := lerpf(40.0, 180.0, _shot_charge)
		var heal_amt := weapon_damage * _charge_damage_mult() * 0.35
		for ally in _allies_in_radius(global_position, heal_r):
			if ally.health != null:
				ally.health.heal(heal_amt)
	staff_cast.emit(class_id, points)


func _cast_frost_shard() -> void:
	var primary := _find_primary_pvp_target()
	var burst_center := _charge_lock_impact if _charge_lock_impact != Vector2.ZERO else (primary.global_position if primary != null else global_position + facing_direction * minf(attack_range, 260.0))
	var radius := frost_burst_radius * _charge_size_mult()
	for target in _pvp_hosts_in_radius(burst_center, radius):
		_weapon_hit(target, weapon_damage)
		if target.has_method("apply_slow"):
			target.apply_slow(frost_slow_factor, frost_slow_duration * lerpf(1.0, 1.6, _shot_charge))
	staff_cast.emit(class_id, PackedVector2Array([burst_center, Vector2(radius, 0.0)]))


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


## Rift Clash: everything worth hitting. Enemies and rival-team players share "hostile"
## picks for beams/blasts; co-op keeps the old behaviour (only the "enemies" group).
func _pvp_hosts_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var found := _enemies_in_radius(center, radius)
	if not GameRuntime.is_rift_clash() or team_id == "":
		return found
	var radius_sq := radius * radius
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var rival := candidate as Player
		if rival.team_id == "" or rival.team_id == team_id:
			continue
		if not rival.active or rival.health.is_dead:
			continue
		if rival.is_pvp_protected():
			continue
		if center.distance_squared_to(rival.global_position) <= radius_sq:
			found.append(rival)
	return found


func _find_primary_pvp_target() -> Node2D:
	var segment_end := global_position + facing_direction * attack_range
	var best_target: Node2D = _find_primary_target()
	var best_score := INF
	if best_target != null:
		var projected := Geometry2D.get_closest_point_to_segment(best_target.global_position, global_position, segment_end)
		best_score = best_target.global_position.distance_to(projected) * 4.0 + global_position.distance_to(projected) * 0.05
	if GameRuntime.is_rift_clash() and team_id != "":
		var projected := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, Vector2.ZERO, segment_end)
		for candidate in get_tree().get_nodes_in_group("players"):
			var rival := candidate as Player
			if not is_instance_valid(rival) or rival.team_id == "" or rival.team_id == team_id:
				continue
			if not rival.active or rival.health.is_dead:
				continue
			if rival.is_pvp_protected():
				continue
			if not rival is Node2D:
				continue
			projected = Geometry2D.get_closest_point_to_segment(rival.global_position, global_position, segment_end)
			var distance_to_beam := rival.global_position.distance_to(projected)
			var forward_distance := global_position.distance_to(projected)
			if distance_to_beam > aim_assist_radius or forward_distance > attack_range:
				continue
			var score := distance_to_beam * 4.0 + forward_distance * 0.05
			if score < best_score:
				best_score = score
				best_target = rival
	return best_target


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


func _find_chain_pvp_target(origin: Node2D, excluded: Array[Node2D]) -> Node2D:
	var nearest: Node2D = _find_chain_target(origin, excluded)
	var nearest_distance_sq := chain_range * chain_range
	if nearest != null:
		nearest_distance_sq = origin.global_position.distance_squared_to(nearest.global_position)
	if GameRuntime.is_rift_clash() and team_id != "":
		for candidate in get_tree().get_nodes_in_group("players"):
			var rival := candidate as Player
			if not is_instance_valid(rival) or rival.team_id == "" or rival.team_id == team_id:
				continue
			if not rival.active or rival.health.is_dead or rival in excluded:
				continue
			if rival.is_pvp_protected():
				continue
			var distance_sq: float = origin.global_position.distance_squared_to(rival.global_position)
			if distance_sq < nearest_distance_sq:
				nearest_distance_sq = distance_sq
				nearest = rival
	return nearest


func _damage_enemy(target: Node2D, amount: float) -> void:
	if target is Player:
		var rival := target as Player
		if rival.is_pvp_protected():
			return
		if GameRuntime.is_rift_clash() and rival.team_id == team_id:
			return
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
	var was_alive := not target_health.is_dead
	target_health.take_damage(dealt, self)
	# Synergy "Iron Will" / "Bruiser": healing on kill. Only triggers if this hit
	# actually killed the target (was alive before, dead after).
	if was_alive and target_health.is_dead and _kill_heal_amount > 0.0:
		health.current_health = minf(health.max_health, health.current_health + _kill_heal_amount)
		health.health_changed.emit(health.current_health, health.max_health)
	if hit_slow_factor < 1.0 and target.has_method("apply_slow"):
		target.apply_slow(hit_slow_factor, hit_slow_duration)
	if knockback_strength > 0.0 and target.has_method("apply_knockback"):
		target.apply_knockback(global_position.direction_to(target.global_position) * knockback_strength)


func add_gold(amount: int) -> void:
	if simulation_mode == SimulationMode.PROXY or amount <= 0:
		return
	gold += int(round(float(amount) * gold_multiplier))
	gold_changed.emit(gold)


func lose_half_gold() -> int:
	if simulation_mode == SimulationMode.PROXY:
		last_death_gold_lost = 0
		return 0
	last_death_gold_lost = gold / 2
	if last_death_gold_lost <= 0:
		return 0
	gold -= last_death_gold_lost
	gold_changed.emit(gold)
	return last_death_gold_lost


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
	var extra := stacks_of(item_id) > 1
	thorns_ratio += _shop_stat(item, "thorns_ratio", extra)
	health_regen_per_second += _shop_stat(item, "health_regen_per_second", extra)
	resistance_pierce += _shop_stat(item, "resistance_pierce", extra)
	ember_damage_per_second += _shop_stat(item, "ember_damage_per_second", extra)
	knockback_strength += _shop_stat(item, "knockback_strength", extra)
	pickup_radius_bonus += _shop_stat(item, "pickup_radius_bonus", extra)
	jetpack_slam += _shop_stat(item, "jetpack_slam", extra)
	skate_speed_bonus += _shop_stat(item, "skate_speed_bonus", extra)
	if bool(item.get("board_jump", false)):
		board_jump = true
	if bool(item.get("water_walk", false)):
		water_walk = true
	var grab := float(item.get("grab_radius", 0.0))
	if grab > 0.0:
		if grab_radius <= 0.0:
			grab_radius = grab
		else:
			grab_radius += float(item.get("grab_radius_step", grab * 0.22))
	if item.has("hit_slow_factor"):
		hit_slow_factor = minf(hit_slow_factor, float(item.hit_slow_factor))
		if extra:
			hit_slow_duration += float(item.get("hit_slow_duration_step", 0.25))
		else:
			hit_slow_duration = maxf(hit_slow_duration, float(item.get("hit_slow_duration", 0.8)))
	if item_id == ShopCatalog.ACTIVE_ITEM_ID:
		sprint_cooldown = 0.0
	_apply_sprite()


func _shop_stat(item: Dictionary, key: String, extra: bool) -> float:
	if extra:
		return float(item.get(key + "_step", item.get(key, 0.0)))
	return float(item.get(key, 0.0))


func has_active_item() -> bool:
	return stacks_of(ShopCatalog.ACTIVE_ITEM_ID) > 0


func sprint_burst_duration() -> float:
	return SPRINT_DURATION + maxf(0.0, float(stacks_of(ShopCatalog.ACTIVE_ITEM_ID) - 1) * 0.25)


func sprint_cycle_length() -> float:
	var cool := maxf(4.5, SPRINT_COOLDOWN - maxf(0.0, float(stacks_of(ShopCatalog.ACTIVE_ITEM_ID) - 1) * 0.85))
	return cool + sprint_burst_duration()


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
	amount = int(round(float(amount) * xp_gain_mult))
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_required:
		current_xp -= xp_required
		level += 1
		xp_required = roundi(xp_required * (1.12 if level >= 7 else XP_GROWTH))
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
		xp_required = roundi(xp_required * (1.12 if level >= 7 else XP_GROWTH))
		xp_changed.emit(current_xp, xp_required, level)
		level_reached.emit(level)


func set_invulnerable(value: bool) -> void:
	health.invulnerable = value


func _record_level_upgrade(upgrade_id: String) -> void:
	var lvl := level
	if not level_upgrades.has(lvl):
		level_upgrades[lvl] = []
	level_upgrades[lvl].append(upgrade_id)


func apply_upgrade(upgrade_id: String) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	if UpgradeCatalog.is_ability_token(upgrade_id):
		_apply_ability_token(UpgradeCatalog.ability_id_from(upgrade_id))
		taken_upgrades.append(upgrade_id)
		_record_level_upgrade(upgrade_id)
		return
	taken_upgrades.append(upgrade_id)
	_record_level_upgrade(upgrade_id)
	match upgrade_id:
		"rapid", "rime":
			attack_interval = maxf(0.18, attack_interval * 0.82)
		"haste":
			attack_interval = maxf(0.18, attack_interval * 0.88)
		"overclock":
			attack_interval = maxf(0.14, attack_interval * 0.68)
		"bullet_time":
			attack_interval = maxf(0.12, attack_interval * 0.55)
		"heavy":
			weapon_damage += 8.0
		"havoc":
			weapon_damage += 16.0
		"titan_shell":
			weapon_damage += 30.0
		"blast":
			blast_radius += 10.0
		"nova_core":
			blast_radius += 28.0
		"world_cracker":
			blast_radius += 48.0
			blast_pulses += 1
		"aftershock":
			blast_pulses += 1
		"double_tap":
			double_blast_chance += 0.25
		"echo_shot":
			double_blast_chance += 0.45
		"extra_bolt":
			extra_projectiles += 1
		"split_shot":
			extra_projectiles += 2
		"volley":
			extra_projectiles += 4
		"keen_eye":
			crit_chance += 0.12
		"lucky_strike":
			crit_chance += 0.18
		"headhunter":
			crit_chance += 0.22
			crit_mult = maxf(crit_mult, 2.6)
		"vitality":
			_add_max_health(25.0)
		"plating":
			_add_damage_reduction(0.08)
		"ironhide":
			_add_max_health(40.0)
			_add_damage_reduction(0.06)
		"fortress":
			_add_max_health(70.0)
			_add_damage_reduction(0.12)
		"chain":
			chain_count += 1
		"volt":
			chain_range += 40.0
		"boots":
			movement_speed += 35.0
		"reach":
			attack_range += 35.0
		"sweep":
			cone_half_angle_degrees += PlayerClass.SWEEP_DEGREES
		"flow":
			support_heal_per_second += 1.5
		"choir":
			support_damage_bonus += 0.06
		"lash":
			attack_range += 60.0
		"depth":
			frost_slow_factor = maxf(0.25, frost_slow_factor - 0.08)
			frost_slow_duration += 0.5
		"shatter":
			frost_burst_radius += 35.0
		"scholar":
			xp_gain_mult += 0.2
		"exp_well":
			xp_gain_mult += 0.4
		"gold_vein":
			gold_multiplier += 0.25
		"metronome":
			_set_pulse_interval(20.0)
		"heartbeat":
			_set_pulse_interval(12.0)
			pulse_radius = maxf(pulse_radius, 220.0)
		"supernova":
			_set_pulse_interval(8.0)
			pulse_radius = maxf(pulse_radius, 300.0)
		"gun_drone", "push_drone", "ember_sprite", "heat_gust", "thorn_sprite", "vine_tether", "spark_sprite", "gale_push", "frost_drone", "laser_drone", "shield_drone":
			_add_companion(upgrade_id)
		"swarm_drones":
			_add_companion("gun_drone")
			_add_companion("gun_drone")
	# Apply any newly-completed synergy bonuses (re-evaluates the full set so
	# each new upgrade can complete a pair, e.g. rapid + keen_eye -> Critical Tempo).
	_apply_synergy_bonuses()


## Apply stat bonuses from every completed synergy pair that hasn't been granted yet.
## Each synergy grants its bonus the first time both required upgrades are held.
func _apply_synergy_bonuses() -> void:
	for syn in UpgradeCatalog.active_synergies(taken_upgrades):
		var key := str(syn.get("key", ""))
		if key.is_empty() or _granted_synergies.has(key):
			continue
		_granted_synergies[key] = true
		var bonus: Dictionary = syn.get("bonus", {})
		if bonus.has("attack_interval_mult"):
			attack_interval = maxf(0.12, attack_interval * float(bonus["attack_interval_mult"]))
		if bonus.has("weapon_damage_flat"):
			weapon_damage += float(bonus["weapon_damage_flat"])
		if bonus.has("max_health_flat"):
			_add_max_health(float(bonus["max_health_flat"]))
		if bonus.has("damage_taken_mult"):
			_add_damage_reduction(float(bonus["damage_taken_mult"]))
		if bonus.has("crit_chance"):
			crit_chance += float(bonus["crit_chance"])
		if bonus.has("crit_mult"):
			crit_mult = maxf(crit_mult, crit_mult + float(bonus["crit_mult"]))
		if bonus.has("attack_range_flat"):
			attack_range += float(bonus["attack_range_flat"])
		if bonus.has("movement_speed_flat"):
			movement_speed += float(bonus["movement_speed_flat"])
		if bonus.has("blast_radius_flat"):
			blast_radius += float(bonus["blast_radius_flat"])
		if bonus.has("extra_projectiles_flat"):
			extra_projectiles += int(bonus["extra_projectiles_flat"])
		if bonus.has("xp_gain_mult"):
			xp_gain_mult += float(bonus["xp_gain_mult"])
		if bonus.has("chain_range_flat"):
			chain_range += float(bonus["chain_range_flat"])
		if bonus.has("companion_damage_flat"):
			_companion_damage_bonus += float(bonus["companion_damage_flat"])
		if bonus.has("self_heal_on_kill"):
			_kill_heal_amount += float(bonus["self_heal_on_kill"])
		if bonus.has("self_heal_on_move"):
			_move_heal_per_second += float(bonus["self_heal_on_move"])
		_granted_synergies[key] = true
		print("Synergy unlocked: ", str(syn.get("name", key)))


func _apply_ability_token(ability_id: String) -> void:
	for entry in known_abilities:
		if entry.id == ability_id:
			upgrade_ability(ability_id)
			return
	if known_abilities.size() < PlayerClass.MAX_KNOWN_ABILITIES:
		learn_ability(ability_id)
	else:
		apply_fallback_bonus()


func _add_max_health(amount: float) -> void:
	health.max_health += amount
	health.current_health = minf(health.max_health, health.current_health + amount)
	health.health_changed.emit(health.current_health, health.max_health)


func _add_damage_reduction(amount: float) -> void:
	base_damage_taken_multiplier = maxf(0.35, base_damage_taken_multiplier - amount)
	health.damage_taken_multiplier = base_damage_taken_multiplier * _ability_damage_taken_factor


func _set_pulse_interval(seconds: float) -> void:
	pulse_interval = seconds if pulse_interval <= 0.0 else minf(pulse_interval, seconds)


func _add_companion(upgrade_id: String) -> void:
	if not is_inside_tree():
		return
	var want := int(CompanionDroneScript.KIND_FOR_UPGRADE.get(upgrade_id, CompanionDroneScript.Kind.GUN))
	for child in get_parent().get_children():
		if child.get_script() == CompanionDroneScript and int(child.kind) == want:
			child.rank += 1
			return
	var drone := CompanionDroneScript.new()
	get_parent().add_child(drone)
	var slot := 0
	for child in get_parent().get_children():
		if child.get_script() == CompanionDroneScript:
			slot += 1
	drone.setup(self, upgrade_id, maxi(0, slot - 1))


func snapshot() -> Dictionary:
	return {
		"peer_id": owner_peer_id,
		"class_id": class_id,
		"team_id": team_id,
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
		"hero_kills": hero_kills,
		"pvp_invuln": pvp_invuln_timer,
	}


func _on_damaged(amount: float) -> void:
	SoundDirector.play("hurt", global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color("ff7777"), 0.05)
	tween.tween_callback(_refresh_pvp_modulate)
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
	# Losing boss form on death: the taken-over state is a temporary power, not
	# permanent. Revert to the hero so they respawn as their normal class.
	if in_boss_form:
		revert_boss_form()
	active = false
	_hazard_inside = false
	_hazard_grace_timer = 0.0
	_hazard_visual_off()
	lose_half_gold()
	modulate = Color(0.35, 0.35, 0.4, 1.0)
	SoundDirector.play("player_down", global_position)
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
	SoundDirector.play("revive", global_position)


func respawn_ffa(at: Vector2) -> void:
	if simulation_mode == SimulationMode.PROXY:
		return
	global_position = at
	active = true
	modulate = Color.WHITE
	health.is_dead = false
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	set_ffa_respawn(0.0)
	grant_pvp_spawn_protection()
	SoundDirector.play("revive", global_position)


func _refresh_pvp_modulate() -> void:
	if not active:
		return
	modulate = Color.WHITE
	if world_health_bar == null:
		return
	var protected := is_pvp_protected()
	world_health_bar.set_shield_active(protected)
	if protected and pvp_invuln_timer <= GameRuntime.FFA_PVP_SHIELD_FLICKER_SECONDS:
		# Accelerating flicker over the final 2s: beat starts at 0.30s and shrinks to
		# 0.06s as the shield is about to drop, so it "dies" in a rapid pulse.
		var flicker_progress: float = clampf(1.0 - pvp_invuln_timer / GameRuntime.FFA_PVP_SHIELD_FLICKER_SECONDS, 0.0, 1.0)
		var beat: float = lerp(0.30, 0.06, flicker_progress)
		world_health_bar.set_shield_flicker(fmod(pvp_invuln_timer, beat * 2.0) > beat)
	else:
		world_health_bar.set_shield_flicker(true)


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
	if is_local_player and attack_charge > 0.05:
		_draw_charge_damage_indicator()
	if is_local_player and secondary_charge > 0.02 and not _drawing_wall:
		_draw_secondary_charge_indicator()
	if aim_indicator_visible and is_local_player and not _pending_ability_id.is_empty():
		_draw_aim_indicator()


## LMB charge indicator: shows the growing damage number above the hero while the
## auto-charge is in progress. No bar under the attack arrow — just the number,
## scaling from base weapon damage up to the full charge value.
func _draw_charge_damage_indicator() -> void:
	var t := _charge_t()
	# Estimated damage this shot would deal at the current charge level.
	var est_damage := weapon_damage * _charge_damage_mult(t)
	# Color shifts from white -> accent -> hot yellow as charge builds.
	var col := Color(1.0, 1.0, 1.0, 0.75).lerp(Color(accent_color.r, accent_color.g, accent_color.b, 0.95), t)
	if t > 0.85:
		col = Color(1.0, 0.92, 0.55, 1.0)
	var scale := 1.0 + t * 0.45
	var font := ThemeDB.fallback_font
	var font_size := int(round(13.0 * scale))
	var txt := "%d" % int(roundi(est_damage))
	var text_w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-text_w * 0.5, -34.0 - t * 6.0)
	# Subtle shadow for readability.
	draw_string(font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.6))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## RMB charge indicator: while the secondary is winding up, draw a pulsing ring that
## grows with the charge and a small multiplier readout, so the player can see the
## effect scaling live. Teleport/dash-type secondaries additionally draw an outward
## arrow showing the reach expanding as the charge builds.
func _draw_secondary_charge_indicator() -> void:
	var t := _secondary_charge_t()
	if t <= 0.02:
		return
	var radius := PlayerClass.SECONDARY_RADIUS * _sec_radius_mult()
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.009)
	# Growing charge ring around the hero, scaling up to the full charged radius.
	var ring_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.75 * pulse)
	if t > 0.85:
		ring_col = Color(1.0, 0.92, 0.5, 0.95)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_col, 2.4, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 48, Color(ring_col.r, ring_col.g, ring_col.b, 0.35 * pulse), 1.4, true)
	# Multiplier readout (x1.0 -> x3.0) so the "bigger effect" is legible at a glance.
	var dmg_mult := lerpf(1.0, SECONDARY_CHARGE_DAMAGE_MULT_MAX, t)
	var font := ThemeDB.fallback_font
	var font_size := int(round(12.0 + t * 5.0))
	var txt := "x%.1f" % dmg_mult
	var text_w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-text_w * 0.5, -radius - 10.0)
	draw_string(font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.6))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ring_col)
	# Teleport / dash / move-flavoured secondaries: outward reach arrow.
	match secondary_kind:
		"blast_jump", "windstep", "gale_gust", "time_skip", "ward_light":
			var dir := facing_direction if facing_direction.length_squared() > 0.0 else Vector2.RIGHT
			var reach := radius * 1.2
			var tip := dir * reach
			var tail := dir * 16.0
			draw_line(tail, tip, Color(1.0, 1.0, 0.95, 0.9), 2.6, true)
			var left := tip - dir * 11.0 + dir.orthogonal() * 6.0
			var right := tip - dir * 11.0 - dir.orthogonal() * 6.0
			draw_line(tip, left, Color(1.0, 1.0, 0.95, 0.9), 2.6, true)
			draw_line(tip, right, Color(1.0, 1.0, 0.95, 0.9), 2.6, true)


## Aim-helper overlay while an ability is armed: a thin circle at the actual cast area and
## a hair-line from the hero to it so you can see where it'll land. Mode-dependent: "vector"
## adds a directional arrow inside the circle since Steam Turret's cone blows that way.
func _draw_aim_indicator() -> void:
	var mode := str(TARGETED_ABILITIES.get(_pending_ability_id, "point"))
	var data := PlayerClass.ability_info(_pending_ability_id)
	if data.is_empty():
		return
	var values := PlayerClass.ability_values(_pending_ability_id, 1)
	# Range clamp: how far the aim point can be from the hero.
	var max_range := float(values.get("range", 540.0))
	var target := aim_world_position
	var offset := target - global_position
	if offset.length() > max_range:
		target = global_position + offset.normalized() * max_range
	# Ability's impact radius — read from values.radius when present.
	var radius := float(values.get("radius", 200.0))
	var local_center := to_local(target)
	var local_start := Vector2.ZERO
	# Thin connecting line so you can see the range.
	draw_line(local_start, local_center, Color(1.0, 1.0, 1.0, 0.4), 1.4, true)
	# Impact circle. Pulsing a bit so it reads "armed".
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	draw_arc(local_center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.7 * pulse), 2.2, true)
	draw_arc(local_center, radius * 0.6, 0.0, TAU, 48, Color(accent_color.r, accent_color.g, accent_color.b, 0.5 * pulse), 1.4, true)
	# Hot center dot.
	draw_circle(local_center, 3.0, Color(1.0, 1.0, 1.0, 0.95))
	if mode == "vector":
		# Direction the cast will face: from the cast point toward the second aim point.
		# For now use current facing_direction — the cast handler reads it at confirm time.
		var arrow_end := local_center + facing_direction * radius * 0.7
		draw_line(local_center, arrow_end, Color(1.0, 1.0, 0.9, 0.9), 2.4, true)
		var arrow_left := arrow_end - facing_direction * 10.0 + facing_direction.orthogonal() * 5.5
		var arrow_right := arrow_end - facing_direction * 10.0 - facing_direction.orthogonal() * 5.5
		draw_line(arrow_end, arrow_left, Color(1.0, 1.0, 0.9, 0.9), 2.4, true)
		draw_line(arrow_end, arrow_right, Color(1.0, 1.0, 0.9, 0.9), 2.4, true)
	elif mode == "unit":
		# Highlight the unit that would be hit.
		var candidate := _nearest_enemy_in_range(_unit_target_range_for(_pending_ability_id))
		if candidate != null:
			var local_target := to_local(candidate.global_position)
			draw_arc(local_target, 18.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.9 * pulse), 2.4, true)
			draw_line(local_center, local_target, Color(1.0, 0.85, 0.4, 0.6), 1.6, true)

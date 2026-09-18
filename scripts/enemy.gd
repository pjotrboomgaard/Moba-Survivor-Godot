class_name Enemy
extends CharacterBody2D

const WorldClock := preload("res://scripts/world_clock.gd")

signal defeated(enemy: Enemy)
signal projectile_fired(origin: Vector2, direction: Vector2, damage: float, speed: float, sprite_name: String)
signal spawn_requested(type_id: String, origin: Vector2, count: int)
signal exploded(origin: Vector2, radius: float, damage: float)
signal arena_hazard_requested(spec: Dictionary)
signal boss_phase_changed(phase: int)
signal boss_death(enemy: Enemy)

const _MinionCorpse := preload("res://scripts/minion_corpse.gd")

const SEPARATION_RANGE := 62.0
const SEPARATION_STRENGTH := 130.0
## Uniform-grid cell size for the shared separation spatial hash (see _rebuild_separation_grid).
## Must be >= SEPARATION_RANGE so a 3x3 neighbourhood around any point's own cell is
## guaranteed to contain every other enemy within SEPARATION_RANGE of it.
const SEPARATION_CELL_SIZE := 64.0
## FFA runs up to four independent WaveDirectors feeding the same shared enemy pool (see
## main.gd's team_wave_directors), so live enemy counts that would be rare in solo/co-op
## (near the 110-160 global cap, see main.gd's max_enemies/BOSS_MAX_ENEMIES) are common
## there instead. Every non-idle enemy calls _separation_offset() every physics frame, and
## it used to do `get_tree().get_nodes_in_group("enemies")` + a full linear scan each time —
## O(enemies^2) per physics tick. A live 4-bot FFA reproduction (tools/selftest/requests/
## ffa_perf_bots.json) measured Performance.TIME_PHYSICS_PROCESS climbing from ~10ms at
## enemies=40-60 to 17-29ms (occasionally 65-74ms) once the shared pool sat at the ~110 cap,
## well past the 16.6ms/frame budget for 60fps — this is the "gets laggy" the enemy count
## itself doesn't explain (see wave_director.gd's per-team budget_for_wave/_desired_live).
## Fix: bucket enemies into a uniform grid rebuilt once per physics frame (O(n)) and have
## each enemy only scan its own 3x3 neighbourhood (bounded by local density, not total
## population) instead of the whole pool. Behaviourally identical — same SEPARATION_RANGE
## cutoff and falloff — just no longer wastefully comparing against enemies that are
## nowhere near close enough to matter.
static var _separation_grid: Dictionary = {}  # Vector2i cell -> Array[Enemy]

## T3.92 — shared per-frame player snapshot for cheap on-screen AI.
## Every on-screen enemy used to call _find_nearest_player() which does
## get_tree().get_nodes_in_group("players") + per-player checks. With 200
## enemies that's 200 group scans per physics frame. Instead, we cache the
## valid player list once per frame (rebuild cost = O(players) ≈ O(4)) and
## every enemy reads the cached array.
static var _player_snap: Array = []  # Array[Player] valid active non-cloaked non-boss players
static var _player_snap_frame: int = -1
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
## Contact-attack throttle: how long since this enemy last struck a player via the active
## melee-range contact attack (_contact_attack_player). Distinct from attack_cooldown,
## which gates the ranged/projectile + _attack_target() strikes; a creeping melee enemy
## that's standing on a stationary player needs its own cooldown so it deals damage on a
## per-second cadence instead of once-per-frame. Task 1.
var _player_attack_cooldown := 0.0
## Melee range for the active contact attack: contact_damage lands when the enemy's body
## is within this many px of a player, even if the player isn't moving. ~12px past the
## body so "touching" reads as attacking. Task 1.
const CONTACT_ATTACK_RANGE_BUFFER := 12.0
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
## Retaliation: when a creep is hit, it becomes briefly enraged (faster + harder hits).
## This makes "creeps fight back" — the more you poke them, the more they fight.
var retaliation_timer := 0.0
const RETALIATION_DURATION := 2.5
const RETALIATION_SPEED_MULT := 1.35
const RETALIATION_DAMAGE_MULT := 1.5
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
var _stuck_time := 0.0
var _stuck_side := Vector2.ZERO
## Perf (post-T4.12): the full unstuck body does a 2nd move_and_slide +
## slide-collision introspection. Throttle it per-enemy to ~8 Hz so a large
## blocked pool doesn't all run move_and_slide every physics frame. The cheap
## progress check still runs every frame; only the expensive side-slip move +
## teleport is gated by this per-enemy timer.
var _unstuck_move_timer := 0.0
const UNSTUCK_TICK_INTERVAL := 0.12  # ~8 Hz per enemy

## Perf (large groups): _update_standing_lava called Arena.hazard_at() — a linear
## scan over hazard zones — for EVERY enemy EVERY physics frame. Throttle it to ~6
## Hz with a short accumulator so ticks stay continuous: total DoT damage over the
## same window is unchanged (dot * (sum of ticks) ≈ dot * window), but the zone
## scan cost drops ~10x for a large pool.
var _lava_scan_timer := 0.0
const LAVA_SCAN_INTERVAL := 0.16  # ~6.25 Hz per enemy

## Perf (large groups): every enemy refreshed its target every TARGET_REFRESH_INTERVAL
## on an identical cadence, so all N enemies ran _find_nearest_player() (O(players +
## turrets) each) in the same frames — a synchronized burst. The jitter spreads the
## refreshes across ~2x the interval so bursts don't stack up.
var _target_refresh_jitter := 0.0

## Movement variety (2026-09-17): each enemy picks a movement pattern on spawn so
## large groups don't all walk in straight lines. The pattern is chosen per type:
##   swarmling  -> PACK (tight formation, no individual variation)
##   grunt      -> STRAFE (sideswipe perpendicular to target)
##   spitter    -> CIRCLE (orbit at preferred distance)
##   brute      -> LUNGE (periodic forward burst)
##   charger    -> (existing charge logic, no extra pattern)
##   other      -> ZIGZAG (alternating perpendicular offset)
enum MovePattern { NONE, STRAFE, ZIGZAG, CIRCLE, LUNGE }
var _move_pattern: int = MovePattern.NONE
var _move_pattern_phase := 0.0
var _move_pattern_timer := 0.0
var _lunge_timer := 0.0
const LUNGE_INTERVAL := 3.5
const LUNGE_DURATION := 0.6
const LUNGE_SPEED_MULT := 2.2
const STRAFE_AMP := 0.45       # fraction of movement_speed added perpendicular
const ZIGZAG_PERIOD := 2.0     # seconds per zigzag cycle
const CIRCLE_SPEED := 0.35     # fraction of movement_speed for orbital motion
## 2026-09-18: wave tactic assignment — which tactical wave group this enemy belongs to.
var _wave_tactic: int = -1
var _wave_tactic_index: int = -1


## Perf (large groups): _rebuild_separation_grid() was gated per PHYSICS frame, so the
## whole pool's bucket map was rebuilt once every frame even though separation pushes
## are velocity offsets that need far less than 60Hz freshness. Rebuilding at ~12.5 Hz
## halves the O(n) rebuild frequency while keeping separation visually identical.
## Perf (large groups): newly spawned / just-re-enabled enemies are inserted lazily so
## they appear in the bucket map on their first move even between rebuilds.
static var _separation_grid_time := 0.0
const SEPARATION_GRID_INTERVAL := 0.08  # ~12.5 Hz grid rebuild

## Camp Guardian: a stationary tanky elite that guards a creep camp.
## - Holds its position (leashed to spawn point within CAMP_GUARDIAN_LEASH_RADIUS).
## - Emits a periodic undodgeable area "slam" pulse around itself.
## - Takes reduced damage (damage resistance) so it is a real threat.
## - Does NOT chase the player far — it holds camp. If the player leaves the
##   leash radius the guardian loses aggro and stops.
## - Contact damage is reduced (0.5x) since the slam pulse is the primary
##   "always take dmg" source; contact is secondary.
var is_camp_guardian := false
var camp_guardian_home := Vector2.ZERO
const CAMP_GUARDIAN_LEASH_RADIUS := 280.0
var _camp_guardian_slaam_timer := 0.0
const CAMP_GUARDIAN_SLAM_INTERVAL := 3.0  # 3s (was 2.2s — too hot for wave 1)
const CAMP_GUARDIAN_SLAM_RADIUS := 140.0
const CAMP_GUARDIAN_SLAM_DAMAGE := 14.0  # 14 (was 24 — too brutal for wave 1)
const CAMP_GUARDIAN_AGGRO_RADIUS := 300.0
## Aggressive in-leash speed multiplier: guardians move faster when aggroed so a
## player standing in the camp is hard to disengage from (Task 2: "camps should be
## difficult"). 1.05x over the base 0.85 → effective ~0.89x of movement_speed.
const CAMP_GUARDIAN_AGGR_SPEED_MULT := 1.05
## Camp ranged-attack state: the guardian fires fast projectiles at the engaged
## player so camps actively attack back (per user request). Populated by main.gd
## when the camp guardian is spawned.
var camp_projectile_range := 340.0
var camp_projectile_interval := 0.9
var _camp_projectile_timer := 0.0

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
var _target_refresh_timer := 0.0
const TARGET_REFRESH_INTERVAL := 0.4
var _lava_scan_acc := 0.0
## FFA performance cull: when no living player is within FAR_CULL_RADIUS, the enemy
## skips expensive AI (target find, separation, behaviour dispatch) and just idles in
## place. Refreshed on FAR_CULL_CHECK_INTERVAL so the per-frame cost is a single
## squared-distance check instead of a full player-group scan + AI dispatch.
const FAR_CULL_RADIUS := 1800.0
const FAR_CULL_CHECK_INTERVAL := 0.5
var _far_cull_timer := 0.0
var _near_player := false

## Viewport culling: enemies far outside the camera viewport are not rendered.
## This saves both draw calls and CanvasItem overhead for off-screen enemies.
## Checked at 2 Hz (cheap squared-distance to camera center) so the toggle
## only flips when the camera actually moves past the threshold.
const VIEWPORT_CULL_RADIUS := 2600.0
const VIEWPORT_CULL_CHECK_INTERVAL := 0.5
var _viewport_cull_timer := 0.0
## T3.85: track the night-state from the previous frame so we can detect the
## flip and trigger a queue_redraw + sprite tint update for red eyes.
var _was_night_last_frame := false
## T3.85: cached day/night sprite textures for fast swap on night flip.
var _day_texture: Texture2D = null
var _night_texture: Texture2D = null


func _ready() -> void:
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	network_target_position = global_position
	# 2026-09-18: random phase so camp-creep idle bobs are out of sync.
	_recruit_bob_phase = randf_range(0.0, TAU)
	queue_redraw()
	# Perf (large groups): insert into the separation grid immediately so a newly
	# spawned enemy participates in separation without waiting for the next 12.5 Hz
	# rebuild. The per-frame rebuild (or the next one) keeps the map current.
	if separation_weight > 0.0:
		var key := _separation_cell(global_position)
		var bucket: Array = Enemy._separation_grid.get(key, [])
		bucket.append(self)
		Enemy._separation_grid[key] = bucket


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
	if is_boss:
		dash_interval *= 0.55
		charge_windup *= 0.7
		dash_timer = dash_interval * 0.35
	z_as_relative = false
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

	# Movement variety: pick a per-type pattern so large groups don't all walk
	# in identical straight lines.
	_move_pattern = _pick_move_pattern()
	_move_pattern_phase = randf_range(0.0, TAU)
	_move_pattern_timer = 0.0
	_lunge_timer = randf_range(0.0, LUNGE_INTERVAL)


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
		collision_mask = 1 | 2 | 4 | 16

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


## 2026-09-18: wave tactic assignment. Called by main.gd when spawning an enemy
## that belongs to a tactical wave group. Sets the movement pattern based on
## the tactic type and the enemy's role within the tactic.
func set_tactic(tactic_id: int, tactic_index: int) -> void:
	_wave_tactic = tactic_id
	_wave_tactic_index = tactic_index
	# Override the per-type default movement pattern with the tactic's pattern.
	match tactic_id:
		0:  # PINCER — flanking groups move with a wide strafe
			_move_pattern = MovePattern.STRAFE
		1:  # PINCER_RANGED — ranged pincer, orbit while shooting
			_move_pattern = MovePattern.CIRCLE
		2:  # ENCIRCLE — slow closing ring
			_move_pattern = MovePattern.NONE  # ring formation handles it
		3:  # OVERWHELM — fast pack rush
			_move_pattern = MovePattern.NONE  # pack formation handles it
		4:  # FEINT_STRIKE — first group feints from front, second from behind
			if tactic_index == 0:
				_move_pattern = MovePattern.ZIGZAG  # feint: erratic approach
			else:
				_move_pattern = MovePattern.STRAFE  # strike: wide approach
		5:  # SNIPER_CURTAIN — ranged units hold and fire
			_move_pattern = MovePattern.CIRCLE
		6:  # BOLT_SQUAD — dash forward, pause, dash again
			_move_pattern = MovePattern.LUNGE
			_lunge_timer = randf_range(0.0, 2.0)
		7:  # WALL_PUSH — slow tanky advance
			_move_pattern = MovePattern.NONE
		8:  # POISON_RAIN — ranged units rain from multiple angles
			_move_pattern = MovePattern.CIRCLE
		9:  # ANVIL_CLAW — anvil (index 0) advances, claws (index 1+) flank
			if tactic_index == 0:
				_move_pattern = MovePattern.NONE  # anvil: straight advance
			else:
				_move_pattern = MovePattern.STRAFE  # claw: flanking approach
		10:  # WING_HARASS — air units circle, ground units push
			if tactic_index == 0:
				_move_pattern = MovePattern.CIRCLE  # wing: circling
			else:
				_move_pattern = MovePattern.NONE  # ground: straight push
		11:  # STAMPEDE — single large fast group
			_move_pattern = MovePattern.NONE  # pack formation handles it
		_:
			pass
	# Desynchronize the pattern phase so enemies in the same group don't move in lockstep.
	_move_pattern_phase = randf_range(0.0, TAU)


## Classic mode stays on the plain vector look (see arena.gd's grid background), so it never
## picks up pixel art here either.
func _apply_sprite() -> void:
	if sprite == null or GameRuntime.is_classic():
		return
	# 2026-09-18: camp creeps use their own recolored sprite name (yellow idle,
	# orange recruited) instead of the normal biome-skinned type sprite.
	var sprite_name := type_id
	if recruit_sprite != "":
		sprite_name = recruit_sprite
	_day_texture = SpriteLibrary.texture_for(sprite_name)
	# T3.85: also load the red-eyed night variant (same base name + "_night").
	# 2026-09-16: use the biome-skinned name for the night variant too, so each
	# biome's minions get their own night texture (with matching skin + eyes).
	_night_texture = SpriteLibrary.texture_for(SpriteLibrary._skinned_name(sprite_name) + "_night")
	if _night_texture == null:
		_night_texture = SpriteLibrary.texture_for(type_id + "_night")
	# Start with whichever matches the current time of day.
	sprite.texture = _night_texture if (WorldClock.is_night and _night_texture != null) else _day_texture
	var visual_radius := body_radius * (1.55 if is_boss else 1.25)
	sprite.scale = SpriteLibrary.scale_for_radius(sprite.texture, visual_radius)


func refresh_biome_look() -> void:
	_apply_boss_biome_theme()
	_apply_sprite()
	queue_redraw()


## Attack telegraphs stay red in every biome. Body sprites are skinned separately.
const BOSS_RING_COLOR := {"fill": "ff3a3a", "outline": "ffc8c8"}


func _apply_boss_biome_theme() -> void:
	if not is_boss:
		return
	fill_color = Color(str(BOSS_RING_COLOR.fill))
	outline_color = Color(str(BOSS_RING_COLOR.outline))


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


## T3.92 — off-screen ("ghost") cadence. When far-mode enemies are many (full-screen
## flood), re-running _find_nearest_player() every render frame is wasted: a far enemy
## only needs its target to refresh a few times per second to keep a straight walk. We
## cache the target between refreshes; the cached Node2D stays valid (or is_instance_valid
## guards a freed one) so the walk continues smoothly at the low cost.
var _far_target_cached: Node2D = null
var _far_target_timer := 0.0
const FAR_TARGET_REFRESH := 0.5  # 2 Hz target refresh while off-screen

## Lightweight movement path used while _in_far_mode is active. Physics is disabled
## in far mode, so this direct-position walk is the only movement that runs. Runs at
## render-frame cadence; it only does a single cached-target position add (target lookup
## throttled to 2 Hz via _far_target_refresh), so hundreds of far enemies stay cheap.
func _process(_delta: float) -> void:
	# T3.85: night-flip redraw check runs in _process (always active) so the
	# red eyes + tint update even when _physics_process is suspended by far mode.
	if WorldClock.is_night != _was_night_last_frame:
		_was_night_last_frame = WorldClock.is_night
		queue_redraw()
		if sprite != null and is_instance_valid(sprite):
			_update_night_sprite_tint()
	# 2026-09-18: idle camp creeps bob up/down (sprite.position.y) so they read
	# as alive rather than a static pile. Driven here because _physics_process
	# early-returns for idle camp creeps (is_camp_creep && !is_camp_recruit).
	if is_camp_creep and not is_camp_recruit and not _in_far_mode:
		_recruit_bob_phase += _delta * 2.6
		if sprite != null:
			sprite.position = Vector2(0.0, sin(_recruit_bob_phase) * 1.5)
	if not _in_far_mode:
		return
	_far_target_timer -= _delta
	if _far_target_timer <= 0.0 or not is_instance_valid(_far_target_cached):
		_far_target_timer = FAR_TARGET_REFRESH
		_far_target_cached = _find_nearest_player()
	var far_target := _far_target_cached
	if far_target == null:
		return
	var target_pos: Vector2 = (far_target as Node2D).global_position
	# Exit far mode once close enough that the full AI / physics path should engage.
	if global_position.distance_squared_to(target_pos) <= FAR_CULL_RADIUS * FAR_CULL_RADIUS:
		_exit_far_mode()
		return
	var dir := global_position.direction_to(target_pos)
	global_position += dir * movement_speed * 0.85 * _delta


## 2026-09-18: camp creeps are externally controlled by MinigameCampCreeps.
## Their movement is driven by the camp system, not normal enemy AI.
## When recruited (is_camp_recruit), they use a special "ally" AI that
## follows the local player and attacks the nearest regular enemy/camp.
var is_camp_creep := false
## True once the camp creep has been recruited by completing a minigame.
var is_camp_recruit := false
## The player this recruited camp creep follows (set by MinigameCampCreeps).
var recruit_owner: Node2D = null
## Recruit sprite name (day). When set, _apply_sprite uses this instead of
## type_id so idle camp creeps render in light-yellow and recruited ones in
## orange. See assets/sprites/*_recruit_yellow.png / *_recruit_orange.png.
var recruit_sprite := ""


func _physics_process(delta: float) -> void:
	if is_camp_creep:
		z_index = WorldClock.depth_z(global_position.y, 2)
		if is_camp_recruit:
			_process_camp_recruit(delta)
		return
	if stealth_alpha < 1.0:
		modulate.a = 1.0 if winding_up else stealth_alpha
	z_index = WorldClock.depth_z(global_position.y, 2)
	if not server_authoritative:
		global_position = global_position.lerp(network_target_position, clampf(delta * 12.0, 0.0, 1.0))
		z_index = WorldClock.depth_z(global_position.y, 2)
		if aura_radius > 0.0 or winding_up or is_boss:
			aura_pulse += delta
			queue_redraw()
		return

	if knockback_velocity.length_squared() > 1.0:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
		if knockback_velocity.length() > KNOCKBACK_FLIGHT_THRESHOLD:
			_was_knocked = true
		_eject_from_ffa_crater()
	elif _was_knocked:
		# Just landed from a knockback arc — check if we ended up in lava.
		_was_knocked = false
		_on_knockback_landed()
	if _in_far_mode:
		velocity = Vector2.ZERO
		queue_redraw()
		return

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
	# Retaliation timer ticks down regardless of the far-cull gate.
	if retaliation_timer > 0.0:
		retaliation_timer = maxf(0.0, retaliation_timer - delta)
		if retaliation_timer <= 0.0:
			modulate = Color.WHITE
			queue_redraw()
	if speed_ramp > 0.0:
		movement_speed = minf(speed_cap, movement_speed + speed_ramp * delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_player_attack_cooldown = maxf(0.0, _player_attack_cooldown - delta)
	if growth_aggro_seconds > 0.0:
		_update_growth(delta)
		if _is_still_growing():
			# Not a threat yet — wanders like an unaggroed target instead of chasing, so
			# the player can choose to kill it small or let it grow into a real problem.
			_process_wander(delta)
			return
	# FFA performance cull: when no living player is within FAR_CULL_RADIUS and this
	# enemy is not a boss/camp guardian/charger (which need to keep their patterns),
	# skip the full AI block and just idle in place. Refreshed on a timer so the
	# squared-distance scan runs at most FAR_CULL_CHECK_INTERVAL times per second
	# per enemy instead of every physics frame.
	_far_cull_timer -= delta
	if _far_cull_timer <= 0.0:
		_far_cull_timer = FAR_CULL_CHECK_INTERVAL
		_near_player = _any_player_within_far_cull()
	# Far-enemy lightweight mode: when no living player is within FAR_CULL_RADIUS and
	# this enemy is not a boss/camp guardian/charger (which need to keep their patterns),
	# hide the sprite, skip collision, and just walk straight toward the nearest player.
	# No separation, no obstacle avoidance, no AI — pure position tracking. This lets
	# hundreds of enemies exist off-screen at near-zero cost.
	if not _near_player and not is_boss and not is_camp_guardian and dash_interval <= 0.0 and teleport_interval <= 0.0:
		_enter_far_mode()
		return
	_exit_far_mode()

	# Task 1: active contact attack. Runs for every enemy (grunts, camp guardians,
	# chargers, bosses...) whenever a player is actually within melee range, on a
	# per-enemy ~1s cadence. Placed after the far-cull gate so no player-group scan
	# happens when no one is near. Also fires when `target` is a *different* (closer)
	# player, which is what makes a player standing in a camp take real damage even
	# when the guardian's aggro is on an FFA rival (Task 2).
	_contact_attack_player()
	_target_refresh_timer -= delta
	if _target_refresh_timer <= 0.0:
		_target_refresh_timer = TARGET_REFRESH_INTERVAL + _target_refresh_jitter
		target = _find_nearest_player()
	if target == null:
		if Arena.ffa_blocks_creeps_from_crater() and _any_living_player_in_crater():
			_process_crater_watch()
		elif _any_player_cloaked():
			_process_wander(delta)
		else:
			velocity = Vector2.ZERO
		return

	# Camp guardians hold their ground: they do not chase the player beyond the
	# leash radius and instead emit a periodic undodgeable slam pulse when the
	# player is inside the camp. If the target drops out of the leash they stop
	# completely (no chase) so kiting away fully disengages.
	if is_camp_guardian:
		_process_camp_guardian(delta)
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
	if Arena.ffa_blocks_creeps_from_crater():
		var rim := Arena.ffa_creep_rim_radius(body_radius)
		if dest.length() < rim:
			var radial := dest.normalized() if dest.length() > 1.0 else Vector2.RIGHT
			dest = radial * rim
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


func _move(direction_velocity: Vector2, allow_crater_inward: bool = false) -> void:
	var dir := direction_velocity
	if scrambling_out > 0.0:
		dir *= LAVA_SCRAMBLE_SPEED_MULT
	# Night creeps move faster.
	dir *= WorldClock.night_speed_mult
	# Retaliation: when recently hit, move faster to fight back.
	if retaliation_timer > 0.0:
		dir *= RETALIATION_SPEED_MULT
	dir = _deflect_from_ffa_crater(dir, allow_crater_inward)
	velocity = dir + _separation_offset()
	var before := global_position
	if flying:
		global_position += velocity * get_physics_process_delta_time()
	else:
		move_and_slide()
		# T4.12 unstuck mechanic — made less intense / cheaper. The full body of
		# _unstick_from_props does a SECOND move_and_slide() plus slide-collision
		# introspection every call, which tanked FPS once the whole enemy pool was
		# calling it every physics frame. So now: the cheap progress check runs
		# every frame (a couple of vector ops), but the expensive side-slip move
		# only runs when the enemy is genuinely blocked (poor forward progress),
		# and even then it's throttled to UNSTUCK_TICK_INTERVAL Hz via a shared
		# static tick counter (all enemies in the same tick batch together, so
		# worst-case we do the heavy work for the whole pool at most N times a
		# second instead of 60). The mechanic still unstuck-routes enemies around
		# obstacles; it just does far less per-frame work when they aren't stuck.
		_try_unstick_from_props(dir, before)
	z_index = WorldClock.depth_z(global_position.y, 2)
	_eject_from_ffa_crater()


## Perf gate for _unstick_from_props: cheap progress check runs every frame,
## but the expensive side-slip move (2nd move_and_slide + slide-collision
## introspection) is throttled to UNSTUCK_TICK_INTERVAL Hz via a shared static
## tick so the whole enemy pool batches its heavy work.
func _try_unstick_from_props(desired: Vector2, before: Vector2) -> void:
	if flying or is_boss:
		_stuck_time = 0.0
		_stuck_side = Vector2.ZERO
		return
	var want := desired.length() * get_physics_process_delta_time()
	# Skip the unstuck bookkeeping only when we are *barely* moving this frame
	# (e.g. near-zero speed or a tiny delta). The previous threshold of 6.0px/frame
	# was wrong: at 60fps a 100px/s enemy only expects ~1.6px/frame of movement,
	# so the check always fired and _stuck_time never accumulated — the unstuck
	# logic was effectively dead. 1.0px/frame corresponds to ~60px/s, well below
	# any real creep speed, so it only guards degenerate frames.
	if want < 1.0:
		_stuck_time = 0.0
		_stuck_side = Vector2.ZERO
		return
	# "Stuck" = not making meaningful progress *toward* the target.
	# Sliding along a wall face gives non-zero `moved` but near-zero progress
	# toward `desired`, so use the dot-product component instead.
	var progress_px := (global_position - before).dot(desired.normalized())
	if progress_px > want * 0.25:
		_stuck_time = 0.0
		_stuck_side = Vector2.ZERO
		return
	# We are blocked. Advance the stuck timer every frame (cheap), then do the
	# expensive side-slip move at most UNSTUCK_TICK_INTERVAL Hz (throttled per
	# enemy) so a large blocked pool doesn't all run move_and_slide every frame.
	_stuck_time += get_physics_process_delta_time()
	_unstuck_move_timer += get_physics_process_delta_time()
	var can_move := _unstuck_move_timer >= UNSTUCK_TICK_INTERVAL
	if can_move:
		_unstuck_move_timer = 0.0
	_do_unstick_side_slip(desired, before, can_move)

## The expensive part of unstuck: pick/commit to a side and move_and_slide along it.
## `do_heavy_move` gates the 2nd move_and_slide (and thus the slide-collision
## introspection that informs the side choice). When false we only commit to a
## side cheaply; the actual lateral move happens on the next heavy tick. This
## keeps the per-frame cost down when many enemies are blocked at once.
func _do_unstick_side_slip(desired: Vector2, before: Vector2, do_heavy_move: bool) -> void:
	# Pick a side to slip around the obstacle. Use the collision normal when we
	# have one, otherwise fall back to the perpendicular of our desired direction.
	# We commit to ONE side and keep it across frames (no per-frame flipping):
	# a wall-parallel desired direction makes n.orthogonal().dot(desired) ≈ 0, so
	# the previous per-frame sign check caused the enemy to oscillate up/down the
	# wall face forever instead of committing and going around.
	var side := desired.orthogonal().normalized()
	if do_heavy_move and get_slide_collision_count() > 0:
		var hit := get_slide_collision(0)
		if hit != null:
			var n := hit.get_normal()
			# For a wall face the normal points away from the wall; its perpendicular
			# is the "around the obstacle" direction. Pick the one that keeps us
			# moving (n.orthogonal() is already near-perpendicular to desired, so
			# just use it stably).
			side = n.orthogonal()
			if side.length_squared() < 0.1:
				side = desired.orthogonal().normalized()
	# Persist the side: commit once, and only flip if we've been sliding this way
	# for a long time (>1.5s) with still no forward progress (i.e. this side is a
	# dead end, so try the other way around).
	if _stuck_side.length_squared() < 0.1:
		_stuck_side = side
	else:
		var progress_ever := (global_position - before).dot(desired.normalized())
		if _stuck_time > 1.5 and progress_ever <= 0.0 and _stuck_side.dot(side) < 0.0:
			_stuck_side = -_stuck_side
	# Move laterally along the committed side at near full speed — but only on
	# the heavy tick. On cheap frames we've already committed to a side; the
	# actual move_and_slide happens on the next heavy tick so we don't do a
	# 2nd collision resolution every frame for every blocked enemy.
	if do_heavy_move:
		velocity = _stuck_side * maxf(desired.length(), movement_speed * 0.9)
		move_and_slide()
	if _stuck_time < 0.45:
		return
	# Sustained stuck: give up and teleport to a free spot offset sideways + forward
	# so we actually get past the obstacle.
	_stuck_time = 0.0
	_stuck_side = Vector2.ZERO
	var arena := Arena.arena_root(self)
	if arena == null:
		return
	var nudge := global_position + _stuck_side * (body_radius + 30.0)
	if desired.length_squared() > 1.0:
		nudge += desired.normalized() * 40.0
	global_position = arena.free_position_near(nudge, body_radius)


func _deflect_from_ffa_crater(dir: Vector2, allow_crater_inward: bool = false) -> Vector2:
	if not Arena.ffa_blocks_creeps_from_crater():
		return dir
	var rim := Arena.ffa_creep_rim_radius(body_radius)
	var dist := global_position.length()
	if dist > rim + 18.0:
		return dir
	if allow_crater_inward and dist > rim + 2.0:
		return dir
	var radial := global_position.normalized() if dist > 1.0 else Vector2.RIGHT
	var inward := dir.dot(radial)
	if inward < 0.0:
		dir -= radial * inward
	if dir.length_squared() < 36.0:
		if allow_crater_inward:
			return Vector2.ZERO
		var around := radial.orthogonal()
		if target != null:
			var side := radial.orthogonal().dot(target.global_position - global_position)
			if side < 0.0:
				around = -around
		dir = around * movement_speed * slow_factor
	return dir


func _eject_from_ffa_crater() -> void:
	if not Arena.ffa_blocks_creeps_from_crater():
		return
	var rim := Arena.ffa_creep_rim_radius(body_radius)
	if global_position.length() >= rim:
		return
	var radial := global_position.normalized() if global_position.length() > 1.0 else Vector2.RIGHT
	global_position = radial * rim


static func _separation_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / SEPARATION_CELL_SIZE)), int(floor(pos.y / SEPARATION_CELL_SIZE)))


## Rebuilds the shared enemy->cell bucket map at ~12.5 Hz (gated by time, not by
## physics frame). O(n) total per rebuild however many enemies call
## _separation_offset() — far cheaper than the old per-enemy
## `get_tree().get_nodes_in_group("enemies")` linear scan (O(n^2) overall).
## 12.5 Hz rebuilds are visually identical for a velocity-offset push while
## halving the rebuild frequency for large pools.
func _rebuild_separation_grid() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - Enemy._separation_grid_time < SEPARATION_GRID_INTERVAL:
		return
	Enemy._separation_grid_time = now
	Enemy._separation_grid.clear()
	# Perf (large groups): single-pass group scan (one allocation per rebuild
	# instead of one per enemy), same O(n) total cost as before.
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	for candidate in all_enemies:
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var key := _separation_cell((candidate as Node2D).global_position)
		var bucket: Array = Enemy._separation_grid.get(key, [])
		bucket.append(candidate)
		Enemy._separation_grid[key] = bucket


## Pick a movement pattern based on enemy type so large groups move with variety.
func _pick_move_pattern() -> int:
	match type_id:
		"swarmling":
			return MovePattern.NONE  # Pack formation — no individual variation
		"grunt":
			return MovePattern.STRAFE
		"spitter", "frostspitter", "embercaster":
			return MovePattern.CIRCLE
		"brute":
			return MovePattern.LUNGE
		"charger", "skitter":
			return MovePattern.ZIGZAG
		_:
			return MovePattern.ZIGZAG


func _separation_offset() -> Vector2:
	if separation_weight <= 0.0:
		return Vector2.ZERO
	_rebuild_separation_grid()
	var push := Vector2.ZERO
	var range_sq := SEPARATION_RANGE * SEPARATION_RANGE
	var base_cell := _separation_cell(global_position)
	# SEPARATION_CELL_SIZE >= SEPARATION_RANGE guarantees every enemy within range sits in
	# this 3x3 neighbourhood around our own cell — see the constant's comment above.
	# `get(key)` without a default avoids allocating an empty Array on every
	# missing-cell lookup (the previous `.get(key, [])` built a new Array per
	# empty cell, 9 times per enemy per physics frame).
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var bucket_raw = Enemy._separation_grid.get(Vector2i(base_cell.x + dx, base_cell.y + dy))
			if bucket_raw == null:
				continue
			var bucket: Array = bucket_raw
			for candidate in bucket:
				if candidate == self or not is_instance_valid(candidate):
					continue
				var cand_node: Node2D = candidate as Node2D
				if cand_node == null:
					continue
				var offset: Vector2 = global_position - cand_node.global_position
				var distance_sq := offset.length_squared()
				if distance_sq <= 0.01 or distance_sq > range_sq:
					continue
				push += offset.normalized() * (1.0 - sqrt(distance_sq) / SEPARATION_RANGE)
	if push == Vector2.ZERO:
		return Vector2.ZERO
	return push.limit_length(2.0) * SEPARATION_STRENGTH / maxf(0.3, separation_weight)


## No-op stub kept so selftest_driver.gd's periodic [perf] print doesn't crash
## after the temp instrumentation was removed.
static func consume_separation_stats() -> Dictionary:
	return {"calls": 0, "candidates": 0}


func _process_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0 or wander_direction == Vector2.ZERO:
		wander_direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		wander_timer = randf_range(WANDER_TURN_MIN, WANDER_TURN_MAX)
	_move(wander_direction * movement_speed * WANDER_SPEED_MULT * slow_factor)


## Player is camping the crater: walk to the rim and hold, don't orbit forever.
func _process_crater_watch() -> void:
	var rim := Arena.ffa_creep_rim_radius(body_radius)
	var dist := global_position.length()
	if dist <= rim + 8.0:
		velocity = Vector2.ZERO
		return
	var inward := -global_position.normalized() if dist > 1.0 else Vector2.LEFT
	_move(inward * movement_speed * slow_factor, true)


func _process_melee() -> void:
	var distance := global_position.distance_to(target.global_position)
	if explode_damage > 0.0 and distance <= attack_distance:
		_explode()
		return
	if distance > attack_distance:
		var chase_dir := global_position.direction_to(target.global_position)
		_move(_apply_move_pattern(chase_dir * movement_speed * slow_factor))
	else:
		velocity = Vector2.ZERO
		_attack_target()


## Applies the per-enemy movement pattern to a base chase direction.
## Returns the modified velocity vector.
func _apply_move_pattern(base_dir: Vector2) -> Vector2:
	_move_pattern_timer += get_physics_process_delta_time()
	if _move_pattern == MovePattern.NONE:
		return base_dir
	var to_target := target.global_position - global_position
	if to_target.length_squared() < 1.0:
		return base_dir
	var target_dir := to_target.normalized()
	match _move_pattern:
		MovePattern.STRAFE:
			# Sideswipe: add a perpendicular component that oscillates.
			# PINCER tactic uses a wider strafe (0.7) for more dramatic flanking.
			var amp := 0.7 if _wave_tactic == 0 else STRAFE_AMP
			var perp := target_dir.orthogonal()
			var strafe := sin(_move_pattern_phase + _move_pattern_timer * 3.0) * amp
			return (target_dir + perp * strafe).normalized() * base_dir.length()
		MovePattern.ZIGZAG:
			# Alternating left/right offset.
			var perp := target_dir.orthogonal()
			var zig := sin(_move_pattern_timer * (TAU / ZIGZAG_PERIOD)) * STRAFE_AMP
			return (target_dir + perp * zig).normalized() * base_dir.length()
		MovePattern.CIRCLE:
			# Orbit: move mostly perpendicular to the target direction.
			var perp := target_dir.orthogonal()
			var mix := CIRCLE_SPEED
			return (target_dir * (1.0 - mix) + perp * mix * signf(sin(_move_pattern_timer * 0.8))) * base_dir.length()
		MovePattern.LUNGE:
			# Periodic forward burst.
			_lunge_timer -= get_physics_process_delta_time()
			if _lunge_timer <= 0.0:
				_lunge_timer = LUNGE_INTERVAL
			var in_lunge := _lunge_timer > LUNGE_INTERVAL - LUNGE_DURATION
			if in_lunge:
				return base_dir * LUNGE_SPEED_MULT
			return base_dir
		_:
			return base_dir


func _process_ranged() -> void:
	_hold_preferred_distance()
	if global_position.distance_to(target.global_position) <= attack_distance:
		_fire_projectile()


## 2026-09-18: Recruited camp-creep AI — the camp creep follows its owner
## player (orbit at CAMP_RECRUIT_FOLLOW_RADIUS) and attacks the nearest regular
## enemy / camp guardian / enemy hero. Does NOT attack its own owner.
## 2026-09-18: follow ring widened (30 -> 70) so recruited creeps spread out
## around the hero instead of stacking on top of each other; aggro range raised
## (220 -> 360) so they notice enemies sooner.
const CAMP_RECRUIT_FOLLOW_RADIUS := 70.0
const CAMP_RECRUIT_COMBAT_RANGE := 360.0

## Per-camp-creep idle-bob phase. Every camp creep (idle or recruited) gets its
## own random phase, so the whole camp bobs out of sync and reads as "alive"
## rather than a static pile of sprites.
var _recruit_bob_phase := 0.0

var _recruit_target: Node2D = null
var _recruit_retarget_timer := 0.0


## 2026-09-18: separation push for recruited creeps. Uses the shared enemy
## spatial grid (same _separation_grid the regular creeps use) so a recruited
## camp of 20 creeps spreads out around the hero instead of stacking into a
## single overlapping blob. Cheap: one 3x3 neighbourhood scan per recruit.
func _recruit_separation() -> Vector2:
	if not Enemy._separation_grid.has(_separation_cell(global_position)):
		_rebuild_separation_grid()
	var push := Vector2.ZERO
	var range_sq := SEPARATION_RANGE * SEPARATION_RANGE
	var base_cell := _separation_cell(global_position)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var bucket_raw = Enemy._separation_grid.get(Vector2i(base_cell.x + dx, base_cell.y + dy))
			if bucket_raw == null:
				continue
			var bucket: Array = bucket_raw
			for candidate in bucket:
				if candidate == self or not is_instance_valid(candidate):
					continue
				var cand_node: Node2D = candidate as Node2D
				if cand_node == null:
					continue
				var offset: Vector2 = global_position - cand_node.global_position
				var distance_sq := offset.length_squared()
				if distance_sq > range_sq or distance_sq <= 0.0:
					continue
				push += offset.normalized() * (1.0 - sqrt(distance_sq) / SEPARATION_RANGE)
	return push * SEPARATION_STRENGTH


func _process_camp_recruit(delta: float) -> void:
	if recruit_owner == null or not is_instance_valid(recruit_owner):
		# Owner gone — stop moving.
		velocity = Vector2.ZERO
		return

	# 2026-09-18: advance the recruit bob phase so the idle-bob animation
	# (sprite.position.y) runs even while recruited. This also drives the
	# orbital slot angle in the orbit-when-idle branch below.
	_recruit_bob_phase += delta * 2.6
	if sprite != null:
		sprite.position = Vector2(0.0, sin(_recruit_bob_phase) * 1.5)

	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	_recruit_retarget_timer -= delta
	if _recruit_retarget_timer <= 0.0:
		_recruit_retarget_timer = 0.4
		_recruit_target = _find_nearest_hostile()

	# If there is a hostile target in combat range, move toward it and attack.
	if _recruit_target != null and is_instance_valid(_recruit_target):
		var dist := global_position.distance_to(_recruit_target.global_position)
		if dist <= attack_distance:
			velocity = Vector2.ZERO
			# Friendly-fire guard: never damage the owner, the owner's
			# same-team players, or other recruited camp creeps.
			if _is_friendly_to_recruit(_recruit_target):
				target = null
				queue_redraw()
				return
			# Recruits have no normal `target`; point it at the hostile and
			# fire a direct contact hit. _attack_target() is gated on the
			# shared `target` var + attack_cooldown, so we drive the hit and
			# cooldown ourselves to guarantee a per-attack_interval cadence.
			if contact_damage > 0.0 and attack_cooldown <= 0.0:
				var th := _recruit_target.get_node_or_null("HealthComponent") as HealthComponent
				if th != null and th.has_method("take_damage"):
					th.call("take_damage", contact_damage, self)
				attack_cooldown = attack_interval
				target = _recruit_target
				_play_melee_dash()
		else:
			# Recruits move via direct position update, not move_and_slide():
			# their collision shapes were deferred-disabled/enabled on recruit,
			# and the shared physics frame can be full of other enemies'
			# move_and_slide calls, which silently blocks/zeroes this body's
			# motion. Direct position move is the pattern idle camp creeps and
			# flying enemies already use, and it guarantees the recruit closes
			# the gap regardless of the physics frame's other traffic.
			var chase_dir := global_position.direction_to(_recruit_target.global_position)
			# 2026-09-18: add separation so a recruited swarm doesn't stack
			# on top of the same target — each creep pushes off its neighbours
			# while still converging on the hostile.
			var sep := _recruit_separation()
			var step := (chase_dir * movement_speed + sep) * get_physics_process_delta_time()
			global_position += step
			# Face the movement direction for the sprite.
			if sprite != null and step.length_squared() > 0.01:
				sprite.flip_h = step.x < 0.0
		queue_redraw()
		return

	# No hostile in range — orbit the owner on a per-camp-creep ring slot so
	# the group forms a loose ring instead of a single overlapping point.
	# Each creep has a fixed slot angle (hash of its network_id) and a fixed
	# orbital radius (base + phase offset), so creeps settle at different
	# angles AND different radii instead of all chasing the same orbit.
	var to_owner: Vector2 = recruit_owner.global_position - global_position
	var owner_dist := to_owner.length()
	if owner_dist < 1.0:
		queue_redraw()
		return
	# Per-camp-creep phase (seeded in _ready) gives each creep its own slot
	# angle and orbital radius offset.
	var phase := fmod(_recruit_bob_phase, TAU)
	var slot_angle: float = fmod(sin(phase) * PI, TAU) - PI
	var slot_radius: float = CAMP_RECRUIT_FOLLOW_RADIUS * (0.85 + 0.3 * fmod(sin(phase * 1.7 + 1.3), 1.0))
	var target_pos: Vector2 = recruit_owner.global_position + Vector2(cos(slot_angle), sin(slot_angle)) * slot_radius
	var to_target: Vector2 = target_pos - global_position
	var target_dist: float = to_target.length()
	# Move toward the slot position (faster when far, slower when close),
	# plus a gentle tangential drift so the ring feels alive.
	var tangential: Vector2 = to_target.rotated(PI / 2.0)
	var step: Vector2
	if target_dist > 12.0:
		step = to_target.normalized() * minf(movement_speed * 0.9, target_dist * 4.0) * get_physics_process_delta_time()
	else:
		step = tangential * movement_speed * 0.2 * get_physics_process_delta_time()
	# 2026-09-18: separation push so recruited creeps spread out instead of
	# stacking at the same follow point.
	step += _recruit_separation() * get_physics_process_delta_time()
	global_position += step
	queue_redraw()


func _find_nearest_hostile() -> Node2D:
	"""Find the nearest hostile entity (regular enemy, camp guardian, or enemy
	hero — i.e. any node in group 'enemies' that is not this camp creep,
	plus any Player that is NOT the recruit_owner)."""
	var best: Node2D = null
	var best_d := CAMP_RECRUIT_COMBAT_RANGE * CAMP_RECRUIT_COMBAT_RANGE
	# Regular enemies / camp guardians.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		if not is_instance_valid(node) or node is Player:
			continue
		# Skip other camp creeps (both idle and recruited) — they're neutral
		# until recruited, and recruited allies shouldn't fight each other.
		if "is_camp_creep" in node and bool(node.get("is_camp_creep")):
			continue
		var d_sq: float = global_position.distance_squared_to(node.global_position)
		if d_sq < best_d:
			best_d = d_sq
			best = node
	# Enemy players (FFA rivals). In co-op, all players are allies of the owner,
	# so only FFA rivals are hostiles.
	if recruit_owner != null and recruit_owner is Player:
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p) or p == recruit_owner:
				continue
			# Friendly-fire guard: never target the owner's own team.
			if "team_id" in p and str(p.get("team_id")) != "":
				if str(p.get("team_id")) == str(recruit_owner.get("team_id")):
					continue
			if "is_local_player" in p and p.is_local_player:
				continue
			var d_sq: float = global_position.distance_squared_to(p.global_position)
			if d_sq < best_d:
				best_d = d_sq
				best = p
	return best


## True when `other` is a friendly unit that this recruited camp creep must
## never damage: its owner, the owner's same-team players, or any other
## recruited camp creep. Idle (un-recruited) camp creeps are neutral and also
## never targeted.
func _is_friendly_to_recruit(other: Node2D) -> bool:
	if other == null or not is_instance_valid(other):
		return false
	# Never fight the owner or the owner's team.
	if recruit_owner != null and recruit_owner is Player:
		if other == recruit_owner:
			return true
		if other is Player and "team_id" in other:
			if str(other.get("team_id")) != "" and str(other.get("team_id")) == str(recruit_owner.get("team_id")):
				return true
	# Never fight other recruited camp creeps (allies) or any camp creep.
	if "is_camp_creep" in other and bool(other.get("is_camp_creep")):
		return true
	return false


func _process_support() -> void:
	_hold_preferred_distance()


## Camp guardian behaviour: hold position at the camp, do not chase the player
## beyond the leash radius, and emit a periodic undodgeable area slam pulse when
## the player is inside the camp. If the target drops out of the leash radius,
## the guardian stops moving (no chase) so kiting away fully disengages.
func _process_camp_guardian(delta: float) -> void:
	# Slam pulse timer.
	_camp_guardian_slaam_timer -= delta
	if _camp_guardian_slaam_timer <= 0.0:
		_camp_guardian_slaam_timer = CAMP_GUARDIAN_SLAM_INTERVAL
		_emit_camp_guardian_slaam()
	# Task 2 — camp aggro. The guardian actively hunts the `target` it's leashed to:
	# it closes the gap faster than a normal melee creep (CAMP_GUARDIAN_AGGR_SPEED_MULT)
	# and stops at the *contact* range (body_radius + buffer) instead of the old
	# attack_distance, so the Task-1 contact attack actually connects. Damage to the
	# player it's inside of is applied by _contact_attack_player() (runs every frame in
	# _physics_process and hits *any* player in range — including a different FFA rival
	# than this guardian's aggro target), so we deliberately do NOT also call
	# _attack_target() here, which would double-hit the same player. Past the leash it
	# still gives up (kiting away disengages) — the leash is kept on purpose so a player
	# can disengage from a camp they're losing.
	var dist := global_position.distance_to(target.global_position)
	if dist <= CAMP_GUARDIAN_LEASH_RADIUS:
		var contact_stop := attack_distance + body_radius
		if dist > contact_stop:
			velocity = global_position.direction_to(target.global_position) * movement_speed * 0.85 * CAMP_GUARDIAN_AGGR_SPEED_MULT
		else:
			velocity = Vector2.ZERO
		# Fast ranged attacks: the camp guardian actively shoots the engaged player
		# (per user request: camps should "be fast with attacking you or projectiles").
		# This is IN ADDITION to the contact tick + undodgeable slam pulse, so a camp
		# that is being attacked shoots back immediately.
		if camp_projectile_interval > 0.0 and projectile_damage > 0.0:
			_camp_projectile_timer -= delta
			if _camp_projectile_timer <= 0.0 and dist <= camp_projectile_range:
				_camp_projectile_timer = camp_projectile_interval
				_camp_guardian_fire_bolt()
		# Visual: face the target.
		queue_redraw()
	else:
		# Out of leash: return to camp home position (sentinel behavior).
		# T3.58: instead of just stopping, walk back to the camp.
		if is_camp_guardian and camp_guardian_home != Vector2.ZERO:
			var home_dist := global_position.distance_to(camp_guardian_home)
			if home_dist > 20.0:
				velocity = global_position.direction_to(camp_guardian_home) * movement_speed * 0.7
			else:
				velocity = Vector2.ZERO
		else:
			velocity = Vector2.ZERO
		# Reset the bolt timer so a fresh engage doesn't get an instant shot.
		_camp_projectile_timer = 0.0


## Camp guardian ranged bolt: fires a fast projectile at the current target.
## Uses the per-camp projectile profile (projectile_count / projectile_speed /
## projectile_sprite) so each camp type reads distinctly.
func _camp_guardian_fire_bolt() -> void:
	if target == null or not server_authoritative or projectile_damage <= 0.0:
		return
	var dmg := projectile_damage
	if _solo_boss_fight():
		dmg *= SOLO_BOSS_HAZARD_DAMAGE_MULT
	var base_direction := global_position.direction_to(target.global_position)
	var count := maxi(1, projectile_count)
	var spread := deg_to_rad(14.0)
	var start := -spread * float(count - 1) * 0.5
	for index in count:
		var direction := base_direction.rotated(start + spread * float(index))
		projectile_fired.emit(global_position, direction, dmg, projectile_speed, projectile_sprite)


## Emit an undodgeable area damage pulse around the camp guardian. All players
## inside CAMP_GUARDIAN_SLAM_RADIUS take CAMP_GUARDIAN_SLAM_DAMAGE.
func _emit_camp_guardian_slaam() -> void:
	var arena_root := get_parent()
	if arena_root == null:
		return
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.health.is_dead:
			continue
		if global_position.distance_to(player.global_position) <= CAMP_GUARDIAN_SLAM_RADIUS:
			player.health.take_damage(CAMP_GUARDIAN_SLAM_DAMAGE, self)
			# Visual feedback: brief red flash on the player.
			var flash := create_tween()
			flash.tween_property(player, "modulate", Color(1.3, 0.9, 0.9, 1.0), 0.05)
			flash.tween_property(player, "modulate", Color.WHITE, 0.12)


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
			SoundDirector.play("dash", global_position)
		return true

	dash_timer -= delta
	if dash_timer <= 0.0:
		winding_up = true
		charge_state_timer = charge_windup / WorldClock.night_attack_mult
		velocity = Vector2.ZERO
		queue_redraw()
		SoundDirector.play("charge", global_position)
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
	SoundDirector.play("boss_alert")


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
	# T3.35 item 9: every boss pattern attack must carry the boss SFX, not just the
	# plain per-interval _attack_target()/_fire_projectile() strikes.
	SoundDirector.play("boss_attack", global_position)
	match pattern:
		"dash":
			winding_up = true
			charge_state_timer = charge_windup * (0.75 if boss_phase >= 3 else 1.0)
			pattern_cooldown = maxf(1.35, dash_interval / float(boss_phase + 1))
			SoundDirector.play("charge", global_position)
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
			# Storm keeps its signature stack (slam volley + cross lines), but the cross
			# lines are trimmed down: only the two base lines (toward + perpendicular, no
			# diagonals at phase 3+) and a capped length so the screen isn't wallpapered.
			# The full slam volley on top of four screen-filling 7200-unit diagonals left
			# no dodge lane for one solo target.
			slam_shots_left = 1 + boss_phase
			slam_shot_gap = 0.0
			_emit_cross_lines(strike_damage, true)
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
	elif type_id == "magma_golem":
		# Magma Golem: heavy slam + fire bloom + dash (no ranged projectile of its own).
		pool = ["slam", "slam", "dash"]
	elif type_id == "frost_titan":
		# Frost Titan: kites at range with frost volleys, occasional dash to reposition.
		pool = ["slam", "volley", "volley"]
	elif type_id == "scrap_colossus":
		# Scrap Colossus: tanky ranged, scrap-bolt volleys + cross lines.
		pool = ["slam", "volley", "cross"]
	elif type_id == "dock_warden":
		# Dock Warden: fast melee/dash + occasional shockwave from the docks.
		pool = ["dash", "slam", "slam"]
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


func _emit_cross_lines(strike_damage: float, trimmed := false) -> void:
	var toward := 0.0 if target == null else global_position.direction_to(target.global_position).angle()
	var angles: Array[float] = [toward, toward + PI * 0.5]
	if boss_phase >= 3 and not trimmed:
		angles.append(toward + PI * 0.25)
		angles.append(toward - PI * 0.25)
	# 7200 units spanned the entire arena and, combined with the slam volley stacked on
	# top by the "storm" pattern, left nothing to dodge into. The capped length keeps the
	# cross lines clearly visible without filling the screen.
	var line_length := 2400.0 if trimmed else 7200.0
	for angle in angles:
		_emit_hazard({
			"kind": "line",
			"origin": global_position,
			"angle": angle,
			"length": line_length,
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
			SoundDirector.play("dash", global_position)
		return

	var distance := global_position.distance_to(target.global_position)
	if distance <= charge_speed * charge_duration * 0.8 and distance > attack_distance:
		winding_up = true
		charge_state_timer = charge_windup
		velocity = Vector2.ZERO
		queue_redraw()
		SoundDirector.play("charge", global_position)
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
	attack_cooldown = attack_interval / WorldClock.night_attack_mult
	return true


func _hold_preferred_distance() -> void:
	var distance := global_position.distance_to(target.global_position)
	var to_target := global_position.direction_to(target.global_position)
	if distance > preferred_distance + 60.0:
		_move(_apply_move_pattern(to_target * movement_speed * slow_factor))
	elif distance < preferred_distance - 60.0:
		_move(_apply_move_pattern(-to_target * movement_speed * slow_factor))
	else:
		# Orbit in place: small perpendicular drift so ranged enemies don't stand still.
		if _move_pattern != MovePattern.NONE:
			var perp := to_target.orthogonal()
			var orbit := sin(_move_pattern_timer * 0.9 + _move_pattern_phase) * 0.2
			_move(perp * movement_speed * orbit * slow_factor)
		else:
			_move(Vector2.ZERO)


func _fire_projectile() -> void:
	if attack_cooldown > 0.0 or projectile_damage <= 0.0:
		return
	attack_cooldown = attack_interval / WorldClock.night_attack_mult
	# T3.35 item 9: ranged boss attacks also need the boss SFX, matching the melee
	# path in _attack_target().
	if is_boss:
		SoundDirector.play("boss_attack", global_position)
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
	SoundDirector.play("hit", global_position)
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
	# Perf (large groups): hazard_at() is a linear scan over the arena's hazard
	# zones — calling it every physics frame for every enemy is O(zones * enemies).
	# Throttle the scan to ~6.25 Hz; the DoT accumulates in _lava_scan_acc so the
	# total damage over any window is unchanged (dot * elapsed, applied in ~0.16s
	# batches). Standing-in-lava is a slow-effect, not a reaction-critical one.
	_lava_scan_acc += delta
	if _lava_scan_acc < LAVA_SCAN_INTERVAL:
		return
	var scan_dt := _lava_scan_acc
	_lava_scan_acc = 0.0
	var hazard := _arena.hazard_at(global_position)
	if hazard.is_empty() or str(hazard.get("type", "")) != "lava":
		return
	var dot := float(hazard.get("enemy_dot", 0.0))
	if dot <= 0.0:
		return
	health.take_damage(dot * scan_dt, self)


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
			SoundDirector.play("charge", global_position)
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


## T3.92 — rebuild the shared player snapshot at most once per physics frame.
## This collapses N× (get_nodes_in_group + per-player validation) into a single
## O(players) rebuild that all enemies read from. Non-static so it can call
## get_tree() (same pattern as _rebuild_separation_grid).
func _rebuild_player_snapshot() -> void:
	var frame := Engine.get_physics_frames()
	if frame == Enemy._player_snap_frame:
		return
	Enemy._player_snap_frame = frame
	var snap: Array = []
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player or not candidate.active:
			continue
		var player := candidate as Player
		if player.is_phase_cloaked() or player.in_boss_form:
			continue
		snap.append(player)
	Enemy._player_snap = snap


func _find_nearest_player() -> Node2D:
	var nearest: Node2D
	var best_score := INF
	var crater_block := Arena.ffa_blocks_creeps_from_crater()
	var crater := Arena.crater_radius()
	_rebuild_player_snapshot()
	for candidate in Enemy._player_snap:
		var player := candidate as Player
		if crater_block and player.global_position.length() < crater:
			continue
		var weight := 1.0 if taunt_immune else player.taunt_weight
		var score: float = global_position.distance_squared_to(player.global_position) * weight
		if score < best_score:
			nearest = player
			best_score = score
	# Turrets are damageable targetable units — creeps will prefer them over the player
	# when they're closer, so a lone turret can pull aggro and buy time.
	# T3.91: skip turrets that are dead, out-of-tree, or queued for free — these are
	# the "invisible leftover objects" that otherwise pull creeps away from players.
	for candidate in get_tree().get_nodes_in_group("turrets"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		# T3.91: a turret that is no longer in the tree (queued for free but not yet
		# flushed) is an invisible leftover — never target it.
		if not candidate.is_inside_tree():
			continue
		var turret := candidate as Node2D
		var turret_health: HealthComponent = turret.get("health") as HealthComponent
		if turret_health == null or turret_health.is_dead:
			continue
		if crater_block and turret.global_position.length() < crater:
			continue
		# Turrets have a taunt_weight property (0.6 by default) — lower than a player
		# (1.0) so a turret only pulls aggro when it's actually closer than the player.
		var turret_weight: float = float(turret.get("taunt_weight")) if "taunt_weight" in turret else 0.6
		var score: float = global_position.distance_squared_to(turret.global_position) * turret_weight
		if score < best_score:
			nearest = turret
			best_score = score
	return nearest


func _any_living_player_in_crater() -> bool:
	if not Arena.ffa_blocks_creeps_from_crater():
		return false
	var crater := Arena.crater_radius()
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.is_phase_cloaked():
			continue
		if player.global_position.length() < crater:
			return true
	return false


## True when every player in range is phase-cloaked, so a null target should wander
## instead of freezing in place (see apply_phase_cloak / _process_wander).
func _any_player_cloaked() -> bool:
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Player and (candidate as Player).is_phase_cloaked():
			return true
	return false


## Cheap squared-distance check used by the far-cull. No group allocation, no
## behaviour dispatch — just a fast scan of living, un-cloaked, non-boss players.
func _any_player_within_far_cull() -> bool:
	var r2 := FAR_CULL_RADIUS * FAR_CULL_RADIUS
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var p := candidate as Player
		# In FFA, a dead player still counts for culling so enemies remain visible
		# on screen during the respawn countdown.
		if not p.active:
			if GameRuntime.is_ffa():
				if global_position.distance_squared_to(p.global_position) <= r2:
					return true
			continue
		if p.is_phase_cloaked() or p.in_boss_form:
			continue
		if global_position.distance_squared_to(p.global_position) <= r2:
			return true
	return false


## Enters lightweight "far" mode: the sprite is hidden so it stops costing draw
## calls / canvas items, and physics collision is disabled so move_and_slide and
## separation are not run while the enemy simply walks toward the player.
var _in_far_mode := false
func _enter_far_mode() -> void:
	if _in_far_mode:
		return
	_in_far_mode = true
	if sprite != null:
		sprite.visible = false
	# 2026-09-18: far-cull is a perf optimization for regular creeps off-screen.
	# Camp creeps are small, fixed, and externally driven (idle linger or
	# recruited follow/attack) — culling their physics would freeze their
	# bob/wander/recruit AI when the player is far away. Keep them always-on.
	if is_camp_creep:
		_in_far_mode = false
		return
	set_physics_process(false)


## Returns the enemy to full rendering + physics once it comes within cull range.
func _exit_far_mode() -> void:
	if not _in_far_mode:
		return
	_in_far_mode = false
	if sprite != null:
		sprite.visible = true
	set_physics_process(true)


## Task 1 — active contact attack. Unlike _attack_target (which only strikes `target`, the
## single nearest player, when it's in melee range and the enemy is idle), this deals
## contact_damage to *any* living player whose body sits within body_radius + buffer, on a
## per-enemy cooldown. That matters in two places:
##   1. A stationary player standing next to a creep is actually hit on a ~1s cadence, not
##      only when the creep happens to walk into it.
##   2. Camp guardians (Task 2) whose AI `target` is a *closer* FFA rival still chip the
##      player physically standing in the camp, so "standing in a camp = meaningful damage
##      over time" holds even when the guardian is focused elsewhere.
## Only runs when server_authoritative (damage is server-side) and when a player is actually
## near (gated by the far-cull _near_player check in _physics_process).
func _contact_attack_player() -> void:
	if not server_authoritative or contact_damage <= 0.0 or _player_attack_cooldown > 0.0:
		return
	var range_sq := (body_radius + CONTACT_ATTACK_RANGE_BUFFER) * (body_radius + CONTACT_ATTACK_RANGE_BUFFER)
	var struck := false
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.in_boss_form:
			continue
		var player_health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
		if player_health == null or player_health.is_dead:
			continue
		if global_position.distance_squared_to(player.global_position) > range_sq:
			continue
		var dmg := contact_damage
		if _solo_boss_fight():
			dmg *= SOLO_BOSS_HAZARD_DAMAGE_MULT
		if retaliation_timer > 0.0:
			dmg *= RETALIATION_DAMAGE_MULT
		if is_camp_guardian:
			# Log so the camp-aggro contact hit is verifiable in the game log (Task 2).
			print("[CampGuardian] aggro contact hit ", type_id, " -> ", player.class_id, " for ", str(dmg))
		player_health.take_damage(dmg, self)
		struck = true
	if struck:
		_player_attack_cooldown = 1.0 / WorldClock.night_attack_mult
		# Visual lunge only when we actually hit, so the tick reads as a deliberate strike.
		if not is_boss:
			_play_melee_dash()


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
		if retaliation_timer > 0.0:
			dmg *= RETALIATION_DAMAGE_MULT
		target_health.take_damage(dmg, self)
		# Retaliating creeps attack faster while enraged.
		var interval := attack_interval / WorldClock.night_attack_mult
		if retaliation_timer > 0.0:
			interval /= 1.5
		attack_cooldown = interval
		# T3.35 item 9: boss attacks must always carry the distinctive boss SFX so
		# the player hears the threat level even without watching the screen closely.
		if is_boss:
			SoundDirector.play("boss_attack", global_position)
		# Visual: a quick lunge toward the target to telegraph the hit.
		if not is_boss:
			_play_melee_dash()


## A short forward lunge + scale pop that plays when a melee enemy lands a hit,
## so contact damage reads as a deliberate strike instead of an invisible tick.
func _play_melee_dash() -> void:
	if target == null:
		return
	var dir := global_position.direction_to(target.global_position)
	if dir == Vector2.ZERO:
		return
	# Lunge forward a few pixels, hold briefly, then slide back to the start.
	var origin := position
	var lunge := dir * (body_radius * 0.45)
	var tween := create_tween()
	tween.tween_property(self, "position", origin + lunge, 0.05)
	tween.tween_property(self, "position", origin, 0.11)
	# Scale pop for a "slam" feel.
	var base_scale := scale
	tween.tween_property(self, "scale", base_scale * 1.12, 0.05)
	tween.parallel().tween_property(self, "scale", base_scale, 0.10)


func _on_damaged(amount: float) -> void:
	SoundDirector.play("hit", global_position)
	# Retaliation: when hit, the creep becomes briefly enraged (faster, harder hits).
	if not is_boss and server_authoritative:
		retaliation_timer = RETALIATION_DURATION
		# Red-tint the creep while retaliating so the player sees the "fighting back" state.
		modulate = Color(1.4, 0.85, 0.85, 1.0)
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
	# Pop visual: scale up briefly, then shrink to 0, with a white flash on death.
	# Bigger enemies (bosses) get a larger, longer pop.
	var base_scale := scale
	var pop_scale: Vector2
	var pop_up_time: float
	var pop_down_time: float
	# Pop scales with the enemy's body size: tiny grunts snap fast, elites pop bigger, bosses biggest.
	var size_mult := clampf(body_radius / 17.0, 0.6, 2.5)
	if is_boss:
		pop_scale = base_scale * (1.4 + 0.2 * size_mult)
		pop_up_time = 0.08
		pop_down_time = 0.25
	else:
		pop_scale = base_scale * (1.15 + 0.25 * size_mult)
		pop_up_time = 0.04 + 0.02 * size_mult
		pop_down_time = 0.12 + 0.06 * size_mult
	var flash_time := 0.04
	var tween := create_tween()
	# Step 1: scale up (pop) + white flash in parallel.
	tween.tween_property(self, "scale", pop_scale, pop_up_time)
	tween.parallel().tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), flash_time)
	# Step 2: shrink to zero + modulate back to white in parallel.
	tween.tween_property(self, "scale", base_scale * 0.0, pop_down_time)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), flash_time + 0.02)
	# Final callback: restore base scale so the corpse captures full-size art, then free.
	tween.chain().tween_callback(func() -> void:
		if not is_boss:
			scale = base_scale
			var parent := get_parent()
			if parent != null:
				var corpse: Node2D = _MinionCorpse.new()
				corpse.setup_from(self)
				parent.add_child(corpse)
		if is_boss:
			boss_death.emit(self)
		queue_free()
	)


func _draw() -> void:
	# T3.92 — skip draw entirely for off-screen (far-mode) enemies: the sprite is
	# already hidden and physics is disabled, so there is nothing to render. This
	# saves the whole _draw body (color lerp, arcs, overlay draws) for hundreds of
	# ghost enemies at once.
	if _in_far_mode:
		return
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
	# T3.59: red eyes at night
	elif WorldClock.is_night:
		fill = fill.lerp(Color("ff2222"), 0.25)

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
		elif WorldClock.is_night:
			# T3.59: subtle red tint at night so night creeps read as dangerous.
			sprite.modulate = Color(1.15, 0.82, 0.82, 1.0)
		else:
			sprite.modulate = Color.WHITE
		_draw_status_overlays()
		# T3.59: red glowing eyes at night — two small dots on the sprite.
		if WorldClock.is_night:
			_draw_night_eyes()
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
	# T3.85: night eyes also apply to vector-drawn (no-sprite) enemies so the
	# red-eyes-at-night mechanic works for ALL biome skins, not just those with
	# a forged PNG texture.
	if WorldClock.is_night:
		_draw_night_eyes()
	_draw_status_overlays()


## T3.59: red glowing eyes at night — two bright dots with a soft glow halo on
## the upper body. 2026-09-16: enlarged + glow so they're clearly visible on
## every minion (user: "make it so all minions eyes have glowing effect").
func _draw_night_eyes() -> void:
	var eye_color := Color(1.0, 0.15, 0.1, 1.0)
	var glow_color := Color(1.0, 0.2, 0.1, 0.35)
	var r := maxf(2.0, body_radius * 0.15)
	var glow_r := r * 2.2
	var pos_l := Vector2(-body_radius * 0.28, -body_radius * 0.45)
	var pos_r := Vector2(body_radius * 0.28, -body_radius * 0.45)
	# Glow halo (drawn first, behind the bright core)
	draw_circle(pos_l, glow_r, glow_color)
	draw_circle(pos_r, glow_r, glow_color)
	# Bright core
	draw_circle(pos_l, r, eye_color)
	draw_circle(pos_r, r, eye_color)


## T3.85: swap to the red-eyed night sprite variant when night flips. The
## night texture has red eyes baked in (generated by tools/add_creep_eyes.py);
## the day texture is the plain body. At night the CanvasModulate dims the
## whole scene (ambient ~0.38, 0.44, 0.58), so we boost the red channel to
## keep the eyes bright and make them "stick out" from the dimmed body.
## Falls back to a red modulate tint when no night variant exists (e.g. boss
## creeps without a _night sprite).
func _update_night_sprite_tint() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if WorldClock.is_night:
		if _night_texture != null:
			sprite.texture = _night_texture
			# Compensate for the CanvasModulate night ambient (~0.38,0.44,0.58)
			# so the red eyes pop through the darkness. Strong red boost keeps
			# the eyes bright; moderate green/blue keeps the body visible but
			# dimmer than the eyes.
			sprite.modulate = Color(3.0, 1.5, 1.2, 1.0)
		else:
			# No night sprite available (boss creeps): fall back to a warm tint.
			sprite.modulate = Color(1.15, 0.82, 0.82, 1.0)
	else:
		if _day_texture != null:
			sprite.texture = _day_texture
		sprite.modulate = Color.WHITE


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

extends Node2D

## Minigame Camp Creeps — spawn a small group of "recruit" creeps at each
## minigame circle. They are visually recoloured light-yellow while idle
## (they linger around the circle). When the player completes the minigame,
## the creeps switch to the player's accent colour and follow the player.
##
## Only world 1 (grass) is supported for now; the system disables itself on
## other biomes until the recoloured sprites are available.

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const MINIGAME_SCRIPTS := [
	"res://scripts/minigame_treasure_dash.gd",
	"res://scripts/minigame_keg_toss.gd",
	"res://scripts/minigame_whack.gd",
	"res://scripts/minigame_rps.gd",
]

# World 1 (grass) enemy type ids, in wave-unlock order.
# These are the non-boss, non-world-exclusive types available on grass biome.
const WORLD_1_TYPE_IDS: Array[String] = [
	"grunt", "swarmling", "spitter", "drifter", "brute",
	"stalker", "bomber", "hexer", "sentinel", "splitter",
	"lurker", "charger", "summoner",
]

## Idle tint: light yellow so the creeps read as neutral / "recruit pool".
const IDLE_TINT := Color("f5e0a0")
## Recruited tint fallback (used if player accent colour isn't available).
const RECRUITED_TINT := Color("ff8a3d")

## How many creeps to spawn at each minigame camp (grows with wave).
const BASE_CREEPS_PER_CAMP := 20
const MAX_CREEPS_PER_CAMP := 30

## Follow distance: creeps orbit at this radius around the player.
const FOLLOW_RADIUS := 30.0
## Linger radius: creeps wander within this radius of the camp centre.
const LINGER_RADIUS := 80.0
## Camp creeps get 3× the normal HP of their base type.
const CAMP_CREEP_HP_MULT := 3.0

var _main: Node = null
var _minigame_area: Node = null
var _actors: Node2D = null
var _arena: Node2D = null

## Per minigame index: { "creeps": Array[Enemy], "recruited": bool }
var _camp_state: Dictionary = {}

var _next_entity_id := 200_000  # avoid collisions with normal entity ids
var _enabled := false


func start(main_node: Node, minigame_area: Node, actors: Node2D, arena: Node2D) -> void:
	_main = main_node
	_minigame_area = minigame_area
	_actors = actors
	_arena = arena

	# Only enable for world 1 (grass) for now.
	if GameRuntime.biome_id != 0:
		print("[MinigameCampCreeps] disabled: not world 1 (biome_id=", GameRuntime.biome_id, ")")
		return

	_enabled = true
	# Spawn initial camps for the 4 corner minigames (indices 0-3).
	_spawn_camps()
	print("[MinigameCampCreeps] enabled, 4 camps spawned")


## Get the next entity id (used to configure enemies).
func _take_entity_id() -> int:
	var id := _next_entity_id
	_next_entity_id += 1
	return id


## Determine which enemy types have been "introduced" (unlock_wave <= current_wave).
## Returns `count` type_ids sampled from the available pool (repeats allowed so
## the camp can hold ~20 creeps even when only a few types are unlocked).
func _available_types(current_wave: int, count: int) -> Array[String]:
	var pool: Array[String] = []
	for tid in WORLD_1_TYPE_IDS:
		var unlock: int = 1
		var td: Dictionary = EnemyType.by_id(tid)
		if td.has("unlock_wave"):
			unlock = int(td["unlock_wave"])
		# Relax unlock for waves >= 4 (mirror spawnable_for_wave logic)
		if current_wave >= 4:
			unlock = maxi(1, unlock - 2)
		if unlock <= current_wave:
			pool.append(tid)
	if pool.is_empty():
		pool = ["grunt"]
	# Shuffle, then repeat to fill up to `count` (round-robin from the shuffled pool).
	pool.shuffle()
	var out: Array[String] = []
	var idx := 0
	for i in count:
		out.append(pool[idx % pool.size()])
		idx += 1
	return out


## Spawn creeps at each minigame position.
func _spawn_camps() -> void:
	if _minigame_area == null or _actors == null:
		return
	var games: Array = _minigame_area.all_minigames()
	for i in games.size():
		var g: Node2D = games[i]
		if g == null or not is_instance_valid(g):
			continue
		if bool(g.get("active")):
			# Already active — skip for now; camp will be created on finish.
			continue
		_spawn_camp_for_minigame(i, g.global_position)


## Called by main.gd when a new wave starts: top up camps with newly-introduced
## enemy types so the roster reflects wave progression.
func on_wave_started() -> void:
	if not _enabled:
		return
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		# Only top up un-recruited camps; recruited creeps follow the player.
		if bool(state.get("recruited", false)):
			continue
		var existing_count: int = (state["creeps"] as Array).size()
		var target_count := _target_camp_count()
		if existing_count >= target_count:
			continue
		# Find the minigame position to spawn near.
		var g: Node2D = null
		if _minigame_area != null:
			g = _minigame_area.get_minigame(index)
		if g == null or not is_instance_valid(g):
			continue
		var camp_pos: Vector2 = g.global_position
		_spawn_camp_for_minigame(index, camp_pos)


func _target_camp_count() -> int:
	var wave: int = 1
	if _main != null and _main.has_method("get") and _main.get("current_wave") != null:
		wave = int(_main.get("current_wave"))
	return mini(BASE_CREEPS_PER_CAMP + int(wave / 3.0), MAX_CREEPS_PER_CAMP)


## Spawn creeps at one minigame camp position.
func _spawn_camp_for_minigame(index: int, camp_pos: Vector2) -> void:
	if _camp_state.has(index):
		# Already have a camp for this index; refresh it.
		_clear_camp(index)

	var wave: int = 1
	if _main != null and _main.has_method("get") and _main.get("current_wave") != null:
		wave = int(_main.get("current_wave"))

	var count := mini(BASE_CREEPS_PER_CAMP + int(wave / 3.0), MAX_CREEPS_PER_CAMP)
	var types := _available_types(wave, count)

	var state := {"creeps": [], "recruited": false, "positions": []}

	for i in types.size():
		var tid: String = types[i]
		# Position: jitter in a ring around camp centre. The ring starts at
		# LINGER_RADIUS*0.5 (40u) so creeps don't cluster on the minigame circle
		# itself (and on the player spawn point, which sits right at the corner).
		var angle: float = TAU * float(i) / float(types.size())
		var dist: float = randf_range(LINGER_RADIUS * 0.5, LINGER_RADIUS)
		var offset := Vector2(cos(angle), sin(angle)) * dist
		var pos: Vector2 = camp_pos + offset

		var enemy := _spawn_enemy_at(pos, tid)
		if enemy == null:
			continue

		# Make it non-combat: no damage, no taunt, just lingers.
		enemy.contact_damage = 0.0
		enemy.projectile_damage = 0.0
		enemy.explode_damage = 0.0
		enemy.taunt_immune = true
		# Store original position for wander logic
		enemy.set_meta("camp_center", camp_pos)
		enemy.set_meta("camp_index", index)
		enemy.set_meta("minigame_camp_creep", true)
		# Apply idle tint
		_apply_tint(enemy, IDLE_TINT)

		state["creeps"].append(enemy)
		state["positions"].append(pos)

	_camp_state[index] = state
	print("[MinigameCampCreeps] camp %d: spawned %d creeps at %s" % [index, types.size(), camp_pos])


## Spawn a single enemy instance directly (bypasses main.gd's wave logic).
func _spawn_enemy_at(pos: Vector2, type_id: String) -> Enemy:
	if _actors == null:
		return null
	# Instantiate from the enemy scene so the @onready node references
	# (CollisionShape2D, Sprite, HealthComponent) resolve. ENEMY_SCRIPT.new()
	# would bypass the scene tree and leave those null.
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.name = "CampCreep_%d" % _take_entity_id()
	# Add to the "enemies" group so recruit AI and other systems can find it.
	enemy.add_to_group("enemies")
	var fitted_id: String = EnemyType.fit_to_biome(type_id)
	_actors.add_child(enemy)
	enemy.global_position = pos
	# Configure after adding to tree so @onready vars are ready.
	enemy.configure(_take_entity_id(), true, fitted_id, 1.0, 1.0)
	enemy.is_camp_creep = true
	# 2026-09-18: idle camp creeps render with the light-yellow recruit sprite
	# (exact same creature art, body recolored to yellow).
	enemy.recruit_sprite = type_id + "_recruit_yellow"
	enemy._apply_sprite()
	# Camp creeps get 3x HP of their base type so they survive longer when recruited.
	enemy.health.max_health *= CAMP_CREEP_HP_MULT
	enemy.health.current_health = enemy.health.max_health
	# Store original damage values so they can be restored on recruitment.
	enemy.set_meta("original_contact_damage", enemy.contact_damage)
	enemy.set_meta("original_projectile_damage", enemy.projectile_damage)
	# Idle camp creeps are non-combat: no damage to anyone until recruited.
	enemy.contact_damage = 0.0
	enemy.projectile_damage = 0.0
	enemy.explode_damage = 0.0
	enemy.taunt_immune = true
	# Disable the collision shape so they can't be physically hit / knocked.
	if enemy.collision_shape != null:
		enemy.collision_shape.set_deferred("disabled", true)
	return enemy


## Apply a tint to the enemy's sprite (modulate).
func _apply_tint(enemy: Enemy, tint: Color) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.modulate = tint


## Called when a minigame finishes. Recolours creeps to player accent and
## marks them as recruited so they fight and follow.
func on_minigame_finished(index: int, owner_player: Player) -> void:
	if not _enabled:
		return
	if not _camp_state.has(index):
		# No camp exists yet — spawn one at the minigame position.
		if _minigame_area != null:
			var g: Node2D = _minigame_area.get_minigame(index)
			if g != null and is_instance_valid(g):
				_spawn_camp_for_minigame(index, g.global_position)
		return

	var state: Dictionary = _camp_state[index]
	if bool(state.get("recruited", false)):
		return  # already recruited

	var accent: Color = RECRUITED_TINT
	if owner_player != null and is_instance_valid(owner_player):
		accent = owner_player.accent_color

	for enemy in state["creeps"]:
		if enemy == null or not is_instance_valid(enemy):
			continue
		# 2026-09-18: swap to the orange recruit sprite (exact same creature
		# art, body recolored to orange) instead of just modulate-tinting.
		enemy.recruit_sprite = enemy.type_id + "_recruit_orange"
		enemy._apply_sprite()
		_apply_tint(enemy, Color.WHITE)
		# Restore damage so recruited creeps can actually fight.
		enemy.contact_damage = float(enemy.get_meta("original_contact_damage", 0.0))
		enemy.projectile_damage = float(enemy.get_meta("original_projectile_damage", 0.0))
		enemy.taunt_immune = false
		# Enable recruit AI: follow owner + attack hostiles.
		enemy.is_camp_recruit = true
		enemy.recruit_owner = owner_player
		# Re-enable collision so they can physically interact.
		if enemy.collision_shape != null:
			enemy.collision_shape.set_deferred("disabled", false)

	state["recruited"] = true
	print("[MinigameCampCreeps] camp %d recruited! %d creeps now follow player" % [
		index, (state["creeps"] as Array).size()
	])


## Per-frame update: make idle creeps wander. Recruited creeps are driven
## by Enemy._process_camp_recruit (follow owner + attack hostiles).
func _process(delta: float) -> void:
	if not _enabled:
		return
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		var creeps: Array = state.get("creeps", [])
		# Only idle (un-recruited) creeps use the camp system's wander logic.
		if not bool(state.get("recruited", false)):
			_update_lingering(creeps, state.get("positions", []), delta)


## Idle creeps: small wander around camp centre.
func _update_lingering(creeps: Array, positions: Array, delta: float) -> void:
	for i in creeps.size():
		var enemy: Enemy = creeps[i]
		if enemy == null or not is_instance_valid(enemy):
			continue
		var center: Vector2 = positions[i] if i < positions.size() else enemy.global_position
		var to_center: Vector2 = center - enemy.global_position
		var dist: float = to_center.length()
		if dist > LINGER_RADIUS:
			# Walk back toward camp centre
			enemy.global_position += to_center.normalized() * enemy.movement_speed * 0.4 * delta
		elif dist < 30.0:
			# Small random drift
			var drift := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 12.0 * delta
			enemy.global_position += drift
		# Face movement direction (toward camp center when walking back).
		# Enemy sprites face left; flip the sprite node when moving left.
		if enemy.sprite != null:
			enemy.sprite.flip_h = to_center.x < 0.0


## Free all idle creeps for one camp so a refresh can re-spawn a fresh mix.
## Recruited camps are skipped: once recruited the creeps follow the player and
## are not re-rolled by wave progression.
func _clear_camp(index: int) -> void:
	if not _camp_state.has(index):
		return
	var state: Dictionary = _camp_state[index]
	if bool(state.get("recruited", false)):
		return  # don't wipe out creeps that already follow the player
	for enemy in state.get("creeps", []):
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_camp_state[index] = {"creeps": [], "recruited": false, "positions": []}


## Clean up all camp creeps (call on game over or scene teardown).
func clear_all() -> void:
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		for enemy in state.get("creeps", []):
			if enemy != null and is_instance_valid(enemy):
				enemy.queue_free()
	_camp_state.clear()


## 2026-09-18: summary for the selftest camp_creep_probe — one entry per camp
## with creep count, recruited flag, sprite sample, and a few sample positions.
func get_camp_state_summary() -> Array:
	var out: Array = []
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		var creeps: Array = state.get("creeps", [])
		var alive := 0
		var sprites: Array[String] = []
		var sample_pos: Array = []
		var all_3x_hp := true
		for e in creeps:
			if e == null or not is_instance_valid(e):
				continue
			alive += 1
			var rs := str(e.recruit_sprite)
			if not sprites.has(rs):
				sprites.append(rs)
			if sample_pos.size() < 3:
				sample_pos.append([snappedf(e.global_position.x, 1.0), snappedf(e.global_position.y, 1.0)])
			# 3x HP check (camp creeps get CAMP_CREEP_HP_MULT x base type HP)
			var base_hp: float = float(EnemyType.field(e.type_id, "max_health"))
			if absf(e.health.max_health - base_hp * CAMP_CREEP_HP_MULT) > 0.5:
				all_3x_hp = false
		out.append({
			"index": index,
			"total": creeps.size(),
			"alive": alive,
			"recruited": bool(state.get("recruited", false)),
			"all_3x_hp": all_3x_hp,
			"sprites": sprites,
			"sample_pos": sample_pos,
		})
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_all()

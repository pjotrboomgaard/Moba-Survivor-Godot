extends Node2D

## Minigame Camp Creeps — spawn a group of "recruit" creeps at each
## minigame circle. They are visually recoloured light-yellow while idle
## (they linger around the circle). When the player starts a minigame,
## recruitment begins: creeps join one-by-one over RECRUIT_DURATION seconds,
## each turning orange and following the player as it joins. If the player
## leaves early (minigame ends before all are recruited), only the creeps
## that have joined so far follow; the rest remain idle at the camp.
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
## 2026-09-18: reduced to 10 per camp (down from 20) for a tighter feel.
const BASE_CREEPS_PER_CAMP := 10
const MAX_CREEPS_PER_CAMP := 18

## Follow distance: creeps orbit at this radius around the player.
const FOLLOW_RADIUS := 30.0
## Linger radius: creeps wander within this radius of the camp centre.
## 2026-09-18: widened from 160 to 260 so the camp visibly spreads out
## around the minigame circle instead of a tight ring.
const LINGER_RADIUS := 260.0
## Camp creeps get 5× the normal HP of their base type.
const CAMP_CREEP_HP_MULT := 5.0
## Camp creeps render 1.5× larger than regular creeps.
const CAMP_CREEP_SCALE := 1.5

## How long (in seconds) it takes for a full camp to recruit all creeps.
## Creeps join one-by-one over this window while the minigame is active.
## Matches the minigame DURATION so all creeps are recruited by the time the
## minigame finishes (player who plays the full game gets the full army; a
## player who walks away early gets fewer creeps).
const RECRUIT_DURATION := 15.0

var _main: Node = null
var _minigame_area: Node = null
var _actors: Node2D = null
var _arena: Node2D = null

## Per minigame index: {
##   "creeps": Array[Enemy],
##   "recruited": Array[bool],   # per-creep recruited flag
##   "recruit_thresholds": Array[float],  # per-creep threshold (0..1)
##   "recruit_progress": float,  # 0.0..1.0, advances while minigame active
##   "minigame_active": bool,    # true while the minigame at this camp is running
##   "owner": Player,            # the player who started the minigame
##   "positions": Array[Vector2]
## }
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
## the camp can hold ~10 creeps even when only a few types are unlocked).
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
	# 2026-09-19: user-placed "Camp Creep" markers (from the world editor) get
	# their own fully-managed camps. These are independent of the corner
	# minigames, so they index starting at 100 to avoid clobbering the 0-3
	# minigame camps.
	_spawn_camps_for_user_markers()


## Spawn a camp at every user-placed CampCreepMarker in the arena.
## Uses index 100+ so it never collides with the 4 corner minigame camps.
func _spawn_camps_for_user_markers() -> void:
	if _actors == null or _arena == null:
		return
	var markers: Array[Node2D] = []
	for node in _arena.get_children():
		if node is Node2D and node.is_in_group("camp_creep_marker"):
			markers.append(node as Node2D)
	if markers.is_empty():
		return
	markers.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(Vector2.ZERO) < b.global_position.distance_to(Vector2.ZERO))
	for i in markers.size():
		var index := 100 + i
		if _camp_state.has(index):
			continue  # already have a camp for this marker
		var marker: Node2D = markers[i]
		_spawn_camp_for_minigame(index, marker.global_position)
		# Hide the marker ring so it doesn't clutter gameplay.
		if marker.has_method("hide_for_game"):
			marker.call("hide_for_game")
	print("[MinigameCampCreeps] %d user-placed camp markers found" % markers.size())


## Called by main.gd when a new wave starts: add newly-introduced enemy types
## to existing camps so the roster reflects wave progression. Does NOT wipe the
## existing camp — it only adds new creeps to the existing pool.
func on_wave_started() -> void:
	if not _enabled:
		return
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		# Only add to camps with no recruited creeps yet.
		var recruited_arr: Array = state.get("recruited", [])
		var any_recruited := false
		for r in recruited_arr:
			if bool(r):
				any_recruited = true
				break
		if any_recruited:
			continue
		var existing_count: int = (state["creeps"] as Array).size()
		var target_count := _target_camp_count()
		if existing_count >= target_count:
			continue
		# Find the camp centre to spawn new creeps near. Corner minigames (0-3)
		# resolve via the minigame area; user-placed marker camps (100+) have no
		# minigame, so they fall back to their own stored position.
		var g: Node2D = null
		if _minigame_area != null:
			g = _minigame_area.get_minigame(index)
		var camp_pos: Vector2
		var have_pos := false
		if g != null and is_instance_valid(g):
			camp_pos = g.global_position
			have_pos = true
		else:
			var stored: Array = state.get("positions", []) as Array
			if stored.size() > 0:
				camp_pos = Vector2(stored[0])
				have_pos = true
		if not have_pos:
			continue
		# Add only the new creeps (target - existing), not the whole camp.
		var to_add: int = target_count - existing_count
		var wave: int = 1
		if _main != null and _main.has_method("get") and _main.get("current_wave") != null:
			wave = int(_main.get("current_wave"))
		var new_types := _available_types(wave, to_add)
		for i in new_types.size():
			var tid: String = new_types[i]
			# Position: jitter in a wide ring around camp centre.
			var angle: float = TAU * randf()
			var dist: float = randf_range(LINGER_RADIUS * 0.25, LINGER_RADIUS)
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
			enemy.set_meta("camp_center", camp_pos)
			enemy.set_meta("camp_index", index)
			enemy.set_meta("minigame_camp_creep", true)
			_apply_tint(enemy, IDLE_TINT)
			state["creeps"].append(enemy)
			state["positions"].append(pos)
			state["recruited"].append(false)
			# Threshold: new creeps join at the end of the recruitment window.
			var total_after = (state["creeps"] as Array).size()
			state["recruit_thresholds"].append(0.85)
		print("[MinigameCampCreeps] camp %d: added %d new creeps (wave %d, total %d)" % [index, to_add, wave, existing_count + to_add])


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

	var state := {"creeps": [], "recruited": [], "recruit_thresholds": [],
		"recruit_progress": 0.0, "minigame_active": false, "owner": null,
		"positions": []}

	for i in types.size():
		var tid: String = types[i]
		# Position: jitter in a wide ring around camp centre. The ring now starts
		# at LINGER_RADIUS*0.2 so creeps are spread across the whole (now bigger)
		# 260u radius instead of clustering tight on the minigame circle.
		var angle: float = TAU * float(i) / float(types.size()) + randf_range(-0.15, 0.15)
		var dist: float = randf_range(LINGER_RADIUS * 0.2, LINGER_RADIUS)
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
		state["recruited"].append(false)
		# Each creep joins at a fraction of RECRUIT_DURATION into the active
		# minigame. Staggered evenly so recruitment is a steady drip.
		state["recruit_thresholds"].append(float(i + 1) / float(types.size()))

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
	# 2026-09-18: idle camp creeps are invulnerable until recruited.
	enemy.health.invulnerable = true
	# 2026-09-18: camp creeps render 1.5x larger than regular creeps.
	enemy.scale = Vector2(CAMP_CREEP_SCALE, CAMP_CREEP_SCALE)
	# 2026-09-18: idle camp creeps render with the light-yellow recruit sprite
	# (exact same creature art, body recolored to yellow).
	enemy.recruit_sprite = type_id + "_recruit_yellow"
	enemy._apply_sprite()
	# Camp creeps get 5x HP of their base type so they survive longer when recruited.
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


## Called when a minigame starts. Begins the progressive recruitment timer for
## this camp. Creeps will join one-by-one over RECRUIT_DURATION seconds.
func on_minigame_started(index: int, owner_player: Player) -> void:
	if not _enabled:
		return
	if not _camp_state.has(index):
		return
	var state: Dictionary = _camp_state[index]
	state["minigame_active"] = true
	state["owner"] = owner_player
	state["recruit_progress"] = 0.0
	# Start recruiting immediately for the first creep.
	_try_recruit(index, state)


## Called when a minigame finishes.
## - If completed_full=true: recruit ALL remaining creeps (player completed the game).
## - If completed_full=false: player left early; only creeps that already joined
##   stay recruited, the rest remain idle at the camp.
func on_minigame_finished(index: int, owner_player: Player, completed_full: bool = true) -> void:
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
	state["minigame_active"] = false

	if completed_full:
		# Full completion: recruit all remaining creeps.
		var remaining := 0
		for i in (state["creeps"] as Array).size():
			if not bool((state["recruited"] as Array)[i]):
				var enemy: Enemy = (state["creeps"] as Array)[i]
				if enemy != null and is_instance_valid(enemy):
					_recruit_single(enemy, owner_player)
					(state["recruited"] as Array)[i] = true
					remaining += 1
		print("[MinigameCampCreeps] camp %d: full completion, %d additional creeps recruited (progress=%.2f)" % [
			index, remaining, state.get("recruit_progress", 0.0)
		])
	else:
		# Early stop: keep only the creeps that already joined.
		var joined := 0
		for r in state["recruited"]:
			if bool(r):
				joined += 1
		print("[MinigameCampCreeps] camp %d: early stop, %d creeps recruited (progress=%.2f)" % [
			index, joined, state.get("recruit_progress", 0.0)
		])


## Recruit a single creep: swap sprite to orange, restore damage, enable recruit AI.
func _recruit_single(enemy: Enemy, owner_player: Player) -> void:
	# 2026-09-18: swap to the orange recruit sprite (exact same creature
	# art, body recolored to orange) instead of just modulate-tinting.
	enemy.recruit_sprite = enemy.type_id + "_recruit_orange"
	enemy._apply_sprite()
	_apply_tint(enemy, Color.WHITE)
	# Recruit is now a real combat unit: no longer invulnerable.
	enemy.health.invulnerable = false
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


## Check if any creeps in this camp are ready to recruit (threshold <= progress).
func _try_recruit(index: int, state: Dictionary) -> void:
	var progress: float = float(state.get("recruit_progress", 0.0))
	var thresholds: Array = state.get("recruit_thresholds", [])
	var recruited: Array = state.get("recruited", [])
	var creeps: Array = state.get("creeps", [])
	var owner: Player = state.get("owner", null)
	var joined := 0
	for i in creeps.size():
		if i >= recruited.size() or i >= thresholds.size():
			break
		if bool(recruited[i]):
			continue
		if progress >= float(thresholds[i]):
			var enemy: Enemy = creeps[i]
			if enemy == null or not is_instance_valid(enemy):
				continue
			_recruit_single(enemy, owner)
			recruited[i] = true
			joined += 1
	if joined > 0:
		print("[MinigameCampCreeps] camp %d: %d creeps joined (progress=%.2f)" % [
			index, joined, progress
		])


## Per-frame update: advance recruitment progress for active camps, make idle
## creeps wander. Recruited creeps are driven by Enemy._process_camp_recruit
## (follow owner + attack hostiles).
func _process(delta: float) -> void:
	if not _enabled:
		return
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		var creeps: Array = state.get("creeps", [])
		# Progressive recruitment: advance progress while minigame is active.
		if bool(state.get("minigame_active", false)):
			state["recruit_progress"] = minf(1.0, float(state.get("recruit_progress", 0.0)) + delta / RECRUIT_DURATION)
			_try_recruit(index, state)
		# Only idle (un-recruited) creeps use the camp system's wander logic.
		var any_not_recruited := false
		for r in state.get("recruited", []):
			if not bool(r):
				any_not_recruited = true
				break
		if any_not_recruited:
			_update_lingering(creeps, state.get("positions", []), delta)


## Idle creeps: slow random wander within the LINGER_RADIUS of camp centre.
## Each creep picks a new wander target every few seconds (stored in meta)
## and walks toward it at a fraction of its movement speed, so the camp
## reads as a loose, drifting crowd rather than a static cluster.
func _update_lingering(creeps: Array, positions: Array, delta: float) -> void:
	for i in creeps.size():
		var enemy: Enemy = creeps[i]
		if enemy == null or not is_instance_valid(enemy):
			continue
		var center: Vector2 = positions[i] if i < positions.size() else enemy.global_position
		var to_center: Vector2 = center - enemy.global_position
		var dist: float = to_center.length()

		# Wander target handling: pick a new random point in the radius every
		# few seconds (stored in meta), or immediately if none / out of range.
		# sqrt(randf()) gives uniform area coverage inside the circle.
		if not enemy.has_meta("wander_target") or dist > LINGER_RADIUS:
			var r: float = sqrt(randf()) * LINGER_RADIUS * 0.9
			var a: float = TAU * randf()
			enemy.set_meta("wander_target", center + Vector2(cos(a), sin(a)) * r)
			enemy.set_meta("wander_repick", randf_range(2.0, 4.5))

		var repick: float = float(enemy.get_meta("wander_repick", 0.0)) - delta
		if repick <= 0.0:
			var r: float = sqrt(randf()) * LINGER_RADIUS * 0.9
			var a: float = TAU * randf()
			enemy.set_meta("wander_target", center + Vector2(cos(a), sin(a)) * r)
			enemy.set_meta("wander_repick", randf_range(2.0, 4.5))

		var target: Vector2 = enemy.get_meta("wander_target", center)
		var to_target: Vector2 = target - enemy.global_position
		var td: float = to_target.length()
		var WANDER_SPEED_MULT := 0.25  # slow drift, not a sprint
		if td > 4.0:
			enemy.global_position += to_target.normalized() * enemy.movement_speed * WANDER_SPEED_MULT * delta
			# Face movement direction. Enemy sprites face left; flip when moving left.
			if enemy.sprite != null:
				enemy.sprite.flip_h = to_target.x < 0.0


## Free all idle creeps for one camp so a refresh can re-spawn a fresh mix.
## Recruited camps are skipped: once recruited the creeps follow the player and
## are not re-rolled by wave progression.
func _clear_camp(index: int) -> void:
	if not _camp_state.has(index):
		return
	var state: Dictionary = _camp_state[index]
	# If any creep has been recruited, don't wipe the camp.
	var recruited_arr: Array = state.get("recruited", [])
	var any_recruited := false
	for r in recruited_arr:
		if bool(r):
			any_recruited = true
			break
	if any_recruited:
		return  # don't wipe out creeps that already follow the player
	for enemy in state.get("creeps", []):
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_camp_state[index] = {"creeps": [], "recruited": [], "recruit_thresholds": [],
		"recruit_progress": 0.0, "minigame_active": false, "owner": null,
		"positions": []}


## Clean up all camp creeps (call on game over or scene teardown).
func clear_all() -> void:
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		for enemy in state.get("creeps", []):
			if enemy != null and is_instance_valid(enemy):
				enemy.queue_free()
	_camp_state.clear()


## 2026-09-18: summary for the selftest camp_creep_probe — one entry per camp
## with creep count, per-creep recruited flags, sprite sample, recruit progress,
## and a few sample positions.
func get_camp_state_summary() -> Array:
	var out: Array = []
	for index in _camp_state.keys():
		var state: Dictionary = _camp_state[index]
		var creeps: Array = state.get("creeps", [])
		var alive := 0
		var recruited_count := 0
		var sprites: Array[String] = []
		var sample_pos: Array = []
		var recruited_pos: Array = []
		var all_5x_hp := true
		var all_invuln_idle := true
		var all_scaled := true
		var recruit_dmg_ok := true
		var recruit_target_count := 0
		for i in creeps.size():
			var e: Enemy = creeps[i]
			if e == null or not is_instance_valid(e):
				continue
			alive += 1
			var is_rec: bool = false
			if i < (state.get("recruited", []) as Array).size():
				is_rec = bool((state.get("recruited", []) as Array)[i])
			if is_rec:
				recruited_count += 1
				if recruited_pos.size() < 5:
					recruited_pos.append([snappedf(e.global_position.x, 1.0), snappedf(e.global_position.y, 1.0)])
				# Recruited creeps should have their contact damage restored (>0 for melee types)
				var orig_dmg: float = float(e.get_meta("original_contact_damage", 0.0))
				if orig_dmg > 0.0 and e.contact_damage < orig_dmg - 0.01:
					recruit_dmg_ok = false
				if e.target != null or e._recruit_target != null:
					recruit_target_count += 1
			var rs := str(e.recruit_sprite)
			if not sprites.has(rs):
				sprites.append(rs)
			if sample_pos.size() < 3:
				sample_pos.append([snappedf(e.global_position.x, 1.0), snappedf(e.global_position.y, 1.0)])
			# 5x HP check (camp creeps get CAMP_CREEP_HP_MULT x base type HP).
			var base_hp: float = float(EnemyType.field(e.type_id, "max_health"))
			if absf(e.health.max_health - base_hp * CAMP_CREEP_HP_MULT) > 0.5:
				all_5x_hp = false
			# 1.5x scale check.
			if absf(e.scale.x - CAMP_CREEP_SCALE) > 0.01:
				all_scaled = false
			# Idle (non-recruited) camp creeps must be invulnerable.
			if not is_rec and not e.health.invulnerable:
				all_invuln_idle = false
		out.append({
			"index": index,
			"total": creeps.size(),
			"alive": alive,
			"recruited_count": recruited_count,
			"recruited": recruited_count >= creeps.size() and creeps.size() > 0,
			"recruit_progress": snappedf(float(state.get("recruit_progress", 0.0)), 3),
			"minigame_active": bool(state.get("minigame_active", false)),
			"all_5x_hp": all_5x_hp,
			"all_scaled": all_scaled,
			"all_invuln_idle": all_invuln_idle,
			"recruit_dmg_ok": recruit_dmg_ok,
			"recruit_target_count": recruit_target_count,
			"sprites": sprites,
			"sample_pos": sample_pos,
			"recruited_pos": recruited_pos,
		})
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_all()

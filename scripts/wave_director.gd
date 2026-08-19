class_name WaveDirector
extends Node

signal wave_started(wave: int, theme_name: String, debut_type_id: String)
signal intermission_started(next_wave: int, seconds: float)
signal group_ready(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float)

enum Archetype {
	STANDARD,
	SWARM,
	SNIPERS,
	ELITE,
	AIR_ASSAULT,
	AMBUSH,
	BOSS,
}

enum Modifier {
	NONE,
	ENRAGED,
	ARMORED,
	FRAGILE_HORDE,
	## A much bigger budget than the wave would normally get — the "af en toe in het nauw
	## gedreven" spike on top of the otherwise gradual climb, not a permanent difficulty bump.
	SURGE,
}

const MODIFIER_NAMES := {
	Modifier.NONE: "",
	Modifier.ENRAGED: "Enraged",
	Modifier.ARMORED: "Armoured",
	Modifier.FRAGILE_HORDE: "Fragile Horde",
	Modifier.SURGE: "Surge",
}

## Waves 1-20 are hand-written so every enemy gets a calm introduction of its
## own before it ever shows up in a crowd. Beyond that the director improvises.
const SCRIPTED_WAVES: Array[Dictionary] = [
	{"name": "First Contact", "archetype": Archetype.STANDARD},
	{"name": "Growing Numbers", "archetype": Archetype.STANDARD, "debut": "swarmling"},
	{"name": "The Swarm", "archetype": Archetype.SWARM},
	{"name": "Acid Rain", "archetype": Archetype.STANDARD, "debut": "spitter"},
	{"name": "Crossfire", "archetype": Archetype.SNIPERS},
	{"name": "Wings", "archetype": Archetype.STANDARD, "debut": "drifter"},
	{"name": "Air Assault", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.SURGE},
	{"name": "The Wall", "archetype": Archetype.STANDARD, "debut": "brute"},
	{"name": "Shadows", "archetype": Archetype.STANDARD, "debut": "stalker", "modifier": Modifier.ENRAGED},
	{"name": "The Ravager", "archetype": Archetype.BOSS},
	{"name": "Bombardment", "archetype": Archetype.STANDARD, "debut": "bomber"},
	{"name": "Unholy Choir", "archetype": Archetype.STANDARD, "debut": "hexer"},
	{"name": "Iron Line", "archetype": Archetype.STANDARD, "debut": "sentinel"},
	{"name": "Ambush", "archetype": Archetype.AMBUSH, "debut": "lurker"},
	{"name": "Division", "archetype": Archetype.STANDARD, "debut": "splitter"},
	{"name": "Skyfall", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.ENRAGED},
	{"name": "Stampede", "archetype": Archetype.STANDARD, "debut": "charger"},
	{"name": "Night Terrors", "archetype": Archetype.SWARM, "modifier": Modifier.FRAGILE_HORDE},
	{"name": "Dark Ritual", "archetype": Archetype.STANDARD, "debut": "summoner"},
	{"name": "The Stormcaller", "archetype": Archetype.BOSS},
]

const IMPROVISED_NAMES := {
	Archetype.STANDARD: ["Advance", "Pressure", "Relentless", "Grinding Halt"],
	Archetype.SWARM: ["The Swarm", "Infestation", "Countless", "Tide of Teeth"],
	Archetype.SNIPERS: ["Crossfire", "Long Range", "Kill Zone", "Rain of Acid"],
	Archetype.ELITE: ["Elite Guard", "Heavy Metal", "The Vanguard", "Ironclad"],
	Archetype.AIR_ASSAULT: ["Air Assault", "Skyfall", "Wings of Ruin", "Overhead"],
	Archetype.AMBUSH: ["Ambush", "Surrounded", "No Way Out", "Closing In"],
	Archetype.BOSS: ["Boss", "The Reckoning", "Apex"],
}

const INTERMISSION_SECONDS := 14.0
const SHOP_INTERMISSION_SECONDS := 30.0
## The shop only opens after every tenth wave, right on the heels of a boss.
const SHOP_WAVE_INTERVAL := 10
const GROUP_INTERVAL_SECONDS := 1.7
const AMBUSH_GROUP_INTERVAL := 0.2
const WAVE_TIMEOUT_SECONDS := 120.0
const ELITE_WAVE_INTERVAL := 5
const BOSS_WAVE_INTERVAL := 10
## Enemies start noticeably tankier now (2x the old wave-1 health) and keep climbing faster
## than before, so the run keeps escalating rather than plateauing once players out-level it.
const BASE_HEALTH_MULTIPLIER := 2.0
const HEALTH_GROWTH_PER_WAVE := 0.10

## The lobby's difficulty pick scales enemy health on top of the wave curve above (Pjotr mode
## only — Classic's endless-grunt test loop stays flat regardless of this).
const DIFFICULTY_HEALTH_MULTIPLIERS := {
	GameRuntime.Difficulty.EASY: 0.65,
	GameRuntime.Difficulty.NORMAL: 1.0,
	GameRuntime.Difficulty.HARD: 1.5,
	GameRuntime.Difficulty.BRUTAL: 2.25,
}

const CLASSIC_SPAWN_INTERVAL := 1.4
const DEBUT_COUNT := 2

var wave := 0
var archetype: Archetype = Archetype.STANDARD
var modifier: Modifier = Modifier.NONE
var theme_name := ""
var debut_type_id := ""
var running := false
var classic_mode := false
var intermission_timer := 0.0
var group_timer := 0.0
var group_interval := GROUP_INTERVAL_SECONDS
var wave_elapsed := 0.0
var player_count := 1
var pending_groups: Array[Dictionary] = []
var live_enemy_count := 0


func start(next_player_count: int = 1, classic: bool = false) -> void:
	player_count = maxi(1, next_player_count)
	classic_mode = classic
	wave = maxi(1, GameRuntime.start_wave) - 1
	running = true
	intermission_timer = 0.0
	pending_groups.clear()
	live_enemy_count = 0
	if classic_mode:
		wave = 1
		group_timer = 0.0
		wave_started.emit(1, "Classic", "")
		return
	_begin_next_wave()


func stop() -> void:
	running = false
	pending_groups.clear()


func set_player_count(next_player_count: int) -> void:
	player_count = maxi(1, next_player_count)


func report_enemy_count(count: int) -> void:
	live_enemy_count = count


func _process(delta: float) -> void:
	if not running:
		return

	if classic_mode:
		_process_classic(delta)
		return

	if intermission_timer > 0.0:
		intermission_timer = maxf(0.0, intermission_timer - delta)
		if intermission_timer <= 0.0:
			_begin_next_wave()
		return

	wave_elapsed += delta

	if not pending_groups.is_empty():
		group_timer = maxf(0.0, group_timer - delta)
		if group_timer <= 0.0:
			_release_next_group()
		return

	if live_enemy_count <= 0 or wave_elapsed >= WAVE_TIMEOUT_SECONDS:
		_begin_intermission()


func _process_classic(delta: float) -> void:
	group_timer = maxf(0.0, group_timer - delta)
	if group_timer > 0.0:
		return
	group_timer = CLASSIC_SPAWN_INTERVAL
	group_ready.emit(EnemyType.DEFAULT_TYPE_ID, EnemyType.Formation.SCATTERED, 1, 1.0, 1.0)


## True while the breather before the given wave is a shopping break.
static func shop_opens_before(next_wave: int) -> bool:
	return next_wave > 1 and (next_wave - 1) % SHOP_WAVE_INTERVAL == 0


func _begin_intermission() -> void:
	var next_wave := wave + 1
	intermission_timer = SHOP_INTERMISSION_SECONDS if shop_opens_before(next_wave) else INTERMISSION_SECONDS
	intermission_started.emit(next_wave, intermission_timer)


## Skips the rest of the breather, used when everyone is done shopping.
func skip_intermission() -> void:
	if running and intermission_timer > 0.0:
		intermission_timer = 0.0
		_begin_next_wave()


func _begin_next_wave() -> void:
	wave += 1
	wave_elapsed = 0.0
	group_timer = 0.0
	var plan := theme_for_wave(wave)
	archetype = plan.archetype
	modifier = plan.modifier
	theme_name = plan.name
	debut_type_id = plan.debut
	group_interval = AMBUSH_GROUP_INTERVAL if archetype == Archetype.AMBUSH else GROUP_INTERVAL_SECONDS
	pending_groups = plan_wave(wave, archetype, modifier, debut_type_id)
	wave_started.emit(wave, display_name(), debut_type_id)
	_release_next_group()


func display_name() -> String:
	if modifier == Modifier.NONE:
		return theme_name
	return "%s (%s)" % [theme_name, str(MODIFIER_NAMES[modifier])]


func _release_next_group() -> void:
	if pending_groups.is_empty():
		return
	var group: Dictionary = pending_groups.pop_front()
	group_timer = group_interval
	group_ready.emit(
		str(group.type_id),
		int(group.formation),
		int(group.count),
		float(group.health_multiplier),
		float(group.speed_multiplier)
	)


func health_multiplier_for_wave(target_wave: int) -> float:
	var base := BASE_HEALTH_MULTIPLIER + HEALTH_GROWTH_PER_WAVE * float(maxi(0, target_wave - 1))
	return base * float(DIFFICULTY_HEALTH_MULTIPLIERS.get(GameRuntime.difficulty, 1.0))


func budget_for_wave(target_wave: int) -> float:
	# Roughly double the old headcount at every wave (base 12->24, per-wave growth 2.6->6.0 —
	# more than double, so the curve keeps getting steeper instead of just shifting up by a
	# flat amount) on top of the doubled per-enemy health above, so both axes compound.
	var solo_budget := 24.0 + 6.0 * float(target_wave)
	return solo_budget * (1.0 + 0.85 * float(player_count - 1))


## Returns {name, archetype, modifier, debut} for any wave number.
func theme_for_wave(target_wave: int) -> Dictionary:
	if target_wave <= SCRIPTED_WAVES.size():
		var scripted: Dictionary = SCRIPTED_WAVES[target_wave - 1]
		return {
			"name": str(scripted.name),
			"archetype": scripted.get("archetype", Archetype.STANDARD) as Archetype,
			"modifier": scripted.get("modifier", Modifier.NONE) as Modifier,
			"debut": str(scripted.get("debut", "")),
		}

	var improvised := _improvised_archetype(target_wave)
	var names: Array = IMPROVISED_NAMES[improvised]
	return {
		"name": str(names[target_wave % names.size()]),
		"archetype": improvised,
		"modifier": _improvised_modifier(target_wave),
		"debut": "",
	}


func _improvised_archetype(target_wave: int) -> Archetype:
	if target_wave % BOSS_WAVE_INTERVAL == 0:
		return Archetype.BOSS
	if target_wave % ELITE_WAVE_INTERVAL == 0:
		return Archetype.ELITE
	# STANDARD gets an extra slot so fast/swarm-heavy archetypes (SWARM, AIR_ASSAULT with its
	# drifter/bomber pair) don't dominate the late-game mix on their own.
	var pool: Array[Archetype] = [
		Archetype.STANDARD,
		Archetype.STANDARD,
		Archetype.STANDARD,
		Archetype.SWARM,
		Archetype.AIR_ASSAULT,
		Archetype.SNIPERS,
		Archetype.AMBUSH,
	]
	return pool[randi() % pool.size()]


func _improvised_modifier(target_wave: int) -> Modifier:
	if target_wave % BOSS_WAVE_INTERVAL == 0:
		return Modifier.NONE
	# Roughly every 7th wave (staggered off the 5-wave elite cadence) throws a much bigger
	# crowd than the gradual curve alone would, for an occasional "cornered" spike.
	if target_wave % 7 == 0 and target_wave % ELITE_WAVE_INTERVAL != 0:
		return Modifier.SURGE
	match target_wave % 4:
		0: return Modifier.ARMORED
		2: return Modifier.ENRAGED
		3: return Modifier.FRAGILE_HORDE
		_: return Modifier.NONE


func plan_wave(target_wave: int, wave_archetype: Archetype, wave_modifier: Modifier = Modifier.NONE, debut: String = "") -> Array[Dictionary]:
	var multiplier := health_multiplier_for_wave(target_wave)
	var speed_multiplier := 1.0
	var budget := budget_for_wave(target_wave)
	match wave_modifier:
		Modifier.ENRAGED:
			speed_multiplier = 1.18
		Modifier.ARMORED:
			multiplier *= 1.25
			budget *= 0.85
		Modifier.FRAGILE_HORDE:
			multiplier *= 0.7
			budget *= 1.5
		Modifier.SURGE:
			speed_multiplier = 1.1
			budget *= 1.9

	var available := EnemyType.spawnable_for_wave(target_wave)
	if available.is_empty():
		return []

	var groups: Array[Dictionary] = []
	if not debut.is_empty() and EnemyType.is_valid_id(debut):
		# The debut group arrives first, alone and in small numbers.
		groups.append(_make_group(EnemyType.by_id(debut), EnemyType.Formation.LONE, DEBUT_COUNT, multiplier, speed_multiplier))
		budget = maxf(2.0, budget - float(EnemyType.by_id(debut).cost) * float(DEBUT_COUNT))
		available = _without(available, debut)

	match wave_archetype:
		Archetype.BOSS:
			groups.append_array(_plan_boss(target_wave, budget, multiplier, speed_multiplier, available))
		Archetype.ELITE:
			groups.append_array(_plan_elite(target_wave, budget, multiplier, speed_multiplier, available))
		Archetype.SWARM:
			groups.append_array(_plan_filtered(budget * 1.15, multiplier, speed_multiplier, available, ["swarmling", "splitter", "grunt"], EnemyType.Formation.PACK))
		Archetype.AIR_ASSAULT:
			groups.append_array(_plan_filtered(budget, multiplier, speed_multiplier, available, ["drifter", "bomber"], EnemyType.Formation.RING))
		Archetype.SNIPERS:
			groups.append_array(_plan_filtered(budget, multiplier, speed_multiplier, available, ["spitter", "summoner", "stalker"], EnemyType.Formation.SCATTERED))
		Archetype.AMBUSH:
			groups.append_array(_plan_ambush(budget, multiplier, speed_multiplier, available))
		_:
			groups.append_array(_plan_standard(budget, multiplier, speed_multiplier, available))
	return groups


func _without(available: Array[Dictionary], excluded_id: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for type_data in available:
		if str(type_data.id) != excluded_id:
			filtered.append(type_data)
	return filtered


func _plan_standard(budget: float, multiplier: float, speed_multiplier: float, available: Array[Dictionary]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var guard := 0
	while budget > 0.0 and guard < 32:
		guard += 1
		var type_data := _pick_weighted_type(available)
		var count := randi_range(int(type_data.group_min), int(type_data.group_max))
		var group_cost := float(type_data.cost) * float(count)
		if group_cost > budget and not groups.is_empty():
			break
		budget -= group_cost
		groups.append(_make_group(type_data, int(type_data.formation), count, multiplier, speed_multiplier))
	groups.shuffle()
	return groups


func _plan_filtered(budget: float, multiplier: float, speed_multiplier: float, available: Array[Dictionary], preferred_ids: Array, formation: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for type_data in available:
		if str(type_data.id) in preferred_ids:
			pool.append(type_data)
	if pool.is_empty():
		return _plan_standard(budget, multiplier, speed_multiplier, available)

	var groups: Array[Dictionary] = []
	var guard := 0
	while budget > 0.0 and guard < 32:
		guard += 1
		var type_data := _pick_weighted_type(pool)
		var count := randi_range(int(type_data.group_min), int(type_data.group_max))
		var group_cost := float(type_data.cost) * float(count)
		if group_cost > budget and not groups.is_empty():
			break
		budget -= group_cost
		groups.append(_make_group(type_data, formation, count, multiplier, speed_multiplier))
	return groups


func _plan_elite(target_wave: int, budget: float, multiplier: float, speed_multiplier: float, available: Array[Dictionary]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for elite_id in ["sentinel", "brute"]:
		var elite := EnemyType.by_id(elite_id)
		if int(elite.unlock_wave) > target_wave:
			continue
		var count := 2 + int(target_wave / ELITE_WAVE_INTERVAL)
		groups.append(_make_group(elite, EnemyType.Formation.RING, count, multiplier, speed_multiplier))
		budget -= float(elite.cost) * float(count)
	groups.append_array(_plan_standard(maxf(0.0, budget), multiplier, speed_multiplier, available))
	return groups


func _plan_boss(target_wave: int, budget: float, multiplier: float, speed_multiplier: float, available: Array[Dictionary]) -> Array[Dictionary]:
	var boss := EnemyType.by_id(EnemyType.boss_for_wave(target_wave))
	var boss_multiplier := multiplier * (1.0 + 0.25 * float(player_count - 1))
	var groups: Array[Dictionary] = [_make_group(boss, EnemyType.Formation.LONE, 1, boss_multiplier, 1.0)]
	groups.append_array(_plan_standard(budget * 0.5, multiplier, speed_multiplier, available))
	return groups


func _plan_ambush(budget: float, multiplier: float, speed_multiplier: float, available: Array[Dictionary]) -> Array[Dictionary]:
	var groups := _plan_standard(budget, multiplier, speed_multiplier, available)
	for index in groups.size():
		groups[index].formation = EnemyType.Formation.RING
	return groups


func _make_group(type_data: Dictionary, formation: int, count: int, multiplier: float, speed_multiplier: float) -> Dictionary:
	return {
		"type_id": str(type_data.id),
		"formation": formation,
		"count": maxi(1, count),
		"health_multiplier": multiplier,
		"speed_multiplier": speed_multiplier,
	}


func _pick_weighted_type(available: Array[Dictionary]) -> Dictionary:
	var total_weight := 0.0
	for type_data in available:
		total_weight += float(type_data.weight)
	var roll := randf() * total_weight
	for type_data in available:
		roll -= float(type_data.weight)
		if roll <= 0.0:
			return type_data
	return available[available.size() - 1]

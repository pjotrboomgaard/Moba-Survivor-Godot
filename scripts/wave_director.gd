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

## Waves 1-88 are hand-written. 1-20 introduce every roster type on grass; later
## 20-wave blocks are volcano / ice / factory / docks themed names. Debuts stay on
## existing type ids only. Beyond 88 the director improvises.
const SCRIPTED_WAVES: Array[Dictionary] = [
	{"name": "First Contact", "archetype": Archetype.STANDARD},
	{"name": "Growing Numbers", "archetype": Archetype.STANDARD, "debut": "swarmling"},
	{"name": "The Swarm", "archetype": Archetype.SWARM},
	{"name": "Acid Rain", "archetype": Archetype.STANDARD, "debut": "spitter"},
	{"name": "The Ravager", "archetype": Archetype.BOSS},
	{"name": "Wings", "archetype": Archetype.AIR_ASSAULT, "debut": "drifter"},
	{"name": "Air Assault", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.SURGE},
	{"name": "The Wall", "archetype": Archetype.STANDARD, "debut": "brute"},
	{"name": "Shadows", "archetype": Archetype.STANDARD, "debut": "stalker", "modifier": Modifier.ENRAGED},
	{"name": "The Stormcaller", "archetype": Archetype.BOSS},
	{"name": "Bombardment", "archetype": Archetype.STANDARD, "debut": "bomber"},
	{"name": "Mending Chant", "archetype": Archetype.STANDARD, "debut": "hexer"},
	{"name": "Guard Post", "archetype": Archetype.ELITE, "debut": "sentinel"},
	{"name": "Burrows", "archetype": Archetype.AMBUSH, "debut": "lurker"},
	{"name": "The Vanguard", "archetype": Archetype.BOSS},
	{"name": "Pod Burst", "archetype": Archetype.SWARM, "debut": "splitter", "modifier": Modifier.FRAGILE_HORDE},
	{"name": "Stampede", "archetype": Archetype.STANDARD, "debut": "charger"},
	{"name": "Overgrowth", "archetype": Archetype.SWARM},
	{"name": "Dark Ritual", "archetype": Archetype.SNIPERS, "debut": "summoner"},
	{"name": "The Warhos", "archetype": Archetype.BOSS},
	{"name": "Kindling", "archetype": Archetype.STANDARD},
	{"name": "Cinder Ring", "archetype": Archetype.SWARM, "modifier": Modifier.ENRAGED},
	{"name": "Scorched Wings", "archetype": Archetype.AIR_ASSAULT},
	{"name": "Sulfur Pits", "archetype": Archetype.AMBUSH},
	{"name": "The Pyrelord", "archetype": Archetype.BOSS},
	{"name": "Flashover", "archetype": Archetype.STANDARD},
	{"name": "Coal Walk", "archetype": Archetype.SWARM},
	{"name": "Flamewall", "archetype": Archetype.SNIPERS, "modifier": Modifier.ARMORED},
	{"name": "Charred Ground", "archetype": Archetype.STANDARD},
	{"name": "The Furnace", "archetype": Archetype.BOSS},
	{"name": "Scorch", "archetype": Archetype.SWARM, "modifier": Modifier.ENRAGED},
	{"name": "Ashen Ranks", "archetype": Archetype.ELITE},
	{"name": "Lava Chorus", "archetype": Archetype.SNIPERS},
	{"name": "Firebrands", "archetype": Archetype.SWARM},
	{"name": "The Salamander", "archetype": Archetype.BOSS},
	{"name": "Smoke Screen", "archetype": Archetype.AMBUSH},
	{"name": "Ember Storm", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.SURGE},
	{"name": "Molten March", "archetype": Archetype.STANDARD},
	{"name": "Blast Furnace", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
	{"name": "The Volcanic", "archetype": Archetype.BOSS},
	{"name": "Pack Ice", "archetype": Archetype.STANDARD},
	{"name": "Whiteout", "archetype": Archetype.SNIPERS, "modifier": Modifier.ENRAGED},
	{"name": "Floes", "archetype": Archetype.AIR_ASSAULT},
	{"name": "Crevasse", "archetype": Archetype.AMBUSH},
	{"name": "The Frostreaver", "archetype": Archetype.BOSS},
	{"name": "Snowblind", "archetype": Archetype.SWARM, "modifier": Modifier.FRAGILE_HORDE},
	{"name": "Permafrost", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
	{"name": "Blizzard", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.SURGE},
	{"name": "Icebreakers", "archetype": Archetype.STANDARD},
	{"name": "The Deep Freeze", "archetype": Archetype.BOSS},
	{"name": "Drift", "archetype": Archetype.SWARM},
	{"name": "Hoarfrost", "archetype": Archetype.ELITE},
	{"name": "Black Ice", "archetype": Archetype.AMBUSH},
	{"name": "Glacier Teeth", "archetype": Archetype.SNIPERS},
	{"name": "The Avalanche", "archetype": Archetype.BOSS},
	{"name": "Cold Snap", "archetype": Archetype.ELITE, "modifier": Modifier.ENRAGED},
	{"name": "Frostbite", "archetype": Archetype.STANDARD},
	{"name": "Frozen Silence", "archetype": Archetype.AMBUSH},
	{"name": "Shatterline", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
	{"name": "The Glacier", "archetype": Archetype.BOSS},
	{"name": "Assembly Line II", "archetype": Archetype.STANDARD},
	{"name": "Iron Line", "archetype": Archetype.ELITE},
	{"name": "Kill Floor", "archetype": Archetype.SNIPERS},
	{"name": "Shift Change", "archetype": Archetype.AMBUSH},
	{"name": "The Foreman", "archetype": Archetype.BOSS},
	{"name": "Overhead Crane", "archetype": Archetype.AIR_ASSAULT},
	{"name": "Press Gang", "archetype": Archetype.SWARM},
	{"name": "Lockdown", "archetype": Archetype.STANDARD, "modifier": Modifier.ENRAGED},
	{"name": "Scrap Tide", "archetype": Archetype.SWARM, "modifier": Modifier.SURGE},
	{"name": "The Machine", "archetype": Archetype.BOSS},
	{"name": "Soldering", "archetype": Archetype.SNIPERS},
	{"name": "Conveyor", "archetype": Archetype.STANDARD},
	{"name": "Welding Arc", "archetype": Archetype.STANDARD, "modifier": Modifier.ENRAGED},
	{"name": "Debris", "archetype": Archetype.SWARM, "modifier": Modifier.FRAGILE_HORDE},
	{"name": "The Smelter", "archetype": Archetype.BOSS},
	{"name": "Overdrive", "archetype": Archetype.STANDARD, "modifier": Modifier.SURGE},
	{"name": "Deadlocks", "archetype": Archetype.AMBUSH},
	{"name": "Riveting", "archetype": Archetype.ELITE},
	{"name": "Full Production", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
	{"name": "The Assembly", "archetype": Archetype.BOSS},
	{"name": "Boardwalk", "archetype": Archetype.STANDARD},
	{"name": "High Tide", "archetype": Archetype.AIR_ASSAULT},
	{"name": "Piers", "archetype": Archetype.AMBUSH},
	{"name": "Gulls", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.ENRAGED},
	{"name": "The Warhos", "archetype": Archetype.BOSS},
	{"name": "Rip Current", "archetype": Archetype.SWARM},
	{"name": "Longshore", "archetype": Archetype.SNIPERS},
	{"name": "Storm Wall", "archetype": Archetype.STANDARD, "modifier": Modifier.SURGE},
]

## When the run is locked to a biome (hero world / F1), cycle these 20-wave
## identity blocks instead of the grass intro table. Wave 1 stays First Contact.
const BIOME_THEMES := {
	1: [
		{"name": "Kindling", "archetype": Archetype.STANDARD},
		{"name": "Cinder Ring", "archetype": Archetype.SWARM, "modifier": Modifier.ENRAGED},
		{"name": "Scorched Wings", "archetype": Archetype.AIR_ASSAULT},
		{"name": "Sulfur Pits", "archetype": Archetype.AMBUSH},
		{"name": "The Pyrelord", "archetype": Archetype.BOSS},
		{"name": "Flashover", "archetype": Archetype.STANDARD},
		{"name": "Coal Walk", "archetype": Archetype.SWARM},
		{"name": "Flamewall", "archetype": Archetype.SNIPERS, "modifier": Modifier.ARMORED},
		{"name": "Charred Ground", "archetype": Archetype.STANDARD},
		{"name": "The Furnace", "archetype": Archetype.BOSS},
		{"name": "Scorch", "archetype": Archetype.SWARM, "modifier": Modifier.ENRAGED},
		{"name": "Ashen Ranks", "archetype": Archetype.ELITE},
		{"name": "Lava Chorus", "archetype": Archetype.SNIPERS},
		{"name": "Firebrands", "archetype": Archetype.SWARM},
		{"name": "The Salamander", "archetype": Archetype.BOSS},
		{"name": "Smoke Screen", "archetype": Archetype.AMBUSH},
		{"name": "Ember Storm", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.SURGE},
		{"name": "Molten March", "archetype": Archetype.STANDARD},
		{"name": "Blast Furnace", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
		{"name": "The Volcanic", "archetype": Archetype.BOSS},
	],
	2: [
		{"name": "Pack Ice", "archetype": Archetype.STANDARD},
		{"name": "Whiteout", "archetype": Archetype.SNIPERS, "modifier": Modifier.ENRAGED},
		{"name": "Floes", "archetype": Archetype.AIR_ASSAULT},
		{"name": "Crevasse", "archetype": Archetype.AMBUSH},
		{"name": "The Frostreaver", "archetype": Archetype.BOSS},
		{"name": "Snowblind", "archetype": Archetype.SWARM, "modifier": Modifier.FRAGILE_HORDE},
		{"name": "Permafrost", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
		{"name": "Blizzard", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.SURGE},
		{"name": "Icebreakers", "archetype": Archetype.STANDARD},
		{"name": "The Deep Freeze", "archetype": Archetype.BOSS},
		{"name": "Drift", "archetype": Archetype.SWARM},
		{"name": "Hoarfrost", "archetype": Archetype.ELITE},
		{"name": "Black Ice", "archetype": Archetype.AMBUSH},
		{"name": "Glacier Teeth", "archetype": Archetype.SNIPERS},
		{"name": "The Avalanche", "archetype": Archetype.BOSS},
		{"name": "Cold Snap", "archetype": Archetype.STANDARD, "modifier": Modifier.ENRAGED},
		{"name": "Frostbite", "archetype": Archetype.STANDARD},
		{"name": "Frozen Silence", "archetype": Archetype.AMBUSH},
		{"name": "Shatterline", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
		{"name": "The Glacier", "archetype": Archetype.BOSS},
	],
	3: [
		{"name": "Assembly Line II", "archetype": Archetype.STANDARD},
		{"name": "Iron Line", "archetype": Archetype.ELITE},
		{"name": "Kill Floor", "archetype": Archetype.SNIPERS},
		{"name": "Shift Change", "archetype": Archetype.AMBUSH},
		{"name": "The Foreman", "archetype": Archetype.BOSS},
		{"name": "Overhead Crane", "archetype": Archetype.AIR_ASSAULT},
		{"name": "Press Gang", "archetype": Archetype.SWARM},
		{"name": "Lockdown", "archetype": Archetype.STANDARD, "modifier": Modifier.ENRAGED},
		{"name": "Scrap Tide", "archetype": Archetype.SWARM, "modifier": Modifier.SURGE},
		{"name": "The Machine", "archetype": Archetype.BOSS},
		{"name": "Soldering", "archetype": Archetype.SNIPERS},
		{"name": "Conveyor", "archetype": Archetype.STANDARD},
		{"name": "Welding Arc", "archetype": Archetype.STANDARD, "modifier": Modifier.ENRAGED},
		{"name": "Debris", "archetype": Archetype.SWARM, "modifier": Modifier.FRAGILE_HORDE},
		{"name": "The Smelter", "archetype": Archetype.BOSS},
		{"name": "Overdrive", "archetype": Archetype.STANDARD, "modifier": Modifier.SURGE},
		{"name": "Deadlocks", "archetype": Archetype.AMBUSH},
		{"name": "Riveting", "archetype": Archetype.ELITE},
		{"name": "Full Production", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
		{"name": "The Assembly", "archetype": Archetype.BOSS},
	],
	4: [
		{"name": "Boardwalk", "archetype": Archetype.STANDARD},
		{"name": "High Tide", "archetype": Archetype.AIR_ASSAULT},
		{"name": "Piers", "archetype": Archetype.AMBUSH},
		{"name": "Gulls", "archetype": Archetype.AIR_ASSAULT, "modifier": Modifier.ENRAGED},
		{"name": "The Warhos", "archetype": Archetype.BOSS},
		{"name": "Rip Current", "archetype": Archetype.SWARM},
		{"name": "Longshore", "archetype": Archetype.SNIPERS},
		{"name": "Storm Wall", "archetype": Archetype.STANDARD, "modifier": Modifier.SURGE},
		{"name": "Last Call", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
		{"name": "The Maelstrom", "archetype": Archetype.BOSS},
		{"name": "Low Tide", "archetype": Archetype.SWARM, "modifier": Modifier.FRAGILE_HORDE},
		{"name": "Harbor Watch", "archetype": Archetype.ELITE},
		{"name": "Undertow", "archetype": Archetype.AMBUSH},
		{"name": "Squall", "archetype": Archetype.SNIPERS},
		{"name": "The Admiral", "archetype": Archetype.BOSS},
		{"name": "Spray", "archetype": Archetype.STANDARD, "modifier": Modifier.ENRAGED},
		{"name": "Capstan", "archetype": Archetype.STANDARD},
		{"name": "Mooring", "archetype": Archetype.AMBUSH},
		{"name": "Breakwater", "archetype": Archetype.STANDARD, "modifier": Modifier.ARMORED},
		{"name": "The Tide", "archetype": Archetype.BOSS},
	],
}

const IMPROVISED_NAMES := {
	Archetype.STANDARD: ["Advance", "Pressure", "Relentless", "Grinding Halt"],
	Archetype.SWARM: ["The Swarm", "Infestation", "Countless", "Tide of Teeth"],
	Archetype.SNIPERS: ["Crossfire", "Long Range", "Kill Zone", "Rain of Acid"],
	Archetype.ELITE: ["Elite Guard", "Heavy Metal", "The Vanguard", "Ironclad"],
	Archetype.AIR_ASSAULT: ["Air Assault", "Skyfall", "Wings of Ruin", "Overhead"],
	Archetype.AMBUSH: ["Ambush", "Surrounded", "No Way Out", "Closing In"],
	Archetype.BOSS: ["Boss", "The Reckoning", "Apex"],
}

const INTERMISSION_SECONDS := 10.0
const SHOP_INTERMISSION_SECONDS := 30.0
## The shop opens after every other boss (waves 10, 20, 30, ...).
const SHOP_WAVE_INTERVAL := 10
const GROUP_INTERVAL_SECONDS := 1.7
const AMBUSH_GROUP_INTERVAL := 0.2
## Ambush waves normally dump every group in ~0.2s cadence, so the whole wave's enemies
## converge on the player in a few seconds instead of the ~25-35s a standard wave spreads
## out over. Slow the first stretch of releases so a kiting player gets a real beat to
## react before the fast cadence resumes — still much more sudden than STANDARD, just not
## "no time to respond" sudden. A live solo run at 70% HP still lost 52% of max HP to the
## opening burst under the first-pass ramp (2.5s / 0.9s), so both the ramp window and the
## per-release pace were widened further here.
const AMBUSH_RAMP_SECONDS := 4.0
const AMBUSH_RAMP_INTERVAL := 1.1
## Ambush plans a smaller total budget than a standard wave (80%) so its "surrounded"
## headcount spike doesn't also add up to a standard wave's full total damage once it's
## all dumped on a fast cadence — same identity (RING formation, faster releases), fewer
## bodies doing it.
const AMBUSH_BUDGET_SCALE := 0.8
## The very first ambush group releases instantly at wave start with no ramp at all (see
## _begin_next_wave -> _release_next_group), so it gets its own extra shrink on top of the
## budget trim above — the opening jolt shouldn't also be the wave's biggest single group.
const AMBUSH_FIRST_GROUP_SCALE := 0.6
const WAVE_TIMEOUT_SECONDS := 120.0
const ELITE_WAVE_INTERVAL := 8
const BOSS_WAVE_INTERVAL := 5
## Enemies start noticeably tankier now (2x the old wave-1 health) and keep climbing faster
## than before, so the run keeps escalating rather than plateauing once players out-level it.
const BASE_HEALTH_MULTIPLIER := 2.0
const HEALTH_GROWTH_PER_WAVE := 0.14
## Offline solo (no CPU allies) ramps from wave 2 so keg/turret/landmarks stay clutch
## without making First Contact unfair. Kept modest so wave 5 budget stays under 60.
## SOLO_HEALTH_PRESSURE was 1.18: on top of BASE_HEALTH_MULTIPLIER + HEALTH_GROWTH_PER_WAVE
## already climbing every wave, that flat 18% tax compounds with budget_for_wave AND
## solo_contact_multiplier (both also wave-indexed) into a much steeper-than-linear curve by
## wave 15-20 — enemies survive longer *and* hit harder *and* there are more of them, all
## three axes growing at once. Eased to 1.12 so enemies are still tankier solo than in co-op,
## just without stacking a third compounding multiplier as hard on the late-wave spike.
const SOLO_HEALTH_PRESSURE := 1.12
const SOLO_BUDGET_PRESSURE := 1.08
const SOLO_DAMAGE_PRESSURE := 1.28
const SOLO_PRESSURE_FROM_WAVE := 2

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
## True once this wave has actually had living enemies. Prevents skip_intermission from
## clearing a boss wave on the same frame the first group is still spawning.
var _wave_engaged := false
## Keep-engaged packs: extra packs when the field is empty or the player is healthy —
## any mode, see _should_reinforce().
var pressure_hp := 1.0
var nearby_enemy_count := 0
var _reinforcements := 0
var _pressure_cooldown := 0.0
var _close_spawn := false


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
	if count > 0:
		_wave_engaged = true


func report_pressure(hp_frac: float, nearby: int) -> void:
	pressure_hp = clampf(hp_frac, 0.0, 1.0)
	nearby_enemy_count = maxi(0, nearby)


func take_close_spawn() -> bool:
	var close := _close_spawn
	_close_spawn = false
	return close


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
	_pressure_cooldown = maxf(0.0, _pressure_cooldown - delta)

	if not pending_groups.is_empty():
		group_timer = maxf(0.0, group_timer - delta)
		if group_timer <= 0.0:
			_release_next_group()
		return

	if _should_reinforce():
		_emit_pressure_pack()
		return

	# First spawn is often a frame behind skip_intermission; don't treat an empty
	# field as "wave cleared" until we've seen living enemies. Give bosses extra
	# time so the announce/flash hitch cannot skip The Ravager.
	if not _wave_engaged:
		if wave_elapsed < (4.5 if archetype == Archetype.BOSS else 2.5):
			return
		# Spawn never registered — fail open so a broken spawn cannot hang the run.

	var timed_out := wave_elapsed >= WAVE_TIMEOUT_SECONDS and archetype != Archetype.BOSS
	if live_enemy_count <= 0 or timed_out:
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


## The enemy type introduced at the given wave, or "" when the wave debuts nothing.
static func debut_index(target_wave: int) -> String:
	if target_wave >= 1 and target_wave <= SCRIPTED_WAVES.size():
		return str(SCRIPTED_WAVES[target_wave - 1].get("debut", ""))
	return ""


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
	_wave_engaged = false
	_reinforcements = 0
	_pressure_cooldown = 0.0
	_close_spawn = false
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
	group_timer = _next_group_interval()
	group_ready.emit(
		str(group.type_id),
		int(group.formation),
		int(group.count),
		float(group.health_multiplier),
		float(group.speed_multiplier)
	)


## Ambush stays on its fast cadence overall, but the first AMBUSH_RAMP_SECONDS of a wave
## release on the slower ramp interval so the opening burst is reactable instead of the
## whole wave's groups landing within a couple seconds of each other.
func _next_group_interval() -> float:
	if archetype == Archetype.AMBUSH and wave_elapsed < AMBUSH_RAMP_SECONDS:
		return AMBUSH_RAMP_INTERVAL
	return group_interval


func health_multiplier_for_wave(target_wave: int) -> float:
	var base := BASE_HEALTH_MULTIPLIER + HEALTH_GROWTH_PER_WAVE * float(maxi(0, target_wave - 1))
	if _solo_pressure_active(target_wave):
		base *= SOLO_HEALTH_PRESSURE
	return base * float(DIFFICULTY_HEALTH_MULTIPLIERS.get(GameRuntime.difficulty, 1.0))


func budget_for_wave(target_wave: int) -> float:
	# Roughly double the old headcount at every wave (base 12->24, per-wave growth 2.6->6.0 —
	# more than double, so the curve keeps getting steeper instead of just shifting up by a
	# flat amount) on top of the doubled per-enemy health above, so both axes compound.
	var solo_budget := 28.0 + 9.5 * float(target_wave)
	if _solo_pressure_active(target_wave):
		solo_budget *= SOLO_BUDGET_PRESSURE
	return solo_budget * (1.0 + 0.85 * float(player_count - 1))


func solo_contact_multiplier(target_wave: int) -> float:
	if classic_mode or GameRuntime.fill_cpu_allies or player_count != 1:
		return 1.0
	# This per-hit multiplier stacks with SOLO_HEALTH_PRESSURE and SOLO_BUDGET_PRESSURE (more,
	# tankier enemies) AND with every hero's own damage_taken_multiplier — for the roster's most
	# fragile hero that compounding meant a wave-20 hit already worth ~1.9x baseline. Ramp
	# coefficient halved (0.016 -> 0.008) so the wave-20 ceiling is closer to +36% instead of
	# +54% on top of the flat SOLO_DAMAGE_PRESSURE tax, leaving the headcount/HP axes above to
	# carry more of the late-wave difficulty climb instead of raw per-hit damage.
	var ramp := 1.0 + 0.012 * float(maxi(0, target_wave - 1))
	return SOLO_DAMAGE_PRESSURE * ramp


## Always-on contact climb so co-op is not a free ride; solo stacks SOLO_DAMAGE_PRESSURE on top.
func contact_multiplier_for_wave(target_wave: int) -> float:
	var ramp := 1.0 + 0.014 * float(maxi(0, target_wave - 1))
	if _solo_pressure_active(target_wave):
		return solo_contact_multiplier(target_wave)
	return ramp


## True for offline PLAY (not CO-OP CPU fill) from wave 2 onward.
func _solo_pressure_active(target_wave: int) -> bool:
	if classic_mode or GameRuntime.fill_cpu_allies:
		return false
	if player_count != 1:
		return false
	return target_wave >= SOLO_PRESSURE_FROM_WAVE


func _desired_live() -> int:
	var floor_n := 12 + int(float(wave) * 2.0)
	if pressure_hp >= 0.80:
		floor_n += 12 + int(float(wave) * 1.1)
	elif pressure_hp >= 0.55:
		floor_n += 7
	elif pressure_hp < 0.28:
		floor_n = maxi(6, floor_n - 4)
	# Cap climbs from wave 1 so every stage stays busy, not just the late run.
	var live_cap := mini(55 + int(float(wave) * 4.0), 190)
	return clampi(floor_n, 6, live_cap)


## Was solo-only (gated behind _solo_pressure_active) so co-op waves could go quiet for a
## stretch once the planned groups were cleared — no minions on screen isn't a breather,
## it's dead air. Generalized to any mode: it only ever fires when live_enemy_count is
## already below _desired_live(), so co-op's bigger planned budget naturally keeps this
## from firing except during an actual lull. Thresholds loosened + cap raised well past the
## old ~3-per-wave ceiling so a healthy player keeps getting fed a busier field all wave,
## not just an occasional top-up right after the opening burst clears.
func _should_reinforce() -> bool:
	if wave < 1:
		return false
	if classic_mode:
		return false
	if archetype == Archetype.BOSS or archetype == Archetype.AMBUSH:
		return false
	if not _wave_engaged:
		return false
	if wave_elapsed < 1.0 or wave_elapsed > 90.0:
		return false
	if _pressure_cooldown > 0.0:
		return false
	if _reinforcements >= 12 + int(float(wave) / 1.0):
		return false
	if pressure_hp < 0.32:
		return false
	return live_enemy_count < _desired_live()


## "Cruising" (pressure_hp >= 0.85, i.e. not just recovering from a scare) gets a tougher
## minion mixed into the trash pack on top of the headcount bump _desired_live() already
## gives it — same "more when doing well" idea, but with actual teeth instead of just more
## bodies, and it keeps scaling as the run's wave-gated roster unlocks tougher trash.
## Pack size + cadence roughly doubled from the first pass: that pass still read as too
## sparse in a live playtest, and pressure_hp < 0.5 already backs this whole system off
## the moment the player is actually struggling, so there's real headroom here.
func _emit_pressure_pack() -> void:
	_reinforcements += 1
	_pressure_cooldown = 0.85
	_close_spawn = true
	var cruising := pressure_hp >= 0.80
	var n := clampi(6 + int(wave / 2) + (8 if cruising else 3), 6, 18)
	var type_id := "swarmling"
	match GameRuntime.biome_id:
		2:
			type_id = "lurker" if randf() < 0.35 else "swarmling"
		4:
			type_id = "drifter" if randf() < 0.3 else "swarmling"
		_:
			type_id = "swarmling"
	group_timer = 1.15
	group_ready.emit(
		type_id,
		EnemyType.Formation.PACK,
		n,
		health_multiplier_for_wave(wave),
		1.0
	)
	if cruising and wave >= 4:
		var tougher_id := _tougher_reinforcement_type(wave)
		if not tougher_id.is_empty():
			group_ready.emit(
				tougher_id,
				EnemyType.Formation.SCATTERED,
				2 + int(wave / 6),
				health_multiplier_for_wave(wave),
				1.0
			)


## Highest-cost non-elite, non-boss type unlocked by this wave — a real step up from
## swarmling/grunt without duplicating the dedicated Elite-wave roster (brute/sentinel).
func _tougher_reinforcement_type(target_wave: int) -> String:
	var best_id := ""
	var best_cost := 0.0
	for type_data in EnemyType.spawnable_for_wave(target_wave):
		var id := str(type_data.id)
		if id in ["grunt", "swarmling", "brute", "sentinel"] or bool(type_data.get("is_boss", false)):
			continue
		var cost := float(type_data.cost)
		if cost > best_cost:
			best_cost = cost
			best_id = id
	return best_id


## Returns {name, archetype, modifier, debut} for any wave number.
func theme_for_wave(target_wave: int) -> Dictionary:
	if GameRuntime.uses_biomes() and GameRuntime.biome_id > 0 and BIOME_THEMES.has(GameRuntime.biome_id):
		if target_wave <= 1:
			return {
				"name": "First Contact",
				"archetype": Archetype.STANDARD,
				"modifier": Modifier.NONE,
				"debut": "",
			}
		var block: Array = BIOME_THEMES[GameRuntime.biome_id]
		if not block.is_empty():
			var themed: Dictionary = block[(target_wave - 1) % block.size()]
			return {
				"name": str(themed.name),
				"archetype": themed.get("archetype", Archetype.STANDARD) as Archetype,
				"modifier": themed.get("modifier", Modifier.NONE) as Modifier,
				"debut": EnemyType.fit_to_biome(str(themed.get("debut", ""))),
			}

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
	var biome := GameRuntime.biome_for_wave(target_wave)
	var pool: Array[Archetype] = [
		Archetype.STANDARD,
		Archetype.STANDARD,
		Archetype.SWARM,
		Archetype.AIR_ASSAULT,
		Archetype.SNIPERS,
		Archetype.AMBUSH,
	]
	match biome:
		1:
			pool = [Archetype.STANDARD, Archetype.AIR_ASSAULT, Archetype.SWARM, Archetype.STANDARD]
		2:
			pool = [Archetype.SNIPERS, Archetype.AIR_ASSAULT, Archetype.AMBUSH, Archetype.STANDARD]
		3:
			pool = [Archetype.STANDARD, Archetype.SNIPERS, Archetype.AMBUSH, Archetype.STANDARD]
		4:
			pool = [Archetype.AIR_ASSAULT, Archetype.AIR_ASSAULT, Archetype.AMBUSH, Archetype.STANDARD]
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
	var fitted_debut := EnemyType.fit_to_biome(debut) if not debut.is_empty() else ""
	if not fitted_debut.is_empty() and EnemyType.is_valid_id(fitted_debut):
		var debut_data := EnemyType.by_id(fitted_debut)
		if int(debut_data.unlock_wave) <= target_wave:
			# The debut group arrives first, alone and in small numbers.
			groups.append(_make_group(debut_data, EnemyType.Formation.LONE, DEBUT_COUNT, multiplier, speed_multiplier))
			budget = maxf(2.0, budget - float(debut_data.cost) * float(DEBUT_COUNT))
			available = _without(available, fitted_debut)

	match wave_archetype:
		Archetype.BOSS:
			groups.append_array(_plan_boss(target_wave, budget, multiplier, speed_multiplier, available))
		Archetype.ELITE:
			groups.append_array(_plan_elite(target_wave, budget, multiplier, speed_multiplier, available))
		Archetype.SWARM:
			var swarm_budget := budget * 1.15
			var swarm_form := EnemyType.Formation.PACK
			if player_count == 1 and not GameRuntime.fill_cpu_allies:
				swarm_budget = budget * 0.95
				swarm_form = EnemyType.Formation.SCATTERED
			groups.append_array(_plan_filtered(swarm_budget, multiplier, speed_multiplier, available, ["swarmling", "splitter", "grunt"], swarm_form))
		Archetype.AIR_ASSAULT:
			var air_form := EnemyType.Formation.RING
			if player_count == 1 and not GameRuntime.fill_cpu_allies:
				air_form = EnemyType.Formation.SCATTERED
			groups.append_array(_plan_filtered(budget, multiplier, speed_multiplier, available, _air_ids(), air_form))
		Archetype.SNIPERS:
			groups.append_array(_plan_filtered(budget, multiplier, speed_multiplier, available, _sniper_ids(), EnemyType.Formation.SCATTERED))
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
	var used: Dictionary = {}
	while budget > 0.0 and guard < 32:
		guard += 1
		var pool := available
		if used.size() + 1 < available.size() and used.size() > 0:
			var fresh: Array[Dictionary] = []
			for type_data in available:
				if not used.has(str(type_data.id)):
					fresh.append(type_data)
			if not fresh.is_empty():
				pool = fresh
		var type_data := _pick_weighted_type(pool)
		used[str(type_data.id)] = true
		var extra := int(float(wave) / 7.0)
		var count := randi_range(int(type_data.group_min), int(type_data.group_max)) + extra
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
	# Solo play gets a softer first elite encounter on three axes: a full RING fully encircles
	# the player with no escape lane (fine with allies to peel, brutal alone), the flat "+2"
	# base count was tuned around co-op headcount, and dumping the ENTIRE leftover budget into
	# a full-density _plan_standard() right behind the elites means the wave's newest, fastest
	# trash (e.g. wave 9's freshly-unlocked stalker) piles on before the elites are even dealt
	# with. None of this is needed with allies around to split aggro.
	var solo := player_count == 1 and not GameRuntime.fill_cpu_allies
	var elite_formation := EnemyType.Formation.SCATTERED if solo else EnemyType.Formation.RING
	for elite_id in ["sentinel", "brute"]:
		if not _id_in_available(elite_id, available):
			continue
		var elite := EnemyType.by_id(elite_id)
		if int(elite.unlock_wave) > target_wave:
			continue
		var count := 2 + int(target_wave / ELITE_WAVE_INTERVAL)
		if solo:
			count = maxi(1, count - 1)
		groups.append(_make_group(elite, elite_formation, count, multiplier, speed_multiplier))
		budget -= float(elite.cost) * float(count)
	var standard_budget := maxf(0.0, budget)
	if solo:
		# A live solo run still died to a wave-8 elite pack from steady sustained contact
		# damage (10 -> 17 enemies on screen, full HP to dead in ~10s), not a single spike —
		# the elites plus a 0.6x trash tail was still too much all dumped at once. Trimmed
		# further; _should_reinforce()'s now-generalized keep-engaged packs backfill any
		# resulting lull once the elites are actually dealt with, so this isn't a net loss
		# of things to fight, just spread out instead of front-loaded.
		standard_budget *= 0.4
	groups.append_array(_plan_standard(standard_budget, multiplier, speed_multiplier, available))
	return groups


func _id_in_available(type_id: String, available: Array[Dictionary]) -> bool:
	for type_data in available:
		if str(type_data.id) == type_id:
			return true
	return false


func _air_ids() -> Array:
	match _active_biome_id():
		1:
			return ["bomber"]
		4:
			return ["drifter", "bomber"]
		_:
			return ["drifter", "bomber"]


func _sniper_ids() -> Array:
	match _active_biome_id():
		1:
			return ["spitter", "hexer"]
		2:
			return ["spitter", "summoner", "stalker"]
		3:
			return ["spitter", "summoner"]
		4:
			return ["spitter", "stalker"]
		_:
			return ["spitter", "summoner", "stalker"]


func _active_biome_id() -> int:
	if GameRuntime.uses_biomes():
		return GameRuntime.biome_id
	return 0


func _plan_boss(target_wave: int, _budget: float, multiplier: float, _speed_multiplier: float, _available: Array[Dictionary]) -> Array[Dictionary]:
	var boss := EnemyType.by_id(EnemyType.boss_for_wave(target_wave))
	var boss_multiplier := multiplier * (1.0 + 0.35 * float(player_count - 1))
	# Always a single boss — never a pack of four.
	return [_make_group(boss, EnemyType.Formation.LONE, 1, boss_multiplier, 1.0)]


func _plan_ambush(budget: float, multiplier: float, speed_multiplier: float, available: Array[Dictionary]) -> Array[Dictionary]:
	var groups := _plan_standard(budget * AMBUSH_BUDGET_SCALE, multiplier, speed_multiplier, available)
	for index in groups.size():
		groups[index].formation = EnemyType.Formation.RING
	if not groups.is_empty():
		# Soften the instant, un-ramped opening jolt specifically (see AMBUSH_FIRST_GROUP_SCALE).
		var first_count := int(groups[0].count)
		groups[0].count = maxi(1, int(round(float(first_count) * AMBUSH_FIRST_GROUP_SCALE)))
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

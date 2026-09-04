class_name EnemyType
extends RefCounted

enum Behaviour {
	MELEE,
	RANGED,
	SUPPORT,
	CHARGER,
}

enum Formation {
	SCATTERED,
	PACK,
	LONE,
	RING,
}

const DEFAULT_TYPE_ID := "grunt"

const BASE_DEFAULTS := {
	"behaviour": Behaviour.MELEE,
	"radius": 17.0,
	"contact_damage": 0.0,
	"attack_interval": 1.0,
	"attack_distance": 40.0,
	"taunt_immune": false,
	"flying": false,
	"is_boss": false,
	"preferred_distance": 0.0,
	"projectile_damage": 0.0,
	"projectile_speed": 0.0,
	"projectile_count": 1,
	"projectile_sprite": "spit",
	"aura_radius": 0.0,
	"aura_heal_per_second": 0.0,
	"explode_damage": 0.0,
	"explode_radius": 0.0,
	"death_spawn_id": "",
	"death_spawn_count": 0,
	"summon_id": "",
	"summon_count": 0,
	"summon_interval": 0.0,
	"charge_speed": 0.0,
	"charge_windup": 0.0,
	"charge_duration": 0.0,
	"dash_interval": 0.0,
	"stealth_alpha": 1.0,
	"separation_weight": 1.0,
	"gold_value": 2,
	"resistances": {},
	## World-signature trash (cinderling/iceball/sparkbot/ripcurrent): only spawnable once
	## their biome is actually active (see spawnable_for_wave) — grass's "full roster"
	## exception would otherwise leak them in from wave 1.
	"world_exclusive": false,
	## Blink-attacker (volcano/docks): every teleport_interval seconds, jump to a random
	## spot teleport_range out from its target instead of walking there. 0 = no teleport.
	"teleport_interval": 0.0,
	"teleport_range": 140.0,
	## Grow-in-place (ice/factory): passively wanders (ignores its target), ramping
	## body_radius/max_health/contact_damage linearly up to growth_max_mult over
	## growth_aggro_seconds, then starts actively chasing once fully grown. 0 = no growth.
	"growth_aggro_seconds": 0.0,
	"growth_max_mult": 1.0,
}

const TYPES: Array[Dictionary] = [
	{
		"id": "grunt",
		"name": "Grunt",
		"fill_color": "ff5d5d",
		"outline_color": "ffb0a9",
		"radius": 17.0,
		"max_health": 26.0,
		"movement_speed": 100.0,
		"contact_damage": 6.0,
		"attack_interval": 1.0,
		"attack_distance": 40.0,
		"xp_value": 10,
		"gold_value": 4,
		"unlock_wave": 1,
		"cost": 1.0,
		"weight": 3.5,
		"formation": Formation.SCATTERED,
		"group_min": 3,
		"group_max": 5,
		"resistances": {},
	},
	{
		"id": "swarmling",
		"name": "Swarmling",
		"fill_color": "ff7a18",
		"outline_color": "ffe08c",
		"radius": 13.0,
		"max_health": 14.0,
		"movement_speed": 175.0,
		"contact_damage": 5.0,
		"attack_interval": 0.7,
		"attack_distance": 32.0,
		"xp_value": 4,
		"gold_value": 1,
		"unlock_wave": 2,
		"cost": 0.4,
		"weight": 2.2,
		"formation": Formation.PACK,
		"group_min": 6,
		"group_max": 8,
		"separation_weight": 0.7,
		"resistances": {
			PlayerClass.DamageType.LIGHTNING: 1.6,
			PlayerClass.DamageType.IMPACT: 1.4,
		},
	},
	{
		"id": "spitter",
		"name": "Spitter",
		"behaviour": Behaviour.RANGED,
		"fill_color": "b06bff",
		"outline_color": "e2c4ff",
		"radius": 15.0,
		"max_health": 24.0,
		"movement_speed": 85.0,
		"attack_interval": 2.0,
		"attack_distance": 420.0,
		"preferred_distance": 360.0,
		"projectile_damage": 7.0,
		"projectile_speed": 420.0,
		"xp_value": 14,
		"gold_value": 4,
		"unlock_wave": 4,
		"cost": 1.2,
		"weight": 2.0,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 3,
		"resistances": {
			PlayerClass.DamageType.FROST: 1.4,
			PlayerClass.DamageType.NATURE: 1.3,
			PlayerClass.DamageType.IMPACT: 0.9,
		},
	},
	{
		"id": "drifter",
		"name": "Drifter",
		"fill_color": "8ad7ff",
		"outline_color": "e6f7ff",
		"radius": 13.0,
		"max_health": 20.0,
		"movement_speed": 135.0,
		"contact_damage": 7.0,
		"attack_interval": 0.9,
		"attack_distance": 36.0,
		"xp_value": 12,
		"gold_value": 4,
		"flying": true,
		"separation_weight": 0.5,
		"unlock_wave": 6,
		"cost": 1.0,
		"weight": 1.6,
		"formation": Formation.SCATTERED,
		"group_min": 4,
		"group_max": 7,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 0.4,
			PlayerClass.DamageType.LIGHTNING: 1.3,
			PlayerClass.DamageType.FROST: 1.2,
		},
	},
	{
		"id": "brute",
		"name": "Brute",
		"fill_color": "a52f3d",
		"outline_color": "ff8f7a",
		"radius": 28.0,
		"max_health": 130.0,
		"movement_speed": 62.0,
		"contact_damage": 18.0,
		"attack_interval": 1.3,
		"attack_distance": 52.0,
		"xp_value": 35,
		"gold_value": 12,
		"unlock_wave": 8,
		"cost": 4.0,
		"weight": 1.8,
		"formation": Formation.LONE,
		"group_min": 1,
		"group_max": 2,
		"separation_weight": 1.4,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 1.5,
			PlayerClass.DamageType.LIGHTNING: 0.6,
			PlayerClass.DamageType.FROST: 0.8,
		},
	},
	{
		"id": "stalker",
		"name": "Stalker",
		"fill_color": "ff4fd0",
		"outline_color": "ffc4f0",
		"radius": 14.0,
		"max_health": 26.0,
		"movement_speed": 205.0,
		"contact_damage": 10.0,
		"attack_interval": 0.75,
		"attack_distance": 36.0,
		"xp_value": 18,
		"gold_value": 6,
		"taunt_immune": true,
		"unlock_wave": 9,
		"cost": 1.5,
		"weight": 1.5,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 4,
		"resistances": {
			PlayerClass.DamageType.FROST: 1.7,
			PlayerClass.DamageType.IMPACT: 0.7,
		},
	},
	{
		"id": "bomber",
		"name": "Bomber",
		"fill_color": "ffdc4d",
		"outline_color": "fff3b0",
		"radius": 14.0,
		"max_health": 16.0,
		"movement_speed": 150.0,
		"attack_distance": 44.0,
		"xp_value": 16,
		"gold_value": 5,
		"flying": true,
		"separation_weight": 0.5,
		"explode_damage": 22.0,
		"explode_radius": 105.0,
		"unlock_wave": 11,
		"cost": 1.4,
		"weight": 1.4,
		"formation": Formation.SCATTERED,
		"group_min": 3,
		"group_max": 5,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 0.5,
			PlayerClass.DamageType.LIGHTNING: 1.4,
			PlayerClass.DamageType.FROST: 1.3,
		},
	},
	{
		"id": "hexer",
		"name": "Hexer",
		"behaviour": Behaviour.SUPPORT,
		"fill_color": "3fd0c0",
		"outline_color": "c2fff6",
		"radius": 18.0,
		"max_health": 60.0,
		"movement_speed": 95.0,
		"attack_distance": 300.0,
		"preferred_distance": 280.0,
		"aura_radius": 240.0,
		"aura_heal_per_second": 5.0,
		"xp_value": 30,
		"gold_value": 10,
		"unlock_wave": 12,
		"cost": 2.5,
		"weight": 1.5,
		"formation": Formation.PACK,
		"group_min": 1,
		"group_max": 2,
		"resistances": {
			PlayerClass.DamageType.NATURE: 1.8,
			PlayerClass.DamageType.LIGHTNING: 1.1,
		},
	},
	{
		"id": "sentinel",
		"name": "Sentinel",
		"fill_color": "8f9bb3",
		"outline_color": "dfe6f2",
		"radius": 22.0,
		"max_health": 100.0,
		"movement_speed": 70.0,
		"contact_damage": 12.0,
		"attack_interval": 1.1,
		"attack_distance": 46.0,
		"xp_value": 28,
		"gold_value": 10,
		"separation_weight": 1.3,
		"unlock_wave": 13,
		"cost": 2.8,
		"weight": 2.2,
		"formation": Formation.RING,
		"group_min": 3,
		"group_max": 5,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 1.6,
			PlayerClass.DamageType.LIGHTNING: 0.45,
			PlayerClass.DamageType.FROST: 0.8,
		},
	},
	{
		"id": "splitter",
		"name": "Splitter",
		"fill_color": "6fdc6f",
		"outline_color": "d6ffd6",
		"radius": 20.0,
		"max_health": 45.0,
		"movement_speed": 95.0,
		"contact_damage": 8.0,
		"attack_interval": 1.0,
		"attack_distance": 42.0,
		"xp_value": 20,
		"gold_value": 7,
		"death_spawn_id": "swarmling",
		"death_spawn_count": 3,
		"unlock_wave": 15,
		"cost": 2.0,
		"weight": 2.2,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 4,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 1.3,
		},
	},
	{
		"id": "lurker",
		"name": "Lurker",
		"behaviour": Behaviour.CHARGER,
		"fill_color": "5a3d2b",
		"outline_color": "c9a876",
		"radius": 15.0,
		"max_health": 32.0,
		"movement_speed": 55.0,
		"contact_damage": 14.0,
		"attack_interval": 1.0,
		"attack_distance": 42.0,
		"charge_speed": 480.0,
		"charge_windup": 1.0,
		"charge_duration": 0.55,
		"stealth_alpha": 0.5,
		"xp_value": 20,
		"gold_value": 6,
		"unlock_wave": 14,
		"cost": 1.8,
		"weight": 1.5,
		"formation": Formation.SCATTERED,
		"group_min": 1,
		"group_max": 2,
		"resistances": {
			PlayerClass.DamageType.LIGHTNING: 1.3,
			PlayerClass.DamageType.IMPACT: 0.8,
		},
	},
	{
		"id": "charger",
		"name": "Charger",
		"behaviour": Behaviour.CHARGER,
		"fill_color": "ff7a29",
		"outline_color": "ffd0a8",
		"radius": 19.0,
		"max_health": 55.0,
		"movement_speed": 85.0,
		"contact_damage": 16.0,
		"attack_interval": 1.0,
		"attack_distance": 44.0,
		"charge_speed": 430.0,
		"charge_windup": 0.7,
		"charge_duration": 0.8,
		"xp_value": 24,
		"gold_value": 8,
		"unlock_wave": 17,
		"cost": 2.2,
		"weight": 1.6,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 3,
		"resistances": {
			PlayerClass.DamageType.FROST: 1.5,
			PlayerClass.DamageType.IMPACT: 0.85,
		},
	},
	{
		"id": "summoner",
		"name": "Summoner",
		"behaviour": Behaviour.SUPPORT,
		"fill_color": "c85cff",
		"outline_color": "eccfff",
		"radius": 19.0,
		"max_health": 70.0,
		"movement_speed": 80.0,
		"attack_distance": 340.0,
		"preferred_distance": 330.0,
		"summon_id": "swarmling",
		"summon_count": 3,
		"summon_interval": 6.0,
		"xp_value": 32,
		"gold_value": 12,
		"unlock_wave": 19,
		"cost": 3.0,
		"weight": 1.4,
		"formation": Formation.LONE,
		"group_min": 1,
		"group_max": 2,
		"resistances": {
			PlayerClass.DamageType.NATURE: 1.6,
		},
	},
	{
		"id": "cinderling",
		"name": "Cinderling",
		"fill_color": "ff5a1e",
		"outline_color": "ffd08a",
		"radius": 15.0,
		"max_health": 26.0,
		"movement_speed": 120.0,
		"contact_damage": 8.0,
		"attack_interval": 0.8,
		"attack_distance": 34.0,
		"xp_value": 16,
		"gold_value": 5,
		"world_exclusive": true,
		"teleport_interval": 3.5,
		"teleport_range": 150.0,
		"unlock_wave": 1,
		"cost": 1.3,
		"weight": 1.8,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 4,
		"resistances": {
			PlayerClass.DamageType.FROST: 1.5,
			PlayerClass.DamageType.IMPACT: 0.7,
		},
	},
	{
		"id": "iceball",
		"name": "Iceball",
		"fill_color": "aee9ff",
		"outline_color": "ffffff",
		"radius": 12.0,
		"max_health": 16.0,
		"movement_speed": 70.0,
		"contact_damage": 4.0,
		"attack_interval": 0.9,
		"attack_distance": 34.0,
		"xp_value": 18,
		"gold_value": 6,
		"world_exclusive": true,
		"growth_aggro_seconds": 14.0,
		"growth_max_mult": 2.6,
		"unlock_wave": 1,
		"cost": 1.6,
		"weight": 1.6,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 3,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 1.4,
			PlayerClass.DamageType.NATURE: 1.2,
		},
	},
	{
		"id": "sparkbot",
		"name": "Sparkbot",
		"fill_color": "ffd23a",
		"outline_color": "fff2b0",
		"radius": 16.0,
		"max_health": 34.0,
		"movement_speed": 90.0,
		"contact_damage": 5.0,
		"attack_interval": 1.0,
		"attack_distance": 36.0,
		"xp_value": 20,
		"gold_value": 7,
		"world_exclusive": true,
		"growth_aggro_seconds": 9.0,
		"growth_max_mult": 1.8,
		"unlock_wave": 1,
		"cost": 1.9,
		"weight": 1.6,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 3,
		"resistances": {
			PlayerClass.DamageType.LIGHTNING: 1.6,
			PlayerClass.DamageType.FROST: 0.8,
		},
	},
	{
		"id": "ripcurrent",
		"name": "Ripcurrent",
		"fill_color": "2ecfc0",
		"outline_color": "d0fff5",
		"radius": 14.0,
		"max_health": 22.0,
		"movement_speed": 110.0,
		"contact_damage": 7.0,
		"attack_interval": 0.85,
		"attack_distance": 34.0,
		"xp_value": 15,
		"gold_value": 5,
		"world_exclusive": true,
		"teleport_interval": 2.6,
		"teleport_range": 110.0,
		"unlock_wave": 1,
		"cost": 1.4,
		"weight": 1.7,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 4,
		"resistances": {
			PlayerClass.DamageType.NATURE: 1.3,
			PlayerClass.DamageType.IMPACT: 0.8,
		},
	},
	{
		"id": "ravager",
		"name": "Ravager",
		"fill_color": "ff3a3a",
		"outline_color": "ffd0d0",
		"radius": 68.0,
		"max_health": 1400.0,
		"movement_speed": 92.0,
		"contact_damage": 12.0,
		"attack_interval": 0.85,
		"attack_distance": 92.0,
		"xp_value": 420,
		"gold_value": 180,
		"is_boss": true,
		"separation_weight": 2.0,
		"summon_id": "",
		"summon_count": 0,
		"summon_interval": 0.0,
		"charge_speed": 540.0,
		"charge_windup": 0.5,
		"charge_duration": 0.62,
		"dash_interval": 3.2,
		"unlock_wave": 5,
		"cost": 12.0,
		"weight": 0.0,
		"formation": Formation.LONE,
		"group_min": 1,
		"group_max": 1,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 1.2,
			PlayerClass.DamageType.LIGHTNING: 0.75,
		},
	},
	{
		"id": "stormcaller",
		"name": "Stormcaller",
		"behaviour": Behaviour.RANGED,
		"fill_color": "2f6bff",
		"outline_color": "b8d4ff",
		"radius": 58.0,
		"max_health": 1100.0,
		"movement_speed": 128.0,
		"attack_interval": 0.9,
		"attack_distance": 720.0,
		"preferred_distance": 380.0,
		"projectile_damage": 16.0,
		"projectile_speed": 500.0,
		"projectile_count": 7,
		"projectile_sprite": "bolt",
		"xp_value": 460,
		"gold_value": 200,
		"is_boss": true,
		"flying": true,
		"separation_weight": 2.0,
		"aura_radius": 340.0,
		"aura_heal_per_second": 10.0,
		"charge_speed": 560.0,
		"charge_windup": 0.42,
		"charge_duration": 0.5,
		"dash_interval": 4.0,
		"unlock_wave": 10,
		"cost": 12.0,
		"weight": 0.0,
		"formation": Formation.LONE,
		"group_min": 1,
		"group_max": 1,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 0.5,
			PlayerClass.DamageType.NATURE: 1.4,
			PlayerClass.DamageType.FROST: 1.15,
		},
	},
]

const BOSS_ROTATION: Array[String] = ["ravager", "stormcaller"]

## Signature roster per biome when biomes are on and biome_id > 0 (grass uses the full table).
## Duplicates raise pick weight in spawnable_for_wave. Grunt/swarmling stay first so wave 1 is fair.
## Volcano leans charger/bomber; ice leans lurker/stalker; factory brute/sentinel; docks drifter/bomber.
## Each world's own signature enemy (cinderling/iceball/sparkbot/ripcurrent) is listed
## twice so it comes up about as often as the pool's more common entries — pool
## membership just gates *whether* a type can spawn, weight decides how often within that.
const BIOME_POOLS := {
	1: ["grunt", "swarmling", "charger", "bomber", "spitter", "lurker", "hexer", "charger", "splitter", "bomber", "cinderling", "cinderling"],
	2: ["grunt", "swarmling", "lurker", "stalker", "spitter", "lurker", "stalker", "hexer", "brute", "summoner", "iceball", "iceball"],
	3: ["grunt", "swarmling", "spitter", "brute", "sentinel", "splitter", "charger", "summoner", "sparkbot", "sparkbot"],
	4: ["grunt", "swarmling", "spitter", "drifter", "bomber", "stalker", "lurker", "hexer", "ripcurrent", "ripcurrent"],
}

const BIOME_STANDINS := {
	1: {
		"drifter": "bomber",
		"brute": "charger",
		"stalker": "lurker",
		"sentinel": "hexer",
		"summoner": "hexer",
	},
	2: {
		"drifter": "stalker",
		"bomber": "spitter",
		"sentinel": "brute",
		"splitter": "lurker",
		"charger": "lurker",
	},
	3: {
		"drifter": "sentinel",
		"bomber": "spitter",
		"lurker": "brute",
		"hexer": "sentinel",
		"stalker": "charger",
	},
	4: {
		"brute": "drifter",
		"sentinel": "bomber",
		"charger": "drifter",
		"summoner": "hexer",
		"splitter": "bomber",
	},
}


static func ids() -> Array[String]:
	var type_ids: Array[String] = []
	for type_data in TYPES:
		type_ids.append(type_data.id)
	return type_ids


static func by_id(type_id: String) -> Dictionary:
	for type_data in TYPES:
		if type_data.id == type_id:
			return type_data
	return TYPES[0]


static func field(type_id: String, key: String) -> Variant:
	var type_data := by_id(type_id)
	if type_data.has(key):
		return type_data[key]
	return BASE_DEFAULTS.get(key, null)


## Per-world combat twist on top of the shared roster. Grass stays the baseline.
static func biome_multipliers() -> Dictionary:
	if not GameRuntime.uses_biomes():
		return {}
	match GameRuntime.biome_id:
		1:
			# Magma: faster, harder hits, bigger bomber blasts, a bit glassier.
			return {
				"speed": 1.18,
				"contact": 1.22,
				"health": 0.92,
				"explode_radius": 1.4,
				"flying_speed": 1.12,
			}
		2:
			# Ice: slow tanks that kite from farther out.
			return {
				"speed": 0.82,
				"health": 1.28,
				"contact": 0.9,
				"projectile_speed": 0.75,
				"projectile_damage": 1.2,
				"attack_distance": 1.22,
				"preferred_distance": 1.18,
			}
		3:
			# Factory: armoured, punchier shots, heavier footsteps.
			return {
				"speed": 0.88,
				"health": 1.35,
				"attack_interval": 0.82,
				"contact": 1.12,
			}
		4:
			# Docks: swift, extra loot, fliers zoom the piers.
			return {
				"speed": 1.16,
				"health": 0.95,
				"gold": 1,
				"flying_speed": 1.28,
			}
		_:
			return {}


static func is_valid_id(type_id: String) -> bool:
	for type_data in TYPES:
		if type_data.id == type_id:
			return true
	return false


static func sanitize_id(type_id: String) -> String:
	return type_id if is_valid_id(type_id) else DEFAULT_TYPE_ID


static func display_name(type_data: Dictionary) -> String:
	return str(type_data.name)


const TOBOR_NAMES := {
	"grunt": "Winkelwagen",
	"swarmling": "Schroef",
	"spitter": "Scanner",
	"drifter": "Drone",
	"brute": "Heftruck",
	"stalker": "Racekar",
	"bomber": "Aanbieding",
	"hexer": "Kassa",
	"sentinel": "Camera",
	"splitter": "Kopieerbot",
	"charger": "Skatebot",
	"summoner": "Omroeper",
	"lurker": "Doos",
	"ravager": "Magazijnbaas",
	"stormcaller": "Bewakingsblimp",
}


static func is_boss(type_id: String) -> bool:
	return bool(field(type_id, "is_boss"))


static func spawnable_for_wave(wave: int) -> Array[Dictionary]:
	var pool := ids_for_active_biome()
	var available: Array[Dictionary] = []
	for type_data in TYPES:
		if is_boss(str(type_data.id)) or float(type_data.weight) <= 0.0:
			continue
		if bool(type_data.get("world_exclusive", false)) and GameRuntime.biome_id <= 0:
			continue
		var unlock := int(type_data.unlock_wave)
		if wave >= 4:
			unlock = maxi(1, unlock - 2)
		if unlock > wave:
			continue
		if not pool.is_empty() and str(type_data.id) not in pool:
			continue
		var copies := 1 if pool.is_empty() else pool.count(str(type_data.id))
		if copies > 1:
			var weighted := type_data.duplicate()
			weighted["weight"] = float(type_data.weight) * float(copies)
			available.append(weighted)
		else:
			available.append(type_data)
	if available.is_empty() and not pool.is_empty():
		return spawnable_unfiltered(wave)
	return available


static func spawnable_unfiltered(wave: int) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for type_data in TYPES:
		if is_boss(str(type_data.id)) or float(type_data.weight) <= 0.0:
			continue
		var unlock := int(type_data.unlock_wave)
		if wave >= 4:
			unlock = maxi(1, unlock - 2)
		if unlock <= wave:
			available.append(type_data)
	return available


static func ids_for_active_biome() -> Array[String]:
	if not GameRuntime.uses_biomes() or GameRuntime.biome_id <= 0:
		return []
	return ids_for_biome(GameRuntime.biome_id)


static func ids_for_biome(biome: int) -> Array[String]:
	var raw: Variant = BIOME_POOLS.get(biome, [])
	var ids: Array[String] = []
	if raw is Array:
		for type_id in raw:
			ids.append(str(type_id))
	return ids


## Map a requested type onto the active biome pool. Bosses and grass (biome 0) pass through.
static func fit_to_biome(type_id: String) -> String:
	if type_id.is_empty():
		return ""
	if is_boss(type_id):
		return sanitize_id(type_id)
	var pool := ids_for_active_biome()
	if pool.is_empty():
		return sanitize_id(type_id)
	if type_id in pool and is_valid_id(type_id):
		return type_id
	var standins: Dictionary = BIOME_STANDINS.get(GameRuntime.biome_id, {})
	var mapped := str(standins.get(type_id, ""))
	if not mapped.is_empty() and mapped in pool and is_valid_id(mapped):
		return mapped
	return str(pool[0])


static func boss_for_wave(wave: int) -> String:
	var unlocked: Array[String] = []
	for boss_id in BOSS_ROTATION:
		if int(by_id(boss_id).unlock_wave) <= wave:
			unlocked.append(boss_id)
	if unlocked.is_empty():
		return BOSS_ROTATION[0]
	return unlocked[(int(wave) / 5 - 1) % unlocked.size()]


static func damage_multiplier(type_id: String, damage_type: int) -> float:
	var resistances: Dictionary = field(type_id, "resistances")
	return float(resistances.get(damage_type, 1.0))

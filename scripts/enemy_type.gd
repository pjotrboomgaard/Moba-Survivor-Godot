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
	"separation_weight": 1.0,
	"gold_value": 2,
	"resistances": {},
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
		"gold_value": 3,
		"unlock_wave": 1,
		"cost": 1.0,
		"weight": 3.0,
		"formation": Formation.SCATTERED,
		"group_min": 3,
		"group_max": 5,
		"resistances": {},
	},
	{
		"id": "swarmling",
		"name": "Swarmling",
		"fill_color": "ff9d4d",
		"outline_color": "ffd9a8",
		"radius": 11.0,
		"max_health": 12.0,
		"movement_speed": 165.0,
		"contact_damage": 4.0,
		"attack_interval": 0.7,
		"attack_distance": 32.0,
		"xp_value": 4,
		"gold_value": 1,
		"unlock_wave": 2,
		"cost": 0.4,
		"weight": 3.0,
		"formation": Formation.PACK,
		"group_min": 8,
		"group_max": 12,
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
		"weight": 2.0,
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
		"weight": 1.5,
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
		"weight": 2.0,
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
		"weight": 1.8,
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
		"weight": 1.8,
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
		"weight": 1.8,
		"formation": Formation.SCATTERED,
		"group_min": 2,
		"group_max": 4,
		"resistances": {
			PlayerClass.DamageType.IMPACT: 1.3,
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
		"id": "ravager",
		"name": "Ravager",
		"fill_color": "7a0f2b",
		"outline_color": "ff6b6b",
		"radius": 52.0,
		"max_health": 1400.0,
		"movement_speed": 58.0,
		"contact_damage": 30.0,
		"attack_interval": 1.4,
		"attack_distance": 82.0,
		"xp_value": 300,
		"gold_value": 120,
		"is_boss": true,
		"separation_weight": 2.0,
		"summon_id": "swarmling",
		"summon_count": 4,
		"summon_interval": 7.0,
		"unlock_wave": 10,
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
		"radius": 44.0,
		"max_health": 1100.0,
		"movement_speed": 95.0,
		"attack_interval": 1.5,
		"attack_distance": 620.0,
		"preferred_distance": 420.0,
		"projectile_damage": 12.0,
		"projectile_speed": 460.0,
		"projectile_count": 5,
		"projectile_sprite": "bolt",
		"xp_value": 320,
		"gold_value": 140,
		"is_boss": true,
		"flying": true,
		"separation_weight": 2.0,
		"aura_radius": 300.0,
		"aura_heal_per_second": 6.0,
		"unlock_wave": 20,
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


static func is_valid_id(type_id: String) -> bool:
	for type_data in TYPES:
		if type_data.id == type_id:
			return true
	return false


static func sanitize_id(type_id: String) -> String:
	return type_id if is_valid_id(type_id) else DEFAULT_TYPE_ID


static func is_boss(type_id: String) -> bool:
	return bool(field(type_id, "is_boss"))


static func spawnable_for_wave(wave: int) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for type_data in TYPES:
		if is_boss(str(type_data.id)) or float(type_data.weight) <= 0.0:
			continue
		if int(type_data.unlock_wave) <= wave:
			available.append(type_data)
	return available


static func boss_for_wave(wave: int) -> String:
	var unlocked: Array[String] = []
	for boss_id in BOSS_ROTATION:
		if int(by_id(boss_id).unlock_wave) <= wave:
			unlocked.append(boss_id)
	if unlocked.is_empty():
		return BOSS_ROTATION[0]
	return unlocked[(wave / 10 - 1) % unlocked.size()]


static func damage_multiplier(type_id: String, damage_type: int) -> float:
	var resistances: Dictionary = field(type_id, "resistances")
	return float(resistances.get(damage_type, 1.0))

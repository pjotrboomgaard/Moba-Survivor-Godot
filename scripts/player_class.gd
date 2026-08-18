class_name PlayerClass
extends RefCounted

enum Weapon {
	CHAIN_BOLT,
	CONE_SLAM,
	MENDING_BOLT,
	FROST_SHARD,
}

enum EffectStyle {
	BOLT,
	BURST,
}

enum DamageType {
	LIGHTNING,
	IMPACT,
	NATURE,
	FROST,
}

const DEFAULT_CLASS_ID := "arclight"

const CLASSES: Array[Dictionary] = [
	{
		"id": "arclight",
		"name": "Arclight",
		"role": "Damage",
		"weapon_name": "Arc Staff",
		"description": "Glass cannon. Chains lightning between packed enemies, but armour shrugs it off.",
		"counters": "Strong vs swarms and fliers  ·  Weak vs armour",
		"damage_type": DamageType.LIGHTNING,
		"weapon": Weapon.CHAIN_BOLT,
		"effect_style": EffectStyle.BOLT,
		"body_color": "45a3ff",
		"accent_color": "bce2ff",
		"effect_color": "8eeeff",
		"effect_secondary": "b990ff",
		"max_health": 100.0,
		"movement_speed": 300.0,
		"attack_interval": 0.7,
		"weapon_damage": 18.0,
		"attack_range": 620.0,
		"aim_assist_radius": 82.0,
		"chain_count": 1,
		"chain_range": 190.0,
		"damage_taken_multiplier": 1.0,
		"taunt_weight": 1.0,
		"upgrades": ["rapid", "heavy", "chain", "boots", "vitality"],
	},
	{
		"id": "bulwark",
		"name": "Bulwark",
		"role": "Tank",
		"weapon_name": "Aegis Hammer",
		"description": "Frontline anchor. Draws enemies in and slams everything in front, but cannot reach the sky.",
		"counters": "Strong vs armour and brutes  ·  Weak vs fliers",
		"damage_type": DamageType.IMPACT,
		"weapon": Weapon.CONE_SLAM,
		"effect_style": EffectStyle.BURST,
		"body_color": "e0a44b",
		"accent_color": "ffe3a8",
		"effect_color": "ffc46b",
		"effect_secondary": "ff8a3d",
		"max_health": 220.0,
		"movement_speed": 230.0,
		"attack_interval": 0.95,
		"weapon_damage": 30.0,
		"attack_range": 150.0,
		"aim_assist_radius": 150.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.7,
		"taunt_weight": 0.4,
		"upgrades": ["plating", "reach", "heavy", "boots", "vitality"],
	},
	{
		"id": "warden",
		"name": "Warden",
		"role": "Support",
		"weapon_name": "Verdant Censer",
		"description": "Force multiplier. Heals nearby allies, raises their damage and purges enemy support.",
		"counters": "Strong vs hexers and summoners",
		"damage_type": DamageType.NATURE,
		"weapon": Weapon.MENDING_BOLT,
		"effect_style": EffectStyle.BOLT,
		"body_color": "45d483",
		"accent_color": "c8ffdf",
		"effect_color": "7dffb4",
		"effect_secondary": "d9ff8a",
		"max_health": 140.0,
		"movement_speed": 285.0,
		"attack_interval": 0.55,
		"weapon_damage": 11.0,
		"attack_range": 520.0,
		"aim_assist_radius": 95.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.0,
		"taunt_weight": 1.25,
		"upgrades": ["flow", "choir", "rapid", "boots", "vitality"],
	},
	{
		"id": "frostbinder",
		"name": "Frostbinder",
		"role": "Control",
		"weapon_name": "Rime Lance",
		"description": "Space control. Freezing bursts slow whole groups and shatter anything that moves fast.",
		"counters": "Strong vs stalkers and chargers  ·  Weak vs brutes",
		"damage_type": DamageType.FROST,
		"weapon": Weapon.FROST_SHARD,
		"effect_style": EffectStyle.BURST,
		"body_color": "7ba9ff",
		"accent_color": "dbe9ff",
		"effect_color": "a8dcff",
		"effect_secondary": "6f8dff",
		"max_health": 130.0,
		"movement_speed": 270.0,
		"attack_interval": 0.8,
		"weapon_damage": 12.0,
		"attack_range": 460.0,
		"aim_assist_radius": 110.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.0,
		"taunt_weight": 1.15,
		"upgrades": ["depth", "shatter", "heavy", "boots", "vitality"],
	},
]

const SUPPORT_AURA_RADIUS := 220.0
const SUPPORT_HEAL_PER_SECOND := 3.0
const SUPPORT_DAMAGE_BONUS := 0.15
const BULWARK_TAUNT_RADIUS := 260.0
const FROST_BURST_RADIUS := 150.0
const FROST_SLOW_FACTOR := 0.55
const FROST_SLOW_DURATION := 2.5
const CONE_HALF_ANGLE_DEGREES := 62.0

const UPGRADES: Dictionary = {
	"rapid": {"name": "Rapid Casting", "description": "Attack 18% faster"},
	"heavy": {"name": "Charged Weapon", "description": "+8 weapon damage"},
	"chain": {"name": "Forked Current", "description": "+1 Arc Staff chain"},
	"boots": {"name": "Windstep Boots", "description": "+35 movement speed"},
	"vitality": {"name": "Second Wind", "description": "+25 max HP and heal"},
	"plating": {"name": "Layered Plating", "description": "-8% damage taken"},
	"reach": {"name": "Long Haft", "description": "+35 slam radius"},
	"flow": {"name": "Steady Flow", "description": "+1.5 aura healing per second"},
	"choir": {"name": "Rising Choir", "description": "+6% team damage aura"},
	"depth": {"name": "Deep Freeze", "description": "Stronger and longer slow"},
	"shatter": {"name": "Shatter Front", "description": "+35 frost burst radius"},
}


static func ids() -> Array[String]:
	var class_ids: Array[String] = []
	for class_data in CLASSES:
		class_ids.append(class_data.id)
	return class_ids


static func by_id(class_id: String) -> Dictionary:
	for class_data in CLASSES:
		if class_data.id == class_id:
			return class_data
	return CLASSES[0]


static func is_valid_id(class_id: String) -> bool:
	for class_data in CLASSES:
		if class_data.id == class_id:
			return true
	return false


static func sanitize_id(class_id: String) -> String:
	return class_id if is_valid_id(class_id) else DEFAULT_CLASS_ID


static func random_upgrade_ids(class_id: String, amount: int = 3) -> Array[String]:
	var pool: Array[String] = []
	for upgrade_id in by_id(class_id).upgrades:
		pool.append(upgrade_id)
	pool.shuffle()
	return pool.slice(0, amount)


static func upgrade_info(upgrade_id: String) -> Dictionary:
	return UPGRADES.get(upgrade_id, {"name": upgrade_id, "description": ""})

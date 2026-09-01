class_name PlayerClass
extends RefCounted

enum Weapon {
	CHAIN_BOLT,
	CONE_SLAM,
	MENDING_BOLT,
	FROST_SHARD,
	ENERGY_BLAST,
}

enum EffectStyle {
	BOLT,
	BURST,
	## Smooth vine-like curve instead of a jagged bolt — Warden's Mending Bolt used to render
	## as a green-tinted copy of Arclight's lightning, which read as the same weapon.
	WAVE,
	## Expanding explosion at the impact, with a short cannon cone from the caster — Tobor's blast.
	BLAST,
	## Directional wedge in the facing direction, not a full ring around the caster — Bulwark slam.
	ARC,
}

enum DamageType {
	LIGHTNING,
	IMPACT,
	NATURE,
	FROST,
}

const DEFAULT_CLASS_ID := "tobor"

const CLASSES: Array[Dictionary] = [
	{
		"id": "tobor",
		"name": "Tobor",
		"role": "Glass Cannon",
		"menu_bg": "res://assets/ui/tobor_menu_bg.png",
		"weapon_name": "Blast Cannon",
		"description": "Glass cannon on wheels. Blast Cannon hits hard; buy parts in the shop.",
		"counters": "Strong vs swarms  ·  Weak vs anything that hits back",
		"damage_type": DamageType.LIGHTNING,
		"weapon": Weapon.ENERGY_BLAST,
		"effect_style": EffectStyle.BLAST,
		"body_color": "9aa8b3",
		"accent_color": "ff8a3d",
		"effect_color": "ffd36b",
		"effect_secondary": "ff8a3d",
		"health_bar_color": "ff9a3c",
		"max_health": 58.0,
		"movement_speed": 355.0,
		"attack_interval": 0.65,
		"weapon_damage": 18.0,
		"attack_range": 520.0,
		"aim_assist_radius": 88.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"blast_radius": 70.0,
		"damage_taken_multiplier": 1.4,
		"taunt_weight": 1.0,
		"secondary": "repulse",
		"secondary_cooldown": 9.0,
		"upgrades": ["rapid", "heavy", "blast", "aftershock", "vitality"],
		"ability_pool": [],
	},
	{
		"id": "arclight",
		"name": "Diord",
		"role": "Damage",
		"menu_bg": "res://assets/ui/arclight_menu_bg.png",
		"weapon_name": "Volt Staff",
		"description": "Staff droid. Chains lightning through packed enemies.",
		"counters": "Strong vs swarms and fliers  ·  Weak vs armour",
		"damage_type": DamageType.LIGHTNING,
		"weapon": Weapon.CHAIN_BOLT,
		"effect_style": EffectStyle.BOLT,
		"body_color": "e8e8e8",
		"accent_color": "e05a28",
		"effect_color": "ffe14a",
		"effect_secondary": "7af0ff",
		"health_bar_color": "3ec8ff",
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
		"secondary": "volt_mend",
		"secondary_cooldown": 10.0,
		"upgrades": ["rapid", "heavy", "chain", "volt", "vitality"],
		"ability_pool": [
			"arclight_static_bolt", "arclight_overcharge", "arclight_ion_storm", "arclight_arc_flash",
			"arclight_thunder_step", "arclight_overclock", "arclight_paralyzing_bolt", "arclight_ball_lightning",
			"arclight_volt_siphon", "arclight_track", "arclight_repulsor_field", "arclight_second_wind",
		],
	},
	{
		"id": "bulwark",
		"name": "Romra",
		"role": "Tank",
		"menu_bg": "res://assets/ui/bulwark_menu_bg.png",
		"weapon_name": "Shield Hammer",
		"description": "Ground tank. Slams a cone and pulls aggro.",
		"counters": "Strong vs armour and brutes  ·  Weak vs fliers",
		"damage_type": DamageType.IMPACT,
		"weapon": Weapon.CONE_SLAM,
		"effect_style": EffectStyle.ARC,
		"body_color": "e05a28",
		"accent_color": "e8e8e8",
		"effect_color": "ffc46b",
		"effect_secondary": "ff8a3d",
		"health_bar_color": "e44545",
		"max_health": 220.0,
		"movement_speed": 230.0,
		"attack_interval": 1.05,
		"weapon_damage": 18.0,
		"attack_range": 115.0,
		"aim_assist_radius": 115.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.7,
		"taunt_weight": 0.4,
		"secondary": "wall",
		"secondary_cooldown": 12.0,
		"upgrades": ["plating", "reach", "sweep", "heavy", "vitality"],
		"ability_pool": [
			"bulwark_shockwave_strike", "bulwark_ground_slam", "bulwark_cleave", "bulwark_iron_charge",
			"bulwark_fortify", "bulwark_provoke", "bulwark_last_stand", "bulwark_aftershock",
			"bulwark_second_wind", "bulwark_rallying_warcry", "bulwark_retribution", "bulwark_sunder",
		],
	},
	{
		"id": "warden",
		"name": "Enord",
		"role": "Support",
		"menu_bg": "res://assets/ui/warden_menu_bg.png",
		"weapon_name": "Plus Beam",
		"description": "Hover drone. Heals allies and pokes foes with a green beam.",
		"counters": "Strong vs hexers and summoners",
		"damage_type": DamageType.NATURE,
		"weapon": Weapon.MENDING_BOLT,
		"effect_style": EffectStyle.WAVE,
		"body_color": "e8e8e8",
		"accent_color": "8cff4a",
		"effect_color": "7dffb4",
		"effect_secondary": "d9ff8a",
		"health_bar_color": "45d483",
		"max_health": 140.0,
		"movement_speed": 310.0,
		"attack_interval": 0.55,
		"weapon_damage": 11.0,
		"attack_range": 520.0,
		"aim_assist_radius": 95.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.0,
		"taunt_weight": 1.25,
		"hovering": true,
		"secondary": "freeze",
		"secondary_cooldown": 10.0,
		"upgrades": ["flow", "choir", "lash", "rapid", "vitality"],
		"ability_pool": [
			"warden_vine_lash", "warden_mending_wave", "warden_thorn_volley", "warden_entangle",
			"warden_natures_grasp", "warden_verdant_ward", "warden_rising_choir", "warden_vine_step",
			"warden_natures_wrath", "warden_second_bloom", "warden_vital_drain", "warden_bramble_wall",
		],
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
		"health_bar_color": "7ba9ff",
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
		"secondary": "rime_ward",
		"secondary_cooldown": 10.0,
		"upgrades": ["depth", "shatter", "rime", "heavy", "vitality"],
		"ability_pool": [
			"frostbinder_ice_spike", "frostbinder_frost_nova", "frostbinder_glacial_cone", "frostbinder_deep_freeze",
			"frostbinder_shatter_chain", "frostbinder_frost_step", "frostbinder_permafrost", "frostbinder_vortex",
			"frostbinder_chilling_clarity", "frostbinder_rime_barrage", "frostbinder_frostbite_mark", "frostbinder_absolute_zero",
		],
	},
]

const SUPPORT_AURA_RADIUS := 220.0
const SUPPORT_HEAL_PER_SECOND := 3.0
const SUPPORT_DAMAGE_BONUS := 0.15
const BULWARK_TAUNT_RADIUS := 260.0
const FROST_BURST_RADIUS := 150.0
const FROST_SLOW_FACTOR := 0.55
const FROST_SLOW_DURATION := 2.5
const CONE_HALF_ANGLE_DEGREES := 36.0
const ABILITY_CONE_HALF_ANGLE_DEGREES := 62.0
const BLAST_RADIUS := 70.0
const BLAST_AFTERSHOCK_DAMAGE := 0.55
const SWEEP_DEGREES := 12.0
const SECONDARY_COOLDOWN := 10.0
const SECONDARY_RADIUS := 170.0
const SECONDARY_HEAL := 28.0
const SECONDARY_DAMAGE := 16.0
const WALL_DURATION := 6.0
const WALL_MAX_LENGTH := 280.0
const WALL_THICKNESS := 28.0

const UPGRADES: Dictionary = {
	"rapid": {"name": "Rapid Casting", "description": "Attack 18% faster"},
	"heavy": {"name": "Charged Weapon", "description": "+8 weapon damage"},
	"chain": {"name": "Forked Current", "description": "+1 Arc Staff chain"},
	"volt": {"name": "Long Arc", "description": "+40 lightning chain range"},
	"blast": {"name": "Wider Blast", "description": "+40 blast radius"},
	"aftershock": {"name": "Aftershock", "description": "A second blast pulse at the impact"},
	"boots": {"name": "Windstep Boots", "description": "+35 movement speed"},
	"vitality": {"name": "Second Wind", "description": "+25 max HP and heal"},
	"plating": {"name": "Layered Plating", "description": "-8% damage taken"},
	"reach": {"name": "Long Haft", "description": "+35 slam radius"},
	"sweep": {"name": "Wide Sweep", "description": "+14 degrees slam arc"},
	"flow": {"name": "Steady Flow", "description": "+1.5 aura healing per second"},
	"choir": {"name": "Rising Choir", "description": "+6% team damage aura"},
	"lash": {"name": "Long Lash", "description": "+60 mending range"},
	"depth": {"name": "Deep Freeze", "description": "Stronger and longer slow"},
	"shatter": {"name": "Shatter Front", "description": "+35 frost burst radius"},
	"rime": {"name": "Rime Tempo", "description": "Cast frost 18% faster"},
}


## Abilities always cap at 4 known, and every known ability can keep ranking up this high.
const MAX_KNOWN_ABILITIES := 4
const MAX_ABILITY_RANK := 5

## Cooldowns are authored short in the ABILITIES table below and then stretched here, so
## every ability starts out slow at rank 1 (long cooldown to earn) and comes down hard as it
## ranks up, instead of hand-tripling every one of the 48 entries individually.
const ABILITY_COOLDOWN_BASE_MULTIPLIER := 3.0
const ABILITY_COOLDOWN_PER_RANK_MULTIPLIER := 4.2
const ABILITY_COOLDOWN_MIN_MULTIPLIER := 1.6

## Abilities hit twice as hard (damage/heal/shield/knockback) as their authored numbers below,
## on top of everything else — a flat power multiplier so the whole roster stays proportional
## instead of hand-doubling 48 entries.
const ABILITY_POWER_MULTIPLIER := 2.0

## Area/chain/mobility abilities also grow physically stronger with rank, not just cheaper —
## a maxed-out ability should feel like it can clear a crowd, not just tick faster.
const ABILITY_RADIUS_GROWTH_PER_RANK := 0.15
const ABILITY_RANGE_GROWTH_PER_RANK := 0.08
const ABILITY_DASH_GROWTH_PER_RANK := 0.06
const ABILITY_CHAIN_RANKS_PER_BONUS := 2
## Every authored radius is stretched again so abilities feel like screen-wide spells.
const AOE_RADIUS_MULTIPLIER := 1.65
## Smaller blasts recycle faster; huge novas take longer. Footprint is the effective radius in units.
const AOE_COOLDOWN_FOOTPRINT_MIN := 90.0
const AOE_COOLDOWN_FOOTPRINT_MAX := 360.0
const AOE_COOLDOWN_SCALE_MIN := 0.52
const AOE_COOLDOWN_SCALE_MAX := 1.28

## Very long runs eventually run out of things to offer (4 abilities, all maxed); rather than
## stall the level-up screen, this flat, choice-free bump keeps the run moving.
const FALLBACK_UPGRADE_HEALTH_BONUS := 20.0

## Ability archetypes — the reusable cast "shapes" every ability id below picks from. See
## Player._cast_known_ability for the matching gameplay code.
enum Archetype {
	NUKE_BOLT,
	CONE_BURST,
	RADIUS_BURST,
	CHAIN_NUKE,
	DASH_STRIKE,
	BLINK,
	SELF_HEAL,
	AOE_HEAL,
	SHIELD_BURST,
	BUFF_SELF,
	PUSH_PULL_BURST,
}

const ARCHETYPE_NAMES := {
	Archetype.NUKE_BOLT: "nuke_bolt",
	Archetype.CONE_BURST: "cone_burst",
	Archetype.RADIUS_BURST: "radius_burst",
	Archetype.CHAIN_NUKE: "chain_nuke",
	Archetype.DASH_STRIKE: "dash_strike",
	Archetype.BLINK: "blink",
	Archetype.SELF_HEAL: "self_heal",
	Archetype.AOE_HEAL: "aoe_heal",
	Archetype.SHIELD_BURST: "shield_burst",
	Archetype.BUFF_SELF: "buff_self",
	Archetype.PUSH_PULL_BURST: "push_pull_burst",
}

## id -> data. Every hero picks 12 of these (see CLASSES[i].ability_pool). Numeric fields scale
## linearly with rank via ability_values(); everything else (radius, chain_count, dash_distance,
## on-hit modifiers, buff_stats) stays fixed across ranks to keep each entry small.
const ABILITIES: Dictionary = {
	# --- Arclight -----------------------------------------------------------------------
	"arclight_static_bolt": {
		"name": "Static Bolt", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a bolt that detonates in a wide arc of raw current.",
		"cooldown_base": 3.4, "cooldown_per_rank": -0.4, "cooldown_min": 1.8,
		"power_base": 46.0, "power_per_rank": 12.0, "range": 620.0,
	},
	"arclight_overcharge": {
		"name": "Overcharge", "archetype": Archetype.CHAIN_NUKE,
		"description": "A heavy bolt that arcs between packed enemies.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.7, "cooldown_min": 3.6,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 620.0,
		"chain_count": 4, "chain_range": 220.0,
	},
	"arclight_ion_storm": {
		"name": "Ion Storm", "archetype": Archetype.RADIUS_BURST,
		"description": "Discharge a ring of lightning around yourself.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.8, "cooldown_min": 3.8,
		"power_base": 24.0, "power_per_rank": 7.0, "range": 0.0, "radius": 170.0,
	},
	"arclight_arc_flash": {
		"name": "Arc Flash", "archetype": Archetype.CONE_BURST,
		"description": "Blast a forward cone with a wide arc of current.",
		"cooldown_base": 5.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.0,
		"power_base": 30.0, "power_per_rank": 8.0, "radius": 260.0,
	},
	"arclight_thunder_step": {
		"name": "Thunder Step", "archetype": Archetype.BLINK,
		"description": "Teleport forward and detonate lightning on landing.",
		"cooldown_base": 9.0, "cooldown_per_rank": -1.0, "cooldown_min": 5.0,
		"power_base": 0.0, "power_per_rank": 0.0, "dash_distance": 300.0,
	},
	"arclight_overclock": {
		"name": "Overclock", "archetype": Archetype.BUFF_SELF,
		"description": "Overclock your staff, casting far faster for a moment.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 4.0, "duration_per_rank": 0.5,
		"buff_stats": {"attack_interval_mult": 0.6, "movement_speed_mult": 1.15}, "target_scope": "self",
	},
	"arclight_paralyzing_bolt": {
		"name": "Paralyzing Bolt", "archetype": Archetype.NUKE_BOLT,
		"description": "A slow bolt that paralyzes every foe caught in the blast.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 5.0,
		"power_base": 22.0, "power_per_rank": 6.0, "range": 560.0,
		"stun_on_hit": {"duration": 1.1},
	},
	"arclight_ball_lightning": {
		"name": "Ball Lightning", "archetype": Archetype.DASH_STRIKE,
		"description": "Become a bolt and streak forward, scorching everything you pass.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 34.0, "power_per_rank": 9.0, "dash_distance": 320.0, "radius": 60.0,
	},
	"arclight_volt_siphon": {
		"name": "Volt Siphon", "archetype": Archetype.NUKE_BOLT,
		"description": "Drain current from every enemy in the blast back into yourself.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 560.0, "lifesteal_pct": 0.5,
	},
	"arclight_track": {
		"name": "Track", "archetype": Archetype.NUKE_BOLT,
		"description": "Mark every enemy in the blast, exposing them to extra damage.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 16.0, "power_per_rank": 4.0, "range": 640.0,
		"mark_on_hit": {"bonus_pct": 0.25, "duration": 4.0},
	},
	"arclight_repulsor_field": {
		"name": "Repulsor Field", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Blast nearby enemies away from you.",
		"cooldown_base": 10.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.0,
		"power_base": -380.0, "power_per_rank": -40.0, "range": 0.0, "radius": 190.0,
	},
	"arclight_second_wind": {
		"name": "Vital Surge", "archetype": Archetype.SELF_HEAL,
		"description": "Catch your breath and mend your wounds.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.4, "cooldown_min": 8.0,
		"power_base": 30.0, "power_per_rank": 9.0,
	},
	# --- Bulwark --------------------------------------------------------------------------
	"bulwark_shockwave_strike": {
		"name": "Shockwave Strike", "archetype": Archetype.NUKE_BOLT,
		"description": "Slam the ground in front of you with a short-range shockwave.",
		"cooldown_base": 4.0, "cooldown_per_rank": -0.4, "cooldown_min": 2.2,
		"power_base": 40.0, "power_per_rank": 11.0, "range": 220.0,
	},
	"bulwark_ground_slam": {
		"name": "Ground Slam", "archetype": Archetype.RADIUS_BURST,
		"description": "Crack the earth around you in every direction.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 34.0, "power_per_rank": 9.0, "range": 0.0, "radius": 190.0,
	},
	"bulwark_cleave": {
		"name": "Cleave", "archetype": Archetype.CONE_BURST,
		"description": "A wide hammer swing through everything in front of you.",
		"cooldown_base": 4.5, "cooldown_per_rank": -0.4, "cooldown_min": 2.6,
		"power_base": 32.0, "power_per_rank": 9.0, "radius": 190.0,
	},
	"bulwark_iron_charge": {
		"name": "Iron Charge", "archetype": Archetype.DASH_STRIKE,
		"description": "Charge forward, trampling anything in your path.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 5.0,
		"power_base": 38.0, "power_per_rank": 10.0, "dash_distance": 280.0, "radius": 70.0,
	},
	"bulwark_fortify": {
		"name": "Fortify", "archetype": Archetype.SHIELD_BURST,
		"description": "Brace behind a wall of raw plating.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 60.0, "power_per_rank": 16.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"bulwark_provoke": {
		"name": "Provoke", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Bellow a challenge that drags nearby enemies toward you.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 340.0, "power_per_rank": 35.0, "range": 0.0, "radius": 220.0,
	},
	"bulwark_last_stand": {
		"name": "Last Stand", "archetype": Archetype.BUFF_SELF,
		"description": "Dig in — damage barely fazes you for a moment.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 4.5, "duration_per_rank": 0.5,
		"buff_stats": {"damage_taken_mult": 0.55, "movement_speed_mult": 1.2}, "target_scope": "self",
	},
	"bulwark_aftershock": {
		"name": "Aftershock", "archetype": Archetype.NUKE_BOLT,
		"description": "A follow-up quake that staggers every foe caught inside.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 24.0, "power_per_rank": 6.0, "range": 200.0,
		"stun_on_hit": {"duration": 1.0},
	},
	"bulwark_second_wind": {
		"name": "Iron Recovery", "archetype": Archetype.SELF_HEAL,
		"description": "Grit your teeth and shrug off the pain.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 7.5,
		"power_base": 45.0, "power_per_rank": 12.0,
	},
	"bulwark_rallying_warcry": {
		"name": "Rallying Warcry", "archetype": Archetype.AOE_HEAL,
		"description": "Rally the party, mending everyone close by.",
		"cooldown_base": 10.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.0,
		"power_base": 22.0, "power_per_rank": 6.0, "range": 0.0, "radius": 230.0,
	},
	"bulwark_retribution": {
		"name": "Retribution", "archetype": Archetype.BUFF_SELF,
		"description": "Coat your armour in barbs that punish attackers.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 4.0, "duration_per_rank": 0.5,
		"buff_stats": {"reflect_pct": 0.4}, "target_scope": "self",
	},
	"bulwark_sunder": {
		"name": "Sunder", "archetype": Archetype.NUKE_BOLT,
		"description": "Crack every defence in a wide area wide open.",
		"cooldown_base": 9.5, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 18.0, "power_per_rank": 5.0, "range": 230.0,
		"mark_on_hit": {"bonus_pct": 0.3, "duration": 4.5},
	},
	# --- Warden -----------------------------------------------------------------------------
	"warden_vine_lash": {
		"name": "Vine Lash", "archetype": Archetype.NUKE_BOLT,
		"description": "Whip barbed vines through every enemy in range.",
		"cooldown_base": 4.2, "cooldown_per_rank": -0.4, "cooldown_min": 2.4,
		"power_base": 26.0, "power_per_rank": 7.0, "range": 520.0,
	},
	"warden_mending_wave": {
		"name": "Mending Wave", "archetype": Archetype.AOE_HEAL,
		"description": "Send out a wave of restorative light to the whole party.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 0.0, "radius": 260.0,
	},
	"warden_thorn_volley": {
		"name": "Thorn Volley", "archetype": Archetype.CHAIN_NUKE,
		"description": "Loose a volley of thorns that skips between enemies.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.6,
		"power_base": 24.0, "power_per_rank": 6.0, "range": 520.0,
		"chain_count": 3, "chain_range": 200.0,
	},
	"warden_entangle": {
		"name": "Entangle", "archetype": Archetype.NUKE_BOLT,
		"description": "Roots burst from the ground to hold every foe in the area fast.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 5.0,
		"power_base": 14.0, "power_per_rank": 4.0, "range": 480.0,
		"stun_on_hit": {"duration": 1.2},
	},
	"warden_natures_grasp": {
		"name": "Nature's Grasp", "archetype": Archetype.RADIUS_BURST,
		"description": "Choking vines slow everything in the area.",
		"cooldown_base": 7.5, "cooldown_per_rank": -0.7, "cooldown_min": 4.2,
		"power_base": 10.0, "power_per_rank": 3.0, "range": 380.0, "radius": 170.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.2},
	},
	"warden_verdant_ward": {
		"name": "Verdant Ward", "archetype": Archetype.SHIELD_BURST,
		"description": "Wrap the party in a barrier of living wood.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 0.0, "radius": 220.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "allies",
	},
	"warden_rising_choir": {
		"name": "Battle Hymn", "archetype": Archetype.BUFF_SELF,
		"description": "Lend the whole party a surge of striking power.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 0.0, "power_per_rank": 0.0, "radius": 240.0,
		"duration_base": 4.5, "duration_per_rank": 0.5,
		"buff_stats": {"damage_dealt_mult": 1.2}, "target_scope": "allies",
	},
	"warden_vine_step": {
		"name": "Vine Step", "archetype": Archetype.BLINK,
		"description": "Ride a vine to close the distance to an ally.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 0.0, "power_per_rank": 0.0, "dash_distance": 280.0,
	},
	"warden_natures_wrath": {
		"name": "Nature's Wrath", "archetype": Archetype.NUKE_BOLT,
		"description": "Curse every enemy in the blast, leaving them exposed to harm.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 16.0, "power_per_rank": 4.0, "range": 500.0,
		"mark_on_hit": {"bonus_pct": 0.25, "duration": 4.0},
	},
	"warden_second_bloom": {
		"name": "Second Bloom", "archetype": Archetype.SELF_HEAL,
		"description": "Draw on the grove's vitality to heal yourself.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 34.0, "power_per_rank": 9.0,
	},
	"warden_vital_drain": {
		"name": "Vital Drain", "archetype": Archetype.NUKE_BOLT,
		"description": "Siphon vitality from every foe in the blast back into your own.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.8,
		"power_base": 20.0, "power_per_rank": 5.0, "range": 480.0, "lifesteal_pct": 0.6,
	},
	"warden_bramble_wall": {
		"name": "Bramble Wall", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Raise a wall of thorns that shoves enemies back.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 6.0,
		"power_base": -300.0, "power_per_rank": -30.0, "range": 0.0, "radius": 200.0,
	},
	# --- Frostbinder --------------------------------------------------------------------------
	"frostbinder_ice_spike": {
		"name": "Ice Spike", "archetype": Archetype.NUKE_BOLT,
		"description": "Launch a razor-sharp spike of ice.",
		"cooldown_base": 3.8, "cooldown_per_rank": -0.4, "cooldown_min": 2.0,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 500.0,
	},
	"frostbinder_frost_nova": {
		"name": "Frost Nova", "archetype": Archetype.RADIUS_BURST,
		"description": "A ring of frost erupts from your feet.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 26.0, "power_per_rank": 7.0, "range": 0.0, "radius": 170.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.4},
	},
	"frostbinder_glacial_cone": {
		"name": "Glacial Cone", "archetype": Archetype.CONE_BURST,
		"description": "Breathe a cone of freezing wind.",
		"cooldown_base": 5.5, "cooldown_per_rank": -0.5, "cooldown_min": 3.0,
		"power_base": 24.0, "power_per_rank": 6.0, "radius": 240.0,
		"slow_on_hit": {"factor": 0.55, "duration": 2.0},
	},
	"frostbinder_deep_freeze": {
		"name": "Glacial Lock", "archetype": Archetype.NUKE_BOLT,
		"description": "Encase every enemy in the blast in solid ice.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 20.0, "power_per_rank": 5.0, "range": 460.0,
		"stun_on_hit": {"duration": 1.3},
	},
	"frostbinder_shatter_chain": {
		"name": "Shatter Chain", "archetype": Archetype.CHAIN_NUKE,
		"description": "A shard of ice that shatters between enemies.",
		"cooldown_base": 6.8, "cooldown_per_rank": -0.6, "cooldown_min": 3.8,
		"power_base": 26.0, "power_per_rank": 7.0, "range": 500.0,
		"chain_count": 3, "chain_range": 210.0,
	},
	"frostbinder_frost_step": {
		"name": "Frost Step", "archetype": Archetype.BLINK,
		"description": "Turn to mist and reform a short distance away.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 0.0, "power_per_rank": 0.0, "dash_distance": 290.0,
	},
	"frostbinder_permafrost": {
		"name": "Permafrost", "archetype": Archetype.SHIELD_BURST,
		"description": "Armour yourself in a shell of packed ice.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 50.0, "power_per_rank": 13.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"frostbinder_vortex": {
		"name": "Vortex", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "A freezing vortex hauls enemies into a cluster.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 320.0, "power_per_rank": 32.0, "range": 0.0, "radius": 210.0,
	},
	"frostbinder_chilling_clarity": {
		"name": "Chilling Clarity", "archetype": Archetype.BUFF_SELF,
		"description": "Cold focus sharpens your casting and footwork.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 4.5, "duration_per_rank": 0.5,
		"buff_stats": {"attack_interval_mult": 0.7, "movement_speed_mult": 1.2}, "target_scope": "self",
	},
	"frostbinder_rime_barrage": {
		"name": "Rime Barrage", "archetype": Archetype.DASH_STRIKE,
		"description": "Skate forward on ice, lancing everything you pass.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 4.8,
		"power_base": 30.0, "power_per_rank": 8.0, "dash_distance": 300.0, "radius": 60.0,
	},
	"frostbinder_frostbite_mark": {
		"name": "Frostbite Mark", "archetype": Archetype.NUKE_BOLT,
		"description": "Bitter cold clings to every foe in the blast, deepening any wound.",
		"cooldown_base": 9.5, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 16.0, "power_per_rank": 4.0, "range": 480.0,
		"mark_on_hit": {"bonus_pct": 0.3, "duration": 4.5},
	},
	"frostbinder_absolute_zero": {
		"name": "Absolute Zero", "archetype": Archetype.RADIUS_BURST,
		"description": "Call down a devastating pocket of absolute cold.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 42.0, "power_per_rank": 11.0, "range": 420.0, "radius": 200.0,
		"slow_on_hit": {"factor": 0.35, "duration": 3.0},
	},
}


static func ids() -> Array[String]:
	var class_ids: Array[String] = []
	for class_data in CLASSES:
		class_ids.append(class_data.id)
	return class_ids


static func playable_ids() -> Array[String]:
	return ["tobor", "arclight", "bulwark", "warden"]


static func cpu_ally_ids(human_class_id: String) -> Array[String]:
	var taken := sanitize_id(human_class_id)
	var allies: Array[String] = []
	for class_id in playable_ids():
		if class_id != taken:
			allies.append(class_id)
	return allies


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


static func ability_pool_for(class_id: String) -> Array[String]:
	var pool: Array[String] = []
	for ability_id in by_id(class_id).ability_pool:
		pool.append(ability_id)
	return pool


static func ability_info(ability_id: String) -> Dictionary:
	return ABILITIES.get(ability_id, {})


## The offer shown on an "ability" level-up: always up to `amount` (4) choices — one
## guaranteed upgrade slot for every ability already known (that still has rank to give), and
## the rest filled with random not-yet-known abilities from the same hero pool. So with 0
## known it's 4 fresh picks; with 1 known it's that ability to upgrade plus 3 fresh picks;
## with all 4 known (the cap) it's always all 4 up for a rank. Whether a given id in the
## result is a "learn" or an "upgrade" is resolved at pick time by checking membership in the
## player's known_abilities — the caller doesn't need a separate tag per candidate.
static func ability_offer_ids(class_id: String, known: Array[Dictionary], amount: int = 4) -> Array[String]:
	var known_ids: Array[String] = []
	var upgrade_candidates: Array[String] = []
	for entry in known:
		var ability_id := str(entry.id)
		known_ids.append(ability_id)
		if int(entry.get("rank", 1)) < MAX_ABILITY_RANK:
			upgrade_candidates.append(ability_id)

	var new_pool: Array[String] = []
	if known.size() < MAX_KNOWN_ABILITIES:
		for ability_id in ability_pool_for(class_id):
			if ability_id not in known_ids:
				new_pool.append(ability_id)
	new_pool.shuffle()

	var result := upgrade_candidates.duplicate()
	var new_slots_needed := maxi(0, amount - result.size())
	result.append_array(new_pool.slice(0, new_slots_needed))
	return result


## Scales an ability's numbers for the given rank (1-based). Every field grows with rank —
## cooldown/power/duration linearly from their per-ability authored rates, radius/range/dash
## distance by a flat percentage per rank, and chain count by +1 every couple of ranks — so a
## rank-5 ability is a visibly bigger, more dangerous version of its rank-1 self, not just a
## faster-cycling one.
static func ability_values(ability_id: String, rank: int) -> Dictionary:
	var data := ability_info(ability_id)
	var steps := maxi(0, rank - 1)
	var cooldown := maxf(
		float(data.get("cooldown_min", 1.0)) * ABILITY_COOLDOWN_MIN_MULTIPLIER,
		float(data.get("cooldown_base", 5.0)) * ABILITY_COOLDOWN_BASE_MULTIPLIER
			+ float(data.get("cooldown_per_rank", 0.0)) * ABILITY_COOLDOWN_PER_RANK_MULTIPLIER * steps
	)
	var power := (float(data.get("power_base", 0.0)) + float(data.get("power_per_rank", 0.0)) * steps) * ABILITY_POWER_MULTIPLIER
	var duration := float(data.get("duration_base", 0.0)) + float(data.get("duration_per_rank", 0.0)) * steps
	var radius := float(data.get("radius", 0.0))
	if radius <= 0.0:
		radius = _default_radius_for(int(data.archetype), data)
	radius *= AOE_RADIUS_MULTIPLIER * (1.0 + ABILITY_RADIUS_GROWTH_PER_RANK * steps)
	var range_value := float(data.get("range", 0.0)) * (1.0 + ABILITY_RANGE_GROWTH_PER_RANK * steps)
	var dash_distance := float(data.get("dash_distance", 0.0)) * (1.0 + ABILITY_DASH_GROWTH_PER_RANK * steps)
	var chain_count := int(data.get("chain_count", 0))
	if chain_count > 0:
		chain_count += int(steps / ABILITY_CHAIN_RANKS_PER_BONUS)
	var footprint := aoe_footprint(data, radius, dash_distance, chain_count, float(data.get("chain_range", 0.0)))
	cooldown *= cooldown_scale_for_footprint(footprint)
	return {
		"cooldown": cooldown,
		"power": power,
		"duration": duration,
		"range": range_value,
		"radius": radius,
		"dash_distance": dash_distance,
		"chain_count": chain_count,
		"footprint": footprint,
	}


static func _default_radius_for(archetype: int, data: Dictionary) -> float:
	match archetype:
		Archetype.NUKE_BOLT:
			return 165.0
		Archetype.CHAIN_NUKE:
			return 155.0
		Archetype.BLINK:
			return 140.0
		Archetype.SELF_HEAL:
			return 185.0
		Archetype.BUFF_SELF:
			return 220.0 if str(data.get("target_scope", "self")) == "allies" else 170.0
		Archetype.SHIELD_BURST:
			return 190.0 if str(data.get("target_scope", "self")) == "self" else 250.0
		_:
			return 0.0


## One number that approximates how much ground an ability covers, for cooldown tuning.
static func aoe_footprint(data: Dictionary, radius: float, dash_distance: float, chain_count: int, chain_range: float) -> float:
	match int(data.archetype):
		Archetype.CONE_BURST, Archetype.RADIUS_BURST, Archetype.NUKE_BOLT, Archetype.PUSH_PULL_BURST, Archetype.AOE_HEAL:
			return radius
		Archetype.CHAIN_NUKE:
			return radius + chain_range * maxf(1.0, float(chain_count)) * 0.22
		Archetype.DASH_STRIKE:
			return dash_distance * 0.55 + radius
		Archetype.BLINK:
			return maxf(radius, dash_distance * 0.35)
		Archetype.SELF_HEAL, Archetype.BUFF_SELF, Archetype.SHIELD_BURST:
			return radius
		_:
			return radius


static func cooldown_scale_for_footprint(footprint: float) -> float:
	var t := clampf(
		(footprint - AOE_COOLDOWN_FOOTPRINT_MIN) / maxf(1.0, AOE_COOLDOWN_FOOTPRINT_MAX - AOE_COOLDOWN_FOOTPRINT_MIN),
		0.0,
		1.0
	)
	return lerpf(AOE_COOLDOWN_SCALE_MIN, AOE_COOLDOWN_SCALE_MAX, t)


static func _modifier_description(data: Dictionary) -> String:
	var parts: Array[String] = []
	if data.has("stun_on_hit"):
		parts.append("Stuns for %.1fs" % float(data.stun_on_hit.duration))
	if data.has("slow_on_hit"):
		parts.append("Slows by %d%% for %.1fs" % [int((1.0 - float(data.slow_on_hit.factor)) * 100.0), float(data.slow_on_hit.duration)])
	if data.has("mark_on_hit"):
		parts.append("Marks for +%d%% damage taken for %.1fs" % [int(float(data.mark_on_hit.bonus_pct) * 100.0), float(data.mark_on_hit.duration)])
	if data.has("lifesteal_pct"):
		parts.append("Heals you for %d%% of the damage dealt" % int(float(data.lifesteal_pct) * 100.0))
	return "  ".join(parts)


## Short, numbers-included description for a level-up choice card, at the rank it would be
## cast at if picked/upgraded right now.
static func ability_description(ability_id: String, rank: int) -> String:
	var data := ability_info(ability_id)
	if data.is_empty():
		return ""
	var values := ability_values(ability_id, rank)
	var effect := ""
	match int(data.archetype):
		Archetype.NUKE_BOLT:
			effect = "Deals %d damage in a %d radius blast. Cooldown %.1fs." % [int(values.power), int(values.radius), values.cooldown]
		Archetype.CONE_BURST, Archetype.RADIUS_BURST:
			effect = "Deals %d damage in a %d radius area. Cooldown %.1fs." % [int(values.power), int(values.radius), values.cooldown]
		Archetype.CHAIN_NUKE:
			effect = "Deals %d damage in %d chained blasts (radius %d). Cooldown %.1fs." % [int(values.power), int(values.chain_count), int(values.radius), values.cooldown]
		Archetype.DASH_STRIKE:
			effect = "Dash %d units through a %d radius corridor. Cooldown %.1fs." % [int(values.dash_distance), int(values.radius), values.cooldown]
		Archetype.BLINK:
			effect = "Blink %d units, detonating a %d radius on landing. Cooldown %.1fs." % [int(values.dash_distance), int(values.radius), values.cooldown]
		Archetype.SELF_HEAL:
			effect = "Heals you for %d and purges enemies within %d. Cooldown %.1fs." % [int(values.power), int(values.radius), values.cooldown]
		Archetype.AOE_HEAL:
			effect = "Heals you and nearby allies for %d. Cooldown %.1fs." % [int(values.power), values.cooldown]
		Archetype.SHIELD_BURST:
			var scope := "you" if data.get("target_scope", "self") == "self" else "you and nearby allies"
			effect = "Shields %s for %d, lasting %.1fs. Cooldown %.1fs." % [scope, int(values.power), values.duration, values.cooldown]
		Archetype.BUFF_SELF:
			var buff_scope := "you" if data.get("target_scope", "self") == "self" else "you and nearby allies"
			effect = "Empowers %s for %.1fs. Cooldown %.1fs." % [buff_scope, values.duration, values.cooldown]
		Archetype.PUSH_PULL_BURST:
			var verb := "Pulls" if float(data.get("power_base", 0.0)) > 0.0 else "Knocks back"
			effect = "%s nearby enemies. Cooldown %.1fs." % [verb, values.cooldown]
	var modifier_text := _modifier_description(data)
	var lines: Array[String] = [str(data.name), str(data.description), effect]
	if not modifier_text.is_empty():
		lines.append(modifier_text)
	return "\n".join(lines)

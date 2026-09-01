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
		"name": "Wrench",
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
		"kit_q": "tobor_steam_keg",
		"kit_e": "tobor_steam_turret",
		"kit_r": "tobor_energy_field",
		"ability_pool": [
			"tobor_steam_keg", "tobor_steam_turret", "tobor_energy_field", "tobor_energy_absorption",
			"tobor_keg_lob", "tobor_turret_overdrive", "tobor_scrap_shield", "tobor_boiler_burst",
			"tobor_wrench_toss", "tobor_repair_pulse", "tobor_steam_vent", "tobor_ironclad_chassis",
		],
	},
	{
		"id": "arclight",
		"name": "Joule",
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
		"kit_q": "arclight_blast_of_lightning",
		"kit_e": "arclight_chain_lightning",
		"kit_r": "arclight_thundergods_wrath",
		"ability_pool": [
			"arclight_blast_of_lightning", "arclight_chain_lightning", "arclight_thundergods_wrath",
			"arclight_static_bolt", "arclight_overcharge", "arclight_ion_storm",
			"arclight_arc_flash", "arclight_thunder_step", "arclight_paralyzing_bolt",
			"arclight_ball_lightning", "arclight_repulsor_field", "arclight_second_wind",
		],
	},
	{
		"id": "bulwark",
		"name": "Tremor",
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
		"kit_q": "bulwark_fissure",
		"kit_e": "bulwark_heavyweight",
		"kit_r": "bulwark_echo_slam",
		"ability_pool": [
			"bulwark_fissure", "bulwark_heavyweight", "bulwark_echo_slam",
			"bulwark_shockwave_strike", "bulwark_ground_slam", "bulwark_cleave",
			"bulwark_iron_charge", "bulwark_fortify", "bulwark_provoke",
			"bulwark_last_stand", "bulwark_aftershock", "bulwark_sunder",
		],
	},
	{
		"id": "warden",
		"name": "Totem",
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
		"kit_q": "warden_tongue_tied",
		"kit_e": "warden_voodoo_wards",
		"kit_r": "warden_life_drain",
		"ability_pool": [
			"warden_tongue_tied", "warden_voodoo_wards", "warden_life_drain",
			"warden_mending_wave", "warden_thorn_volley", "warden_entangle",
			"warden_natures_grasp", "warden_verdant_ward", "warden_rising_choir",
			"warden_vine_step", "warden_vital_drain", "warden_bramble_wall",
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
	# --- Caldera world heroes ---
	{
		"id": "cinder",
		"name": "Blaze",
		"role": "Blaster",
		"menu_bg": "",
		"weapon_name": "Pyro Staff",
		"description": "Pyromancer cast out of the Foundry. Chains fire through packed enemies and dashes in a blaze.",
		"counters": "Strong vs swarms  ·  Weak vs brutes",
		"damage_type": DamageType.LIGHTNING,
		"weapon": Weapon.CHAIN_BOLT,
		"effect_style": EffectStyle.BLAST,
		"body_color": "c94a20",
		"accent_color": "ffd36b",
		"effect_color": "ffb347",
		"effect_secondary": "e0452a",
		"health_bar_color": "ff7a30",
		"max_health": 90.0,
		"movement_speed": 320.0,
		"attack_interval": 0.7,
		"weapon_damage": 16.0,
		"attack_range": 620.0,
		"aim_assist_radius": 84.0,
		"chain_count": 1,
		"chain_range": 190.0,
		"damage_taken_multiplier": 1.1,
		"taunt_weight": 1.0,
		"secondary": "repulse",
		"secondary_cooldown": 9.0,
		"upgrades": ["rapid", "heavy", "chain", "vitality"],
		"kit_q": "cinder_dragon_fire",
		"kit_e": "cinder_fiery_assault",
		"kit_r": "cinder_pillar_of_flame",
		"ability_pool": [
			"cinder_dragon_fire", "cinder_fiery_assault", "cinder_pillar_of_flame",
			"cinder_whirling_flame", "cinder_firebomb", "cinder_scorch",
			"cinder_ignite", "cinder_combustion_wave", "cinder_flame_dash",
			"cinder_magma_armor", "cinder_heat_surge", "cinder_pyroclasm",
		],
	},
	{
		"id": "pyra",
		"name": "Barrage",
		"role": "DPS Ranger",
		"menu_bg": "",
		"weapon_name": "Mortar Lance",
		"description": "Artillery dragon of the caldera. Lobs ordnance over the field and calls down sky strikes.",
		"counters": "Strong vs clusters and fortifications  ·  Weak vs flankers",
		"damage_type": DamageType.IMPACT,
		"weapon": Weapon.FROST_SHARD,
		"effect_style": EffectStyle.BURST,
		"body_color": "8a3d2a",
		"accent_color": "ffe14a",
		"effect_color": "ff8a5c",
		"effect_secondary": "ffd36b",
		"health_bar_color": "e4653a",
		"max_health": 110.0,
		"movement_speed": 310.0,
		"attack_interval": 0.8,
		"weapon_damage": 18.0,
		"attack_range": 640.0,
		"aim_assist_radius": 88.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.05,
		"taunt_weight": 1.0,
		"secondary": "repulse",
		"secondary_cooldown": 9.0,
		"upgrades": ["rapid", "heavy", "blast", "vitality"],
		"kit_q": "pyra_sticky_bomb",
		"kit_e": "pyra_boom_dust",
		"kit_r": "pyra_air_strike",
		"ability_pool": [
			"pyra_sticky_bomb", "pyra_boom_dust", "pyra_bombardment", "pyra_air_strike",
			"pyra_fireball", "pyra_meteor", "pyra_scorch_mark", "pyra_flame_wall",
			"pyra_molten_charge", "pyra_heat_shield", "pyra_rock_throw", "pyra_volcano",
		],
	},
	{
		"id": "slag",
		"name": "Vulcan",
		"role": "Bulldozer",
		"menu_bg": "",
		"weapon_name": "Magma Fists",
		"description": "A walking volcano. Plows through the frontline and reshapes the ground itself.",
		"counters": "Strong vs armour and brutes  ·  Weak vs fliers",
		"damage_type": DamageType.IMPACT,
		"weapon": Weapon.CONE_SLAM,
		"effect_style": EffectStyle.ARC,
		"body_color": "5c2e1e",
		"accent_color": "ff8a3d",
		"effect_color": "ff6b2a",
		"effect_secondary": "ffc46b",
		"health_bar_color": "c94a20",
		"max_health": 200.0,
		"movement_speed": 240.0,
		"attack_interval": 1.0,
		"weapon_damage": 20.0,
		"attack_range": 130.0,
		"aim_assist_radius": 120.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.75,
		"taunt_weight": 0.5,
		"secondary": "wall",
		"secondary_cooldown": 12.0,
		"upgrades": ["plating", "reach", "sweep", "heavy", "vitality"],
		"kit_q": "slag_steam_bath",
		"kit_e": "slag_volcanic_touch",
		"kit_r": "slag_eruption",
		"ability_pool": [
			"slag_steam_bath", "slag_volcanic_touch", "slag_lava_surge", "slag_eruption",
			"slag_magma_charge", "slag_earthen_slam", "slag_basalt_armour", "slag_lava_wall",
			"slag_seismic_ring", "slag_boulder_hurl", "slag_molten_skin", "slag_geysers",
		],
	},
	{
		"id": "ember",
		"name": "Witchfire",
		"role": "Support Bruiser",
		"menu_bg": "",
		"weapon_name": "Cinder Scepter",
		"description": "Plague-witch of the ash wastes. Mends allies with warm currents and roots foes in bramble-fire.",
		"counters": "Strong vs hexers  ·  Weak vs assassins",
		"damage_type": DamageType.NATURE,
		"weapon": Weapon.MENDING_BOLT,
		"effect_style": EffectStyle.WAVE,
		"body_color": "b3542e",
		"accent_color": "8cff4a",
		"effect_color": "ffb46b",
		"effect_secondary": "8cff4a",
		"health_bar_color": "d98a3c",
		"max_health": 150.0,
		"movement_speed": 300.0,
		"attack_interval": 0.6,
		"weapon_damage": 12.0,
		"attack_range": 520.0,
		"aim_assist_radius": 92.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.95,
		"taunt_weight": 1.15,
		"secondary": "freeze",
		"secondary_cooldown": 10.0,
		"upgrades": ["flow", "lash", "heavy", "vitality"],
		"kit_q": "ember_entangle",
		"kit_e": "ember_healing_wave",
		"kit_r": "ember_unbreakable",
		"ability_pool": [
			"ember_entangle", "ember_healing_wave", "ember_storm_cloud", "ember_unbreakable",
			"ember_firebomb", "ember_mending_flame", "ember_spark_volley", "ember_phoenix_dash",
			"ember_heat_vent", "ember_burning_aura", "ember_cinder_shield", "ember_flamebreak",
		],
	},
	# --- Verdant world heroes ---
	{
		"id": "thorn",
		"name": "Venom",
		"role": "DOT Caster",
		"menu_bg": "",
		"weapon_name": "Acid Sprayer",
		"description": "Witch of the deep jungle. Sprays virulent toxins and grows wards that spit poison.",
		"counters": "Strong vs hexers and brutes  ·  Weak vs fliers",
		"damage_type": DamageType.NATURE,
		"weapon": Weapon.MENDING_BOLT,
		"effect_style": EffectStyle.WAVE,
		"body_color": "4a7a2e",
		"accent_color": "d9ff8a",
		"effect_color": "a8e05c",
		"effect_secondary": "e8ff9a",
		"health_bar_color": "6aa83c",
		"max_health": 115.0,
		"movement_speed": 300.0,
		"attack_interval": 0.6,
		"weapon_damage": 13.0,
		"attack_range": 500.0,
		"aim_assist_radius": 90.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.05,
		"taunt_weight": 1.0,
		"secondary": "freeze",
		"secondary_cooldown": 10.0,
		"upgrades": ["flow", "lash", "heavy", "vitality"],
		"kit_q": "thorn_poison_spray",
		"kit_e": "thorn_toxin_ward",
		"kit_r": "thorn_poison_burst",
		"ability_pool": [
			"thorn_poison_spray", "thorn_toxin_ward", "thorn_toxicity", "thorn_poison_burst",
			"thorn_vine_lash", "thorn_toxic_cloud", "thorn_thorn_armour", "thorn_venom_strike",
			"thorn_bramble_dash", "thorn_root_tangle", "thorn_spore_burst", "thorn_ambush",
		],
	},
	{
		"id": "willow",
		"name": "Flick",
		"role": "Carry Archer",
		"menu_bg": "",
		"weapon_name": "Thorn Bow",
		"description": "Forest ranger with impossible aim. Strikes swift, shoots far, and vanishes into the green.",
		"counters": "Strong vs squishies  ·  Weak vs armour",
		"damage_type": DamageType.LIGHTNING,
		"weapon": Weapon.CHAIN_BOLT,
		"effect_style": EffectStyle.BOLT,
		"body_color": "6b5a3a",
		"accent_color": "b8ff6b",
		"effect_color": "d4ff8f",
		"effect_secondary": "7de84a",
		"health_bar_color": "8ee04a",
		"max_health": 95.0,
		"movement_speed": 330.0,
		"attack_interval": 0.65,
		"weapon_damage": 17.0,
		"attack_range": 660.0,
		"aim_assist_radius": 82.0,
		"chain_count": 1,
		"chain_range": 200.0,
		"damage_taken_multiplier": 1.1,
		"taunt_weight": 1.0,
		"secondary": "volt_mend",
		"secondary_cooldown": 10.0,
		"upgrades": ["rapid", "heavy", "boots", "vitality"],
		"kit_q": "willow_swift_strike",
		"kit_e": "willow_forsaken_shot",
		"kit_r": "willow_wall_of_roots",
		"ability_pool": [
			"willow_swift_strike", "willow_forsaken_shot", "willow_volley", "willow_wall_of_roots",
			"willow_briar_jab", "willow_seed_bomb", "willow_thorn_snare", "willow_shadow_step",
			"willow_spore_volley", "willow_vital_strike", "willow_briar_wall", "willow_final_bloom",
		],
	},
	{
		"id": "stump",
		"name": "Keeper",
		"role": "Fort Support Tank",
		"menu_bg": "",
		"weapon_name": "Bark Bulwark",
		"description": "A walking tree-fort. Rallies the party behind living bark and buries foes in overgrowth.",
		"counters": "Strong vs swarms  ·  Weak vs fire",
		"damage_type": DamageType.IMPACT,
		"weapon": Weapon.CONE_SLAM,
		"effect_style": EffectStyle.ARC,
		"body_color": "7a5a30",
		"accent_color": "d4b06b",
		"effect_color": "c49a55",
		"effect_secondary": "8cff4a",
		"health_bar_color": "a8894c",
		"max_health": 210.0,
		"movement_speed": 230.0,
		"attack_interval": 1.1,
		"weapon_damage": 10.0,
		"attack_range": 140.0,
		"aim_assist_radius": 122.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.72,
		"taunt_weight": 0.45,
		"secondary": "wall",
		"secondary_cooldown": 12.0,
		"upgrades": ["plating", "reach", "sweep", "flow", "vitality"],
		"kit_q": "stump_natures_rally",
		"kit_e": "stump_camouflage",
		"kit_r": "stump_overgrowth",
		"ability_pool": [
			"stump_natures_rally", "stump_camouflage", "stump_natures_veil", "stump_overgrowth",
			"stump_trunk_slam", "stump_root_charge", "stump_barkskin", "stump_wall",
			"stump_living_seed", "stump_heartwood", "stump_wildgrowth", "stump_fortress_grove",
		],
	},
	{
		"id": "sage",
		"name": "Nymphel",
		"role": "Healer",
		"menu_bg": "",
		"weapon_name": "Moon Blossom",
		"description": "Nymph of the glades. Showers the party in grace and charms predators out of the fight.",
		"counters": "Strong vs hexers and overconfident carries",
		"damage_type": DamageType.NATURE,
		"weapon": Weapon.MENDING_BOLT,
		"effect_style": EffectStyle.WAVE,
		"body_color": "6b4a1e",
		"accent_color": "ffd9e0",
		"effect_color": "ffe3ec",
		"effect_secondary": "9fe6a0",
		"health_bar_color": "e8a1b2",
		"max_health": 130.0,
		"movement_speed": 310.0,
		"attack_interval": 0.6,
		"weapon_damage": 10.0,
		"attack_range": 540.0,
		"aim_assist_radius": 98.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.95,
		"taunt_weight": 1.3,
		"hovering": true,
		"secondary": "freeze",
		"secondary_cooldown": 10.0,
		"upgrades": ["flow", "lash", "boots", "vitality"],
		"kit_q": "sage_grace",
		"kit_e": "sage_volatile_pod",
		"kit_r": "sage_charm",
		"ability_pool": [
			"sage_grace", "sage_volatile_pod", "sage_nymphoras_kiss", "sage_charm",
			"sage_healing_wave", "sage_lifeward", "sage_rejuvenate", "sage_natures_step",
			"sage_petal_dance", "sage_entangle", "sage_starfall", "sage_world_seed",
		],
	},
	# --- Storm world heroes ---
	{
		"id": "volt",
		"name": "Gale",
		"role": "Wind Controller",
		"menu_bg": "",
		"weapon_name": "Cyclone Rod",
		"description": "Tempest shaman. Herds enemies with gales and shepherds the party under a living wind shield.",
		"counters": "Strong vs melee packs  ·  Weak vs long range",
		"damage_type": DamageType.LIGHTNING,
		"weapon": Weapon.CHAIN_BOLT,
		"effect_style": EffectStyle.BOLT,
		"body_color": "e8e8e8",
		"accent_color": "7af0ff",
		"effect_color": "b0e8ff",
		"effect_secondary": "ffe14a",
		"health_bar_color": "4ad0e8",
		"max_health": 110.0,
		"movement_speed": 320.0,
		"attack_interval": 0.7,
		"weapon_damage": 15.0,
		"attack_range": 620.0,
		"aim_assist_radius": 86.0,
		"chain_count": 1,
		"chain_range": 190.0,
		"damage_taken_multiplier": 1.05,
		"taunt_weight": 1.0,
		"secondary": "volt_mend",
		"secondary_cooldown": 10.0,
		"upgrades": ["rapid", "chain", "heavy", "vitality"],
		"kit_q": "volt_gust",
		"kit_e": "volt_wind_shield",
		"kit_r": "volt_typhoon",
		"ability_pool": [
			"volt_gust", "volt_wind_shield", "volt_wind_control", "volt_typhoon",
			"volt_plasma_bolt", "volt_electroshock", "volt_lightning_lunge", "volt_voltaic_cage",
			"volt_electro_dash", "volt_static_drain", "volt_repulsor_blast", "volt_amp_field",
		],
	},
	{
		"id": "nebula",
		"name": "Aeon",
		"role": "Time Manipulator",
		"menu_bg": "",
		"weapon_name": "Aeon Sphere",
		"description": "A shard of eternity let loose. Curves time around its foes and locks the whole arena in a chronosphere.",
		"counters": "Strong vs everything once ahead  ·  Weak early",
		"damage_type": DamageType.FROST,
		"weapon": Weapon.FROST_SHARD,
		"effect_style": EffectStyle.BURST,
		"body_color": "3a2a5c",
		"accent_color": "b48cff",
		"effect_color": "cbb0ff",
		"effect_secondary": "8a6dff",
		"health_bar_color": "8a6de0",
		"max_health": 120.0,
		"movement_speed": 305.0,
		"attack_interval": 0.75,
		"weapon_damage": 16.0,
		"attack_range": 580.0,
		"aim_assist_radius": 88.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.0,
		"taunt_weight": 1.1,
		"secondary": "volt_mend",
		"secondary_cooldown": 10.0,
		"upgrades": ["rapid", "heavy", "boots", "vitality"],
		"kit_q": "nebula_time_shift",
		"kit_e": "nebula_curse_of_ages",
		"kit_r": "nebula_chronofield",
		"ability_pool": [
			"nebula_time_shift", "nebula_curse_of_ages", "nebula_rewind", "nebula_chronofield",
			"nebula_frost_blast", "nebula_arcane_bolt", "nebula_cold_snap", "nebula_blink",
			"nebula_meteor_shower", "nebula_warp_field", "nebula_emp", "nebula_void_rift",
		],
	},
	{
		"id": "astral",
		"name": "Lumina",
		"role": "Beacon Support",
		"menu_bg": "",
		"weapon_name": "Star Lantern",
		"description": "A young moonlight given form. Threads the party together under a single guiding beacon.",
		"counters": "Strong vs hexers and summoners",
		"damage_type": DamageType.NATURE,
		"weapon": Weapon.MENDING_BOLT,
		"effect_style": EffectStyle.WAVE,
		"body_color": "d8dff0",
		"accent_color": "ffe9a0",
		"effect_color": "fff4c4",
		"effect_secondary": "d8e4ff",
		"health_bar_color": "f0d971",
		"max_health": 125.0,
		"movement_speed": 300.0,
		"attack_interval": 0.6,
		"weapon_damage": 10.0,
		"attack_range": 540.0,
		"aim_assist_radius": 97.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 0.95,
		"taunt_weight": 1.3,
		"hovering": true,
		"secondary": "freeze",
		"secondary_cooldown": 10.0,
		"upgrades": ["flow", "lash", "choir", "vitality"],
		"kit_q": "astral_essence_link",
		"kit_e": "astral_ward_of_light",
		"kit_r": "astral_as_one",
		"ability_pool": [
			"astral_essence_link", "astral_ward_of_light", "astral_spirit_bond", "astral_as_one",
			"astral_ghost_light", "astral_moonfall", "astral_luminous_ward", "astral_ethereal_link",
			"astral_bright_tether", "astral_ghastly_touch", "astral_wisp_nova", "astral_seance",
		],
	},
	{
		"id": "rime",
		"name": "Glacier",
		"role": "Frost Caster",
		"menu_bg": "",
		"weapon_name": "Absolute Zero",
		"description": "A glacier that chose to walk. Burial ice imprison foes and a blizzard ends the argument.",
		"counters": "Strong vs chargers  ·  Weak vs brutes",
		"damage_type": DamageType.FROST,
		"weapon": Weapon.FROST_SHARD,
		"effect_style": EffectStyle.BURST,
		"body_color": "b8d4ff",
		"accent_color": "3a5a8c",
		"effect_color": "cfe8ff",
		"effect_secondary": "7ba9ff",
		"health_bar_color": "7fb4f0",
		"max_health": 115.0,
		"movement_speed": 295.0,
		"attack_interval": 0.75,
		"weapon_damage": 14.0,
		"attack_range": 560.0,
		"aim_assist_radius": 92.0,
		"chain_count": 0,
		"chain_range": 0.0,
		"damage_taken_multiplier": 1.0,
		"taunt_weight": 1.15,
		"secondary": "rime_ward",
		"secondary_cooldown": 10.0,
		"upgrades": ["depth", "rime", "heavy", "vitality"],
		"kit_q": "rime_ice_imprisonment",
		"kit_e": "rime_chilling_touch",
		"kit_r": "rime_freezing_field",
		"ability_pool": [
			"rime_ice_imprisonment", "rime_chilling_touch", "rime_glacier_blast", "rime_freezing_field",
			"rime_hailstorm", "rime_cold_rush", "rime_frost_armor", "rime_whiteout",
			"rime_winters_grasp", "rime_cleave", "rime_thaw", "rime_frozen_ward",
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
	STORM_PULL,
	ZONE_CHANNEL,
	SUMMON_SPIRIT,
	SLAM_TAUNT,
	BLINK_STRIKE,
	PIT_SLOW,
	ATTACK_FURY,
}

## The four worlds the roster is drawn from — Iron Foundry is the original robot crew,
## Caldera/Verdant/Storm are the HoN-inspired expansion worlds.
enum World {
	IRON_FOUNDRY,
	ASHEN_CALDERA,
	VERDANT_WILDS,
	STORM_COURT,
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
	Archetype.STORM_PULL: "storm_pull",
	Archetype.ZONE_CHANNEL: "zone_channel",
	Archetype.SUMMON_SPIRIT: "summon_spirit",
	Archetype.SLAM_TAUNT: "slam_taunt",
	Archetype.BLINK_STRIKE: "blink_strike",
	Archetype.PIT_SLOW: "pit_slow",
	Archetype.ATTACK_FURY: "attack_fury",
}

## id -> data. Every hero picks 12 of these (see CLASSES[i].ability_pool). Numeric fields scale
## linearly with rank via ability_values(); everything else (radius, chain_count, dash_distance,
## on-hit modifiers, buff_stats) stays fixed across ranks to keep each entry small.
const ABILITIES: Dictionary = {
	# --- Tobor (Wrench / Engineer) ---------------------------------------------------------
	"tobor_steam_keg": {
		"name": "Steam Keg", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a pressurized keg that bursts in scalding steam, knocking enemies back.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 560.0, "radius": 200.0,
		"stun_on_hit": {"duration": 0.6},
	},
	"tobor_steam_turret": {
		"name": "Steam Turret", "archetype": Archetype.SUMMON_SPIRIT,
		"description": "Deploy an automated turret that peppers the nearest enemy with steam bolts.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 12.0, "power_per_rank": 3.0, "range": 420.0,
		"duration_base": 20.0, "duration_per_rank": 1.0, "summon_count": 1,
	},
	"tobor_energy_field": {
		"name": "Energy Field", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Project a pulsing field that slows and sears everything inside.",
		"cooldown_base": 50.0, "cooldown_per_rank": -4.2, "cooldown_min": 30.0,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 0.0, "radius": 320.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
		"slow_on_hit": {"factor": 0.5, "duration": 2.5},
	},
	"tobor_energy_absorption": {
		"name": "Energy Absorption", "archetype": Archetype.SHIELD_BURST,
		"description": "Convert incoming current into a crackling personal shield.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 60.0, "power_per_rank": 15.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"tobor_keg_lob": {
		"name": "Keg Lob", "archetype": Archetype.NUKE_BOLT,
		"description": "Lob an unpressurized keg. Less elegant than the Steam Keg, still loud.",
		"cooldown_base": 4.5, "cooldown_per_rank": -0.4, "cooldown_min": 2.5,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 520.0, "radius": 180.0,
	},
	"tobor_turret_overdrive": {
		"name": "Turret Overdrive", "archetype": Archetype.BUFF_SELF,
		"description": "Overclock every gadget on your frame, casting far faster for a moment.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 4.5, "duration_per_rank": 0.5,
		"buff_stats": {"attack_interval_mult": 0.65, "movement_speed_mult": 1.1}, "target_scope": "self",
	},
	"tobor_scrap_shield": {
		"name": "Scrap Shield", "archetype": Archetype.SHIELD_BURST,
		"description": "Weld a hasty barrier out of whatever scrap is nearby.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 50.0, "power_per_rank": 13.0,
		"duration_base": 4.5, "duration_per_rank": 0.5, "target_scope": "self",
	},
	"tobor_boiler_burst": {
		"name": "Boiler Burst", "archetype": Archetype.RADIUS_BURST,
		"description": "Vent the main boiler in a ring of scalding steam.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 4.0,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 0.0, "radius": 180.0,
	},
	"tobor_wrench_toss": {
		"name": "Wrench Toss", "archetype": Archetype.NUKE_BOLT,
		"description": "Fling the trusty wrench. It always comes back. Usually.",
		"cooldown_base": 3.4, "cooldown_per_rank": -0.4, "cooldown_min": 1.8,
		"power_base": 38.0, "power_per_rank": 10.0, "range": 540.0,
	},
	"tobor_repair_pulse": {
		"name": "Repair Pulse", "archetype": Archetype.SELF_HEAL,
		"description": "Run a quick self-diagnostic and weld the worst of the damage shut.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.0,
		"power_base": 40.0, "power_per_rank": 11.0,
	},
	"tobor_steam_vent": {
		"name": "Steam Vent", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Blow a ring of steam outward, shoving everything away from you.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 6.0,
		"power_base": -320.0, "power_per_rank": -32.0, "range": 0.0, "radius": 200.0,
	},
	"tobor_ironclad_chassis": {
		"name": "Ironclad Chassis", "archetype": Archetype.BUFF_SELF,
		"description": "Lock the frame down: incoming damage bounces off the plating.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 4.5, "duration_per_rank": 0.5,
		"buff_stats": {"damage_taken_mult": 0.6}, "target_scope": "self",
	},
	# --- Arclight (Joule / Thunderbringer) -----------------------------------------------
	"arclight_blast_of_lightning": {
		"name": "Blast of Lightning", "archetype": Archetype.NUKE_BOLT,
		"description": "Smite a single target with a bolt from the heavens.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 110.0, "power_per_rank": 28.0, "range": 640.0,
	},
	"arclight_chain_lightning": {
		"name": "Chain Lightning", "archetype": Archetype.CHAIN_NUKE,
		"description": "Loose a bolt that leaps greedily from foe to foe.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 620.0,
		"chain_count": 5, "chain_range": 240.0,
	},
	"arclight_thundergods_wrath": {
		"name": "Thundergod's Wrath", "archetype": Archetype.RADIUS_BURST,
		"description": "Call down the wrath of the sky on every enemy in the arena.",
		"cooldown_base": 50.0, "cooldown_per_rank": -4.2, "cooldown_min": 30.0,
		"power_base": 180.0, "power_per_rank": 45.0, "range": 0.0, "radius": 999.0,
		"stun_on_hit": {"duration": 0.5},
	},
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
	# --- Bulwark (Tremor / Behemoth) ------------------------------------------------------
	"bulwark_fissure": {
		"name": "Fissure", "archetype": Archetype.DASH_STRIKE,
		"description": "Crack the earth open in a line, stunning everything standing on it.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 4.8,
		"power_base": 55.0, "power_per_rank": 14.0, "dash_distance": 340.0, "radius": 60.0,
		"stun_on_hit": {"duration": 1.2},
	},
	"bulwark_heavyweight": {
		"name": "Heavyweight", "archetype": Archetype.ATTACK_FURY,
		"description": "Swing with both fists — every strike lands twice as hard for a while.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 8.0, "duration_per_rank": 0.6, "multi_attack": 2,
	},
	"bulwark_echo_slam": {
		"name": "Echo Slam", "archetype": Archetype.RADIUS_BURST,
		"description": "Slam the ground so hard the arena itself answers, louder for every enemy inside.",
		"cooldown_base": 45.0, "cooldown_per_rank": -3.8, "cooldown_min": 27.0,
		"power_base": 120.0, "power_per_rank": 30.0, "range": 0.0, "radius": 300.0,
		"stun_on_hit": {"duration": 1.0},
	},
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
	# --- Warden (Totem / Pollywog Priest) --------------------------------------------------
	"warden_tongue_tied": {
		"name": "Tongue Tied", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Lash out with the priest's tongue and yank the closest enemy to hand.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 380.0, "power_per_rank": 38.0, "range": 480.0, "radius": 160.0,
	},
	"warden_voodoo_wards": {
		"name": "Voodoo Wards", "archetype": Archetype.SUMMON_SPIRIT,
		"description": "Plant a clutch of voodoo wards that spit venom at anything hostile.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 9.0, "power_per_rank": 2.5, "range": 400.0,
		"duration_base": 18.0, "duration_per_rank": 1.0, "summon_count": 1,
	},
	"warden_life_drain": {
		"name": "Life Drain", "archetype": Archetype.NUKE_BOLT,
		"description": "Channel the old rite, siphoning the life from an enemy into yourself.",
		"cooldown_base": 45.0, "cooldown_per_rank": -3.8, "cooldown_min": 27.0,
		"power_base": 130.0, "power_per_rank": 33.0, "range": 560.0, "lifesteal_pct": 1.0,
	},
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
	# --- Cinder -----------------------------------------------------------------------------
	"cinder_whirling_flame": {
		"name": "Whirling Flame", "archetype": Archetype.DASH_STRIKE,
		"description": "Dash forward wreathed in flame, scorching a trail that keeps burning.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 35.0, "power_per_rank": 9.0, "dash_distance": 340.0, "radius": 60.0,
		"stun_on_hit": {"duration": 0.4}, "fire_trail": true,
	},
	"cinder_fiery_assault": {
		"name": "Fiery Assault", "archetype": Archetype.RADIUS_BURST,
		"description": "Detonate a ring of fire around yourself.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 6.5,
		"power_base": 32.0, "power_per_rank": 9.0, "range": 0.0, "radius": 220.0,
	},
	"cinder_dragon_fire": {
		"name": "Dragon Fire", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a searing bolt that bursts into dragon fire.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 105.0, "power_per_rank": 26.0, "range": 620.0,
	},
	"cinder_pillar_of_flame": {
		"name": "Pillar of Flame", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Call up a towering pillar of flame that incinerates everything inside.",
		"cooldown_base": 22.0, "cooldown_per_rank": -1.8, "cooldown_min": 12.0,
		"power_base": 22.0, "power_per_rank": 6.0, "range": 0.0, "radius": 280.0,
		"duration_base": 4.0, "duration_per_rank": 0.4,
	},
	"cinder_firebomb": {
		"name": "Firebomb", "archetype": Archetype.NUKE_BOLT,
		"description": "Lob a heavy firebomb that blankets the area in flame.",
		"cooldown_base": 5.0, "cooldown_per_rank": -0.5, "cooldown_min": 2.8,
		"power_base": 60.0, "power_per_rank": 15.0, "range": 540.0,
	},
	"cinder_scorch": {
		"name": "Scorch", "archetype": Archetype.CONE_BURST,
		"description": "Breathe a cone of withering heat.",
		"cooldown_base": 5.0, "cooldown_per_rank": -0.5, "cooldown_min": 2.8,
		"power_base": 36.0, "power_per_rank": 9.0, "radius": 240.0,
	},
	"cinder_ignite": {
		"name": "Ignite", "archetype": Archetype.NUKE_BOLT,
		"description": "Set every enemy in the blast alight.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.6,
		"power_base": 42.0, "power_per_rank": 11.0, "range": 520.0,
	},
	"cinder_combustion_wave": {
		"name": "Combustion Wave", "archetype": Archetype.NUKE_BOLT,
		"description": "Violently detonate the air around every enemy in the blast.",
		"cooldown_base": 9.5, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 65.0, "power_per_rank": 17.0, "range": 540.0, "radius": 190.0,
		"stun_on_hit": {"duration": 0.8},
	},
	"cinder_flame_dash": {
		"name": "Flame Dash", "archetype": Archetype.BLINK,
		"description": "Turn to flame and surge forward, igniting the landing point.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 20.0, "power_per_rank": 6.0, "dash_distance": 310.0, "radius": 120.0,
	},
	"cinder_magma_armor": {
		"name": "Magma Armor", "archetype": Archetype.SHIELD_BURST,
		"description": "Cool your skin into a shell of blackened magma.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 55.0, "power_per_rank": 14.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"cinder_heat_surge": {
		"name": "Heat Surge", "archetype": Archetype.BUFF_SELF,
		"description": "Stoke your inner furnace, casting far faster for a moment.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.5,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
		"buff_stats": {"attack_interval_mult": 0.65, "movement_speed_mult": 1.1}, "target_scope": "self",
	},
	"cinder_pyroclasm": {
		"name": "Pyroclasm", "archetype": Archetype.NUKE_BOLT,
		"description": "Split the earth with a surge of volcanic pressure.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 560.0, "radius": 180.0,
	},
	# --- Pyra -------------------------------------------------------------------------------
	"pyra_sticky_bomb": {
		"name": "Sticky Bomb", "archetype": Archetype.NUKE_BOLT,
		"description": "Lob an adhesive bomb that clings and bursts.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 75.0, "power_per_rank": 19.0, "range": 540.0,
	},
	"pyra_boom_dust": {
		"name": "Boom Dust", "archetype": Archetype.RADIUS_BURST,
		"description": "Shake loose a cloud of explosive dust.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.0,
		"power_base": 38.0, "power_per_rank": 10.0, "range": 0.0, "radius": 240.0,
	},
	"pyra_bombardment": {
		"name": "Bombardment", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Saturate an area with sustained mortar fire.",
		"cooldown_base": 26.0, "cooldown_per_rank": -2.2, "cooldown_min": 15.0,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 0.0, "radius": 260.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"pyra_air_strike": {
		"name": "Air Strike", "archetype": Archetype.RADIUS_BURST,
		"description": "Paint a target and let the ordnance scream down from above.",
		"cooldown_base": 70.0, "cooldown_per_rank": -6.0, "cooldown_min": 40.0,
		"power_base": 220.0, "power_per_rank": 55.0, "range": 620.0, "radius": 340.0,
		"sky_strike": true, "sky_delay": 0.6,
	},
	"pyra_fireball": {
		"name": "Fireball", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a classic ball of flame.",
		"cooldown_base": 4.0, "cooldown_per_rank": -0.4, "cooldown_min": 2.2,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 560.0,
	},
	"pyra_meteor": {
		"name": "Meteor", "archetype": Archetype.NUKE_BOLT,
		"description": "Pull a meteor out of the sky onto a single point.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 90.0, "power_per_rank": 23.0, "range": 600.0, "radius": 200.0,
	},
	"pyra_scorch_mark": {
		"name": "Scorch Mark", "archetype": Archetype.NUKE_BOLT,
		"description": "Brand every enemy in the blast, exposing them to extra damage.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 16.0, "power_per_rank": 4.0, "range": 540.0,
		"mark_on_hit": {"bonus_pct": 0.25, "duration": 4.0},
	},
	"pyra_flame_wall": {
		"name": "Flame Wall", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Raise a line of standing flame that cooks anything crossing it.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 6.0,
		"power_base": 25.0, "power_per_rank": 7.0, "range": 0.0, "radius": 240.0,
		"duration_base": 3.0, "duration_per_rank": 0.4,
	},
	"pyra_molten_charge": {
		"name": "Molten Charge", "archetype": Archetype.DASH_STRIKE,
		"description": "Barrel forward in a surge of molten rock.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 5.0,
		"power_base": 40.0, "power_per_rank": 10.0, "dash_distance": 320.0, "radius": 65.0,
	},
	"pyra_heat_shield": {
		"name": "Heat Shield", "archetype": Archetype.SHIELD_BURST,
		"description": "Wrap yourself in a wavering curtain of heat.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 55.0, "power_per_rank": 14.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"pyra_rock_throw": {
		"name": "Rock Throw", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a boulder with a casual flick.",
		"cooldown_base": 4.5, "cooldown_per_rank": -0.4, "cooldown_min": 2.5,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 480.0,
	},
	"pyra_volcano": {
		"name": "Volcano", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Open a small volcano under your enemies' feet.",
		"cooldown_base": 24.0, "cooldown_per_rank": -2.2, "cooldown_min": 14.0,
		"power_base": 35.0, "power_per_rank": 9.0, "range": 0.0, "radius": 280.0,
		"duration_base": 4.0, "duration_per_rank": 0.4,
	},
	# --- Slag -------------------------------------------------------------------------------
	"slag_steam_bath": {
		"name": "Steam Bath", "archetype": Archetype.BUFF_SELF,
		"description": "Vent a cloud of steam that hardens your magma shell.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.5,
		"power_base": 25.0, "power_per_rank": 7.0,
		"duration_base": 6.0, "duration_per_rank": 0.6,
		"buff_stats": {"damage_taken_mult": 0.7, "movement_speed_mult": 1.05}, "target_scope": "self",
	},
	"slag_volcanic_touch": {
		"name": "Volcanic Touch", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Slam the ground and fling everything nearby away.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": -55.0, "power_per_rank": -6.0, "range": 0.0, "radius": 260.0,
	},
	"slag_lava_surge": {
		"name": "Lava Surge", "archetype": Archetype.DASH_STRIKE,
		"description": "Flow forward like molten rock, scorching everything you pass.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 45.0, "power_per_rank": 12.0, "dash_distance": 380.0, "radius": 65.0,
		"fire_trail": true,
	},
	"slag_eruption": {
		"name": "Eruption", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Blow the ground apart in a volcanic eruption.",
		"cooldown_base": 60.0, "cooldown_per_rank": -5.0, "cooldown_min": 36.0,
		"power_base": 80.0, "power_per_rank": 20.0, "range": 0.0, "radius": 320.0,
		"duration_base": 3.0, "duration_per_rank": 0.3,
	},
	"slag_magma_charge": {
		"name": "Magma Charge", "archetype": Archetype.DASH_STRIKE,
		"description": "Rush forward like an avalanche of molten stone.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 5.0,
		"power_base": 42.0, "power_per_rank": 11.0, "dash_distance": 300.0, "radius": 70.0,
	},
	"slag_earthen_slam": {
		"name": "Earthen Slam", "archetype": Archetype.NUKE_BOLT,
		"description": "Bring both fists down in a shockwave of stone.",
		"cooldown_base": 5.5, "cooldown_per_rank": -0.5, "cooldown_min": 3.0,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 220.0, "radius": 175.0,
	},
	"slag_basalt_armour": {
		"name": "Basalt Armour", "archetype": Archetype.SHIELD_BURST,
		"description": "Grow a fresh jacket of cooling basalt.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 70.0, "power_per_rank": 18.0,
		"duration_base": 5.5, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"slag_lava_wall": {
		"name": "Lava Wall", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Push a slow wall of lava ahead of you.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 28.0, "power_per_rank": 7.0, "range": 0.0, "radius": 240.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"slag_seismic_ring": {
		"name": "Seismic Ring", "archetype": Archetype.RADIUS_BURST,
		"description": "Pound the earth so hard it rings like a bell.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 0.0, "radius": 230.0,
	},
	"slag_boulder_hurl": {
		"name": "Boulder Hurl", "archetype": Archetype.NUKE_BOLT,
		"description": "Tear a chunk of mountain free and hurl it.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.6,
		"power_base": 70.0, "power_per_rank": 18.0, "range": 520.0,
	},
	"slag_molten_skin": {
		"name": "Molten Skin", "archetype": Archetype.BUFF_SELF,
		"description": "Let your hide run half-liquid, softening every blow.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.5,
		"power_base": 30.0, "power_per_rank": 8.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
		"buff_stats": {"damage_taken_mult": 0.65}, "target_scope": "self",
	},
	"slag_geysers": {
		"name": "Geysers", "archetype": Archetype.RADIUS_BURST,
		"description": "Split the ground so steam vents blast everything nearby.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 0.0, "radius": 220.0,
		"stun_on_hit": {"duration": 0.5},
	},
	# --- Ember ------------------------------------------------------------------------------
	"ember_entangle": {
		"name": "Entangle", "archetype": Archetype.NUKE_BOLT,
		"description": "Roots and cinders burst up to hold every foe in the area.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 65.0, "power_per_rank": 17.0, "range": 560.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.5},
	},
	"ember_healing_wave": {
		"name": "Healing Wave", "archetype": Archetype.AOE_HEAL,
		"description": "Send a warm wave of renewal through the party.",
		"cooldown_base": 16.0, "cooldown_per_rank": -1.5, "cooldown_min": 9.5,
		"power_base": 70.0, "power_per_rank": 18.0, "range": 0.0, "radius": 300.0,
	},
	"ember_storm_cloud": {
		"name": "Storm Cloud", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Summon a blistering ash-storm that bathes the area.",
		"cooldown_base": 24.0, "cooldown_per_rank": -2.2, "cooldown_min": 14.0,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 0.0, "radius": 260.0,
		"duration_base": 4.0, "duration_per_rank": 0.4,
	},
	"ember_unbreakable": {
		"name": "Unbreakable", "archetype": Archetype.BUFF_SELF,
		"description": "Take on the resolve of ancient oak. Almost nothing gets through.",
		"cooldown_base": 60.0, "cooldown_per_rank": -5.0, "cooldown_min": 36.0,
		"power_base": 80.0, "power_per_rank": 20.0,
		"duration_base": 8.0, "duration_per_rank": 0.8,
		"buff_stats": {"damage_taken_mult": 0.45}, "target_scope": "self",
	},
	"ember_firebomb": {
		"name": "Firebomb", "archetype": Archetype.NUKE_BOLT,
		"description": "Lob a clay bomb packed with cinder.",
		"cooldown_base": 5.0, "cooldown_per_rank": -0.5, "cooldown_min": 2.8,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 540.0,
	},
	"ember_mending_flame": {
		"name": "Mending Flame", "archetype": Archetype.AOE_HEAL,
		"description": "A gentle flame that knits wounds instead of opening them.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 0.0, "radius": 260.0,
	},
	"ember_spark_volley": {
		"name": "Spark Volley", "archetype": Archetype.CHAIN_NUKE,
		"description": "Loose a handful of embers that skip between foes.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 540.0,
		"chain_count": 3, "chain_range": 200.0,
	},
	"ember_phoenix_dash": {
		"name": "Phoenix Dash", "archetype": Archetype.DASH_STRIKE,
		"description": "Burst forward like a rising phoenix, reborn on arrival.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 30.0, "power_per_rank": 8.0, "dash_distance": 300.0, "radius": 60.0,
		"lifesteal_pct": 0.4,
	},
	"ember_heat_vent": {
		"name": "Heat Vent", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Vent a blast of hot air, shoving enemies back.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": -320.0, "power_per_rank": -32.0, "range": 0.0, "radius": 200.0,
	},
	"ember_burning_aura": {
		"name": "Burning Aura", "archetype": Archetype.BUFF_SELF,
		"description": "Ignite your own outline, burning anything that dares come close.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 30.0, "power_per_rank": 8.0,
		"duration_base": 6.0, "duration_per_rank": 0.6,
		"buff_stats": {"reflect_pct": 0.45}, "target_scope": "self",
	},
	"ember_cinder_shield": {
		"name": "Cinder Shield", "archetype": Archetype.SHIELD_BURST,
		"description": "Swirl cinders into a shield around yourself and nearby allies.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 0.0, "radius": 240.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "allies",
	},
	"ember_flamebreak": {
		"name": "Flamebreak", "archetype": Archetype.NUKE_BOLT,
		"description": "Shatter every enemy in the blast with a rolling wave of flame.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 500.0, "radius": 180.0,
	},
	# --- Thorn ------------------------------------------------------------------------------
	"thorn_poison_spray": {
		"name": "Poison Spray", "archetype": Archetype.CONE_BURST,
		"description": "Hose the area in front of you with virulent toxin.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 30.0, "power_per_rank": 8.0, "radius": 340.0,
	},
	"thorn_toxin_ward": {
		"name": "Toxin Ward", "archetype": Archetype.SUMMON_SPIRIT,
		"description": "Plant a ward that spits venom at anything that wanders close.",
		"cooldown_base": 24.0, "cooldown_per_rank": -2.2, "cooldown_min": 14.0,
		"power_base": 8.0, "power_per_rank": 2.0, "range": 380.0,
		"duration_base": 18.0, "duration_per_rank": 1.0, "summon_count": 1,
	},
	"thorn_toxicity": {
		"name": "Toxicity", "archetype": Archetype.ATTACK_FURY,
		"description": "Drench your next strikes in a double-dose of venom.",
		"cooldown_base": 5.0, "cooldown_per_rank": -0.5, "cooldown_min": 3.0,
		"power_base": 0.0, "power_per_rank": 0.0,
		"duration_base": 8.0, "duration_per_rank": 0.6, "multi_attack": 2,
	},
	"thorn_poison_burst": {
		"name": "Poison Burst", "archetype": Archetype.RADIUS_BURST,
		"description": "Detonate every pocket of venom in the area at once.",
		"cooldown_base": 26.0, "cooldown_per_rank": -2.4, "cooldown_min": 15.0,
		"power_base": 70.0, "power_per_rank": 18.0, "range": 0.0, "radius": 260.0,
	},
	"thorn_vine_lash": {
		"name": "Vine Lash", "archetype": Archetype.NUKE_BOLT,
		"description": "Whip thorned vines through every enemy in range.",
		"cooldown_base": 4.5, "cooldown_per_rank": -0.4, "cooldown_min": 2.5,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 520.0,
	},
	"thorn_toxic_cloud": {
		"name": "Toxic Cloud", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Exhale a lingering miasma that rots everything inside.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 22.0, "power_per_rank": 6.0, "range": 0.0, "radius": 240.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"thorn_thorn_armour": {
		"name": "Thorn Armour", "archetype": Archetype.BUFF_SELF,
		"description": "Sheathe yourself in bark and barbs that punish attackers.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.5,
		"power_base": 45.0, "power_per_rank": 12.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
		"buff_stats": {"reflect_pct": 0.4}, "target_scope": "self",
	},
	"thorn_venom_strike": {
		"name": "Venom Strike", "archetype": Archetype.CHAIN_NUKE,
		"description": "A bolt of venom that splashes from body to body.",
		"cooldown_base": 7.5, "cooldown_per_rank": -0.7, "cooldown_min": 4.2,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 520.0,
		"chain_count": 3, "chain_range": 200.0,
	},
	"thorn_bramble_dash": {
		"name": "Bramble Dash", "archetype": Archetype.DASH_STRIKE,
		"description": "Ride a surge of brambles through the enemy line.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 30.0, "power_per_rank": 8.0, "dash_distance": 300.0, "radius": 60.0,
	},
	"thorn_root_tangle": {
		"name": "Root Tangle", "archetype": Archetype.NUKE_BOLT,
		"description": "Roots coil around every foot in the blast.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 14.0, "power_per_rank": 4.0, "range": 480.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.0},
	},
	"thorn_spore_burst": {
		"name": "Spore Burst", "archetype": Archetype.NUKE_BOLT,
		"description": "A shower of spores that marks every enemy caught inside.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 5.0,
		"power_base": 38.0, "power_per_rank": 10.0, "range": 500.0,
		"mark_on_hit": {"bonus_pct": 0.25, "duration": 4.0},
	},
	"thorn_ambush": {
		"name": "Ambush", "archetype": Archetype.BUFF_SELF,
		"description": "Melt into the undergrowth, then strike from nowhere.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 30.0, "power_per_rank": 8.0, "dash_distance": 280.0,
		"duration_base": 6.0, "duration_per_rank": 0.5,
		"buff_stats": {"damage_dealt_mult": 1.2}, "target_scope": "self",
	},
	# --- Willow -----------------------------------------------------------------------------
	"willow_swift_strike": {
		"name": "Swift Strike", "archetype": Archetype.DASH_STRIKE,
		"description": "Blink-quick dash through the enemy line, blade first.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.0,
		"power_base": 30.0, "power_per_rank": 8.0, "dash_distance": 320.0, "radius": 60.0,
	},
	"willow_forsaken_shot": {
		"name": "Forsaken Shot", "archetype": Archetype.NUKE_BOLT,
		"description": "A single impossible shot that crosses the whole field.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 95.0, "power_per_rank": 24.0, "range": 700.0,
	},
	"willow_volley": {
		"name": "Volley", "archetype": Archetype.CONE_BURST,
		"description": "Loose a fan of arrows across the treeline ahead.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 6.0,
		"power_base": 40.0, "power_per_rank": 10.0, "radius": 480.0,
	},
	"willow_wall_of_roots": {
		"name": "Wall of Roots", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Raise a wall of grasping roots that snares everything it catches.",
		"cooldown_base": 50.0, "cooldown_per_rank": -4.2, "cooldown_min": 30.0,
		"power_base": 35.0, "power_per_rank": 9.0, "range": 0.0, "radius": 280.0,
		"duration_base": 4.0, "duration_per_rank": 0.4,
	},
	"willow_briar_jab": {
		"name": "Briar Jab", "archetype": Archetype.NUKE_BOLT,
		"description": "A quick, nasty jab from a briar-wrapped fist.",
		"cooldown_base": 4.0, "cooldown_per_rank": -0.4, "cooldown_min": 2.2,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 540.0,
	},
	"willow_seed_bomb": {
		"name": "Seed Bomb", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a seed that detonates in a shower of thorns.",
		"cooldown_base": 5.0, "cooldown_per_rank": -0.5, "cooldown_min": 2.8,
		"power_base": 42.0, "power_per_rank": 11.0, "range": 520.0,
	},
	"willow_thorn_snare": {
		"name": "Thorn Snare", "archetype": Archetype.NUKE_BOLT,
		"description": "Roots coil around every foot in the blast.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 18.0, "power_per_rank": 5.0, "range": 560.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.2},
	},
	"willow_shadow_step": {
		"name": "Shadow Step", "archetype": Archetype.BLINK,
		"description": "Step behind the veil and come out a breath ahead.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.9, "cooldown_min": 4.8,
		"power_base": 25.0, "power_per_rank": 7.0, "dash_distance": 330.0, "radius": 120.0,
	},
	"willow_spore_volley": {
		"name": "Spore Volley", "archetype": Archetype.CHAIN_NUKE,
		"description": "A burst of darting spores that skip from enemy to enemy.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 520.0,
		"chain_count": 3, "chain_range": 210.0,
	},
	"willow_vital_strike": {
		"name": "Vital Strike", "archetype": Archetype.NUKE_BOLT,
		"description": "Lance clean through the target and take some of its life with you.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.6,
		"power_base": 38.0, "power_per_rank": 10.0, "range": 560.0, "lifesteal_pct": 0.5,
	},
	"willow_briar_wall": {
		"name": "Briar Wall", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Raise a line of brambles that shreds anything crossing it.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 25.0, "power_per_rank": 7.0, "range": 0.0, "radius": 240.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"willow_final_bloom": {
		"name": "Final Bloom", "archetype": Archetype.NUKE_BOLT,
		"description": "A single perfect shot that blossoms into ruin at the impact.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 85.0, "power_per_rank": 21.0, "range": 620.0, "radius": 180.0,
	},
	# --- Stump ------------------------------------------------------------------------------
	"stump_natures_rally": {
		"name": "Nature's Rally", "archetype": Archetype.BUFF_SELF,
		"description": "Lend a surge of life to everyone standing near the old tree.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 30.0, "power_per_rank": 8.0, "radius": 320.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
		"buff_stats": {"damage_dealt_mult": 1.12}, "target_scope": "allies",
	},
	"stump_camouflage": {
		"name": "Camouflage", "archetype": Archetype.BUFF_SELF,
		"description": "Settle into the landscape so the enemy barely notices you.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 40.0, "power_per_rank": 10.0,
		"duration_base": 7.0, "duration_per_rank": 0.7,
		"buff_stats": {"damage_taken_mult": 0.6}, "target_scope": "self",
	},
	"stump_natures_veil": {
		"name": "Nature's Veil", "archetype": Archetype.AOE_HEAL,
		"description": "Draw a veil of green that knits every wound it touches.",
		"cooldown_base": 20.0, "cooldown_per_rank": -1.8, "cooldown_min": 12.0,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 0.0, "radius": 280.0,
	},
	"stump_overgrowth": {
		"name": "Overgrowth", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Let the forest reclaim the arena, choking everything hostile.",
		"cooldown_base": 46.0, "cooldown_per_rank": -3.8, "cooldown_min": 27.0,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 0.0, "radius": 340.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
	},
	"stump_trunk_slam": {
		"name": "Trunk Slam", "archetype": Archetype.NUKE_BOLT,
		"description": "Bring a whole trunk down on the enemy.",
		"cooldown_base": 4.5, "cooldown_per_rank": -0.4, "cooldown_min": 2.5,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 220.0, "radius": 175.0,
	},
	"stump_root_charge": {
		"name": "Root Charge", "archetype": Archetype.DASH_STRIKE,
		"description": "Barrel forward on a wave of roots and bark.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 40.0, "power_per_rank": 10.0, "dash_distance": 300.0, "radius": 70.0,
	},
	"stump_barkskin": {
		"name": "Barkskin", "archetype": Archetype.SHIELD_BURST,
		"description": "Grow a fresh coat of bark for yourself and the nearest allies.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 0.0, "radius": 220.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "allies",
	},
	"stump_wall": {
		"name": "Wall", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Root a wall of packed earth where you stand.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 20.0, "power_per_rank": 5.0, "range": 0.0, "radius": 220.0,
		"duration_base": 4.0, "duration_per_rank": 0.4,
	},
	"stump_living_seed": {
		"name": "Living Seed", "archetype": Archetype.SUMMON_SPIRIT,
		"description": "Drop a seed that sprouts into a seedling helper.",
		"cooldown_base": 16.0, "cooldown_per_rank": -1.5, "cooldown_min": 9.5,
		"power_base": 8.0, "power_per_rank": 2.0, "range": 380.0,
		"duration_base": 12.0, "duration_per_rank": 1.0, "summon_count": 1,
	},
	"stump_heartwood": {
		"name": "Heartwood", "archetype": Archetype.SELF_HEAL,
		"description": "Settle your roots deep and knit the damage shut.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 50.0, "power_per_rank": 13.0,
	},
	"stump_wildgrowth": {
		"name": "Wildgrowth", "archetype": Archetype.NUKE_BOLT,
		"description": "A pressure-wave of unchecked growth that staggers everything inside.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 40.0, "power_per_rank": 11.0, "range": 260.0, "radius": 200.0,
		"slow_on_hit": {"factor": 0.6, "duration": 2.0},
	},
	"stump_fortress_grove": {
		"name": "Fortress Grove", "archetype": Archetype.BUFF_SELF,
		"description": "Sink roots so deep that nothing short of a mountain can move you.",
		"cooldown_base": 18.0, "cooldown_per_rank": -1.6, "cooldown_min": 10.5,
		"power_base": 30.0, "power_per_rank": 8.0,
		"duration_base": 8.0, "duration_per_rank": 0.8,
		"buff_stats": {"damage_taken_mult": 0.6}, "target_scope": "allies",
	},
	# --- Sage -------------------------------------------------------------------------------
	"sage_grace": {
		"name": "Grace", "archetype": Archetype.AOE_HEAL,
		"description": "Wash the whole party in a cool, clean wave of grace.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 60.0, "power_per_rank": 15.0, "range": 0.0, "radius": 260.0,
	},
	"sage_volatile_pod": {
		"name": "Volatile Pod", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a seed pod that splits on impact.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 75.0, "power_per_rank": 19.0, "range": 600.0,
	},
	"sage_nymphoras_kiss": {
		"name": "Nymphora's Kiss", "archetype": Archetype.SELF_HEAL,
		"description": "Steal a moment of the grove's peace to settle your own wounds.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 80.0, "power_per_rank": 20.0,
	},
	"sage_charm": {
		"name": "Charm", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "A soft word and a gentle shove that coaxes foes out of formation.",
		"cooldown_base": 44.0, "cooldown_per_rank": -3.8, "cooldown_min": 27.0,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 400.0, "radius": 220.0,
	},
	"sage_healing_wave": {
		"name": "Healing Wave", "archetype": Archetype.AOE_HEAL,
		"description": "A rolling tide of green light that closes wounds as it passes.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 0.0, "radius": 280.0,
	},
	"sage_lifeward": {
		"name": "Lifeward", "archetype": Archetype.SHIELD_BURST,
		"description": "Wrap the ward around the party, turning harm aside with green light.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 0.0, "radius": 240.0,
		"duration_base": 6.0, "duration_per_rank": 0.7, "target_scope": "allies",
	},
	"sage_rejuvenate": {
		"name": "Rejuvenate", "archetype": Archetype.SHIELD_BURST,
		"description": "Renew the body's defences with a gentle green tide.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 35.0, "power_per_rank": 9.0,
		"duration_base": 5.0, "duration_per_rank": 0.5, "target_scope": "self",
	},
	"sage_natures_step": {
		"name": "Nature's Step", "archetype": Archetype.BLINK,
		"description": "Ride a filigree of roots and wildflowers in a great stride.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.9, "cooldown_min": 4.8,
		"power_base": 10.0, "power_per_rank": 3.0, "dash_distance": 290.0, "radius": 160.0,
	},
	"sage_petal_dance": {
		"name": "Petal Dance", "archetype": Archetype.CONE_BURST,
		"description": "A swirling fan of razor-edged petals.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.8, "cooldown_min": 5.2,
		"power_base": 30.0, "power_per_rank": 8.0, "radius": 340.0,
	},
	"sage_entangle": {
		"name": "Entangle", "archetype": Archetype.NUKE_BOLT,
		"description": "Roots burst from the ground to pin every foe in the area fast.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 16.0, "power_per_rank": 4.0, "range": 520.0,
		"stun_on_hit": {"duration": 1.0},
	},
	"sage_starfall": {
		"name": "Starfall", "archetype": Archetype.NUKE_BOLT,
		"description": "Call down a single cold star to break enemy lines.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 68.0, "power_per_rank": 17.0, "range": 620.0, "radius": 200.0,
	},
	"sage_world_seed": {
		"name": "World Seed", "archetype": Archetype.AOE_HEAL,
		"description": "Drop the seed of a future world into the party's hands.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 0.0, "radius": 240.0,
	},
	# --- Volt -------------------------------------------------------------------------------
	"volt_gust": {
		"name": "Gust", "archetype": Archetype.CONE_BURST,
		"description": "Throw a hard-edged gust that flattens the frontline.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 32.0, "power_per_rank": 8.0, "radius": 480.0,
	},
	"volt_wind_shield": {
		"name": "Wind Shield", "archetype": Archetype.SHIELD_BURST,
		"description": "Weave a wall of fast-moving air into armour.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 65.0, "power_per_rank": 17.0, "range": 0.0, "radius": 200.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "allies",
	},
	"volt_wind_control": {
		"name": "Wind Control", "archetype": Archetype.STORM_PULL,
		"description": "Snatch the farthest enemy off its feet and drag it to you.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.0,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 580.0,
	},
	"volt_typhoon": {
		"name": "Typhoon", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Drop a slow, merciless spiral of wind on the arena.",
		"cooldown_base": 54.0, "cooldown_per_rank": -4.5, "cooldown_min": 32.0,
		"power_base": 60.0, "power_per_rank": 15.0, "range": 0.0, "radius": 380.0,
		"duration_base": 4.0, "duration_per_rank": 0.4,
	},
	"volt_plasma_bolt": {
		"name": "Plasma Bolt", "archetype": Archetype.NUKE_BOLT,
		"description": "Hurl a knot of raw storm current.",
		"cooldown_base": 5.5, "cooldown_per_rank": -0.5, "cooldown_min": 3.0,
		"power_base": 40.0, "power_per_rank": 10.0, "range": 560.0,
	},
	"volt_electroshock": {
		"name": "Electroshock", "archetype": Archetype.CHAIN_NUKE,
		"description": "A fork of lightning that skip-jumps from foe to foe.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 25.0, "power_per_rank": 7.0, "range": 540.0,
		"chain_count": 4, "chain_range": 200.0,
	},
	"volt_lightning_lunge": {
		"name": "Lightning Lunge", "archetype": Archetype.DASH_STRIKE,
		"description": "Leap forward as a courier of voltage.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 4.8,
		"power_base": 30.0, "power_per_rank": 8.0, "dash_distance": 280.0, "radius": 60.0,
	},
	"volt_voltaic_cage": {
		"name": "Voltaic Cage", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Throw a storm-cell that stuns everything trapped inside.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 24.0, "power_per_rank": 6.0, "range": 0.0, "radius": 220.0,
		"duration_base": 3.0, "duration_per_rank": 0.3,
		"stun_on_hit": {"duration": 1.0},
	},
	"volt_electro_dash": {
		"name": "Electro Dash", "archetype": Archetype.BLINK,
		"description": "Flash forward in a clap of lightning.",
		"cooldown_base": 7.5, "cooldown_per_rank": -0.8, "cooldown_min": 4.2,
		"power_base": 15.0, "power_per_rank": 4.0, "dash_distance": 330.0, "radius": 100.0,
	},
	"volt_static_drain": {
		"name": "Static Drain", "archetype": Archetype.NUKE_BOLT,
		"description": "Leech the current out of every enemy in the blast.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 4.8,
		"power_base": 32.0, "power_per_rank": 9.0, "range": 560.0, "lifesteal_pct": 0.4,
	},
	"volt_repulsor_blast": {
		"name": "Repulsor Blast", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Blast both wind and current outward from yourself.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": -340.0, "power_per_rank": -34.0, "range": 0.0, "radius": 200.0,
	},
	"volt_amp_field": {
		"name": "Amp Field", "archetype": Archetype.BUFF_SELF,
		"description": "Flood yourself with voltage until everything runs faster.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 7.5,
		"power_base": 35.0, "power_per_rank": 9.0,
		"duration_base": 6.0, "duration_per_rank": 0.6,
		"buff_stats": {"attack_interval_mult": 0.65, "movement_speed_mult": 1.15}, "target_scope": "self",
	},
	# --- Nebula -----------------------------------------------------------------------------
	"nebula_time_shift": {
		"name": "Time Shift", "archetype": Archetype.BLINK,
		"description": "Step sideways through time and come out elsewhere.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 15.0, "power_per_rank": 4.0, "dash_distance": 420.0, "radius": 140.0,
	},
	"nebula_curse_of_ages": {
		"name": "Curse of Ages", "archetype": Archetype.RADIUS_BURST,
		"description": "Curse every foe in the arena to feel the full weight of the eons.",
		"cooldown_base": 12.0, "cooldown_per_rank": -1.1, "cooldown_min": 7.0,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 0.0, "radius": 280.0,
		"slow_on_hit": {"factor": 0.5, "duration": 3.0},
	},
	"nebula_rewind": {
		"name": "Rewind", "archetype": Archetype.SELF_HEAL,
		"description": "Turn your own body back before the wounds landed.",
		"cooldown_base": 24.0, "cooldown_per_rank": -2.2, "cooldown_min": 14.0,
		"power_base": 120.0, "power_per_rank": 30.0,
	},
	"nebula_chronofield": {
		"name": "Chronofield", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Stop time in a wide pocket of the arena.",
		"cooldown_base": 60.0, "cooldown_per_rank": -5.0, "cooldown_min": 36.0,
		"power_base": 90.0, "power_per_rank": 23.0, "range": 0.0, "radius": 380.0,
		"duration_base": 4.5, "duration_per_rank": 0.5,
	},
	"nebula_frost_blast": {
		"name": "Frost Blast", "archetype": Archetype.RADIUS_BURST,
		"description": "A silent blast of frozen potential.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 35.0, "power_per_rank": 10.0, "range": 0.0, "radius": 240.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.5},
	},
	"nebula_arcane_bolt": {
		"name": "Arcane Bolt", "archetype": Archetype.NUKE_BOLT,
		"description": "A shard of timeless energy flung at the enemy.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 50.0, "power_per_rank": 13.0, "range": 560.0,
	},
	"nebula_cold_snap": {
		"name": "Cold Snap", "archetype": Archetype.CONE_BURST,
		"description": "Snap the ambient heat out of the air ahead of you.",
		"cooldown_base": 7.5, "cooldown_per_rank": -0.7, "cooldown_min": 4.2,
		"power_base": 34.0, "power_per_rank": 9.0, "radius": 240.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.0},
	},
	"nebula_blink": {
		"name": "Blink", "archetype": Archetype.BLINK,
		"description": "A basic flicker through time and space.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 10.0, "power_per_rank": 3.0, "dash_distance": 400.0, "radius": 100.0,
	},
	"nebula_meteor_shower": {
		"name": "Meteor Shower", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Rain distant stars on the enemy's position.",
		"cooldown_base": 30.0, "cooldown_per_rank": -2.6, "cooldown_min": 18.0,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 0.0, "radius": 280.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"nebula_warp_field": {
		"name": "Warp Field", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Tear space into a biting field of fractures.",
		"cooldown_base": 22.0, "cooldown_per_rank": -2.0, "cooldown_min": 12.0,
		"power_base": 45.0, "power_per_rank": 12.0, "range": 0.0, "radius": 320.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"nebula_emp": {
		"name": "EMP", "archetype": Archetype.RADIUS_BURST,
		"description": "A snap of nothing that stuns every working thing around you.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 0.0, "radius": 240.0,
		"stun_on_hit": {"duration": 1.2},
	},
	"nebula_void_rift": {
		"name": "Void Rift", "archetype": Archetype.PUSH_PULL_BURST,
		"description": "Open a rift and let it haul the room toward it.",
		"cooldown_base": 11.0, "cooldown_per_rank": -1.0, "cooldown_min": 6.5,
		"power_base": 300.0, "power_per_rank": 30.0, "range": 0.0, "radius": 200.0,
	},
	# --- Astral -----------------------------------------------------------------------------
	"astral_essence_link": {
		"name": "Essence Link", "archetype": Archetype.AOE_HEAL,
		"description": "Connect the party with a strand that shares its life around.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 0.0, "radius": 300.0,
	},
	"astral_ward_of_light": {
		"name": "Ward of Light", "archetype": Archetype.SHIELD_BURST,
		"description": "Set a halo of pure light over every ally in reach — it catches hard hits for them.",
		"cooldown_base": 24.0, "cooldown_per_rank": -2.2, "cooldown_min": 14.0,
		"power_base": 90.0, "power_per_rank": 23.0, "range": 0.0, "radius": 280.0,
		"duration_base": 6.0, "duration_per_rank": 0.7, "target_scope": "allies",
	},
	"astral_spirit_bond": {
		"name": "Spirit Bond", "archetype": Archetype.BUFF_SELF,
		"description": "Pour a share of your courage into everyone who will take it.",
		"cooldown_base": 16.0, "cooldown_per_rank": -1.5, "cooldown_min": 9.5,
		"power_base": 60.0, "power_per_rank": 15.0, "radius": 260.0,
		"duration_base": 7.0, "duration_per_rank": 0.7,
		"buff_stats": {"damage_taken_mult": 0.75}, "target_scope": "allies",
	},
	"astral_as_one": {
		"name": "As One", "archetype": Archetype.SELF_HEAL,
		"description": "Invite the whole team inside, and hold their weight for a beat.",
		"cooldown_base": 70.0, "cooldown_per_rank": -6.0, "cooldown_min": 40.0,
		"power_base": 140.0, "power_per_rank": 35.0,
	},
	"astral_ghost_light": {
		"name": "Ghost Light", "archetype": Archetype.NUKE_BOLT,
		"description": "Release a glimmer of light that marks whoever it falls on.",
		"cooldown_base": 8.0, "cooldown_per_rank": -0.8, "cooldown_min": 4.5,
		"power_base": 25.0, "power_per_rank": 6.0, "range": 540.0,
		"mark_on_hit": {"bonus_pct": 0.25, "duration": 5.0},
	},
	"astral_moonfall": {
		"name": "Moonfall", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Drop a slice of moonlight that burns enemies and mends allies.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 35.0, "power_per_rank": 9.0, "range": 0.0, "radius": 220.0,
		"duration_base": 3.5, "duration_per_rank": 0.4,
	},
	"astral_luminous_ward": {
		"name": "Luminous Ward", "archetype": Archetype.SUMMON_SPIRIT,
		"description": "Set a wisp of cool fire on watch.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 10.0, "power_per_rank": 3.0, "range": 380.0,
		"duration_base": 15.0, "duration_per_rank": 1.0, "summon_count": 1,
	},
	"astral_ethereal_link": {
		"name": "Ethereal Link", "archetype": Archetype.BUFF_SELF,
		"description": "Hold the party's spirits together for a while.",
		"cooldown_base": 15.0, "cooldown_per_rank": -1.4, "cooldown_min": 9.0,
		"power_base": 25.0, "power_per_rank": 6.0, "radius": 240.0,
		"duration_base": 6.0, "duration_per_rank": 0.6,
		"buff_stats": {"damage_taken_mult": 0.8}, "target_scope": "allies",
	},
	"astral_bright_tether": {
		"name": "Bright Tether", "archetype": Archetype.CONE_BURST,
		"description": "Send out a fan of serene but searing light.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 30.0, "power_per_rank": 8.0, "radius": 340.0,
	},
	"astral_ghastly_touch": {
		"name": "Ghastly Touch", "archetype": Archetype.NUKE_BOLT,
		"description": "A single luminous tap that takes its due with interest.",
		"cooldown_base": 9.5, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 30.0, "power_per_rank": 8.0, "range": 520.0, "lifesteal_pct": 0.5,
	},
	"astral_wisp_nova": {
		"name": "Wisp Nova", "archetype": Archetype.BLINK,
		"description": "Burst outward in every direction, though only you lead.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 28.0, "power_per_rank": 7.0, "dash_distance": 250.0, "radius": 180.0,
	},
	"astral_seance": {
		"name": "Seance", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Let the whisper of a dozen voices rise from the ground.",
		"cooldown_base": 18.0, "cooldown_per_rank": -1.6, "cooldown_min": 10.5,
		"power_base": 20.0, "power_per_rank": 5.0, "range": 0.0, "radius": 260.0,
		"duration_base": 3.0, "duration_per_rank": 0.3,
	},
	# --- Rime -------------------------------------------------------------------------------
	"rime_ice_imprisonment": {
		"name": "Ice Imprisonment", "archetype": Archetype.NUKE_BOLT,
		"description": "Bury an enemy beneath a coffin of unmelting ice.",
		"cooldown_base": 9.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.2,
		"power_base": 65.0, "power_per_rank": 17.0, "range": 540.0,
		"slow_on_hit": {"factor": 0.6, "duration": 1.8},
	},
	"rime_chilling_touch": {
		"name": "Chilling Touch", "archetype": Archetype.BUFF_SELF,
		"description": "Let the cold sharpen every movement.",
		"cooldown_base": 14.0, "cooldown_per_rank": -1.3, "cooldown_min": 8.5,
		"power_base": 70.0, "power_per_rank": 18.0,
		"duration_base": 6.0, "duration_per_rank": 0.6,
		"buff_stats": {"attack_interval_mult": 0.7}, "target_scope": "self",
	},
	"rime_glacier_blast": {
		"name": "Glacier Blast", "archetype": Archetype.RADIUS_BURST,
		"description": "Split the ground with an expanding layer of ice.",
		"cooldown_base": 18.0, "cooldown_per_rank": -1.6, "cooldown_min": 10.5,
		"power_base": 75.0, "power_per_rank": 19.0, "range": 0.0, "radius": 280.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.0},
	},
	"rime_freezing_field": {
		"name": "Freezing Field", "archetype": Archetype.ZONE_CHANNEL,
		"description": "Blanket the arena in a killing field of absolute cold.",
		"cooldown_base": 90.0, "cooldown_per_rank": -8.0, "cooldown_min": 50.0,
		"power_base": 110.0, "power_per_rank": 28.0, "range": 0.0, "radius": 400.0,
		"duration_base": 5.0, "duration_per_rank": 0.5,
	},
	"rime_hailstorm": {
		"name": "Hailstorm", "archetype": Archetype.CONE_BURST,
		"description": "Hurl a sheeting torrent of broken ice.",
		"cooldown_base": 6.0, "cooldown_per_rank": -0.6, "cooldown_min": 3.4,
		"power_base": 30.0, "power_per_rank": 8.0, "radius": 340.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.0},
	},
	"rime_cold_rush": {
		"name": "Cold Rush", "archetype": Archetype.DASH_STRIKE,
		"description": "Skate across the battlefield on a wave of runaway ice.",
		"cooldown_base": 8.5, "cooldown_per_rank": -0.8, "cooldown_min": 4.8,
		"power_base": 28.0, "power_per_rank": 7.0, "dash_distance": 310.0, "radius": 65.0,
	},
	"rime_frost_armor": {
		"name": "Frost Armor", "archetype": Archetype.SHIELD_BURST,
		"description": "Throw a veil of packed ice over yourself.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 8.0,
		"power_base": 60.0, "power_per_rank": 15.0,
		"duration_base": 5.0, "duration_per_rank": 0.6, "target_scope": "self",
	},
	"rime_whiteout": {
		"name": "Whiteout", "archetype": Archetype.CONE_BURST,
		"description": "Cancel the sun and drop a wall of frozen air.",
		"cooldown_base": 6.5, "cooldown_per_rank": -0.6, "cooldown_min": 3.6,
		"power_base": 32.0, "power_per_rank": 8.0, "radius": 240.0,
		"slow_on_hit": {"factor": 0.5, "duration": 2.0},
	},
	"rime_winters_grasp": {
		"name": "Winter's Grasp", "archetype": Archetype.PIT_SLOW,
		"description": "The cold closes around everything near for a long moment.",
		"cooldown_base": 10.0, "cooldown_per_rank": -0.9, "cooldown_min": 5.5,
		"power_base": 15.0, "power_per_rank": 4.0, "range": 0.0, "radius": 240.0,
		"slow_on_hit": {"factor": 0.5, "duration": 3.0},
	},
	"rime_cleave": {
		"name": "Cleave", "archetype": Archetype.NUKE_BOLT,
		"description": "Split whatever you touch with a blade of packed ice.",
		"cooldown_base": 7.0, "cooldown_per_rank": -0.7, "cooldown_min": 3.8,
		"power_base": 55.0, "power_per_rank": 14.0, "range": 480.0,
	},
	"rime_thaw": {
		"name": "Thaw", "archetype": Archetype.SELF_HEAL,
		"description": "Step out of your own shell as yourself again.",
		"cooldown_base": 13.0, "cooldown_per_rank": -1.2, "cooldown_min": 7.5,
		"power_base": 45.0, "power_per_rank": 12.0,
	},
	"rime_frozen_ward": {
		"name": "Frozen Ward", "archetype": Archetype.SUMMON_SPIRIT,
		"description": "Set a fist of cold magic on watch that lashes at intruders.",
		"cooldown_base": 16.0, "cooldown_per_rank": -1.5, "cooldown_min": 9.5,
		"power_base": 10.0, "power_per_rank": 3.0, "range": 380.0,
		"duration_base": 16.0, "duration_per_rank": 1.0, "summon_count": 1,
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


## Fixed 4-ability kit — agent-based tests lean on this for two-stage targeting + sim casts.
## Order: Q, E, R. Callers build the 4th slot from the pool.
static func kit_ability_ids(class_id: String) -> Array[String]:
	var class_data := by_id(class_id)
	var out: Array[String] = []
	for slot in ["kit_q", "kit_e", "kit_r"]:
		var id := str(class_data.get(slot, ""))
		if not id.is_empty():
			out.append(id)
	return out


## "Kit" = Q, E, R locked; the alternate (slot index 2 in PlayerProfile.loadout_for) comes
## from the ability_pool (first non-kit entry).
static func kit_for(class_id: String) -> Array[String]:
	return kit_ability_ids(class_id)


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


## Hero kit wiring + world routing --------------------------------------------------------

const _WORLD_BY_ID := {
	"tobor": World.IRON_FOUNDRY,
	"arclight": World.IRON_FOUNDRY,
	"bulwark": World.IRON_FOUNDRY,
	"warden": World.IRON_FOUNDRY,
	"frostbinder": World.IRON_FOUNDRY,
	"cinder": World.ASHEN_CALDERA,
	"pyra": World.ASHEN_CALDERA,
	"slag": World.ASHEN_CALDERA,
	"ember": World.ASHEN_CALDERA,
	"thorn": World.VERDANT_WILDS,
	"willow": World.VERDANT_WILDS,
	"stump": World.VERDANT_WILDS,
	"sage": World.VERDANT_WILDS,
	"volt": World.STORM_COURT,
	"nebula": World.STORM_COURT,
	"astral": World.STORM_COURT,
	"rime": World.STORM_COURT,
}


static func world_of(class_id: String) -> int:
	return int(_WORLD_BY_ID.get(class_id, World.IRON_FOUNDRY))


static func name_of(class_id: String) -> String:
	return str(by_id(class_id).get("name", class_id))


static func kit_q(class_id: String) -> String:
	return str(by_id(class_id).get("kit_q", ""))


static func kit_e(class_id: String) -> String:
	return str(by_id(class_id).get("kit_e", ""))


static func kit_r(class_id: String) -> String:
	return str(by_id(class_id).get("kit_r", ""))

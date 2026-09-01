class_name KitFxLibrary
extends RefCounted

## Pure-data styling library for kit ability VFX.
## Maps each kit_ability_id to vector styling traits consumed by _play_ability_effect
## to tint LightningEffect / ZonePulse instances per ability.
##
## Trait keys:
##   primary_color   — hex String, main bolt/ring tint (hero effect_color)
##   secondary_color — hex String, chain/impact tint (hero accent_color)
##   pulse_count     — int, number of expanding pulse rings / stacking bursts
##   ribbon_count    — int, number of trailing ribbons / chain strands
##   style           — "fire" | "nature" | "storm" | "arcane"

const KIT_VISUALS: Dictionary = {
	# ── Cinder (fire) ──────────────────────────────────────────────
	"cinder_whirling_flame": {
		"primary_color": "ffb347",
		"secondary_color": "ffd36b",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "fire",
	},
	"cinder_fiery_assault": {
		"primary_color": "ffb347",
		"secondary_color": "ff8a3d",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "fire",
	},
	"cinder_blazing_strike": {
		"primary_color": "ffc46b",
		"secondary_color": "ffd36b",
		"pulse_count": 1,
		"ribbon_count": 2,
		"style": "fire",
	},
	"cinder_blazing_pillar": {
		"primary_color": "ff8a3d",
		"secondary_color": "ffe14a",
		"pulse_count": 4,
		"ribbon_count": 6,
		"style": "fire",
	},
	# ── Pyra (fire) ────────────────────────────────────────────────
	"pyra_sticky_bomb": {
		"primary_color": "ff8a5c",
		"secondary_color": "ffe14a",
		"pulse_count": 2,
		"ribbon_count": 2,
		"style": "fire",
	},
	"pyra_boom_dust": {
		"primary_color": "ff8a5c",
		"secondary_color": "ffc46b",
		"pulse_count": 3,
		"ribbon_count": 3,
		"style": "fire",
	},
	"pyra_boomerang_knife": {
		"primary_color": "ffe14a",
		"secondary_color": "ff8a5c",
		"pulse_count": 1,
		"ribbon_count": 3,
		"style": "fire",
	},
	"pyra_air_strike": {
		"primary_color": "ff6b2a",
		"secondary_color": "ffe14a",
		"pulse_count": 4,
		"ribbon_count": 5,
		"style": "fire",
	},
	# ── Slag (fire) ────────────────────────────────────────────────
	"slag_steam_bath": {
		"primary_color": "ff6b2a",
		"secondary_color": "ffc46b",
		"pulse_count": 3,
		"ribbon_count": 2,
		"style": "fire",
	},
	"slag_volcanic_touch": {
		"primary_color": "ff6b2a",
		"secondary_color": "ff8a3d",
		"pulse_count": 1,
		"ribbon_count": 2,
		"style": "fire",
	},
	"slag_lava_slam": {
		"primary_color": "ff5a1e",
		"secondary_color": "ff8a3d",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "fire",
	},
	"slag_eruption": {
		"primary_color": "ff6b2a",
		"secondary_color": "ffe14a",
		"pulse_count": 5,
		"ribbon_count": 7,
		"style": "fire",
	},
	# ── Ember (fire / druidic flame) ───────────────────────────────
	"ember_entangle": {
		"primary_color": "ffb46b",
		"secondary_color": "8cff4a",
		"pulse_count": 2,
		"ribbon_count": 4,
		"style": "fire",
	},
	"ember_healing_wave": {
		"primary_color": "ffd36b",
		"secondary_color": "8cff4a",
		"pulse_count": 4,
		"ribbon_count": 3,
		"style": "fire",
	},
	"ember_thunder_dance": {
		"primary_color": "ffb46b",
		"secondary_color": "ffe14a",
		"pulse_count": 3,
		"ribbon_count": 5,
		"style": "fire",
	},
	"ember_unbreakable": {
		"primary_color": "ffc46b",
		"secondary_color": "ffd36b",
		"pulse_count": 2,
		"ribbon_count": 2,
		"style": "fire",
	},
	# ── Thorn (nature / poison) ────────────────────────────────────
	"thorn_poison_spray": {
		"primary_color": "a8e05c",
		"secondary_color": "d9ff8a",
		"pulse_count": 2,
		"ribbon_count": 5,
		"style": "nature",
	},
	"thorn_toxin_ward": {
		"primary_color": "a8e05c",
		"secondary_color": "7dffb4",
		"pulse_count": 3,
		"ribbon_count": 2,
		"style": "nature",
	},
	"thorn_toxin_outbreak": {
		"primary_color": "8cff4a",
		"secondary_color": "d9ff8a",
		"pulse_count": 4,
		"ribbon_count": 6,
		"style": "nature",
	},
	"thorn_poison_burst": {
		"primary_color": "8ce04a",
		"secondary_color": "d9ff8a",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "nature",
	},
	# ── Willow (nature / wind) ─────────────────────────────────────
	"willow_swift_strike": {
		"primary_color": "d4ff8f",
		"secondary_color": "b8ff6b",
		"pulse_count": 1,
		"ribbon_count": 3,
		"style": "nature",
	},
	"willow_forsaken_shot": {
		"primary_color": "d4ff8f",
		"secondary_color": "7dffb4",
		"pulse_count": 1,
		"ribbon_count": 4,
		"style": "nature",
	},
	"willow_grasp_of_nature": {
		"primary_color": "b8ff6b",
		"secondary_color": "8cff4a",
		"pulse_count": 2,
		"ribbon_count": 5,
		"style": "nature",
	},
	"willow_strangling_vines": {
		"primary_color": "b8ff6b",
		"secondary_color": "d9ff8a",
		"pulse_count": 3,
		"ribbon_count": 7,
		"style": "nature",
	},
	# ── Stump (nature / bark & beast) ──────────────────────────────
	"stump_rally": {
		"primary_color": "c49a55",
		"secondary_color": "d4b06b",
		"pulse_count": 3,
		"ribbon_count": 2,
		"style": "nature",
	},
	"stump_camouflage": {
		"primary_color": "c49a55",
		"secondary_color": "8cff4a",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "nature",
	},
	"stump_call_of_the_wild": {
		"primary_color": "d4b06b",
		"secondary_color": "c49a55",
		"pulse_count": 4,
		"ribbon_count": 4,
		"style": "nature",
	},
	"stump_overgrowth": {
		"primary_color": "8ee04a",
		"secondary_color": "d4b06b",
		"pulse_count": 4,
		"ribbon_count": 7,
		"style": "nature",
	},
	# ── Sage (nature / fae) ────────────────────────────────────────
	"sage_grace_of_the_nymph": {
		"primary_color": "ffe3ec",
		"secondary_color": "ffd9e0",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "nature",
	},
	"sage_volatile_pod": {
		"primary_color": "ffe3ec",
		"secondary_color": "8cff4a",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "nature",
	},
	"sage_natures_veil": {
		"primary_color": "d4ff8f",
		"secondary_color": "ffd9e0",
		"pulse_count": 3,
		"ribbon_count": 5,
		"style": "nature",
	},
	"sage_charm": {
		"primary_color": "ffd9e0",
		"secondary_color": "ffe3ec",
		"pulse_count": 2,
		"ribbon_count": 6,
		"style": "nature",
	},
	# ── Volt (storm) ───────────────────────────────────────────────
	"volt_gust": {
		"primary_color": "b0e8ff",
		"secondary_color": "7af0ff",
		"pulse_count": 2,
		"ribbon_count": 4,
		"style": "storm",
	},
	"volt_wind_shield": {
		"primary_color": "b0e8ff",
		"secondary_color": "dbe9ff",
		"pulse_count": 3,
		"ribbon_count": 3,
		"style": "storm",
	},
	"volt_storm_cloud": {
		"primary_color": "7af0ff",
		"secondary_color": "b48cff",
		"pulse_count": 4,
		"ribbon_count": 5,
		"style": "storm",
	},
	"volt_typhoon": {
		"primary_color": "7af0ff",
		"secondary_color": "b0e8ff",
		"pulse_count": 5,
		"ribbon_count": 6,
		"style": "storm",
	},
	# ── Nebula (arcane / time) ─────────────────────────────────────
	"nebula_time_shift": {
		"primary_color": "cbb0ff",
		"secondary_color": "b48cff",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "arcane",
	},
	"nebula_curse_of_ages": {
		"primary_color": "cbb0ff",
		"secondary_color": "8a6de0",
		"pulse_count": 3,
		"ribbon_count": 5,
		"style": "arcane",
	},
	"nebula_time_freeze": {
		"primary_color": "b48cff",
		"secondary_color": "dbe9ff",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "arcane",
	},
	"nebula_chronosphere": {
		"primary_color": "b48cff",
		"secondary_color": "cbb0ff",
		"pulse_count": 5,
		"ribbon_count": 6,
		"style": "arcane",
	},
	# ── Astral (arcane / radiant) ──────────────────────────────────
	"astral_essence_link": {
		"primary_color": "fff4c4",
		"secondary_color": "ffe9a0",
		"pulse_count": 2,
		"ribbon_count": 4,
		"style": "arcane",
	},
	"astral_guardian_angel": {
		"primary_color": "fff4c4",
		"secondary_color": "ffffff",
		"pulse_count": 4,
		"ribbon_count": 5,
		"style": "arcane",
	},
	"astral_essence_projection": {
		"primary_color": "ffe9a0",
		"secondary_color": "fff4c4",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "arcane",
	},
	"astral_as_one": {
		"primary_color": "fff4c4",
		"secondary_color": "b48cff",
		"pulse_count": 5,
		"ribbon_count": 6,
		"style": "arcane",
	},
	# ── Rime (arcane / ice) ────────────────────────────────────────
	"rime_ice_imprisonment": {
		"primary_color": "cfe8ff",
		"secondary_color": "3a5a8c",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "arcane",
	},
	"rime_chilling_touch": {
		"primary_color": "cfe8ff",
		"secondary_color": "a8dcff",
		"pulse_count": 1,
		"ribbon_count": 2,
		"style": "arcane",
	},
	"rime_bitter_chill": {
		"primary_color": "a8dcff",
		"secondary_color": "dbe9ff",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "arcane",
	},
	"rime_absolute_zero": {
		"primary_color": "dbe9ff",
		"secondary_color": "cfe8ff",
		"pulse_count": 5,
		"ribbon_count": 7,
		"style": "arcane",
	},
}


static func kit_visual(ability_id: String) -> Dictionary:
	return KIT_VISUALS.get(ability_id, {})

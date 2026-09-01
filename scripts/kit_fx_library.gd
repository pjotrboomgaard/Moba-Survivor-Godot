class_name KitFxLibrary
extends RefCounted

## Pure-data styling library for kit ability VFX.
## Maps each canonical kit_ability_id (PlayerClass.kit_q / kit_e / kit_r) to
## vector styling traits consumed by LightningEffect / AbilityVfx.
##
## Trait keys:
##   primary_color   — hex String, main bolt/ring tint (hero effect_color)
##   secondary_color — hex String, chain/impact tint (hero accent_color)
##   pulse_count     — int, number of expanding pulse rings / stacking bursts
##   ribbon_count    — int, number of trailing ribbons / chain strands
##   style           — "fire" | "nature" | "storm" | "arcane" | "steam" | "ice"

const KIT_VISUALS: Dictionary = {
	# ── Tobor (Wrench / Engineer) ────────────────────────────────────────────
	"tobor_steam_keg": {
		"primary_color": "ffd36b",
		"secondary_color": "ff8a3d",
		"pulse_count": 2,
		"ribbon_count": 2,
		"style": "steam",
	},
	"tobor_steam_turret": {
		"primary_color": "ffd36b",
		"secondary_color": "ff8a3d",
		"pulse_count": 2,
		"ribbon_count": 1,
		"style": "steam",
	},
	"tobor_energy_field": {
		"primary_color": "7af0ff",
		"secondary_color": "ffd36b",
		"pulse_count": 4,
		"ribbon_count": 6,
		"style": "arcane",
	},
	# ── Arclight (Joule / Thunderbringer) ────────────────────────────────────
	"arclight_blast_of_lightning": {
		"primary_color": "fff8a8",
		"secondary_color": "7af0ff",
		"pulse_count": 1,
		"ribbon_count": 3,
		"style": "storm",
	},
	"arclight_chain_lightning": {
		"primary_color": "b0e8ff",
		"secondary_color": "fff8a8",
		"pulse_count": 2,
		"ribbon_count": 5,
		"style": "storm",
	},
	"arclight_thundergods_wrath": {
		"primary_color": "fff8a8",
		"secondary_color": "b48cff",
		"pulse_count": 4,
		"ribbon_count": 6,
		"style": "storm",
	},
	# ── Bulwark (Tremor / Behemoth) ──────────────────────────────────────────
	"bulwark_fissure": {
		"primary_color": "d4a06b",
		"secondary_color": "8a5a2a",
		"pulse_count": 1,
		"ribbon_count": 2,
		"style": "nature",
	},
	"bulwark_heavyweight": {
		"primary_color": "c49a55",
		"secondary_color": "ffe14a",
		"pulse_count": 2,
		"ribbon_count": 2,
		"style": "nature",
	},
	"bulwark_echo_slam": {
		"primary_color": "d4b06b",
		"secondary_color": "ffe14a",
		"pulse_count": 4,
		"ribbon_count": 3,
		"style": "nature",
	},
	# ── Warden (Totem / Pollywog) ────────────────────────────────────────────
	"warden_tongue_tied": {
		"primary_color": "8cff4a",
		"secondary_color": "c49a55",
		"pulse_count": 1,
		"ribbon_count": 2,
		"style": "nature",
	},
	"warden_voodoo_wards": {
		"primary_color": "d4b06b",
		"secondary_color": "8cff4a",
		"pulse_count": 2,
		"ribbon_count": 3,
		"style": "nature",
	},
	"warden_life_drain": {
		"primary_color": "ff5a5a",
		"secondary_color": "8cff4a",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "fire",
	},
	# ── Cinder (Blaze / Pyro) ────────────────────────────────────────────────
	"cinder_dragon_fire": {
		"primary_color": "ffb347",
		"secondary_color": "ffd36b",
		"pulse_count": 2,
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
	"cinder_pillar_of_flame": {
		"primary_color": "ff8a3d",
		"secondary_color": "ffe14a",
		"pulse_count": 4,
		"ribbon_count": 6,
		"style": "fire",
	},
	# ── Pyra (Barrage / Bombardier) ──────────────────────────────────────────
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
	"pyra_air_strike": {
		"primary_color": "ff6b2a",
		"secondary_color": "ffe14a",
		"pulse_count": 4,
		"ribbon_count": 5,
		"style": "fire",
	},
	# ── Slag (Vulcan / Magmus) ───────────────────────────────────────────────
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
	"slag_eruption": {
		"primary_color": "ff6b2a",
		"secondary_color": "ffe14a",
		"pulse_count": 5,
		"ribbon_count": 7,
		"style": "fire",
	},
	# ── Ember (Witchfire / Demented) ─────────────────────────────────────────
	"ember_entangle": {
		"primary_color": "ffb46b",
		"secondary_color": "8cff4a",
		"pulse_count": 2,
		"ribbon_count": 4,
		"style": "nature",
	},
	"ember_healing_wave": {
		"primary_color": "ffd36b",
		"secondary_color": "8cff4a",
		"pulse_count": 4,
		"ribbon_count": 3,
		"style": "nature",
	},
	"ember_unbreakable": {
		"primary_color": "ffc46b",
		"secondary_color": "ffd36b",
		"pulse_count": 2,
		"ribbon_count": 2,
		"style": "fire",
	},
	# ── Thorn (Venom / Slither) ──────────────────────────────────────────────
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
	"thorn_poison_burst": {
		"primary_color": "8ce04a",
		"secondary_color": "d9ff8a",
		"pulse_count": 4,
		"ribbon_count": 5,
		"style": "nature",
	},
	# ── Willow (Flick / Forsaken Archer) ─────────────────────────────────────
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
	"willow_wall_of_roots": {
		"primary_color": "b8ff6b",
		"secondary_color": "d9ff8a",
		"pulse_count": 3,
		"ribbon_count": 7,
		"style": "nature",
	},
	# ── Stump (Keeper) ───────────────────────────────────────────────────────
	"stump_natures_rally": {
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
	"stump_overgrowth": {
		"primary_color": "8ee04a",
		"secondary_color": "d4b06b",
		"pulse_count": 4,
		"ribbon_count": 7,
		"style": "nature",
	},
	# ── Sage (Nymphel / Nymphora) ────────────────────────────────────────────
	"sage_grace": {
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
	"sage_charm": {
		"primary_color": "ffd9e0",
		"secondary_color": "ffe3ec",
		"pulse_count": 2,
		"ribbon_count": 6,
		"style": "nature",
	},
	# ── Volt (Gale / Zephyr) ─────────────────────────────────────────────────
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
	"volt_typhoon": {
		"primary_color": "7af0ff",
		"secondary_color": "b0e8ff",
		"pulse_count": 5,
		"ribbon_count": 6,
		"style": "storm",
	},
	# ── Nebula (Aeon / Chronos) ──────────────────────────────────────────────
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
	"nebula_chronofield": {
		"primary_color": "b48cff",
		"secondary_color": "cbb0ff",
		"pulse_count": 5,
		"ribbon_count": 6,
		"style": "arcane",
	},
	# ── Astral (Lumina / Empath) ─────────────────────────────────────────────
	"astral_essence_link": {
		"primary_color": "fff4c4",
		"secondary_color": "ffe9a0",
		"pulse_count": 2,
		"ribbon_count": 4,
		"style": "arcane",
	},
	"astral_ward_of_light": {
		"primary_color": "fff4c4",
		"secondary_color": "ffffff",
		"pulse_count": 4,
		"ribbon_count": 5,
		"style": "arcane",
	},
	"astral_as_one": {
		"primary_color": "fff4c4",
		"secondary_color": "b48cff",
		"pulse_count": 5,
		"ribbon_count": 6,
		"style": "arcane",
	},
	# ── Rime (Glacier / Glacius) ─────────────────────────────────────────────
	"rime_ice_imprisonment": {
		"primary_color": "cfe8ff",
		"secondary_color": "3a5a8c",
		"pulse_count": 3,
		"ribbon_count": 4,
		"style": "ice",
	},
	"rime_chilling_touch": {
		"primary_color": "cfe8ff",
		"secondary_color": "a8dcff",
		"pulse_count": 1,
		"ribbon_count": 2,
		"style": "ice",
	},
	"rime_freezing_field": {
		"primary_color": "dbe9ff",
		"secondary_color": "cfe8ff",
		"pulse_count": 5,
		"ribbon_count": 7,
		"style": "ice",
	},
}


static func kit_visual(ability_id: String) -> Dictionary:
	return KIT_VISUALS.get(ability_id, {})


## Applies KIT_VISUALS styling onto a LightningEffect. Call after setting
## style/points so pulse/ribbon counts can influence the vector draw.
static func apply_to_lightning(fx: LightningEffect, kit_id: String) -> void:
	if fx == null:
		return
	var data := kit_visual(kit_id)
	if data.is_empty():
		return
	var primary := str(data.get("primary_color", ""))
	var secondary := str(data.get("secondary_color", ""))
	if primary != "":
		fx.main_color = Color(primary)
	if secondary != "":
		fx.chain_color = Color(secondary)
	fx.pulse_count = int(data.get("pulse_count", 1))
	fx.ribbon_count = int(data.get("ribbon_count", 1))
	fx.style_tag = str(data.get("style", "storm"))
	fx.queue_redraw()

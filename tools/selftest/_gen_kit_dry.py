import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requests")
os.makedirs(ROOT, exist_ok=True)

# hero -> 4 loadout slots in the order PlayerProfile.loadout_for() composes them:
#   slot0 = kit_q, slot1 = kit_e, slot2 = first pool id NOT in kit, slot3 = kit_r.
# Ids verified against scripts/player_class.gd CLASSES (kit_q/kit_e/kit_r + ability_pool).
# Two-stage press-flow comes from scripts/player.gd TARGETED_ABILITIES: abilities absent
# from that table (or "instant") fire on a single tap; "unit" needs a live enemy at the
# aim point, "point"/"vector" use the aim offset directly.
HEROES = {
    "tobor":    ["tobor_steam_keg", "tobor_steam_turret", "tobor_energy_absorption", "tobor_energy_field"],
    "arclight": ["arclight_blast_of_lightning", "arclight_chain_lightning", "arclight_static_bolt", "arclight_thundergods_wrath"],
    "bulwark":  ["bulwark_fissure", "bulwark_heavyweight", "bulwark_shockwave_strike", "bulwark_echo_slam"],
    "warden":   ["warden_tongue_tied", "warden_voodoo_wards", "warden_mending_wave", "warden_life_drain"],
    "cinder":   ["cinder_dragon_fire", "cinder_fiery_assault", "cinder_whirling_flame", "cinder_pillar_of_flame"],
    "pyra":     ["pyra_sticky_bomb", "pyra_boom_dust", "pyra_bombardment", "pyra_air_strike"],
    "slag":     ["slag_steam_bath", "slag_volcanic_touch", "slag_lava_surge", "slag_eruption"],
    "ember":    ["ember_entangle", "ember_healing_wave", "ember_storm_cloud", "ember_unbreakable"],
    "thorn":    ["thorn_poison_spray", "thorn_toxin_ward", "thorn_toxicity", "thorn_poison_burst"],
    "willow":   ["willow_swift_strike", "willow_forsaken_shot", "willow_volley", "willow_strangling_vines"],
    "stump":    ["stump_natures_rally", "stump_camouflage", "stump_natures_veil", "stump_overgrowth"],
    "sage":     ["sage_grace", "sage_volatile_pod", "sage_nymphoras_kiss", "sage_charm"],
    "volt":     ["volt_gust", "volt_wind_shield", "volt_wind_control", "volt_typhoon"],
    "nebula":   ["nebula_time_shift", "nebula_curse_of_ages", "nebula_rewind", "nebula_chronofield"],
    "astral":   ["astral_essence_link", "astral_ward_of_light", "astral_spirit_bond", "astral_as_one"],
    "rime":     ["rime_ice_imprisonment", "rime_chilling_touch", "rime_glacier_blast", "rime_freezing_field"],
}

CAST_TIMES = [0.0, 2.0, 4.0, 6.0]
SNAP_TIMES = {1.0: "t1", 3.0: "t3", 5.0: "t5", 8.0: "t8"}

for hero, abilities in HEROES.items():
    events = [
        # Live targets so any unit-mode ability has something to hit; brute so effects
        # that scale on target presence still have one alive late in the run.
        {"t": 0.02, "kind": "spawn", "at": [120, 0], "type": "grunt"},
        {"t": 0.02, "kind": "spawn", "at": [-120, 0], "type": "grunt"},
        {"t": 0.02, "kind": "spawn", "at": [0, 120], "type": "grunt"},
        {"t": 0.02, "kind": "spawn", "at": [0, -120], "type": "brute", "hp_mult": 12.0},
    ]
    for slot, t in enumerate(CAST_TIMES):
        events.append({"t": t + 0.02, "kind": "aim", "at": [120, 0]})
        events.append({"t": t + 0.05, "kind": "cast", "slot": slot})
        events.append({"t": t + 0.15, "kind": "cast", "slot": slot})  # confirm tap for two-stage kits
    for t, label in SNAP_TIMES.items():
        events.append({"t": t, "kind": "snap", "label": label})
    events.append({"t": 9.0, "kind": "report"})
    events.sort(key=lambda e: float(e["t"]))

    doc = {
        "hero": hero,
        "comment": "Kit coverage dry-run: cast each of the 4 loadout slots (Q/E/pool-alt/R) at 0s,2s,4s,6s; snap at 1s,3s,5s,8s.",
        "abilities": abilities,
        "expected_casts": abilities,
        "events": events,
    }
    out = os.path.join(ROOT, "%s_kit_dry.json" % hero)
    with open(out, "w") as f:
        json.dump(doc, f, indent=2)
    print("wrote %s" % out)
print("done: %d heroes" % len(HEROES))

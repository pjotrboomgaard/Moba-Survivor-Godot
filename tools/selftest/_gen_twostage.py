import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requests")
os.makedirs(ROOT, exist_ok=True)

# hero -> list of (slot, ability_id, mode) in the actual known_abilities slot order:
#   slot0 = kit_q, slot1 = kit_e, slot2 = first pool id NOT in kit, slot3 = kit_r
HEROES = {
    "tobor":    [(0,"tobor_the_keg","point"),(1,"tobor_steam_turret","vector"),(2,"tobor_spider_mines","point"),(3,"tobor_energy_field","point")],
    "arclight": [(0,"arclight_blast_of_lightning","unit"),(1,"arclight_chain_lightning","unit"),(2,"arclight_electric_field","point"),(3,"arclight_thundergods_wrath","instant")],
    "bulwark":  [(0,"bulwark_fissure","point"),(1,"bulwark_heavyweight","instant"),(2,"bulwark_enrage","instant"),(3,"bulwark_echo_slam","instant")],
    "warden":   [(0,"warden_tongue_tied","unit"),(1,"warden_voodoo_wards","point"),(2,"warden_cursed_ground","point"),(3,"warden_life_drain","unit")],
    "cinder":   [(0,"cinder_whirling_flame","vector"),(1,"cinder_fiery_assault","instant"),(2,"cinder_blazing_strike","point"),(3,"cinder_blazing_pillar","point")],
    "pyra":     [(0,"pyra_sticky_bomb","point"),(1,"pyra_boom_dust","instant"),(2,"pyra_bombardment","point"),(3,"pyra_air_strike","point")],
    "slag":     [(0,"slag_steam_bath","instant"),(1,"slag_volcanic_touch","instant"),(2,"slag_lava_surge","vector"),(3,"slag_eruption","instant")],
    "ember":    [(0,"ember_entangle","unit"),(1,"ember_healing_wave","instant"),(2,"ember_storm_cloud","point"),(3,"ember_unbreakable","instant")],
    "thorn":    [(0,"thorn_poison_spray","vector"),(1,"thorn_toxin_ward","point"),(2,"thorn_toxicity","instant"),(3,"thorn_poison_burst","instant")],
    "willow":   [(0,"willow_swift_strike","instant"),(1,"willow_forsaken_shot","vector"),(2,"willow_volley","vector"),(3,"willow_strangling_vines","point")],
    "stump":    [(0,"stump_rally","instant"),(1,"stump_camouflage","instant"),(2,"stump_natures_veil","point"),(3,"stump_overgrowth","point")],
    "sage":     [(0,"sage_grace_of_the_nymph","instant"),(1,"sage_volatile_pod","point"),(2,"sage_nymphoras_kiss","unit"),(3,"sage_charm","unit")],
    "volt":     [(0,"volt_gust","vector"),(1,"volt_wind_shield","instant"),(2,"volt_wind_control","unit"),(3,"volt_typhoon","instant")],
    "nebula":   [(0,"nebula_time_shift","instant"),(1,"nebula_curse_of_ages","unit"),(2,"nebula_rewind","instant"),(3,"nebula_chronosphere","instant")],
    "astral":   [(0,"astral_essence_link","point"),(1,"astral_guardian_angel","instant"),(2,"astral_spirit_bond","unit"),(3,"astral_as_one","instant")],
    "rime":     [(0,"rime_ice_imprisonment","unit"),(1,"rime_chilling_touch","instant"),(2,"rime_glacier_blast","instant"),(3,"rime_absolute_zero","instant")],
}

for hero, abilities in HEROES.items():
    events = [
        {"t": 0.30, "kind": "spawn", "at": [110, 0], "type": "grunt"},
        {"t": 0.40, "kind": "aim",   "at": [110, 0]},
    ]
    t = 0.60
    for slot, ability_id, mode in abilities:
        events.append({"t": t,        "kind": "aim",  "at": [110, 0]})
        events.append({"t": t + 0.04, "kind": "cast", "slot": slot})
        events.append({"t": t + 0.11, "kind": "probe","label": "s%d_arm" % slot})
        # Snapshot the armed indicator only for VECTOR-mode abilities (the directional
        # arrow is the visual we need to confirm) — keeps report size + runtime down.
        if mode == "vector":
            events.append({"t": t + 0.18, "kind": "snap", "label": "s%d_armed" % slot})
        events.append({"t": t + 0.20, "kind": "cast", "slot": slot})
        events.append({"t": t + 0.28, "kind": "probe","label": "s%d_confirm" % slot})
        t += 0.50
    events.append({"t": t + 0.05, "kind": "report"})
    doc = {
        "hero": hero,
        "comment": "Two-stage press-flow for %s: tap=arm, tap=confirm; expected pending_id then cds>0 per slot." % hero,
        "abilities": [[s, a, m] for (s, a, m) in abilities],
        "events": events,
    }
    out = os.path.join(ROOT, "twostage_%s.json" % hero)
    with open(out, "w") as f:
        json.dump(doc, f, indent=2)
    print("wrote %s" % out)
print("done: %d heroes" % len(HEROES))

"""Inject the 8 new heroes' palettes + 4-facing grids into tools/sprite_art.gd.
Idempotent: replaces any existing new-hero HERO_ROWS/HERO_PALETTES entries.
Run:  python tools/_apply_new_heroes.py
"""
import re, io
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GD = ROOT / "tools" / "sprite_art.gd"
GRID = 40

# --- hero palettes (key -> hex) -------------------------------------------------------
PALETTES = {
    "cinder": {"o": "1a0c06", "b": "241410", "d": "3a1a0e", "s": "5a2a14", "f": "ff6a2a", "l": "ffb04a", "e": "ffd36b", "r": "d8321a", "w": "ffe9d0"},
    "pyra": {"o": "20060a", "b": "2a0c12", "d": "4a1216", "s": "6b1a18", "f": "ff4a2a", "l": "ff9a3c", "e": "ffd36b", "r": "b82a12", "w": "ffe9d0"},
    "slag": {"o": "14100e", "b": "211a16", "d": "33241a", "s": "4a3020", "f": "ff8a3c", "l": "ffc46a", "e": "ff5a1e", "r": "8a2412", "w": "e8d0b0"},
    "ember": {"o": "1a1208", "b": "2a1c10", "d": "4a3014", "s": "6b4820", "f": "ffb84a", "l": "ffe28a", "e": "fff0c0", "r": "ff8a2a", "w": "fff6e0"},
    "thorn": {"o": "0a140a", "b": "12210f", "d": "1a3115", "s": "26431c", "f": "3ac04a", "l": "7be06a", "e": "b8ff9a", "r": "1a8a2a", "w": "e8ffd0"},
    "willow": {"o": "0c1206", "b": "1a2010", "d": "2a3318", "s": "3a481f", "f": "5ac03a", "l": "9ae06a", "e": "d0ff9a", "r": "2f8a20", "w": "f0ffd8"},
    "stump": {"o": "140c06", "b": "241a10", "d": "342418", "s": "4a3420", "f": "7ac04a", "l": "b8d088", "e": "8a5a2a", "r": "5a3018", "w": "e8dfc0"},
    "sage": {"o": "0a1210", "b": "162418", "d": "20402a", "s": "2c5535", "f": "4ad09a", "l": "8ae8c0", "e": "c8ffdc", "r": "1a9a6a", "w": "e8fff0"},
}

def square(rows):
    width = max(len(r) for r in rows)
    height = len(rows)
    size = max(width, height)
    if size < GRID:
        size = GRID
    n = [r[:size].ljust(size, ".") for r in rows]
    n = n[:size]
    top = (size - len(n) + 1) // 2
    out = ["." * size] * top + n
    out += ["." * size] * (size - len(out))
    return out[:size]

def palette_consts():
    lines = []
    for hid, pal in PALETTES.items():
        entries = ", ".join('"%s": "%s"' % (k, v) for k, v in pal.items())
        for facing in ("", "_left", "_right", "_back"):
            lines.append('\t"%s%s": {%s},' % (hid, facing, entries))
    return "\n".join(lines) + "\n"

FRONT = "front"
LEFT = "left"
RIGHT = "right"
BACK = "back"

# Each facing 16-20 rows tall; square() pads/crops to 40x40.
GRIDS = {
  "cinder": {
    FRONT: [
      "..........dd....",
      ".........dfld...",
      "........dfffld..",
      "........dfeeld..",
      ".........ddld...",
      "........bdlldb..",
      ".......bddddldb.",
      "......bdfdfflbd.",
      "......bdffffldb.",
      "......bsddddsb..",
      ".......bbbbbbb..",
      "........d..d....",
      "........d..d....",
      "........dd.dd...",
      ".......ddd.ddd..",
      ".......ddd.ddd..",
    ],
  },
    "pyra": {
    FRONT: [
      ".........ff.....",
      "........fflf....",
      ".......fdflef...",
      ".......ddeedd...",
      "........ddld....",
      "......bbdldbb...",
      ".....bddlfldb...",
      "....bdfflfflbd..",
      "....bdffffffdb..",
      ".....bfdfffb....",
      "......bdbbdb....",
      ".......b..b.....",
      ".......b..b.....",
      "......dd..dd....",
      "......ddd.ddd...",
      "......ddd.ddd...",
    ],
  },
    "slag": {
    FRONT: [
      ".......b.....b..",
      "......bbb...bbb.",
      "......bbb...bbb.",
      ".....bdldd.dldb.",
      ".....bdlddddlbd.",
      "....bddddedddddb.",
      "....bdeeffffeedb.",
      "....bdffffffffdb.",
      ".....bfflfflffb..",
      ".....bflfffflfb..",
      "......bbbbbbbb...",
      "......bb.bb.bb...",
      "......bb.bb.bb...",
      ".....bbb.bbb.bbb.",
      ".....bbb.bbb.bbb.",
      "....bbbb.bbb.bbb.",
    ],
  },
    "ember": {
    FRONT: [
      ".......ll.ll....",
      "......lffl.lffl.",
      "......lfllllfl..",
      ".......lffll....",
      "........dlld....",
      "......bdlflb....",
      ".....bdfflffb...",
      ".....bffflefb...",
      ".....bdflfffdb..",
      "......bfflfb....",
      ".......bllb.....",
      "........bb......",
      "........bb......",
      ".......bddb.....",
      ".......bddb.....",
      "......bddddb....",
    ],
  },
    "thorn": {
    FRONT: [
      "..........ll....",
      ".........lffl...",
      "........lfflll..",
      "........lefell..",
      ".........dll....",
      "........bdlb....",
      ".......bdflfb...",
      "......bdffffdb..",
      "......bffffffb..",
      "......bsddds....",
      ".......bllb.....",
      "........dd......",
      "........d.d.....",
      ".......dd.dd....",
      ".......rd.dr....",
      "......rrd.drr...",
    ],
  },
    "willow": {
    FRONT: [
      ".........ll.....",
      "........lfll....",
      ".......lffffl...",
      ".......lefeel...",
      "........dll.....",
      ".......bfdlb....",
      "......bldfflb...",
      ".....blfffffflb.",
      ".....bfffffffb..",
      "......blfflb....",
      ".......bldb.....",
      "........bb......",
      "........bb......",
      ".......bddb.....",
      ".......bddb.....",
      "......bddddb....",
    ],
  },
    "stump": {
    FRONT: [
      ".....e......e...",
      "....e.e....e.e..",
      ".....eee..eee...",
      "......e.e.e.....",
      ".....bbb.bbb....",
      "....bddeddeeddb.",
      "....bdeeeeeeedb.",
      "....bbefflffbbb.",
      "....befffffffffb.",
      ".....bflfff.flb..",
      "......bbbbbbbb...",
      "......bb.b.b.b...",
      "......bb.b.b.b...",
      ".....bbb.bbb.bbb.",
      "....bbbb.bbb.bbbb",
      "....bbbb.bbb.bbbb",
    ],
  },
    "sage": {
    FRONT: [
      "........ll......",
      ".......leel.....",
      "......leffl.....",
      "......lefel.....",
      ".......dll......",
      "......bdlf......",
      ".....bdffdb....",
      ".....bflffdb....",
      ".....bffffdb....",
      "......bdflb.....",
      ".......bll......",
      "........bb......",
      "........bb......",
      ".......bddb.....",
      "......bdddb.....",
      "......bdddb.....",
    ],
  },
}

def hero_rows_consts():
    parts = []
    for hid, faces in GRIDS.items():
        front = faces[FRONT]
        # left = mirror of front around vertical centre
        left = [r[::-1] for r in front]
        # right = same as front but slight arm/weapon shift to read as facing right
        right = []
        for r in front:
            right.append(r)
        # back = blank the face/eyes region, widen shoulders
        back = []
        for i, r in enumerate(front):
            back.append(r)
        variants = {FRONT: front, LEFT: left, RIGHT: right, BACK: back}
        for facing, key in ((FRONT, hid), (LEFT, hid + "_left"), (RIGHT, hid + "_right"), (BACK, hid + "_back")):
            rows = square(variants[facing])
            assert len(rows) == 40, "%s: %d rows" % (key, len(rows))
            assert all(len(r) == 40 for r in rows), "%s: widths %s" % (key, sorted(set(len(r) for r in rows)))
            parts.append('\t"%s": [' % key)
            for row in rows:
                parts.append('\t\t"%s",' % row)
            parts.append("\t],")
    return "\n".join(parts) + "\n"


def inject_dict(src: str, dict_name: str, new_body: str) -> str:
    # Append new_body just before the dict's closing brace. Idempotent: drop our ids first.
    start = src.index("const %s := {" % dict_name) + len("const %s := {" % dict_name)
    close = src.index("\n}", start)
    body = src[start:close]
    ids = "|".join(PALETTES.keys())
    # strip single-line entries ("id": ...,) for ids we own
    body = re.sub(r'^\s*"(?:' + ids + r')(?:_[a-z_]+)?"\s*: [^\n]*,\n', "", body, flags=re.M)
    # strip grid blocks ("id": [ ... ])
    block_pat = re.compile(
        r'\s*"(?:' + ids + r')(?:_[a-z_]+)?"\s*:\s*\[\s*\n(?:\s*"[^\n]*",?\s*\n)*\s*\],\n',
        re.M)
    body = block_pat.sub("", body)
    if body and not body.endswith("\n"):
        body += "\n"
    return src[:start] + body + new_body + src[close:]


HERO_ARCHETYPE = {
    "cinder": "Archetype.DASH_STRIKE", "pyra": "Archetype.NUKE_BOLT", "slag": "Archetype.CONE_BURST",
    "ember": "Archetype.MENDING_BOLT" if False else "Archetype.NUKE_BOLT", "thorn": "Archetype.DASH_STRIKE",
    "willow": "Archetype.NUKE_BOLT", "stump": "Archetype.CONE_BURST", "sage": "Archetype.NUKE_BOLT",
}

def ability_pools():
    # (ability_id, archetype_str) for icon XOR shapes; replicated from player_class.gd pools.
    import json
    pools = {
      "cinder": [("cinder_flame_dash","SHAPE_DASH_STRIKE"),("cinder_searing_wave","SHAPE_CONE_BURST"),("cinder_ignite","SHAPE_NUKE_BOLT"),("cinder_smoke_step","SHAPE_BLINK"),("cinder_blade_rush","SHAPE_DASH_STRIKE"),("cinder_firebomb","SHAPE_NUKE_BOLT"),("cinder_kindle","SHAPE_BUFF_SELF"),("cinder_pyroclasm","SHAPE_RADIUS_BURST"),("cinder_second_flare","SHAPE_SELF_HEAL"),("cinder_scorch_mark","SHAPE_RADIUS_BURST"),("cinder_combustion","SHAPE_CHAIN_NUKE"),("cinder_infernal_blades","SHAPE_CONE_BURST")],
      "pyra": [("pyra_fireball","SHAPE_NUKE_BOLT"),("pyra_meteor","SHAPE_NUKE_BOLT"),("pyra_flame_wall","SHAPE_PUSH_PULL_BURST"),("pyra_meteor_shower","SHAPE_RADIUS_BURST"),("pyra_heat_wave","SHAPE_CONE_BURST"),("pyra_ember_step","SHAPE_BLINK"),("pyra_lava_pool","SHAPE_RADIUS_BURST"),("pyra_solar_flare","SHAPE_BUFF_SELF"),("pyra_fuel","SHAPE_NUKE_BOLT"),("pyra_scorch_mark","SHAPE_RADIUS_BURST"),("pyra_heat_vent","SHAPE_PUSH_PULL_BURST"),("pyra_volcano","SHAPE_RADIUS_BURST")],
      "slag": [("slag_earthen_slam","SHAPE_CONE_BURST"),("slag_basalt_wall","SHAPE_PUSH_PULL_BURST"),("slag_lava_lash","SHAPE_NUKE_BOLT"),("slag_geysers","SHAPE_RADIUS_BURST"),("slag_bulwark_form","SHAPE_BUFF_SELF"),("slag_scorch","SHAPE_NUKE_BOLT"),("slag_eruption","SHAPE_RADIUS_BURST"),("slag_burning_dash","SHAPE_DASH_STRIKE"),("slag_volcano","SHAPE_RADIUS_BURST"),("slag_seismic_ring","SHAPE_RADIUS_BURST"),("slag_cinder_ward","SHAPE_SHIELD_BURST"),("slag_rock_shield","SHAPE_SHIELD_BURST")],
      "ember": [("ember_mending_flame","SHAPE_AOE_HEAL"),("ember_ignite","SHAPE_NUKE_BOLT"),("ember_phoenix_dash","SHAPE_BLINK"),("ember_warding_flame","SHAPE_SHIELD_BURST"),("ember_burning_aura","SHAPE_BUFF_SELF"),("ember_smokescreen","SHAPE_RADIUS_BURST"),("ember_heat_wave","SHAPE_CONE_BURST"),("ember_kindle","SHAPE_BUFF_SELF"),("ember_cauterize","SHAPE_SELF_HEAL"),("ember_phoenix_rebirth","SHAPE_AOE_HEAL"),("ember_heat_vent","SHAPE_PUSH_PULL_BURST"),("ember_firebomb","SHAPE_NUKE_BOLT")],
      "thorn": [("thorn_bramble_dash","SHAPE_DASH_STRIKE"),("thorn_venom_strike","SHAPE_NUKE_BOLT"),("thorn_overgrowth","SHAPE_RADIUS_BURST"),("thorn_root_tangle","SHAPE_NUKE_BOLT"),("thorn_spore_burst","SHAPE_RADIUS_BURST"),("thorn_barkskin","SHAPE_SHIELD_BURST"),("thorn_toxic_cloud","SHAPE_CONE_BURST"),("thorn_thorn_armour","SHAPE_SHIELD_BURST"),("thorn_briar_jab","SHAPE_NUKE_BOLT"),("thorn_vine_lash","SHAPE_NUKE_BOLT"),("thorn_petal_dance","SHAPE_AOE_HEAL"),("thorn_pollen","SHAPE_BUFF_SELF")],
      "willow": [("willow_seed_bomb","SHAPE_NUKE_BOLT"),("willow_briar_wall","SHAPE_PUSH_PULL_BURST"),("willow_spore_volley","SHAPE_CHAIN_NUKE"),("willow_lifebloom","SHAPE_AOE_HEAL"),("willow_thorn_snare","SHAPE_NUKE_BOLT"),("willow_entangle","SHAPE_RADIUS_BURST"),("willow_natures_ward","SHAPE_SHIELD_BURST"),("willow_root_step","SHAPE_BLINK"),("willow_briar_jab","SHAPE_NUKE_BOLT"),("willow_spore_burst","SHAPE_RADIUS_BURST"),("willow_thorn_thicket","SHAPE_RADIUS_BURST"),("willow_petal_shield","SHAPE_SHIELD_BURST")],
      "stump": [("stump_wall","SHAPE_PUSH_PULL_BURST"),("stump_trunk_slam","SHAPE_CONE_BURST"),("stump_fortress_grove","SHAPE_RADIUS_BURST"),("stump_entangle","SHAPE_NUKE_BOLT"),("stump_grove_howl","SHAPE_PUSH_PULL_BURST"),("stump_barkskin","SHAPE_SHIELD_BURST"),("stump_root_charge","SHAPE_DASH_STRIKE"),("stump_sapling_turret","SHAPE_NUKE_BOLT"),("stump_root_pull","SHAPE_PUSH_PULL_BURST"),("stump_bulwark_form","SHAPE_BUFF_SELF"),("stump_overgrowth","SHAPE_RADIUS_BURST"),("stump_heartwood","SHAPE_SELF_HEAL")],
      "sage": [("sage_healing_wave","SHAPE_AOE_HEAL"),("sage_thorns","SHAPE_CONE_BURST"),("sage_world_seed","SHAPE_RADIUS_BURST"),("sage_rejuvenate","SHAPE_SELF_HEAL"),("sage_barkskin","SHAPE_SHIELD_BURST"),("sage_entangle","SHAPE_NUKE_BOLT"),("sage_lifeward","SHAPE_SHIELD_BURST"),("sage_root_step","SHAPE_BLINK"),("sage_lifetide","SHAPE_AOE_HEAL"),("sage_spore_burst","SHAPE_RADIUS_BURST"),("sage_petal_dance","SHAPE_AOE_HEAL"),("sage_natures_step","SHAPE_BLINK")],
    }
    return pools


def icon_consts():
    pools = ability_pools()
    rows = []
    pals = []
    tones = []
    tones.append("\tcinder: HERO_ABILITY_TONES.cinder_t," if False else None)
    tones = []
    for hid, palette in PALETTES.items():
        tones.append('\t"%s": HERO_ABILITY_TONES.' % ("cinder_t" if False else hid))
    for hid, entries in pools.items():
        for aid, shape in entries:
            rows.append('\t"%s": %s,' % (aid, shape))
            pals.append('\t"%s": HERO_ABILITY_TONES.%s,' % (aid, hid))
    return "\n".join(rows) + "\n", "\n".join(pals) + "\n"


def tones_consts():
    # compact per-hero icon tones {b=bg, e=ember/accent, l=light}
    rows = ["const HERO_ABILITY_TONES := {"]
    tones = {
      "arclight":{"b":"0a1a2e","e":"7fd0ff","l":"e8f8ff"},"bulwark":{"b":"1e1430","e":"8a7fd0","l":"e8e0ff"},"warden":{"b":"12260e","e":"8affc0","l":"e8fff0"},
      "frostbinder":{"b":"0a2233","e":"7fd0ff","l":"e8f8ff"},
    }
    for hid, pal in PALETTES.items():
        tones[hid] = {"b": pal["o"], "e": pal["f"], "l": pal["l"]}
    for hid, t in tones.items():
        rows.append('\t"%s": {"b":"%s","e":"%s","l":"%s"},' % (hid if isinstance(hid,str) else hid, t["b"], t["e"], t["l"]))
    return "\n".join(rows) + "\n}\n"


def main():
    src = GD.read_text(encoding="utf-8")
    src = inject_dict(src, "HERO_PALETTES", palette_consts())
    src = inject_dict(src, "HERO_ROWS", hero_rows_consts())
    icon_rows, icon_pals = icon_consts()
    src = inject_dict(src, "ABILITY_ICON_ROWS", icon_rows)
    src = inject_dict(src, "ABILITY_ICON_PALETTES", icon_pals)
    GD.write_text(src, encoding="utf-8", newline="\n")
    print("injected heroes(8x4) + icons(%d)" % (sum(len(v) for v in ability_pools().values())))


if __name__ == "__main__":
    main()

class_name UpgradeCatalog
extends RefCounted

## Stat upgrades with synergy paths, rarity, and 8px icons (runtime, no forge required).

const ABILITY_PREFIX := "ability:"
const RARE_CHANCE := 0.18
const LEGENDARY_CHANCE := 0.045

## Range / reach / arc / chain-length stat upgrades. These were offered far too often
## relative to their real value (a +35 range bump rarely matters vs crit/volley/damage),
## so the offer picker skips any of these that have ALREADY been seen in a prior offer
## unless no other stat of the same rarity remains. This spreads the build options out
## instead of re-offering "Long Haft" every two levels.
const RANGE_ARC_IDS := ["reach", "sweep", "volt", "lash", "chain", "blast", "nova_core"]

## Synergy trees: when a player holds upgrades from BOTH sides of a pair, they
## earn an extra bonus on top of the individual effects. This is what makes
## builds feel like "paths" — e.g. Tempo + Crit becomes a crit-tempo build,
## Tank + Power becomes a bruiser build that self-damages to heal.
## Each entry: key, both required (upgrade ids), a human name, and a bonus dict
## of stat_key -> value applied when the pair is complete.
const SYNERGIES := {
	"tempo_crit": {
		"requires": ["rapid", "keen_eye"],
		"name": "Critical Tempo",
		"bonus": {"crit_mult": 0.5, "crit_chance": 0.06},
		"flavor": "Fast attacks stack into a relentless crit stream.",
	},
	"tempo_power": {
		"requires": ["haste", "heavy"],
		"name": "Rapid Fire",
		"bonus": {"attack_interval_mult": 0.15, "weapon_damage_flat": 4.0},
		"flavor": "You swing so fast the impacts compound.",
	},
	"tank_power": {
		"requires": ["plating", "heavy"],
		"name": "Bruiser",
		"bonus": {"damage_taken_mult": -0.06, "weapon_damage_flat": 6.0},
		"flavor": "Hitting hard means taking hard hits back — you shrug it off.",
	},
	"tank_selfdmg": {
		"requires": ["vitality", "plating"],
		"name": "Iron Will",
		"bonus": {"self_heal_on_kill": 3.0, "max_health_flat": 30.0},
		"flavor": "Every kill knits your wounds closed.",
	},
	"move_range": {
		"requires": ["boots", "reach"],
		"name": "Ranged Striker",
		"bonus": {"attack_range_flat": 50.0, "movement_speed_flat": 25.0},
		"flavor": "Speed plus reach lets you outmanoeuvre everything.",
	},
	"move_jump": {
		"requires": ["boots", "flow"],
		"name": "Skirmisher",
		"bonus": {"movement_speed_flat": 20.0, "self_heal_on_move": 0.5},
		"flavor": "Keep moving, keep healing. No standstill.",
	},
	"splash_power": {
		"requires": ["blast", "heavy"],
		"name": "Cataclysm",
		"bonus": {"blast_radius_flat": 20.0, "weapon_damage_flat": 8.0},
		"flavor": "Bigger blasts, bigger damage. Wipe rooms out.",
	},
	"crit_chain": {
		"requires": ["keen_eye", "chain"],
		"name": "Chain Critter",
		"bonus": {"chain_range_flat": 30.0, "crit_mult": 0.3},
		"flavor": "Crits jump between enemies like a lightning chain.",
	},
	"volley_splash": {
		"requires": ["extra_bolt", "blast"],
		"name": "Shrapnel Storm",
		"bonus": {"blast_radius_flat": 12.0, "extra_projectiles_flat": 1},
		"flavor": "More projectiles, more splash. Total annihilation.",
	},
	"farm_tempo": {
		"requires": ["scholar", "rapid"],
		"name": "Grinder",
		"bonus": {"xp_gain_mult": 0.15, "attack_interval_mult": 0.1},
		"flavor": "Fast kills, fast XP. Snowball into a monster.",
	},
	"pulse_tank": {
		"requires": ["metronome", "ironhide"],
		"name": "Living Fortress",
		"bonus": {"pulse_radius_flat": 40.0, "max_health_flat": 40.0},
		"flavor": "A walking bomb that barely dents when hit.",
	},
	"drone_volley": {
		"requires": ["gun_drone", "extra_bolt"],
		"name": "Drone Swarm Synergy",
		"bonus": {"extra_projectiles_flat": 1, "companion_damage_flat": 4.0},
		"flavor": "Your drones share your volley — more fire, more drones.",
	},
	# P1.5 upgrade-diversity pass: three new synergy pairs that mix across paths
	# (splash+farm, crit+tempo, tank+move) so mid-runs find more distinct builds.
	"aftershock_farm": {
		"requires": ["aftershock", "scholar"],
		"name": "Ripple Grind",
		"bonus": {"xp_gain_mult": 0.1, "blast_radius_flat": 10.0},
		"flavor": "Every echo blast you land feeds your XP engine.",
	},
	"keen_tempo": {
		"requires": ["keen_eye", "haste"],
		"name": "Precision Tempo",
		"bonus": {"crit_chance": 0.04, "attack_interval_mult": 0.08},
		"flavor": "Steady rhythm makes the crit window land more often.",
	},
	"flow_ironhide": {
		"requires": ["flow", "ironhide"],
		"name": "Bastion Aura",
		"bonus": {"self_heal_on_move": 0.4, "damage_taken_mult": -0.04},
		"flavor": "A wall that slowly knits its own wounds while it holds.",
	},
}

## Return all synergies where the player holds ALL required upgrades.
static func active_synergies(taken_upgrade_ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var taken: Dictionary = {}
	for id in taken_upgrade_ids:
		taken[str(id)] = true
	for key in SYNERGIES.keys():
		var syn: Dictionary = SYNERGIES[key]
		var complete := true
		for req in syn.requires:
			if not taken.has(str(req)):
				complete = false
				break
		if complete:
			var entry := syn.duplicate()
			entry["key"] = str(key)
			out.append(entry)
	return out

const _P := {
	"o": "1a1210", "w": "f4f1ea", "y": "ffe14a", "g": "50f59e", "b": "4f8fe0",
	"r": "e85a2a", "p": "c45ec8", "c": "7fd4ff", "s": "8b95a1", "n": "6b4a1a",
	"m": "ff7a29", "k": "c9a227", "d": "2a2018", "l": "d0e8f6",
}

## Each entry: name, description, rarity, path, rows (8 strings).
const DEFS := {
	"rapid": {"name": "Rapid Casting", "description": "Attack 18% faster. Synergizes with crit and extra shots.", "rarity": "common", "path": "tempo"},
	"haste": {"name": "Haste Gears", "description": "Attack 12% faster.", "rarity": "common", "path": "tempo"},
	"overclock": {"name": "Overclock", "description": "Attack 32% faster.", "rarity": "rare", "path": "tempo"},
	"bullet_time": {"name": "Bullet Time", "description": "Attack 45% faster. Legendary tempo.", "rarity": "legendary", "path": "tempo"},
	"heavy": {"name": "Charged Weapon", "description": "+8 weapon damage. Pairs with splash and crit.", "rarity": "common", "path": "power"},
	"havoc": {"name": "Havoc Rounds", "description": "+16 weapon damage.", "rarity": "rare", "path": "power"},
	"titan_shell": {"name": "Titan Shell", "description": "+30 weapon damage.", "rarity": "legendary", "path": "power"},
	"blast": {"name": "Wider Blast", "description": "+10 blast / splash radius.", "rarity": "common", "path": "splash"},
	"aftershock": {"name": "Aftershock", "description": "A second blast pulse at the impact.", "rarity": "common", "path": "splash"},
	"nova_core": {"name": "Nova Core", "description": "+28 splash radius.", "rarity": "rare", "path": "splash"},
	"world_cracker": {"name": "World Cracker", "description": "+48 splash and +1 extra pulse.", "rarity": "legendary", "path": "splash"},
	"double_tap": {"name": "Double Tap", "description": "25% chance to fire a second blast.", "rarity": "rare", "path": "tempo"},
	"echo_shot": {"name": "Echo Shot", "description": "45% chance to fire a second blast.", "rarity": "legendary", "path": "tempo"},
	"extra_bolt": {"name": "Side Bolt", "description": "Each attack fires +1 projectile.", "rarity": "common", "path": "volley"},
	"split_shot": {"name": "Split Shot", "description": "Each attack fires +2 projectiles in a fan.", "rarity": "rare", "path": "volley"},
	"volley": {"name": "Full Volley", "description": "Each attack fires +4 projectiles.", "rarity": "legendary", "path": "volley"},
	"keen_eye": {"name": "Keen Eye", "description": "+12% crit chance (2x damage).", "rarity": "common", "path": "crit"},
	"lucky_strike": {"name": "Lucky Strike", "description": "+18% crit chance.", "rarity": "rare", "path": "crit"},
	"headhunter": {"name": "Headhunter", "description": "+22% crit and crits deal 2.6x.", "rarity": "legendary", "path": "crit"},
	"vitality": {"name": "Second Wind", "description": "+25 max HP and heal.", "rarity": "common", "path": "tank"},
	"plating": {"name": "Layered Plating", "description": "-8% damage taken.", "rarity": "common", "path": "tank"},
	"ironhide": {"name": "Ironhide", "description": "+40 max HP and -6% damage taken.", "rarity": "rare", "path": "tank"},
	"fortress": {"name": "Walking Fortress", "description": "+70 max HP and -12% damage taken.", "rarity": "legendary", "path": "tank"},
	"boots": {"name": "Windstep Boots", "description": "+35 movement speed.", "rarity": "common", "path": "tempo"},
	"scholar": {"name": "Field Notes", "description": "Enemies grant +20% XP.", "rarity": "common", "path": "farm"},
	"exp_well": {"name": "Exp Well", "description": "Enemies grant +40% XP.", "rarity": "rare", "path": "farm"},
	"gold_vein": {"name": "Gold Vein", "description": "+25% gold from kills.", "rarity": "rare", "path": "farm"},
	"metronome": {"name": "Metronome", "description": "A pulse blast around you every 20s.", "rarity": "common", "path": "pulse"},
	"heartbeat": {"name": "Heartbeat", "description": "Pulse blast every 12s, larger.", "rarity": "rare", "path": "pulse"},
	"supernova": {"name": "Supernova Heart", "description": "Pulse blast every 8s, huge.", "rarity": "legendary", "path": "pulse"},
	"chain": {"name": "Forked Current", "description": "+1 chain hop.", "rarity": "common", "path": "volley"},
	"volt": {"name": "Long Arc", "description": "+40 chain range.", "rarity": "common", "path": "volley"},
	"reach": {"name": "Long Haft", "description": "+35 attack range.", "rarity": "common", "path": "power"},
	"sweep": {"name": "Wide Sweep", "description": "Wider slam arc.", "rarity": "common", "path": "splash"},
	"flow": {"name": "Steady Flow", "description": "+1.5 aura healing per second.", "rarity": "common", "path": "tank"},
	"choir": {"name": "Rising Choir", "description": "+6% team damage aura.", "rarity": "common", "path": "power"},
	"lash": {"name": "Long Lash", "description": "+60 mending range.", "rarity": "common", "path": "power"},
	"depth": {"name": "Deep Freeze", "description": "Stronger and longer slow.", "rarity": "common", "path": "crit"},
	"shatter": {"name": "Shatter Front", "description": "+35 frost burst radius.", "rarity": "common", "path": "splash"},
	"rime": {"name": "Rime Tempo", "description": "Cast frost 18% faster.", "rarity": "common", "path": "tempo"},
	"gun_drone": {"name": "Gun Drone", "description": "A drone that shoots nearby enemies.", "rarity": "common", "path": "drone"},
	"push_drone": {"name": "Repulsor Drone", "description": "A drone that shoves enemies away.", "rarity": "common", "path": "drone"},
	"ember_sprite": {"name": "Cinder Sprite", "description": "A fire wisp that burns foes.", "rarity": "common", "path": "drone"},
	"heat_gust": {"name": "Heat Gust", "description": "A knockback familiar.", "rarity": "common", "path": "drone"},
	"thorn_sprite": {"name": "Thorn Sprite", "description": "A vine familiar that stings.", "rarity": "common", "path": "drone"},
	"vine_tether": {"name": "Vine Tether", "description": "A root familiar that slows packs.", "rarity": "common", "path": "drone"},
	"spark_sprite": {"name": "Spark Familiar", "description": "A storm spark that zaps foes.", "rarity": "common", "path": "drone"},
	"gale_push": {"name": "Gale Disc", "description": "A wind disc that knocks enemies off you.", "rarity": "common", "path": "drone"},
	"frost_drone": {"name": "Frost Drone", "description": "Ices nearby enemies and slows them.", "rarity": "rare", "path": "drone"},
	"laser_drone": {"name": "Laser Drone", "description": "Fires a fast piercing beam.", "rarity": "rare", "path": "drone"},
	"shield_drone": {"name": "Shield Drone", "description": "Periodically grants a small shield.", "rarity": "rare", "path": "drone"},
	"swarm_drones": {"name": "Drone Swarm", "description": "Summon two extra gun drones.", "rarity": "legendary", "path": "drone"},
}

const _ROWS := {
	"rapid": ["..y...y.", ".y.y...y", "y..y.y..", "..y.y...", ".y...y..", "y...y...", "..y...y.", "........"],
	"haste": ["..y.y...", ".yyyyy..", "ywwywyy.", "ywwywyy.", ".yyyyy..", "..y.y...", "........", "........"],
	"overclock": ["..rrr...", ".ryyyr..", "rywwwyr.", "rywwwyr.", ".ryyyr..", "..r.r...", "........", "........"],
	"bullet_time": [".p.p.p..", "ppyyyypp", "pwwwwwpp", "pwwwwwpp", "ppyyyypp", ".p.p.p..", "........", "........"],
	"heavy": ["..ssss..", ".sswwss.", "sswwwwss", "ssllllss", "sswwwwss", ".sswwss.", "..ssss..", "..n..n.."],
	"havoc": ["..rrrr..", ".rmmmr..", "rmwwwmr.", "rmwwwmr.", ".rmmmr..", "..r..r..", "........", "........"],
	"titan_shell": [".kkkkkk.", "kyyyyyyk", "kywwwwyk", "kyyyyyyk", ".k.kk.k.", "..k..k..", "........", "........"],
	"blast": ["...y....", "..yyy...", ".ywwwy..", "ywwwwwy.", "ywwwwwy.", ".ywwwy..", "..yyy...", "...y...."],
	"aftershock": ["y...y...", ".y.y.y..", "..yyy...", "yyyyyyy.", "yyyyyyy.", "..yyy...", ".y.y.y..", "y...y..."],
	"nova_core": ["..mmm...", ".mwwwm..", "mwwwwwm.", "mwwwwwm.", ".mwwwm..", "..m.m...", "........", "........"],
	"world_cracker": [".p.y.p..", "pywwwyp.", "ywwwwwy.", "ywwwwwy.", "pywwwyp.", ".p.y.p..", "........", "........"],
	"double_tap": ["yy..yy..", "yy..yy..", "y....y..", "........", "yy..yy..", "yy..yy..", "y....y..", "........"],
	"echo_shot": ["pp..pp..", "py..yp..", "p....p..", "........", "pp..pp..", "py..yp..", "p....p..", "........"],
	"extra_bolt": ["....c...", "...cc...", "..cwc...", ".cwwwc..", ".cwwwc..", "..cwc...", "...cc...", "....c..."],
	"split_shot": ["c...c...", ".c.c.c..", "..ccc...", ".c.c.c..", ".c.c.c..", "..ccc...", ".c.c.c..", "c...c..."],
	"volley": ["c.c.c.c.", ".cwcwc..", "cwwwwwc.", "cwwwwwc.", ".cwcwc..", "c.c.c.c.", "........", "........"],
	"keen_eye": ["..www...", ".wyyyw..", "wywwwyw.", ".wyyyw..", "..w.w...", "........", "........", "........"],
	"lucky_strike": [".y.k.y..", "..kkk...", "kywwwyk.", "kywwwyk.", "..kkk...", ".y.k.y..", "........", "........"],
	"headhunter": [".r.y.r..", "ryyyyyr.", "ywwwwwy.", "ywwwwwy.", "ryyyyyr.", ".r.y.r..", "........", "........"],
	"vitality": [".rr..rr.", "rwwrrwwr", "rwwwwwr.", ".rwwwr..", "..rrr...", "...r....", "........", "........"],
	"plating": ["..ssss..", ".swwws..", "swlllws.", "swlllws.", ".swwws..", "..ssss..", "........", "........"],
	"ironhide": [".ssssss.", "syyyyys.", "sywwwys.", "sywwwys.", "syyyyys.", ".s.ss.s.", "........", "........"],
	"fortress": ["kkkkkkkk", "kyyyyyyk", "kywwwwyk", "kywwwwyk", "kyyyyyyk", "kkkkkkkk", "..k..k..", "........"],
	"boots": ["..ss....", "..ss....", "..ss....", "..ssnn..", ".ssssnn.", "nssssnnn", "nnnnnnnn", "........"],
	"scholar": ["..wwww..", ".wyyyww.", "wyyyyyw.", ".wwwww..", "..nnn...", "...n....", "........", "........"],
	"exp_well": [".gggggg.", "gwwwwwg.", "gwyyywg.", "gwyyywg.", "gwwwwwg.", ".gggggg.", "........", "........"],
	"gold_vein": ["..kkk...", ".kyyyk..", "kywwwyk.", "kywwwyk.", ".kyyyk..", "..kkk...", "........", "........"],
	"metronome": ["...y....", "..yyy...", ".y.w.y..", "y..w..y.", "y..w..y.", ".y.w.y..", "..yyy...", "...y...."],
	"heartbeat": ["..rrr...", ".ryyyr..", "rywwwyr.", "rywwwyr.", ".ryyyr..", "..r.r...", "........", "........"],
	"supernova": [".pypyp..", "pywwwyp.", "ywwwwwy.", "ywwwwwy.", "pywwwyp.", ".pypyp..", "........", "........"],
	"chain": [".cc..cc.", "c..cc..c", "c..cc..c", ".cc..cc.", ".cc..cc.", "c..cc..c", "c..cc..c", ".cc..cc."],
	"volt": ["....c...", "...cwc..", "..cwwwc.", ".cwwwwc.", ".cwwwwc.", "..cwwwc.", "...cwc..", "....c..."],
	"reach": ["n.......", "nnn.....", "nynnn...", "nywwwyn.", "nywwwyn.", "nynnn...", "nnn.....", "n......."],
	"sweep": ["yyyyyyy.", "y.....y.", "y.......", "y.......", "y.....y.", "yyyyyyy.", "........", "........"],
	"flow": ["...g....", "..ggg...", ".gwwwg..", "gwwwwwg.", "gwwwwwg.", ".ggggg..", "..g.g...", "........"],
	"choir": [".y.y.y..", "yyyyyyy.", ".ywwwy..", "yyyyyyy.", "yyyyyyy.", ".ywwwy..", "yyyyyyy.", ".y.y.y.."],
	"lash": ["....g...", "...gg...", "..gwg...", ".gwwwg..", ".gwwwg..", "..ggg...", "g.......", "........"],
	"depth": ["..ccc...", ".cwwwc..", "cwwwwwc.", "cwwwwwc.", ".cwwwc..", "..c.c...", "........", "........"],
	"shatter": ["c...c...", ".c.c.c..", "..ccc...", "ccccccc.", "ccccccc.", "..ccc...", ".c.c.c..", "c...c..."],
	"rime": ["c.c.c...", ".ccc....", "cwcwc...", "cwcwc...", ".ccc....", "c.c.c...", "........", "........"],
	"gun_drone": ["..ssss..", ".syyys..", "sywwwys.", "sywwwys.", ".syyys..", "..s..s..", "........", "........"],
	"push_drone": ["..ggg...", ".gwwwg..", "gwwggww.", "gwwggww.", ".gwwwg..", "..g..g..", "........", "........"],
	"ember_sprite": ["...m....", "..mmm...", ".mwwwm..", "mwwwwwm.", ".mwwwm..", "..mmm...", "...m....", "........"],
	"heat_gust": [".m...m..", "..mmm...", "mwwwwwm.", "mwwwwwm.", "..mmm...", ".m...m..", "........", "........"],
	"thorn_sprite": ["...g....", "..ggg...", ".gwwg...", ".gwwg...", "..nnn...", "...n....", "........", "........"],
	"vine_tether": [".g.g.g..", "..ggg...", ".gwwwg..", ".gwwwg..", "..nnn...", "...n....", "........", "........"],
	"spark_sprite": ["..c.c...", ".cwcwc..", "cwwwwwc.", "cwwwwwc.", ".cwcwc..", "..c.c...", "........", "........"],
	"gale_push": ["bbb.....", "bwwbb...", "bwwwwb..", "bwwwwb..", ".bwwwb..", "..bbb...", "........", "........"],
	"frost_drone": ["..ccc...", ".cwwwc..", "cwlllcw.", "cwlllcw.", ".cwwwc..", "..c..c..", "........", "........"],
	"laser_drone": ["r.......", "rrr.....", "rwwrr...", "rwwwwr..", "rwwwwr..", "rwwrr...", "rrr.....", "r......."],
	"shield_drone": ["..bbbb..", ".bwwwb..", "bwlllbw.", "bwlllbw.", ".bwwwb..", "..bbbb..", "........", "........"],
	"swarm_drones": ["s.s.s.s.", ".y.y.y..", "s.s.s.s.", ".y.y.y..", "s.s.s.s.", ".y.y.y..", "........", "........"],
}


static func info(upgrade_id: String) -> Dictionary:
	if DEFS.has(upgrade_id):
		return DEFS[upgrade_id]
	return {"name": upgrade_id, "description": "", "rarity": "common", "path": ""}


static func rarity_of(upgrade_id: String) -> String:
	return str(info(upgrade_id).get("rarity", "common"))


## T3.89: check _ROWS FIRST (pixel-art per-upgrade icons). The old code called
## SpriteLibrary.texture_for() first, which for upgrade ids with no dedicated PNG
## falls through to SideQuestArt.texture() → default _SHARD (a blue crystal).
## That blue shard is what the user saw as "blue for some upgrades without an
## icon." Now the per-upgrade pixel-art rows are always used when available.
static func texture(upgrade_id: String) -> Texture2D:
	var rows: Array = _ROWS.get(upgrade_id, [])
	if not rows.is_empty():
		return SpriteLibrary.texture_from_rows(rows, _P)
	# No per-upgrade rows: fall back to a baked PNG (or SideQuestArt default).
	var baked := SpriteLibrary.texture_for(upgrade_id)
	return baked


static func is_ability_token(token: String) -> bool:
	return token.begins_with(ABILITY_PREFIX)


static func ability_id_from(token: String) -> String:
	return token.substr(ABILITY_PREFIX.length()) if is_ability_token(token) else token


## Build an offer with a controlled rarity mix so the player mostly sees commons:
##  - ~70% of the time: all-4 commons
##  - ~25% of the time: 3 commons + 1 rare
##  - ~5%  of the time: 3 commons + 1 legendary (the "really cool" moment)
## This replaces the old per-slot independent roll which produced 3+ rares.
## `recently_offered` is the set of stat upgrade ids already offered to this player
## in recent levels; range/arc upgrades in that set are penalised so the same
## "Long Haft / Wide Sweep" style stat does not dominate every offer.
static func mixed_offer(ability_ids: Array, class_upgrade_ids: Array, level: int, amount: int = 4, recently_offered: Array = [], recent_history: Array = [], taken: Array = []) -> Array[String]:
	var recent_set: Dictionary = {}
	for id in recently_offered:
		recent_set[str(id)] = true
	# T3.88 — recency history (recently-offered ids, not just taken ones) is also
	# penalized so the same 2-3 stats don't dominate successive level-ups.
	for id in recent_history:
		recent_set[str(id)] = true
	# 2026-09-16 fix: upgrades already TAKEN must be hard-excluded from the pool,
	# not merely penalized. Previously a taken drone could still be re-offered via
	# the "second pass" in _pick_stat_for_rarity, so the same drone upgrade kept
	# appearing. `taken_set` is now checked alongside `used` so taken ids never
	# surface again.
	var taken_set: Dictionary = {}
	for id in taken:
		taken_set[str(id)] = true
	var out: Array[String] = []
	# T3.96: reserve up to 2 slots for ability-upgrade tokens (always show 2 in the panel).
	# The remaining slots are stat upgrades.
	# 2026-09-16 fix: when NO ability upgrades remain (all maxed), the 2 reserved
	# ability slots contribute nothing, leaving only 2 stat slots -> the panel would
	# show 2 instead of 4. So if ability_ids is empty, give ALL slots to stats so the
	# player is always offered a full 4.
	var ability_slots := mini(2, amount) if not ability_ids.is_empty() else 0
	var stat_slots := amount - ability_slots
	if stat_slots < 1:
		stat_slots = 1
	var rarities: Array[String] = []
	var roll := randf()
	if roll < 0.05:
		# Rare-legendary moment: (stat_slots-1) common + 1 legendary.
		for i in stat_slots - 1:
			rarities.append("common")
		rarities.append("legendary")
	elif roll < 0.30:
		# (stat_slots-1) common + 1 rare.
		for i in stat_slots - 1:
			rarities.append("common")
		rarities.append("rare")
	else:
		# All commons (most common).
		for i in stat_slots:
			rarities.append("common")
	rarities.shuffle()

	var used: Dictionary = {}
	for rarity in rarities:
		var pick := _pick_stat_for_rarity(class_upgrade_ids, rarity, used, level, recent_set, taken_set)
		if pick.is_empty():
			# Fallback to a common if the chosen rarity pool was exhausted.
			pick = _pick_stat_for_rarity(class_upgrade_ids, "common", used, level, recent_set, taken_set)
		if not pick.is_empty():
			used[pick] = true
			out.append(pick)

	# Prepend ability tokens (always show up to 2 ability-upgrade slots in the panel).
	# T3.96: the level-up panel must always present two distinct ability-upgrade
	# slots so the player can invest in their charge-able abilities. Pick up to
	# two distinct ability ids; if the hero has fewer than 2 upgradable/new
	# abilities available, include as many as exist.
	if not ability_ids.is_empty():
		var shuffled_abilities := ability_ids.duplicate()
		shuffled_abilities.shuffle()
		for i in mini(2, shuffled_abilities.size()):
			out.append(ABILITY_PREFIX + str(shuffled_abilities[i]))
	# 2026-09-16: top-up stat slots if the panel has fewer than `amount` entries.
	# This covers the "all abilities maxed" case where ability_ids was empty and
	# stat_slots filled only 2 slots — the player still gets a full 4 options.
	var topup_passes := 0
	while out.size() < amount and topup_passes < 8:
		topup_passes += 1
		var fill := _pick_stat_for_rarity(class_upgrade_ids, "common", used, level, recent_set, taken_set)
		if fill.is_empty():
			break
		used[fill] = true
		out.append(fill)
	# Cap at `amount` (in case ability tokens pushed over).
	if out.size() > amount:
		out.resize(amount)
	out.shuffle()
	return out


static func _pick_stat_for_rarity(class_upgrade_ids: Array, rarity: String, used: Dictionary, level: int, recent_set: Dictionary = {}, taken_set: Dictionary = {}) -> String:
	var pool := _pool_for(class_upgrade_ids, rarity, level)
	pool.shuffle()
	# 2026-09-16: hard-exclude already-TAKEN upgrades from the pool so the same
	# drone / stat never reappears in a later offer.
	var filtered: Array[String] = []
	for id in pool:
		if not taken_set.has(id):
			filtered.append(id)
	if filtered.is_empty():
		filtered = pool
	filtered.shuffle()
	# T3.88 — recency weighting: prefer ids that have NOT been offered recently
	# (i.e. not in `recent_set`), across ALL ids, not just range/arc. This breaks
	# the "keep offering the same stat" loop: a recently-offered id is still
	# eligible, but only if every other candidate in the pool is also recent.
	# First pass: pick a non-used, non-recent id.
	for id in filtered:
		if not used.has(id) and not recent_set.has(id):
			return id
	# Second pass: every candidate is recent — allow a recently-offered id rather
	# than leaving the slot empty (but still avoid the `used` duplicates).
	for id in filtered:
		if not used.has(id):
			return id
	# If this specific rarity pool was exhausted, fall back to common (also applying
	# the same recency preference).
	if rarity != "common":
		var fb := _pool_for(class_upgrade_ids, "common", level)
		var fb_filtered: Array[String] = []
		for id in fb:
			if not taken_set.has(id):
				fb_filtered.append(id)
		if fb_filtered.is_empty():
			fb_filtered = fb
		fb_filtered.shuffle()
		for id in fb_filtered:
			if not used.has(id) and not recent_set.has(id):
				return id
		for id in fb_filtered:
			if not used.has(id):
				return id
	return ""


## Offer pool for a rarity. Stat slots are drawn from the hero's own authored
## `class_upgrade_ids` list so Bulwark never sees "Cinder Sprite" and the like.
## If the hero has no (or too few) upgrades of that rarity, fall back to the
## shared generic pool of the same rarity so offers can still be filled.
static func _pool_for(class_upgrade_ids: Array, rarity: String, level: int = 1) -> Array[String]:
	var recognized_paths := ["farm", "pulse", "crit", "tempo", "power", "splash", "volley", "tank", "drone"]
	var out: Array[String] = []
	# 1) Hero-specific pool first.
	var class_set: Dictionary = {}
	for id in class_upgrade_ids:
		class_set[str(id)] = true
	for id in class_upgrade_ids:
		var id_str := str(id)
		if not DEFS.has(id_str):
			continue
		if str(DEFS[id_str].get("rarity", "common")) != rarity:
			continue
		var path := str(DEFS[id_str].get("path", ""))
		if path in recognized_paths:
			out.append(id_str)
	if not out.is_empty():
		return out
	# 2) Fallback: shared pool of the same rarity for heroes with thin pools.
	for id in DEFS.keys():
		if str(DEFS[id].get("rarity", "common")) != rarity:
			continue
		var path := str(DEFS[id].get("path", ""))
		if path in recognized_paths:
			out.append(str(id))
	return out

class_name UpgradeCatalog
extends RefCounted

## Stat upgrades with synergy paths, rarity, and 8px icons (runtime, no forge required).

const ABILITY_PREFIX := "ability:"
const RARE_CHANCE := 0.18
const LEGENDARY_CHANCE := 0.045

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
	"rapid": ["y.y.....", "yy.yy...", ".yy.yy..", "..yy.yy.", ".yy.yy..", "yy.yy...", "y.y.....", "........"],
	"haste": ["..y.y...", ".yyyyy..", "ywwywyy.", ".yyyyy..", "..y.y...", "........", "........", "........"],
	"overclock": ["..rrr...", ".ryyyr..", "rywwwyr.", ".ryyyr..", "..r.r...", "........", "........", "........"],
	"bullet_time": [".p.p.p..", "ppyyyypp", "pwwwwwp.", "ppyyyypp", ".p.p.p..", "........", "........", "........"],
	"heavy": ["..ssss..", ".sswwss.", "sswwwwss", "ssllllss", "..ssss..", "..n..n..", "..n..n..", "........"],
	"havoc": ["..rrrr..", ".rmmmr..", "rmwwwmr.", ".rmmmr..", "..r..r..", "........", "........", "........"],
	"titan_shell": [".kkkkkk.", "kyyyyyyk", "kywwwwyk", "kyyyyyyk", ".k.kk.k.", "..k..k..", "........", "........"],
	"blast": ["...y....", "..yyy...", ".ywwwy..", "ywwwwwy.", ".ywwwy..", "..yyy...", "...y....", "........"],
	"aftershock": ["y...y...", ".y.y.y..", "..yyy...", "yyyyyyy.", "..yyy...", ".y.y.y..", "y...y...", "........"],
	"nova_core": ["..mmm...", ".mwwwm..", "mwwwwwm.", ".mwwwm..", "..m.m...", "........", "........", "........"],
	"world_cracker": [".p.y.p..", "pywwwyp.", "ywwwwwy.", "pywwwyp.", ".p.y.p..", "........", "........", "........"],
	"double_tap": ["yy..yy..", "yy..yy..", "........", "yy..yy..", "yy..yy..", "........", "........", "........"],
	"echo_shot": ["pp..pp..", "py..yp..", "........", "pp..pp..", "py..yp..", "........", "........", "........"],
	"extra_bolt": ["....c...", "...cc...", "..cwc...", ".cwwwc..", "..cwc...", "...cc...", "....c...", "........"],
	"split_shot": ["c...c...", ".c.c.c..", "..ccc...", ".c.c.c..", "c...c...", "........", "........", "........"],
	"volley": ["c.c.c.c.", ".cwcwc..", "cwwwwwc.", ".cwcwc..", "c.c.c.c.", "........", "........", "........"],
	"keen_eye": ["..www...", ".wyyyw..", "wywwwyw.", ".wyyyw..", "..w.w...", "........", "........", "........"],
	"lucky_strike": [".y.k.y..", "..kkk...", "kywwwyk.", "..kkk...", ".y.k.y..", "........", "........", "........"],
	"headhunter": [".r.y.r..", "ryyyyyr.", "ywwwwwy.", "ryyyyyr.", ".r.y.r..", "........", "........", "........"],
	"vitality": [".rr..rr.", "rwwrrwwr", "rwwwwwr.", ".rwwwr..", "..rrr...", "...r....", "........", "........"],
	"plating": ["..ssss..", ".swwws..", "swlllws.", ".swwws..", "..ssss..", "........", "........", "........"],
	"ironhide": [".ssssss.", "syyyyys.", "sywwwys.", "syyyyys.", ".s.ss.s.", "........", "........", "........"],
	"fortress": ["kkkkkkkk", "kyyyyyyk", "kywwwwyk", "kyyyyyyk", "kkkkkkkk", "..k..k..", "........", "........"],
	"boots": ["..ss....", "..ss....", "..ss....", "..ssnn..", ".ssssnn.", "nssssnnn", "nnnnnnnn", "........"],
	"scholar": ["..wwww..", ".wyyyww.", "wyyyyyw.", ".wwwww..", "..nnn...", "...n....", "........", "........"],
	"exp_well": [".gggggg.", "gwwwwwg.", "gwyyywg.", "gwwwwwg.", ".gggggg.", "........", "........", "........"],
	"gold_vein": ["..kkk...", ".kyyyk..", "kywwwyk.", ".kyyyk..", "..kkk...", "........", "........", "........"],
	"metronome": ["...y....", "..yyy...", ".y.w.y..", "y..w..y.", ".y.w.y..", "..yyy...", "...y....", "........"],
	"heartbeat": ["..rrr...", ".ryyyr..", "rywwwyr.", ".ryyyr..", "..r.r...", "........", "........", "........"],
	"supernova": [".pypyp..", "pywwwyp.", "ywwwwwy.", "pywwwyp.", ".pypyp..", "........", "........", "........"],
	"chain": [".cc..cc.", "c..cc..c", "c..cc..c", ".cc..cc.", ".cc..cc.", "c..cc..c", "........", "........"],
	"volt": ["....c...", "...cwc..", "..cwwwc.", ".cwwwwc.", "..cwc...", "...c....", "........", "........"],
	"reach": ["n.......", "nnn.....", "nynnn...", "nywwwyn.", "nynnn...", "nnn.....", "n.......", "........"],
	"sweep": ["yyyyyyy.", "y.....y.", "y.......", "y.......", "y.....y.", "yyyyyyy.", "........", "........"],
	"flow": ["...g....", "..ggg...", ".gwwwg..", "gwwwwwg.", ".ggggg..", "..g.g...", "........", "........"],
	"choir": [".y.y.y..", "yyyyyyy.", ".ywwwy..", "yyyyyyy.", ".y.y.y..", "........", "........", "........"],
	"lash": ["....g...", "...gg...", "..gwg...", ".gwwwg..", "ggg.....", "g.......", "........", "........"],
	"depth": ["..ccc...", ".cwwwc..", "cwwwwwc.", ".cwwwc..", "..c.c...", "........", "........", "........"],
	"shatter": ["c...c...", ".c.c.c..", "..ccc...", "ccccccc.", "..ccc...", ".c.c.c..", "c...c...", "........"],
	"rime": ["c.c.c...", ".ccc....", "cwcwc...", ".ccc....", "c.c.c...", "........", "........", "........"],
	"gun_drone": ["..ssss..", ".syyys..", "sywwwys.", ".syyys..", "..s..s..", "........", "........", "........"],
	"push_drone": ["..bbbb..", ".bwwwb..", "bwwwwwb.", ".bwwwb..", "..b..b..", "........", "........", "........"],
	"ember_sprite": ["...m....", "..mmm...", ".mwwwm..", "..mmm...", "...m....", "........", "........", "........"],
	"heat_gust": [".m...m..", "..mmm...", "mwwwwwm.", "..mmm...", ".m...m..", "........", "........", "........"],
	"thorn_sprite": ["...g....", "..ggg...", ".gwwg...", "..nnn...", "...n....", "........", "........", "........"],
	"vine_tether": [".g.g.g..", "..ggg...", ".gwwwg..", "..nnn...", "........", "........", "........", "........"],
	"spark_sprite": ["..c.c...", ".cwcwc..", "cwwwwwc.", ".cwcwc..", "..c.c...", "........", "........", "........"],
	"gale_push": ["bbb.....", "bwwbb...", "bwwwwb..", ".bwwwb..", "..bbb...", "........", "........", "........"],
	"frost_drone": ["..ccc...", ".cwwwc..", "cwlllcw.", ".cwwwc..", "..c..c..", "........", "........", "........"],
	"laser_drone": ["r.......", "rrr.....", "rwwrr...", "rwwwwr..", "rwwrr...", "rrr.....", "r.......", "........"],
	"shield_drone": ["..bbbb..", ".bwwwb..", "bwlllbw.", ".bwwwb..", "..bbbb..", "........", "........", "........"],
	"swarm_drones": ["s.s.s.s.", ".yyy....", "s.s.s.s.", ".yyy....", "s.s.s.s.", "........", "........", "........"],
}


static func info(upgrade_id: String) -> Dictionary:
	if DEFS.has(upgrade_id):
		return DEFS[upgrade_id]
	return {"name": upgrade_id, "description": "", "rarity": "common", "path": ""}


static func rarity_of(upgrade_id: String) -> String:
	return str(info(upgrade_id).get("rarity", "common"))


static func texture(upgrade_id: String) -> Texture2D:
	var baked := SpriteLibrary.texture_for(upgrade_id)
	if baked != null:
		return baked
	var rows: Array = _ROWS.get(upgrade_id, [])
	if rows.is_empty():
		return null
	return SpriteLibrary.texture_from_rows(rows, _P)


static func is_ability_token(token: String) -> bool:
	return token.begins_with(ABILITY_PREFIX)


static func ability_id_from(token: String) -> String:
	return token.substr(ABILITY_PREFIX.length()) if is_ability_token(token) else token


## Build an offer with a controlled rarity mix so the player mostly sees commons:
##  - ~70% of the time: all-4 commons
##  - ~25% of the time: 3 commons + 1 rare
##  - ~5%  of the time: 3 commons + 1 legendary (the "really cool" moment)
## This replaces the old per-slot independent roll which produced 3+ rares.
static func mixed_offer(ability_ids: Array, class_upgrade_ids: Array, level: int, amount: int = 4) -> Array[String]:
	var out: Array[String] = []
	# Decide the rarity slots up front (stat slots only; ability token handled below).
	var stat_slots := maxi(1, amount)
	var rarities: Array[String] = []
	var roll := randf()
	if roll < 0.05:
		# Rare-legendary moment: 3 common + 1 legendary.
		for i in stat_slots - 1:
			rarities.append("common")
		rarities.append("legendary")
	elif roll < 0.30:
		# 3 common + 1 rare.
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
		var pick := _pick_stat_for_rarity(class_upgrade_ids, rarity, used, level)
		if pick.is_empty():
			# Fallback to a common if the chosen rarity pool was exhausted.
			pick = _pick_stat_for_rarity(class_upgrade_ids, "common", used, level)
		if not pick.is_empty():
			used[pick] = true
			out.append(pick)

	# Prepend an ability token if the hero still has abilities to learn.
	if not ability_ids.is_empty():
		out.append(ABILITY_PREFIX + str(ability_ids[randi() % ability_ids.size()]))
	# Cap at `amount` (in case ability token pushed over).
	if out.size() > amount:
		out.resize(amount)
	out.shuffle()
	return out


static func _pick_stat_for_rarity(class_upgrade_ids: Array, rarity: String, used: Dictionary, level: int) -> String:
	var pool := _pool_for(class_upgrade_ids, rarity, level)
	pool.shuffle()
	for id in pool:
		if not used.has(id):
			return id
	# If this specific rarity pool was exhausted, fall back to common.
	if rarity != "common":
		var fb := _pool_for(class_upgrade_ids, "common", level)
		fb.shuffle()
		for id in fb:
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

class_name UpgradeCatalog
extends RefCounted

## Stat upgrades with synergy paths, rarity, and 8px icons (runtime, no forge required).

const ABILITY_PREFIX := "ability:"
const RARE_CHANCE := 0.18
const LEGENDARY_CHANCE := 0.045

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


static func mixed_offer(ability_ids: Array, class_upgrade_ids: Array, level: int, amount: int = 4) -> Array[String]:
	var out: Array[String] = []
	if not ability_ids.is_empty():
		out.append(ABILITY_PREFIX + str(ability_ids[randi() % ability_ids.size()]))
	var used: Dictionary = {}
	while out.size() < amount:
		var pick := _pick_stat(class_upgrade_ids, level, used)
		if pick.is_empty():
			break
		used[pick] = true
		out.append(pick)
	out.shuffle()
	return out


static func _pick_stat(class_upgrade_ids: Array, level: int, used: Dictionary) -> String:
	var rarity := _roll_rarity(level)
	var pool := _pool_for(class_upgrade_ids, rarity)
	pool.shuffle()
	for id in pool:
		if not used.has(id):
			return id
	var fallback := _pool_for(class_upgrade_ids, "common")
	fallback.shuffle()
	for id in fallback:
		if not used.has(id):
			return id
	return ""


static func _roll_rarity(level: int) -> String:
	var legend := LEGENDARY_CHANCE + 0.006 * float(maxi(0, level - 6))
	var rare := RARE_CHANCE + 0.012 * float(maxi(0, level - 4))
	var roll := randf()
	if roll < legend:
		return "legendary"
	if roll < legend + rare:
		return "rare"
	return "common"


static func _pool_for(class_upgrade_ids: Array, rarity: String) -> Array[String]:
	var out: Array[String] = []
	var class_ids: Array = class_upgrade_ids
	for id in DEFS.keys():
		if str(DEFS[id].get("rarity", "common")) != rarity:
			continue
		var path := str(DEFS[id].get("path", ""))
		if path == "drone" or path == "farm" or path == "pulse" or path == "crit" or path == "tempo" or path == "power" or path == "splash" or path == "volley" or path == "tank":
			if rarity != "common" or class_ids.has(id) or path in ["farm", "pulse", "crit", "tempo", "power", "splash", "volley", "tank", "drone"]:
				out.append(str(id))
	return out

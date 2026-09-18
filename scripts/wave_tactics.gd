class_name WaveTactics
extends RefCounted
## Wave tactics system (2026-09-18): assigns 2+ tactical behaviors per wave so
## enemy groups don't all just walk straight at the player. Each tactic modifies
## the spawn positions, speed, and (via enemy.gd) the movement pattern of the
## assigned group. Tactics scale in count with wave number:
##   waves 1-2: 1 tactic
##   waves 3-5: 2 tactics
##   waves 6-9: 3 tactics
##   waves 10+: 3-4 tactics
##
## Each tactic has:
##   - id (String): unique identifier
##   - name (String): human-readable
##   - min_wave (int): minimum wave number it can appear
##   - types (Array[String]): enemy type ids that fit this tactic
##   - speed_mult (float): speed multiplier applied to the group
##   - formation (int): preferred EnemyType.Formation value
##   - group_count_range (Vector2i): min/max group size for this tactic

enum TacticId {
	PINCER,
	PINCER_RANGED,
	ENCIRCLE,
	OVERWHELM,
	FEINT_STRIKE,
	SNIPER_CURTAIN,
	BOLT_SQUAD,
	WALL_PUSH,
	POISON_RAIN,
	ANVIL_CLAW,
	WING_HARASS,
	STAMPEDE,
}

const TACTICS: Array[Dictionary] = [
	{
		"id": TacticId.PINCER,
		"name": "Pincer",
		"min_wave": 3,
		"types": ["grunt", "swarmling", "cinderling"],
		"speed_mult": 1.15,
		"formation": 0,  # SCATTERED
		"group_count_range": Vector2i(4, 7),
		"num_groups": 2,  # two flanking groups
	},
	{
		"id": TacticId.PINCER_RANGED,
		"name": "Ranged Pincer",
		"min_wave": 5,
		"types": ["spitter", "hexer", "iceball"],
		"speed_mult": 0.95,
		"formation": 0,
		"group_count_range": Vector2i(3, 5),
		"num_groups": 2,
	},
	{
		"id": TacticId.ENCIRCLE,
		"name": "Encircle",
		"min_wave": 4,
		"types": ["swarmling", "grunt", "cinderling"],
		"speed_mult": 0.85,  # slow closing ring
		"formation": 3,  # RING
		"group_count_range": Vector2i(8, 12),
		"num_groups": 1,
	},
	{
		"id": TacticId.OVERWHELM,
		"name": "Overwhelm",
		"min_wave": 6,
		"types": ["swarmling", "charger", "sparkbot"],
		"speed_mult": 1.4,
		"formation": 1,  # PACK
		"group_count_range": Vector2i(5, 8),
		"num_groups": 3,
	},
	{
		"id": TacticId.FEINT_STRIKE,
		"name": "Feint & Strike",
		"min_wave": 8,
		"types": ["charger", "stalker", "ripcurrent"],
		"speed_mult": 1.3,
		"formation": 0,
		"group_count_range": Vector2i(3, 5),
		"num_groups": 2,
	},
	{
		"id": TacticId.SNIPER_CURTAIN,
		"name": "Sniper Curtain",
		"min_wave": 5,
		"types": ["spitter", "hexer", "sentinel"],
		"speed_mult": 0.9,
		"formation": 0,
		"group_count_range": Vector2i(4, 6),
		"num_groups": 2,
	},
	{
		"id": TacticId.BOLT_SQUAD,
		"name": "Bolt Squad",
		"min_wave": 7,
		"types": ["charger", "drifter", "sparkbot"],
		"speed_mult": 1.5,
		"formation": 1,
		"group_count_range": Vector2i(3, 5),
		"num_groups": 2,
	},
	{
		"id": TacticId.WALL_PUSH,
		"name": "Wall Push",
		"min_wave": 10,
		"types": ["brute", "sentinel", "lava_spitter"],
		"speed_mult": 0.7,  # slow, tanky advance
		"formation": 1,
		"group_count_range": Vector2i(4, 6),
		"num_groups": 1,
	},
	{
		"id": TacticId.POISON_RAIN,
		"name": "Poison Rain",
		"min_wave": 6,
		"types": ["spitter", "hexer", "summoner", "lava_spitter"],
		"speed_mult": 0.85,
		"formation": 0,
		"group_count_range": Vector2i(3, 5),
		"num_groups": 3,
	},
	{
		"id": TacticId.ANVIL_CLAW,
		"name": "Anvil & Claw",
		"min_wave": 12,
		"types": ["brute", "swarmling", "charger"],
		"speed_mult": 1.0,
		"formation": 1,
		"group_count_range": Vector2i(3, 5),
		"num_groups": 3,  # 1 anvil (brute) + 2 claw (swarmling/charger)
	},
	{
		"id": TacticId.WING_HARASS,
		"name": "Wing Harass",
		"min_wave": 8,
		"types": ["drifter", "bomber", "grunt"],
		"speed_mult": 1.1,
		"formation": 0,
		"group_count_range": Vector2i(3, 5),
		"num_groups": 2,
	},
	{
		"id": TacticId.STAMPEDE,
		"name": "Stampede",
		"min_wave": 10,
		"types": ["charger", "swarmling", "cinderling"],
		"speed_mult": 1.6,
		"formation": 1,
		"group_count_range": Vector2i(8, 12),
		"num_groups": 1,
	},
]


## Returns the number of tactics to use for a given wave.
static func tactic_count_for_wave(wave: int) -> int:
	if wave <= 2:
		return 1
	elif wave <= 5:
		return 2
	elif wave <= 9:
		return 3
	return 3 + (1 if wave % 3 == 0 else 0)  # 3 or 4 for wave 10+


## Picks random non-repeating tactics that are valid for the given wave.
static func pick_tactics(wave: int, count: int) -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	for t in TACTICS:
		if int(t.min_wave) <= wave:
			valid.append(t)
	if valid.is_empty():
		return []
	valid.shuffle()
	var result: Array[Dictionary] = []
	for i in mini(count, valid.size()):
		result.append(valid[i])
	return result


## Generates the group dictionaries for a tactic.
## Returns an array of group dicts (same format as wave_director._make_group).
## Each dict has: type_id, formation, count, health_multiplier, speed_multiplier,
## and a "tactic" key with the tactic id.
static func generate_groups(tactic: Dictionary, health_mult: float, available_types: Array[Dictionary]) -> Array[Dictionary]:
	var tactic_id: int = int(tactic.id)
	var types: Array[String] = tactic.types
	var num_groups: int = int(tactic.num_groups)
	var formation: int = int(tactic.formation)
	var speed_mult: float = float(tactic.speed_mult)
	var count_range: Vector2i = tactic.group_count_range

	# Filter to types that are actually available.
	var usable: Array[String] = []
	for t in types:
		usable.append(t)
	if usable.is_empty():
		usable = ["grunt"]

	var groups: Array[Dictionary] = []
	for g in num_groups:
		# For ANVIL_CLAW: first group is the anvil (brute), remaining are claws.
		var type_id: String
		if tactic_id == TacticId.ANVIL_CLAW:
			if g == 0:
				type_id = "brute" if "brute" in usable else usable[0]
			else:
				var claw_types: Array[String] = []
				for t in usable:
					if t != "brute":
						claw_types.append(t)
				type_id = claw_types[0] if not claw_types.is_empty() else usable[0]
		else:
			type_id = usable[g % usable.size()]

		var count: int
		if tactic_id == TacticId.ANVIL_CLAW and g == 0:
			count = maxi(2, count_range.x / 2)  # fewer, tanky anvil
		else:
			count = randi_range(count_range.x, count_range.y)

		groups.append({
			"type_id": type_id,
			"formation": formation,
			"count": count,
			"health_multiplier": health_mult,
			"speed_multiplier": speed_mult,
			"tactic": tactic_id,
			"tactic_index": g,  # which group in the tactic (0 = first/anvil, etc.)
		})

	return groups


## Gets a human-readable tactic name for the HUD/log.
static func name_for(tactic_id: int) -> String:
	for t in TACTICS:
		if int(t.id) == tactic_id:
			return str(t.name)
	return "Unknown"

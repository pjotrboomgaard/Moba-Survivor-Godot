class_name ShopCatalog
extends RefCounted

## SuperMercator: each suit is a look plus a mechanic. Level-up still sells the
## plain stat bumps (damage, attack speed, move speed, HP); the shop never does.
## Items are filtered per hero so a hover-medic does not buy a skateboard.

const ACTIVE_ITEM_ID := "sirene"
const SHOP_PRICE_MULTIPLIER := 18
const SHOP_MAX_STACKS := 5
const ALL_HEROES: Array[String] = [
	"tobor", "arclight", "bulwark", "warden", "frostbinder",
	"cinder", "pyra", "slag", "ember",
	"thorn", "willow", "stump", "sage",
	"volt", "nebula", "astral", "rime",
]
const TOBOR_ONLY: Array[String] = ["tobor"]

const ITEMS: Array[Dictionary] = [
	{
		"id": "sirene",
		"name": "Siren",
		"description": "SPACE: dash through enemies for 1.5s (+90% speed). 9s cooldown. Ranks 2-5: longer dash, shorter cooldown.",
		"base_price": 70,
		"price_step": 48,
		"max_stacks": SHOP_MAX_STACKS,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Overclock", "description": "SPACE: 1.5s volt-dash through enemies. 9s cooldown."},
			"bulwark": {"name": "Charge", "description": "SPACE: 1.5s charge through the horde. 9s cooldown."},
			"warden": {"name": "Hover Boost", "description": "SPACE: 1.5s hover-boost through enemies. 9s cooldown."},
				"frostbinder": {"name": "Blink Step", "description": "SPACE: 1.5s frost-dash through enemies. 9s cooldown."},
				"rime": {"name": "Glacial Dash", "description": "SPACE: 1.5s ice-dash through enemies. 9s cooldown."},
				"cinder": {"name": "Cinder Dash", "description": "SPACE: 1.5s burning dash through enemies. 9s cooldown."},
				"pyra": {"name": "Flare Sprint", "description": "SPACE: 1.5s flare-dash through enemies. 9s cooldown."},
				"slag": {"name": "Magma Charge", "description": "SPACE: 1.5s molten charge through the horde. 9s cooldown."},
				"ember": {"name": "Witch Dash", "description": "SPACE: 1.5s hexfire dash through enemies. 9s cooldown."},
				"thorn": {"name": "Vine Dash", "description": "SPACE: 1.5s vine-dash through enemies. 9s cooldown."},
				"willow": {"name": "Quickstep", "description": "SPACE: 1.5s dash through enemies. 9s cooldown."},
				"stump": {"name": "Root Charge", "description": "SPACE: 1.5s root-charge through the horde. 9s cooldown."},
				"sage": {"name": "Fae Sprint", "description": "SPACE: 1.5s fae-dash through enemies. 9s cooldown."},
				"volt": {"name": "Gale Dash", "description": "SPACE: 1.5s wind-dash through enemies. 9s cooldown."},
				"nebula": {"name": "Time Skip", "description": "SPACE: 1.5s blink-dash through enemies. 9s cooldown."},
				"astral": {"name": "Starlight Dash", "description": "SPACE: 1.5s starlight dash through enemies. 9s cooldown."},
		},
	},
	{
		"id": "antenne",
		"name": "Mech Arms",
		"description": "Pulls enemies and XP within 170 toward you. Ranks 2-5: wider pull, more thorns.",
		"base_price": 48,
		"price_step": 36,
		"max_stacks": SHOP_MAX_STACKS,
		"grab_radius": 170.0,
		"grab_radius_step": 38.0,
		"thorns_ratio": 0.15,
		"thorns_ratio_step": 0.08,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Magnet Coil", "description": "Pulls enemies and XP within 170 toward the staff."},
			"bulwark": {"name": "Grabber", "description": "Drags enemies and XP within 170 toward your shield."},
			"warden": {"name": "Tractor Beam", "description": "Pulls enemies and XP within 170 toward the hover cone."},
				"frostbinder": {"name": "Frost Anchor", "description": "Pulls enemies and XP within 170 toward the frost core."},
				"rime": {"name": "Glacial Pull", "description": "Pulls enemies and XP within 170 toward the ice core."},
				"cinder": {"name": "Ember Draw", "description": "Pulls enemies and XP within 170 toward the cinder trail."},
				"pyra": {"name": "Flak Magnet", "description": "Pulls enemies and XP within 170 toward the barrage post."},
				"slag": {"name": "Molten Drag", "description": "Pulls enemies and XP within 170 toward the furnace."},
				"ember": {"name": "Hex Pull", "description": "Pulls enemies and XP within 170 toward the coven fire."},
				"thorn": {"name": "Thorn Snare", "description": "Pulls enemies and XP within 170 toward the venom."},
				"willow": {"name": "Vine Hook", "description": "Pulls enemies and XP within 170 toward the bowstring."},
				"stump": {"name": "Root Grasp", "description": "Pulls enemies and XP within 170 toward the fort."},
				"sage": {"name": "Fae Lure", "description": "Pulls enemies and XP within 170 toward the grove."},
				"volt": {"name": "Cyclone Pull", "description": "Pulls enemies and XP within 170 toward the gale."},
				"nebula": {"name": "Gravity Pull", "description": "Pulls enemies and XP within 170 toward the rift."},
				"astral": {"name": "Starlight Pull", "description": "Pulls enemies and XP within 170 toward the beacon."},
		},
	},
	{
		"id": "sjaal",
		"name": "Wings",
		"description": "+1.5 HP/s. Hoverboard jumps hang longer. Ranks 2-5: more regen.",
		"base_price": 52,
		"price_step": 38,
		"max_stacks": SHOP_MAX_STACKS,
		"health_regen_per_second": 1.5,
		"health_regen_per_second_step": 1.0,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Feathered Cloak", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
			"bulwark": {"name": "Mending Plating", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
			"warden": {"name": "Mossy Vestment", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"frostbinder": {"name": "Frost Ward", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"rime": {"name": "Glacier's Blessing", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"cinder": {"name": "Ashwing Cloak", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"pyra": {"name": "Flare Vest", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"slag": {"name": "Slag Plating", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"ember": {"name": "Witchfire Shawl", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"thorn": {"name": "Venom-Proof Cloak", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"willow": {"name": "Leafwing Cape", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"stump": {"name": "Bark Plating", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"sage": {"name": "Petal Shawl", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"volt": {"name": "Windward Cloak", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"nebula": {"name": "Aeon Shroud", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
				"astral": {"name": "Lumen Veil", "description": "+1.5 HP/s. Ranks 2-5: more regen."},
		},
	},
	{
		"id": "romp",
		"name": "Jetpack",
		"description": "Hops every 2s. Landing slams enemies in a circle. Ranks 2-5: harder slam.",
		"base_price": 62,
		"price_step": 44,
		"max_stacks": SHOP_MAX_STACKS,
		"jetpack_slam": 32.0,
		"jetpack_slam_step": 18.0,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Charge Booster", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
			"bulwark": {"name": "Siege Boots", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
			"warden": {"name": "Glider Tunic", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"frostbinder": {"name": "Ice Ram", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"rime": {"name": "Glacial Stomp", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"cinder": {"name": "Cinder Boots", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"pyra": {"name": "Flak Boosters", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"slag": {"name": "Furnace Treads", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"ember": {"name": "Broomstick Hops", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"thorn": {"name": "Spore Hops", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"willow": {"name": "Bounding Boots", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"stump": {"name": "Root Stomp", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"sage": {"name": "Fae Hops", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"volt": {"name": "Gale Hops", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"nebula": {"name": "Rewind Hops", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
				"astral": {"name": "Star Hops", "description": "Hops every 2s. Landing slams enemies. Ranks 2-5: harder slam."},
		},
	},
	{
		"id": "armen",
		"name": "Cannons",
		"description": "Hits knock enemies far back. Ranks 2-5: stronger knockback.",
		"base_price": 70,
		"price_step": 48,
		"max_stacks": SHOP_MAX_STACKS,
		"knockback_strength": 520.0,
		"knockback_strength_step": 160.0,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Recoil", "description": "Staff hits knock enemies far back."},
			"bulwark": {"name": "Shield Bash", "description": "Slams knock enemies far back."},
			"warden": {"name": "Repulsor", "description": "Plus Beam knocks enemies far back."},
				"frostbinder": {"name": "Frost Cannons", "description": "Hits knock enemies far back."},
				"rime": {"name": "Glacial Cannons", "description": "Hits knock enemies far back."},
				"cinder": {"name": "Cinder Cannons", "description": "Hits knock enemies far back."},
				"pyra": {"name": "Flak Cannons", "description": "Hits knock enemies far back."},
				"slag": {"name": "Slag Cannons", "description": "Hits knock enemies far back."},
				"ember": {"name": "Hexfire Cannons", "description": "Hits knock enemies far back."},
				"thorn": {"name": "Thorn Cannons", "description": "Hits knock enemies far back."},
				"willow": {"name": "Longbow Cannons", "description": "Hits knock enemies far back."},
				"stump": {"name": "Root Cannons", "description": "Hits knock enemies far back."},
				"sage": {"name": "Fae Cannons", "description": "Hits knock enemies far back."},
				"volt": {"name": "Gale Cannons", "description": "Hits knock enemies far back."},
				"nebula": {"name": "Aeon Cannons", "description": "Hits knock enemies far back."},
				"astral": {"name": "Lumina Cannons", "description": "Hits knock enemies far back."},
		},
	},
	{
		"id": "benen",
		"name": "Grippers",
		"description": "Hits slow enemies by 25% for 0.8s. Ranks 2-5: longer slow.",
		"base_price": 62,
		"price_step": 44,
		"max_stacks": SHOP_MAX_STACKS,
		"hit_slow_factor": 0.75,
		"hit_slow_duration": 0.8,
		"hit_slow_duration_step": 0.25,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Static Latch", "description": "Hits slow enemies by 25%."},
			"bulwark": {"name": "Heavy Hands", "description": "Hits slow enemies by 25%."},
			"warden": {"name": "Root Grip", "description": "Hits slow enemies by 25%."},
				"frostbinder": {"name": "Rimelock", "description": "Hits slow enemies by 25%."},
				"rime": {"name": "Ice Grip", "description": "Hits slow enemies by 25%."},
				"cinder": {"name": "Cinder Latch", "description": "Hits slow enemies by 25%."},
				"pyra": {"name": "Slug Rounds", "description": "Hits slow enemies by 25%."},
				"slag": {"name": "Molten Grip", "description": "Hits slow enemies by 25%."},
				"ember": {"name": "Hex Latch", "description": "Hits slow enemies by 25%."},
				"thorn": {"name": "Vine Grip", "description": "Hits slow enemies by 25%."},
				"willow": {"name": "Bramble Grip", "description": "Hits slow enemies by 25%."},
				"stump": {"name": "Root Grip", "description": "Hits slow enemies by 25%."},
				"sage": {"name": "Fae Latch", "description": "Hits slow enemies by 25%."},
				"volt": {"name": "Gale Latch", "description": "Hits slow enemies by 25%."},
				"nebula": {"name": "Time Latch", "description": "Hits slow enemies by 25%."},
				"astral": {"name": "Star Latch", "description": "Hits slow enemies by 25%."},
		},
	},
	{
		"id": "hoverboard",
		"name": "Hoverboard",
		"description": "+45% move speed. Press Space (or C) to hop over rocks, trees, and lava. Wings lengthen the hang. Ranks 2-5: more speed.",
		"base_price": 82,
		"price_step": 55,
		"max_stacks": SHOP_MAX_STACKS,
		"skate_speed_bonus": 0.45,
		"skate_speed_bonus_step": 0.12,
		"pickup_radius_bonus": 0.25,
		"pickup_radius_bonus_step": 0.08,
		"board_jump": true,
		"heroes": TOBOR_ONLY,
	},
]


static func ids() -> Array[String]:
	var item_ids: Array[String] = []
	for item in ITEMS:
		item_ids.append(str(item.id))
	return item_ids


static func by_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if str(item.id) == item_id:
			return item
	return {}


static func is_valid_id(item_id: String) -> bool:
	return not by_id(item_id).is_empty()


static func available_for(item_id: String, class_id: String) -> bool:
	var item := by_id(item_id)
	if item.is_empty():
		return false
	var heroes: Array = item.get("heroes", ALL_HEROES)
	return class_id in heroes


static func items_for(class_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for item in ITEMS:
		if available_for(str(item.id), class_id):
			found.append(item)
	return found


static func display_name(item_id: String, class_id: String) -> String:
	var item := by_id(item_id)
	if item.is_empty():
		return item_id
	var alias: Dictionary = item.get("alias", {}).get(class_id, {})
	return str(alias.get("name", item.name))


static func display_description(item_id: String, class_id: String) -> String:
	var item := by_id(item_id)
	if item.is_empty():
		return ""
	var alias: Dictionary = item.get("alias", {}).get(class_id, {})
	return str(alias.get("description", item.description))


static func price_for(item_id: String, owned_stacks: int) -> int:
	var item := by_id(item_id)
	if item.is_empty():
		return 0
	return (int(item.base_price) + int(item.price_step) * maxi(0, owned_stacks)) * SHOP_PRICE_MULTIPLIER


static func is_sold_out(item_id: String, owned_stacks: int) -> bool:
	var item := by_id(item_id)
	if item.is_empty():
		return true
	return owned_stacks >= int(item.max_stacks)

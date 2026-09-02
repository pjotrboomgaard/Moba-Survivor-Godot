class_name ShopCatalog
extends RefCounted

## SuperMercator: each suit is a look plus a mechanic. Level-up still sells the
## plain stat bumps (damage, attack speed, move speed, HP); the shop never does.
## Items are filtered per hero so a hover-medic does not buy a skateboard.

const ACTIVE_ITEM_ID := "sirene"
const SHOP_PRICE_MULTIPLIER := 10
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
		"description": "SPACE: dash through enemies for 1.5s (+90% speed). 9s cooldown.",
		"base_price": 45,
		"price_step": 0,
		"max_stacks": 1,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Overclock", "description": "SPACE: 1.5s volt-dash through enemies. 9s cooldown."},
			"bulwark": {"name": "Charge", "description": "SPACE: 1.5s charge through the horde. 9s cooldown."},
			"warden": {"name": "Hover Boost", "description": "SPACE: 1.5s hover-boost through enemies. 9s cooldown."},
		},
	},
	{
		"id": "antenne",
		"name": "Mech Arms",
		"description": "Pulls enemies and XP within 170 toward you.",
		"base_price": 25,
		"price_step": 0,
		"max_stacks": 1,
		"grab_radius": 170.0,
		"thorns_ratio": 0.15,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Magnet Coil", "description": "Pulls enemies and XP within 170 toward the staff."},
			"bulwark": {"name": "Grabber", "description": "Drags enemies and XP within 170 toward your shield."},
			"warden": {"name": "Tractor Beam", "description": "Pulls enemies and XP within 170 toward the hover cone."},
		},
	},
	{
		"id": "sjaal",
		"name": "Wings",
		"description": "+1.5 HP/s. Stay airborne longer with the jetpack.",
		"base_price": 30,
		"price_step": 0,
		"max_stacks": 1,
		"health_regen_per_second": 1.5,
		"heroes": TOBOR_ONLY,
	},
	{
		"id": "romp",
		"name": "Jetpack",
		"description": "Hops every 2s. Landing slams enemies in a circle.",
		"base_price": 40,
		"price_step": 0,
		"max_stacks": 1,
		"jetpack_slam": 32.0,
		"heroes": TOBOR_ONLY,
	},
	{
		"id": "armen",
		"name": "Cannons",
		"description": "Hits knock enemies far back.",
		"base_price": 45,
		"price_step": 0,
		"max_stacks": 1,
		"knockback_strength": 520.0,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Recoil", "description": "Staff hits knock enemies far back."},
			"bulwark": {"name": "Shield Bash", "description": "Slams knock enemies far back."},
			"warden": {"name": "Repulsor", "description": "Plus Beam knocks enemies far back."},
		},
	},
	{
		"id": "benen",
		"name": "Tentacles",
		"description": "Heal for 8% of the damage you deal.",
		"base_price": 40,
		"price_step": 0,
		"max_stacks": 1,
		"lifesteal_ratio": 0.08,
		"heroes": ALL_HEROES,
		"alias": {
			"arclight": {"name": "Volt Siphon", "description": "8% of your lightning damage returns as HP."},
			"bulwark": {"name": "Revenge Plate", "description": "8% of your slam damage returns as HP."},
			"warden": {"name": "Plus Drain", "description": "8% of your Plus Beam damage returns as HP."},
		},
	},
	{
		"id": "hoverboard",
		"name": "Skateboard",
		"description": "No more wobble: +45% move speed, glide across the arena.",
		"base_price": 50,
		"price_step": 0,
		"max_stacks": 1,
		"skate_speed_bonus": 0.45,
		"pickup_radius_bonus": 0.25,
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

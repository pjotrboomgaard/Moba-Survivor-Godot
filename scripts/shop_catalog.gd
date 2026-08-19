class_name ShopCatalog
extends RefCounted

## MOBA-style between-wave items. These deliberately avoid the raw stat lines
## the level-up pool already sells: every item here adds a mechanic the player
## does not otherwise have. Prices climb with every copy owned.

const ACTIVE_ITEM_ID := "phase_boots"
## Shop prices are scaled up so full gold income still keeps purchases scarce.
const SHOP_PRICE_MULTIPLIER := 10

const ITEMS: Array[Dictionary] = [
	{
		"id": "carapace",
		"name": "Spiked Carapace",
		"description": "Reflect 25% of melee damage back at the attacker",
		"base_price": 40,
		"price_step": 30,
		"max_stacks": 4,
	},
	{
		"id": "phase_boots",
		"name": "Phase Boots",
		"description": "ACTIVE (Space): sprint for 1.5s, 9s cooldown",
		"base_price": 45,
		"price_step": 40,
		"max_stacks": 4,
	},
	{
		"id": "bloodfang",
		"name": "Bloodfang",
		"description": "Heal for 8% of the damage you deal",
		"base_price": 45,
		"price_step": 35,
		"max_stacks": 5,
	},
	{
		"id": "pendant",
		"name": "Regrowth Pendant",
		"description": "Regenerate 1.5 health per second",
		"base_price": 35,
		"price_step": 25,
		"max_stacks": 6,
	},
	{
		"id": "prism",
		"name": "Rending Prism",
		"description": "Ignore 20% of enemy resistance to your damage type",
		"base_price": 50,
		"price_step": 40,
		"max_stacks": 4,
	},
	{
		"id": "aegis",
		"name": "Aegis Sigil",
		"description": "Once per wave, survive a lethal hit at 35% health",
		"base_price": 70,
		"price_step": 60,
		"max_stacks": 2,
	},
	{
		"id": "ember",
		"name": "Ember Aura",
		"description": "Burn enemies within 140 for 6 damage per second",
		"base_price": 55,
		"price_step": 40,
		"max_stacks": 5,
	},
	{
		"id": "frostbite",
		"name": "Frostbite Charm",
		"description": "Your hits slow enemies by 20% for 1s",
		"base_price": 45,
		"price_step": 35,
		"max_stacks": 3,
	},
	{
		"id": "lodestone",
		"name": "Lodestone",
		"description": "Pull XP orbs in from 60% further away",
		"base_price": 30,
		"price_step": 20,
		"max_stacks": 4,
	},
	{
		"id": "bash",
		"name": "War Maul",
		"description": "Every hit knocks enemies back",
		"base_price": 50,
		"price_step": 35,
		"max_stacks": 3,
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

extends Node

## Solo hero-unlock helpers. Shards bank per hero as you clear milestone waves; a hero
## unlocks once it banked enough, also unlocking by hero for multiplayer/CPU for free.

## Spend the current-oriented spark/shard pool on any hero the player can now afford.
func auto_unlock_affordable() -> void:
	for class_data in PlayerClass.CLASSES:
		var hero_id := str(class_data.id)
		if PlayerProfile.unlocked_heroes.get(hero_id, false):
			continue
		if int(PlayerProfile.hero_shards.get(hero_id, 0)) >= PlayerProfile.HERO_SHARDS_TO_UNLOCK:
			PlayerProfile.unlock_hero(hero_id)


## Unlock every locked hero — used by multiplayer and CPU ally spawns, which must be able to
## field the full roster regardless of the local player's solo shard progress.
func unlock_entire_roster() -> void:
	for class_data in PlayerClass.CLASSES:
		PlayerProfile.unlock_hero(str(class_data.id))


## Progress toward a hero's unlock, for menu display (0.0..1.0 and a shard count label).
func unlock_progress(hero_id: String) -> float:
	return clampf(
		float(int(PlayerProfile.hero_shards.get(hero_id, 0))) / float(PlayerProfile.HERO_SHARDS_TO_UNLOCK),
		0.0,
		1.0
	)

extends Node

const PROFILE_PATH := "user://local_profile.json"

## Shards a hero must bank before it unlocks for solo play.
const HERO_SHARDS_TO_UNLOCK := 300
## Every N fully cleared waves banks one more ability from the hero's pool (mastery reward).
const ABILITY_EVERY_WAVES := 5
## Sparks credited to mastery each time a 5-wave milestone is beaten (per milestone step).
const MASTERY_SPARKS_PER_STEP := 5.0

var player_id := ""
var display_name := "Player"
var selected_class_id := PlayerClass.DEFAULT_CLASS_ID
var linked_platforms: Dictionary = {}
var sfx_enabled := true
var music_enabled := true

## Solo meta-progression: sparks earned by surviving waves, hero shards toward unlocks.
## hero_shards:    hero_id -> shard count owned. unlocked_heroes: hero_id -> true.
var sparks := 0.0
var hero_shards: Dictionary = {}
var unlocked_heroes: Dictionary = {}

## hero_mastery: hero_id -> {
##   "best_wave": int,
##   "sparks_banked": float,
##   "abilities_unlocked": Array[String],
##   "ult_unlocked": bool,
##   "banked": int  (count of pool abilities granted so far)
## }
var hero_mastery: Dictionary = {}


func _ready() -> void:
	_load_or_create_profile()


func _load_or_create_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var profile_file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if profile_file != null:
			var parsed: Variant = JSON.parse_string(profile_file.get_as_text())
			if parsed is Dictionary:
				player_id = str(parsed.get("player_id", ""))
				display_name = str(parsed.get("display_name", "Player"))
				selected_class_id = PlayerClass.sanitize_id(str(parsed.get("selected_class_id", PlayerClass.DEFAULT_CLASS_ID)))
				linked_platforms = parsed.get("linked_platforms", {})
				sfx_enabled = bool(parsed.get("sfx_enabled", true))
				music_enabled = bool(parsed.get("music_enabled", true))
				sparks = float(parsed.get("sparks", 0.0))
				hero_shards = parsed.get("hero_shards", {})
				var saved_unlocked: Variant = parsed.get("unlocked_heroes", {})
				if saved_unlocked is Array:
					unlocked_heroes = {}
					for hero_id in saved_unlocked:
						unlocked_heroes[str(hero_id)] = true
				elif saved_unlocked is Dictionary:
					unlocked_heroes = saved_unlocked
				hero_mastery = parsed.get("hero_mastery", {})
	if player_id.is_empty():
		player_id = _generate_local_player_id()
		_save_profile()


func select_class(class_id: String) -> void:
	var sanitized := PlayerClass.sanitize_id(class_id)
	if sanitized == selected_class_id:
		return
	selected_class_id = sanitized
	_save_profile()


func save_display_name() -> void:
	_save_profile()


func save_audio_prefs() -> void:
	_save_profile()


## ---------------------------------------------------------------------------
## Sparks + hero shards: the solo earn/spend pool.
## ---------------------------------------------------------------------------

func grant_sparks(amount: float, hero_id: String = "") -> void:
	sparks += amount
	if not hero_id.is_empty() and PlayerClass.is_valid_id(hero_id):
		grant_hero_shard(hero_id, int(amount))
	_save_profile()


func grant_hero_shard(hero_id: String, amount: int = 1) -> void:
	if not PlayerClass.is_valid_id(hero_id):
		return
	hero_shards[hero_id] = int(hero_shards.get(hero_id, 0)) + amount
	_save_profile()


func unlock_hero(hero_id: String) -> void:
	if not PlayerClass.is_valid_id(hero_id) or unlocked_heroes.get(hero_id, false):
		return
	unlocked_heroes[hero_id] = true
	_save_profile()


## ---------------------------------------------------------------------------
## Hero mastery: per-hero banked progression from solo runs.
## ---------------------------------------------------------------------------

func mastery_for(hero_id: String) -> Dictionary:
	var mastery: Dictionary = hero_mastery.get(hero_id, {})
	# Migrate/seed the canonical shape; legacy saves used an "unlocked_abilities" dict.
	if not mastery.has("abilities_unlocked"):
		var legacy: Variant = mastery.get("unlocked_abilities", [])
		var abilities: Array[String] = []
		if legacy is Dictionary:
			for key in legacy.keys():
				if bool(legacy[key]):
					abilities.append(str(key))
		elif legacy is Array:
			for key in legacy:
				abilities.append(str(key))
		mastery["abilities_unlocked"] = abilities
	if not mastery.has("best_wave"):
		mastery["best_wave"] = 0
	if not mastery.has("sparks_banked"):
		mastery["sparks_banked"] = 0.0
	if not mastery.has("ult_unlocked"):
		mastery["ult_unlocked"] = true
	if not mastery.has("banked"):
		mastery["banked"] = (mastery["abilities_unlocked"] as Array).size()
	hero_mastery[hero_id] = mastery
	return mastery


## Every 5 waves survived banks sparks into mastery and grants one more ability from the
## hero's pool (in pool order, skipping the kit); paid out once per run end.
func bank_wave_progress(hero_id: String, wave_beaten: int) -> Dictionary:
	if not PlayerClass.is_valid_id(hero_id) or wave_beaten <= 0:
		return {"newly_unlocked": [], "banked": 0}
	var mastery := mastery_for(hero_id)
	var sparks_earned := float(wave_beaten / ABILITY_EVERY_WAVES) * MASTERY_SPARKS_PER_STEP
	if sparks_earned > 0.0:
		grant_sparks(sparks_earned, hero_id)
		mastery["sparks_banked"] = float(mastery.get("sparks_banked", 0.0)) + sparks_earned
	var pool := PlayerClass.ability_pool_for(hero_id)
	var kit := PlayerClass.kit_ability_ids(hero_id)
	var candidates: Array[String] = []
	for ability_id in pool:
		if ability_id not in kit:
			candidates.append(ability_id)
	var unlocked: Array = mastery["abilities_unlocked"]
	var earned := maxi(0, wave_beaten / ABILITY_EVERY_WAVES)
	var already := mini(int(mastery.get("banked", 0)), candidates.size())
	var newly: Array[String] = []
	for i in range(already, mini(earned, candidates.size())):
		var aid := candidates[i]
		if aid not in unlocked:
			unlocked.append(aid)
			newly.append(aid)
	mastery["abilities_unlocked"] = unlocked
	mastery["banked"] = already + newly.size()
	mastery["best_wave"] = maxi(int(mastery.get("best_wave", 0)), wave_beaten)
	hero_mastery[hero_id] = mastery
	_save_profile()
	return {"newly_unlocked": newly, "banked": mastery["banked"]}


## Ults are unlocked from the start.
func is_ult_unlocked(_hero_id: String) -> bool:
	return true


## Slow ramp: 5 sparks at wave 5, 10 at 10, 15 at 15, a bonus step every 10 after 20.
func sparks_for_wave(wave_index: int) -> float:
	if wave_index <= 0:
		return 0.0
	var step := int(floor(wave_index / 5.0))
	return float(5 * step + maxi(0, step - 4))


## Default 4-ability loadout: Q, E, first non-kit from pool, R.
func loadout_for(hero_id: String) -> Array[String]:
	var out: Array[String] = []
	var kit := PlayerClass.kit_ability_ids(hero_id)
	var pool := PlayerClass.ability_pool_for(hero_id)
	var alt := ""
	for ability_id in pool:
		if ability_id not in kit:
			alt = ability_id
			break
	for i in [0, 1]:
		out.append(kit[i] if kit.size() > i else "")
	out.append(alt)
	if kit.size() > 2:
		out.append(kit[2])
	return out


func _generate_local_player_id() -> String:
	var source := "%s:%s:%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]
	return source.sha256_text().substr(0, 32)


func _save_profile() -> void:
	var profile_file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if profile_file == null:
		push_error("Unable to save local player profile")
		return
	profile_file.store_string(JSON.stringify({
		"player_id": player_id,
		"display_name": display_name,
		"selected_class_id": selected_class_id,
		"linked_platforms": linked_platforms,
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"sparks": sparks,
		"hero_shards": hero_shards,
		"unlocked_heroes": unlocked_heroes,
		"hero_mastery": hero_mastery,
	}, "\t"))

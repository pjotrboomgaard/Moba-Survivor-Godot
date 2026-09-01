extends Node

const PROFILE_PATH := "user://local_profile.json"

var player_id := ""
var display_name := "Player"
var selected_class_id := PlayerClass.DEFAULT_CLASS_ID
var linked_platforms: Dictionary = {}
var sfx_enabled := true
var music_enabled := true


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


## Ults are unlocked from the start.
func is_ult_unlocked(_hero_id: String) -> bool:
	return true


func bank_wave_progress(_hero_id: String, _wave_beaten: int) -> Dictionary:
	return {"newly_unlocked": [], "banked": 0}


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
	}, "\t"))

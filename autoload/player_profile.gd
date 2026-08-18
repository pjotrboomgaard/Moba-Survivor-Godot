extends Node

const PROFILE_PATH := "user://local_profile.json"

var player_id := ""
var display_name := "Player"
var linked_platforms: Dictionary = {}


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
				linked_platforms = parsed.get("linked_platforms", {})

	if player_id.is_empty():
		player_id = _generate_local_player_id()
		_save_profile()


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
		"linked_platforms": linked_platforms,
	}, "\t"))

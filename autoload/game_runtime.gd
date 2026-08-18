extends Node

signal mode_changed(mode: RuntimeMode)

enum RuntimeMode {
	OFFLINE,
	HOST,
	CLIENT,
	DEDICATED_SERVER,
}

## Classic preserves the original single-hero Arc Staff run.
## Pjotr mode unlocks the four heroes, the full enemy roster, waves and bosses.
enum GameMode {
	CLASSIC,
	PJOTR,
}

const DEFAULT_PORT := 27015
const DEFAULT_MAX_PLAYERS := 4

var mode: RuntimeMode = RuntimeMode.OFFLINE
var game_mode: GameMode = GameMode.PJOTR
## Debug aid: skip ahead so late waves and bosses can be reached without a full run.
var start_wave := 1
var server_address := "127.0.0.1"
var server_port := DEFAULT_PORT
var max_players := DEFAULT_MAX_PLAYERS


func _ready() -> void:
	configure_from_arguments(OS.get_cmdline_user_args())


func configure_from_arguments(arguments: PackedStringArray) -> void:
	var next_mode := RuntimeMode.OFFLINE
	var next_address := "127.0.0.1"
	var next_port := DEFAULT_PORT

	if OS.has_feature("dedicated_server"):
		next_mode = RuntimeMode.DEDICATED_SERVER

	for argument in arguments:
		if argument == "--server":
			next_mode = RuntimeMode.DEDICATED_SERVER
		elif argument == "--host":
			next_mode = RuntimeMode.HOST
		elif argument.begins_with("--join="):
			next_mode = RuntimeMode.CLIENT
			next_address = argument.trim_prefix("--join=")
		elif argument.begins_with("--start-wave="):
			start_wave = maxi(1, int(argument.split("=")[1]))
		elif argument == "--classic":
			game_mode = GameMode.CLASSIC
		elif argument == "--pjotr":
			game_mode = GameMode.PJOTR
		elif argument.begins_with("--port="):
			var requested_port := argument.trim_prefix("--port=").to_int()
			if requested_port > 0 and requested_port <= 65535:
				next_port = requested_port

	mode = next_mode
	server_address = next_address
	server_port = next_port
	mode_changed.emit(mode)


func set_game_mode(next_game_mode: GameMode) -> void:
	game_mode = next_game_mode


func is_classic() -> bool:
	return game_mode == GameMode.CLASSIC


func active_class_id() -> String:
	if is_classic():
		return PlayerClass.DEFAULT_CLASS_ID
	return PlayerProfile.selected_class_id


func game_mode_name() -> String:
	return "classic" if is_classic() else "pjotr"


func is_server() -> bool:
	return mode == RuntimeMode.HOST or mode == RuntimeMode.DEDICATED_SERVER


func is_client() -> bool:
	return mode == RuntimeMode.CLIENT


func is_dedicated_server() -> bool:
	return mode == RuntimeMode.DEDICATED_SERVER


func set_runtime_mode(next_mode: RuntimeMode, address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> void:
	mode = next_mode
	server_address = address
	server_port = clampi(port, 1, 65535)
	mode_changed.emit(mode)


func mode_name() -> String:
	return RuntimeMode.keys()[mode].to_lower()

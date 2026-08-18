extends Node

signal mode_changed(mode: RuntimeMode)

enum RuntimeMode {
	OFFLINE,
	HOST,
	CLIENT,
	DEDICATED_SERVER,
}

const DEFAULT_PORT := 27015
const DEFAULT_MAX_PLAYERS := 4

var mode: RuntimeMode = RuntimeMode.OFFLINE
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
		elif argument.begins_with("--port="):
			var requested_port := argument.trim_prefix("--port=").to_int()
			if requested_port > 0 and requested_port <= 65535:
				next_port = requested_port

	mode = next_mode
	server_address = next_address
	server_port = next_port
	mode_changed.emit(mode)


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

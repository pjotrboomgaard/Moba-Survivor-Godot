extends Node

const GAME_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

@onready var backdrop: ColorRect = $StatusLayer/Backdrop
@onready var lobby_panel: PanelContainer = $StatusLayer/LobbyPanel
@onready var address_input: LineEdit = $StatusLayer/LobbyPanel/Margin/Layout/AddressInput
@onready var solo_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/SoloButton
@onready var host_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/HostButton
@onready var join_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/JoinButton
@onready var status_label: Label = $StatusLayer/StatusLabel
@onready var class_grid: GridContainer = $StatusLayer/LobbyPanel/Margin/Layout/ClassGrid
@onready var class_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/ClassLabel
@onready var class_description: Label = $StatusLayer/LobbyPanel/Margin/Layout/ClassDescription
@onready var classic_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/ModeRow/ClassicButton
@onready var pjotr_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/ModeRow/PjotrButton
@onready var steam_status_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/SteamStatusLabel
@onready var join_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/JoinLabel

var game_loaded := false
var class_buttons: Array[Button] = []
## Steam init is async (see SteamService.INIT_TIMEOUT_SECONDS); Host must not be clickable
## until we know either way, or a click during that window silently falls back to a
## LAN-only host with no lobby or invite at all.
var _steam_status_known := false
var _lobby_enabled := true


func _ready() -> void:
	classic_button.pressed.connect(_on_game_mode_pressed.bind(GameRuntime.GameMode.CLASSIC))
	pjotr_button.pressed.connect(_on_game_mode_pressed.bind(GameRuntime.GameMode.PJOTR))
	_build_class_selection()
	_refresh_game_mode()
	solo_button.pressed.connect(_on_solo_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	address_input.text_submitted.connect(_on_address_submitted)
	SteamService.steam_ready.connect(_on_steam_ready)
	SteamService.steam_unavailable.connect(_on_steam_unavailable)
	SteamService.join_requested.connect(_on_steam_join_requested)
	_refresh_steam_status()
	AudioService.play_music()
	call_deferred("_start_runtime")


func _start_runtime() -> void:
	match GameRuntime.mode:
		GameRuntime.RuntimeMode.OFFLINE:
			_show_lobby("Choose solo, host, or join")
			_check_pending_steam_invite()
		GameRuntime.RuntimeMode.HOST:
			_start_host()
		GameRuntime.RuntimeMode.CLIENT:
			_start_client(GameRuntime.server_address, GameRuntime.server_port)
		GameRuntime.RuntimeMode.DEDICATED_SERVER:
			_start_dedicated_server()


func _on_steam_ready() -> void:
	_steam_status_known = true
	_refresh_steam_status()
	_check_pending_steam_invite()


func _on_steam_unavailable(_reason: String) -> void:
	_steam_status_known = true
	_refresh_steam_status()


func _refresh_steam_status() -> void:
	if steam_status_label == null:
		return
	if not _steam_status_known:
		steam_status_label.text = "Checking Steam..."
		join_label.text = "Server address"
	elif SteamService.is_available():
		steam_status_label.text = "Steam: signed in as %s — Host opens an invite" % SteamService.local_persona_name()
		join_label.text = "LAN / direct IP (advanced)"
	else:
		steam_status_label.text = "Steam not detected — host/join by LAN address only"
		join_label.text = "Server address"
	host_button.disabled = not _lobby_enabled or not _steam_status_known


## A friend accepted a Steam invite or clicked "Join Game": connect straight away, from
## the lobby menu or (via +connect_lobby on the command line) from a cold launch.
func _check_pending_steam_invite() -> void:
	if not game_loaded and GameRuntime.pending_steam_lobby_id != 0 and SteamService.is_available():
		var lobby_id := GameRuntime.pending_steam_lobby_id
		GameRuntime.pending_steam_lobby_id = 0
		_join_via_steam(lobby_id)


func _on_steam_join_requested(lobby_id: int) -> void:
	if game_loaded:
		return
	_join_via_steam(lobby_id)


func _build_class_selection() -> void:
	for index in PlayerClass.CLASSES.size():
		var class_data := PlayerClass.CLASSES[index]
		var button := class_grid.get_child(index) as Button
		if button == null:
			continue
		button.text = "%s\n%s · %s" % [class_data.name, class_data.role, class_data.weapon_name]
		button.add_theme_color_override("font_color", Color(class_data.accent_color))
		button.pressed.connect(_on_class_pressed.bind(str(class_data.id)))
		class_buttons.append(button)
	_refresh_class_selection()


func _on_game_mode_pressed(next_game_mode: GameRuntime.GameMode) -> void:
	GameRuntime.set_game_mode(next_game_mode)
	_refresh_game_mode()


func _refresh_game_mode() -> void:
	var classic := GameRuntime.is_classic()
	classic_button.button_pressed = classic
	pjotr_button.button_pressed = not classic
	class_label.visible = not classic
	class_grid.visible = not classic
	if classic:
		var arclight := PlayerClass.by_id(PlayerClass.DEFAULT_CLASS_ID)
		class_description.text = "Classic run — %s only, endless grunts, no waves or bosses." % arclight.name
	else:
		_refresh_class_selection()


func _on_class_pressed(class_id: String) -> void:
	PlayerProfile.select_class(class_id)
	_refresh_class_selection()


func _refresh_class_selection() -> void:
	for index in class_buttons.size():
		var class_data := PlayerClass.CLASSES[index]
		class_buttons[index].button_pressed = class_data.id == PlayerProfile.selected_class_id
	var selected := PlayerClass.by_id(PlayerProfile.selected_class_id)
	class_description.text = "%s — %d HP · %d speed · %d damage\n%s" % [
		selected.name,
		int(selected.max_health),
		int(selected.movement_speed),
		int(selected.weapon_damage),
		selected.counters,
	]


func _on_solo_pressed() -> void:
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_open_game()


func _on_host_pressed() -> void:
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.HOST)
	if SteamService.is_available():
		_start_steam_host()
	else:
		_start_host()


func _on_join_pressed() -> void:
	var endpoint := _parse_endpoint(address_input.text)
	GameRuntime.set_runtime_mode(
		GameRuntime.RuntimeMode.CLIENT,
		endpoint.address,
		endpoint.port
	)
	_start_client(endpoint.address, endpoint.port)


func _on_address_submitted(_value: String) -> void:
	_on_join_pressed()


func _start_host() -> void:
	_set_lobby_enabled(false)
	status_label.text = "Starting host on UDP %d..." % GameRuntime.server_port
	if NetworkService.start_server(GameRuntime.server_port, GameRuntime.max_players) == OK:
		_open_game()
	else:
		_show_lobby("Could not start host on UDP %d" % GameRuntime.server_port)


func _start_steam_host() -> void:
	_set_lobby_enabled(false)
	_clear_host_callbacks()
	NetworkService.server_started.connect(_on_steam_host_started, CONNECT_ONE_SHOT)
	NetworkService.server_start_failed.connect(_on_steam_host_failed, CONNECT_ONE_SHOT)
	status_label.text = "Creating Steam lobby..."
	NetworkService.start_steam_host(GameRuntime.max_players)


func _on_steam_host_started(_port: int) -> void:
	_clear_host_callbacks()
	SteamService.invite_friends(NetworkService.current_steam_lobby_id)
	_open_game()


func _on_steam_host_failed(_error: Error) -> void:
	_clear_host_callbacks()
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby("Could not create Steam lobby. Try LAN / direct IP instead.")


func _clear_host_callbacks() -> void:
	if NetworkService.server_started.is_connected(_on_steam_host_started):
		NetworkService.server_started.disconnect(_on_steam_host_started)
	if NetworkService.server_start_failed.is_connected(_on_steam_host_failed):
		NetworkService.server_start_failed.disconnect(_on_steam_host_failed)


## Joins a Steam lobby, whether from an in-session invite (Steam overlay "Join Game") or a
## cold launch via +connect_lobby.
func _join_via_steam(lobby_id: int) -> void:
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.CLIENT)
	_set_lobby_enabled(false)
	_clear_connection_callbacks()
	NetworkService.connection_succeeded.connect(_on_connection_succeeded, CONNECT_ONE_SHOT)
	NetworkService.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	status_label.text = "Joining Steam lobby..."
	if NetworkService.start_steam_client(lobby_id) != OK:
		_show_lobby("Could not join Steam lobby")


func _start_client(address: String, port: int) -> void:
	_set_lobby_enabled(false)
	_clear_connection_callbacks()
	NetworkService.connection_succeeded.connect(_on_connection_succeeded, CONNECT_ONE_SHOT)
	NetworkService.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	status_label.text = "Connecting to %s:%d..." % [address, port]
	if NetworkService.start_client(address, port) != OK:
		_show_lobby("Could not create network client")


func _start_dedicated_server() -> void:
	lobby_panel.visible = false
	backdrop.visible = false
	status_label.visible = false
	if NetworkService.start_server(GameRuntime.server_port, GameRuntime.max_players) != OK:
		push_error("Dedicated server failed to start")
		get_tree().quit(1)
		return
	print("Dedicated server listening on UDP %d" % GameRuntime.server_port)
	_open_game()


func _open_game() -> void:
	if game_loaded:
		return
	game_loaded = true
	var game := GAME_SCENE.instantiate()
	add_child(game)
	lobby_panel.visible = false
	backdrop.visible = false
	status_label.visible = false


func restart_game() -> void:
	var game := get_node_or_null("Main")
	if game != null:
		game.free()
	game_loaded = false
	_open_game()


## Escape-menu "leave to lobby": drops the connection (if any) and returns to the lobby screen
## without restarting into a fresh solo run.
func leave_game() -> void:
	var game := get_node_or_null("Main")
	if game != null:
		game.free()
	NetworkService.stop()
	game_loaded = false
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby("Choose solo, host, or join")


func _on_connection_failed() -> void:
	_clear_connection_callbacks()
	NetworkService.stop()
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby("Connection failed. Check the address and host.")


func _on_connection_succeeded() -> void:
	_clear_connection_callbacks()
	if not NetworkService.connection_failed.is_connected(_on_connection_lost):
		NetworkService.connection_failed.connect(_on_connection_lost)
	_open_game()


func _clear_connection_callbacks() -> void:
	if NetworkService.connection_succeeded.is_connected(_on_connection_succeeded):
		NetworkService.connection_succeeded.disconnect(_on_connection_succeeded)
	if NetworkService.connection_failed.is_connected(_on_connection_failed):
		NetworkService.connection_failed.disconnect(_on_connection_failed)


func _on_connection_lost() -> void:
	if NetworkService.connection_failed.is_connected(_on_connection_lost):
		NetworkService.connection_failed.disconnect(_on_connection_lost)
	var game := get_node_or_null("Main")
	if game != null:
		game.queue_free()
	game_loaded = false
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby("Disconnected from server")


func _show_lobby(message: String) -> void:
	backdrop.visible = true
	lobby_panel.visible = true
	status_label.visible = true
	status_label.text = message
	_set_lobby_enabled(true)


func _set_lobby_enabled(enabled: bool) -> void:
	_lobby_enabled = enabled
	solo_button.disabled = not enabled
	host_button.disabled = not enabled or not _steam_status_known
	join_button.disabled = not enabled
	address_input.editable = enabled
	classic_button.disabled = not enabled
	pjotr_button.disabled = not enabled
	for button in class_buttons:
		button.disabled = not enabled


func _parse_endpoint(value: String) -> Dictionary:
	var address := value.strip_edges()
	var port := GameRuntime.DEFAULT_PORT
	if address.count(":") == 1:
		var parts := address.split(":", false, 1)
		address = parts[0]
		var requested_port := parts[1].to_int()
		if requested_port > 0 and requested_port <= 65535:
			port = requested_port
	if address.is_empty():
		address = "127.0.0.1"
	return {"address": address, "port": port}

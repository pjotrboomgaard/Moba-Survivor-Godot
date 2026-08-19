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
@onready var mode_row: HBoxContainer = $StatusLayer/LobbyPanel/Margin/Layout/ModeRow
@onready var roster_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/RosterLabel
@onready var start_game_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/StartGameButton
@onready var waiting_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/WaitingLabel

var game_loaded := false
var class_buttons: Array[Button] = []
## Steam init is async (see SteamService.INIT_TIMEOUT_SECONDS); Host must not be clickable
## until we know either way, or a click during that window silently falls back to a
## LAN-only host with no lobby or invite at all.
var _steam_status_known := false
var _lobby_enabled := true

## True once the multiplayer peer is connected (host or client) but the match hasn't been
## started yet — everyone sits here seeing who's connected until the host presses Start.
var _in_network_lobby := false
var _is_lobby_host := false
## peer_id -> {"name": String, "class_id": String}
var lobby_roster: Dictionary = {}


func _ready() -> void:
	classic_button.pressed.connect(_on_game_mode_pressed.bind(GameRuntime.GameMode.CLASSIC))
	pjotr_button.pressed.connect(_on_game_mode_pressed.bind(GameRuntime.GameMode.PJOTR))
	_build_class_selection()
	_refresh_game_mode()
	solo_button.pressed.connect(_on_solo_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	address_input.text_submitted.connect(_on_address_submitted)
	start_game_button.pressed.connect(_on_start_game_pressed)
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
		_enter_network_lobby(true)
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
	_enter_network_lobby(true)


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


## Waiting room between "connected" and "playing": everyone sees who's here, only the host
## can press Start, and the match opens for every peer at the same moment (see
## client_start_game below) instead of each peer falling straight into a game in progress.
func _enter_network_lobby(is_host: bool) -> void:
	_in_network_lobby = true
	_is_lobby_host = is_host
	if is_host:
		lobby_roster = {1: {"name": PlayerProfile.display_name, "class_id": GameRuntime.active_class_id()}}
		if not NetworkService.peer_left.is_connected(_on_lobby_peer_left):
			NetworkService.peer_left.connect(_on_lobby_peer_left)
	else:
		lobby_roster = {}
		server_submit_lobby_profile.rpc_id(1, {
			"display_name": PlayerProfile.display_name,
			"class_id": GameRuntime.active_class_id(),
		})
	_show_network_lobby()


func _show_network_lobby() -> void:
	backdrop.visible = true
	lobby_panel.visible = true
	status_label.visible = true
	status_label.text = "Connected" if _is_lobby_host else "Connected to host"
	_set_lobby_enabled(false)
	mode_row.visible = false
	class_label.visible = false
	class_grid.visible = false
	class_description.visible = false
	solo_button.visible = false
	host_button.visible = false
	join_label.visible = false
	address_input.visible = false
	join_button.visible = false
	steam_status_label.visible = false
	roster_label.visible = true
	start_game_button.visible = _is_lobby_host
	waiting_label.visible = not _is_lobby_host
	_refresh_roster_label()


func _on_lobby_peer_left(peer_id: int) -> void:
	lobby_roster.erase(peer_id)
	_broadcast_roster()


func _refresh_roster_label() -> void:
	var lines: Array[String] = ["Players in lobby (%d/%d):" % [lobby_roster.size(), GameRuntime.max_players]]
	for peer_id in lobby_roster.keys():
		var entry: Dictionary = lobby_roster[peer_id]
		var class_data := PlayerClass.by_id(str(entry.get("class_id", PlayerClass.DEFAULT_CLASS_ID)))
		var host_tag := "  (host)" if peer_id == 1 else ""
		lines.append("• %s — %s%s" % [str(entry.get("name", "Player")), class_data.name, host_tag])
	roster_label.text = "\n".join(lines)


@rpc("any_peer", "call_remote", "reliable")
func server_submit_lobby_profile(profile: Dictionary) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	lobby_roster[peer_id] = {
		"name": str(profile.get("display_name", "Player")),
		"class_id": str(profile.get("class_id", PlayerClass.DEFAULT_CLASS_ID)),
	}
	_broadcast_roster()


func _broadcast_roster() -> void:
	_refresh_roster_label()
	for peer_id in multiplayer.get_peers():
		client_receive_roster.rpc_id(peer_id, lobby_roster)


@rpc("authority", "call_remote", "reliable")
func client_receive_roster(roster: Dictionary) -> void:
	lobby_roster = roster
	_refresh_roster_label()


func _on_start_game_pressed() -> void:
	if not _is_lobby_host:
		return
	for peer_id in multiplayer.get_peers():
		client_start_game.rpc_id(peer_id)
	_open_game()


@rpc("authority", "call_remote", "reliable")
func client_start_game() -> void:
	_open_game()


func _leave_network_lobby() -> void:
	if NetworkService.peer_left.is_connected(_on_lobby_peer_left):
		NetworkService.peer_left.disconnect(_on_lobby_peer_left)
	_in_network_lobby = false
	lobby_roster.clear()


func _open_game() -> void:
	if game_loaded:
		return
	_leave_network_lobby()
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
	_enter_network_lobby(false)


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
	_leave_network_lobby()
	backdrop.visible = true
	lobby_panel.visible = true
	status_label.visible = true
	status_label.text = message
	_set_lobby_enabled(true)
	mode_row.visible = true
	class_label.visible = not GameRuntime.is_classic()
	class_grid.visible = not GameRuntime.is_classic()
	class_description.visible = true
	solo_button.visible = true
	host_button.visible = true
	join_label.visible = true
	address_input.visible = true
	join_button.visible = true
	steam_status_label.visible = true
	roster_label.visible = false
	start_game_button.visible = false
	waiting_label.visible = false


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

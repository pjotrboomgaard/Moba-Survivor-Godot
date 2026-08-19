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
@onready var lobby_title_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/LobbyTitleLabel
@onready var player_slots: VBoxContainer = $StatusLayer/LobbyPanel/Margin/Layout/PlayerSlots
@onready var lobby_action_row: HBoxContainer = $StatusLayer/LobbyPanel/Margin/Layout/LobbyActionRow
@onready var invite_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/LobbyActionRow/InviteButton
@onready var leave_lobby_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/LobbyActionRow/LeaveLobbyButton
@onready var cancel_create_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/LobbyActionRow/CancelCreateButton
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
var _waiting_steam_operation := false
var _steam_operation_elapsed := 0.0
var _steam_lobby_members: Array[String] = []
var _lobby_refresh_timer := 0.0

const STEAM_OPERATION_TIMEOUT := 22.0


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
	invite_button.pressed.connect(_on_invite_pressed)
	leave_lobby_button.pressed.connect(_on_leave_lobby_pressed)
	cancel_create_button.pressed.connect(_on_cancel_create_pressed)
	SteamService.steam_ready.connect(_on_steam_ready)
	SteamService.steam_unavailable.connect(_on_steam_unavailable)
	SteamService.join_requested.connect(_on_steam_join_requested)
	SteamService.lobby_members_changed.connect(_on_steam_lobby_members_changed)
	NetworkService.peer_joined.connect(_on_lobby_peer_joined)
	_refresh_steam_status()
	AudioService.play_music()
	call_deferred("_start_runtime")
	set_process(true)


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
	_sync_steam_display_name()
	_refresh_steam_status()
	_check_pending_steam_invite()


func _on_steam_unavailable(_reason: String) -> void:
	_steam_status_known = true
	_refresh_steam_status()


func _sync_steam_display_name() -> void:
	if not SteamService.is_available():
		return
	var steam_name := SteamService.local_persona_name().strip_edges()
	if steam_name.is_empty():
		return
	if PlayerProfile.display_name == "Player" or PlayerProfile.display_name.is_empty():
		PlayerProfile.display_name = steam_name
		PlayerProfile.save_display_name()


func _process(delta: float) -> void:
	if _waiting_steam_operation:
		_steam_operation_elapsed += delta
		if _steam_operation_elapsed >= STEAM_OPERATION_TIMEOUT:
			_cancel_steam_operation("Steam lobby timed out. Check Steam is online, then try again.")
		return
	if _in_network_lobby and NetworkService.current_steam_lobby_id != 0:
		_lobby_refresh_timer += delta
		if _lobby_refresh_timer >= 1.0:
			_lobby_refresh_timer = 0.0
			_refresh_steam_lobby_members()
			_refresh_player_slots()


func _begin_steam_operation(message: String) -> void:
	_waiting_steam_operation = true
	_steam_operation_elapsed = 0.0
	_set_lobby_enabled(false)
	cancel_create_button.visible = true
	lobby_title_label.visible = true
	lobby_title_label.text = message
	player_slots.visible = true
	_refresh_player_slots()
	status_label.text = message


func _end_steam_operation() -> void:
	_waiting_steam_operation = false
	_steam_operation_elapsed = 0.0
	cancel_create_button.visible = false


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
	_sync_steam_display_name()
	_begin_steam_operation("Creating Steam lobby...")
	_clear_host_callbacks()
	NetworkService.server_started.connect(_on_steam_host_started, CONNECT_ONE_SHOT)
	NetworkService.server_start_failed.connect(_on_steam_host_failed, CONNECT_ONE_SHOT)
	NetworkService.start_steam_host(GameRuntime.max_players)


func _on_steam_host_started(_port: int) -> void:
	_clear_host_callbacks()
	_end_steam_operation()
	_refresh_steam_lobby_members()
	_enter_network_lobby(true)
	SteamService.invite_friends(NetworkService.current_steam_lobby_id)


func _on_steam_host_failed(_error: Error) -> void:
	_clear_host_callbacks()
	_end_steam_operation()
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
	_sync_steam_display_name()
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.CLIENT)
	_begin_steam_operation("Joining Steam lobby...")
	_clear_connection_callbacks()
	NetworkService.connection_succeeded.connect(_on_connection_succeeded, CONNECT_ONE_SHOT)
	NetworkService.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	if NetworkService.start_steam_client(lobby_id) != OK:
		_cancel_steam_operation("Could not join Steam lobby")


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
	_end_steam_operation()
	backdrop.visible = true
	lobby_panel.visible = true
	status_label.visible = true
	status_label.text = "Invite friends, then start when everyone is ready." if _is_lobby_host else "Waiting for the host to start the game..."
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
	lobby_title_label.visible = true
	lobby_title_label.text = "Rift Survivors Lobby"
	player_slots.visible = true
	lobby_action_row.visible = true
	invite_button.visible = _is_lobby_host and NetworkService.current_steam_lobby_id != 0
	leave_lobby_button.visible = true
	roster_label.visible = false
	start_game_button.visible = _is_lobby_host
	waiting_label.visible = not _is_lobby_host
	_refresh_steam_lobby_members()
	_refresh_player_slots()


func _on_lobby_peer_joined(peer_id: int) -> void:
	if not _in_network_lobby or not _is_lobby_host or peer_id == 1:
		return
	if lobby_roster.has(peer_id):
		return
	lobby_roster[peer_id] = {
		"name": "Connecting...",
		"class_id": PlayerClass.DEFAULT_CLASS_ID,
	}
	_broadcast_roster()


func _on_steam_lobby_members_changed(lobby_id: int) -> void:
	if lobby_id != NetworkService.current_steam_lobby_id:
		return
	_refresh_steam_lobby_members()


func _refresh_steam_lobby_members() -> void:
	var lobby_id := NetworkService.current_steam_lobby_id
	if lobby_id == 0 or not SteamService.is_available():
		_steam_lobby_members = []
		return
	_steam_lobby_members = SteamService.lobby_member_names(lobby_id)


func _refresh_player_slots() -> void:
	for child in player_slots.get_children():
		child.queue_free()
	var slot_entries: Array[Dictionary] = []
	if _in_network_lobby:
		var peer_ids: Array = lobby_roster.keys()
		peer_ids.sort()
		for peer_id in peer_ids:
			var entry: Dictionary = lobby_roster[peer_id]
			slot_entries.append({
				"name": str(entry.get("name", "Player")),
				"class_id": str(entry.get("class_id", PlayerClass.DEFAULT_CLASS_ID)),
				"status": "Connected",
				"host": int(peer_id) == 1,
			})
		for member_name in _steam_lobby_members:
			var already_listed := false
			for slot_data in slot_entries:
				if str(slot_data.name) == member_name:
					already_listed = true
					break
			if already_listed:
				continue
			slot_entries.append({
				"name": member_name,
				"class_id": "",
				"status": "In Steam lobby",
				"host": false,
			})
	else:
		slot_entries.append({
			"name": PlayerProfile.display_name,
			"class_id": GameRuntime.active_class_id(),
			"status": "Setting up...",
			"host": true,
		})
	while slot_entries.size() < GameRuntime.max_players:
		slot_entries.append({"name": "Empty slot", "class_id": "", "status": "", "host": false})
	for index in GameRuntime.max_players:
		var slot_data: Dictionary = slot_entries[index]
		var label := Label.new()
		var class_text := ""
		if not str(slot_data.class_id).is_empty():
			class_text = " — %s" % PlayerClass.by_id(str(slot_data.class_id)).name
		var host_text := " [HOST]" if bool(slot_data.host) else ""
		var status_text := ""
		if not str(slot_data.status).is_empty():
			status_text = " (%s)" % slot_data.status
		label.text = "%d. %s%s%s%s" % [index + 1, slot_data.name, class_text, host_text, status_text]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		player_slots.add_child(label)


func _on_invite_pressed() -> void:
	if NetworkService.current_steam_lobby_id != 0:
		SteamService.invite_friends(NetworkService.current_steam_lobby_id)


func _on_leave_lobby_pressed() -> void:
	_cancel_steam_operation("Left the lobby.")


func _on_cancel_create_pressed() -> void:
	_cancel_steam_operation("Lobby creation cancelled.")


func _cancel_steam_operation(message: String) -> void:
	_end_steam_operation()
	_clear_host_callbacks()
	_clear_connection_callbacks()
	NetworkService.stop()
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby(message)


func _on_lobby_peer_left(peer_id: int) -> void:
	lobby_roster.erase(peer_id)
	_broadcast_roster()


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
	_refresh_player_slots()
	for peer_id in multiplayer.get_peers():
		client_receive_roster.rpc_id(peer_id, lobby_roster)


@rpc("authority", "call_remote", "reliable")
func client_receive_roster(roster: Dictionary) -> void:
	lobby_roster = roster
	_refresh_player_slots()


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
	_steam_lobby_members.clear()


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
	_end_steam_operation()
	NetworkService.stop()
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby("Connection failed. Check the address and host.")


func _on_connection_succeeded() -> void:
	_clear_connection_callbacks()
	_end_steam_operation()
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
	lobby_title_label.visible = false
	player_slots.visible = false
	lobby_action_row.visible = false
	invite_button.visible = false
	leave_lobby_button.visible = false
	cancel_create_button.visible = false
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

extends Node

signal server_started(port: int)
## `reason` is empty for a plain ENet failure (nothing more specific to say); a Steam failure
## carries the real reason string from SteamService instead of a generic message.
signal server_start_failed(error: Error, reason: String)
signal connection_succeeded
signal connection_failed(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

var enet_peer: ENetMultiplayerPeer
var steam_peer: MultiplayerPeer
var current_steam_lobby_id := 0

## "host" or "client" while a Steam lobby create/join is in flight; empty once resolved.
var _pending_steam_role := ""


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	SteamService.lobby_created.connect(_on_steam_lobby_created)
	SteamService.lobby_create_failed.connect(_on_steam_lobby_create_failed)
	SteamService.lobby_joined.connect(_on_steam_lobby_joined)
	SteamService.lobby_join_failed.connect(_on_steam_lobby_join_failed)


func start_server(port: int = GameRuntime.DEFAULT_PORT, max_players: int = GameRuntime.DEFAULT_MAX_PLAYERS) -> Error:
	stop()
	enet_peer = ENetMultiplayerPeer.new()
	var error := enet_peer.create_server(port, max_players)
	if error != OK:
		enet_peer = null
		server_start_failed.emit(error, "")
		return error
	multiplayer.multiplayer_peer = enet_peer
	server_started.emit(port)
	return OK


func start_client(address: String, port: int = GameRuntime.DEFAULT_PORT) -> Error:
	stop()
	enet_peer = ENetMultiplayerPeer.new()
	var error := enet_peer.create_client(address, port)
	if error != OK:
		enet_peer = null
		connection_failed.emit("")
		return error
	multiplayer.multiplayer_peer = enet_peer
	return OK


## Creates a Steam P2P host and a matching friends-only Steam lobby so friends can join via
## the Steam overlay without any port forwarding. Result arrives on server_started/
## server_start_failed (asynchronous: lobby creation is a round trip to Steam).
func start_steam_host(max_players: int = GameRuntime.DEFAULT_MAX_PLAYERS) -> Error:
	stop()
	if not SteamService.is_available():
		server_start_failed.emit(ERR_UNAVAILABLE, "Steam is not available")
		return ERR_UNAVAILABLE
	_pending_steam_role = "host"
	SteamService.create_lobby(max_players)
	return OK


## Joins a Steam lobby by id and connects to its owner as a Steam P2P client. Result arrives
## on connection_succeeded/connection_failed.
func start_steam_client(lobby_id: int) -> Error:
	stop()
	if not SteamService.is_available():
		connection_failed.emit("Steam is not available")
		return ERR_UNAVAILABLE
	_pending_steam_role = "client"
	SteamService.join_lobby(lobby_id)
	return OK


func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	enet_peer = null
	steam_peer = null
	## Every teardown path — cancel, leave, disconnect, error — routes through here, so this is
	## the one place that needs to tell Steam we're done with the lobby instead of leaving
	## membership dangling until Steam notices the connection dropped on its own.
	if current_steam_lobby_id != 0:
		SteamService.leave_lobby(current_steam_lobby_id)
	current_steam_lobby_id = 0
	_pending_steam_role = ""


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _on_steam_lobby_created(lobby_id: int) -> void:
	print("[NetworkService] Steam lobby created: ", lobby_id, " (pending role: ", _pending_steam_role, ")")
	if _pending_steam_role != "host":
		return
	_pending_steam_role = ""
	var peer := SteamMultiplayerPeer.new()
	var error := peer.host_with_lobby(lobby_id)
	if error != OK:
		print("[NetworkService] host_with_lobby failed: ", error)
		## Steam itself already considers us a member of this lobby at this point, even though
		## the P2P layer on top of it failed — leave it rather than lingering in a lobby with
		## no working game connection behind it.
		SteamService.leave_lobby(lobby_id)
		server_start_failed.emit(error, "Could not host the Steam lobby's network connection")
		return
	steam_peer = peer
	current_steam_lobby_id = lobby_id
	multiplayer.multiplayer_peer = peer
	print("[NetworkService] Steam host ready, lobby_id=", lobby_id)
	server_started.emit(0)


func _on_steam_lobby_create_failed(reason: String) -> void:
	print("[NetworkService] Steam lobby create failed: ", reason)
	if _pending_steam_role != "host":
		return
	_pending_steam_role = ""
	server_start_failed.emit(ERR_CANT_CREATE, reason)


func _on_steam_lobby_joined(lobby_id: int) -> void:
	if _pending_steam_role != "client":
		return
	_pending_steam_role = ""
	var peer := SteamMultiplayerPeer.new()
	var error := peer.connect_to_lobby(lobby_id)
	if error != OK:
		SteamService.leave_lobby(lobby_id)
		connection_failed.emit("Could not join the Steam lobby's network connection")
		return
	steam_peer = peer
	current_steam_lobby_id = lobby_id
	multiplayer.multiplayer_peer = peer


func _on_steam_lobby_join_failed(reason: String) -> void:
	if _pending_steam_role != "client":
		return
	_pending_steam_role = ""
	connection_failed.emit(reason)


func _on_connected_to_server() -> void:
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	connection_failed.emit("")


func _on_server_disconnected() -> void:
	stop()
	connection_failed.emit("Disconnected from host")


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)

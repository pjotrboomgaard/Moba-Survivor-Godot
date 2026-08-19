extends Node

signal server_started(port: int)
signal server_start_failed(error: Error)
signal connection_succeeded
signal connection_failed
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
		server_start_failed.emit(error)
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
		connection_failed.emit()
		return error
	multiplayer.multiplayer_peer = enet_peer
	return OK


## Creates a Steam P2P host and a matching friends-only Steam lobby so friends can join via
## the Steam overlay without any port forwarding. Result arrives on server_started/
## server_start_failed (asynchronous: lobby creation is a round trip to Steam).
func start_steam_host(max_players: int = GameRuntime.DEFAULT_MAX_PLAYERS) -> Error:
	stop()
	if not SteamService.is_available():
		server_start_failed.emit(ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE
	_pending_steam_role = "host"
	SteamService.create_lobby(max_players)
	return OK


## Joins a Steam lobby by id and connects to its owner as a Steam P2P client. Result arrives
## on connection_succeeded/connection_failed.
func start_steam_client(lobby_id: int) -> Error:
	stop()
	if not SteamService.is_available():
		connection_failed.emit()
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
	current_steam_lobby_id = 0
	_pending_steam_role = ""


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _on_steam_lobby_created(lobby_id: int) -> void:
	if _pending_steam_role != "host":
		return
	_pending_steam_role = ""
	var peer := SteamMultiplayerPeer.new()
	var error := peer.host_with_lobby(lobby_id)
	if error != OK:
		server_start_failed.emit(error)
		return
	steam_peer = peer
	current_steam_lobby_id = lobby_id
	multiplayer.multiplayer_peer = peer
	server_started.emit(0)


func _on_steam_lobby_create_failed(_reason: String) -> void:
	if _pending_steam_role != "host":
		return
	_pending_steam_role = ""
	server_start_failed.emit(ERR_CANT_CREATE)


func _on_steam_lobby_joined(lobby_id: int) -> void:
	if _pending_steam_role != "client":
		return
	_pending_steam_role = ""
	var peer := SteamMultiplayerPeer.new()
	var error := peer.connect_to_lobby(lobby_id)
	if error != OK:
		connection_failed.emit()
		return
	steam_peer = peer
	current_steam_lobby_id = lobby_id
	multiplayer.multiplayer_peer = peer


func _on_steam_lobby_join_failed(_reason: String) -> void:
	if _pending_steam_role != "client":
		return
	_pending_steam_role = ""
	connection_failed.emit()


func _on_connected_to_server() -> void:
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	stop()
	connection_failed.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)

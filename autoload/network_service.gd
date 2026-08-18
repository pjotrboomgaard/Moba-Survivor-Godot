extends Node

signal server_started(port: int)
signal server_start_failed(error: Error)
signal connection_succeeded
signal connection_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

var enet_peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


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


func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	enet_peer = null


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


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

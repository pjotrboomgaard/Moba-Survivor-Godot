extends Node

## Thin wrapper around the GodotSteam GDExtension (addons/godotsteam). Fails soft: on any
## machine without Steam running (CI, the headless dedicated server, a bare `godot` binary
## without the extension) `is_available()` stays false and every other autoload keeps working
## through the existing ENet path instead.
##
## steam_appid.txt at the project root currently holds 480, Valve's public "Spacewar" test
## App ID. A real release needs the studio's own Steamworks App ID there instead.

signal steam_ready
signal steam_unavailable(reason: String)
signal lobby_created(lobby_id: int)
signal lobby_create_failed(reason: String)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal join_requested(lobby_id: int)
signal lobby_members_changed(lobby_id: int)

const INIT_TIMEOUT_SECONDS := 8.0
const LOBBY_CREATE_TIMEOUT_SECONDS := 20.0
const LOBBY_JOIN_TIMEOUT_SECONDS := 20.0
## bootstrap.gd's own Steam-operation timeout should stay a little longer than either of the
## two above, so this module's timeout always fires first with a specific reason instead of
## bootstrap's generic one firing while a real Steam callback is still in flight.
const BOOTSTRAP_TIMEOUT_MARGIN_SECONDS := 2.0

var initialized := false
var init_error := ""

var _init_thread: Thread
var _init_mutex: Mutex
var _init_done := false
var _init_result: Dictionary
var _init_elapsed := 0.0
var _waiting_for_init := false

var _creating_lobby := false
var _lobby_create_elapsed := 0.0
var _joining_lobby := false
var _lobby_join_elapsed := 0.0


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		init_error = "GodotSteam extension not loaded"
		print("[SteamService] ", init_error)
		steam_unavailable.emit(init_error)
		return
	if not Steam.isSteamRunning():
		init_error = "Steam client is not running"
		print("[SteamService] ", init_error)
		steam_unavailable.emit(init_error)
		return
	print("[SteamService] Steam extension loaded and client detected, starting init thread...")
	_init_mutex = Mutex.new()
	_init_thread = Thread.new()
	_waiting_for_init = true
	set_process(true)
	_init_thread.start(_run_steam_init)


func _run_steam_init() -> void:
	var result: Dictionary = Steam.steamInitEx()
	_init_mutex.lock()
	_init_result = result
	_init_done = true
	_init_mutex.unlock()


## Quitting while Steam's init thread is still running used to hard-crash the game (SIGSEGV):
## Thread's destructor runs while the thread is unjoined. Steam init can take seconds, so this
## was reachable just by launching and immediately quitting. Joining here blocks until
## steamInitEx() returns, which is exactly what makes the teardown safe.
func _exit_tree() -> void:
	_join_init_thread()


func _join_init_thread() -> void:
	if _init_thread != null and _init_thread.is_started():
		_init_thread.wait_to_finish()
	_init_thread = null


func _process(delta: float) -> void:
	if _waiting_for_init:
		_init_elapsed += delta
		_init_mutex.lock()
		var done := _init_done
		_init_mutex.unlock()
		if done:
			_waiting_for_init = false
			_join_init_thread()
			_finish_init(_init_result)
		elif _init_elapsed >= INIT_TIMEOUT_SECONDS:
			_waiting_for_init = false
			set_process(false)
			init_error = "Steam did not respond in time"
			## Deliberately NOT joined here — the whole point of the timeout is that the call
			## is wedged, so joining would block the main thread for exactly as long as we just
			## refused to wait. _exit_tree joins it at shutdown instead.
			steam_unavailable.emit(init_error)
		return

	if _creating_lobby:
		_lobby_create_elapsed += delta
		if _lobby_create_elapsed >= LOBBY_CREATE_TIMEOUT_SECONDS:
			_creating_lobby = false
			lobby_create_failed.emit("Steam lobby creation timed out")

	if _joining_lobby:
		_lobby_join_elapsed += delta
		if _lobby_join_elapsed >= LOBBY_JOIN_TIMEOUT_SECONDS:
			_joining_lobby = false
			lobby_join_failed.emit("Steam lobby join timed out")

	Steam.run_callbacks()


func _finish_init(result: Dictionary) -> void:
	initialized = int(result.get("status", -1)) == Steam.STEAM_API_INIT_RESULT_OK
	if not initialized:
		set_process(false)
		init_error = str(result.get("verbal", "Steam is not running"))
		print("[SteamService] init failed: ", init_error, " raw=", result)
		steam_unavailable.emit(init_error)
		return
	if Steam.has_method("initRelayNetworkAccess"):
		Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)
	if Steam.has_signal("lobby_chat_update"):
		Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	print("[SteamService] ready as ", Steam.getPersonaName())
	steam_ready.emit()


func is_available() -> bool:
	return initialized


func local_persona_name() -> String:
	return Steam.getPersonaName() if initialized else ""


func local_steam_id() -> int:
	return int(Steam.getSteamID()) if initialized else 0


func create_lobby(max_players: int) -> void:
	_creating_lobby = true
	_lobby_create_elapsed = 0.0
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)


func join_lobby(lobby_id: int) -> void:
	_joining_lobby = true
	_lobby_join_elapsed = 0.0
	Steam.joinLobby(lobby_id)


## Tells Steam we're no longer part of this lobby — cancelling a create/join, leaving the
## waiting room, or ending a run all count. Without this, Steam-side membership lingers until
## Steam itself notices the network drop, which can leave friends' clients showing us as still
## in a lobby that's actually gone.
func leave_lobby(lobby_id: int) -> void:
	if initialized and lobby_id != 0:
		Steam.leaveLobby(lobby_id)


## False whenever the Steam overlay can't actually open — it only injects into processes Steam
## itself launched (so never during development, where the binary is run directly), and players
## can disable it outright in Steam's settings. invite_friends() below is a silent no-op in
## that state, so callers should check this first and offer the lobby code instead.
func overlay_available() -> bool:
	if not initialized or not Steam.has_method("isOverlayEnabled"):
		return false
	return bool(Steam.isOverlayEnabled())


func invite_friends(lobby_id: int) -> void:
	if initialized and lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)


func lobby_member_count(lobby_id: int) -> int:
	if not initialized or lobby_id == 0:
		return 0
	return int(Steam.getNumLobbyMembers(lobby_id))


func lobby_member_names(lobby_id: int) -> Array[String]:
	var names: Array[String] = []
	if not initialized or lobby_id == 0:
		return names
	var count := lobby_member_count(lobby_id)
	for member_index in count:
		var member_id := int(Steam.getLobbyMemberByIndex(lobby_id, member_index))
		var persona := str(Steam.getFriendPersonaName(member_id))
		if persona.is_empty():
			persona = "Steam player"
		names.append(persona)
	return names


func lobby_owner_name(lobby_id: int) -> String:
	if not initialized or lobby_id == 0:
		return ""
	var owner_id := int(Steam.getLobbyOwner(lobby_id))
	var persona := str(Steam.getFriendPersonaName(owner_id))
	return persona if not persona.is_empty() else "Host"


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	_creating_lobby = false
	if connect_result == Steam.RESULT_OK:
		print("[SteamService] lobby created: ", lobby_id)
		if Steam.has_method("setLobbyData"):
			Steam.setLobbyData(lobby_id, "name", "Rift Survivors")
		lobby_created.emit(lobby_id)
	else:
		lobby_create_failed.emit("Steam lobby creation failed (result %d)" % connect_result)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	_joining_lobby = false
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_joined.emit(lobby_id)
	else:
		lobby_join_failed.emit("Could not join Steam lobby (response %d)" % response)


func _on_join_requested(lobby_id: int, _friend_steam_id: int) -> void:
	join_requested.emit(lobby_id)


func _on_lobby_chat_update(lobby_id: int, _changed_id: int, _making_change: int, _chat_state: int) -> void:
	lobby_members_changed.emit(lobby_id)

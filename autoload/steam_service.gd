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

## steamInitEx() is a blocking SDK call. isSteamRunning() alone isn't a reliable guard against
## it hanging: it can report true from a stale local Steam registration even when there's no
## live client to actually answer the handshake. Running the call on a worker thread with a
## timeout means a dead/absent Steam install can never freeze the game's own startup.
const INIT_TIMEOUT_SECONDS := 8.0

var initialized := false
var init_error := ""

var _init_thread: Thread
var _init_mutex: Mutex
var _init_done := false
var _init_result: Dictionary
var _init_elapsed := 0.0
var _waiting_for_init := false


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		init_error = "GodotSteam extension not loaded"
		steam_unavailable.emit(init_error)
		return
	if not Steam.isSteamRunning():
		init_error = "Steam client is not running"
		steam_unavailable.emit(init_error)
		return
	_init_mutex = Mutex.new()
	_init_thread = Thread.new()
	_waiting_for_init = true
	set_process(true)
	_init_thread.start(_run_steam_init)


## Runs on the worker thread. Only touches Steam before any other code calls into it, so
## there's no concurrent access to guard against.
func _run_steam_init() -> void:
	var result: Dictionary = Steam.steamInitEx()
	_init_mutex.lock()
	_init_result = result
	_init_done = true
	_init_mutex.unlock()


func _process(delta: float) -> void:
	if _waiting_for_init:
		_init_elapsed += delta
		_init_mutex.lock()
		var done := _init_done
		_init_mutex.unlock()
		if done:
			_waiting_for_init = false
			_init_thread.wait_to_finish()
			_finish_init(_init_result)
		elif _init_elapsed >= INIT_TIMEOUT_SECONDS:
			_waiting_for_init = false
			set_process(false)
			# The thread is abandoned, not killed: if steamInitEx() does eventually return,
			# its result is simply never read.
			init_error = "Steam did not respond in time"
			steam_unavailable.emit(init_error)
		return
	Steam.run_callbacks()


func _finish_init(result: Dictionary) -> void:
	initialized = int(result.get("status", -1)) == Steam.STEAM_API_INIT_RESULT_OK
	if not initialized:
		set_process(false)
		init_error = str(result.get("verbal", "Steam is not running"))
		steam_unavailable.emit(init_error)
		return
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)
	steam_ready.emit()


func is_available() -> bool:
	return initialized


func local_persona_name() -> String:
	return Steam.getPersonaName() if initialized else ""


## Creates a friends-only Steam lobby. Result arrives on lobby_created/lobby_create_failed.
func create_lobby(max_players: int) -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)


## Joins an existing lobby by id. Result arrives on lobby_joined/lobby_join_failed.
func join_lobby(lobby_id: int) -> void:
	Steam.joinLobby(lobby_id)


## Opens the Steam overlay's "invite friends" dialog for a lobby the local user owns/is in.
func invite_friends(lobby_id: int) -> void:
	if initialized and lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result == Steam.RESULT_OK:
		lobby_created.emit(lobby_id)
	else:
		lobby_create_failed.emit("Steam lobby creation failed (result %d)" % connect_result)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_joined.emit(lobby_id)
	else:
		lobby_join_failed.emit("Could not join Steam lobby (response %d)" % response)


func _on_join_requested(lobby_id: int, _friend_steam_id: int) -> void:
	join_requested.emit(lobby_id)

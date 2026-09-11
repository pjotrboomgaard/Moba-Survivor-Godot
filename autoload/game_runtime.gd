extends Node

signal mode_changed(mode: RuntimeMode)

enum RuntimeMode {
	OFFLINE,
	HOST,
	CLIENT,
	DEDICATED_SERVER,
}

## Classic preserves the original single-hero Arc Staff run.
## Pjotr mode unlocks the four heroes, the full enemy roster, waves, bosses and biomes.
enum GameMode {
	CLASSIC,
	PJOTR,
	TOBORWORLD,
}

## How hard enemy waves hit in Pjotr mode — see WaveDirector.DIFFICULTY_HEALTH_MULTIPLIERS
## for the actual enemy-health multipliers each of these maps to.
enum Difficulty {
	EASY,
	NORMAL,
	HARD,
	BRUTAL,
}

## NONE is co-op / solo PvE. FFA is four rival teams, first to FFA_KILLS_TO_WIN hero kills.
enum TeamMode {
	NONE,
	FFA,
}

const DEFAULT_PORT := 27015
const DEFAULT_MAX_PLAYERS := 4

var mode: RuntimeMode = RuntimeMode.OFFLINE
var game_mode: GameMode = GameMode.PJOTR
var difficulty: Difficulty = Difficulty.NORMAL
## Debug aid: skip ahead so late waves and bosses can be reached without a full run.
var start_wave := 1
## Continue-run payload filled before Main loads; consumed in Main._ready.
var pending_run_save: Dictionary = {}
var server_address := "127.0.0.1"
var server_port := DEFAULT_PORT
var max_players := DEFAULT_MAX_PLAYERS
## Set when Steam launches the game to accept a friend's invite while it wasn't already
## running (Steam appends "+connect_lobby <id>" to the command line in that case).
var pending_steam_lobby_id := 0
## Which biome the current wave is in (Pjotr mode).
## 0 grass meadow, 1 volcano, 2 ice, 3 factory, 4 docks — see biome_key().
var biome_id := 0
## When true, wave progression and new runs keep the chosen biome (F1 / --biome=).
var biome_locked := false
var biome_from_cli := false
## Playtest from the world editor: keep the dressed biome and return to the editor on leave.
var return_to_world_editor := false
## When true, Arena replaces auto-scatter with the saved editor layout for this biome.
var use_editor_level := false
## Optional explicit map name (without the world_editor_level_ prefix and .json
## suffix). When set, editor_level_path() resolves to user://world_editor_level_<name>.json.
## Lets the user tell the game exactly which "Save As" file to use.
var custom_editor_level_name := ""
## Offline co-op stand-ins: spawn the other three playable heroes as CPU allies.
var fill_cpu_allies := false
## FFA / Rift Clash split. NONE until a lobby or the FFA simulate button sets it.
var team_mode: TeamMode = TeamMode.NONE

const FFA_KILLS_TO_WIN := 15
const FFA_RESPAWN_SECONDS := 30.0
## Flat gold paid to the hero who landed a player kill, on top of the victim's lost purse.
const HERO_KILL_GOLD := 500
const FFA_PVP_INVULN_SECONDS := 10.0
## The last N seconds of the spawn shield flicker on/off before it disappears. The
## flicker beat accelerates as the timer runs down (see _refresh_pvp_modulate in
## player.gd), so the shield "dies" in a rapid pulse.
const FFA_PVP_SHIELD_FLICKER_SECONDS := 2.0
const FFA_CLASS_ID := "tobor"
const FFA_CPU_PEER_BASE := 101
const FFA_HEALTH_MULT := 1.45
## Primary cannon vs rival heroes: this many connected blasts to drop a full bar.
const FFA_PVP_SHOTS_TO_KILL := 10.0
## When true, the local FFA seat is also a CPU (four-bot sim). Menu FFA leaves this false.
var ffa_all_bots := false

const BIOME_KEYS := ["", "volcano", "ice", "factory", "docks"]
const BIOME_NAMES := ["Verdant Hollow", "Ashen Crater", "Frostmere Reach", "Ironworks Yard", "Saltbreak Docks"]
const BIOME_ALIASES := {
	"parking": 0,
	"parkeer": 0,
	"grass": 0,
	"gras": 0,
	"0": 0,
	"volcano": 1,
	"vulkaan": 1,
	"1": 1,
	"ice": 2,
	"ijs": 2,
	"2": 2,
	"factory": 3,
	"fabriek": 3,
	"3": 3,
	"docks": 4,
	"4": 4,
}


## One biome every 10 waves (2 boss cycles) so a run walks grass → volcano → ice → factory → docks.
## A world transition fires after the 2nd boss of the current world is defeated.
const BIOME_CYCLE_WAVES := 10


func biome_for_wave(wave: int) -> int:
	return posmod(int((maxi(1, wave) - 1) / float(BIOME_CYCLE_WAVES)), BIOME_KEYS.size())


func parse_biome(token: String) -> int:
	var key := token.strip_edges().to_lower()
	if BIOME_ALIASES.has(key):
		return int(BIOME_ALIASES[key])
	return -1


func biome_name() -> String:
	var index := clampi(biome_id, 0, BIOME_NAMES.size() - 1)
	return str(BIOME_NAMES[index])


func set_biome(id: int, lock: bool = true) -> void:
	biome_id = posmod(id, BIOME_KEYS.size())
	biome_locked = lock


func unlock_biome_for_wave(wave: int) -> void:
	biome_locked = false
	set_biome_for_wave(wave)


func set_biome_for_wave(wave: int) -> void:
	if biome_locked:
		return
	biome_id = biome_for_wave(wave)


func reset_biome_for_new_run() -> void:
	if biome_from_cli:
		return
	# World-editor playtest keeps the dressed biome. Menu PLAY must cycle worlds.
	if return_to_world_editor:
		return
	biome_locked = false
	set_biome_for_wave(start_wave)


func biome_key() -> String:
	var index := clampi(biome_id, 0, BIOME_KEYS.size() - 1)
	return str(BIOME_KEYS[index])


func editor_level_path() -> String:
	# An explicitly chosen "Save As" map overrides the default, so the user
	# can tell the game exactly which map file to use.
	if custom_editor_level_name:
		return "user://world_editor_level_%s.json" % custom_editor_level_name
	# Default map: the current biome's authored level. Grass (biome_key() == "")
	# keeps the original "grass_real" filename so the UI-verify harness (which
	# checks for the dense Verdant Hollow level specifically) keeps working.
	var key := biome_key()
	if key.is_empty():
		return "user://world_editor_level_grass_real.json"
	return "user://world_editor_level_%s.json" % key


const _CUSTOM_MAP_FILE := "user://custom_editor_map.json"


func persist_custom_map_name(name: String) -> void:
	## Remember the chosen "Save As" map so it survives restarts / fresh games.
	custom_editor_level_name = name
	var file := FileAccess.open(_CUSTOM_MAP_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"name": name}))
	file.close()


func _load_custom_map_name() -> void:
	if not FileAccess.file_exists(_CUSTOM_MAP_FILE):
		return
	var f := FileAccess.open(_CUSTOM_MAP_FILE, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var n := str(parsed.get("name", ""))
		if n:
			custom_editor_level_name = n


func _ready() -> void:
	_load_custom_map_name()
	configure_from_arguments(_cli_arguments())
	if is_ffa():
		print("[runtime] FFA auto-start bots=%s args=%s" % [ffa_all_bots, ",".join(_cli_arguments())])


func _cli_arguments() -> PackedStringArray:
	var merged: PackedStringArray = OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--") or argument.begins_with("+"):
			if argument not in merged:
				merged.append(argument)
	return merged


func configure_from_arguments(arguments: PackedStringArray) -> void:
	var next_mode := RuntimeMode.OFFLINE
	var next_address := "127.0.0.1"
	var next_port := DEFAULT_PORT

	if OS.has_feature("dedicated_server"):
		next_mode = RuntimeMode.DEDICATED_SERVER

	for i in arguments.size():
		var argument := arguments[i]
		if argument == "+connect_lobby" and i + 1 < arguments.size():
			pending_steam_lobby_id = arguments[i + 1].to_int()
		elif argument == "--server":
			next_mode = RuntimeMode.DEDICATED_SERVER
		elif argument == "--host":
			next_mode = RuntimeMode.HOST
		elif argument.begins_with("--join="):
			next_mode = RuntimeMode.CLIENT
			next_address = argument.trim_prefix("--join=")
		elif argument.begins_with("--start-wave="):
			start_wave = maxi(1, int(argument.split("=")[1]))
			if not biome_locked:
				biome_id = biome_for_wave(start_wave)
		elif argument.begins_with("--biome="):
			var parsed := parse_biome(argument.trim_prefix("--biome="))
			if parsed >= 0:
				biome_id = parsed
				biome_locked = true
				biome_from_cli = true
		elif argument == "--classic":
			game_mode = GameMode.CLASSIC
		elif argument == "--pjotr":
			game_mode = GameMode.PJOTR
		elif argument == "--toborworld":
			game_mode = GameMode.PJOTR
		elif argument == "--ffa":
			team_mode = TeamMode.FFA
			fill_cpu_allies = true
			game_mode = GameMode.PJOTR
		elif argument == "--ffa-bots":
			team_mode = TeamMode.FFA
			fill_cpu_allies = true
			ffa_all_bots = true
			game_mode = GameMode.PJOTR
		elif argument.begins_with("--difficulty="):
			var requested_difficulty := argument.trim_prefix("--difficulty=").to_upper()
			if requested_difficulty in Difficulty.keys():
				difficulty = Difficulty[requested_difficulty]
		elif argument.begins_with("--port="):
			var requested_port := argument.trim_prefix("--port=").to_int()
			if requested_port > 0 and requested_port <= 65535:
				next_port = requested_port

	mode = next_mode
	server_address = next_address
	server_port = next_port
	mode_changed.emit(mode)


func set_game_mode(next_game_mode: GameMode) -> void:
	game_mode = GameMode.PJOTR if next_game_mode == GameMode.TOBORWORLD else next_game_mode


func set_difficulty(next_difficulty: Difficulty) -> void:
	difficulty = next_difficulty


func difficulty_name() -> String:
	return Difficulty.keys()[difficulty].capitalize()


func set_team_mode(next_mode: TeamMode) -> void:
	team_mode = next_mode
	if team_mode == TeamMode.NONE:
		ffa_all_bots = false
		return
	fill_cpu_allies = true


func is_rift_clash() -> bool:
	return team_mode == TeamMode.FFA


func is_ffa() -> bool:
	return team_mode == TeamMode.FFA


func is_classic() -> bool:
	return game_mode == GameMode.CLASSIC


func is_tobor_world() -> bool:
	return false


func uses_biomes() -> bool:
	return not is_classic()


func uses_pixel_art() -> bool:
	return not is_classic()


func active_class_id() -> String:
	if is_classic():
		return "arclight"
	return PlayerProfile.selected_class_id


## One playable hero per FFA seat. Seat 0 (local) uses the lobby pick; CPUs take the rest.
func ffa_class_for_peer(peer_id: int) -> String:
	var roster := PlayerClass.playable_ids()
	var preferred := PlayerClass.sanitize_id(PlayerProfile.selected_class_id)
	var start := roster.find(preferred)
	if start < 0:
		start = 0
	var seat := 0
	if peer_id >= FFA_CPU_PEER_BASE and peer_id < FFA_CPU_PEER_BASE + 8:
		seat = 1 + (peer_id - FFA_CPU_PEER_BASE)
	return roster[(start + seat) % roster.size()]


func game_mode_name() -> String:
	match game_mode:
		GameMode.CLASSIC:
			return "classic"
		_:
			return "pjotr"


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

extends Node

const GAME_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

@onready var backdrop: ColorRect = $StatusLayer/Backdrop
@onready var lobby_panel: PanelContainer = $StatusLayer/LobbyPanel
@onready var title_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/Title
@onready var subtitle_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/Subtitle
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
@onready var tobor_world_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/ModeRow/ToborWorldButton
@onready var difficulty_label: Label = $StatusLayer/LobbyPanel/Margin/Layout/DifficultyLabel
@onready var difficulty_row: HBoxContainer = $StatusLayer/LobbyPanel/Margin/Layout/DifficultyRow
@onready var easy_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/DifficultyRow/EasyButton
@onready var normal_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/DifficultyRow/NormalButton
@onready var hard_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/DifficultyRow/HardButton
@onready var brutal_button: Button = $StatusLayer/LobbyPanel/Margin/Layout/DifficultyRow/BrutalButton
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
@onready var sfx_toggle: CheckButton = $StatusLayer/LobbyPanel/Margin/Layout/AudioRow/SfxToggle
@onready var music_toggle: CheckButton = $StatusLayer/LobbyPanel/Margin/Layout/AudioRow/MusicToggle

# --- Overhaul UI (built programmatically in _ready, parented into the existing Layout) ---
var world_row: HBoxContainer = null
var loadout_panel: VBoxContainer = null
var loadout_row: HBoxContainer = null
var ability_pool: GridContainer = null
var loadout_slots: Array[Button] = []

# --- HoN-style ability description panel (lives in bootstrap.tscn) ---
@onready var ability_panel: PanelContainer = $StatusLayer/AbilityPanel
@onready var ability_hero_header: Label = $StatusLayer/AbilityPanel/Margin/Layout/HeroHeader
@onready var ability_hero_blurb: Label = $StatusLayer/AbilityPanel/Margin/Layout/HeroBlurb
@onready var ability_list: VBoxContainer = $StatusLayer/AbilityPanel/Margin/Layout/AbilityScroll/AbilityList

var game_loaded := false
var class_buttons: Array[Button] = []
var world_buttons: Array[Button] = []
var _hero_group: ButtonGroup = null
var _rebuilding_cards := false
var _world_by_id_runtime: Dictionary = {}
var WORLD_ORDER: Array = []
## Steam init is async (see SteamService.INIT_TIMEOUT_SECONDS); Host must not be clickable
## until we know either way, or a click during that window silently falls back to a
## LAN-only host with no lobby or invite at all.
var _steam_status_known := false
var _lobby_enabled := true

## True once the multiplayer peer is connected (host or client) but the match hasn't been
## started yet — everyone sits here seeing who's connected until the host presses Start.
var _in_network_lobby := false
var _is_lobby_host := false
## peer_id -> {"name": String, "class_id": String, "loadout": Array}
var lobby_roster: Dictionary = {}
var _waiting_steam_operation := false
var _steam_operation_elapsed := 0.0
var _steam_lobby_members: Array[String] = []
var _lobby_refresh_timer := 0.0
var _updating_class_ui := false
var _updating_audio_ui := false
var cpu_coop_button: Button

const STEAM_OPERATION_TIMEOUT := 22.0

const _WORLD_LABELS := {
	0: "Iron Foundry",
	1: "Ashen Caldera",
	2: "Verdant Wilds",
	3: "Storm Court",
}


## ---------------------------------------------------------------------------
## Missing player_class helpers (rebuilt player_class.gd has world_of() but no
## world_name / ids_in_world / WORLD_ORDER / is_hero_unlocked / default_hero_for_world).
## Kept inline here so bootstrap doesn't depend on them being re-added to the data layer.
## ---------------------------------------------------------------------------
func _init_world_helpers() -> void:
	_world_by_id_runtime.clear()
	WORLD_ORDER = []
	var seen: Dictionary = {}
	for entry in PlayerClass.CLASSES:
		var cid := str(entry.get("id", ""))
		if cid.is_empty():
			continue
		var w := PlayerClass.world_of(cid)
		_world_by_id_runtime[cid] = w
		if not seen.has(w):
			seen[w] = true
			WORLD_ORDER.append(w)
	WORLD_ORDER.sort()


func world_name(world_index: int) -> String:
	return str(_WORLD_LABELS.get(world_index, "World %d" % world_index))


func ids_in_world(world_index: int) -> Array[String]:
	var out: Array[String] = []
	for cid in _world_by_id_runtime.keys():
		if int(_world_by_id_runtime[cid]) == world_index:
			out.append(String(cid))
	return out


func _is_hero_unlocked(_hero_id: String) -> bool:
	if PlayerProfile.has_method("is_hero_unlocked"):
		return bool(PlayerProfile.is_hero_unlocked(_hero_id))
	return true


func _default_hero_for_world(world_index: int) -> String:
	var ids := ids_in_world(world_index)
	for hid in ids:
		if _is_hero_unlocked(hid):
			return hid
	return ids[0] if not ids.is_empty() else PlayerClass.DEFAULT_CLASS_ID


func _ready() -> void:
	_init_world_helpers()
	_build_overhaul_ui()
	classic_button.pressed.connect(_on_game_mode_pressed.bind(GameRuntime.GameMode.CLASSIC))
	pjotr_button.pressed.connect(_on_game_mode_pressed.bind(GameRuntime.GameMode.PJOTR))
	tobor_world_button.visible = false
	easy_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.EASY))
	normal_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.NORMAL))
	hard_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.HARD))
	brutal_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.BRUTAL))
	_refresh_difficulty()
	for slot_index in loadout_slots.size():
		(loadout_slots[slot_index] as Button).disabled = true
		_decorate_slot_button(loadout_slots[slot_index] as Button)
	_apply_tobor_theme()
	_install_cpu_coop_button()
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
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	music_toggle.toggled.connect(_on_music_toggled)
	_sync_audio_toggles()
	SteamService.steam_ready.connect(_on_steam_ready)
	SteamService.steam_unavailable.connect(_on_steam_unavailable)
	SteamService.join_requested.connect(_on_steam_join_requested)
	SteamService.lobby_members_changed.connect(_on_steam_lobby_members_changed)
	NetworkService.peer_joined.connect(_on_lobby_peer_joined)
	_refresh_steam_status()
	AudioService.play_music()
	call_deferred("_start_runtime")
	set_process(true)


## Builds the WorldRow, LoadoutPanel (LoadoutRow + AbilityPool) and wires them into the
## existing tscn Layout so the .tscn doesn't need to be rewritten. Parents them around
## the ClassGrid so the reading order is: ModeRow → Difficulty → Hero label → WorldRow →
## ClassGrid → LoadoutPanel → ClassDescription.
func _build_overhaul_ui() -> void:
	var layout := class_grid.get_parent() as VBoxContainer
	if layout == null:
		return
	# Wrap WorldRow + ClassGrid + LoadoutPanel in a ScrollContainer so the growing
	# hero content scrolls instead of pushing StartGameButton (a later Layout sibling)
	# offscreen. The scroll container expands to fill leftover space, so the ModeRow
	# and StartGameButton keep their fixed slots below it.
	var hero_scroll := ScrollContainer.new()
	hero_scroll.name = "HeroContentScroll"
	hero_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_scroll.custom_minimum_size = Vector2(0, 240)
	hero_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(hero_scroll)
	layout.move_child(hero_scroll, class_grid.get_index())
	var hero_content := VBoxContainer.new()
	hero_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_content.add_theme_constant_override("separation", 6)
	hero_scroll.add_child(hero_content)
	# Reparent the hero grid into the scroll content; the `class_grid` onready ref is
	# unaffected because it points at the node, not its parent.
	class_grid.reparent(hero_content)
	# WorldRow sits directly above the hero grid.
	world_row = HBoxContainer.new()
	world_row.name = "WorldRow"
	world_row.alignment = BoxContainer.ALIGNMENT_CENTER
	world_row.add_theme_constant_override("separation", 6)
	hero_content.add_child(world_row)
	hero_content.move_child(world_row, class_grid.get_index())
	# LoadoutPanel goes right under the hero grid.
	loadout_panel = VBoxContainer.new()
	loadout_panel.name = "LoadoutPanel"
	loadout_panel.add_theme_constant_override("separation", 6)
	loadout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_content.add_child(loadout_panel)
	hero_content.move_child(loadout_panel, class_grid.get_index() + 1)
	var loadout_header := Label.new()
	loadout_header.text = "Loadout"
	loadout_header.add_theme_color_override("font_color", Color("9fb3d1"))
	loadout_panel.add_child(loadout_header)
	loadout_row = HBoxContainer.new()
	loadout_row.name = "LoadoutRow"
	loadout_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout_row.add_theme_constant_override("separation", 8)
	loadout_panel.add_child(loadout_row)
	loadout_slots = []
	for slot_name in ["Slot1", "Slot2", "Slot3", "SlotUlt"]:
		var b := Button.new()
		b.name = slot_name
		b.toggle_mode = false
		b.custom_minimum_size = Vector2(72, 72)
		b.disabled = true
		loadout_row.add_child(b)
		loadout_slots.append(b)
	var pool_header := Label.new()
	pool_header.text = "Pool"
	pool_header.add_theme_color_override("font_color", Color("9fb3d1"))
	loadout_panel.add_child(pool_header)
	ability_pool = GridContainer.new()
	ability_pool.name = "AbilityPool"
	ability_pool.columns = 4
	ability_pool.add_theme_constant_override("h_separation", 6)
	ability_pool.add_theme_constant_override("v_separation", 6)
	loadout_panel.add_child(ability_pool)


func _start_runtime() -> void:
	match GameRuntime.mode:
		GameRuntime.RuntimeMode.OFFLINE:
			if GameRuntime.pending_steam_lobby_id != 0:
				_show_lobby("Joining Steam lobby...")
				_check_pending_steam_invite()
			else:
				_show_lobby("Pick a hero")
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
		join_label.text = "Join address"
	elif SteamService.is_available():
		steam_status_label.text = "Steam  ·  %s" % SteamService.local_persona_name()
		join_label.text = "LAN address"
	else:
		steam_status_label.text = "Steam offline  ·  LAN only"
		join_label.text = "Join address"
	host_button.disabled = not _lobby_enabled or not _steam_status_known


func _check_pending_steam_invite() -> void:
	if not game_loaded and GameRuntime.pending_steam_lobby_id != 0 and SteamService.is_available():
		var lobby_id := GameRuntime.pending_steam_lobby_id
		GameRuntime.pending_steam_lobby_id = 0
		_join_via_steam(lobby_id)


func _on_steam_join_requested(lobby_id: int) -> void:
	if game_loaded:
		return
	_join_via_steam(lobby_id)


func _apply_tobor_theme() -> void:
	backdrop.color = Color("0c0a08")
	title_label.text = "TOBOR"
	title_label.add_theme_font_override("font", preload("res://assets/fonts/Barlow-SemiBold.ttf"))
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color("ff7a2e"))
	subtitle_label.add_theme_color_override("font_color", Color("f5c542"))
	mode_row.visible = true
	class_label.text = "Hero"
	lobby_title_label.text = "Lobby"
	_apply_hero_backdrop()


func _hero_backdrop() -> TextureRect:
	var layer := $StatusLayer as CanvasLayer
	var art := layer.get_node_or_null("ToborAction") as TextureRect
	if art != null:
		return art
	art = TextureRect.new()
	art.name = "ToborAction"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(art)
	layer.move_child(art, backdrop.get_index() + 1)
	return art


func _apply_hero_backdrop() -> void:
	var art := _hero_backdrop()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = SpriteLibrary.menu_backdrop_for(PlayerProfile.selected_class_id)
	art.visible = true


var selected_world: int = 0

func _build_class_selection() -> void:
	_hero_group = ButtonGroup.new()
	_hero_group.allow_unpress = false
	_build_world_tabs()
	selected_world = PlayerClass.world_of(PlayerProfile.selected_class_id)
	_rebuild_hero_cards()


func _build_world_tabs() -> void:
	if world_row == null:
		return
	for child in world_row.get_children():
		child.queue_free()
	world_buttons.clear()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for world in WORLD_ORDER:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_group = group
		tab.custom_minimum_size = Vector2(120, 34)
		tab.text = world_name(world).to_upper()
		tab.add_theme_font_size_override("font_size", 12)
		tab.toggled.connect(_on_world_tab_toggled.bind(world))
		world_row.add_child(tab)
		world_buttons.append(tab)


func _rebuild_hero_cards() -> void:
	if _rebuilding_cards:
		return
	_rebuilding_cards = true
	for child in class_grid.get_children():
		class_grid.remove_child(child)
		child.free()
	class_buttons.clear()
	for world_index in world_buttons.size():
		if world_index < WORLD_ORDER.size():
			world_buttons[world_index].button_pressed = (WORLD_ORDER[world_index] == selected_world)
	var hero_ids := ids_in_world(selected_world)
	for hero_id in hero_ids:
		var class_data := PlayerClass.by_id(hero_id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _hero_group
		button.custom_minimum_size = Vector2(252, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_constant_override("line_spacing", 0)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.icon = SpriteLibrary.texture_for(hero_id)
		button.add_theme_constant_override("icon_max_width", 40)
		button.text = "%s\n%s" % [str(class_data.name).to_upper(), str(class_data.role).to_upper()]
		button.add_theme_color_override("font_color", Color(str(class_data.accent_color)))
		button.toggled.connect(_on_class_toggled.bind(hero_id))
		button.mouse_entered.connect(_on_hero_hovered.bind(hero_id))
		class_grid.add_child(button)
		class_buttons.append(button)
		_style_hero_card(button, class_data)
	while class_grid.get_child_count() < 6:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(252, 56)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		class_grid.add_child(pad)
	_rebuilding_cards = false
	_refresh_class_selection()


func _style_hero_card(button: Button, class_data: Dictionary) -> void:
	var hero_id := str(class_data.id)
	var unlocked := _is_hero_unlocked(hero_id)
	button.add_theme_color_override("font_color", Color(str(class_data.accent_color)))
	if unlocked:
		button.disabled = false
		button.text = "%s\n%s" % [str(class_data.name).to_upper(), str(class_data.role).to_upper()]
		button.modulate = Color.WHITE
	else:
		var shards := int(PlayerProfile.hero_shards.get(hero_id, 0)) if PlayerProfile.has_method("get") else 0
		var needed := int(PlayerProfile.HERO_SHARDS_TO_UNLOCK) if PlayerProfile.has_method("get") else 0
		button.disabled = true
		button.text = "%s\nLOCKED %d/%d" % [str(class_data.name).to_upper(), shards, needed]
		button.modulate = Color(0.55, 0.55, 0.6, 1.0)
		button.tooltip_text = "Clear waves solo to unlock %s (%s)." % [str(class_data.name), world_name(int(class_data.get("world", 0)))]


func _on_world_tab_toggled(is_pressed: bool, world: int) -> void:
	if not is_pressed:
		return
	selected_world = world
	AudioService.play("ui_click")
	_rebuild_hero_cards()
	_select_default_current_hero()


func _select_default_current_hero() -> void:
	if _is_hero_unlocked(PlayerProfile.selected_class_id):
		return
	PlayerProfile.select_class(_default_hero_for_world(selected_world))


func _on_game_mode_pressed(next_game_mode: GameRuntime.GameMode) -> void:
	AudioService.play("ui_click")
	GameRuntime.set_game_mode(next_game_mode)
	_refresh_game_mode()


func _refresh_game_mode() -> void:
	classic_button.button_pressed = GameRuntime.game_mode == GameRuntime.GameMode.CLASSIC
	pjotr_button.button_pressed = not GameRuntime.is_classic()
	tobor_world_button.visible = false
	mode_row.visible = true
	var show_classes := not GameRuntime.is_classic()
	if world_row != null:
		world_row.visible = show_classes
	class_label.visible = show_classes
	class_grid.visible = show_classes
	if loadout_panel != null:
		loadout_panel.visible = show_classes
	if ability_panel != null:
		ability_panel.visible = show_classes and not _in_network_lobby
	difficulty_label.visible = not GameRuntime.is_classic()
	difficulty_row.visible = not GameRuntime.is_classic()
	if cpu_coop_button != null:
		cpu_coop_button.visible = not GameRuntime.is_classic()
	if GameRuntime.is_classic():
		class_description.text = "Original grid arena. Arc Staff, no shop."
	else:
		_refresh_class_selection()


func _on_difficulty_pressed(next_difficulty: GameRuntime.Difficulty) -> void:
	AudioService.play("ui_click")
	GameRuntime.set_difficulty(next_difficulty)
	_refresh_difficulty()


func _refresh_difficulty() -> void:
	var buttons := {
		GameRuntime.Difficulty.EASY: easy_button,
		GameRuntime.Difficulty.NORMAL: normal_button,
		GameRuntime.Difficulty.HARD: hard_button,
		GameRuntime.Difficulty.BRUTAL: brutal_button,
	}
	for difficulty_option in buttons:
		buttons[difficulty_option].button_pressed = difficulty_option == GameRuntime.difficulty


func _on_class_toggled(is_pressed: bool, class_id: String) -> void:
	if _updating_class_ui or not is_pressed:
		return
	PlayerProfile.select_class(class_id)
	AudioService.play("ui_click")
	_refresh_class_selection()


func _on_hero_hovered(hero_id: String) -> void:
	_populate_ability_panel(hero_id)


func _sync_audio_toggles() -> void:
	_updating_audio_ui = true
	sfx_toggle.button_pressed = AudioService.sfx_enabled
	music_toggle.button_pressed = AudioService.music_enabled
	_updating_audio_ui = false


func _on_sfx_toggled(pressed: bool) -> void:
	if _updating_audio_ui:
		return
	AudioService.set_sfx_enabled(pressed)
	if pressed:
		AudioService.play("ui_click")


func _on_music_toggled(pressed: bool) -> void:
	if _updating_audio_ui:
		return
	AudioService.set_music_enabled(pressed)
	AudioService.play("ui_click")


func _refresh_class_selection() -> void:
	_updating_class_ui = true
	var hero_ids := ids_in_world(selected_world)
	for index in class_buttons.size():
		if index < hero_ids.size():
			class_buttons[index].button_pressed = hero_ids[index] == PlayerProfile.selected_class_id
	_updating_class_ui = false
	_refresh_loadout_panel()
	_apply_hero_backdrop()
	_refresh_header_detail(PlayerProfile.selected_class_id)
	_populate_ability_panel(PlayerProfile.selected_class_id)


## ---------------------------------------------------------------------------
## HoN-style ability description panel.
##
## Template convention used in PlayerClass.ABILITIES[*].description:
##   {power}        -> "POWER_RANK1/POWER_RANK2/POWER_RANK3/POWER_RANK4" (slash list)
##   {power_base}   -> just rank-1 number
##   {cooldown}     -> "CD1/CD2/CD3/CD4 seconds"
##   {radius}, {range}, {dash_distance}, {duration}, {chain_count}
##                -> same slash-list treatment
##   {RANGE_BASE}/{RADIUS_BASE}/etc (any-caps "_BASE") -> rank-1 number only
##   {slow_factor} / {stun_duration} / {mark_pct} / {lifesteal_pct}
##                -> pulled from the ability's on-hit modifier dicts
##
## ability_values() calls below hit ranks 1..MAX_ABILITY_RANK_REPORT so the
## numbers are honest, not authored-flat.
## ---------------------------------------------------------------------------

const ABILITY_PANEL_RANKS_TO_SHOW := 4
const ABILITY_PANEL_HOTKEYS := ["Q", "W", "E", "R"]

func _populate_ability_panel(hero_id: String) -> void:
	if ability_list == null or ability_hero_header == null or ability_panel == null:
		return
	if GameRuntime.is_classic():
		ability_panel.visible = false
		return
	ability_panel.visible = true
	var hero_data := PlayerClass.by_id(hero_id)
	ability_hero_header.text = "%s  ·  %s" % [str(hero_data.get("name", hero_id)).to_upper(), str(hero_data.get("role", "")).to_upper()]
	ability_hero_header.add_theme_color_override("font_color", Color(str(hero_data.get("accent_color", "ff8a3d"))))
	ability_hero_blurb.text = str(hero_data.get("description", ""))
	for child in ability_list.get_children():
		child.queue_free()
	var kit: Array = _get_loadout_for(hero_id)
	for slot_index in mini(kit.size(), 4):
		var ability_id := String(kit[slot_index])
		if ability_id.is_empty() or not PlayerClass.ABILITIES.has(ability_id):
			continue
		ability_list.add_child(_build_ability_card(ability_id, ABILITY_PANEL_HOTKEYS[slot_index]))


func _build_ability_card(ability_id: String, hotkey: String) -> Control:
	var info: Dictionary = PlayerClass.ABILITIES.get(ability_id, {})
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.85)
	style.border_color = Color(0.24, 0.28, 0.36, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vbox.add_child(head)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = SpriteLibrary.texture_for(ability_id)
	head.add_child(icon)
	var title_label := Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = str(info.get("name", ability_id))
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55, 1.0))
	head.add_child(title_label)
	var hotkey_label := Label.new()
	hotkey_label.text = "[%s]" % hotkey
	hotkey_label.add_theme_font_size_override("font_size", 14)
	hotkey_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8, 1.0))
	head.add_child(hotkey_label)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color", Color(0.86, 0.90, 0.96, 1.0))
	body.add_theme_font_size_override("normal_font_size", 13)
	body.text = _format_ability_tooltip(ability_id)
	vbox.add_child(body)
	return card


## Builds the BBCode body for one ability card. Substitutes any {placeholder} in
## the stored description with rank-slashed numbers pulled from ability_values().
func _format_ability_tooltip(ability_id: String) -> String:
	var info: Dictionary = PlayerClass.ABILITIES.get(ability_id, {})
	if info.is_empty():
		return ability_id
	var template := str(info.get("description", ""))
	var substituted := _substitute_placeholders(template, ability_id, info)
	var out: Array[String] = []
	out.append(substituted)
	var values_r1 := PlayerClass.ability_values(ability_id, 1)
	var values_r4 := PlayerClass.ability_values(ability_id, ABILITY_PANEL_RANKS_TO_SHOW)
	var stat_line: Array[String] = []
	if float(values_r1.get("cooldown", 0.0)) > 0.0:
		stat_line.append("[b]Cooldown:[/b] %s s" % _rank_slash_list(ability_id, "cooldown", 1))
	if float(values_r1.get("radius", 0.0)) > 0.0:
		stat_line.append("[b]Radius:[/b] %s" % _rank_slash_list(ability_id, "radius", 0))
	if float(values_r1.get("range", 0.0)) > 0.0:
		stat_line.append("[b]Range:[/b] %s" % _rank_slash_list(ability_id, "range", 0))
	if float(values_r1.get("dash_distance", 0.0)) > 0.0:
		stat_line.append("[b]Dash:[/b] %s" % _rank_slash_list(ability_id, "dash_distance", 0))
	if int(values_r1.get("chain_count", 0)) > 0:
		stat_line.append("[b]Chains:[/b] %s" % _rank_slash_list(ability_id, "chain_count", 0))
	if float(values_r4.get("duration", 0.0)) > 0.0:
		stat_line.append("[b]Duration:[/b] %s s" % _rank_slash_list(ability_id, "duration", 1))
	if not stat_line.is_empty():
		out.append("[color=9fb3d1]%s[/color]" % "  ·  ".join(stat_line))
	return "\n".join(out)


## Replaces {key} symbols in a template with numbers derived from ability_values().
## For keys like "power", "cooldown", "radius", "range", "dash_distance", "duration",
## "chain_count", we emit rank lists "R1/R2/R3/R4". Suffix "_base" returns rank-1 only.
func _substitute_placeholders(template: String, ability_id: String, info: Dictionary) -> String:
	if template.find("{") == -1:
		return template
	var result := template
	# Build a value pool for this ability: rank1..rank4 values + raw field lookups.
	var ranks: Array[Dictionary] = []
	for r in range(1, ABILITY_PANEL_RANKS_TO_SHOW + 1):
		ranks.append(PlayerClass.ability_values(ability_id, r))
	var regex := RegEx.new()
	regex.compile("\\{([a-zA-Z_]+)\\}")
	var rebuilt := ""
	var last_end := 0
	for m in regex.search_all(template):
		rebuilt += template.substr(last_end, m.get_start() - last_end)
		var key := m.get_string(1)
		rebuilt += _placeholder_value(key, ability_id, info, ranks)
		last_end = m.get_end()
	rebuilt += template.substr(last_end)
	result = rebuilt
	return result


func _placeholder_value(key: String, _ability_id: String, info: Dictionary, ranks: Array[Dictionary]) -> String:
	if key.is_empty():
		return ""
	var lower := key.to_lower()
	# "<field>_base" -> rank-1 only.
	if lower.ends_with("_base"):
		var field := lower.substr(0, lower.length() - 5)
		if ranks.size() > 0 and ranks[0].has(field):
			return _format_number(float(ranks[0][field]), field)
		# Fall back to raw info dict (e.g. "cooldown_base" was a raw field).
		if info.has(key):
			return _format_number(float(info[key]), field)
		return ""
	# Recognized rank-scaled fields -> "R1/R2/R3/R4".
	if lower in ["power", "cooldown", "radius", "range", "dash_distance", "duration", "chain_count", "footprint"]:
		return _rank_slash_list_from_values(ranks, lower)
	# On-hit modifiers.
	match lower:
		"slow_factor":
			if info.has("slow_on_hit"):
				return "%d%%" % int((1.0 - float(info.slow_on_hit.factor)) * 100.0)
		"slow_duration":
			if info.has("slow_on_hit"):
				return "%.1f" % float(info.slow_on_hit.duration)
		"stun_duration":
			if info.has("stun_on_hit"):
				return "%.1f" % float(info.stun_on_hit.duration)
		"mark_pct":
			if info.has("mark_on_hit"):
				return "%d%%" % int(float(info.mark_on_hit.bonus_pct) * 100.0)
		"mark_duration":
			if info.has("mark_on_hit"):
				return "%.1f" % float(info.mark_on_hit.duration)
		"lifesteal_pct":
			if info.has("lifesteal_pct"):
				return "%d%%" % int(float(info.lifesteal_pct) * 100.0)
	# Raw lookup.
	if info.has(key):
		var v: Variant = info[key]
		if v is float or v is int:
			return _format_number(float(v), lower)
		return str(v)
	return "{%s}" % key


func _rank_slash_list(ability_id: String, field: String, decimals: int) -> String:
	var parts: Array[String] = []
	for r in range(1, ABILITY_PANEL_RANKS_TO_SHOW + 1):
		var v := PlayerClass.ability_values(ability_id, r)
		if not v.has(field):
			continue
		parts.append(_format_number(float(v[field]), field, decimals))
	return "/".join(parts)


func _rank_slash_list_from_values(ranks: Array[Dictionary], field: String) -> String:
	var parts: Array[String] = []
	for v in ranks:
		if not v.has(field):
			continue
		parts.append(_format_number(float(v[field]), field))
	return "[b]%s[/b]" % "/".join(parts)


func _format_number(value: float, field: String, decimals: int = -1) -> String:
	if decimals >= 0:
		return "%.*f" % [decimals, value]
	match field:
		"cooldown", "duration", "slow_duration", "stun_duration", "mark_duration":
			return "%.1f" % value
		_:
			return "%d" % int(roundf(value))


func _refresh_loadout_panel() -> void:
	if loadout_panel == null:
		return
	var hero_id := PlayerProfile.selected_class_id
	var loadout: Array = []
	if PlayerProfile.has_method("loadout_for"):
		loadout = PlayerProfile.loadout_for(hero_id)
	else:
		var kit := PlayerClass.kit_ability_ids(hero_id)
		var pool := PlayerClass.ability_pool_for(hero_id)
		var alt := ""
		for aid in pool:
			if aid not in kit:
				alt = aid
				break
		loadout = [kit[0] if kit.size() > 0 else "", kit[1] if kit.size() > 1 else "", alt, kit[2] if kit.size() > 2 else ""]
	var slot_names := ["1", "2", "3", "ULT"]
	for slot_index in loadout_slots.size():
		var button := loadout_slots[slot_index] as Button
		var want: String = str(loadout[slot_index]) if slot_index < loadout.size() else ""
		var label: String = slot_names[slot_index]
		button.disabled = true
		button.text = ""
		if want.is_empty() or not PlayerClass.ABILITIES.has(want):
			button.icon = null
			(button.get_node_or_null("SlotTag") as Label).text = label
			continue
		button.icon = SpriteLibrary.texture_for(want)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 52)
		button.add_theme_constant_override("icon_max_height", 52)
		(button.get_node_or_null("SlotTag") as Label).text = label
		button.tooltip_text = _ability_tooltip(want)
	_refresh_ability_pool(hero_id)


func _ability_tooltip(ability_id: String) -> String:
	var info: Dictionary = PlayerClass.ABILITIES.get(ability_id, {})
	if info.is_empty():
		return ability_id
	var lines: Array[String] = []
	var tag := "ULT" if float(info.get("cooldown_base", 0.0)) >= 14.0 else str(PlayerClass.ARCHETYPE_NAMES.get(int(info.get("archetype", 0)), "Ability"))
	lines.append("%s  ·  %s" % [str(info.get("name", ability_id)).to_upper(), tag])
	lines.append(str(info.get("description", "")))
	var values := PlayerClass.ability_values(ability_id, 1)
	var stats: Array[String] = []
	if values.has("cooldown"):
		stats.append("CD %.0fs" % float(values.cooldown))
	if values.has("power") and float(values.power) > 0.0:
		stats.append("PWR %d" % int(values.power))
	if values.has("range") and float(values.range) > 0.0:
		stats.append("RNG %d" % int(values.range))
	if values.has("radius") and float(values.radius) > 0.0:
		stats.append("AoE %d" % int(values.radius))
	if values.has("dash_distance") and float(values.dash_distance) > 0.0:
		stats.append("Dash %d" % int(values.dash_distance))
	if values.has("duration") and float(values.duration) > 0.0:
		stats.append("%.1fs up" % float(values.duration))
	if not stats.is_empty():
		lines.append(" | ".join(stats))
	return "\n".join(lines)


func _refresh_header_detail(hero_id: String) -> void:
	var selected := PlayerClass.by_id(hero_id)
	subtitle_label.text = str(selected.role).to_upper()
	class_description.text = "%s\n%s" % [str(selected.description), _stat_summary(selected)]


func _stat_summary(cls: Dictionary) -> String:
	var rng := "Melee" if int(cls.get("attack_range", 0)) <= 150 else "Ranged"
	return "%s · HP %d · CD %ds" % [rng, int(cls.get("max_health", 0)), int(cls.get("attack_interval", 0))]


func _refresh_ability_pool(hero_id: String) -> void:
	if ability_pool == null:
		return
	for child in ability_pool.get_children():
		ability_pool.remove_child(child)
		child.free()
	var kit: Array = PlayerClass.kit_ability_ids(hero_id)
	var pool: Array[String] = PlayerClass.ability_pool_for(hero_id)
	var shown: Array[String] = []
	for aid in kit:
		if not shown.has(aid):
			shown.append(aid)
	for aid in pool:
		if shown.size() >= 12:
			break
		if aid not in shown:
			shown.append(aid)
	for ability_id in shown:
		var info: Dictionary = PlayerClass.ABILITIES.get(ability_id, {})
		if info.is_empty():
			continue
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.texture_normal = SpriteLibrary.texture_for(ability_id)
		btn.tooltip_text = _ability_tooltip(ability_id)
		ability_pool.add_child(btn)


func _decorate_slot_button(button: Button) -> void:
	button.expand_icon = false
	var tag := Label.new()
	tag.name = "SlotTag"
	tag.position = Vector2(2, 2)
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", Color("f5c542"))
	tag.add_theme_color_override("font_shadow_color", Color.BLACK)
	tag.add_theme_constant_override("shadow_size", 2)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tag)


func _on_solo_pressed() -> void:
	AudioService.play("ui_click")
	GameRuntime.fill_cpu_allies = false
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_lock_biome_to_selected_hero()
	_open_game()


func _lock_biome_to_selected_hero() -> void:
	var hero_world := PlayerClass.world_of(PlayerProfile.selected_class_id)
	match hero_world:
		PlayerClass.World.ASHEN_CALDERA:
			GameRuntime.set_biome(1, true)
		PlayerClass.World.VERDANT_WILDS:
			GameRuntime.set_biome(4, true)
		PlayerClass.World.STORM_COURT:
			GameRuntime.set_biome(3, true)
		_:
			GameRuntime.set_biome(0, true)


func _install_cpu_coop_button() -> void:
	cpu_coop_button = Button.new()
	cpu_coop_button.name = "CpuCoopButton"
	cpu_coop_button.custom_minimum_size = Vector2(0, 48)
	cpu_coop_button.text = "CO-OP"
	var layout := solo_button.get_parent()
	layout.add_child(cpu_coop_button)
	layout.move_child(cpu_coop_button, solo_button.get_index() + 1)
	cpu_coop_button.pressed.connect(_on_cpu_coop_pressed)


func _on_cpu_coop_pressed() -> void:
	AudioService.play("ui_click")
	GameRuntime.fill_cpu_allies = true
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	if ProgressionService.has_method("unlock_entire_roster"):
		ProgressionService.unlock_entire_roster()
	_open_game()


func _on_host_pressed() -> void:
	AudioService.play("ui_click")
	GameRuntime.fill_cpu_allies = false
	GameRuntime.set_team_mode(GameRuntime.TeamMode.NONE)
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.HOST)
	if SteamService.is_available():
		_start_steam_host()
	else:
		_start_host()


func _on_join_pressed() -> void:
	AudioService.play("ui_click")
	GameRuntime.fill_cpu_allies = false
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


func _get_loadout_for(hero_id: String) -> Array:
	if PlayerProfile.has_method("loadout_for"):
		return PlayerProfile.loadout_for(hero_id)
	var kit := PlayerClass.kit_ability_ids(hero_id)
	var pool := PlayerClass.ability_pool_for(hero_id)
	var alt := ""
	for aid in pool:
		if aid not in kit:
			alt = aid
			break
	return [kit[0] if kit.size() > 0 else "", kit[1] if kit.size() > 1 else "", alt, kit[2] if kit.size() > 2 else ""]


func _enter_network_lobby(is_host: bool) -> void:
	_in_network_lobby = true
	_is_lobby_host = is_host
	if is_host:
		lobby_roster = {1: {
			"name": PlayerProfile.display_name,
			"class_id": GameRuntime.active_class_id(),
			"loadout": _get_loadout_for(GameRuntime.active_class_id()),
		}}
		if not NetworkService.peer_left.is_connected(_on_lobby_peer_left):
			NetworkService.peer_left.connect(_on_lobby_peer_left)
	else:
		lobby_roster = {}
		server_submit_lobby_profile.rpc_id(1, {
			"display_name": PlayerProfile.display_name,
			"class_id": GameRuntime.active_class_id(),
			"loadout": _get_loadout_for(GameRuntime.active_class_id()),
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
	difficulty_label.visible = false
	difficulty_row.visible = false
	class_label.visible = false
	class_grid.visible = false
	class_description.visible = false
	if world_row != null:
		world_row.visible = false
	if loadout_panel != null:
		loadout_panel.visible = false
	solo_button.visible = false
	if cpu_coop_button != null:
		cpu_coop_button.visible = false
	host_button.visible = false
	join_label.visible = false
	address_input.visible = false
	join_button.visible = false
	steam_status_label.visible = false
	if ability_panel != null:
		ability_panel.visible = false
	lobby_title_label.visible = true
	lobby_title_label.text = "Lobby"
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
		"loadout": [],
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
				"loadout": entry.get("loadout", []),
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
				"loadout": [],
				"status": "In Steam lobby",
				"host": false,
			})
	else:
		slot_entries.append({
			"name": PlayerProfile.display_name,
			"class_id": GameRuntime.active_class_id(),
			"loadout": _get_loadout_for(GameRuntime.active_class_id()),
			"status": "Setting up...",
			"host": true,
		})
	while slot_entries.size() < GameRuntime.max_players:
		slot_entries.append({"name": "Empty slot", "class_id": "", "loadout": [], "status": "", "host": false})
	for index in GameRuntime.max_players:
		var slot_data: Dictionary = slot_entries[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var hero_tex := TextureRect.new()
		hero_tex.custom_minimum_size = Vector2(40, 40)
		hero_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var hero_id := str(slot_data.class_id)
		if not hero_id.is_empty() and PlayerClass.is_valid_id(hero_id):
			hero_tex.texture = SpriteLibrary.texture_for(hero_id)
		row.add_child(hero_tex)
		var name_label := Label.new()
		var host_text := " [HOST]" if bool(slot_data.host) else ""
		var status_text := ""
		if not str(slot_data.status).is_empty():
			status_text = " (%s)" % slot_data.status
		name_label.text = "%s%s%s" % [str(slot_data.name), host_text, status_text]
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var picked: Array = slot_data.get("loadout", []) as Array
		for i in 4:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(28, 28)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if i < picked.size():
				var aid := String(picked[i])
				if not aid.is_empty() and PlayerClass.ABILITIES.has(aid):
					icon.texture = SpriteLibrary.texture_for(aid)
					icon.tooltip_text = str(PlayerClass.ABILITIES[aid].get("name", aid))
				else:
					icon.modulate = Color(0.25, 0.25, 0.3, 0.5)
			else:
				icon.modulate = Color(0.25, 0.25, 0.3, 0.5)
			row.add_child(icon)
		player_slots.add_child(row)


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
	var hero_id := PlayerClass.sanitize_id(str(profile.get("class_id", PlayerClass.DEFAULT_CLASS_ID)))
	var submitted_loadout: Array = profile.get("loadout", []) as Array
	var loadout: Array[String] = []
	for aid in _get_loadout_for(hero_id):
		loadout.append(String(aid))
	for i in mini(submitted_loadout.size(), 4):
		var aid := String(submitted_loadout[i])
		if not aid.is_empty() and PlayerClass.ABILITIES.has(aid):
			loadout[i] = aid
	lobby_roster[peer_id] = {
		"name": str(profile.get("display_name", "Player")),
		"class_id": hero_id,
		"loadout": loadout,
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
	AudioService.play("ui_click")
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
	GameRuntime.reset_biome_for_new_run()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	lobby_panel.visible = false
	backdrop.visible = false
	status_label.visible = false
	var action := $StatusLayer.get_node_or_null("ToborAction") as CanvasItem
	if action != null:
		action.visible = false


func restart_game() -> void:
	var game := get_node_or_null("Main")
	if game != null:
		game.free()
	game_loaded = false
	_open_game()


func leave_game() -> void:
	var game := get_node_or_null("Main")
	if game != null:
		game.free()
	NetworkService.stop()
	game_loaded = false
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	_show_lobby("Play as Tobor")


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
	var action := $StatusLayer.get_node_or_null("ToborAction") as CanvasItem
	if action != null:
		action.visible = true
	_set_lobby_enabled(true)
	mode_row.visible = true
	class_description.visible = true
	_refresh_game_mode()
	solo_button.visible = true
	if cpu_coop_button != null:
		cpu_coop_button.visible = not GameRuntime.is_classic()
	host_button.visible = true
	join_label.visible = true
	address_input.visible = true
	join_button.visible = true
	difficulty_label.visible = not GameRuntime.is_classic()
	difficulty_row.visible = not GameRuntime.is_classic()
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
	if cpu_coop_button != null:
		cpu_coop_button.disabled = not enabled
	host_button.disabled = not enabled or not _steam_status_known
	join_button.disabled = not enabled
	address_input.editable = enabled
	classic_button.disabled = not enabled
	pjotr_button.disabled = not enabled
	easy_button.disabled = not enabled
	normal_button.disabled = not enabled
	hard_button.disabled = not enabled
	brutal_button.disabled = not enabled
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

extends Node

const RunSave := preload("res://scripts/run_save.gd")
const AbilityPreviewScript := preload("res://scenes/bootstrap/ability_preview.gd")
const AbilityPreviewWorldScene := preload("res://scenes/bootstrap/ability_preview_world.tscn")

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
@onready var solo_toggle: Button = $StatusLayer/LobbyPanel/Margin/Layout/ModeRow/SoloToggle
@onready var coop_toggle: Button = $StatusLayer/LobbyPanel/Margin/Layout/ModeRow/CoopToggle
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
@onready var resolution_option: OptionButton = $StatusLayer/LobbyPanel/Margin/Layout/AudioRow/ResolutionOption
@onready var audio_row: HBoxContainer = $StatusLayer/LobbyPanel/Margin/Layout/AudioRow

# --- Overhaul UI (built programmatically in _ready, parented into the existing Layout) ---
var world_row: HFlowContainer = null
var loadout_panel: VBoxContainer = null
var loadout_row: HBoxContainer = null
var ability_pool: GridContainer = null
var loadout_slots: Array[Button] = []
var lmb_slot_button: Button = null
var rmb_slot_button: Button = null
## Ability index pinned open by a click (-1 = none). While pinned, mouse_exited does
## NOT close the panel, so you can keep the preview up for screenshots / testing.
var _pinned_ability_index := -1

# --- HoN-style ability description panel (lives in bootstrap.tscn) ---
@onready var ability_panel: PanelContainer = $StatusLayer/AbilityPanel
@onready var ability_hero_header: Label = $StatusLayer/AbilityPanel/Margin/Layout/HeroHeader
@onready var ability_hero_blurb: Label = $StatusLayer/AbilityPanel/Margin/Layout/HeroBlurb
@onready var ability_list: VBoxContainer = $StatusLayer/AbilityPanel/Margin/Layout/AbilityScroll/AbilityList
var ability_hover_icon: TextureRect = null
var ability_hover_body: RichTextLabel = null
var ability_preview: Node = null
var ability_preview_world: AbilityPreviewWorld = null

var _ability_panel_hero_id: String = ""
var _pending_run_save: Dictionary = {}
var roster_info_button: Button = null
var _shown_kit_ids: Array[String] = []

var game_loaded := false
var class_buttons: Array[Button] = []
var world_buttons: Array[Button] = []
var _hero_group: ButtonGroup = null
var _rebuilding_cards := false
var _hero_hover_anim: Dictionary = {}
var _hero_hover_walk: Dictionary = {}
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
var _play_mode := 0  # 0 solo, 1 ffa, 2 co-op
var _play_mode_group: ButtonGroup = null

# --- Compact menu (2026-09-16 redesign) ---
## Big hero icon + < > nav instead of full grid. 9-dot button opens roster popup.
var _hero_nav_index := 0
var _hero_nav_ids: Array[String] = []
var _hero_big_icon: TextureRect = null
var _hero_prev_btn: Button = null
var _hero_next_btn: Button = null
var _roster_dots_btn: Button = null
var _roster_popup: Control = null
## Mode < > nav: 0=Solo, 1=FFA, 2=Co-op, 3=World Editor
var _mode_nav_index := 0
var _mode_label: Label = null
var _mode_prev_btn: Button = null
var _mode_next_btn: Button = null
## Difficulty < > nav: 0=Easy,1=Normal,2=Hard,3=Brutal
var _diff_nav_index := 1
var _diff_label: Label = null
var _diff_prev_btn: Button = null
var _diff_next_btn: Button = null
## Ability strip (icons under the hero)
var _ability_strip: HBoxContainer = null
var _roster_preview_icon: TextureRect = null
## 16-hero roster grid shown in the menu (bottom-right of the panel)
var _roster_grid: GridContainer = null
## Compact top-row widgets (2026-09-17 menu redesign):
##   - hero name top-right (TOBOR), START / CONTINUE buttons, < MODE > nav
##   - difficulty < > nav below, roster + ability strip pinned to bottom-right,
##   - small wrench/gear settings button (resolution + sound) bottom-right.
var _compact_hero_name_label: Label = null
var _compact_start_btn: Button = null
var _compact_continue_btn: Button = null
var _compact_settings_btn: Button = null

## T3.71 / T3.97: animated menu background (from MP4 frame extraction).
## Generic per-hero: any hero whose class def has an "animated_menu_bg" folder
## gets a frame-based backdrop. Joule (arclight) keeps its lightning-filtered
## frames; Tobor (tobor) and Diord (warden) use every frame at 20% speed.
var _menu_frames: Array[Texture2D] = []
var _menu_frames_class := ""
var _menu_fps := 2.4  # ticks/sec; Joule 2.4, Tobor 4.8 (20% of 24fps), Diord 2.4 (half speed, T4.1)

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
	if GameRuntime.is_ffa() and GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		AudioService.play_music()
		_play_mode = 1
		print("[bootstrap] skipping menu, opening FFA")
		_open_game()
		return
	_build_overhaul_ui()
	_constrain_lobby_layout()
	_layout_ability_hover_panel()
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	_setup_play_mode_toggles()
	easy_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.EASY))
	normal_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.NORMAL))
	hard_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.HARD))
	brutal_button.pressed.connect(_on_difficulty_pressed.bind(GameRuntime.Difficulty.BRUTAL))
	_refresh_difficulty()
	_setup_menu_tooltips()
	for slot_index in loadout_slots.size():
		_decorate_slot_button(loadout_slots[slot_index] as Button)
	_apply_tobor_theme()
	_build_class_selection()
	_refresh_game_mode()
	solo_button.pressed.connect(_on_solo_pressed)
	_sync_continue_button()
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
	_build_resolution_options()
	_build_world_editor_button()
	if ability_panel != null:
		ability_panel.visible = false
		_ability_panel_hero_id = ""
	SteamService.steam_ready.connect(_on_steam_ready)
	SteamService.steam_unavailable.connect(_on_steam_unavailable)
	SteamService.join_requested.connect(_on_steam_join_requested)
	SteamService.lobby_members_changed.connect(_on_steam_lobby_members_changed)
	NetworkService.peer_joined.connect(_on_lobby_peer_joined)
	_refresh_steam_status()
	AudioService.play_music()
	# UI verify driver: attach when --ui-verify flag is present.
	if "--ui-verify" in OS.get_cmdline_args():
		call_deferred("_attach_ui_verify")
	# Joule menu video verify driver: attach when marker file exists (set by test runner).
	if FileAccess.file_exists("user://joule_menu_video_test"):
		call_deferred("_attach_joule_menu_video_verify")
	# T3.97 menu-bg verify driver (Tobor + Diord animated backdrops).
	if FileAccess.file_exists("user://menu_bg_ingame_test"):
		call_deferred("_attach_menu_bg_ingame_verify")
	# 2026-09-16 compact menu verify driver (big hero icon + < > nav + roster + mode nav).
	if FileAccess.file_exists("user://compact_menu_test"):
		call_deferred("_attach_compact_menu_test")
	call_deferred("_start_runtime")
	set_process(true)


func _attach_ui_verify() -> void:
	var driver_scene: PackedScene = load("res://tools/selftest/ui_verify/ui_verify_driver.tscn")
	if driver_scene == null:
		print("[ui-verify] driver scene not found")
		return
	var driver = driver_scene.instantiate()
	get_tree().root.add_child(driver)
	print("[ui-verify] driver attached to root (survives scene changes)")


func _attach_joule_menu_video_verify() -> void:
	var driver_scene: PackedScene = load("res://scenes/joule_menu_ingame_test/joule_menu_ingame_test.tscn")
	if driver_scene == null:
		print("[joule-video] driver scene not found")
		return
	var driver = driver_scene.instantiate()
	get_tree().root.add_child(driver)
	print("[joule-video] driver attached to root")


func _attach_menu_bg_ingame_verify() -> void:
	var driver_scene: PackedScene = load("res://scenes/menu_bg_ingame_test/menu_bg_ingame_test.tscn")
	if driver_scene == null:
		print("[menu-bg] driver scene not found")
		return
	var driver = driver_scene.instantiate()
	get_tree().root.add_child(driver)
	print("[menu-bg] driver attached to root")


func _attach_compact_menu_test() -> void:
	var driver_scene: PackedScene = load("res://scenes/compact_menu_test/compact_menu_test.tscn")
	if driver_scene == null:
		print("[compact-menu] driver scene not found")
		return
	var driver = driver_scene.instantiate()
	get_tree().root.add_child(driver)
	print("[compact-menu] driver attached to root")


## Builds the WorldRow, LoadoutPanel (LoadoutRow + AbilityPool) and wires them into the
## existing tscn Layout so the .tscn doesn't need to be rewritten. Parents them around
## the ClassGrid so the reading order is: ModeRow (Solo/Co-op) → Difficulty → Hero label →
## WorldRow → ClassGrid → HERO ABILITIES → LoadoutPanel → ClassDescription.
func _build_overhaul_ui() -> void:
	var layout := class_grid.get_parent() as VBoxContainer
	if layout == null:
		return
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Wrap WorldRow + ClassGrid + LoadoutPanel in a ScrollContainer so the growing
	# hero content scrolls instead of pushing StartGameButton (a later Layout sibling)
	# offscreen. The scroll container expands to fill leftover space, so the ModeRow
	# and StartGameButton keep their fixed slots below it.
	var hero_scroll := ScrollContainer.new()
	hero_scroll.name = "HeroContentScroll"
	hero_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_scroll.custom_minimum_size = Vector2(0, 120)
	hero_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(hero_scroll)
	layout.move_child(hero_scroll, class_grid.get_index())
	var hero_content := VBoxContainer.new()
	hero_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_content.add_theme_constant_override("separation", 6)
	hero_scroll.add_child(hero_content)
	# Reparent the hero grid into the scroll content; the `class_grid` onready ref is
	# unaffected because it points at the node, not its parent.
	class_grid.reparent(hero_content)
	class_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# WorldRow sits directly above the hero grid and wraps on narrow panels.
	world_row = HFlowContainer.new()
	world_row.name = "WorldRow"
	world_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_row.add_theme_constant_override("h_separation", 6)
	world_row.add_theme_constant_override("v_separation", 6)
	hero_content.add_child(world_row)
	hero_content.move_child(world_row, class_grid.get_index())
	# Four kit abilities sit directly under the hero grid; hover shows their info.
	loadout_panel = VBoxContainer.new()
	loadout_panel.name = "LoadoutPanel"
	loadout_panel.add_theme_constant_override("separation", 6)
	loadout_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_content.add_child(loadout_panel)
	hero_content.move_child(loadout_panel, class_grid.get_index() + 1)
	var loadout_header := Label.new()
	loadout_header.text = "Abilities"
	loadout_header.add_theme_color_override("font_color", Color("9fb3d1"))
	loadout_panel.add_child(loadout_header)
	loadout_row = HBoxContainer.new()
	loadout_row.name = "LoadoutRow"
	loadout_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout_row.add_theme_constant_override("separation", 8)
	loadout_panel.add_child(loadout_row)
	loadout_slots = []
	# LMB/RMB buttons on the left, flat with no background.
	var lmb_b := Button.new()
	lmb_b.name = "LmbSlot"
	lmb_b.toggle_mode = false
	lmb_b.custom_minimum_size = Vector2(72, 72)
	lmb_b.disabled = false
	lmb_b.focus_mode = Control.FOCUS_NONE
	lmb_b.mouse_entered.connect(_on_lmb_hover)
	lmb_b.mouse_exited.connect(_on_ability_slot_unhover)
	lmb_b.pressed.connect(_on_lmb_pressed)
	_style_lmb_rmb_button(lmb_b)
	loadout_row.add_child(lmb_b)
	var rmb_b := Button.new()
	rmb_b.name = "RmbSlot"
	rmb_b.toggle_mode = false
	rmb_b.custom_minimum_size = Vector2(72, 72)
	rmb_b.disabled = false
	rmb_b.focus_mode = Control.FOCUS_NONE
	rmb_b.mouse_entered.connect(_on_rmb_hover)
	rmb_b.mouse_exited.connect(_on_ability_slot_unhover)
	rmb_b.pressed.connect(_on_rmb_pressed)
	_style_lmb_rmb_button(rmb_b)
	loadout_row.add_child(rmb_b)
	lmb_slot_button = lmb_b
	rmb_slot_button = rmb_b
	# Slight visual gap between LMB/RMB and the 4 ability slots.
	var gap := Control.new()
	gap.name = "LoadoutGap"
	gap.custom_minimum_size = Vector2(16, 1)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loadout_row.add_child(gap)
	for slot_index in 4:
		var b := Button.new()
		b.name = "Slot%d" % (slot_index + 1)
		b.toggle_mode = false
		b.custom_minimum_size = Vector2(72, 72)
		b.disabled = false
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(_on_ability_slot_hover.bind(slot_index))
		b.mouse_exited.connect(_on_ability_slot_unhover)
		b.pressed.connect(_on_ability_slot_pressed.bind(slot_index))
		_style_ability_button(b)
		loadout_row.add_child(b)
		loadout_slots.append(b)


func _constrain_lobby_layout() -> void:
	lobby_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	lobby_panel.anchor_left = 1.0
	lobby_panel.anchor_top = 0.0
	lobby_panel.anchor_right = 1.0
	lobby_panel.anchor_bottom = 1.0
	# 2026-09-17 user rule: the whole panel is a FIXED width equal to the hero
	# roster's natural width, so picking a different hero never reflows / moves
	# the panel. Roster = 4 cols x 52px + 3 x 6px gaps = 224px; add ~24px
	# margin/padding each side -> ~272px. No content may stretch past this.
	var panel_w := 272
	lobby_panel.offset_left = -float(panel_w)
	lobby_panel.offset_top = 10.0
	lobby_panel.offset_right = -10.0
	lobby_panel.offset_bottom = -10.0
	lobby_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lobby_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	lobby_panel.clip_contents = true
	lobby_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	# Pin the panel's own width so text/labels inside can never widen it.
	lobby_panel.custom_minimum_size = Vector2(panel_w, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.border_color = Color(0.32, 0.26, 0.16, 0.0)
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(0)
	lobby_panel.add_theme_stylebox_override("panel", panel_style)
	var layout := lobby_panel.get_node_or_null("Margin/Layout") as VBoxContainer
	if layout == null:
		return
	# --- Hide old full-width UI elements (grid, mode row, etc.) ---
	class_label.visible = false
	class_grid.visible = false
	class_description.visible = false
	world_row.visible = false
	mode_row.visible = false
	title_label.visible = false
	subtitle_label.visible = false
	host_button.visible = false
	join_button.visible = false
	join_label.visible = false
	address_input.visible = false
	start_game_button.visible = false
	# Difficulty + audio rows will be re-shown and reordered in _build_compact_menu.
	# --- Build compact menu in the layout ---
	_build_compact_menu(layout)


# ============================================================================
# COMPACT MENU (2026-09-16 redesign)
#
# Layout (top to bottom in the 400px right panel):
#   [Title "RIFT SURVIVORS"]
#   [Hero nav:  <  BIG_ICON  >  ... 9-dot roster button]
#   [Mode nav:  <  SOLO  >  ...]
#   [Play button]
#   [Difficulty: 4 small toggle buttons]
#   [Audio: SFX / Music / Resolution]
#   [World Editor button]
# ============================================================================

func _build_compact_menu(layout: VBoxContainer) -> void:
	# ========================================================================
	# 2026-09-17 v2 LAYOUT — single vertical column, no side-by-side clutter.
	# Every item is its own full-width row, stacked top to bottom:
	#   [HERO NAME]     ← selected hero name (updates on roster click)
	#   [PLAY]          ← full-width button
	#   [CONTINUE]      ← full-width button (hidden when no save)
	#   [< SOLO >]      ← mode row (single row, centered)
	#   [< NORMAL >]    ← difficulty row (single row, centered)
	#   [4x4 roster]    ← 16 hero buttons (defines panel width)
	#   [⚙ Settings]    ← full-width button
	# ========================================================================

	# --- HERO NAME label (top of panel, centered) ---
	_compact_hero_name_label = Label.new()
	_compact_hero_name_label.name = "CompactHeroName"
	_compact_hero_name_label.text = "TOBOR"
	_compact_hero_name_label.add_theme_font_size_override("font_size", 22)
	_compact_hero_name_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3, 1.0))
	_compact_hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compact_hero_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_compact_hero_name_label)

	# --- PLAY button (full width) ---
	_compact_start_btn = Button.new()
	_compact_start_btn.name = "CompactStartBtn"
	_compact_start_btn.text = "PLAY"
	_compact_start_btn.custom_minimum_size = Vector2(0, 48)
	_compact_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_start_btn.add_theme_font_size_override("font_size", 18)
	_compact_start_btn.focus_mode = Control.FOCUS_NONE
	_compact_start_btn.pressed.connect(_on_solo_pressed)
	_style_action_button(_compact_start_btn)
	layout.add_child(_compact_start_btn)

	# --- CONTINUE button (full width, hidden when no save) ---
	_compact_continue_btn = Button.new()
	_compact_continue_btn.name = "CompactContinueBtn"
	_compact_continue_btn.text = "CONTINUE"
	_compact_continue_btn.custom_minimum_size = Vector2(0, 44)
	_compact_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_continue_btn.add_theme_font_size_override("font_size", 15)
	_compact_continue_btn.focus_mode = Control.FOCUS_NONE
	_compact_continue_btn.pressed.connect(_on_continue_pressed)
	_compact_continue_btn.visible = false
	_style_action_button(_compact_continue_btn)
	layout.add_child(_compact_continue_btn)

	# --- MODE row: < SOLO > (full width, centered) ---
	var mode_row := HBoxContainer.new()
	mode_row.name = "CompactModeRow"
	mode_row.add_theme_constant_override("separation", 6)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(mode_row)
	_mode_prev_btn = _make_nav_btn("<", 40)
	_mode_prev_btn.pressed.connect(_cycle_mode.bind(-1))
	mode_row.add_child(_mode_prev_btn)
	_mode_label = Label.new()
	_mode_label.text = "SOLO"
	_mode_label.add_theme_font_size_override("font_size", 16)
	_mode_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	_mode_label.custom_minimum_size = Vector2(120, 0)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_nav_label_bg(_mode_label)
	mode_row.add_child(_mode_label)
	_mode_next_btn = _make_nav_btn(">", 40)
	_mode_next_btn.pressed.connect(_cycle_mode.bind(1))
	mode_row.add_child(_mode_next_btn)

	# --- DIFFICULTY row: < NORMAL > (full width, centered) ---
	var diff_row := HBoxContainer.new()
	diff_row.name = "CompactDiffRow"
	diff_row.add_theme_constant_override("separation", 6)
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(diff_row)
	_diff_prev_btn = _make_nav_btn("<", 40)
	_diff_prev_btn.pressed.connect(_cycle_diff.bind(-1))
	diff_row.add_child(_diff_prev_btn)
	_diff_label = Label.new()
	_diff_label.text = "NORMAL"
	_diff_label.add_theme_font_size_override("font_size", 16)
	_diff_label.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0, 1.0))
	_diff_label.custom_minimum_size = Vector2(120, 0)
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_nav_label_bg(_diff_label)
	diff_row.add_child(_diff_label)
	_diff_next_btn = _make_nav_btn(">", 40)
	_diff_next_btn.pressed.connect(_cycle_diff.bind(1))
	diff_row.add_child(_diff_next_btn)

	# --- 16-hero roster grid (4x4) — defines the panel width ---
	_roster_grid = GridContainer.new()
	_roster_grid.name = "CompactRosterGrid"
	_roster_grid.columns = 4
	_roster_grid.add_theme_constant_override("h_separation", 6)
	_roster_grid.add_theme_constant_override("v_separation", 6)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_roster_grid)
	_populate_roster_grid()

	# --- SETTINGS button (full width) ---
	_compact_settings_btn = Button.new()
	_compact_settings_btn.name = "CompactSettingsBtn"
	_compact_settings_btn.text = "⚙  SETTINGS"
	_compact_settings_btn.custom_minimum_size = Vector2(0, 44)
	_compact_settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_settings_btn.add_theme_font_size_override("font_size", 15)
	_compact_settings_btn.focus_mode = Control.FOCUS_NONE
	_compact_settings_btn.tooltip_text = "Settings: Resolution & Sound"
	_compact_settings_btn.pressed.connect(_on_compact_settings_pressed)
	_style_action_button(_compact_settings_btn)
	layout.add_child(_compact_settings_btn)

	# --- Hide old UI elements ---
	title_label.visible = false
	difficulty_row.visible = false
	difficulty_label.visible = false
	mode_row.visible = false
	solo_button.visible = false
	# The old 4-big-button "Abilities" loadout panel is replaced by the compact
	# ability strip (LMB/RMB + 4 small icons) under the roster — keep it hidden.
	if loadout_panel != null:
		loadout_panel.visible = false
		if class_description != null:
			class_description.visible = false

	# Hide old audio row (moved behind settings button)
	if audio_row != null:
		audio_row.visible = false

	# --- Steam status ---
	if steam_status_label != null:
		steam_status_label.visible = true
		layout.move_child(steam_status_label, layout.get_child_count())

	# Sync the continue button visibility
	_sync_compact_continue()

	# Initialize nav
	_init_hero_nav()
	_init_mode_nav()
	_init_diff_nav()


## Shared background style for all action/nav buttons in the compact menu.
func _style_action_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	normal.border_color = Color(0.3, 0.35, 0.5, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.95)
	hover.border_color = Color(0.5, 0.6, 0.8, 0.8)
	hover.set_border_width_all(1)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	pressed.border_color = Color(0.4, 0.45, 0.6, 0.7)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color("f4f0e6"))


## Shared background for the mode/difficulty nav labels (looks like a button slot).
func _style_nav_label_bg(lbl: Label) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18, 0.8)
	sb.border_color = Color(0.25, 0.3, 0.45, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	lbl.add_theme_stylebox_override("normal", sb)


## Show/hide the compact Continue button based on save existence.
func _sync_compact_continue() -> void:
	if _compact_continue_btn != null:
		_compact_continue_btn.visible = RunSave.has_save()


## Called when the settings (wrench) button is pressed — toggle audio row.
func _on_compact_settings_pressed() -> void:
	AudioService.play("ui_click")
	if audio_row == null:
		return
	# Toggle visibility of the audio row; insert it right above the settings row.
	var layout := lobby_panel.get_node_or_null("Margin/Layout") as VBoxContainer
	if layout == null:
		return
	if audio_row.visible:
		audio_row.visible = false
	else:
		audio_row.visible = true
		# Move audio row to just before the settings row
		var settings_row := layout.get_node_or_null("CompactSettingsRow")
		if settings_row != null:
			layout.move_child(audio_row, settings_row.get_index())
		else:
			layout.add_child(audio_row)


func _make_nav_btn(txt: String, min_h: float = 84) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(40, min_h)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 1.0))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _init_hero_nav() -> void:
	_hero_nav_ids = ids_in_world(selected_world)
	if _hero_nav_ids.is_empty():
		_hero_nav_ids = ["tobor"]
	var sel := PlayerProfile.selected_class_id
	_hero_nav_index = _hero_nav_ids.find(sel)
	if _hero_nav_index < 0:
		_hero_nav_index = 0
	_sync_hero_nav()


func _sync_hero_nav() -> void:
	if _hero_nav_index >= _hero_nav_ids.size():
		_hero_nav_index = 0
	if _hero_nav_index < 0:
		_hero_nav_index = 0
	var hero_id: String = _hero_nav_ids[_hero_nav_index]
	if _hero_big_icon != null:
		var tex := SpriteLibrary.texture_for(hero_id)
		if tex != null:
			_hero_big_icon.texture = tex
	# Update the compact top-right hero name label (2026-09-17 redesign).
	if _compact_hero_name_label != null:
		var _cls: Dictionary = PlayerClass.by_id(hero_id)
		_compact_hero_name_label.text = str(_cls.get("name", hero_id)).to_upper()
	# Sync with the existing class selection system.
	PlayerProfile.select_class(hero_id)
	_updating_class_ui = true
	for index in class_buttons.size():
		var nav_id := _hero_nav_ids[index] if index < _hero_nav_ids.size() else ""
		class_buttons[index].button_pressed = (nav_id == hero_id)
	_updating_class_ui = false
	_refresh_loadout_panel()
	_apply_hero_backdrop()
	_refresh_header_detail(hero_id)
	_populate_ability_strip(hero_id)
	_update_roster_selection()


## Highlight the currently-selected hero in the always-visible roster grid.
func _update_roster_selection() -> void:
	if _roster_grid == null:
		return
	var sel := _hero_nav_ids[_hero_nav_index] if _hero_nav_index < _hero_nav_ids.size() else ""
	for child in _roster_grid.get_children():
		if child is Button:
			var hid := String(child.name).trim_prefix("RosterBtn_")
			_set_roster_btn_selected(child, hid == sel)


## Ability strip: LMB, RMB + 4 ability buttons under the hero roster.
## Each shows the ability icon; hover shows the panel; click pins the panel open.
## Styled to match the main loadout-panel ability buttons (_style_ability_button).
func _populate_ability_strip(hero_id: String) -> void:
	if _ability_strip == null:
		return
	for child in _ability_strip.get_children():
		child.queue_free()
	# LMB button (primary attack). Icon illustrates the LMB attack (the
	# "spark" projectile the hero actually fires), NOT the hero portrait.
	var lmb_btn := Button.new()
	lmb_btn.name = "LmbBtn"
	lmb_btn.custom_minimum_size = Vector2(48, 48)
	var lmb_proj_icon := SpriteLibrary.texture_for("spark")
	lmb_btn.icon = lmb_proj_icon if lmb_proj_icon != null else SpriteLibrary.texture_for("secondary_repulse")
	lmb_btn.add_theme_constant_override("icon_max_width", 40)
	lmb_btn.add_theme_constant_override("icon_max_height", 40)
	lmb_btn.tooltip_text = "LMB — " + _lmb_tooltip(hero_id)
	lmb_btn.focus_mode = Control.FOCUS_NONE
	_style_ability_button(lmb_btn)
	_add_slot_tag(lmb_btn, "LMB")
	lmb_btn.mouse_entered.connect(_on_lmb_hover)
	lmb_btn.mouse_exited.connect(_hide_ability_hover)
	lmb_btn.pressed.connect(_on_lmb_pressed)
	_ability_strip.add_child(lmb_btn)
	# RMB button (secondary attack)
	var rmb_btn := Button.new()
	rmb_btn.name = "RmbBtn"
	rmb_btn.custom_minimum_size = Vector2(48, 48)
	var sec_kind := str(PlayerClass.by_id(hero_id).get("secondary", "repulse"))
	rmb_btn.icon = SpriteLibrary.texture_for("secondary_" + sec_kind)
	if rmb_btn.icon == null:
		rmb_btn.icon = SpriteLibrary.texture_for("secondary_repulse")
	rmb_btn.add_theme_constant_override("icon_max_width", 40)
	rmb_btn.add_theme_constant_override("icon_max_height", 40)
	rmb_btn.tooltip_text = "RMB — " + str(PlayerClass.secondary_info_for_class(hero_id).get("name", "Secondary"))
	rmb_btn.focus_mode = Control.FOCUS_NONE
	_style_ability_button(rmb_btn)
	_add_slot_tag(rmb_btn, "RMB")
	rmb_btn.mouse_entered.connect(_on_rmb_hover)
	rmb_btn.mouse_exited.connect(_hide_ability_hover)
	rmb_btn.pressed.connect(_on_rmb_pressed)
	_ability_strip.add_child(rmb_btn)
	# Q/E/R + 4th ability buttons
	var ids := _hero_ability_ids(hero_id)
	for i in mini(ids.size(), 4):
		var ability_id: String = ids[i]
		if ability_id.is_empty():
			continue
		var btn := Button.new()
		btn.name = "AbilityBtn%d" % i
		btn.custom_minimum_size = Vector2(48, 48)
		btn.icon = SpriteLibrary.texture_for(ability_id)
		btn.add_theme_constant_override("icon_max_width", 40)
		btn.add_theme_constant_override("icon_max_height", 40)
		btn.tooltip_text = str(PlayerClass.ABILITIES.get(ability_id, {}).get("name", ability_id))
		btn.focus_mode = Control.FOCUS_NONE
		var aid := ability_id
		btn.mouse_entered.connect(_on_ability_strip_hover.bind(aid))
		btn.mouse_exited.connect(_hide_ability_hover)
		btn.pressed.connect(_on_ability_strip_pressed.bind(aid))
		_ability_strip.add_child(btn)


func _on_ability_strip_hover(ability_id: String) -> void:
	_show_ability_hover(ability_id)


## Click an ability button: just (re)show the hover panel for that ability.
## The panel is hover-driven only — it closes when the mouse leaves the button.
func _on_ability_strip_pressed(ability_id: String) -> void:
	_show_ability_hover(ability_id)


func _cycle_hero(direction: int) -> void:
	AudioService.play("ui_click")
	_hero_nav_index = wrapf(_hero_nav_index + direction, 0, _hero_nav_ids.size())
	_sync_hero_nav()


func _init_mode_nav() -> void:
	_mode_nav_index = _play_mode  # 0=solo, 1=ffa, 2=coop, 3=world editor
	_sync_mode_nav()


func _sync_mode_nav() -> void:
	if _mode_label == null:
		return
	match _mode_nav_index:
		0: _mode_label.text = "SOLO"
		1: _mode_label.text = "FFA"
		2: _mode_label.text = "CO-OP"
		3: _mode_label.text = "WORLD EDITOR"
		_: _mode_label.text = "SOLO"
	# World editor is not a play mode — it just opens the editor when PLAY is pressed.
	if _mode_nav_index == 3:
		_play_mode = 0  # keep solo as the underlying play mode
	else:
		_play_mode = _mode_nav_index
	_refresh_play_mode()


func _cycle_mode(direction: int) -> void:
	AudioService.play("ui_click")
	_mode_nav_index = wrapf(_mode_nav_index + direction, 0, 4)
	_sync_mode_nav()


# --- Difficulty < > nav ---
const _DIFF_NAMES := ["EASY", "NORMAL", "HARD", "BRUTAL"]
const _DIFF_VALUES := [GameRuntime.Difficulty.EASY, GameRuntime.Difficulty.NORMAL, GameRuntime.Difficulty.HARD, GameRuntime.Difficulty.BRUTAL]

func _init_diff_nav() -> void:
	# Find current difficulty (default NORMAL)
	_diff_nav_index = _DIFF_VALUES.find(GameRuntime.difficulty)
	if _diff_nav_index < 0:
		_diff_nav_index = 1
	_sync_diff_nav()


func _sync_diff_nav() -> void:
	if _diff_label == null:
		return
	_diff_label.text = _DIFF_NAMES[_diff_nav_index]
	GameRuntime.set_difficulty(_DIFF_VALUES[_diff_nav_index])


func _cycle_diff(direction: int) -> void:
	AudioService.play("ui_click")
	_diff_nav_index = wrapf(_diff_nav_index + direction, 0, 4)
	_sync_diff_nav()


func _on_hero_big_icon_hover() -> void:
	# Hover on the big icon shows the ability panel (same as clicking a hero card).
	_show_ability_panel_for_selected_hero()


func _on_big_icon_hover_enter() -> void:
	# Hover-only: show the selected hero's description + stats.
	var hero_id := _hero_nav_ids[_hero_nav_index] if _hero_nav_index < _hero_nav_ids.size() else ""
	if hero_id != "":
		_show_hero_description_hover(hero_id)


func _on_big_icon_hover_exit() -> void:
	# Hover-only: hide the panel when the mouse leaves the big icon.
	_hide_ability_hover()


func _show_ability_panel_for_selected_hero() -> void:
	var hero_id := ""
	if _hero_nav_index < _hero_nav_ids.size():
		hero_id = _hero_nav_ids[_hero_nav_index]
	if hero_id == "" or hero_id == _ability_panel_hero_id:
		return
	_ability_panel_hero_id = hero_id
	if ability_panel != null:
		ability_panel.visible = true
		var cls: Dictionary = PlayerClass.by_id(hero_id)
		ability_hero_header.text = str(cls.get("name", hero_id))
		ability_hero_blurb.text = str(cls.get("blurb", cls.get("description", "")))
		_populate_ability_panel(hero_id)
	else:
		var abilities: Array = _hero_ability_ids(hero_id)
		if abilities.size() > 0:
			_show_ability_hover(str(abilities[0]))


## Populates the always-visible 12-hero roster grid in the compact menu.
## 4 columns x 3 rows = 12 hero sprite buttons. Hover animates the sprite
## (walk-in-place) and previews it in the big hero icon. Click selects.
func _populate_roster_grid() -> void:
	if _roster_grid == null:
		return
	for child in _roster_grid.get_children():
		child.queue_free()
	var all_heroes: Array[String] = []
	for world_idx in 3:
		all_heroes.append_array(ids_in_world(world_idx))
	var seen := {}
	var heroes: Array[String] = []
	for hid in all_heroes:
		if not seen.has(hid):
			seen[hid] = true
			heroes.append(hid)
	if heroes.size() > 16:
		heroes = heroes.slice(0, 16)
	for hero_id in heroes:
		var btn := Button.new()
		btn.name = "RosterBtn_%s" % hero_id
		btn.custom_minimum_size = Vector2(52, 52)
		btn.icon = SpriteLibrary.texture_for(hero_id)
		btn.add_theme_constant_override("icon_max_width", 44)
		btn.add_theme_constant_override("icon_max_height", 44)
		btn.tooltip_text = str(PlayerClass.by_id(hero_id).name)
		btn.text = ""
		btn.focus_mode = Control.FOCUS_NONE
		var aid := hero_id
		btn.mouse_entered.connect(_on_roster_hover.bind(aid))
		btn.mouse_exited.connect(_on_roster_hover_exit.bind(btn, aid))
		btn.pressed.connect(_on_roster_hero_pressed.bind(aid))
		_roster_grid.add_child(btn)
		# Register for hover walk animation (animated on mouse over by default).
		_bind_roster_hover_animation(btn, hero_id)
		# Highlight the currently selected hero.
		if _hero_nav_index < _hero_nav_ids.size() and hero_id == _hero_nav_ids[_hero_nav_index]:
			_set_roster_btn_selected(btn, true)


## Highlight / un-highlight a roster button to show the selected hero.
func _set_roster_btn_selected(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.9, 0.75, 0.3, 0.35)
		style.border_color = Color(1.0, 0.85, 0.4, 1.0)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.08, 0.09, 0.13, 0.4)
		style.border_color = Color(0.25, 0.3, 0.4, 0.5)
		style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)


## Hover a roster sprite -> preview it in the big hero icon AND show the hero's
## full description + stats in the ability panel (hover-only: hides on exit).
func _on_roster_hover(hero_id: String) -> void:
	if _hero_big_icon != null:
		var tex := SpriteLibrary.texture_for(hero_id)
		if tex != null:
			_hero_big_icon.texture = tex
	_show_hero_description_hover(hero_id)

## Leave a roster sprite -> revert the big hero icon to the selected hero and
## hide the hover panel (unless the mouse has moved onto the panel itself).
func _on_roster_hover_exit(btn: Button, hero_id: String) -> void:
	if _hero_big_icon != null and hero_id != PlayerProfile.selected_class_id:
		var front := SpriteLibrary.texture_for(PlayerProfile.selected_class_id)
		if front != null:
			_hero_big_icon.texture = front
	_hide_ability_hover()


## Show the hovered hero's description + stats in the ability panel (hover-only).
func _show_hero_description_hover(hero_id: String) -> void:
	if ability_panel == null or ability_hero_header == null:
		return
	var cls: Dictionary = PlayerClass.by_id(hero_id)
	_ability_panel_hero_id = hero_id
	# Header: hero name + role
	ability_hero_header.text = ("%s  ·  %s" % [
		str(cls.get("name", hero_id)).to_upper(),
		str(cls.get("role", "Hero")).to_upper()
	])
	# Body: full description + stat block
	if ability_hover_body != null:
		ability_hover_body.visible = true
		ability_hover_body.text = _hero_description_body(hero_id)
	# Show the hero's own sprite as the panel icon.
	if ability_hover_icon != null:
		ability_hover_icon.texture = SpriteLibrary.texture_for(hero_id)
		ability_hover_icon.visible = true
	# No ability preview for a hero-description hover.
	if ability_preview != null:
		ability_preview.visible = false
	ability_panel.visible = true
	_raise_ability_hover()


## Full substituted hero description + stats block for the panel body.
func _hero_description_body(hero_id: String) -> String:
	var cls: Dictionary = PlayerClass.by_id(hero_id)
	var desc := str(cls.get("description", ""))
	var rng := "Melee" if int(cls.get("attack_range", 0)) <= 150 else "Ranged (%d px)" % int(cls.get("attack_range", 0))
	var lines: Array[String] = ["[color=#f4f0e6]%s[/color]" % desc]
	var stats: Array[String] = [
		"HP %d" % int(cls.get("max_health", 0)),
		"%s" % rng,
		"DMG %d" % int(cls.get("weapon_damage", 0)),
		"CD %.1fs" % float(cls.get("attack_interval", 0)),
	]
	lines.append("[color=9fb3d1]%s[/color]" % "  |  ".join(stats))
	return "\n".join(lines)


## Bind a roster button to animate its own sprite on hover (walk-in-place).
## Reuses the _hero_hover_walk system so each button cycles through
## front/right/back/left frames while the mouse is over it.
func _bind_roster_hover_animation(btn: Button, hero_id: String) -> void:
	# Build the 4-frame walk cycle.
	var frames: Array = []
	var front := SpriteLibrary.texture_for(hero_id)
	if front == null:
		return
	for facing in ["", "right", "back", "left"]:
		var tex: Texture2D = front
		if facing != "":
			var dir_tex := SpriteLibrary.texture_for("%s_%s" % [hero_id, facing])
			if dir_tex != null:
				tex = dir_tex
		frames.append(tex)
	# Only register if we have more than 1 distinct frame (else static is fine).
	var unique_frames := _distinct_frames(frames)
	if unique_frames.size() < 2:
		return
	_hero_hover_walk[btn] = {
		"frames": frames,
		"frame": 0,
		"t": 0.0,
		"interval": 0.22,
		"base_icon": front,
		"active": false,
	}
	btn.mouse_entered.connect(_on_hero_card_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_hero_card_hover.bind(btn, false))


## Return the unique textures in `frames` (first-occurrence order), dropping nulls.
func _distinct_frames(frames: Array) -> Array:
	var seen := {}
	var out: Array = []
	for t in frames:
		if t == null:
			continue
		var key := str(t.resource_path) if t != null and "resource_path" in t else str(t)
		if not seen.has(key):
			seen[key] = true
			out.append(t)
	return out


func _on_roster_hero_pressed(hero_id: String) -> void:
	AudioService.play("ui_click")
	# Find this hero in the current world's nav list.
	var idx := _hero_nav_ids.find(hero_id)
	if idx >= 0:
		_hero_nav_index = idx
	# If hero is in another world, switch world.
	else:
		for w in 3:
			var ids := ids_in_world(w)
			idx = ids.find(hero_id)
			if idx >= 0:
				selected_world = w
				_hero_nav_ids = ids
				_hero_nav_index = idx
				break
	_sync_hero_nav()


func _start_runtime() -> void:
	match GameRuntime.mode:
		GameRuntime.RuntimeMode.OFFLINE:
			if GameRuntime.is_ffa():
				_play_mode = 1
				_refresh_play_mode()
				call_deferred("_open_game")
			elif GameRuntime.pending_steam_lobby_id != 0:
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
	_tick_menu_video(delta)
	_process_hero_hover_walk(delta)
	_update_preview_viewport()
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
	if subtitle_label != null:
		subtitle_label.visible = false
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
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 0.0
	art.offset_top = 0.0
	art.offset_right = 0.0
	art.offset_bottom = 0.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(art)
	layer.move_child(art, backdrop.get_index() + 1)
	_raise_ability_hover()
	return art


func _backdrop_right_offset() -> float:
	var vp_w := get_viewport().get_visible_rect().size.x
	return float(clampi(int(vp_w * 0.36), 500, 1000))


func _apply_hero_backdrop() -> void:
	var art := _hero_backdrop()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.offset_right = 0.0
	var class_id := PlayerProfile.selected_class_id
	var class_data := PlayerClass.by_id(class_id)
	var anim_folder := str(class_data.get("animated_menu_bg", ""))
	# Any hero with an "animated_menu_bg" folder gets a frame-based animated
	# backdrop; everything else falls back to the static menu_bg texture.
	if anim_folder != "":
		var frames := _load_menu_frames(class_id)
		if not frames.is_empty():
			_menu_frames = frames
			_menu_frames_class = class_id
			# Tobor plays at ~20% of the source 24fps (4.8 fps). Joule keeps its
			# lightning-filtered frames at 2.4 fps (its own tuned loop).
			# T4.1 (2026-09-15): Diord (warden) bg runs at half speed = 2.4 fps.
			if class_id == "arclight":
				_menu_fps = 2.4
			elif class_id == "warden":
				_menu_fps = 2.4
			else:
				_menu_fps = 4.8
			_menu_video_active = true
			_menu_direction = 1
			# Warden starts at the sub-range start so the framing is centered.
			_menu_frame_index = _WARDEN_LOOP_START if class_id == "warden" else 0
			art.texture = frames[_menu_frame_index]
			# Pin the backdrop in place — no positional drift (T4.2 revised).
			art.offset_top = 0.0
			art.offset_bottom = 0.0
			art.offset_left = 0.0
			art.offset_right = 0.0
			art.visible = true
			_raise_ability_hover()
			return
	# Static backdrop for heroes without an animated bg (or if frames failed).
	_menu_video_active = false
	_menu_frames = []
	art.texture = SpriteLibrary.menu_backdrop_for(class_id)
	art.visible = true
	_raise_ability_hover()


## Generic animated-menu-background frame loader.
## For "arclight" (Joule): keeps ONLY the lightning frames (see _load_joule_menu_frames).
## For other heroes (tobor, warden/Diord): loads every frame in the folder.
func _load_menu_frames(class_id: String) -> Array[Texture2D]:
	if class_id == "arclight":
		return _load_joule_menu_frames()
	# Generic: load every frame_*.png in the class's animated_menu_bg folder.
	var folder := str(PlayerClass.by_id(class_id).get("animated_menu_bg", ""))
	if folder == "":
		return []
	var out: Array[Texture2D] = []
	var i := 0
	while true:
		var path := "%s/frame_%03d.png" % [folder, i + 1]
		if not ResourceLoader.exists(path):
			break
		var tex := load(path) as Texture2D
		if tex != null:
			out.append(tex)
		i += 1
		if i >= 256:  # safety cap
			break
	return out


func _load_joule_menu_frames() -> Array[Texture2D]:
	# Keep ONLY the frames that actually show a lightning bolt / electric arc in
	# the sky. Deterministic pixel classification (tools/classify_joule_frames.py)
	# marks the calm, no-lightning frames: 1, 4, 13, 14, 27, 28, 29. Everything
	# else (2,3,5-12,15-26) shows a bolt and is kept.
	# Index is 0-based; frame N is keep[N-1].
	var keep := [
		false,  # frame 1
		true,   # frame 2
		true,   # frame 3
		false,  # frame 4
		true,   # frame 5
		true,   # frame 6
		true,   # frame 7
		true,   # frame 8
		true,   # frame 9
		true,   # frame 10
		true,   # frame 11
		true,   # frame 12
		false,  # frame 13
		false,  # frame 14
		true,   # frame 15
		true,   # frame 16
		true,   # frame 17
		true,   # frame 18
		true,   # frame 19
		true,   # frame 20
		true,   # frame 21
		true,   # frame 22
		true,   # frame 23
		true,   # frame 24
		true,   # frame 25
		true,   # frame 26
		false,  # frame 27
		false,  # frame 28
		false,  # frame 29
	]
	var out: Array[Texture2D] = []
	for i in range(keep.size()):
		if not keep[i]:
			continue
		var path := "res://assets/ui/joule_menu_video/frames/frame_%03d.png" % (i + 1)
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex != null:
			out.append(tex)
	return out


## Generic tick for the active hero's animated menu background.
var _menu_video_active := false
var _menu_frame_index := 0
var _menu_frame_timer := 0.0
var _menu_direction := 1


func _menu_set_frame(index: int) -> void:
	var art := _hero_backdrop()
	if art != null and not _menu_frames.is_empty():
		art.texture = _menu_frames[clampi(index, 0, _menu_frames.size() - 1)]


## T4.2 v2 (2026-09-15, revised per user): Diord (warden) menu bg should sit in ONE
## place (no forward/back drift, no zoom) and simply loop a SHORT sub-range of frames.
## The full 49-frame source pans/zooms across the whole totem; instead we loop a
## short, centered segment so the framing stays fixed and the animation reads as a
## calm, repeating beat. Range: frames 18..34 (0-based 17..33), a centered medium
## shot where the totem stays roughly in the same place.
const _WARDEN_LOOP_START := 17   # 0-based start frame (frame 18)
const _WARDEN_LOOP_END := 33     # 0-based end frame (frame 34), inclusive

func _tick_menu_video(delta: float) -> void:
	if not _menu_video_active or _menu_frames.is_empty():
		return
	_menu_frame_timer += delta
	if _menu_frame_timer >= 1.0 / _menu_fps:
		_menu_frame_timer = 0.0
		_menu_frame_index += _menu_direction
		# Determine the effective loop range: warden uses a fixed sub-range so the
		# framing stays put; everyone else loops all frames.
		var lo: int = 0
		var hi: int = _menu_frames.size() - 1
		if _menu_frames_class == "warden":
			lo = _WARDEN_LOOP_START
			hi = mini(_WARDEN_LOOP_END, _menu_frames.size() - 1)
		# Ping-pong within [lo, hi].
		if _menu_frame_index > hi:
			_menu_frame_index = hi - 1
			_menu_direction = -1
		elif _menu_frame_index < lo:
			_menu_frame_index = lo + 1
			_menu_direction = 1
		_menu_set_frame(_menu_frame_index)
	# Keep the warden backdrop pinned in place (no vertical drift).
	if _menu_frames_class == "warden":
		var art := _hero_backdrop()
		if art != null:
			art.offset_top = 0.0


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
		tab.custom_minimum_size = Vector2(210, 32)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
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
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_constant_override("line_spacing", 0)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.icon = SpriteLibrary.texture_for(hero_id)
		button.add_theme_constant_override("icon_max_width", 40)
		button.text = "%s\n%s" % [str(class_data.name).to_upper(), str(class_data.role).to_upper()]
		button.add_theme_color_override("font_color", Color(str(class_data.accent_color)))
		button.toggled.connect(_on_class_toggled.bind(hero_id))
		if _is_hero_unlocked(hero_id):
			_bind_hero_hover_animation(button, hero_id)
		class_grid.add_child(button)
		class_buttons.append(button)
		_style_hero_card(button, class_data)
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


func _bind_hero_hover_animation(button: Button, hero_id: String) -> void:
	# Build the walk-in-place frame set: front, right, back, left facings.
	# Each facing falls back to the front sprite when the directional PNG is absent.
	var frames: Array[Texture2D] = []
	var front := SpriteLibrary.texture_for(hero_id)
	for facing_name in ["", "right", "back", "left"]:
		var tex: Texture2D = front
		if facing_name != "":
			var dir_tex := SpriteLibrary.texture_for("%s_%s" % [hero_id, facing_name])
			if dir_tex != null:
				tex = dir_tex
		frames.append(tex)
	var walk: Dictionary = {
		"frames": frames,
		"frame": 0,
		"t": 0.0,
		"interval": 0.28,
		"base_icon": front,
		"active": false,
	}
	_hero_hover_walk[button] = walk
	button.mouse_entered.connect(_on_hero_card_hover.bind(button, true))
	button.mouse_exited.connect(_on_hero_card_hover.bind(button, false))


func _process_hero_hover_walk(delta: float) -> void:
	if _hero_hover_walk.is_empty():
		return
	for button in _hero_hover_walk.keys():
		var walk: Dictionary = _hero_hover_walk[button]
		# Animate ONLY on hover — not when selected (user request: static when selected).
		if not bool(walk.get("active", false)):
			continue
		var t: float = float(walk["t"]) + delta
		if t >= float(walk["interval"]):
			t = 0.0
			var next_frame: int = int(walk["frame"]) + 1
			var frames: Array = walk["frames"]
			if next_frame >= frames.size():
				if int(walk["frame"]) == 0:
					next_frame = 1
				else:
					next_frame = 0
			walk["frame"] = next_frame
			(button as Button).icon = frames[next_frame]
		walk["t"] = t
	for key in _hero_hover_walk.keys():
		if not is_instance_valid(key):
			_hero_hover_walk.erase(key)


func _on_hero_card_hover(button: Button, entering: bool) -> void:
	var walk: Dictionary = _hero_hover_walk.get(button, {})
	if walk.is_empty():
		return
	walk["active"] = entering
	walk["t"] = 0.0
	walk["frame"] = 0
	if entering:
		(button as Button).icon = (walk["frames"] as Array)[0]
	else:
		(button as Button).icon = walk["base_icon"]


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
	_refresh_class_selection()


func _setup_play_mode_toggles() -> void:
	_play_mode_group = ButtonGroup.new()
	_play_mode_group.allow_unpress = false
	solo_toggle.toggle_mode = true
	coop_toggle.toggle_mode = true
	tobor_world_button.toggle_mode = true
	solo_toggle.button_group = _play_mode_group
	tobor_world_button.button_group = _play_mode_group
	coop_toggle.button_group = _play_mode_group
	solo_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tobor_world_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coop_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tobor_world_button.visible = true
	tobor_world_button.text = "FFA"
	tobor_world_button.custom_minimum_size = Vector2(0, 36)
	mode_row.move_child(tobor_world_button, 1)
	solo_toggle.toggled.connect(_on_play_mode_toggled.bind(0))
	tobor_world_button.toggled.connect(_on_play_mode_toggled.bind(1))
	coop_toggle.toggled.connect(_on_play_mode_toggled.bind(2))
	if GameRuntime.is_ffa():
		_play_mode = 1
		tobor_world_button.set_pressed_no_signal(true)
	else:
		solo_toggle.set_pressed_no_signal(true)


func _on_play_mode_toggled(is_pressed: bool, mode: int) -> void:
	if not is_pressed or _play_mode == mode:
		return
	AudioService.play("ui_click")
	_play_mode = mode
	GameRuntime.fill_cpu_allies = mode == 1
	if mode == 1:
		GameRuntime.set_team_mode(GameRuntime.TeamMode.FFA)
	else:
		GameRuntime.ffa_all_bots = false
		GameRuntime.set_team_mode(GameRuntime.TeamMode.NONE)
	_refresh_play_mode()


func _refresh_play_mode() -> void:
	if solo_toggle != null:
		solo_toggle.set_pressed_no_signal(_play_mode == 0)
	if tobor_world_button != null:
		tobor_world_button.set_pressed_no_signal(_play_mode == 1)
	if coop_toggle != null:
		coop_toggle.set_pressed_no_signal(_play_mode == 2)
	if _in_network_lobby:
		return
	var coop := _play_mode == 2
	var ffa := _play_mode == 1
	solo_button.visible = not coop
	solo_button.text = "PLAY FFA" if ffa else "PLAY"
	host_button.visible = coop
	join_button.visible = coop
	join_label.visible = coop
	address_input.visible = coop
	steam_status_label.visible = coop
	if cpu_coop_button != null:
		cpu_coop_button.visible = false
	# Keep the co-op setup screen on the hero picker + Host/Join. The four empty
	# lobby slots only appear after a real network lobby exists.
	lobby_title_label.visible = false
	player_slots.visible = false
	lobby_action_row.visible = false
	invite_button.visible = false
	start_game_button.visible = false
	waiting_label.visible = false
	leave_lobby_button.visible = false
	cancel_create_button.visible = false


func _refresh_game_mode() -> void:
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	if _in_network_lobby:
		return
	# 2026-09-16 compact menu: hero/mode selection now uses the compact < > nav.
	# The old grid-based rows stay hidden; the compact rows are already visible.
	if world_row != null:
		world_row.visible = false
	class_label.visible = false
	class_grid.visible = false
	mode_row.visible = false
	# 2026-09-16: compact menu uses the < > difficulty slide nav, not the
	# 4-button difficulty row — keep the old row hidden so it doesn't reappear.
	# 2026-09-17: the compact ability strip under the roster replaces the old
	# 4-big-button loadout panel, so keep loadout_panel hidden in the compact menu.
	if loadout_panel != null:
		loadout_panel.visible = false
	if roster_info_button != null and roster_info_button.get_parent() != null:
		roster_info_button.get_parent().visible = false
	difficulty_label.visible = false
	difficulty_row.visible = false
	if cpu_coop_button != null:
		cpu_coop_button.visible = false
	_refresh_class_selection()
	_refresh_play_mode()


func _on_difficulty_pressed(next_difficulty: GameRuntime.Difficulty) -> void:
	AudioService.play("ui_click")
	GameRuntime.set_difficulty(next_difficulty)
	_refresh_difficulty()


## Hover explanations for the difficulty + game-mode rows. Godot's Button renders
## `tooltip_text` natively when hovered, so this just fills each button's string.
func _setup_menu_tooltips() -> void:
	if easy_button != null:
		easy_button.tooltip_text = "EASY — Fewer, weaker enemies with a gentler scaling curve and more starting resources. Best for learning the ropes."
	if normal_button != null:
		normal_button.tooltip_text = "NORMAL — The standard experience. Baseline enemy health, spawn counts, and difficulty scaling."
	if hard_button != null:
		hard_button.tooltip_text = "HARD — Tougher enemies (≈1.5× health) and a steeper difficulty ramp. Rewarding for confident players."
	if brutal_button != null:
		brutal_button.tooltip_text = "BRUTAL — Extreme run: ≈2.25× enemy health and aggressive scaling. High risk, high reward."
	if solo_toggle != null:
		solo_toggle.tooltip_text = "SOLO — Play alone or with a co-op friend; survive the enemy waves together."
	if coop_toggle != null:
		coop_toggle.tooltip_text = "CO-OP — Host or join a lobby and team up with up to 4 players against the waves."
	if tobor_world_button != null:
		tobor_world_button.tooltip_text = "FFA — 4 players fight each other; first to the kill target wins. Last one standing takes the crown."


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
	# Clear any pinned ability/preview — it belonged to the previous hero.
	_pinned_ability_index = -1
	_hide_ability_hover()
	PlayerProfile.select_class(class_id)
	AudioService.play("ui_click")
	_refresh_class_selection()


func _on_roster_info_pressed() -> void:
	return


func _show_selected_hero_info() -> void:
	return


func _sync_info_button_text() -> void:
	return


func _sync_audio_toggles() -> void:
	_updating_audio_ui = true
	sfx_toggle.button_pressed = AudioService.sfx_enabled
	music_toggle.button_pressed = AudioService.music_enabled
	_updating_audio_ui = false


## ---------------------------------------------------------------------------
## Resolution options (main menu)
## ---------------------------------------------------------------------------
const MENU_RESOLUTIONS: Array[Vector2] = [
	Vector2(1920, 1080),
	Vector2(2880, 1800),
	Vector2(3840, 2160),
]
const _MENU_FULLWIDTH := -1

func _build_resolution_options() -> void:
	resolution_option.clear()
	for size in MENU_RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [int(size.x), int(size.y)])
	resolution_option.add_item("FULLSCREEN")
	resolution_option.set_item_metadata(resolution_option.item_count - 1, _MENU_FULLWIDTH)
	resolution_option.item_selected.connect(_on_menu_resolution_selected)
	_sync_menu_resolution_option()


func _sync_menu_resolution_option() -> void:
	var window_size := DisplayServer.window_get_size()
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		resolution_option.select(resolution_option.item_count - 1)
		return
	var best_index := 0
	var best_dist := INF
	for index in MENU_RESOLUTIONS.size():
		var dist := absf(int(MENU_RESOLUTIONS[index].x) - int(window_size.x))
		if dist < best_dist:
			best_dist = dist
			best_index = index
	resolution_option.select(best_index)


func _on_menu_resolution_selected(index: int) -> void:
	AudioService.play("ui_click")
	if resolution_option.get_item_metadata(index) == _MENU_FULLWIDTH:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_sync_menu_resolution_option()
		return
	var size := MENU_RESOLUTIONS[index]
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	_sync_menu_resolution_option()


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
	# User (2026-09-16): "no hero description" — the blurb line is hidden.
	ability_hero_blurb.visible = false
	ability_hero_blurb.text = ""
	for child in ability_list.get_children():
		child.queue_free()
	# LMB/RMB tooltip row (shown above the ability cards).
	var lmb_rmb_label := Label.new()
	lmb_rmb_label.name = "LmbRmbTooltip"
	lmb_rmb_label.add_theme_font_size_override("font_size", 13)
	lmb_rmb_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80, 1.0))
	lmb_rmb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var weapon_name := str(hero_data.get("weapon_name", "Primary Attack"))
	var secondary_id := str(hero_data.get("secondary", ""))
	var secondary_display := secondary_id
	if not secondary_id.is_empty() and PlayerClass.ABILITIES.has(secondary_id):
		secondary_display = str(PlayerClass.ABILITIES[secondary_id].get("name", secondary_id))
	lmb_rmb_label.text = "LMB — %s    RMB — %s" % [weapon_name, secondary_display]
	ability_list.add_child(lmb_rmb_label)
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


## Builds a simple "attack" card for LMB/RMB — shows weapon name, damage, and
## cooldown in the same visual style as the ability cards.
func _build_attack_card(hero_id: String, weapon_name: String, damage: int, cooldown: float, range_px: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	style.border_color = Color(0.18, 0.22, 0.30, 1.0)
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
	# Use the hero's front sprite as the icon.
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = SpriteLibrary.texture_for(hero_id)
	head.add_child(icon)
	var title_label := Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = weapon_name
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0, 1.0))
	head.add_child(title_label)
	var tag := Label.new()
	tag.text = "[LMB]"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8, 1.0))
	head.add_child(tag)
	# Description line.
	var body := Label.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.80, 0.85, 0.92, 1.0))
	var desc: String = ""
	if damage > 0:
		desc = "Deals %d damage every %.1fs" % [damage, cooldown]
		if range_px > 150:
			desc += " at range (%d px)" % range_px
		else:
			desc += " (melee)"
	else:
		desc = "No secondary attack for this hero."
	body.text = desc
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
	if float(values_r1.get("power", 0.0)) > 0.0:
		stat_line.append("[b]Power:[/b] %s" % _rank_slash_list(ability_id, "power", 0))
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
	_shown_kit_ids = _hero_ability_ids(hero_id)
	var hero_data := PlayerClass.by_id(hero_id)
	var weapon_name := str(hero_data.get("weapon_name", "Primary Attack"))
	var secondary_id := str(hero_data.get("secondary", ""))
	# LMB button: capture of the primary-attack projectile sprite (what LMB actually fires).
	# The LMB attack projectile is configured with the "spark" projectile art, so the button
	# shows that projectile icon rather than the hero portrait.
	if lmb_slot_button != null:
		lmb_slot_button.disabled = false
		lmb_slot_button.text = ""
		var lmb_proj_icon := SpriteLibrary.texture_for("spark")
		lmb_slot_button.icon = lmb_proj_icon if lmb_proj_icon != null else SpriteLibrary.texture_for(hero_id)
		lmb_slot_button.expand_icon = false
		lmb_slot_button.add_theme_constant_override("icon_max_width", 52)
		lmb_slot_button.add_theme_constant_override("icon_max_height", 52)
		var lmb_tag := lmb_slot_button.get_node_or_null("SlotTag") as Label
		if lmb_tag == null:
			var t := Label.new()
			t.name = "SlotTag"
			t.position = Vector2(2, 2)
			t.add_theme_font_size_override("font_size", 9)
			t.add_theme_color_override("font_color", Color("f5c542"))
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lmb_slot_button.add_child(t)
			lmb_tag = t
		lmb_tag.text = "LMB"
		# No native tooltip: hover is handled by the ability panel (name + description
		# + live preview in the panel body). A gray native tooltip at the cursor is a
		# visual regression the user explicitly asked to remove.
		lmb_slot_button.tooltip_text = ""
	# RMB button: secondary ability icon. Every hero has a right-click secondary
	# (a `secondary_kind` like "repulse", not an entry in the ABILITIES table), so this
	# is always populated. The secondary icon reuses the shared secondary sprite when
	# one exists, otherwise falls back to the hero's accent glyph.
	if rmb_slot_button != null:
		var sec_info := PlayerClass.secondary_info_for_class(hero_id)
		var sec_name := str(sec_info.get("name", "Secondary"))
		var sec_charge := bool(sec_info.get("charge", false))
		var sec_desc := str(sec_info.get("desc", ""))
		var sec_tooltip := "%s\n%s" % [sec_name, sec_desc]
		if sec_charge:
			sec_tooltip += "\n\nCharged — hold to build, release to fire."
		sec_tooltip += "\nCooldown: ~%.0fs" % float(PlayerClass.SECONDARY_COOLDOWN)
		rmb_slot_button.disabled = false
		rmb_slot_button.text = ""
		# Try the shared secondary icon set first (only the five common secondaries have
		# bespoke 8x8 glyphs: repulse / freeze / volt_mend / rime_ward / wall). Other
		# secondary kinds fall back to the repulse glyph so the button is never empty.
		var sec_kind := str(PlayerClass.by_id(hero_id).get("secondary", "repulse"))
		var sec_texture := SpriteLibrary.texture_for("secondary_%s" % sec_kind)
		if sec_texture == null:
			sec_texture = SpriteLibrary.texture_for("secondary_repulse")
		rmb_slot_button.icon = sec_texture
		rmb_slot_button.expand_icon = false
		rmb_slot_button.add_theme_constant_override("icon_max_width", 52)
		rmb_slot_button.add_theme_constant_override("icon_max_height", 52)
		var rmb_tag := rmb_slot_button.get_node_or_null("SlotTag") as Label
		if rmb_tag == null:
			var t := Label.new()
			t.name = "SlotTag"
			t.position = Vector2(2, 2)
			t.add_theme_font_size_override("font_size", 9)
			t.add_theme_color_override("font_color", Color("f5c542"))
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rmb_slot_button.add_child(t)
			rmb_tag = t
		rmb_tag.text = "RMB"
		# No native tooltip: the RMB panel body shows the full description + cooldown.
		rmb_slot_button.tooltip_text = ""
	var slot_names := ["Q", "E", "D", "R"]
	for slot_index in loadout_slots.size():
		var button := loadout_slots[slot_index] as Button
		var want: String = str(_shown_kit_ids[slot_index]) if slot_index < _shown_kit_ids.size() else ""
		var label: String = slot_names[slot_index] if slot_index < slot_names.size() else str(slot_index + 1)
		button.disabled = false
		button.text = ""
		if want.is_empty() or not PlayerClass.ABILITIES.has(want):
			button.icon = null
			button.tooltip_text = ""
			var tag := button.get_node_or_null("SlotTag") as Label
			if tag != null:
				tag.text = label
			continue
		button.icon = SpriteLibrary.texture_for(want)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 52)
		button.add_theme_constant_override("icon_max_height", 52)
		var tag_ok := button.get_node_or_null("SlotTag") as Label
		if tag_ok != null:
			tag_ok.text = label
		# No native tooltip on the Q/E/D/R slot buttons: the ability panel (with
		# icon + description + live preview) is the only hover surface.
		button.tooltip_text = ""


func _hero_ability_ids(hero_id: String) -> Array[String]:
	var ids: Array[String] = []
	if PlayerProfile.has_method("loadout_for"):
		for aid in PlayerProfile.loadout_for(hero_id):
			ids.append(str(aid))
	if ids.size() >= 4:
		return ids.slice(0, 4)
	var kit := PlayerClass.kit_ability_ids(hero_id)
	for aid in kit:
		if aid not in ids:
			ids.append(aid)
	var secondary := str(PlayerClass.by_id(hero_id).get("secondary", ""))
	if not secondary.is_empty() and PlayerClass.ABILITIES.has(secondary) and secondary not in ids:
		ids.insert(mini(2, ids.size()), secondary)
	while ids.size() < 4:
		ids.append("")
	return ids.slice(0, 4)


func _on_ability_slot_hover(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _shown_kit_ids.size():
		return
	var ability_id := str(_shown_kit_ids[slot_index])
	if ability_id.is_empty():
		return
	_show_ability_hover(ability_id)


func _on_ability_slot_unhover() -> void:
	# When an ability is pinned open by a click, leaving the button must NOT close the
	# panel (so the tooltip + rendered preview stay up for screenshots / testing).
	if _pinned_ability_index >= 0:
		return
	_hide_ability_hover()


## Click-to-pin handlers: clicking an ability button pins its tooltip + rendered
## preview so it stays visible after the mouse moves away. Clicking a different slot
## re-pins that one; the pin persists until the hero changes or the user hovers away
## from the whole panel.
func _on_ability_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _shown_kit_ids.size():
		return
	var ability_id := str(_shown_kit_ids[slot_index])
	if ability_id.is_empty():
		return
	_pinned_ability_index = slot_index
	_show_ability_hover(ability_id)


func _on_lmb_pressed() -> void:
	_pinned_ability_index = -1
	_show_lmb_hover(PlayerProfile.selected_class_id)


func _on_rmb_pressed() -> void:
	_pinned_ability_index = -2
	_show_rmb_hover(PlayerProfile.selected_class_id)


## Maps an ability id to its slot index (0..3) in the given hero's current loadout.
## Returns -1 if not found (e.g. a secondary id not in the kit).
func _ability_slot_index_for(hero_id: String, ability_id: String) -> int:
	var ids := _hero_ability_ids(hero_id)
	for i in ids.size():
		if str(ids[i]) == ability_id:
			return i
	return -1


## Keep the preview SubViewport sized to the visible preview Control so the mini world
## fills the hover panel's preview area (and scales with the window). Called every
## frame from _process — cheap when the panel is hidden (skips work).
func _update_preview_viewport() -> void:
	if ability_preview == null or not ability_preview.visible:
		return
	if ability_preview_world != null:
		ability_preview_world._update_viewport_size()


func _on_lmb_hover() -> void:
	var hero_id := PlayerProfile.selected_class_id
	_show_lmb_hover(hero_id)


func _on_rmb_hover() -> void:
	_show_rmb_hover(PlayerProfile.selected_class_id)


func _show_rmb_hover(hero_id: String) -> void:
	var sec_info := PlayerClass.secondary_info_for_class(hero_id)
	var sec_name := str(sec_info.get("name", "Secondary"))
	var sec_charge := bool(sec_info.get("charge", false))
	var sec_desc := str(sec_info.get("desc", ""))
	# Show the secondary-ability icon, matching the Q/E/D/R tooltip layout.
	if ability_hover_icon != null:
		var sec_kind := str(PlayerClass.by_id(hero_id).get("secondary", "repulse"))
		var sec_tex := SpriteLibrary.texture_for("secondary_%s" % sec_kind)
		ability_hover_icon.texture = sec_tex if sec_tex != null else SpriteLibrary.texture_for("secondary_repulse")
		ability_hover_icon.visible = true
	# Every hero has a right-click secondary (a secondary_kind, not an ABILITIES entry),
	# so show a full card: name, what it does, whether it's charged, and its cooldown.
	if ability_hero_header != null:
		ability_hero_header.text = ("RMB  ·  " + sec_name).to_upper()
	# RMB description in the panel body (not a gray native tooltip at the cursor).
	if ability_hover_body != null:
		ability_hover_body.visible = true
		ability_hover_body.text = _rmb_description(hero_id, sec_name, sec_desc, sec_charge)
	# Rendered preview: the hero bot performs its RMB secondary on the standing creeps.
	if ability_preview != null:
		ability_preview.visible = true
	if ability_preview_world != null:
		ability_preview_world.reload(hero_id, -2)
	ability_panel.visible = true
	_raise_ability_hover()


## RMB secondary description + stats, rendered in the panel body.
func _rmb_description(hero_id: String, sec_name: String, sec_desc: String, sec_charge: bool) -> String:
	var body := "[color=#f4f0e6]%s[/color]" % sec_desc
	body += "\n\n[color=#9fb3d1]Charged: %s   Cooldown: ~%.0fs[/color]" % [
		"yes (hold to build)" if sec_charge else "no",
		float(PlayerClass.SECONDARY_COOLDOWN),
	]
	return body


func _lmb_tooltip(hero_id: String) -> String:
	var hero_data := PlayerClass.by_id(hero_id)
	var dmg := int(hero_data.get("weapon_damage", 0))
	var cd := float(hero_data.get("attack_interval", 0))
	var rng := int(hero_data.get("attack_range", 0))
	var text := "Deals %d damage every %.1fs" % [dmg, cd]
	if rng > 150:
		text += " at range (%d px)" % rng
	else:
		text += " (melee)"
	return text


func _layout_ability_hover_panel() -> void:
	if ability_panel == null:
		return
	ability_panel.visible = false
	ability_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ability_panel.anchor_left = 0.0
	ability_panel.anchor_top = 0.0
	ability_panel.anchor_right = 0.0
	ability_panel.anchor_bottom = 0.0
	ability_panel.offset_left = 36.0
	ability_panel.offset_top = 72.0
	ability_panel.offset_right = 520.0
	ability_panel.offset_bottom = 690.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.55)
	style.border_color = Color(1.0, 0.72, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	ability_panel.add_theme_stylebox_override("panel", style)
	var layout := ability_panel.get_node_or_null("Margin/Layout") as VBoxContainer
	if layout != null:
		ability_hover_icon = layout.get_node_or_null("AbilityHoverIcon") as TextureRect
		if ability_hover_icon == null:
			ability_hover_icon = TextureRect.new()
			ability_hover_icon.name = "AbilityHoverIcon"
			layout.add_child(ability_hover_icon)
			layout.move_child(ability_hover_icon, 0)
		ability_hover_icon.custom_minimum_size = Vector2(64, 64)
		ability_hover_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ability_hover_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ability_hover_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ability_hover_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ability_hover_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_hover_icon.visible = false
		ability_hover_body = layout.get_node_or_null("AbilityHoverBody") as RichTextLabel
		if ability_hover_body == null:
			ability_hover_body = RichTextLabel.new()
			ability_hover_body.name = "AbilityHoverBody"
			layout.add_child(ability_hover_body)
			var blurb_index := ability_hero_blurb.get_index() if ability_hero_blurb != null else 2
			layout.move_child(ability_hover_body, blurb_index + 1)
		ability_hover_body.bbcode_enabled = true
		ability_hover_body.fit_content = true
		ability_hover_body.scroll_active = false
		ability_hover_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_hover_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ability_hover_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ability_hover_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_hover_body.add_theme_color_override("default_color", Color("f4f0e6"))
		ability_hover_body.add_theme_font_size_override("normal_font_size", 16)
		# Rendered ability preview: a real SubViewport running a mini game world where
		# the hero bot casts the hovered ability on 3 standing creeps (actual in-game
		# hero sprite + creeps + VFX, not a hand-drawn mimicry). See ability_preview_world.
		# The preview is pinned to the BOTTOM of the panel, separated from the ability
		# text by an expanding spacer, so it does not hug the description.
		var spacer := layout.get_node_or_null("PreviewSpacer") as Control
		if spacer == null:
			spacer = Control.new()
			spacer.name = "PreviewSpacer"
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layout.add_child(spacer)
		var preview_node := layout.get_node_or_null("AbilityPreview")
		if preview_node == null:
			preview_node = AbilityPreviewWorldScene.instantiate()
		ability_preview = preview_node as Node
		ability_preview.name = "AbilityPreview"
		ability_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ability_preview.size_flags_vertical = Control.SIZE_SHRINK_END
		ability_preview.custom_minimum_size = Vector2(340, 150)
		ability_preview_world = ability_preview as AbilityPreviewWorld
		if ability_preview.get_parent() != layout:
			layout.add_child(ability_preview)
		layout.move_child(ability_preview, layout.get_child_count() - 1)
	if ability_hero_header != null:
		ability_hero_header.add_theme_font_size_override("font_size", 28)
		ability_hero_header.add_theme_color_override("font_color", Color("ffe08c"))
		ability_hero_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		ability_hero_header.add_theme_constant_override("outline_size", 8)
		ability_hero_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ability_hero_blurb != null:
		ability_hero_blurb.visible = false
		ability_hero_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_hero_blurb.add_theme_font_size_override("font_size", 20)
		ability_hero_blurb.add_theme_color_override("font_color", Color("f4f0e6"))
		ability_hero_blurb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		ability_hero_blurb.add_theme_constant_override("outline_size", 6)
	var scroll := ability_panel.get_node_or_null("Margin/Layout/AbilityScroll") as Control
	if scroll != null:
		scroll.visible = false
	var divider := ability_panel.get_node_or_null("Margin/Layout/Divider") as Control
	if divider != null:
		divider.visible = false
	_raise_ability_hover()


func _raise_ability_hover() -> void:
	if ability_panel == null:
		return
	var layer := $StatusLayer as CanvasLayer
	if layer == null:
		return
	layer.move_child(ability_panel, layer.get_child_count() - 1)
	if lobby_panel != null and lobby_panel.get_parent() == layer:
		layer.move_child(lobby_panel, layer.get_child_count() - 1)


## Shows a simple hover panel for the LMB weapon (no preview animation, just stats).
func _show_lmb_hover(hero_id: String) -> void:
	if ability_panel == null or ability_hero_header == null:
		return
	var hero_data := PlayerClass.by_id(hero_id)
	var weapon_name := str(hero_data.get("weapon_name", "Primary Attack"))
	ability_hero_header.text = "%s  ·  LMB" % weapon_name.to_upper()
	# Show the primary-attack projectile icon, matching the Q/E/D/R tooltip layout.
	if ability_hover_icon != null:
		var lmb_icon := SpriteLibrary.texture_for("spark")
		ability_hover_icon.texture = lmb_icon if lmb_icon != null else SpriteLibrary.texture_for(hero_id)
		ability_hover_icon.visible = true
	# LMB description in the panel body (not a gray native tooltip at the cursor).
	if ability_hover_body != null:
		ability_hover_body.visible = true
		ability_hover_body.text = _lmb_description(hero_id)
	# Rendered preview: the hero bot performs its LMB primary on the standing creeps.
	if ability_preview != null:
		ability_preview.visible = true
	if ability_preview_world != null:
		ability_preview_world.reload(hero_id, -1)
	ability_panel.visible = true


## LMB primary-attack description + stats, rendered in the panel body.
func _lmb_description(hero_id: String) -> String:
	var hero_data := PlayerClass.by_id(hero_id)
	var weapon_name := str(hero_data.get("weapon_name", "Primary Attack"))
	var dmg := int(hero_data.get("weapon_damage", 0))
	var cd := float(hero_data.get("attack_interval", 0.0))
	var rng := int(hero_data.get("attack_range", 0))
	var desc := "Deals [b]%d[/b] damage every [b]%.1f[/b]s" % [dmg, cd]
	if rng > 150:
		desc += " at [b]%d[/b] range" % rng
	return "[color=#f4f0e6]%s[/color]" % desc


func _show_ability_hover(ability_id: String) -> void:
	if ability_panel == null or ability_hero_header == null:
		return
	var text := _ability_tooltip(ability_id)
	var lines := text.split("\n")
	ability_hero_header.text = str(lines[0]) if lines.size() > 0 else ability_id
	if ability_hover_icon != null:
		ability_hover_icon.texture = SpriteLibrary.texture_for(ability_id)
		ability_hover_icon.visible = true
	# Show the ability description in the panel body (NOT a native gray tooltip
	# that follows the mouse). The header carries name+tag, the body carries the
	# full substituted description + stat line.
	if ability_hover_body != null:
		ability_hover_body.visible = true
		ability_hover_body.text = _ability_tooltip_body(ability_id)
	# Rendered preview: drive the hero bot to cast this ability on the standing creeps.
	if ability_preview != null:
		ability_preview.visible = true
	if ability_preview_world != null:
		var slot := _ability_slot_index_for(PlayerProfile.selected_class_id, ability_id)
		ability_preview_world.reload(PlayerProfile.selected_class_id, slot)
	ability_panel.visible = true


## Full substituted description + stats block for the panel body (used by the
## ability hover, NOT the native tooltip which would create a gray box at the
## mouse position).
func _ability_tooltip_body(ability_id: String) -> String:
	var info: Dictionary = PlayerClass.ABILITIES.get(ability_id, {})
	if info.is_empty():
		return ability_id
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
	var desc := _substitute_placeholders(str(info.get("description", "")), ability_id, info)
	var lines: Array[String] = ["[color=#f4f0e6]%s[/color]" % desc]
	if not stats.is_empty():
		lines.append("[color=9fb3d1]%s[/color]" % "  |  ".join(stats))
	return "\n".join(lines)


func _hide_ability_hover() -> void:
	if ability_panel != null:
		ability_panel.visible = false
	if ability_hover_icon != null:
		ability_hover_icon.visible = false
	if ability_preview != null:
		ability_preview.visible = false


func _ability_tooltip(ability_id: String) -> String:
	var info: Dictionary = PlayerClass.ABILITIES.get(ability_id, {})
	if info.is_empty():
		return ability_id
	var lines: Array[String] = []
	var tag := "ULT" if float(info.get("cooldown_base", 0.0)) >= 14.0 else str(PlayerClass.ARCHETYPE_NAMES.get(int(info.get("archetype", 0)), "Ability"))
	lines.append("%s  ·  %s" % [str(info.get("name", ability_id)).to_upper(), tag])
	lines.append(_substitute_placeholders(str(info.get("description", "")), ability_id, info))
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
	if subtitle_label != null:
		subtitle_label.visible = false
	class_description.text = "%s\n%s" % [str(selected.description), _stat_summary(selected)]


func _stat_summary(cls: Dictionary) -> String:
	var rng := "Melee" if int(cls.get("attack_range", 0)) <= 150 else "Ranged"
	return "%s · HP %d · CD %ds" % [rng, int(cls.get("max_health", 0)), int(cls.get("attack_interval", 0))]


func _refresh_ability_pool(_hero_id: String) -> void:
	return


func _decorate_slot_button(button: Button) -> void:
	_style_ability_button(button)
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


## LMB/RMB: flat, NO background, NO border. Reads as a bare icon slot, not a
## pushable button. Only a faint highlight on hover so the user knows it's live.
func _style_lmb_rmb_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.11, 0.07, 0.45)
	hover.border_color = Color(1.0, 0.72, 0.28, 0.55)
	hover.set_border_width_all(1)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.07, 0.04, 0.55)
	pressed.border_color = Color(0.45, 0.38, 0.2, 0.6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", Color("f4f0e6"))


## Q/E/D/R ability slots: subtle dark plate, NO border. Reads as a clean icon
## frame without the orange border chrome the old version had.
func _style_ability_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.08, 0.06, 0.9)
	normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.12, 0.08, 0.95)
	hover.border_color = Color(0.0, 0.0, 0.0, 0.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.04, 0.03, 0.95)
	pressed.border_color = Color(0.0, 0.0, 0.0, 0.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", Color("f4f0e6"))


## Small corner tag (LMB/RMB/Q/E/R) overlaid on an ability button.
func _add_slot_tag(button: Button, text: String) -> void:
	var tag := Label.new()
	tag.name = "SlotTag"
	tag.position = Vector2(3, 2)
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", Color("f5c542"))
	tag.add_theme_color_override("font_shadow_color", Color.BLACK)
	tag.add_theme_constant_override("shadow_size", 2)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.text = text
	button.add_child(tag)


func _on_solo_pressed() -> void:
	AudioService.play("ui_click")
	# World Editor mode: open the editor instead of starting a run.
	if _mode_nav_index == 3:
		_on_world_editor_pressed()
		return
	RunSave.clear()
	_pending_run_save = {}
	if _play_mode == 1:
		GameRuntime.fill_cpu_allies = true
		GameRuntime.ffa_all_bots = false
		GameRuntime.set_team_mode(GameRuntime.TeamMode.FFA)
	else:
		GameRuntime.fill_cpu_allies = false
		GameRuntime.ffa_all_bots = false
		GameRuntime.set_team_mode(GameRuntime.TeamMode.NONE)
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	GameRuntime.start_wave = 1
	GameRuntime.pending_run_save = {}
	GameRuntime.biome_locked = false
	_open_game()


func _play_row() -> HBoxContainer:
	if solo_button == null:
		return null
	var parent := solo_button.get_parent()
	if parent is HBoxContainer and parent.name == "PlayRow":
		return parent as HBoxContainer
	return parent.get_node_or_null("PlayRow") as HBoxContainer if parent != null else null


func _sync_continue_button() -> void:
	if solo_button == null:
		return
	var row := _play_row()
	var existing := row.get_node_or_null("ContinueButton") as Button if row != null else null
	if not RunSave.has_save():
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		existing.visible = true
		return
	_install_continue_button()


func _install_continue_button() -> void:
	if solo_button == null or not RunSave.has_save():
		return
	var parent := solo_button.get_parent()
	if parent == null:
		return
	var row := _play_row()
	if row == null:
		row = HBoxContainer.new()
		row.name = "PlayRow"
		row.custom_minimum_size = Vector2(0, 48)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var solo_index := solo_button.get_index()
		parent.add_child(row)
		parent.move_child(row, solo_index)
		parent.remove_child(solo_button)
		row.add_child(solo_button)
		solo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if row.get_node_or_null("ContinueButton") != null:
		return
	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "CONTINUE"
	continue_button.custom_minimum_size = Vector2(0, 48)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	AudioService.play("ui_click")
	var data := RunSave.read_dict()
	if data.is_empty():
		return
	GameRuntime.start_wave = int(data.get("wave", 1))
	PlayerProfile.selected_class_id = str(data.get("class_id", PlayerProfile.selected_class_id))
	_pending_run_save = data
	GameRuntime.pending_run_save = data.duplicate(true)
	GameRuntime.fill_cpu_allies = false
	GameRuntime.ffa_all_bots = false
	GameRuntime.set_team_mode(GameRuntime.TeamMode.NONE)
	GameRuntime.set_runtime_mode(GameRuntime.RuntimeMode.OFFLINE)
	GameRuntime.biome_locked = false
	if data.has("biome_id"):
		GameRuntime.set_biome(int(data.get("biome_id", 0)), false)
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
	# Bin it next to Solo inside a horizontal row so it never gets clipped by
	# the Layout's vertical overflow when the ability panel grows.
	var row := HBoxContainer.new()
	row.name = "CoopRow"
	row.custom_minimum_size = Vector2(0, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var parent := solo_button.get_parent()
	parent.add_child(row)
	parent.move_child(row, solo_button.get_index() + 1)
	solo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cpu_coop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cpu_coop_button)
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


func _build_world_editor_button() -> void:
	var row := mode_row as HBoxContainer
	if row == null:
		return
	var btn := Button.new()
	btn.name = "WorldEditorButton"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	btn.text = "WORLD EDITOR"
	btn.tooltip_text = "Open the world/level editor to place trees, rocks, grass and landmarks"
	btn.pressed.connect(_on_world_editor_pressed)
	row.add_child(btn)
	row.move_child(btn, row.get_child_count() - 1)
	for child in row.get_children():
		if child is Button:
			(child as Button).add_theme_font_size_override("font_size", 12)
			(child as Button).clip_text = true


func _on_world_editor_pressed() -> void:
	AudioService.play("ui_click")
	get_tree().change_scene_to_file("res://scenes/world_editor/world_editor.tscn")


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
	_play_mode = 2
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
	if roster_info_button != null and roster_info_button.get_parent() != null:
		roster_info_button.get_parent().visible = false
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
		_ability_panel_hero_id = ""
	_sync_info_button_text()
	lobby_title_label.visible = true
	lobby_title_label.text = "Lobby"
	player_slots.visible = true
	lobby_action_row.visible = true
	invite_button.visible = _is_lobby_host and NetworkService.current_steam_lobby_id != 0
	invite_button.disabled = false
	leave_lobby_button.visible = true
	roster_label.visible = false
	start_game_button.visible = _is_lobby_host
	start_game_button.disabled = false
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
	GameRuntime.use_editor_level = true
	GameRuntime.reset_biome_for_new_run()
	var game := GAME_SCENE.instantiate()
	add_child(game)
	if not _pending_run_save.is_empty():
		if game.has_method("restore_run"):
			game.call("restore_run", _pending_run_save)
		_pending_run_save = {}
	lobby_panel.visible = false
	backdrop.visible = false
	status_label.visible = false
	if ability_panel != null:
		ability_panel.visible = false
		_ability_panel_hero_id = ""
	_sync_info_button_text()
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
	# Reset FFA/team mode so the menu doesn't treat the next entry as FFA and the
	# class picker doesn't fall into a stale team-assigned layout.
	GameRuntime.set_team_mode(GameRuntime.TeamMode.NONE)
	GameRuntime.ffa_all_bots = false
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
	difficulty_label.visible = true
	difficulty_row.visible = true
	leave_lobby_button.visible = false
	cancel_create_button.visible = false
	roster_label.visible = false
	waiting_label.visible = false
	_refresh_game_mode()
	_sync_continue_button()


func _set_lobby_enabled(enabled: bool) -> void:
	_lobby_enabled = enabled
	solo_button.disabled = not enabled
	if cpu_coop_button != null:
		cpu_coop_button.disabled = not enabled
	host_button.disabled = not enabled or not _steam_status_known
	join_button.disabled = not enabled
	address_input.editable = enabled
	solo_toggle.disabled = not enabled
	coop_toggle.disabled = not enabled
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

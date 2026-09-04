class_name GameHUD
extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)
signal ability_chosen(ability_id: String)
signal shop_item_chosen(item_id: String)
signal shop_closed
signal restart_requested
signal leave_requested
signal dev_command(command: String)
signal next_wave_requested

const UPGRADE_ICON_MAX_WIDTH := 28

@onready var class_label: Label = $MarginContainer/Layout/Title
@onready var instructions_label: Label = $MarginContainer/Layout/Instructions
@onready var health_bar: ProgressBar = $MarginContainer/Layout/HealthBar
@onready var health_label: Label = $MarginContainer/Layout/HealthLabel
@onready var game_over_label: Label = $MarginContainer/Layout/GameOver
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var connection_label: Label = $ConnectionLabel
@onready var world_label: Label = $ConnectionLabel
@onready var wave_label: Label = $WaveLabel
@onready var next_wave_button: Button = $NextWaveButton
@onready var next_wave_timer_label: Label = $NextWaveTimer
@onready var boss_panel: VBoxContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var gold_label: Label = $GoldLabel
@onready var ability_label: Label = $AbilityLabel
@onready var ability_bar_label: Label = $AbilityBar
@onready var theme_banner: Label = $ThemeBanner
@onready var debut_banner: Label = $DebutBanner
@onready var mission_banner: Label = $MissionBanner
@onready var mission_card_bg: ColorRect = $MissionCardBg
@onready var mission_subtitle: Label = $MissionSubtitle
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var shop_title: Label = $ShopPanel/ShopLayout/ShopTitle
@onready var shop_gold_label: Label = $ShopPanel/ShopLayout/ShopGold
@onready var shop_grid: GridContainer = $ShopPanel/ShopLayout/ShopGrid
@onready var shop_continue: Button = $ShopPanel/ShopLayout/ShopContinue
@onready var upgrade_panel: PanelContainer = $UpgradePanel
@onready var offer_title_label: Label = $UpgradePanel/Layout/OfferTitle
@onready var choice_buttons: Array[Button] = [
	$UpgradePanel/Layout/Choices/Choice1,
	$UpgradePanel/Layout/Choices/Choice2,
	$UpgradePanel/Layout/Choices/Choice3,
	$UpgradePanel/Layout/Choices/Choice4,
]
@onready var escape_menu: PanelContainer = $EscapeMenu
@onready var resume_button: Button = $EscapeMenu/EscapeLayout/ResumeButton
@onready var restart_button: Button = $EscapeMenu/EscapeLayout/RestartButton
@onready var leave_button: Button = $EscapeMenu/EscapeLayout/LeaveButton
@onready var sfx_toggle: CheckButton = $EscapeMenu/EscapeLayout/SfxToggle
@onready var music_toggle: CheckButton = $EscapeMenu/EscapeLayout/MusicToggle
@onready var dev_panel: PanelContainer = $DevPanel
@onready var dev_add_xp_button: Button = $DevPanel/DevLayout/DevButtons/AddXPButton
@onready var dev_add_levels_button: Button = $DevPanel/DevLayout/DevButtons/AddLevelsButton
@onready var dev_spawn_elite_button: Button = $DevPanel/DevLayout/DevButtons/SpawnEliteButton
@onready var dev_invulnerable_button: Button = $DevPanel/DevLayout/DevButtons/InvulnerableButton
@onready var dev_add_gold_button: Button = $DevPanel/DevLayout/DevButtons/AddGoldButton
@onready var codex_panel: PanelContainer = $CodexPanel
@onready var codex_title: Label = $CodexPanel/CodexLayout/CodexTitle
@onready var codex_scroll: ScrollContainer = $CodexPanel/CodexLayout/CodexScroll
@onready var codex_text: RichTextLabel = $CodexPanel/CodexLayout/CodexScroll/CodexText
@onready var stats_panel: PanelContainer = $StatsPanel
@onready var stats_text: Label = $StatsPanel/StatsLayout/StatsText

var bound_player: Player
var offered_upgrade_ids: Array[String] = []
var offer_kind := "stat"
var pauses_game := false
var shop_pauses_game := false
var shown_class_id := ""
var shop_buttons: Dictionary = {}
var _last_gold := -1
var _escape_paused := false
var _updating_audio_ui := false
var _next_wave_countdown := 0.0
var chant_panel: PanelContainer
var chant_words_label: RichTextLabel
var chant_timer_label: Label
var chant_hint_label: Label
var _biome_buttons: Array[Button] = []
var _biome_caption: Label
var _biome_row: HBoxContainer
var warning_veil: ColorRect
var boss_phase_label: Label
var secondary_slot: Control
var secondary_icon: TextureRect
var secondary_cd_bar: ProgressBar
var secondary_key_label: Label
var secondary_name_label: Label
var _shown_secondary_kind := ""
var rift_banner: Label
var ffa_scoreboard: VBoxContainer
var ffa_row_box: VBoxContainer
var ffa_board_bg: ColorRect
var aim_reticle: Control
var ability_icon_row: VBoxContainer
var ability_icon_slots: Array[Dictionary] = []
var _shown_ability_ids: Array[String] = []
var item_icon_row: VBoxContainer
var item_icon_slots: Array[Dictionary] = []
var _shown_item_ids: Array[String] = []
var _hud_wave := 1
var _hotkeys_visible := false
var secondary_hotkey_label: Label


const SECONDARY_ICON_BY_KIND := {
	"repulse": "secondary_repulse",
	"freeze": "secondary_freeze",
	"volt_mend": "secondary_volt_mend",
	"rime_ward": "secondary_rime_ward",
	"wall": "secondary_wall",
}

const SECONDARY_NAMES := {
	"repulse": "Repulse",
	"freeze": "Freeze",
	"volt_mend": "Volt Mend",
	"rime_ward": "Rime Ward",
	"wall": "Wall",
}


func _ready() -> void:
	for index in choice_buttons.size():
		var choice_button := choice_buttons[index]
		choice_button.pressed.connect(_on_upgrade_selected.bind(index))
		choice_button.expand_icon = true
		choice_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		choice_button.add_theme_constant_override("icon_max_width", UPGRADE_ICON_MAX_WIDTH)
		## Ability cards run up to 4 lines (name, flavor, effect, modifier) — without wrapping
		## and a smaller size, that text just overflows the button instead of fitting it.
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.add_theme_font_size_override("font_size", 13)
		choice_button.clip_text = true
		choice_button.custom_minimum_size = Vector2(220, 108)
	shop_continue.pressed.connect(_on_shop_continue_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	music_toggle.toggled.connect(_on_music_toggled)
	_sync_audio_toggles()
	dev_add_xp_button.pressed.connect(_on_dev_button_pressed.bind("add_xp"))
	dev_add_levels_button.pressed.connect(_on_dev_button_pressed.bind("add_5_levels"))
	dev_spawn_elite_button.pressed.connect(_on_dev_button_pressed.bind("spawn_elite"))
	dev_invulnerable_button.pressed.connect(_on_dev_button_pressed.bind("toggle_invulnerable"))
	if dev_add_gold_button != null:
		dev_add_gold_button.pressed.connect(_on_dev_button_pressed.bind("add_gold"))
	next_wave_button.pressed.connect(_on_next_wave_pressed)
	codex_title.text = "HOTKEYS  (TAB to close)"
	codex_text.text = _build_help_text()
	codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_title.text = "SUPERMERCATOR"
	leave_button.visible = true
	leave_button.text = "LEAVE TO MENU"
	_build_shop()
	_build_chant_overlay()
	_build_dev_biome_row()
	_build_boss_overlay()
	_build_secondary_slot()
	_build_ability_icon_bar()
	_build_item_icon_bar()
	_build_aim_reticle()
	_build_ffa_overlay()
	class_label.visible = false
	health_bar.visible = false
	health_label.visible = false
	instructions_label.visible = false
	ability_label.visible = false
	_set_world_wave(1)
	upgrade_panel.visible = false
	offered_upgrade_ids.clear()
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if upgrade_panel.visible and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("ability_1"):
			get_viewport().set_input_as_handled()
			_on_upgrade_selected(0)
			return
		if event.is_action_pressed("ability_2"):
			get_viewport().set_input_as_handled()
			_on_upgrade_selected(1)
			return
		if event.is_action_pressed("ability_3"):
			get_viewport().set_input_as_handled()
			_on_upgrade_selected(2)
			return
		if event.is_action_pressed("ability_4"):
			get_viewport().set_input_as_handled()
			_on_upgrade_selected(3)
			return
	if event.is_action_pressed("show_stats"):
		stats_panel.visible = true
		stats_text.text = _build_stats_text()
		return
	if event.is_action_released("show_stats"):
		stats_panel.visible = false
		return
	if OS.is_debug_build() and event.is_action_pressed("dev_toggle"):
		dev_panel.visible = not dev_panel.visible
		return
	## Quick "+1 level" without opening the panel — the panel's own button does +5 at once.
	if OS.is_debug_build() and event.is_action_pressed("dev_add_level"):
		dev_command.emit("add_1_level")
		return
	if not event.is_action_pressed("pause_menu"):
		return
	if escape_menu.visible:
		_close_escape_menu()
	elif not shop_panel.visible and not upgrade_panel.visible and not game_over_label.visible:
		_open_escape_menu()


func _toggle_help_panel() -> void:
	if codex_panel.visible:
		codex_panel.visible = false
		return
	codex_text.text = _build_help_text()
	codex_panel.visible = true
	codex_scroll.scroll_vertical = 0


func _build_help_text() -> String:
	var lines: Array[String] = []
	lines.append("[b][color=ffd166]CONTROLS[/color][/b]")
	lines.append("[b]WASD[/b] — Move")
	lines.append("[b]Mouse[/b] — Aim")
	lines.append("[b]LMB[/b] — Hold to charge, release to fire")
	lines.append("[b]RMB[/b] — Secondary")
	if bound_player != null:
		var secondary_name := str(SECONDARY_NAMES.get(bound_player.secondary_kind, bound_player.secondary_kind))
		lines.append("        %s" % secondary_name)
	lines.append("[b]1 2 3 4[/b] — Abilities / level-up picks")
	if bound_player != null:
		for slot in bound_player.known_abilities.size():
			var entry: Dictionary = bound_player.known_abilities[slot]
			var info := PlayerClass.ability_info(str(entry.id))
			lines.append("        [b]%d[/b] — %s" % [slot + 1, str(info.get("name", entry.id))])
		if bound_player.has_active_item():
			lines.append("[b]SPACE[/b] — %s" % ShopCatalog.display_name("sirene", bound_player.class_id))
		for item_id in _owned_item_ids():
			if item_id == "sirene":
				continue
			lines.append("[b]Item[/b] — %s" % ShopCatalog.display_name(item_id, bound_player.class_id))
	else:
		lines.append("[b]SPACE[/b] — Dash (after buying Siren)")
	lines.append("[b]B[/b] — Shop")
	lines.append("[b]TAB[/b] — This list")
	lines.append("[b]SHIFT[/b] — Live stats")
	lines.append("[b]ESC[/b] — Menu")
	lines.append("[b]R[/b] — Restart after defeat")
	lines.append("")
	lines.append(_build_codex_text())
	return "\n".join(lines)


func _open_escape_menu() -> void:
	restart_button.visible = GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE
	_sync_audio_toggles()
	escape_menu.visible = true
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		_escape_paused = true
		get_tree().paused = true


func _close_escape_menu() -> void:
	escape_menu.visible = false
	if _escape_paused:
		_escape_paused = false
		get_tree().paused = false


func _on_resume_pressed() -> void:
	AudioService.play("ui_click")
	_close_escape_menu()


func _on_restart_pressed() -> void:
	AudioService.play("ui_click")
	_close_escape_menu()
	restart_requested.emit()


func _on_leave_pressed() -> void:
	AudioService.play("ui_click")
	_close_escape_menu()
	leave_requested.emit()


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


func _on_dev_button_pressed(command: String) -> void:
	AudioService.play("ui_click")
	dev_command.emit(command)


func _process(delta: float) -> void:
	if shop_panel.visible:
		_refresh_shop()
	if dev_panel.visible:
		_refresh_dev_panel()
	if stats_panel.visible:
		stats_text.text = _build_stats_text()
	if next_wave_timer_label.visible:
		_next_wave_countdown = maxf(0.0, _next_wave_countdown - delta)
		next_wave_timer_label.text = "auto in %ds" % ceili(_next_wave_countdown)
	_refresh_ability()
	_refresh_ability_bar()
	_refresh_ability_icons()
	_refresh_item_icons()
	_refresh_secondary_slot()
	_refresh_aim_reticle()
	_refresh_hotkey_overlays()


## Hold SHIFT to see it — a live readout of the bound player's current combat stats,
## including anything upgrades/shop items have changed so far this run.
func _build_stats_text() -> String:
	if bound_player == null:
		return ""
	var lines: Array[String] = []
	lines.append("HP: %d / %d" % [ceili(bound_player.health.current_health), ceili(bound_player.health.max_health)])
	lines.append("Damage: %.1f" % bound_player.weapon_damage)
	lines.append("Attack speed: %.2f/s" % (1.0 / maxf(0.01, bound_player.attack_interval)))
	lines.append("Range: %d" % int(bound_player.attack_range))
	lines.append("Move speed: %d" % int(bound_player.movement_speed))
	if bound_player.chain_count > 0:
		lines.append("Chains: %d" % bound_player.chain_count)
	if bound_player.weapon_kind == PlayerClass.Weapon.ENERGY_BLAST:
		lines.append("Blast: %d" % int(bound_player.blast_radius))
	if bound_player.weapon_kind == PlayerClass.Weapon.CONE_SLAM:
		lines.append("Arc: %d°" % int(bound_player.cone_half_angle_degrees * 2.0))
	if bound_player.health.damage_taken_multiplier < 1.0:
		lines.append("Damage taken: x%.2f" % bound_player.health.damage_taken_multiplier)
	if bound_player.lifesteal_ratio > 0.0:
		lines.append("Lifesteal: %d%%" % roundi(bound_player.lifesteal_ratio * 100.0))
	if bound_player.thorns_ratio > 0.0:
		lines.append("Thorns: %d%%" % roundi(bound_player.thorns_ratio * 100.0))
	if bound_player.health_regen_per_second > 0.0:
		lines.append("Regen: %.1f HP/s" % bound_player.health_regen_per_second)
	if bound_player.ember_damage_per_second > 0.0:
		lines.append("Burn aura: %.0f/s" % bound_player.ember_damage_per_second)
	if bound_player.jetpack_slam > 0.0:
		lines.append("Jetpack slam: %.0f" % bound_player.jetpack_slam)
	if bound_player.skate_speed_bonus > 0.0:
		lines.append("Skate: +%d%% speed" % roundi(bound_player.skate_speed_bonus * 100.0))
	if bound_player.grab_radius > 0.0:
		lines.append("Grab: %.0f" % bound_player.grab_radius)
	if bound_player.knockback_strength > 0.0:
		lines.append("Knockback: yes")
	if bound_player.hit_slow_factor < 1.0:
		lines.append("Hit slow: %d%%" % roundi((1.0 - bound_player.hit_slow_factor) * 100.0))
	if bound_player.pickup_radius_bonus > 0.0:
		lines.append("XP pull: +%d%%" % roundi(bound_player.pickup_radius_bonus * 100.0))
	if bound_player.resistance_pierce > 0.0:
		lines.append("Pierce: %d%%" % roundi(bound_player.resistance_pierce * 100.0))
	lines.append("Gold: %d" % bound_player.gold)
	return "\n".join(lines)


func _refresh_dev_panel() -> void:
	if bound_player != null:
		dev_invulnerable_button.text = "INVULNERABLE: %s" % ("ON" if bound_player.health.invulnerable else "OFF")
	var show_worlds := GameRuntime.uses_biomes()
	if _biome_caption != null:
		_biome_caption.visible = show_worlds
	if _biome_row != null:
		_biome_row.visible = show_worlds
	if not show_worlds or _biome_buttons.size() < 6:
		return
	var locked := GameRuntime.biome_locked
	var current := GameRuntime.biome_id
	for index in _biome_buttons.size():
		var selected := (index == 0 and not locked) or (index > 0 and locked and current == index - 1)
		_biome_buttons[index].modulate = Color("d4ff9a") if selected else Color.WHITE


func _build_dev_biome_row() -> void:
	var layout := $DevPanel/DevLayout as VBoxContainer
	var caption := Label.new()
	caption.text = "WORLD  (locks until AUTO)"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.75, 0.82, 0.7, 1))
	layout.add_child(caption)
	_biome_caption = caption
	var row := HBoxContainer.new()
	row.name = "BiomeButtons"
	row.add_theme_constant_override("separation", 6)
	layout.add_child(row)
	_biome_row = row
	var specs: Array[Array] = [
		["AUTO", "biome_auto"],
		["GRAS", "biome_0"],
		["VULKAAN", "biome_1"],
		["IJS", "biome_2"],
		["FABRIEK", "biome_3"],
		["DOCKS", "biome_4"],
	]
	for spec in specs:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(spec[0])
		button.pressed.connect(_on_dev_button_pressed.bind(str(spec[1])))
		row.add_child(button)
		_biome_buttons.append(button)


func _refresh_ability() -> void:
	ability_label.visible = false
	ability_label.text = ""


func _dash_item_name() -> String:
	if bound_player == null:
		return "SIREN"
	return ShopCatalog.display_name("sirene", bound_player.class_id).to_upper()


const ABILITY_SLOT_KEYS := ["1", "2", "3", "4"]


func _build_secondary_slot() -> void:
	secondary_slot = Control.new()
	secondary_slot.name = "SecondarySlot"
	secondary_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_slot.offset_left = 1190.0
	secondary_slot.offset_top = 118.0
	secondary_slot.offset_right = 1252.0
	secondary_slot.offset_bottom = 206.0
	add_child(secondary_slot)

	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.08, 0.78)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_slot.add_child(panel)

	secondary_icon = TextureRect.new()
	secondary_icon.name = "Icon"
	secondary_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	secondary_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	secondary_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	secondary_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_icon.offset_left = 7.0
	secondary_icon.offset_top = 4.0
	secondary_icon.offset_right = 55.0
	secondary_icon.offset_bottom = 52.0
	secondary_slot.add_child(secondary_icon)

	secondary_cd_bar = ProgressBar.new()
	secondary_cd_bar.name = "Cooldown"
	secondary_cd_bar.show_percentage = false
	secondary_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_cd_bar.min_value = 0.0
	secondary_cd_bar.max_value = 1.0
	secondary_cd_bar.value = 0.0
	secondary_cd_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	secondary_cd_bar.offset_left = 7.0
	secondary_cd_bar.offset_top = 4.0
	secondary_cd_bar.offset_right = 55.0
	secondary_cd_bar.offset_bottom = 52.0
	var cd_bg := StyleBoxFlat.new()
	cd_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var cd_fill := StyleBoxFlat.new()
	cd_fill.bg_color = Color(0.04, 0.06, 0.1, 0.62)
	secondary_cd_bar.add_theme_stylebox_override("background", cd_bg)
	secondary_cd_bar.add_theme_stylebox_override("fill", cd_fill)
	secondary_slot.add_child(secondary_cd_bar)

	secondary_key_label = Label.new()
	secondary_key_label.name = "Key"
	secondary_key_label.text = "RMB"
	secondary_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary_key_label.add_theme_font_size_override("font_size", 11)
	secondary_key_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.42, 1.0))
	secondary_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_key_label.offset_left = 0.0
	secondary_key_label.offset_top = 50.0
	secondary_key_label.offset_right = 62.0
	secondary_key_label.offset_bottom = 66.0
	secondary_slot.add_child(secondary_key_label)

	secondary_name_label = Label.new()
	secondary_name_label.name = "Name"
	secondary_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary_name_label.add_theme_font_size_override("font_size", 11)
	secondary_name_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1.0))
	secondary_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_name_label.offset_left = 0.0
	secondary_name_label.offset_top = 64.0
	secondary_name_label.offset_right = 62.0
	secondary_name_label.offset_bottom = 80.0
	secondary_slot.add_child(secondary_name_label)
	secondary_hotkey_label = Label.new()
	secondary_hotkey_label.name = "Hotkey"
	secondary_hotkey_label.text = "RMB"
	secondary_hotkey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary_hotkey_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	secondary_hotkey_label.add_theme_font_size_override("font_size", 13)
	secondary_hotkey_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	secondary_hotkey_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	secondary_hotkey_label.add_theme_constant_override("shadow_outline_size", 4)
	secondary_hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_hotkey_label.offset_left = 0.0
	secondary_hotkey_label.offset_top = 14.0
	secondary_hotkey_label.offset_right = 62.0
	secondary_hotkey_label.offset_bottom = 42.0
	secondary_hotkey_label.visible = false
	secondary_slot.add_child(secondary_hotkey_label)
	secondary_slot.visible = false


func _make_kit_icon_slot(parent: Control, key_text: String, compact: bool = false) -> Dictionary:
	var slot := Control.new()
	var slot_h := 62.0 if compact else 88.0
	slot.custom_minimum_size = Vector2(62.0, slot_h)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)

	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.08, 0.78)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(panel)

	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.offset_left = 7.0
	icon.offset_top = 4.0
	icon.offset_right = 55.0
	icon.offset_bottom = 52.0
	slot.add_child(icon)

	var cd_bar := ProgressBar.new()
	cd_bar.show_percentage = false
	cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_bar.min_value = 0.0
	cd_bar.max_value = 1.0
	cd_bar.value = 0.0
	cd_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	cd_bar.offset_left = 7.0
	cd_bar.offset_top = 4.0
	cd_bar.offset_right = 55.0
	cd_bar.offset_bottom = 52.0
	var cd_bg := StyleBoxFlat.new()
	cd_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var cd_fill := StyleBoxFlat.new()
	cd_fill.bg_color = Color(0.04, 0.06, 0.1, 0.62)
	cd_bar.add_theme_stylebox_override("background", cd_bg)
	cd_bar.add_theme_stylebox_override("fill", cd_fill)
	slot.add_child(cd_bar)

	var key_label := Label.new()
	key_label.text = key_text
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.42, 1.0))
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.offset_top = 36.0 if compact else 50.0
	key_label.offset_right = 62.0
	key_label.offset_bottom = 52.0 if compact else 66.0
	key_label.clip_text = true
	slot.add_child(key_label)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.offset_top = 48.0 if compact else 64.0
	name_label.offset_right = 62.0
	name_label.offset_bottom = 62.0 if compact else 80.0
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	slot.add_child(name_label)
	var hotkey := Label.new()
	hotkey.text = key_text
	hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hotkey.add_theme_font_size_override("font_size", 13)
	hotkey.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	hotkey.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	hotkey.add_theme_constant_override("shadow_outline_size", 4)
	hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotkey.offset_top = 14.0
	hotkey.offset_right = 62.0
	hotkey.offset_bottom = 42.0
	hotkey.visible = false
	slot.add_child(hotkey)
	return {"root": slot, "icon": icon, "bar": cd_bar, "key": key_label, "name": name_label, "hotkey": hotkey, "bind": key_text}


func _apply_kit_cooldown(nodes: Dictionary, remaining: float, cooldown_max: float, _ready_key: String = "") -> void:
	var bar := nodes.bar as ProgressBar
	var icon := nodes.icon as TextureRect
	var key_label := nodes.key as Label
	if remaining > 0.0:
		bar.value = clampf(remaining / maxf(0.01, cooldown_max), 0.0, 1.0)
		icon.modulate = Color(0.55, 0.55, 0.6, 1.0)
		key_label.text = "%.1f" % remaining
		key_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	else:
		bar.value = 0.0
		icon.modulate = Color.WHITE
		key_label.text = ""


func _secondary_icon_id(kind: String) -> String:
	return str(SECONDARY_ICON_BY_KIND.get(kind, "secondary_repulse"))


func _refresh_secondary_slot() -> void:
	if secondary_slot == null:
		return
	if bound_player == null:
		secondary_slot.visible = false
		_shown_secondary_kind = ""
		return
	secondary_slot.visible = true
	var kind := bound_player.secondary_kind
	if kind != _shown_secondary_kind:
		_shown_secondary_kind = kind
		secondary_icon.texture = SpriteLibrary.texture_for(_secondary_icon_id(kind))
		secondary_name_label.text = str(SECONDARY_NAMES.get(kind, kind)).to_upper()
	var remaining := bound_player.secondary_cooldown
	var cooldown_max := maxf(0.01, bound_player.secondary_cooldown_max)
	if remaining > 0.0:
		secondary_cd_bar.value = clampf(remaining / cooldown_max, 0.0, 1.0)
		secondary_icon.modulate = Color(0.55, 0.55, 0.6, 1.0)
		secondary_key_label.text = "%.1f" % remaining
		secondary_key_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	else:
		secondary_cd_bar.value = 0.0
		secondary_icon.modulate = Color.WHITE
		secondary_key_label.text = ""


func _refresh_ability_bar() -> void:
	ability_bar_label.visible = false
	ability_bar_label.text = ""


func _build_ability_icon_bar() -> void:
	ability_icon_row = VBoxContainer.new()
	ability_icon_row.name = "AbilityIconBar"
	ability_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_icon_row.add_theme_constant_override("separation", 2)
	ability_icon_row.offset_left = 1190.0
	ability_icon_row.offset_top = 236.0
	ability_icon_row.offset_right = 1252.0
	ability_icon_row.offset_bottom = 500.0
	add_child(ability_icon_row)
	ability_icon_slots.clear()
	for slot in 4:
		ability_icon_slots.append(_make_kit_icon_slot(ability_icon_row, ABILITY_SLOT_KEYS[slot], true))


func _build_item_icon_bar() -> void:
	item_icon_row = VBoxContainer.new()
	item_icon_row.name = "ItemIconBar"
	item_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon_row.add_theme_constant_override("separation", 2)
	item_icon_row.offset_left = 12.0
	item_icon_row.offset_top = 176.0
	item_icon_row.offset_right = 74.0
	item_icon_row.offset_bottom = 700.0
	add_child(item_icon_row)
	item_icon_slots.clear()
	_shown_item_ids.clear()


func _owned_item_ids() -> Array[String]:
	var ids: Array[String] = []
	if bound_player == null:
		return ids
	for item_id in ShopCatalog.ids():
		if bound_player.stacks_of(item_id) > 0:
			ids.append(item_id)
	return ids


func _item_cooldown(item_id: String) -> Vector2:
	if bound_player == null:
		return Vector2.ZERO
	match item_id:
		"sirene":
			return Vector2(bound_player.sprint_cooldown, bound_player.sprint_cycle_length())
		"romp":
			var wait := 2.4 if bound_player.stacks_of("sjaal") > 0 else 2.0
			return Vector2(float(bound_player.get("_jump_cooldown")), wait)
		_:
			return Vector2.ZERO


func _refresh_item_icons() -> void:
	if item_icon_row == null:
		return
	var ids := _owned_item_ids()
	if ids.is_empty():
		item_icon_row.visible = false
		_shown_item_ids.clear()
		return
	item_icon_row.visible = true
	if ids != _shown_item_ids:
		for slot in item_icon_slots:
			var root := slot.root as Control
			if root != null:
				root.queue_free()
		item_icon_slots.clear()
		var class_id := bound_player.class_id
		for item_id in ids:
			var nodes := _make_kit_icon_slot(item_icon_row, _item_bind(item_id), true)
			(nodes.icon as TextureRect).texture = SpriteLibrary.item_icon(item_id)
			(nodes.name as Label).text = _item_icon_caption(item_id)
			item_icon_slots.append(nodes)
		_shown_item_ids = ids
	for index in item_icon_slots.size():
		if index >= ids.size():
			break
		(item_icon_slots[index].name as Label).text = _item_icon_caption(ids[index])
		var cd := _item_cooldown(ids[index])
		_apply_kit_cooldown(item_icon_slots[index], cd.x, cd.y)


func _item_icon_caption(item_id: String) -> String:
	var class_id := bound_player.class_id if bound_player != null else PlayerClass.DEFAULT_CLASS_ID
	var caption := _clip_label(ShopCatalog.display_name(item_id, class_id), 6)
	var stacks := bound_player.stacks_of(item_id) if bound_player != null else 0
	if stacks > 1:
		return "%s x%d" % [caption, stacks]
	return caption


func _clip_label(text: String, max_chars: int = 8) -> String:
	var clipped := text.to_upper()
	if clipped.length() <= max_chars:
		return clipped
	return clipped.substr(0, max_chars)


func _item_bind(item_id: String) -> String:
	match item_id:
		"sirene":
			return "SPACE"
		"romp":
			return "AUTO"
		_:
			return ""


func _refresh_hotkey_overlays() -> void:
	var show := Input.is_action_pressed("codex_toggle")
	_hotkeys_visible = show
	if secondary_hotkey_label != null:
		secondary_hotkey_label.visible = show and secondary_slot != null and secondary_slot.visible
	for slot in ability_icon_slots:
		var hotkey := slot.get("hotkey") as Label
		var root := slot.get("root") as Control
		if hotkey == null:
			continue
		hotkey.text = str(slot.get("bind", ""))
		hotkey.visible = show and root != null and root.visible
	for slot in item_icon_slots:
		var hotkey := slot.get("hotkey") as Label
		var root := slot.get("root") as Control
		if hotkey == null:
			continue
		var bind := str(slot.get("bind", ""))
		hotkey.text = bind
		hotkey.visible = show and root != null and root.visible and not bind.is_empty()


func _refresh_ability_icons() -> void:
	if ability_icon_row == null:
		return
	if bound_player == null or bound_player.known_abilities.is_empty():
		ability_icon_row.visible = false
		_shown_ability_ids.clear()
		return
	ability_icon_row.visible = true
	var ids: Array[String] = []
	for slot in ability_icon_slots.size():
		var nodes: Dictionary = ability_icon_slots[slot]
		var root := nodes.root as Control
		if slot >= bound_player.known_abilities.size():
			root.visible = false
			continue
		root.visible = true
		var entry: Dictionary = bound_player.known_abilities[slot]
		var ability_id := str(entry.id)
		ids.append(ability_id)
		var icon := nodes.icon as TextureRect
		var name_label := nodes.name as Label
		if slot >= _shown_ability_ids.size() or _shown_ability_ids[slot] != ability_id:
			icon.texture = SpriteLibrary.texture_for(ability_id)
			var info := PlayerClass.ability_info(ability_id)
			name_label.text = _clip_label(str(info.get("name", ability_id)))
		var remaining: float = bound_player.ability_cooldowns[slot] if slot < bound_player.ability_cooldowns.size() else 0.0
		var values := PlayerClass.ability_values(ability_id, int(entry.get("rank", 1)))
		var cooldown_max := maxf(0.01, float(values.get("cooldown", 1.0)))
		_apply_kit_cooldown(nodes, remaining, cooldown_max)
		var armed: bool = int(bound_player.get("_pending_ability_slot")) == slot
		if remaining <= 0.0 and armed:
			icon.modulate = Color(1.15, 1.1, 0.85, 1.0)
	_shown_ability_ids = ids


func _build_aim_reticle() -> void:
	aim_reticle = AimReticle.new()
	aim_reticle.name = "AimReticle"
	aim_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aim_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(aim_reticle)


func _refresh_aim_reticle() -> void:
	var menus_open := shop_panel.visible or escape_menu.visible or upgrade_panel.visible or game_over_label.visible or codex_panel.visible
	var show := bound_player != null and bound_player.is_local_player and not menus_open
	if aim_reticle != null:
		aim_reticle.visible = show
		var reticle := aim_reticle as AimReticle
		if bound_player != null:
			reticle.accent = bound_player.accent_color
			var charging: bool = bool(bound_player.get("_charge_firing"))
			var charge_t: float = bound_player._shot_charge if charging else bound_player._charge_t()
			reticle.charge_t = charge_t
			reticle.show_charge = show and (charge_t > 0.0 or charging)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if show else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func bind_player(player: Player) -> void:
	if bound_player == player:
		return
	bound_player = player
	var health := player.health
	health.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.gold_changed.connect(_on_gold_changed)
	_on_health_changed(health.current_health, health.max_health)
	_on_xp_changed(player.current_xp, player.xp_required, player.level)
	_on_gold_changed(player.gold)
	show_player_class(player.class_id)
	if GameRuntime.is_ffa() and player.team_id != "":
		set_team_health_color(RiftClashManager.team_color(player.team_id))
	_build_shop()


func show_player_class(class_id: String) -> void:
	if class_id == shown_class_id:
		return
	shown_class_id = class_id
	class_label.visible = false
	health_bar.visible = false
	health_label.visible = false
	instructions_label.visible = false


func set_connection_text(_mode: String) -> void:
	pass


func _world_number_for_wave(wave: int) -> int:
	return (maxi(1, wave) - 1) / GameRuntime.BIOME_CYCLE_WAVES + 1


func _set_world_wave(wave: int) -> void:
	_hud_wave = maxi(1, wave)
	var hide := GameRuntime.is_classic()
	if world_label != null:
		world_label.visible = not hide
		world_label.text = "WORLD %d" % _world_number_for_wave(_hud_wave)
	if wave_label != null:
		wave_label.visible = not hide


func set_wave(wave: int, archetype_name: String = "") -> void:
	_set_world_wave(wave)
	if GameRuntime.is_classic():
		return
	var wave_number := maxi(1, wave)
	if archetype_name.is_empty():
		wave_label.text = "WAVE %d" % wave_number
	else:
		wave_label.text = "WAVE %d — %s" % [wave_number, archetype_name.to_upper()]
	var pulse := create_tween()
	pulse.tween_property(wave_label, "scale", Vector2(1.18, 1.18), 0.12)
	pulse.tween_property(wave_label, "scale", Vector2.ONE, 0.18)


func update_boss(boss: Enemy) -> void:
	if boss == null or not is_instance_valid(boss):
		boss_panel.visible = false
		return
	boss_panel.visible = true
	boss_name_label.text = str(EnemyType.by_id(boss.type_id).name).to_upper()
	boss_bar.max_value = boss.health.max_health
	boss_bar.value = boss.health.current_health
	if boss_phase_label != null:
		boss_phase_label.text = "PHASE %d / 3" % clampi(boss.boss_phase, 1, 3)


func announce_wave(wave: int, theme_display_name: String, debut_type_id: String) -> void:
	if GameRuntime.is_classic():
		return
	var is_boss_wave := wave > 0 and wave % WaveDirector.BOSS_WAVE_INTERVAL == 0
	if is_boss_wave:
		theme_banner.text = "BOSS  ·  WAVE %d  ·  %s" % [maxi(1, wave), theme_display_name.to_upper()]
		theme_banner.add_theme_font_size_override("font_size", 42)
		theme_banner.add_theme_color_override("font_color", Color("ff4a4a"))
		_flash(theme_banner, 3.4)
		AudioService.play("boss_alert")
		pulse_danger(2.2)
		debut_banner.visible = false
		return
	theme_banner.add_theme_font_size_override("font_size", 30)
	theme_banner.add_theme_color_override("font_color", Color(1, 0.86, 0.6, 1))
	theme_banner.text = "WAVE %d — %s" % [maxi(1, wave), theme_display_name.to_upper()]
	_flash(theme_banner, 2.6)
	AudioService.play("wave_start")
	if debut_type_id.is_empty():
		debut_banner.visible = false
		return
	debut_banner.text = "NEW ENEMY: %s" % str(EnemyType.by_id(debut_type_id).name).to_upper()
	_flash(debut_banner, 3.2)
	AudioService.play("scan")


## Drop-in beat: "MISSION N — LANDED ON <planet>". Fired on the very first wave and again
## every time the run crosses into a new world (see main.gd's _trigger_world_landing).
## Held title card behind the black warp screen (see main.gd's mission-warp sequence) —
## a real beat instead of the quick 3.4s label flash the wave/debut banners use, since a
## world change deserves to actually read as a destination arrival, not a passing notice.
func announce_mission(mission_number: int, planet_name: String, tagline: String, hold_seconds: float) -> void:
	if GameRuntime.is_classic():
		return
	mission_banner.text = "MISSION %d\nLANDED ON %s" % [maxi(1, mission_number), planet_name.to_upper()]
	mission_subtitle.text = tagline
	for node in [mission_card_bg, mission_banner, mission_subtitle]:
		node.visible = true
		node.modulate.a = 0.0
	var card := create_tween()
	card.tween_property(mission_card_bg, "modulate:a", 1.0, 0.35)
	card.parallel().tween_property(mission_banner, "modulate:a", 1.0, 0.35)
	card.parallel().tween_property(mission_subtitle, "modulate:a", 1.0, 0.35)
	card.tween_interval(hold_seconds)
	card.tween_property(mission_card_bg, "modulate:a", 0.0, 0.4)
	card.parallel().tween_property(mission_banner, "modulate:a", 0.0, 0.4)
	card.parallel().tween_property(mission_subtitle, "modulate:a", 0.0, 0.4)
	card.tween_callback(func() -> void:
		mission_card_bg.visible = false
		mission_banner.visible = false
		mission_subtitle.visible = false
	)
	AudioService.play("scan")


func announce_boss_phase(phase: int, boss_name: String) -> void:
	if GameRuntime.is_classic():
		return
	var titles := {
		2: "THE ARENA BREAKS",
		3: "ENRAGE",
	}
	debut_banner.text = "%s  ·  PHASE %d  ·  %s" % [boss_name.to_upper(), phase, str(titles.get(phase, "PHASE UP"))]
	_flash(debut_banner, 2.8)
	AudioService.play("boss_alert")
	pulse_danger(1.6)


func pulse_danger(seconds: float) -> void:
	if warning_veil == null:
		return
	warning_veil.color = Color(0.62, 0.02, 0.08, 0.0)
	var fade := create_tween()
	fade.tween_property(warning_veil, "color:a", 0.26, 0.12)
	fade.tween_interval(maxf(0.2, seconds))
	fade.tween_property(warning_veil, "color:a", 0.0, 0.35)


## Shown for the whole breather between waves (not just shop breathers), so anyone can cut
## the wait short instead of always sitting out the full intermission timer. `seconds` is the
## full breather length, counted down locally in _process for the "auto in Ns" label.
func show_next_wave_button(value: bool, seconds: float = 0.0) -> void:
	var show := value and not GameRuntime.is_classic()
	next_wave_button.visible = show
	next_wave_timer_label.visible = show
	next_wave_button.disabled = false
	next_wave_button.text = "NEXT WAVE ▶"
	_next_wave_countdown = seconds


## Solo skips the moment it's pressed; co-op needs everyone in, so the label tracks how many
## players have pressed it so far instead of just vanishing on the first click.
func set_next_wave_ready_count(ready_count: int, total_count: int) -> void:
	if total_count <= 1:
		return
	next_wave_button.text = "NEXT WAVE ▶ (%d/%d READY)" % [ready_count, total_count]


func _on_next_wave_pressed() -> void:
	AudioService.play("ui_click")
	next_wave_button.disabled = true
	next_wave_requested.emit()


func _build_boss_overlay() -> void:
	warning_veil = ColorRect.new()
	warning_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning_veil.color = Color(0.62, 0.02, 0.08, 0.0)
	add_child(warning_veil)
	move_child(warning_veil, 0)
	boss_phase_label = Label.new()
	boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_label.add_theme_font_size_override("font_size", 15)
	boss_phase_label.add_theme_color_override("font_color", Color("ffd166"))
	boss_panel.add_child(boss_phase_label)
	boss_bar.custom_minimum_size = Vector2(720.0, 26.0)
	boss_panel.offset_left = 280.0
	boss_panel.offset_right = 1000.0


func _build_chant_overlay() -> void:
	var overlay := Control.new()
	overlay.name = "ChantOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	chant_panel = PanelContainer.new()
	chant_panel.visible = false
	chant_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chant_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	chant_panel.anchor_left = 0.5
	chant_panel.anchor_right = 0.5
	chant_panel.offset_left = -460.0
	chant_panel.offset_right = 460.0
	chant_panel.offset_top = 72.0
	chant_panel.offset_bottom = 268.0
	overlay.add_child(chant_panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	chant_panel.add_child(layout)

	chant_timer_label = Label.new()
	chant_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chant_timer_label.add_theme_font_size_override("font_size", 22)
	chant_timer_label.add_theme_color_override("font_color", Color("ff8a3d"))
	layout.add_child(chant_timer_label)

	chant_words_label = RichTextLabel.new()
	chant_words_label.bbcode_enabled = true
	chant_words_label.fit_content = true
	chant_words_label.scroll_active = false
	chant_words_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chant_words_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chant_words_label.custom_minimum_size = Vector2(880.0, 96.0)
	chant_words_label.add_theme_font_size_override("normal_font_size", 42)
	layout.add_child(chant_words_label)

	chant_hint_label = Label.new()
	chant_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chant_hint_label.add_theme_font_size_override("font_size", 16)
	chant_hint_label.add_theme_color_override("font_color", Color("9aa8b3"))
	layout.add_child(chant_hint_label)


func show_chant(mantra: String, matched: int, seconds_left: float, use_mic: bool) -> void:
	if chant_panel == null:
		return
	chant_panel.visible = true
	var words := mantra.split(" ", false)
	var parts: PackedStringArray = []
	for index in words.size():
		var color := "ffd36b" if index < matched else "e8eef5"
		parts.append("[color=#%s][b]%s[/b][/color]" % [color, str(words[index]).to_upper()])
	chant_words_label.text = " ".join(parts)
	chant_timer_label.text = "%.1fs" % maxf(0.0, seconds_left)
	if use_mic:
		chant_hint_label.text = "Say the chant word by word. ENTER also confirms a word."
	else:
		chant_hint_label.text = "No microphone. ENTER confirms the next word."


func hide_chant() -> void:
	if chant_panel != null:
		chant_panel.visible = false


func _flash(label: Label, seconds: float) -> void:
	label.visible = true
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var fade := create_tween()
	fade.tween_property(label, "modulate:a", 1.0, 0.25)
	fade.tween_interval(seconds)
	fade.tween_property(label, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func() -> void: label.visible = false)


func open_shop(pause_game: bool) -> void:
	if GameRuntime.is_classic():
		return
	shop_pauses_game = pause_game
	shop_panel.visible = true
	_refresh_shop()
	AudioService.play("shop_open")
	if shop_pauses_game:
		get_tree().paused = true


func close_shop() -> void:
	if not shop_panel.visible:
		return
	shop_panel.visible = false
	AudioService.play("shop_close")
	if shop_pauses_game:
		get_tree().paused = false
	shop_pauses_game = false


## Static reference text, built once — enemies, shop items, and every class's upgrade pool.
func _build_codex_text() -> String:
	var lines: Array[String] = []

	lines.append("[b][color=ff8f7a]ENEMIES[/color][/b]")
	for type_data in EnemyType.TYPES:
		var tag := " [color=ffd166](boss)[/color]" if bool(type_data.get("is_boss", false)) else ""
		lines.append(
			"[b]%s[/b]%s — %d HP, %d speed, wave %d+" % [
				EnemyType.display_name(type_data),
				tag,
				int(type_data.max_health),
				int(type_data.movement_speed),
				int(type_data.unlock_wave),
			]
		)

	lines.append("")
	lines.append("[b][color=ffd166]SUPERMERCATOR[/color][/b]")
	for class_id in PlayerClass.playable_ids():
		lines.append("[b]%s[/b]" % PlayerClass.by_id(class_id).name)
		for item in ShopCatalog.items_for(class_id):
			var item_id := str(item.id)
			lines.append(
				"  [b]%s[/b] (%dg) — %s" % [
					ShopCatalog.display_name(item_id, class_id),
					ShopCatalog.price_for(item_id, 0),
					ShopCatalog.display_description(item_id, class_id),
				]
			)

	lines.append("")
	lines.append("[b][color=6fd6ff]STAT UPGRADES[/color][/b]  (elke level-up)")
	for class_data in PlayerClass.CLASSES:
		if str(class_data.id) != PlayerClass.DEFAULT_CLASS_ID:
			continue
		for upgrade_id in class_data.upgrades:
			var upgrade := PlayerClass.upgrade_info(str(upgrade_id))
			lines.append("  [b]%s[/b] — %s" % [str(upgrade.name), str(upgrade.description)])

	return "\n".join(lines)


const SHOP_ICON_MAX_WIDTH := 72

func _build_shop() -> void:
	for child in shop_grid.get_children():
		shop_grid.remove_child(child)
		child.free()
	shop_buttons.clear()
	var class_id := bound_player.class_id if bound_player != null else PlayerClass.DEFAULT_CLASS_ID
	for item in ShopCatalog.items_for(class_id):
		var item_id := str(item.id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(300.0, 128.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.icon = SpriteLibrary.item_icon(item_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", SHOP_ICON_MAX_WIDTH)
		button.pressed.connect(_on_shop_item_pressed.bind(item_id))
		shop_grid.add_child(button)
		shop_buttons[item_id] = button


func _refresh_shop() -> void:
	var gold := bound_player.gold if bound_player != null else 0
	var class_id := bound_player.class_id if bound_player != null else PlayerClass.DEFAULT_CLASS_ID
	shop_gold_label.text = "%d GOLD" % gold
	for item in ShopCatalog.items_for(class_id):
		var item_id := str(item.id)
		if not shop_buttons.has(item_id):
			continue
		var button := shop_buttons[item_id] as Button
		var stacks := bound_player.stacks_of(item_id) if bound_player != null else 0
		var item_name := ShopCatalog.display_name(item_id, class_id)
		var item_description := ShopCatalog.display_description(item_id, class_id)
		if ShopCatalog.is_sold_out(item_id, stacks):
			button.text = "%s\nSOLD OUT\n%s" % [item_name, item_description]
			button.disabled = true
			continue
		var price := ShopCatalog.price_for(item_id, stacks)
		var cap := int(item.max_stacks)
		button.text = "%s  %d/%d\n%s\n%d gold" % [item_name, stacks, cap, item_description, price]
		button.disabled = gold < price


func _on_shop_item_pressed(item_id: String) -> void:
	AudioService.play("ui_click")
	shop_item_chosen.emit(item_id)


func _on_shop_continue_pressed() -> void:
	AudioService.play("ui_click")
	close_shop()
	shop_closed.emit()


func show_game_over() -> void:
	if game_over_label.visible:
		return
	close_shop()
	game_over_label.visible = true
	AudioService.play("game_over")


func _build_ffa_overlay() -> void:
	rift_banner = Label.new()
	rift_banner.name = "RiftBanner"
	rift_banner.visible = false
	rift_banner.position = Vector2(12, 8)
	rift_banner.add_theme_font_size_override("font_size", 16)
	rift_banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	rift_banner.add_theme_constant_override("shadow_size", 3)
	add_child(rift_banner)
	ffa_board_bg = ColorRect.new()
	ffa_board_bg.name = "FfaBoardBg"
	ffa_board_bg.visible = false
	ffa_board_bg.color = Color(0.04, 0.05, 0.08, 0.72)
	ffa_board_bg.position = Vector2(8, 8)
	ffa_board_bg.size = Vector2(268, 152)
	add_child(ffa_board_bg)
	ffa_scoreboard = VBoxContainer.new()
	ffa_scoreboard.name = "FfaScoreboard"
	ffa_scoreboard.visible = false
	ffa_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ffa_scoreboard.position = Vector2(12, 10)
	ffa_scoreboard.size = Vector2(260, 148)
	ffa_scoreboard.add_theme_constant_override("separation", 2)
	add_child(ffa_scoreboard)
	var title := Label.new()
	title.text = "LEADERBOARD"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98, 1.0))
	ffa_scoreboard.add_child(title)
	ffa_row_box = VBoxContainer.new()
	ffa_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ffa_row_box.add_theme_constant_override("separation", 3)
	ffa_scoreboard.add_child(ffa_row_box)


func _hero_portrait(class_id: String) -> Texture2D:
	if class_id == "tobor":
		return SpriteLibrary.compose_tobor({})
	return SpriteLibrary.texture_for(class_id)


func set_team_health_color(color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("fill", fill)


func refresh_rift_clash_banner(team_name: String, corner: String, color: Color) -> void:
	if rift_banner == null:
		return
	rift_banner.visible = true
	rift_banner.text = "%s · %s" % [team_name.to_upper(), corner]
	rift_banner.add_theme_color_override("font_color", color)


func refresh_ffa_scoreboard(rows: Array) -> void:
	if ffa_scoreboard == null or ffa_row_box == null:
		return
	if rows.is_empty():
		ffa_scoreboard.visible = false
		if ffa_board_bg != null:
			ffa_board_bg.visible = false
		return
	ffa_scoreboard.visible = true
	if ffa_board_bg != null:
		ffa_board_bg.visible = true
	for child in ffa_row_box.get_children():
		ffa_row_box.remove_child(child)
		child.queue_free()
	for row in rows:
		var color := row.get("color", Color.WHITE) as Color
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _hero_portrait(str(row.get("class_id", "tobor")))
		line.add_child(icon)
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = str(row.get("name", "?"))
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", color)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(row.get("local", false)):
			name_label.text += "  you"
		if not bool(row.get("alive", true)):
			name_label.modulate = Color(0.7, 0.72, 0.76, 1.0)
		line.add_child(name_label)
		var kills_label := Label.new()
		kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kills_label.custom_minimum_size = Vector2(36, 0)
		kills_label.text = str(int(row.get("kills", 0)))
		kills_label.add_theme_font_size_override("font_size", 15)
		kills_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0) if bool(row.get("alive", true)) else Color(0.72, 0.74, 0.78, 1.0))
		kills_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(kills_label)
		ffa_row_box.add_child(line)
	var row_count := maxi(rows.size(), 1)
	if ffa_board_bg != null:
		ffa_board_bg.size = Vector2(268, 28.0 + float(row_count) * 30.0)


func show_rift_clash_result(placement: int, _field: int, winner_name: String, _delta: int, _total: int) -> void:
	close_shop()
	game_over_label.visible = true
	if placement == 1:
		game_over_label.text = "%s WINS\nFirst to %d kills" % [winner_name.to_upper(), GameRuntime.FFA_KILLS_TO_WIN]
	else:
		game_over_label.text = "%s WINS\nYou placed #%d\nPress R to restart" % [winner_name.to_upper(), placement]
	AudioService.play("game_over")


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "HP %d / %d" % [ceili(current_health), ceili(max_health)]


func _on_gold_changed(gold: int) -> void:
	gold_label.visible = not GameRuntime.is_classic()
	gold_label.text = "%d GOLD" % gold
	if _last_gold >= 0 and gold > _last_gold:
		AudioService.play("gold")
	_last_gold = gold


func _on_xp_changed(current_xp: int, required_xp: int, next_level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	level_label.text = "LVL %d   %d / %d XP" % [next_level, current_xp, required_xp]


func show_upgrade_ids(player: Player, upgrade_ids: Array[String], pause_game: bool) -> void:
	bound_player = player
	offered_upgrade_ids = upgrade_ids.duplicate()
	offer_kind = "stat"
	pauses_game = pause_game
	offer_title_label.text = "PICK  1  2  3  4"
	for index in choice_buttons.size():
		if index >= offered_upgrade_ids.size():
			choice_buttons[index].visible = false
			continue
		var upgrade := PlayerClass.upgrade_info(offered_upgrade_ids[index])
		choice_buttons[index].visible = true
		choice_buttons[index].text = "[%d]  %s\n%s" % [index + 1, upgrade.name, upgrade.description]
		choice_buttons[index].icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(offered_upgrade_ids[index])
	upgrade_panel.visible = true
	InputService.block_ability_slots = true
	AudioService.play("level_up")
	if pauses_game:
		get_tree().paused = true


## Odd level-ups: a mix of not-yet-known abilities (learn) and already-known ones that still
## have rank to give (upgrade) — see PlayerClass.ability_offer_ids for how the mix is built.
func show_ability_offer(player: Player, ability_ids: Array[String], pause_game: bool) -> void:
	bound_player = player
	offered_upgrade_ids = ability_ids.duplicate()
	offer_kind = "ability"
	pauses_game = pause_game
	offer_title_label.text = "PICK  1  2  3  4"
	for index in choice_buttons.size():
		if index >= offered_upgrade_ids.size():
			choice_buttons[index].visible = false
			continue
		var ability_id := offered_upgrade_ids[index]
		var current_rank := 0
		for entry in player.known_abilities:
			if entry.id == ability_id:
				current_rank = int(entry.rank)
				break
		var info := PlayerClass.ability_info(ability_id)
		var ability_name := str(info.get("name", ability_id))
		var verb := "Upgrade" if current_rank > 0 else "Learn"
		choice_buttons[index].visible = true
		choice_buttons[index].text = "[%d]  %s %s" % [index + 1, verb, ability_name]
		choice_buttons[index].icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(ability_id)
	upgrade_panel.visible = true
	InputService.block_ability_slots = true
	AudioService.play("level_up")
	if pauses_game:
		get_tree().paused = true


func _on_upgrade_selected(index: int) -> void:
	if index >= offered_upgrade_ids.size():
		return
	AudioService.play("ui_click")
	var chosen_id := offered_upgrade_ids[index]
	var chosen_kind := offer_kind
	upgrade_panel.visible = false
	offered_upgrade_ids.clear()
	InputService.block_ability_slots = false
	if pauses_game:
		get_tree().paused = false
	pauses_game = false
	if chosen_kind == "ability":
		ability_chosen.emit(chosen_id)
	else:
		upgrade_chosen.emit(chosen_id)


class AimReticle extends Control:
	var accent := Color(0.95, 0.95, 0.98, 0.95)
	var charge_t := 0.0
	var show_charge := false

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p := get_local_mouse_position()
		var ring := accent
		ring.a = 0.9
		draw_arc(p, 11.0, 0.0, TAU, 28, ring, 1.6, true)
		draw_arc(p, 3.2, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.85), 1.2, true)
		var tick := Color(1.0, 1.0, 1.0, 0.8)
		draw_line(p + Vector2(0.0, -15.0), p + Vector2(0.0, -7.0), tick, 1.4)
		draw_line(p + Vector2(0.0, 7.0), p + Vector2(0.0, 15.0), tick, 1.4)
		draw_line(p + Vector2(-15.0, 0.0), p + Vector2(-7.0, 0.0), tick, 1.4)
		draw_line(p + Vector2(7.0, 0.0), p + Vector2(15.0, 0.0), tick, 1.4)
		if not show_charge:
			return
		var bar_w := 28.0
		var bar_h := 4.0
		var origin := p + Vector2(-bar_w * 0.5, 18.0)
		draw_rect(Rect2(origin, Vector2(bar_w, bar_h)), Color(0.05, 0.06, 0.08, 0.85))
		var fill := accent
		fill.a = 0.95
		draw_rect(Rect2(origin + Vector2(1.0, 1.0), Vector2((bar_w - 2.0) * clampf(charge_t, 0.0, 1.0), bar_h - 2.0)), fill)

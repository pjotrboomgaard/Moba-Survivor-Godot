class_name GameHUD
extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)
signal ability_chosen(ability_id: String)
signal shop_item_chosen(item_id: String)
signal restart_requested
signal leave_requested
signal dev_command(command: String)
signal next_wave_requested
## Asks main.gd to pause/resume — in co-op that's a request to the server, which owns the
## actual pause for everyone, so the HUD never touches get_tree().paused itself for this.
signal pause_requested(value: bool)

const UPGRADE_ICON_MAX_WIDTH := 40

## Scannable colour coding for tooltip stat lines — kept separate from any hero/team colour.
const COLOR_DAMAGE := "ff6b5c"
const COLOR_HEAL := "7cd6a0"
const COLOR_CONTROL := "8ab4e8"
const COLOR_BUFF := "e0b667"
const COLOR_SHIELD := "b99cf0"
const COLOR_NEUTRAL := "9aa0ad"
const COLOR_FLAVOR := "6c7280"

@onready var class_label: Label = $TopBar/TopLayout/Title
@onready var controls_hint: Label = $TopBar/TopLayout/ControlsHint
@onready var health_bar: ProgressBar = $VitalsCluster/HealthRow/HealthBar
@onready var health_label: Label = $VitalsCluster/HealthRow/HealthLabel
@onready var game_over_label: Label = $GameOver
@onready var downed_label: Label = $DownedLabel
@onready var coop_paused_label: Label = $CoopPausedLabel
@onready var xp_bar: ProgressBar = $VitalsCluster/XPRow/XPBar
@onready var level_label: Label = $VitalsCluster/LevelLabel
@onready var connection_label: Label = $StatusCluster/ConnectionLabel
@onready var wave_label: Label = $StatusCluster/WaveLabel
@onready var next_wave_button: Button = $NextWaveButton
@onready var next_wave_timer_label: Label = $NextWaveTimer
@onready var boss_panel: VBoxContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var gold_label: Label = $StatusCluster/GoldLabel
@onready var ability_status_label: Label = $AbilityStatusLabel
@onready var theme_banner: Label = $ThemeBanner
@onready var debut_banner: Label = $DebutBanner
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var shop_gold_label: Label = $ShopPanel/ShopLayout/ShopGold
@onready var shop_categories: VBoxContainer = $ShopPanel/ShopLayout/ShopCategories
@onready var shop_close_button: Button = $ShopPanel/ShopLayout/ShopHeader/ShopCloseButton
@onready var offer_title_label: Label = $OfferTitle
@onready var ability_offer_bar: HBoxContainer = $AbilityOfferBar
@onready var offer_buttons: Array[Button] = [
	$AbilityOfferBar/OfferChoice1,
	$AbilityOfferBar/OfferChoice2,
	$AbilityOfferBar/OfferChoice3,
	$AbilityOfferBar/OfferChoice4,
]
@onready var ability_bar: HBoxContainer = $AbilityBar
@onready var ability_slot_buttons: Array[Button] = [
	$AbilityBar/AbilitySlot0,
	$AbilityBar/AbilitySlot1,
	$AbilityBar/AbilitySlot2,
	$AbilityBar/AbilitySlot3,
]
@onready var tooltip: PanelContainer = $Tooltip
@onready var tooltip_text: RichTextLabel = $Tooltip/TooltipMargin/TooltipText
@onready var escape_menu: PanelContainer = $EscapeMenu
@onready var resume_button: Button = $EscapeMenu/EscapeLayout/ResumeButton
@onready var restart_button: Button = $EscapeMenu/EscapeLayout/RestartButton
@onready var leave_button: Button = $EscapeMenu/EscapeLayout/LeaveButton
@onready var dev_panel: PanelContainer = $DevPanel
@onready var dev_add_xp_button: Button = $DevPanel/DevLayout/DevButtons/AddXPButton
@onready var dev_add_levels_button: Button = $DevPanel/DevLayout/DevButtons/AddLevelsButton
@onready var dev_spawn_elite_button: Button = $DevPanel/DevLayout/DevButtons/SpawnEliteButton
@onready var dev_invulnerable_button: Button = $DevPanel/DevLayout/DevButtons/InvulnerableButton
@onready var codex_panel: PanelContainer = $CodexPanel
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
var _next_wave_countdown := 0.0
## Whether a NEXT WAVE skip is available at all this breather — separate from the button's
## actual on-screen visibility, which also depends on the shop panel being closed (see
## _update_next_wave_visibility) so the two never overlap on screen.
var _next_wave_available := false
## Set by show_ability_offer for the duration of the current offer — _on_offer_hover can't
## re-derive this from the offered ids the way _on_ability_slot_hover derives it from a slot
## index, since a fresh ultimate pick isn't in known_abilities yet to look a slot up from.
var _offer_is_ultimate := false


func _ready() -> void:
	for index in offer_buttons.size():
		var choice_button := offer_buttons[index]
		choice_button.pressed.connect(_on_upgrade_selected.bind(index))
		choice_button.mouse_entered.connect(_on_offer_hover.bind(index))
		choice_button.mouse_exited.connect(_hide_tooltip)
		choice_button.expand_icon = true
		choice_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		choice_button.add_theme_constant_override("icon_max_width", UPGRADE_ICON_MAX_WIDTH)
	for index in ability_slot_buttons.size():
		var slot_button := ability_slot_buttons[index]
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.expand_icon = true
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_button.mouse_entered.connect(_on_ability_slot_hover.bind(index))
		slot_button.mouse_exited.connect(_hide_tooltip)
	controls_hint.mouse_entered.connect(_on_controls_hint_hover)
	controls_hint.mouse_exited.connect(_hide_tooltip)
	shop_close_button.pressed.connect(_on_shop_close_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	dev_add_xp_button.pressed.connect(_on_dev_button_pressed.bind("add_xp"))
	dev_add_levels_button.pressed.connect(_on_dev_button_pressed.bind("add_5_levels"))
	dev_spawn_elite_button.pressed.connect(_on_dev_button_pressed.bind("spawn_elite"))
	dev_invulnerable_button.pressed.connect(_on_dev_button_pressed.bind("toggle_invulnerable"))
	next_wave_button.pressed.connect(_on_next_wave_pressed)
	codex_text.text = _build_codex_text()
	_build_shop()


func _unhandled_input(event: InputEvent) -> void:
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
	if event.is_action_pressed("codex_toggle"):
		codex_panel.visible = not codex_panel.visible
		return
	if not event.is_action_pressed("pause_menu"):
		return
	if escape_menu.visible:
		_close_escape_menu()
	elif not shop_panel.visible and not ability_offer_bar.visible and not game_over_label.visible:
		_open_escape_menu()


func _open_escape_menu() -> void:
	## Restarting is host-authoritative (see main.gd's _request_restart) — a client restarting
	## on its own would be playing a fresh run against a server still in the old one, so it
	## doesn't get the button at all.
	var can_restart := GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE or GameRuntime.is_server()
	restart_button.visible = can_restart
	restart_button.text = "RESTART SOLO RUN" if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE else "RESTART RUN (ALL PLAYERS)"
	escape_menu.visible = true
	## Opening the pause menu pauses the run for everyone in co-op too, not just solo — the
	## request goes to the server, which owns the actual pause (see main.gd's request_pause).
	_escape_paused = true
	pause_requested.emit(true)


func _close_escape_menu() -> void:
	escape_menu.visible = false
	if _escape_paused:
		_escape_paused = false
		pause_requested.emit(false)


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
	if _next_wave_available:
		## Ticks on real elapsed time regardless of on-screen visibility — the button can be
		## hidden behind the shop panel for a while and reappear, and the countdown it shows
		## must match the breather's actual remaining time at that point, not restart from
		## wherever it was when it went out of view.
		_next_wave_countdown = maxf(0.0, _next_wave_countdown - delta)
		next_wave_timer_label.text = "auto in %ds" % ceili(_next_wave_countdown)
	_refresh_ability_status()
	_refresh_ability_bar()


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
	if bound_player.health.damage_taken_multiplier < 1.0:
		lines.append("Damage taken: x%.2f" % bound_player.health.damage_taken_multiplier)
	if bound_player.lifesteal_ratio > 0.0:
		lines.append("Lifesteal: %d%%" % roundi(bound_player.lifesteal_ratio * 100.0))
	if bound_player.thorns_ratio > 0.0:
		lines.append("Thorns: %d%%" % roundi(bound_player.thorns_ratio * 100.0))
	if bound_player.knockback_strength > 0.0:
		lines.append("Knockback: yes")
	if bound_player.hit_slow_factor < 1.0:
		lines.append("Hit slow: %d%%" % roundi((1.0 - bound_player.hit_slow_factor) * 100.0))
	lines.append("Gold: %d" % bound_player.gold)
	return "\n".join(lines)


func _refresh_dev_panel() -> void:
	if bound_player == null:
		return
	dev_invulnerable_button.text = "INVULNERABLE: %s" % ("ON" if bound_player.health.invulnerable else "OFF")


func _refresh_ability_status() -> void:
	if bound_player == null or not bound_player.has_active_item():
		ability_status_label.visible = false
		return
	ability_status_label.visible = true
	if bound_player.is_sprinting():
		ability_status_label.text = "SPACE  DASHING"
		ability_status_label.add_theme_color_override("font_color", Color("ffe08c"))
	elif bound_player.sprint_cooldown > 0.0:
		ability_status_label.text = "SPACE  %.1fs" % bound_player.sprint_cooldown
		ability_status_label.add_theme_color_override("font_color", Color("7b8496"))
	else:
		ability_status_label.text = "SPACE  DASH READY"
		ability_status_label.add_theme_color_override("font_color", Color("94ddff"))


const ABILITY_SLOT_KEYS := ["Q", "E", "F", "R"]


## Compact icon + key-letter + live cooldown for each of the four ability slots — the R slot
## (PlayerClass.ULTIMATE_SLOT) is drawn slightly larger since it's the hero's ultimate. Full
## detail (name, rank, description, colour-coded numbers) only shows up on hover, see
## _on_ability_slot_hover.
func _refresh_ability_bar() -> void:
	if bound_player == null:
		return
	for slot in ability_slot_buttons.size():
		var button := ability_slot_buttons[slot]
		var entry: Dictionary = bound_player.known_abilities[slot] if slot < bound_player.known_abilities.size() else {}
		if entry.is_empty():
			button.text = ABILITY_SLOT_KEYS[slot]
			button.icon = null
			button.disabled = true
			button.modulate = Color(1.0, 1.0, 1.0, 0.35)
			continue
		button.disabled = false
		button.modulate = Color.WHITE
		var ability_id := str(entry.id)
		button.icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(ability_id)
		var cooldown_left := bound_player.ability_cooldowns[slot] if slot < bound_player.ability_cooldowns.size() else 0.0
		if cooldown_left > 0.0:
			button.text = "%.1f" % cooldown_left
			button.modulate = Color(1.0, 1.0, 1.0, 0.55)
		else:
			button.text = ABILITY_SLOT_KEYS[slot]


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


func show_player_class(class_id: String) -> void:
	if class_id == shown_class_id:
		return
	shown_class_id = class_id
	var class_data := PlayerClass.by_id(class_id)
	class_label.text = "%s // %s" % [str(class_data.name).to_upper(), str(class_data.role).to_upper()]
	class_label.add_theme_color_override("font_color", Color(class_data.accent_color))


func set_connection_text(mode: String) -> void:
	connection_label.text = mode.to_upper()


func set_wave(wave: int, archetype_name: String = "") -> void:
	if GameRuntime.is_classic():
		wave_label.visible = false
		return
	wave_label.visible = true
	var wave_number := maxi(1, wave)
	if archetype_name.is_empty():
		wave_label.text = "WAVE %d" % wave_number
	else:
		wave_label.text = "WAVE %d — %s" % [wave_number, archetype_name.to_upper()]
	if WaveDirector.shop_opens_before(wave_number + 1):
		wave_label.text += "   SHOP NEXT"
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


func announce_wave(wave: int, theme_display_name: String, debut_type_id: String) -> void:
	if GameRuntime.is_classic():
		return
	theme_banner.text = "WAVE %d — %s" % [maxi(1, wave), theme_display_name.to_upper()]
	_flash(theme_banner, 2.6)
	AudioService.play("wave_start")
	if debut_type_id.is_empty():
		debut_banner.visible = false
		return
	debut_banner.text = "NEW ENEMY: %s" % str(EnemyType.by_id(debut_type_id).name).to_upper()
	_flash(debut_banner, 3.2)
	AudioService.play("boss_alert")


## Shown for the whole breather between waves (not just shop breathers), so anyone can cut
## the wait short instead of always sitting out the full intermission timer. `seconds` is the
## full breather length, counted down locally in _process for the "auto in Ns" label.
func show_next_wave_button(value: bool, seconds: float = 0.0) -> void:
	_next_wave_available = value and not GameRuntime.is_classic()
	next_wave_button.disabled = false
	next_wave_button.text = "NEXT WAVE ▶"
	_next_wave_countdown = seconds
	_update_next_wave_visibility()


## Every shop breather is also a wave breather, so the skip option is available the whole time
## — it just stays hidden behind the shop panel while that's open, to avoid stacking two
## controls that do a similar job on top of each other on screen.
func _update_next_wave_visibility() -> void:
	var show := _next_wave_available and not shop_panel.visible
	next_wave_button.visible = show
	next_wave_timer_label.visible = show


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
	_update_next_wave_visibility()
	AudioService.play("shop_open")
	if shop_pauses_game:
		get_tree().paused = true


func close_shop() -> void:
	if not shop_panel.visible:
		return
	shop_panel.visible = false
	_update_next_wave_visibility()
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
				str(type_data.name),
				tag,
				int(type_data.max_health),
				int(type_data.movement_speed),
				int(type_data.unlock_wave),
			]
		)

	lines.append("")
	lines.append("[b][color=ffd166]SHOP ITEMS[/color][/b]")
	for item in ShopCatalog.ITEMS:
		lines.append("[b]%s[/b] (%dg+) — %s" % [str(item.name), int(item.base_price), str(item.description)])

	lines.append("")
	lines.append("[b][color=6fd6ff]STAT UPGRADES[/color][/b]  (every even level-up)")
	for class_data in PlayerClass.CLASSES:
		lines.append("[i]%s[/i]" % str(class_data.name).to_upper())
		for upgrade_id in class_data.upgrades:
			var upgrade := PlayerClass.upgrade_info(str(upgrade_id))
			lines.append("  [b]%s[/b] — %s" % [str(upgrade.name), str(upgrade.description)])

	lines.append("")
	lines.append("[b][color=c8a4ff]ABILITIES[/color][/b]  Q/E/F learn and rank up on every odd level-up. R is the ultimate — it only appears on level %d, %d, %d... — up to 4 known." % [PlayerClass.ULTIMATE_LEVEL_INTERVAL, PlayerClass.ULTIMATE_LEVEL_INTERVAL * 2, PlayerClass.ULTIMATE_LEVEL_INTERVAL * 3])
	for class_data in PlayerClass.CLASSES:
		lines.append("[i]%s[/i]" % str(class_data.name).to_upper())
		for ability_id in class_data.ability_pool:
			var ability := PlayerClass.ability_info(str(ability_id))
			lines.append("  [b]%s[/b] — %s" % [str(ability.name), str(ability.description)])

	return "\n".join(lines)


const SHOP_ICON_MAX_WIDTH := 30
const SHOP_CATEGORY_COLUMNS := 3

## One header + grid per ShopCatalog.CATEGORIES entry, built from the category list itself
## rather than one node per category in the scene — a 5th category needs no scene changes.
func _build_shop() -> void:
	for category in ShopCatalog.CATEGORIES:
		var items := ShopCatalog.for_category(category)
		if items.is_empty():
			continue
		var header := Label.new()
		header.text = str(ShopCatalog.CATEGORY_LABELS.get(category, category)).to_upper()
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color("9aa0ad"))
		shop_categories.add_child(header)

		var grid := GridContainer.new()
		grid.columns = SHOP_CATEGORY_COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		shop_categories.add_child(grid)

		for item in items:
			var button := Button.new()
			var item_id := str(item.id)
			button.custom_minimum_size = Vector2(150.0, 52.0)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 12)
			button.icon = SpriteLibrary.texture_for(item_id)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", SHOP_ICON_MAX_WIDTH)
			button.pressed.connect(_on_shop_item_pressed.bind(item_id))
			button.mouse_entered.connect(_on_shop_item_hover.bind(item_id))
			button.mouse_exited.connect(_hide_tooltip)
			grid.add_child(button)
			shop_buttons[item_id] = button


func _refresh_shop() -> void:
	var gold := bound_player.gold if bound_player != null else 0
	shop_gold_label.text = "%d GOLD" % gold
	for item in ShopCatalog.ITEMS:
		var item_id := str(item.id)
		var button := shop_buttons[item_id] as Button
		var stacks := bound_player.stacks_of(item_id) if bound_player != null else 0
		if ShopCatalog.is_sold_out(item_id, stacks):
			button.text = "%s\nSOLD OUT" % item.name
			button.disabled = true
			continue
		var price := ShopCatalog.price_for(item_id, stacks)
		var owned := "" if stacks == 0 else "  (owned %d)" % stacks
		button.text = "%s\n%d gold%s" % [item.name, price, owned]
		button.disabled = gold < price


func _on_shop_item_hover(item_id: String) -> void:
	_show_tooltip(_item_tooltip_bbcode(item_id), shop_buttons[item_id])


func _on_shop_item_pressed(item_id: String) -> void:
	AudioService.play("ui_click")
	shop_item_chosen.emit(item_id)


## Closing the shop never skips the breather — the shop panel has no wave-progression control
## of its own any more, that's what the shared NEXT WAVE button (see show_next_wave_button) is
## for, and it's already available underneath: opening the shop just hides it, closing reveals
## it again, see _update_next_wave_visibility.
func _on_shop_close_pressed() -> void:
	AudioService.play("ui_click")
	close_shop()


## The run is over for everyone. Solo can restart in place; in co-op only the host can, so the
## prompt has to match what the key actually does instead of always promising R.
func show_game_over() -> void:
	if game_over_label.visible:
		return
	close_shop()
	downed_label.visible = false
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		game_over_label.text = "YOU FELL\nPress R to restart"
	elif GameRuntime.is_server():
		game_over_label.text = "THE PARTY FELL\nPress R to restart the run"
	else:
		game_over_label.text = "THE PARTY FELL\nWaiting for the host to restart..."
	game_over_label.visible = true
	AudioService.play("game_over")


func hide_game_over() -> void:
	game_over_label.visible = false


## Someone paused the run for the whole party. Solo pauses silently (the menu itself is the
## indication); in co-op the banner names who, so the other players know why the world stopped
## rather than assuming they've lagged out.
func set_coop_paused(value: bool, holder_names: String) -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		coop_paused_label.visible = false
		return
	coop_paused_label.visible = value
	if not value:
		return
	if holder_names.is_empty():
		coop_paused_label.text = "PAUSED"
	else:
		coop_paused_label.text = "PAUSED BY %s" % holder_names.to_upper()


## Downed but revivable — distinct from show_game_over above, which is the whole run ending.
## A teammate holding position next to you fills the ring drawn on your body (Player._draw).
func set_downed(value: bool) -> void:
	if game_over_label.visible:
		downed_label.visible = false
		return
	downed_label.visible = value


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "%d / %d" % [ceili(current_health), ceili(max_health)]


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
	offer_title_label.text = "UPGRADE A STAT"
	offer_title_label.visible = true
	for index in offer_buttons.size():
		if index >= offered_upgrade_ids.size():
			offer_buttons[index].visible = false
			continue
		var upgrade := PlayerClass.upgrade_info(offered_upgrade_ids[index])
		offer_buttons[index].visible = true
		offer_buttons[index].text = str(upgrade.name)
		offer_buttons[index].icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(offered_upgrade_ids[index])
	ability_offer_bar.visible = true
	AudioService.play("level_up")
	if pauses_game:
		get_tree().paused = true


## Odd level-ups: a mix of not-yet-known abilities (learn) and already-known ones that still
## have rank to give (upgrade) — see PlayerClass.ability_offer_ids for how the mix is built.
## `is_ultimate_offer` comes straight from main.gd's own milestone-level check at the moment the
## offer was generated — it can't be re-derived from the ability ids here, since a fresh
## ultimate pick is (by definition) not yet in the player's known_abilities to look up a slot for.
func show_ability_offer(player: Player, ability_ids: Array[String], pause_game: bool, is_ultimate_offer: bool = false) -> void:
	bound_player = player
	offered_upgrade_ids = ability_ids.duplicate()
	offer_kind = "ability"
	pauses_game = pause_game
	_offer_is_ultimate = is_ultimate_offer
	offer_title_label.text = "CHOOSE YOUR ULTIMATE" if is_ultimate_offer else "LEARN OR UPGRADE AN ABILITY"
	offer_title_label.visible = true
	for index in offer_buttons.size():
		if index >= offered_upgrade_ids.size():
			offer_buttons[index].visible = false
			continue
		var ability_id := offered_upgrade_ids[index]
		var current_rank := _known_rank(player, ability_id)
		var target_rank := current_rank + 1 if current_rank > 0 else 1
		offer_buttons[index].visible = true
		offer_buttons[index].text = "%s\n%s" % [str(PlayerClass.ability_info(ability_id).name), ("Rk %d" % target_rank) if current_rank > 0 else "NEW"]
		offer_buttons[index].icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(ability_id)
	ability_offer_bar.visible = true
	AudioService.play("level_up")
	if pauses_game:
		get_tree().paused = true


func _known_rank(player: Player, ability_id: String) -> int:
	for entry in player.known_abilities:
		if not entry.is_empty() and entry.id == ability_id:
			return int(entry.rank)
	return 0


func _on_upgrade_selected(index: int) -> void:
	if index >= offered_upgrade_ids.size():
		return
	AudioService.play("ui_click")
	var chosen_id := offered_upgrade_ids[index]
	var chosen_kind := offer_kind
	ability_offer_bar.visible = false
	offer_title_label.visible = false
	offered_upgrade_ids.clear()
	_hide_tooltip()
	if pauses_game:
		get_tree().paused = false
	pauses_game = false
	if chosen_kind == "ability":
		ability_chosen.emit(chosen_id)
	else:
		upgrade_chosen.emit(chosen_id)


## --- Hover tooltips -------------------------------------------------------------------------
## One shared panel, repositioned above whatever is currently hovered. Colour coding lets the
## numbers get scanned at a glance instead of read word by word: red is damage, green is
## healing/lifesteal, blue is control (slow/stun), gold is a timed buff, purple is a shield.

func _show_tooltip(bbcode: String, anchor: Control) -> void:
	tooltip_text.text = bbcode
	tooltip.visible = true
	await get_tree().process_frame
	var anchor_top_left := anchor.get_global_rect().position
	var target := anchor_top_left + Vector2(anchor.size.x * 0.5 - tooltip.size.x * 0.5, -tooltip.size.y - 10.0)
	target.x = clampf(target.x, 12.0, 1280.0 - tooltip.size.x - 12.0)
	target.y = maxf(12.0, target.y)
	tooltip.position = target


func _hide_tooltip() -> void:
	tooltip.visible = false


func _on_controls_hint_hover() -> void:
	var class_data := PlayerClass.by_id(shown_class_id) if not shown_class_id.is_empty() else {}
	var weapon_name := str(class_data.get("weapon_name", "your weapon"))
	var lines := [
		"[b]Controls[/b]",
		"[color=%s]WASD[/color]  Move" % COLOR_NEUTRAL,
		"[color=%s]Mouse[/color]  Aim, hold left button to use %s" % [COLOR_NEUTRAL, weapon_name],
		"[color=%s]Q E F[/color]  Abilities" % COLOR_NEUTRAL,
		"[color=%s]R[/color]  Ultimate — unlocks level %d" % [COLOR_BUFF, PlayerClass.ULTIMATE_LEVEL_INTERVAL],
		"[color=%s]Space[/color]  Dash (once you own an active item)" % COLOR_NEUTRAL,
		"[color=%s]Shift[/color]  Hold to see full stats" % COLOR_NEUTRAL,
		"[color=%s]B[/color]  Shop, near the stand" % COLOR_NEUTRAL,
		"[color=%s]Tab[/color]  Codex" % COLOR_NEUTRAL,
	]
	_show_tooltip("\n".join(lines), controls_hint)


func _on_ability_slot_hover(slot: int) -> void:
	if bound_player == null or slot >= PlayerClass.MAX_KNOWN_ABILITIES:
		return
	## known_abilities only grows as abilities are learned, so an unfilled slot (including the
	## still-locked ultimate) may not have an entry at this index at all yet — not just an empty
	## one — and must still resolve to the "locked/empty" tooltip below, not a silent no-op that
	## leaves whatever tooltip was showing before this hover on screen.
	var entry: Dictionary = bound_player.known_abilities[slot] if slot < bound_player.known_abilities.size() else {}
	if entry.is_empty():
		var locked := "[b]%s[/b]\n[color=%s]Empty — pick one on your next ability level-up[/color]" % [ABILITY_SLOT_KEYS[slot], COLOR_FLAVOR]
		if slot == PlayerClass.ULTIMATE_SLOT:
			locked = "[b]R — Ultimate[/b]\n[color=%s]Locked until level %d[/color]" % [COLOR_FLAVOR, PlayerClass.ULTIMATE_LEVEL_INTERVAL]
		_show_tooltip(locked, ability_slot_buttons[slot])
		return
	_show_tooltip(_ability_tooltip_bbcode(str(entry.id), int(entry.rank), 0, slot == PlayerClass.ULTIMATE_SLOT), ability_slot_buttons[slot])


func _on_offer_hover(index: int) -> void:
	if index >= offered_upgrade_ids.size():
		return
	var chosen_id := offered_upgrade_ids[index]
	var bbcode: String
	if offer_kind == "ability":
		var current_rank := _known_rank(bound_player, chosen_id) if bound_player != null else 0
		bbcode = _ability_tooltip_bbcode(chosen_id, current_rank + 1 if current_rank > 0 else 1, current_rank, _offer_is_ultimate)
	else:
		var upgrade := PlayerClass.upgrade_info(chosen_id)
		bbcode = _stat_tooltip_bbcode(str(upgrade.name), str(upgrade.description))
	_show_tooltip(bbcode, offer_buttons[index])


## Ability tooltips are built from structured data (PlayerClass.ability_values), not the flavor
## text, so the colour coding is always accurate instead of guessed from a description string.
## `previous_rank` (0 = not previously known) prints every changed number as "old → new" instead
## of just the new value, so a rank-up's actual payoff is visible at a glance instead of having
## to remember what the ability did before. `is_ultimate` applies PlayerClass's ultimate
## multipliers to both values so the tooltip matches what actually casts from that slot.
func _ability_tooltip_bbcode(ability_id: String, rank: int, previous_rank: int = 0, is_ultimate: bool = false) -> String:
	var data := PlayerClass.ability_info(ability_id)
	if data.is_empty():
		return ""
	var values := PlayerClass.ability_values(ability_id, rank, is_ultimate)
	var previous_values := PlayerClass.ability_values(ability_id, previous_rank, is_ultimate) if previous_rank > 0 and previous_rank != rank else {}
	var archetype := int(data.archetype)
	var lines: Array[String] = []
	var rank_text := "Rank %d → %d" % [previous_rank, rank] if not previous_values.is_empty() else "Rank %d" % rank
	var name_line := "[b]%s[/b]  [color=%s]%s[/color]" % [str(data.name), COLOR_FLAVOR, rank_text]
	if is_ultimate:
		name_line = "[color=%s]★ ULTIMATE[/color]  %s" % [COLOR_BUFF, name_line]
	lines.append(name_line)
	lines.append("[color=%s]%s[/color]" % [COLOR_FLAVOR, str(data.description)])

	var is_heal := archetype == PlayerClass.Archetype.SELF_HEAL or archetype == PlayerClass.Archetype.AOE_HEAL
	var stat_bits: Array[String] = []
	if is_heal and float(values.power) > 0.0:
		stat_bits.append("[color=%s]%s heal[/color]" % [COLOR_HEAL, _num_delta(previous_values, values, "power", 0)])
	elif archetype == PlayerClass.Archetype.SHIELD_BURST and float(values.power) > 0.0:
		stat_bits.append("[color=%s]%s shield[/color]" % [COLOR_SHIELD, _num_delta(previous_values, values, "power", 0)])
	elif archetype == PlayerClass.Archetype.PUSH_PULL_BURST:
		stat_bits.append("[color=%s]%s[/color]" % [COLOR_CONTROL, "pull" if float(values.power) > 0.0 else "knockback"])
	elif float(values.power) != 0.0:
		stat_bits.append("[color=%s]%s damage[/color]" % [COLOR_DAMAGE, _num_delta(previous_values, values, "power", 0)])
	if data.has("lifesteal_pct"):
		stat_bits.append("[color=%s]%d%% lifesteal[/color]" % [COLOR_HEAL, roundi(float(data.lifesteal_pct) * 100.0)])
	if data.has("slow_on_hit"):
		stat_bits.append("[color=%s]slows[/color]" % COLOR_CONTROL)
	if data.has("stun_on_hit"):
		stat_bits.append("[color=%s]stuns[/color]" % COLOR_CONTROL)
	if data.has("mark_on_hit"):
		stat_bits.append("[color=%s]+%d%% vuln[/color]" % [COLOR_DAMAGE, roundi(float(data.mark_on_hit.bonus_pct) * 100.0)])
	if archetype == PlayerClass.Archetype.BUFF_SELF and float(values.duration) > 0.0:
		stat_bits.append("[color=%s]%ss buff[/color]" % [COLOR_BUFF, _num_delta(previous_values, values, "duration", 1)])
	if int(values.chain_count) > 0:
		stat_bits.append("[color=%s]chains %s[/color]" % [COLOR_NEUTRAL, _num_delta(previous_values, values, "chain_count", 0)])
	stat_bits.append("[color=%s]⟳ %ss[/color]" % [COLOR_NEUTRAL, _num_delta(previous_values, values, "cooldown", 1)])
	lines.append("  ·  ".join(stat_bits))
	return "\n".join(lines)


## "12 → 18" when `previous` has the field and it actually changed, otherwise just "18" — used
## for every rank-comparable number in the ability tooltip above.
func _num_delta(previous: Dictionary, current: Dictionary, field: String, decimals: int) -> String:
	var new_value := float(current.get(field, 0.0))
	if previous.is_empty():
		return "%.*f" % [decimals, new_value]
	var old_value := float(previous.get(field, 0.0))
	if is_equal_approx(old_value, new_value):
		return "%.*f" % [decimals, new_value]
	return "%.*f→%.*f" % [decimals, old_value, decimals, new_value]


## Shop items and stat upgrades only have free-text descriptions, so this scans for a handful
## of known keywords and colours the whole line by whichever category matches first — coarser
## than the structured ability tooltip above, but still lets the eye sort "heal" from "hurt"
## from "control" at a glance instead of reading every word.
func _stat_tooltip_bbcode(item_name: String, description: String) -> String:
	var lower := description.to_lower()
	var color := COLOR_NEUTRAL
	if lower.contains("heal") or lower.contains("regenerat") or lower.contains("lifesteal") or lower.contains("mend"):
		color = COLOR_HEAL
	elif lower.contains("slow") or lower.contains("stun") or lower.contains("freeze") or lower.contains("knock"):
		color = COLOR_CONTROL
	elif lower.contains("shield") or lower.contains("absorb") or lower.contains("survive") or lower.contains("reduc") or lower.contains("resist") or lower.contains("mitigat"):
		color = COLOR_SHIELD
	elif lower.contains("speed") or lower.contains("cooldown") or lower.contains("faster") or lower.contains("sprint") or lower.contains("dash"):
		color = COLOR_BUFF
	elif lower.contains("damage") or lower.contains("reflect") or lower.contains("burn") or lower.contains("pierce"):
		color = COLOR_DAMAGE
	return "[b]%s[/b]\n[color=%s]%s[/color]" % [item_name, color, description]


func _item_tooltip_bbcode(item_id: String) -> String:
	var item := ShopCatalog.by_id(item_id)
	if item.is_empty():
		return ""
	return _stat_tooltip_bbcode(str(item.name), str(item.description))

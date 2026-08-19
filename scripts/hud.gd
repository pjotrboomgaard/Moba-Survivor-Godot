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

const UPGRADE_ICON_MAX_WIDTH := 40

@onready var class_label: Label = $MarginContainer/Layout/Title
@onready var instructions_label: Label = $MarginContainer/Layout/Instructions
@onready var health_bar: ProgressBar = $MarginContainer/Layout/HealthBar
@onready var health_label: Label = $MarginContainer/Layout/HealthLabel
@onready var game_over_label: Label = $MarginContainer/Layout/GameOver
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var connection_label: Label = $ConnectionLabel
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
@onready var shop_panel: PanelContainer = $ShopPanel
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
		choice_button.add_theme_font_size_override("font_size", 15)
		choice_button.clip_text = false
	shop_continue.pressed.connect(_on_shop_continue_pressed)
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
	elif not shop_panel.visible and not upgrade_panel.visible and not game_over_label.visible:
		_open_escape_menu()


func _open_escape_menu() -> void:
	restart_button.visible = GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE
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


func _refresh_ability() -> void:
	if bound_player == null or not bound_player.has_active_item():
		ability_label.visible = false
		return
	ability_label.visible = true
	if bound_player.is_sprinting():
		ability_label.text = "SPACE  DASHING"
		ability_label.add_theme_color_override("font_color", Color("ffe08c"))
	elif bound_player.sprint_cooldown > 0.0:
		ability_label.text = "SPACE  %.1fs" % bound_player.sprint_cooldown
		ability_label.add_theme_color_override("font_color", Color("7b8496"))
	else:
		ability_label.text = "SPACE  DASH READY"
		ability_label.add_theme_color_override("font_color", Color("94ddff"))


const ABILITY_SLOT_KEYS := ["1", "2", "3", "4"]


func _refresh_ability_bar() -> void:
	if bound_player == null or bound_player.known_abilities.is_empty():
		ability_bar_label.text = ""
		return
	var lines: Array[String] = []
	for slot in bound_player.known_abilities.size():
		var entry := bound_player.known_abilities[slot]
		var ability_id := str(entry.id)
		var ability_data := PlayerClass.ability_info(ability_id)
		var ability_name := str(ability_data.get("name", ability_id))
		var cooldown_left := bound_player.ability_cooldowns[slot] if slot < bound_player.ability_cooldowns.size() else 0.0
		var status := "READY" if cooldown_left <= 0.0 else "%.1fs" % cooldown_left
		lines.append("%s  %s (Rk %d)  %s" % [ABILITY_SLOT_KEYS[slot], ability_name, int(entry.rank), status])
	ability_bar_label.text = "\n".join(lines)


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
	instructions_label.text = "WASD  Move     Hold left mouse  Aim and use %s     1-4  Abilities     R  Restart solo run" % class_data.weapon_name


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
	lines.append("[b][color=c8a4ff]ABILITIES[/color][/b]  (every odd level-up — learn a new one or rank up a known one, up to 4 known)")
	for class_data in PlayerClass.CLASSES:
		lines.append("[i]%s[/i]" % str(class_data.name).to_upper())
		for ability_id in class_data.ability_pool:
			var ability := PlayerClass.ability_info(str(ability_id))
			lines.append("  [b]%s[/b] — %s" % [str(ability.name), str(ability.description)])

	return "\n".join(lines)


const SHOP_ICON_MAX_WIDTH := 48

func _build_shop() -> void:
	for item in ShopCatalog.ITEMS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(300.0, 112.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.icon = SpriteLibrary.texture_for(str(item.id))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", SHOP_ICON_MAX_WIDTH)
		button.pressed.connect(_on_shop_item_pressed.bind(str(item.id)))
		shop_grid.add_child(button)
		shop_buttons[str(item.id)] = button


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
		button.text = "%s\n%s\n%d gold%s" % [item.name, item.description, price, owned]
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
	offer_title_label.text = "UPGRADE A STAT"
	for index in choice_buttons.size():
		if index >= offered_upgrade_ids.size():
			choice_buttons[index].visible = false
			continue
		var upgrade := PlayerClass.upgrade_info(offered_upgrade_ids[index])
		choice_buttons[index].visible = true
		choice_buttons[index].text = "%s\n%s" % [upgrade.name, upgrade.description]
		choice_buttons[index].icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(offered_upgrade_ids[index])
	upgrade_panel.visible = true
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
	offer_title_label.text = "LEARN OR UPGRADE AN ABILITY"
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
		var target_rank := current_rank + 1 if current_rank > 0 else 1
		var prefix := "UPGRADE (Rank %d)" % target_rank if current_rank > 0 else "LEARN"
		choice_buttons[index].visible = true
		choice_buttons[index].text = "[%s]\n%s" % [prefix, PlayerClass.ability_description(ability_id, target_rank)]
		choice_buttons[index].icon = null if GameRuntime.is_classic() else SpriteLibrary.texture_for(ability_id)
	upgrade_panel.visible = true
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
	if pauses_game:
		get_tree().paused = false
	pauses_game = false
	if chosen_kind == "ability":
		ability_chosen.emit(chosen_id)
	else:
		upgrade_chosen.emit(chosen_id)

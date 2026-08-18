class_name GameHUD
extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)
signal shop_item_chosen(item_id: String)
signal shop_closed

@onready var class_label: Label = $MarginContainer/Layout/Title
@onready var instructions_label: Label = $MarginContainer/Layout/Instructions
@onready var health_bar: ProgressBar = $MarginContainer/Layout/HealthBar
@onready var health_label: Label = $MarginContainer/Layout/HealthLabel
@onready var game_over_label: Label = $MarginContainer/Layout/GameOver
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var connection_label: Label = $ConnectionLabel
@onready var wave_label: Label = $WaveLabel
@onready var boss_panel: VBoxContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/BossName
@onready var boss_bar: ProgressBar = $BossPanel/BossBar
@onready var gold_label: Label = $GoldLabel
@onready var ability_label: Label = $AbilityLabel
@onready var theme_banner: Label = $ThemeBanner
@onready var debut_banner: Label = $DebutBanner
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var shop_gold_label: Label = $ShopPanel/ShopLayout/ShopGold
@onready var shop_grid: GridContainer = $ShopPanel/ShopLayout/ShopGrid
@onready var shop_continue: Button = $ShopPanel/ShopLayout/ShopContinue
@onready var upgrade_panel: PanelContainer = $UpgradePanel
@onready var choice_buttons: Array[Button] = [
	$UpgradePanel/Choices/Choice1,
	$UpgradePanel/Choices/Choice2,
	$UpgradePanel/Choices/Choice3,
]

var bound_player: Player
var offered_upgrade_ids: Array[String] = []
var pauses_game := false
var shop_pauses_game := false
var shown_class_id := ""
var shop_buttons: Dictionary = {}


func _ready() -> void:
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_upgrade_selected.bind(index))
	shop_continue.pressed.connect(_on_shop_continue_pressed)
	_build_shop()


func _process(_delta: float) -> void:
	if shop_panel.visible:
		_refresh_shop()
	_refresh_ability()


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
	instructions_label.text = "WASD  Move     Hold left mouse  Aim and use %s     R  Restart solo run" % class_data.weapon_name


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
	if debut_type_id.is_empty():
		debut_banner.visible = false
		return
	debut_banner.text = "NEW ENEMY: %s" % str(EnemyType.by_id(debut_type_id).name).to_upper()
	_flash(debut_banner, 3.2)


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
	if shop_pauses_game:
		get_tree().paused = true


func close_shop() -> void:
	if not shop_panel.visible:
		return
	shop_panel.visible = false
	if shop_pauses_game:
		get_tree().paused = false
	shop_pauses_game = false


func _build_shop() -> void:
	for item in ShopCatalog.ITEMS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(300.0, 112.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	shop_item_chosen.emit(item_id)


func _on_shop_continue_pressed() -> void:
	close_shop()
	shop_closed.emit()


func show_game_over() -> void:
	close_shop()
	game_over_label.visible = true


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "HP %d / %d" % [ceili(current_health), ceili(max_health)]


func _on_gold_changed(gold: int) -> void:
	gold_label.visible = not GameRuntime.is_classic()
	gold_label.text = "%d GOLD" % gold


func _on_xp_changed(current_xp: int, required_xp: int, next_level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	level_label.text = "LVL %d   %d / %d XP" % [next_level, current_xp, required_xp]


func show_upgrade_ids(player: Player, upgrade_ids: Array[String], pause_game: bool) -> void:
	bound_player = player
	offered_upgrade_ids = upgrade_ids.duplicate()
	pauses_game = pause_game
	for index in choice_buttons.size():
		if index >= offered_upgrade_ids.size():
			choice_buttons[index].visible = false
			continue
		var upgrade := PlayerClass.upgrade_info(offered_upgrade_ids[index])
		choice_buttons[index].visible = true
		choice_buttons[index].text = "%s\n%s" % [upgrade.name, upgrade.description]
	upgrade_panel.visible = true
	if pauses_game:
		get_tree().paused = true


func _on_upgrade_selected(index: int) -> void:
	if index >= offered_upgrade_ids.size():
		return
	var upgrade_id := offered_upgrade_ids[index]
	upgrade_panel.visible = false
	offered_upgrade_ids.clear()
	if pauses_game:
		get_tree().paused = false
	pauses_game = false
	upgrade_chosen.emit(upgrade_id)

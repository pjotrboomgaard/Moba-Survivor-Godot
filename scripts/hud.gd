class_name GameHUD
extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)
signal dev_command(command: String)
signal restart_requested
signal leave_requested

@onready var health_bar: ProgressBar = $MarginContainer/Layout/HealthBar
@onready var health_label: Label = $MarginContainer/Layout/HealthLabel
@onready var game_over_label: Label = $MarginContainer/Layout/GameOver
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var connection_label: Label = $ConnectionLabel
@onready var timer_label: Label = $TimerLabel
@onready var stats_label: Label = $StatsPanel/Margin/StatsLabel
@onready var upgrade_panel: PanelContainer = $UpgradePanel
@onready var dev_panel: PanelContainer = $DevPanel
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var choice_buttons: Array[Button] = [
	$UpgradePanel/Choices/Choice1,
	$UpgradePanel/Choices/Choice2,
	$UpgradePanel/Choices/Choice3,
]

const UPGRADE_POOL: Array[Dictionary] = [
	{"id": "rapid", "category": "OFFENCE", "name": "Charged Rhythm", "description": "Cast lightning 18% faster"},
	{"id": "heavy", "category": "OFFENCE", "name": "Arc Power", "description": "+8 lightning damage"},
	{"id": "chain", "category": "OFFENCE", "name": "Conductive Reach", "description": "+1 visible chain target"},
	{"id": "split", "category": "OFFENCE", "name": "Split Current", "description": "Cast a second main bolt with its own chain"},
	{"id": "crit_chance", "category": "OFFENCE", "name": "Keen Current", "description": "+8% critical strike chance"},
	{"id": "crit_power", "category": "OFFENCE", "name": "Brutal Voltage", "description": "Critical hits deal +35% damage"},
	{"id": "vitality", "category": "SURVIVAL", "name": "Second Wind", "description": "+25 max HP and heal 25 HP"},
	{"id": "regeneration", "category": "SURVIVAL", "name": "Trollblood", "description": "Regenerate 0.6 HP per second"},
	{"id": "lifesteal", "category": "SURVIVAL", "name": "Blood Current", "description": "Heal for 3% of damage dealt"},
	{"id": "boots", "category": "UTILITY", "name": "Windstep Boots", "description": "+35 movement speed"},
	{"id": "chain_range", "category": "UTILITY", "name": "Long Conductor", "description": "+35 chain search range"},
	{"id": "magnet", "category": "UTILITY", "name": "Arc Magnet", "description": "+45 XP pickup range"},
]

var bound_player: Player
var offered_upgrade_ids: Array[String] = []
var pauses_game := false
var health_fill_style: StyleBoxFlat


func _ready() -> void:
	var base_fill := health_bar.get_theme_stylebox("fill")
	if base_fill is StyleBoxFlat:
		health_fill_style = base_fill.duplicate() as StyleBoxFlat
		health_bar.add_theme_stylebox_override("fill", health_fill_style)
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_upgrade_selected.bind(index))
	$DevPanel/Margin/Layout/AddXP.pressed.connect(_emit_dev_command.bind("add_xp"))
	$DevPanel/Margin/Layout/AddLevels.pressed.connect(_emit_dev_command.bind("add_5_levels"))
	$DevPanel/Margin/Layout/SpawnElite.pressed.connect(_emit_dev_command.bind("spawn_elite"))
	$DevPanel/Margin/Layout/Invulnerable.pressed.connect(_emit_dev_command.bind("toggle_invulnerable"))
	$MenuPanel/Margin/Layout/Resume.pressed.connect(_toggle_menu)
	$MenuPanel/Margin/Layout/Restart.pressed.connect(restart_requested.emit)
	$MenuPanel/Margin/Layout/Leave.pressed.connect(leave_requested.emit)
	dev_panel.visible = false
	$MenuPanel/Margin/Layout/Restart.visible = GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE


func bind_player(player: Player) -> void:
	if bound_player == player:
		return
	bound_player = player
	var health := player.health
	health.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.stats_changed.connect(_on_stats_changed)
	_on_health_changed(health.current_health, health.max_health)
	_on_xp_changed(player.current_xp, player.xp_required, player.level)
	_on_stats_changed(player.combat_stats())


func set_connection_text(mode: String) -> void:
	connection_label.text = mode.to_upper()


func set_run_time(seconds: float) -> void:
	var total_seconds := floori(seconds)
	timer_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func show_game_over() -> void:
	game_over_label.visible = true


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "HP %d / %d" % [ceili(current_health), ceili(max_health)]
	var ratio := current_health / maxf(1.0, max_health)
	if ratio <= 0.25:
		health_label.modulate = Color("ff6868")
		health_fill_style.bg_color = Color("f04452")
	elif ratio <= 0.55:
		health_label.modulate = Color("ffd166")
		health_fill_style.bg_color = Color("f0a83f")
	else:
		health_label.modulate = Color("d8ffe8")
		health_fill_style.bg_color = Color("3ed17d")


func _on_xp_changed(current_xp: int, required_xp: int, next_level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	level_label.text = "LVL %d   %d / %d XP" % [next_level, current_xp, required_xp]


func structured_upgrade_ids(player: Player) -> Array[String]:
	var result: Array[String] = []
	for category in ["OFFENCE", "SURVIVAL", "UTILITY"]:
		var category_pool: Array[String] = []
		for upgrade in UPGRADE_POOL:
			if upgrade.category == category and player.can_upgrade(upgrade.id):
				category_pool.append(upgrade.id)
		category_pool.shuffle()
		if not category_pool.is_empty():
			result.append(category_pool[0])
	return result


func show_upgrade_ids(player: Player, upgrade_ids: Array[String], pause_game: bool) -> void:
	bound_player = player
	offered_upgrade_ids = upgrade_ids.duplicate()
	pauses_game = pause_game
	for index in choice_buttons.size():
		choice_buttons[index].visible = index < offered_upgrade_ids.size()
		if index >= offered_upgrade_ids.size():
			continue
		var upgrade := _upgrade_by_id(offered_upgrade_ids[index])
		var rank := player.upgrade_rank(upgrade.id) + 1
		choice_buttons[index].text = "%s · RANK %d\n%s\n%s" % [upgrade.category, rank, upgrade.name, upgrade.description]
	upgrade_panel.visible = true
	if pauses_game:
		get_tree().paused = true


func _upgrade_by_id(upgrade_id: String) -> Dictionary:
	for upgrade in UPGRADE_POOL:
		if upgrade.id == upgrade_id:
			return upgrade
	return {"id": upgrade_id, "name": upgrade_id, "description": ""}


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


func _on_stats_changed(stats: Dictionary) -> void:
	stats_label.text = "ARC STAFF\n\nDAMAGE        %d\nCASTS / SEC   %.2f\nMOVE SPEED    %d\nCRIT          %.0f%%\nCRIT DAMAGE   %.0f%%\nMAIN BOLTS    %d\nCHAINS        %d\nCHAIN RANGE   %d\nREGEN         %.1f /s\nLIFESTEAL     %.0f%%\nXP PICKUP     %d" % [
		roundi(float(stats.get("weapon_damage", 0.0))),
		float(stats.get("casts_per_second", 0.0)),
		roundi(float(stats.get("movement_speed", 0.0))),
		float(stats.get("critical_chance", 0.0)) * 100.0,
		float(stats.get("critical_multiplier", 0.0)) * 100.0,
		int(stats.get("main_bolts", 1)),
		int(stats.get("chains", 0)),
		roundi(float(stats.get("chain_range", 0.0))),
		float(stats.get("regeneration", 0.0)),
		float(stats.get("lifesteal", 0.0)) * 100.0,
		roundi(float(stats.get("pickup_radius", 0.0))),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_toggle") and OS.is_debug_build():
		dev_panel.visible = not dev_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_menu"):
		_toggle_menu()
		get_viewport().set_input_as_handled()


func _toggle_menu() -> void:
	if upgrade_panel.visible:
		return
	menu_panel.visible = not menu_panel.visible
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_tree().paused = menu_panel.visible


func _emit_dev_command(command: String) -> void:
	dev_command.emit(command)

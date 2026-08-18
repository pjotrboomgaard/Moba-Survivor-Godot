extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)

@onready var health_bar: ProgressBar = $MarginContainer/Layout/HealthBar
@onready var health_label: Label = $MarginContainer/Layout/HealthLabel
@onready var game_over_label: Label = $MarginContainer/Layout/GameOver
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var connection_label: Label = $ConnectionLabel
@onready var upgrade_panel: PanelContainer = $UpgradePanel
@onready var choice_buttons: Array[Button] = [
	$UpgradePanel/Choices/Choice1,
	$UpgradePanel/Choices/Choice2,
	$UpgradePanel/Choices/Choice3,
]

const UPGRADE_POOL: Array[Dictionary] = [
	{"id": "rapid", "name": "Rapid Casting", "description": "Cast the weapon 18% faster"},
	{"id": "heavy", "name": "Charged Weapon", "description": "+8 weapon damage"},
	{"id": "chain", "name": "Forked Current", "description": "+1 Arc Staff chain"},
	{"id": "boots", "name": "Windstep Boots", "description": "+35 movement speed"},
	{"id": "vitality", "name": "Second Wind", "description": "+25 max HP and heal"},
]

var bound_player: Player
var offered_upgrade_ids: Array[String] = []
var pauses_game := false


func _ready() -> void:
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_upgrade_selected.bind(index))


func bind_player(player: Player) -> void:
	if bound_player == player:
		return
	bound_player = player
	var health := player.health
	health.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	_on_health_changed(health.current_health, health.max_health)
	_on_xp_changed(player.current_xp, player.xp_required, player.level)


func set_connection_text(mode: String) -> void:
	connection_label.text = mode.to_upper()


func show_game_over() -> void:
	game_over_label.visible = true


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "HP %d / %d" % [ceili(current_health), ceili(max_health)]


func _on_xp_changed(current_xp: int, required_xp: int, next_level: int) -> void:
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp
	level_label.text = "LVL %d   %d / %d XP" % [next_level, current_xp, required_xp]


func random_upgrade_ids() -> Array[String]:
	var pool: Array[String] = []
	for upgrade in UPGRADE_POOL:
		pool.append(upgrade.id)
	pool.shuffle()
	return pool.slice(0, 3)


func show_upgrade_ids(player: Player, upgrade_ids: Array[String], pause_game: bool) -> void:
	bound_player = player
	offered_upgrade_ids = upgrade_ids.duplicate()
	pauses_game = pause_game
	for index in choice_buttons.size():
		var upgrade := _upgrade_by_id(offered_upgrade_ids[index])
		choice_buttons[index].text = "%s\n%s" % [upgrade.name, upgrade.description]
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

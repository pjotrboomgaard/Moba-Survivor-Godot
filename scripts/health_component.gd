class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0
@export var damage_taken_multiplier: float = 1.0
var current_health: float
var is_dead: bool = false
## Whoever landed the most recent hit, so reflect effects know where to aim.
var last_damage_source: Node = null


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or amount <= 0.0:
		return
	last_damage_source = source
	var mitigated := amount * damage_taken_multiplier
	current_health = maxf(0.0, current_health - mitigated)
	damaged.emit(mitigated)
	health_changed.emit(current_health, max_health)
	if current_health > 0.0:
		return
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("try_cheat_death") and owner_node.try_cheat_death():
		health_changed.emit(current_health, max_health)
		return
	is_dead = true
	died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func set_network_state(next_health: float, next_max_health: float) -> void:
	var new_max_health := maxf(1.0, next_max_health)
	var new_current_health := clampf(next_health, 0.0, new_max_health)
	if new_current_health < current_health:
		damaged.emit(current_health - new_current_health)
	max_health = new_max_health
	current_health = new_current_health
	is_dead = current_health <= 0.0
	health_changed.emit(current_health, max_health)

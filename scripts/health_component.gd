class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0
var current_health: float
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func set_network_state(next_health: float, next_max_health: float) -> void:
	max_health = maxf(1.0, next_max_health)
	current_health = clampf(next_health, 0.0, max_health)
	is_dead = current_health <= 0.0
	health_changed.emit(current_health, max_health)

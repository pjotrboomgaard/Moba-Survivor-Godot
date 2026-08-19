class_name CombatText
extends Node2D

## Floating "-N" damage popup, spawned locally by whichever client sees a HealthComponent's
## `damaged` signal fire (works for both authoritative and proxy entities, see enemy.gd/player.gd).

@export var lifetime := 0.72
@export var rise_speed := 54.0

@onready var label: Label = $Label

var elapsed := 0.0


func setup(amount: float) -> void:
	label.text = "-%d" % maxi(1, roundi(amount))


func _process(delta: float) -> void:
	elapsed += delta
	position.y -= rise_speed * delta
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - progress * progress
	if elapsed >= lifetime:
		queue_free()

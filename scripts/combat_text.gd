class_name CombatText
extends Node2D

## Floating "-N" damage popup, spawned locally by whichever client sees a HealthComponent's
## `damaged` signal fire (works for both authoritative and proxy entities, see enemy.gd/player.gd).
## Went through a boss-wave freeze once a big fight had many simultaneous hits landing every
## frame, so spawning is capped rather than unbounded.

const MAX_ACTIVE := 48
const SCENE: PackedScene = preload("res://scenes/effects/combat_text.tscn")

@export var lifetime := 0.72
@export var rise_speed := 54.0

@onready var label: Label = $Label

var elapsed := 0.0

static var _active_count := 0


## Skips the spawn once MAX_ACTIVE popups are already on screen instead of piling up more.
static func spawn(parent: Node, world_position: Vector2, amount: float) -> void:
	if _active_count >= MAX_ACTIVE:
		return
	var instance := SCENE.instantiate() as CombatText
	instance.global_position = world_position
	parent.add_child(instance)
	instance.setup(amount)


func setup(amount: float) -> void:
	label.text = "-%d" % maxi(1, roundi(amount))


func _ready() -> void:
	_active_count += 1


func _exit_tree() -> void:
	_active_count -= 1


func _process(delta: float) -> void:
	elapsed += delta
	position.y -= rise_speed * delta
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - progress * progress
	if elapsed >= lifetime:
		queue_free()

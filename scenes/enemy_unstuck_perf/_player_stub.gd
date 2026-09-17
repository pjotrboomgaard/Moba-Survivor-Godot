## Minimal Player stub for the isolated enemy-unstuck perf test.
## Inherits the real Player so `candidate is Player` checks pass.
##
## We must NOT let the real Player._physics_process / _ready run — the stub has
## none of Player's required children (HealthComponent, WorldHealthBar,
## Camera2D, Sprite, etc.) and those loops crash on null. So we override BOTH
## _ready() and _physics_process() as no-ops, and just register in the
## "players" group so Enemy._find_nearest_player() / _any_player_within_far_cull()
## can see the stub and treat it as a valid target.
##
## The stub is purely a static target marker: enemies path toward its
## global_position. It does no movement / AI of its own.

extends Player

func _ready() -> void:
	# Do NOT call super._ready() — the stub has no health/camera children.
	set_physics_process(false)
	add_to_group("players")

func _physics_process(_delta: float) -> void:
	# Intentionally empty: the stub is a static target marker. The real
	# Player._physics_process needs HealthComponent/WorldHealthBar/Camera2D
	# children which this stub does not have, so we override it as a no-op.
	pass

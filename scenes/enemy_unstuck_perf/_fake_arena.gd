## Minimal fake arena node for the isolated enemy-unstuck perf test.
## Inherits the real Arena so `candidate is Arena` passes, but overrides the
## methods the unstuck/teleport path needs. Skips _ready to avoid the heavy
## obstacle/landmark setup.
extends "res://scripts/arena.gd"

func _ready() -> void:
	# Do NOT call super._ready() — skip obstacle/landmark/teleporter setup.
	# Just register in the "arena" group so Arena.arena_root() can find us.
	add_to_group("arena")

func free_position_near(world_position: Vector2, _radius: float = 20.0) -> Vector2:
	# Open-world fake arena: nothing blocks, so the nudge position is free.
	return world_position

func is_blocked(_world_position: Vector2, _radius: float = 20.0) -> bool:
	return false

func _inside_playfield(_world_position: Vector2) -> bool:
	return true

func hazard_at(_world_position: Vector2) -> Dictionary:
	# No hazards in the isolated perf world — _update_standing_lava reads this.
	return {}

func crater_feature_active() -> bool:
	return false

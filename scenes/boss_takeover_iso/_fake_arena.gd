## Minimal fake arena node for the isolated boss-takeover test.
## Inherits the real Arena so `candidate is Arena` passes and tree methods work.
## Overrides _ready to skip the heavy obstacle/landmark setup.
## Overrides damage_trees_in_radius to actually free trees so the test can
## observe tree destruction via is_queued_for_deletion().
extends "res://scripts/arena.gd"

func _ready() -> void:
	# Do NOT call super._ready() — skip obstacle/landmark/teleporter setup.
	# Just register in the "arena" group so Arena.arena_root() can find us.
	add_to_group("arena")

func free_position_near(world_position: Vector2, _radius: float = 20.0) -> Vector2:
	return world_position

func is_blocked(_world_position: Vector2, _radius: float = 20.0) -> bool:
	return false

func _inside_playfield(_world_position: Vector2) -> bool:
	return true

func hazard_at(_world_position: Vector2) -> Dictionary:
	# No hazards in the isolated boss world.
	return {}

func crater_feature_active() -> bool:
	return false

## Override: actually free the tree obstacle so the test can detect destruction.
func damage_trees_in_radius(center: Vector2, radius: float, amount: float) -> int:
	if radius <= 0.0 or amount <= 0.0:
		return 0
	var r_sq := radius * radius
	var hits := 0
	for o in obstacles:
		if not is_instance_valid(o):
			continue
		if not o.sprite_id.begins_with("tree"):
			continue
		if o.global_position.distance_squared_to(center) > r_sq:
			continue
		o.queue_free()
		obstacles.erase(o)
		hits += 1
		print("[FakeArena] tree destroyed at %s" % str(o.global_position))
	if hits > 0:
		queue_redraw()
	return hits

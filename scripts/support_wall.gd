class_name SupportWall
extends StaticBody2D

## Player-drawn barrier. Blocks enemies (obstacle layer) while allies walk through.
## Contact slows and chips anything that leans on it.

const CONTACT_TICK := 0.35

var _duration := 6.0
var _age := 0.0
var _color := Color("ffc46b")
var _local_points := PackedVector2Array()
var _contact_timer := 0.0
var _hurt: Area2D


func configure(world_points: PackedVector2Array, duration: float, owner: Player, color: Color) -> void:
	collision_layer = 16
	collision_mask = 0
	_duration = maxf(0.4, duration)
	_color = color
	z_index = 6
	add_to_group("support_walls")
	if world_points.is_empty():
		queue_free()
		return
	global_position = world_points[0]
	_local_points = PackedVector2Array()
	for point in world_points:
		_local_points.append(point - global_position)
	if _local_points.size() == 1:
		_local_points.append(_local_points[0] + Vector2(PlayerClass.WALL_THICKNESS, 0.0))
	_build_shapes()
	_hurt = Area2D.new()
	_hurt.collision_layer = 0
	_hurt.collision_mask = 4
	_hurt.monitoring = true
	add_child(_hurt)
	for child in get_children():
		if child is CollisionShape2D:
			var copy := CollisionShape2D.new()
			copy.shape = (child as CollisionShape2D).shape
			copy.position = (child as CollisionShape2D).position
			copy.rotation = (child as CollisionShape2D).rotation
			_hurt.add_child(copy)
	if owner != null and owner.is_inside_tree():
		for candidate in owner.get_tree().get_nodes_in_group("players"):
			if candidate is PhysicsBody2D:
				add_collision_exception_with(candidate)
	queue_redraw()


func _build_shapes() -> void:
	for index in range(_local_points.size() - 1):
		var start := _local_points[index]
		var finish := _local_points[index + 1]
		var length := maxf(8.0, start.distance_to(finish))
		var rect := RectangleShape2D.new()
		rect.size = Vector2(length, PlayerClass.WALL_THICKNESS)
		var piece := CollisionShape2D.new()
		piece.shape = rect
		piece.position = start.lerp(finish, 0.5)
		piece.rotation = start.angle_to_point(finish)
		add_child(piece)


func _process(delta: float) -> void:
	_age += delta
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var fade := clampf(1.0 - _age / _duration, 0.0, 1.0)
	modulate.a = 0.35 + fade * 0.65
	if _contact_timer <= 0.0:
		_contact_timer = CONTACT_TICK
		_strike_touching()
	queue_redraw()
	if _age >= _duration:
		queue_free()


func _strike_touching() -> void:
	if _hurt == null:
		return
	for body in _hurt.get_overlapping_bodies():
		if not is_instance_valid(body) or not body.is_in_group("enemies"):
			continue
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.take_damage(6.0, self)
		if body.has_method("apply_slow"):
			body.apply_slow(0.45, 0.6)


func _draw() -> void:
	if _local_points.size() < 2:
		return
	draw_polyline(_local_points, Color(_color, 0.35), PlayerClass.WALL_THICKNESS + 10.0, true)
	draw_polyline(_local_points, _color, PlayerClass.WALL_THICKNESS * 0.7, true)
	for point in _local_points:
		draw_circle(point, PlayerClass.WALL_THICKNESS * 0.38, Color(1.0, 1.0, 1.0, 0.35))

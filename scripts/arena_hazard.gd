class_name ArenaHazard
extends Node2D

## Telegraph-then-strike arena attacks for solo boss fights. Circles are slams,
## rings are expanding shockwaves you step through, lines cut the whole field.

enum Kind {
	CIRCLE,
	RING,
	LINE,
}

var kind: Kind = Kind.CIRCLE
var telegraph_seconds := 1.0
var active_seconds := 0.3
var radius := 90.0
var inner_radius := 0.0
var max_radius := 1400.0
var line_length := 3200.0
var line_width := 78.0
var line_angle := 0.0
var damage := 18.0
var fill_color := Color("ff3a3a")
var cosmetic := false

var _age := 0.0
var _hit_ids: Dictionary = {}
var _finished := false


func configure(spec: Dictionary) -> void:
	kind = _kind_from(str(spec.get("kind", "circle")))
	telegraph_seconds = maxf(0.0, float(spec.get("telegraph", 1.0)))
	active_seconds = maxf(0.05, float(spec.get("active", 0.3)))
	radius = maxf(8.0, float(spec.get("radius", 90.0)))
	inner_radius = maxf(0.0, float(spec.get("inner_radius", 0.0)))
	max_radius = maxf(radius, float(spec.get("max_radius", 1400.0)))
	line_length = maxf(200.0, float(spec.get("length", 3200.0)))
	line_width = maxf(16.0, float(spec.get("width", 78.0)))
	line_angle = float(spec.get("angle", 0.0))
	damage = maxf(0.0, float(spec.get("damage", 18.0)))
	fill_color = Color(str(spec.get("color", "ff3a3a")))
	cosmetic = bool(spec.get("cosmetic", false))
	global_position = spec.get("origin", global_position)
	z_index = 8
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return
	_age += delta
	queue_redraw()
	if _is_active():
		_try_damage()
	if _age >= telegraph_seconds + active_seconds:
		_finished = true
		queue_free()


func _is_active() -> bool:
	return _age >= telegraph_seconds and _age < telegraph_seconds + active_seconds


func _ring_radius() -> float:
	var t := clampf((_age - telegraph_seconds) / maxf(0.05, active_seconds), 0.0, 1.0)
	return lerpf(40.0, max_radius, t)


func _try_damage() -> void:
	if cosmetic or damage <= 0.0 or not is_inside_tree():
		return
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.health.is_dead:
			continue
		var id := player.get_instance_id()
		if _hit_ids.has(id):
			continue
		if not _overlaps(player.global_position):
			continue
		_hit_ids[id] = true
		player.health.take_damage(damage, self)


func _overlaps(world_point: Vector2) -> bool:
	var local := world_point - global_position
	match kind:
		Kind.CIRCLE:
			return local.length() <= radius
		Kind.RING:
			var dist := local.length()
			var band := maxf(28.0, line_width * 0.5)
			return absf(dist - _ring_radius()) <= band
		Kind.LINE:
			var direction := Vector2.RIGHT.rotated(line_angle)
			var along := local.dot(direction)
			if along < -line_length * 0.5 or along > line_length * 0.5:
				return false
			return absf(local.dot(direction.orthogonal())) <= line_width * 0.5
	return false


func _draw() -> void:
	var warning := not _is_active()
	var pulse := 0.45 + 0.55 * sin(_age * 14.0)
	var alpha := 0.18 + 0.16 * pulse if warning else 0.42
	var color := Color(fill_color, alpha)
	var edge := Color(fill_color, 0.85 if warning else 1.0)
	match kind:
		Kind.CIRCLE:
			draw_circle(Vector2.ZERO, radius, color)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, edge, 4.0, true)
		Kind.RING:
			var shown := 80.0 if warning else _ring_radius()
			if warning:
				draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 72, Color(fill_color, 0.16 + 0.1 * pulse), 6.0, true)
			draw_arc(Vector2.ZERO, shown, 0.0, TAU, 72, edge, 10.0, true)
			draw_arc(Vector2.ZERO, maxf(4.0, shown - 14.0), 0.0, TAU, 72, Color(fill_color, 0.22), 6.0, true)
		Kind.LINE:
			var direction := Vector2.RIGHT.rotated(line_angle)
			var half := direction * line_length * 0.5
			var width := line_width if warning else line_width * 1.15
			draw_line(-half, half, color, width, true)
			draw_line(-half, half, edge, 5.0, true)


static func _kind_from(name: String) -> Kind:
	match name:
		"ring":
			return Kind.RING
		"line":
			return Kind.LINE
		_:
			return Kind.CIRCLE

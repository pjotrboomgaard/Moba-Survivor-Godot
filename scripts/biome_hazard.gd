extends Area2D

## Biome-specific periodic hazard:
## - Volcano (biome 1): expanding lava geyser that damages players AND enemies.
## - Factory (biome 3): EMP pulse that slows and damages all units in radius.
## Runs a telegraph -> active -> fade cycle, then frees itself.

var radius := 150.0
var damage := 12.0
var color := Color("ff5a1e")
var telegraph := 1.6
var active_seconds := 1.0
var biome_id := 1

# EMP-specific
var slow_factor := 0.0
var slow_duration := 0.0

var _age := 0.0
var _finished := false
var _hit_ids: Dictionary = {}
var _active_damage_done := false


func configure(next_radius: float, next_damage: float, next_color: Color, next_telegraph: float, next_active: float, next_biome: int) -> void:
	radius = next_radius
	damage = next_damage
	color = next_color
	telegraph = next_telegraph
	active_seconds = next_active
	biome_id = next_biome
	if biome_id == 3:
		slow_factor = 0.45
		slow_duration = 2.5
	global_position = get_parent().global_position if get_parent() else global_position
	z_index = 10
	z_as_relative = false
	# We don't need collision; we'll manually check distance
	collision_layer = 0
	collision_mask = 0
	add_to_group("biome_hazards")
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return
	_age += delta
	queue_redraw()
	if _is_active():
		_try_damage(delta)
		_apply_slow()
	if _age >= telegraph + active_seconds:
		_finished = true
		queue_free()


func _is_active() -> bool:
	return _age >= telegraph and _age < telegraph + active_seconds


func _is_telegraphing() -> bool:
	return _age < telegraph


func _try_damage(delta: float) -> void:
	if _active_damage_done:
		return
	_active_damage_done = true
	var r_sq := radius * radius
	# Damage players
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if not p.get("active"):
			continue
		var h = p.get("health")
		if h == null or h.is_dead:
			continue
		if global_position.distance_squared_to(p.global_position) <= r_sq:
			h.take_damage(damage)
	# Damage enemies
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var eh = e.get("health")
		if eh == null or eh.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= r_sq:
			eh.take_damage(damage * 0.7)


func _apply_slow() -> void:
	if biome_id != 3:
		return
	var r_sq := radius * radius
	# Apply slow to enemies and players within radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var eh = e.get("health")
		if eh == null or eh.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) <= r_sq:
			if e.has_method("apply_slow"):
				e.apply_slow(slow_factor, slow_duration)
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if not p.get("active"):
			continue
		var h = p.get("health")
		if h == null or h.is_dead:
			continue
		if global_position.distance_squared_to(p.global_position) <= r_sq:
			if p.has_method("apply_slow"):
				p.apply_slow(slow_factor, slow_duration)


func _draw() -> void:
	var pulse := 0.45 + 0.55 * sin(_age * 12.0)
	if _is_telegraphing():
		# Telegraph: show growing warning circle
		var t := _age / telegraph
		var r := radius * (0.3 + 0.7 * t)
		var a := 0.15 + 0.2 * pulse
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.6 + 0.3 * pulse), 3.0, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.12), 2.0, true)
	elif _is_active():
		# Active: full damaging zone
		var t := (_age - telegraph) / active_seconds
		var fade := 1.0 - t
		var r := radius
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.35 * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.9 * fade), 5.0, true)
		# Inner glow
		draw_circle(Vector2.ZERO, r * 0.6, Color(color.r, color.g, color.b, 0.2 * fade))

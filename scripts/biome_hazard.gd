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

# Volcano: when true, spawns random fire impacts around the geyser + red screen tint.
var volcano_geyser := false

# EMP-specific
var slow_factor := 0.0
var slow_duration := 0.0

var _age := 0.0
var _finished := false
var _hit_ids: Dictionary = {}
var _active_damage_done := false
var _fire_impacts_done := false
var _tint_emitted := false


func configure(next_radius: float, next_damage: float, next_color: Color, next_telegraph: float, next_active: float, next_biome: int) -> void:
	radius = next_radius
	damage = next_damage
	color = next_color
	telegraph = next_telegraph
	active_seconds = next_active
	biome_id = next_biome
	volcano_geyser = (next_biome == 1)
	if next_biome == 3:
		slow_factor = 0.45
		slow_duration = 2.5
	global_position = get_parent().global_position if get_parent() else global_position
	z_index = 10
	z_as_relative = false
	collision_layer = 0
	collision_mask = 0
	add_to_group("biome_hazards")
	queue_redraw()


func _process(delta: float) -> void:
	if _finished:
		return
	_age += delta
	queue_redraw()
	if volcano_geyser:
		# Red screen tint pulse once at the start of the telegraph.
		if not _tint_emitted and _age < 0.1:
			_tint_emitted = true
			_apply_volcano_tint()
		# Fire impacts land just before the geyser becomes active.
		if not _fire_impacts_done and _age >= telegraph * 0.65:
			_fire_impacts_done = true
			_spawn_fire_impacts()
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


## Volcano only: red screen tint warning via the HUD danger veil.
func _apply_volcano_tint() -> void:
	var hud := get_tree().get_first_node_in_group("hud") as Node
	if hud == null or not hud.has_method("pulse_danger"):
		return
	hud.pulse_danger(telegraph + active_seconds)


## Spawn fire impacts at random positions within the geyser radius.
func _spawn_fire_impacts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var count := rng.randi_range(5, 9)
	for i in count:
		var dist := radius * 0.85 * rng.randf()
		var ang := rng.randf() * TAU
		var spot := global_position + Vector2.from_angle(ang) * dist
		var power := damage * rng.randf_range(0.8, 1.6)
		var impact_radius := rng.randf_range(38.0, 72.0)
		var delay := i * 0.06
		_spawn_single_fire_impact(scene_root, spot, power, impact_radius, delay)


func _spawn_single_fire_impact(scene_root: Node, pos: Vector2, power: float, impact_radius: float, delay: float) -> void:
	# Visual: fire burst that fades.
	var visual := _FireImpactVisual.new()
	visual.global_position = pos
	visual.radius = impact_radius
	visual.color = color
	visual.lifetime = 0.55
	scene_root.add_child(visual)
	# Timer to tick damage once the impact lands (after the visual delay).
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(delay + 0.15, 0.15)
	scene_root.add_child(timer)
	timer.timeout.connect(func():
		var r_sq := impact_radius * impact_radius
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p):
				continue
			if not p.get("active"):
				continue
			var h = p.get("health")
			if h == null or h.is_dead:
				continue
			if pos.distance_squared_to(p.global_position) <= r_sq:
				h.take_damage(power)
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var eh = e.get("health")
			if eh == null or eh.is_dead:
				continue
			if pos.distance_squared_to(e.global_position) <= r_sq:
				eh.take_damage(power * 0.7)
		timer.queue_free()
	)


## Lightweight visual for a fire impact: expanding ring + core glow that fades.
class _FireImpactVisual:
	extends Node2D
	var radius := 48.0
	var color := Color("ff5a1e")
	var lifetime := 0.55
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		queue_redraw()
		if _age >= lifetime:
			queue_free()

	func _draw() -> void:
		var t := clampf(_age / lifetime, 0.0, 1.0)
		var fade := 1.0 - t
		var r := radius * (0.3 + 0.7 * t)
		# Outer glow
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.25 * fade))
		# Core
		draw_circle(Vector2.ZERO, r * 0.4, Color(color.r, color.g, color.b, 0.6 * fade))
		# Expanding ring
		var ring_r := r * (0.5 + 0.5 * t)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.5 * fade), 2.0, true)


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
		var t := _age / telegraph
		var r := radius * (0.3 + 0.7 * t)
		var a := 0.15 + 0.2 * pulse
		# Volcano: aggressive red telegraph with expanding rings + central eruption warning.
		if volcano_geyser:
			# Three expanding concentric warning rings.
			for ri in 3:
				var ring_f := (ri + 1) / 3.0
				var ring_r := radius * ring_f * t
				var ring_a := 0.25 + 0.35 * pulse * (1.0 - ring_f * 0.5)
				draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(0.95, 0.2, 0.05, ring_a), 3.0 - float(ri) * 0.6, true)
			# Central warning glow filling the radius as t approaches 1.
			var glow := Color(0.9, 0.1, 0.0, 0.12 + 0.1 * pulse)
			draw_circle(Vector2.ZERO, r, glow)
			# Pulsing core "eruption point" — reads as "volcano bursting soon".
			var inner_pulse := 0.5 + 0.5 * sin(_age * 8.0)
			var inner_r := radius * 0.15 * (1.0 + 0.3 * inner_pulse)
			draw_circle(Vector2.ZERO, inner_r, Color(1.0, 0.3, 0.0, 0.4 + 0.2 * inner_pulse))
			# Crosshair marker at the center.
			var ch := Color(1.0, 0.4, 0.0, 0.6)
			draw_line(Vector2(-radius * 0.1, 0), Vector2(radius * 0.1, 0), ch, 2.0)
			draw_line(Vector2(0, -radius * 0.1), Vector2(0, radius * 0.1), ch, 2.0)
		else:
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, a))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.6 + 0.3 * pulse), 3.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.12), 2.0, true)
	elif _is_active():
		var t := (_age - telegraph) / active_seconds
		var fade := 1.0 - t
		var r := radius
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.35 * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.9 * fade), 5.0, true)
		# Inner glow
		draw_circle(Vector2.ZERO, r * 0.6, Color(color.r, color.g, color.b, 0.2 * fade))
		# Volcano: fire petals radiating outward + central eruption column.
		if volcano_geyser:
			for i in 10:
				var a := TAU * float(i) / 10.0 + _age * 1.5
				var tip := Vector2.from_angle(a) * r * (0.5 + 0.3 * sin(_age * 10.0 + float(i) * 2.1))
				var left := Vector2.from_angle(a - 0.15) * r * 0.15
				var right := Vector2.from_angle(a + 0.15) * r * 0.15
				var petal_col := Color(color.r, color.g, color.b, 0.5 * fade)
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, left, tip, right]), petal_col)
			# Central eruption column — bright core that throbs.
			var col_r := r * 0.2 * (1.0 + 0.2 * sin(_age * 12.0))
			draw_circle(Vector2.ZERO, col_r, Color(1.0, 0.5, 0.1, 0.6 * fade))
			draw_circle(Vector2.ZERO, col_r * 0.5, Color(1.0, 0.8, 0.2, 0.8 * fade))

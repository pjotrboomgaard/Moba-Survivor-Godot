class_name ZonePulse
extends Node2D

## Short-lived visible zone for ultimates with on-hit slows/stuns (Energy Field, etc.).
## Draws an expanding double-ring at `radius`, fills the inside with a tint, breathes
## for `duration` seconds, then pops out. Pure visual — actual damage/knockback was
## already applied by the ability handler; this just paints where it lands.

var radius: float = 300.0
var duration: float = 3.0
var tint: Color = Color("ffd36b")
var secondary: Color = Color("ff8a3d")

var _elapsed: float = 0.0


func setup(p_position: Vector2, p_radius: float, p_duration: float, p_tint: Color, p_secondary: Color) -> void:
	global_position = p_position
	radius = p_radius
	duration = p_duration
	tint = p_tint
	secondary = p_secondary
	z_index = 5


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var life := 1.0 - _elapsed / maxf(duration, 0.01)
	var breath := sin(_elapsed * 5.5) * 0.5 + 0.5
	# Transparent interior fill — just enough to read "energy".
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.10 * life * (0.6 + 0.4 * breath)))
	# Double hexagonal wall — outer strong, inner weaker, both jagged with luminous nodes.
	_draw_hex_ring(radius, 0.85 * life, 5.0)
	_draw_hex_ring(radius * 0.6, 0.45 * life * (0.7 + 0.3 * breath), 2.5)
	# Radial pulse wave rippling outward.
	var pulse_phase := fmod(_elapsed * 2.0, 1.0)
	var pulse_radius := radius * (0.15 + pulse_phase * 0.85)
	draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 96, Color(tint.r, tint.g, tint.b, 0.7 * (1.0 - pulse_phase) * life), 2.5, true)
	# Lightning cracks — short random segments around the inner wall that flicker fast.
	var crack_count := 9
	for i in crack_count:
		var base_angle := TAU * float(i) / float(crack_count) + _elapsed * 0.6
		var jag_angle := base_angle + sin(_elapsed * 13.0 + float(i) * 7.0) * 0.18
		var inner_pt := Vector2.from_angle(base_angle) * radius * 0.6
		var outer_pt := Vector2.from_angle(jag_angle) * radius * (0.6 + 0.3 * (sin(_elapsed * 9.0 + float(i)) * 0.5 + 0.5))
		draw_line(inner_pt, outer_pt, Color(secondary.r, secondary.g, secondary.b, 0.6 * life), 1.5, true)
	# Center ember — a small crystal that pulses.
	var crystal_size := 4.0 + 1.5 * breath
	var crystal := PackedVector2Array()
	for k in 6:
		var a := TAU * float(k) / 6.0
		crystal.append(Vector2(cos(a), sin(a)) * crystal_size)
	draw_colored_polygon(crystal, Color(1.0, 1.0, 0.95, 0.9 * life))
	draw_polyline(crystal + PackedVector2Array([crystal[0]]), tint, 1.4, true)


func _draw_hex_ring(ring_radius: float, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	var nodes := PackedVector2Array()
	for k in 6:
		var a := TAU * float(k) / 6.0
		var p := Vector2(cos(a), sin(a)) * ring_radius
		points.append(p)
		nodes.append(p)
	# Closed hex outline
	draw_polyline(points + PackedVector2Array([points[0]]), Color(tint.r, tint.g, tint.b, alpha), width, true)
	# Corner nodes glow
	for p in nodes:
		draw_circle(p, 2.5, Color(1.0, 1.0, 0.9, alpha * 0.9))
		draw_circle(p, 5.0, Color(tint.r, tint.g, tint.b, alpha * 0.4))

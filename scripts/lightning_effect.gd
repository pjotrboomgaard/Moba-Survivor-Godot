class_name LightningEffect
extends Node2D

@export var lifetime := 0.16
@export var main_color := Color("8eeeff")
@export var chain_color := Color("b990ff")

## Kit VFX styling — populated by KitFxLibrary.apply_to_lightning.
## All additive: existing casts work with defaults (1 / 1 / "storm").
var pulse_count := 1
var ribbon_count := 1
var style_tag := "storm"

var style: PlayerClass.EffectStyle = PlayerClass.EffectStyle.BOLT
var points := PackedVector2Array()
var elapsed := 0.0
var flicker_seed := 0


func _ready() -> void:
	flicker_seed = randi()
	if style == PlayerClass.EffectStyle.BURST or style == PlayerClass.EffectStyle.BLAST or style == PlayerClass.EffectStyle.ARC:
		lifetime = maxf(lifetime, 0.42)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var effect_alpha := 1.0 - elapsed / lifetime
	match style:
		PlayerClass.EffectStyle.BURST:
			_draw_burst(points[0], points[1].x, effect_alpha)
		PlayerClass.EffectStyle.BLAST:
			var impact := points[1]
			var radius := points[2].x if points.size() >= 3 else 90.0
			_draw_blast(points[0], impact, radius, effect_alpha)
		PlayerClass.EffectStyle.ARC:
			var radius := points[1].x
			var half_angle := deg_to_rad(points[1].y if points[1].y > 0.0 else PlayerClass.CONE_HALF_ANGLE_DEGREES)
			var facing := (points[2] - points[0]) if points.size() >= 3 else Vector2.RIGHT
			_draw_arc_wedge(points[0], radius, facing, half_angle, effect_alpha)
		_:
			for segment_index in range(points.size() - 1):
				var color := main_color if segment_index == 0 else chain_color
				color.a *= effect_alpha
				var width := 4.0 if segment_index == 0 else 2.4
				if style == PlayerClass.EffectStyle.WAVE:
					_draw_wave(points[segment_index], points[segment_index + 1], color, width, segment_index, effect_alpha)
				else:
					_draw_bolt(points[segment_index], points[segment_index + 1], color, width, segment_index, effect_alpha)
				# Extra parallel ribbons for multi-ribbon kits (chain lightning, etc).
				if ribbon_count > 1:
					var dir := (points[segment_index + 1] - points[segment_index])
					var normal := Vector2(-dir.y, dir.x).normalized()
					for ribbon_index in range(1, ribbon_count):
						var offset := normal * float(ribbon_index) * 8.0
						var ribbon_color := chain_color
						ribbon_color.a *= effect_alpha * 0.5 / float(ribbon_index)
						var from_pt: Vector2 = points[segment_index] + offset
						var to_pt: Vector2 = points[segment_index + 1] + offset
						if style == PlayerClass.EffectStyle.WAVE:
							_draw_wave(from_pt, to_pt, ribbon_color, width * 0.6, segment_index + ribbon_index, effect_alpha)
						else:
							_draw_bolt(from_pt, to_pt, ribbon_color, width * 0.6, segment_index + ribbon_index, effect_alpha)


func _draw_burst(center: Vector2, radius: float, alpha: float) -> void:
	var color := main_color
	color.a *= alpha
	draw_circle(center, radius, color)
	# Extra echo pulses for kit visual depth — HoN-faithful stacked rings.
	if pulse_count > 1:
		for i in range(1, pulse_count):
			var f := float(i) / float(pulse_count)
			var ring_color := chain_color
			ring_color.a *= alpha * (1.0 - f * 0.6)
			draw_arc(center, radius * (0.5 + f * 0.5), 0.0, TAU, 72, ring_color, 3.0, true)


func _draw_blast(from: Vector2, impact: Vector2, radius: float, alpha: float) -> void:
	var line_color := main_color
	line_color.a *= alpha
	draw_line(from, impact, line_color, 4.0)
	# Ribbon trails fanning from the impact point — HoN-faithful shatter.
	if ribbon_count > 1:
		var base_angle := (impact - from).angle()
		for i in range(ribbon_count):
			var spread := (float(i) / maxf(float(ribbon_count - 1), 1.0) - 0.5) * PI * 0.6
			var dir := Vector2.from_angle(base_angle + spread)
			var trail_color := chain_color
			trail_color.a *= alpha * 0.6
			draw_line(from, impact + dir * radius * 0.6, trail_color, 2.0)
	var impact_color := chain_color
	impact_color.a *= alpha
	draw_circle(impact, radius, impact_color)


func _draw_arc_wedge(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var color := main_color
	color.a *= alpha * 0.5
	var base_angle := facing.angle()
	var arc_points := PackedVector2Array()
	arc_points.append(center)
	var steps := 20
	for i in range(steps + 1):
		var angle := base_angle - half_angle + (half_angle * 2.0 * float(i) / float(steps))
		arc_points.append(center + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(arc_points, color)
	# Extra concentric wedges add depth for multi-pulse kits.
	if pulse_count > 1:
		for i in range(1, pulse_count):
			var f := float(i) / float(pulse_count)
			var wedge_color := chain_color
			wedge_color.a *= alpha * 0.2 * (1.0 - f)
			var inner := PackedVector2Array()
			inner.append(center)
			for step in range(steps + 1):
				var angle := base_angle - half_angle + (half_angle * 2.0 * float(step) / float(steps))
				inner.append(center + Vector2.from_angle(angle) * radius * (0.4 + f * 0.4))
			draw_colored_polygon(inner, wedge_color)


func _draw_wave(from: Vector2, to: Vector2, color: Color, width: float, segment_index: int, progress: float) -> void:
	var segments := 16
	var previous := from
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var node: Vector2 = from.lerp(to, t)
		node += Vector2.from_angle((to - from).angle() + PI / 2.0) * sin(t * TAU + progress * TAU + float(segment_index)) * 6.0
		draw_line(previous, node, color, width * (1.0 - t * 0.5))
		previous = node


func _draw_bolt(from: Vector2, to: Vector2, color: Color, width: float, segment_index: int, progress: float) -> void:
	var midpoints := 4
	var previous := from
	for i in range(1, midpoints + 1):
		var t := float(i) / float(midpoints)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0 * sin(progress * 20.0 + float(segment_index))
		var node: Vector2 = from.lerp(to, t) + offset
		draw_line(previous, node, color, width * (1.0 - t * 0.3))
		previous = node

class_name LightningEffect
extends Node2D

@export var lifetime := 0.16
@export var main_color := Color("8eeeff")
@export var chain_color := Color("b990ff")

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


func _draw_burst(center: Vector2, radius: float, effect_alpha: float) -> void:
	var expansion := 1.0 - effect_alpha
	var outer := radius * (0.55 + 0.45 * expansion)
	var line_width := clampf(radius / 55.0, 5.0, 14.0)
	draw_circle(center, outer, Color(main_color, 0.24 * effect_alpha))
	draw_arc(center, outer, 0.0, TAU, 64, Color(main_color, effect_alpha), line_width, true)
	draw_arc(center, outer * 0.72, 0.0, TAU, 48, Color(chain_color, effect_alpha * 0.85), line_width * 0.65, true)
	draw_circle(center, outer * 0.18, Color(1.0, 1.0, 1.0, effect_alpha * 0.35))


func _draw_blast(origin: Vector2, impact: Vector2, radius: float, effect_alpha: float) -> void:
	var expansion := 1.0 - effect_alpha
	var outer := radius * (0.45 + 0.55 * expansion)
	var direction := origin.direction_to(impact)
	if direction.length_squared() <= 0.0:
		direction = Vector2.RIGHT
	var perp := direction.orthogonal()
	var muzzle := lerpf(8.0, 18.0, expansion)
	var flare := lerpf(22.0, outer * 0.62, expansion)
	var cone := PackedVector2Array([
		origin + perp * muzzle * 0.35,
		origin - perp * muzzle * 0.35,
		impact - perp * flare,
		impact + perp * flare,
	])
	draw_colored_polygon(cone, Color(main_color, 0.32 * effect_alpha))
	draw_line(origin, impact, Color(main_color, 0.75 * effect_alpha), 7.0, true)
	draw_line(origin, impact, Color(1.0, 0.96, 0.72, effect_alpha * 0.85), 3.0, true)
	draw_circle(impact, outer, Color(main_color, 0.42 * effect_alpha))
	draw_circle(impact, outer * 0.7, Color(chain_color, 0.32 * effect_alpha))
	var line_width := clampf(radius / 42.0, 6.0, 16.0)
	draw_arc(impact, outer, 0.0, TAU, 56, Color(main_color, effect_alpha), line_width, true)
	draw_arc(impact, outer * 0.58, 0.0, TAU, 40, Color(chain_color, effect_alpha * 0.95), line_width * 0.6, true)
	draw_circle(impact, outer * 0.2, Color(1.0, 1.0, 1.0, effect_alpha * 0.7))
	var spike_count := 12
	for spike_index in spike_count:
		var angle := TAU * float(spike_index) / float(spike_count) + float(flicker_seed % 11) * 0.05
		var tip := impact + Vector2.from_angle(angle) * outer * 1.28
		draw_line(impact, tip, Color(main_color, effect_alpha * 0.9), 3.2, true)
		if spike_index % 2 == 0:
			var jag := impact + Vector2.from_angle(angle + 0.18) * outer * 0.72
			draw_line(impact, jag, Color(1.0, 1.0, 1.0, effect_alpha * 0.55), 1.6, true)


func _draw_arc_wedge(center: Vector2, radius: float, facing: Vector2, half_angle: float, effect_alpha: float) -> void:
	var expansion := 1.0 - effect_alpha
	var outer := radius * (0.55 + 0.45 * expansion)
	var mid := facing.angle() if facing.length_squared() > 0.0 else 0.0
	var start := mid - half_angle
	var finish := mid + half_angle
	var wedge := PackedVector2Array([center])
	var steps := 22
	for step_index in range(steps + 1):
		var angle := lerpf(start, finish, float(step_index) / float(steps))
		wedge.append(center + Vector2.from_angle(angle) * outer)
	draw_colored_polygon(wedge, Color(main_color, 0.28 * effect_alpha))
	var line_width := clampf(radius / 55.0, 5.0, 14.0)
	draw_arc(center, outer, start, finish, 32, Color(main_color, effect_alpha), line_width, true)
	draw_arc(center, outer * 0.68, start, finish, 24, Color(chain_color, effect_alpha * 0.85), line_width * 0.6, true)
	var rim := center + Vector2.from_angle(mid) * outer
	draw_line(center, rim, Color(1.0, 1.0, 1.0, effect_alpha * 0.45), 3.0, true)
	draw_circle(center, 8.0, Color(1.0, 1.0, 1.0, effect_alpha * 0.3))


## Smooth sine curve tapering to zero at both ends, unlike _draw_bolt's jagged noise — reads
## as a growing vine/tendril rather than a lightning strike.
func _draw_wave(start: Vector2, finish: Vector2, color: Color, width: float, segment_index: int, effect_alpha: float) -> void:
	var wave := PackedVector2Array([start])
	var distance := start.distance_to(finish)
	var steps := maxi(6, ceili(distance / 18.0))
	var normal := start.direction_to(finish).orthogonal()
	var amplitude := 9.0
	var phase := float(flicker_seed % 100 + segment_index * 17)
	for index in range(1, steps):
		var progress := float(index) / float(steps)
		var center := start.lerp(finish, progress)
		var offset := sin(progress * TAU * 1.5 + phase) * amplitude * sin(progress * PI)
		wave.append(center + normal * offset)
	wave.append(finish)
	draw_polyline(wave, Color(color, color.a * 0.25), width + 6.0, true)
	draw_polyline(wave, color, width, true)
	for index in range(2, steps, 3):
		var progress := float(index) / float(steps)
		var offset := sin(progress * TAU * 1.5 + phase) * amplitude * sin(progress * PI)
		var bud := start.lerp(finish, progress) + normal * offset
		draw_circle(bud, width * 0.6, Color(1.0, 1.0, 1.0, effect_alpha * 0.6))


func _draw_bolt(start: Vector2, finish: Vector2, color: Color, width: float, segment_index: int, effect_alpha: float) -> void:
	var bolt := PackedVector2Array([start])
	var distance := start.distance_to(finish)
	var steps := maxi(3, ceili(distance / 32.0))
	var normal := start.direction_to(finish).orthogonal()
	for index in range(1, steps):
		var progress := float(index) / float(steps)
		var center := start.lerp(finish, progress)
		var noise := sin(float(flicker_seed + segment_index * 31 + index * 17)) * 8.0
		bolt.append(center + normal * noise)
	bolt.append(finish)
	draw_polyline(bolt, Color(color, color.a * 0.22), width + 7.0, true)
	draw_polyline(bolt, color, width, true)
	draw_polyline(bolt, Color(0.92, 0.99, 1.0, effect_alpha), maxf(1.0, width * 0.35), true)

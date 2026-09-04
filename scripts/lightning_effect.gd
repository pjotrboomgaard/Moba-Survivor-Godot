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
## Optional KitFxLibrary override: "cone_mist", "hex_field", "shard_burst", ...
var draw_mode := ""

var style: PlayerClass.EffectStyle = PlayerClass.EffectStyle.BOLT
var points := PackedVector2Array()
var elapsed := 0.0
var flicker_seed := 0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	flicker_seed = randi()
	# BURST/ARC rings need a beat to read; BLAST shatter stays a short pop (keg vs field).
	# KitFxLibrary may already have set a longer per-ability lifetime — never shorten it.
	if style == PlayerClass.EffectStyle.BURST or style == PlayerClass.EffectStyle.ARC:
		lifetime = maxf(lifetime, 0.42)
	if style == PlayerClass.EffectStyle.BLAST:
		lifetime = maxf(lifetime, 0.38)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _fade_alpha() -> float:
	var t := clampf(elapsed / maxf(lifetime, 0.001), 0.0, 1.0)
	# Lingering cones / hex fields hang at full read then ease out.
	if draw_mode == "cone_mist" or lifetime >= 1.0:
		return pow(1.0 - t, 0.55)
	if draw_mode == "hex_field" or draw_mode == "clock_field" or draw_mode == "freeze_field":
		return pow(1.0 - t, 0.7)
	return 1.0 - t


func _mode() -> String:
	if not draw_mode.is_empty():
		return draw_mode
	match style_tag:
		"fire":
			return "fire_petals"
		"ice":
			return "shard_burst"
		"nature":
			return "vine_lash"
		"steam":
			return "steam_ring"
		"arcane":
			return "orbit_rings"
		_:
			return "storm_bolts"


func _noise(i: int) -> float:
	var n := sin(float(flicker_seed + i) * 12.9898 + elapsed * 7.1) * 43758.5453
	return n - floor(n)


func _draw() -> void:
	if points.size() < 2:
		return
	var effect_alpha := _fade_alpha()
	match style:
		PlayerClass.EffectStyle.BURST:
			_draw_burst(points[0], points[1].x, effect_alpha)
		PlayerClass.EffectStyle.BLAST:
			var impact := points[1]
			var radius := points[2].x if points.size() >= 3 else 56.0
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
				_draw_styled_line(points[segment_index], points[segment_index + 1], color, width, segment_index, effect_alpha)
				if ribbon_count > 1:
					var dir := (points[segment_index + 1] - points[segment_index])
					var normal := Vector2(-dir.y, dir.x).normalized()
					for ribbon_index in range(1, ribbon_count):
						var offset := normal * float(ribbon_index) * 8.0
						var ribbon_color := chain_color
						ribbon_color.a *= effect_alpha * 0.5 / float(ribbon_index)
						var from_pt: Vector2 = points[segment_index] + offset
						var to_pt: Vector2 = points[segment_index + 1] + offset
						_draw_styled_line(from_pt, to_pt, ribbon_color, width * 0.6, segment_index + ribbon_index, effect_alpha)


func _draw_styled_line(from: Vector2, to: Vector2, color: Color, width: float, segment_index: int, progress: float) -> void:
	match style_tag:
		"nature":
			_draw_wave(from, to, color, width, segment_index, progress)
		"ice":
			_draw_shard_line(from, to, color, width)
		"arcane":
			_draw_dotted_line(from, to, color, width, segment_index)
		"fire":
			_draw_heat_line(from, to, color, width, segment_index, progress)
		"steam":
			_draw_bolt(from, to, color, width * 1.15, segment_index, progress)
		_:
			if style == PlayerClass.EffectStyle.WAVE:
				_draw_wave(from, to, color, width, segment_index, progress)
			else:
				_draw_bolt(from, to, color, width, segment_index, progress)


func _draw_burst(center: Vector2, radius: float, alpha: float) -> void:
	var mode := _mode()
	match mode:
		"hex_field", "steam_ring", "gear_ring":
			_draw_hex_field(center, radius, alpha, mode == "gear_ring")
		"fire_petals", "flame_pillar", "dust_burst":
			_draw_fire_petals(center, radius, alpha, mode == "flame_pillar")
		"eruption_plume":
			_draw_eruption_plume(center, radius, alpha)
		"shard_burst", "ice_cage", "chill_burst":
			_draw_ice_shards(center, radius, alpha, mode == "ice_cage")
		"freeze_field":
			_draw_freeze_field(center, radius, alpha)
		"vine_lash", "vine_ring", "rally_totem":
			_draw_vine_ring(center, radius, alpha, false)
		"overgrowth", "root_wall":
			_draw_vine_ring(center, radius, alpha, true)
		"toxic_bloom", "ward_spit":
			_draw_toxic_bloom(center, radius, alpha)
		"storm_bolts", "storm_pillar", "fist_shock":
			_draw_storm_burst(center, radius, alpha, mode == "storm_pillar")
		"quake_rings":
			_draw_quake_rings(center, radius, alpha)
		"orbit_rings", "clock_field", "curse_clock":
			_draw_orbit_rings(center, radius, alpha, mode == "clock_field" or mode == "curse_clock")
		"moonfall":
			_draw_moonfall(center, radius, alpha)
		"ward_shell":
			_draw_ward_shell(center, radius, alpha)
		"typhoon_spiral":
			_draw_typhoon(center, radius, alpha)
		"petal_fan":
			_draw_petal_burst(center, radius, alpha)
		"air_strike":
			_draw_air_strike(center + Vector2(0.0, -radius * 0.8), center, radius * 0.45, alpha)
		_:
			_draw_tagged_burst_fallback(center, radius, alpha)


func _draw_tagged_burst_fallback(center: Vector2, radius: float, alpha: float) -> void:
	# Never a full-radius filled disc — faint core + style-tag silhouette.
	match style_tag:
		"fire":
			_draw_fire_petals(center, radius, alpha, false)
		"ice":
			_draw_ice_shards(center, radius, alpha, false)
		"nature":
			_draw_vine_ring(center, radius, alpha, false)
		"steam":
			_draw_hex_field(center, radius, alpha, true)
		"arcane":
			_draw_orbit_rings(center, radius, alpha, false)
		_:
			_draw_storm_burst(center, radius, alpha, pulse_count >= 4)


func _draw_blast(from: Vector2, impact: Vector2, radius: float, alpha: float) -> void:
	var r := maxf(radius, 22.0)
	var mode := _mode()
	if mode == "simple_circle" or draw_mode == "simple_circle":
		if from.distance_squared_to(impact) > 36.0:
			var line_color := main_color
			line_color.a *= alpha
			draw_line(from, impact, line_color, 3.2, true)
		_draw_simple_circle(impact, r, alpha)
		return
	var has_beam := from.distance_squared_to(impact) > 36.0
	if has_beam and mode in ["keg_shatter", "fissure_crack", "air_strike"]:
		var line_color := main_color
		line_color.a *= alpha
		_draw_blast_beam(from, impact, line_color, alpha)
	match mode:
		"keg_shatter", "fire_petals", "bomb_pop", "dragon_breath":
			if mode == "keg_shatter" and not has_beam:
				var grow := clampf(elapsed / maxf(lifetime * 0.4, 0.05), 0.0, 1.0)
				_draw_simple_circle(impact, r * lerpf(0.1, 1.0, grow), alpha)
			else:
				_draw_fire_petals(impact, r * 1.2, alpha, false)
		"shard_burst", "ice_spike":
			_draw_ice_shards(impact, r * 1.15, alpha, false)
		"vine_lash", "dash_slash":
			_draw_vine_ring(impact, r, alpha, false)
		"fissure_crack":
			_draw_fissure(from, impact, r, alpha)
		"boulder_crash":
			_draw_quake_rings(impact, r * 1.25, alpha)
		"air_strike":
			_draw_air_strike(from, impact, r, alpha)
		_:
			_draw_simple_circle(impact, r, alpha)


func _draw_simple_circle(impact: Vector2, radius: float, alpha: float) -> void:
	var expand := 0.82 + 0.18 * clampf(elapsed / maxf(lifetime * 0.22, 0.03), 0.0, 1.0)
	var pop := radius * expand
	var fill := main_color
	fill.a *= alpha * 0.62
	draw_circle(impact, pop, fill)


func _draw_energy_impact(from: Vector2, impact: Vector2, radius: float, _alpha: float, _has_beam: bool) -> void:
	_draw_simple_circle(impact, radius, _fade_alpha())


func _draw_blast_beam(from: Vector2, to: Vector2, color: Color, alpha: float) -> void:
	var segments := 7
	var previous := from
	var side := Vector2(-(to - from).y, (to - from).x)
	if side.length_squared() > 0.0:
		side = side.normalized()
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var node: Vector2 = from.lerp(to, t)
		if i < segments:
			node += side * sin(t * PI * 2.0 + elapsed * 14.0) * 5.0
		draw_line(previous, node, color, lerpf(5.8, 2.4, t))
		previous = node
	var tip := chain_color
	tip.a *= alpha
	draw_circle(to, 8.0, tip)


func _draw_default_shatter(from: Vector2, impact: Vector2, shatter_r: float, alpha: float) -> void:
	var shards := maxi(ribbon_count, 2)
	var base_angle := (impact - from).angle() if from.distance_squared_to(impact) > 4.0 else 0.0
	for i in shards:
		var shard_dir := Vector2.from_angle(base_angle + TAU * float(i) / float(shards))
		var trail_color := chain_color
		trail_color.a *= alpha * 0.85
		draw_line(impact, impact + shard_dir * shatter_r, trail_color, 2.2)
	var impact_color := chain_color
	impact_color.a *= alpha * 0.55
	draw_circle(impact, shatter_r * 0.22, impact_color)


func _draw_arc_wedge(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var mode := _mode()
	match mode:
		"cone_mist":
			_draw_cone_mist(center, radius, facing, half_angle, alpha)
		"ice_cone", "shard_burst":
			_draw_ice_cone(center, radius, facing, half_angle, alpha)
		"fire_petals", "dragon_breath":
			_draw_fire_cone(center, radius, facing, half_angle, alpha)
		"wind_cone", "storm_bolts":
			_draw_storm_cone(center, radius, facing, half_angle, alpha)
		"petal_fan":
			_draw_petal_cone(center, radius, facing, half_angle, alpha)
		"vine_lash":
			_draw_vine_cone(center, radius, facing, half_angle, alpha)
		_:
			_draw_tagged_cone(center, radius, facing, half_angle, alpha)


func _draw_tagged_cone(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	match style_tag:
		"fire":
			_draw_fire_cone(center, radius, facing, half_angle, alpha)
		"ice":
			_draw_ice_cone(center, radius, facing, half_angle, alpha)
		"nature":
			_draw_vine_cone(center, radius, facing, half_angle, alpha)
		"storm":
			_draw_storm_cone(center, radius, facing, half_angle, alpha)
		_:
			_draw_basic_wedge(center, radius, facing, half_angle, alpha)


func _draw_basic_wedge(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
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


## Slow-fading venom hose — wavy leading edge, mist puffs, dripping droplets. Stays a wedge.
func _draw_cone_mist(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var base_angle := facing.angle()
	var expand := 0.72 + 0.28 * clampf(elapsed / maxf(lifetime * 0.35, 0.05), 0.0, 1.0)
	var reach := radius * expand
	var steps := 22
	var mist := PackedVector2Array()
	mist.append(center)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := base_angle - half_angle + (half_angle * 2.0 * t)
		var wave := 1.0 + 0.08 * sin(t * 9.0 + elapsed * 3.4)
		mist.append(center + Vector2.from_angle(angle) * reach * wave)
	var fill := main_color
	fill.a *= alpha * 0.32
	draw_colored_polygon(mist, fill)
	var edge := chain_color
	edge.a *= alpha * 0.75
	for i in range(1, mist.size()):
		draw_line(mist[i - 1], mist[i], edge, 2.4)
	# Inner venom streaks.
	var streaks := maxi(ribbon_count, 3)
	for s in streaks:
		var u := (float(s) + 0.5) / float(streaks)
		var ang := base_angle - half_angle + (half_angle * 2.0 * u)
		var streak := chain_color if s % 2 == 0 else main_color
		streak.a *= alpha * 0.55
		var tip := center + Vector2.from_angle(ang) * reach * (0.55 + 0.35 * _noise(s))
		draw_line(center, tip, streak, 2.0)
	# Lingering mist puffs + venom drips along the cone.
	var puffs := 8 + pulse_count * 2
	for p in puffs:
		var u := _noise(p + 20)
		var v := 0.25 + 0.7 * _noise(p + 40)
		var ang := base_angle - half_angle + (half_angle * 2.0 * u)
		var puff_pos := center + Vector2.from_angle(ang) * reach * v
		var puff := main_color
		puff.a *= alpha * (0.22 + 0.2 * sin(elapsed * 5.0 + float(p)))
		draw_circle(puff_pos, 7.0 + 5.0 * _noise(p + 60), puff)
		var drip := chain_color
		drip.a *= alpha * 0.5
		var drip_len := 6.0 + 10.0 * _noise(p + 80)
		draw_line(puff_pos, puff_pos + Vector2(0.0, drip_len), drip, 1.4)


func _draw_ice_cone(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var base_angle := facing.angle()
	var pale := main_color
	pale.a *= alpha * 0.22
	var fill := PackedVector2Array()
	fill.append(center)
	var steps := 14
	for i in range(steps + 1):
		var angle := base_angle - half_angle + (half_angle * 2.0 * float(i) / float(steps))
		fill.append(center + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(fill, pale)
	var shards := maxi(ribbon_count + 2, 5)
	for i in shards:
		var t := float(i) / float(maxi(shards - 1, 1))
		var ang := base_angle - half_angle + (half_angle * 2.0 * t)
		var tip := center + Vector2.from_angle(ang) * radius
		var left := center + Vector2.from_angle(ang - 0.07) * 16.0
		var right := center + Vector2.from_angle(ang + 0.07) * 16.0
		var col := chain_color if i % 2 == 0 else main_color
		col.a *= alpha * 0.8
		draw_colored_polygon(PackedVector2Array([center, left, tip, right]), col)
		draw_line(center, tip, col, 1.8)


func _draw_fire_cone(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var base_angle := facing.angle()
	var petals := maxi(ribbon_count + 3, 5)
	for i in petals:
		var t := float(i) / float(maxi(petals - 1, 1))
		var ang := base_angle - half_angle + (half_angle * 2.0 * t)
		var jag := 0.7 + 0.3 * sin(elapsed * 16.0 + float(i) * 2.2)
		var tip := center + Vector2.from_angle(ang) * radius * jag
		var left := center + Vector2.from_angle(ang - 0.12) * radius * 0.2
		var right := center + Vector2.from_angle(ang + 0.12) * radius * 0.2
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * 0.55
		draw_colored_polygon(PackedVector2Array([center, left, tip, right]), col)
		draw_line(center, tip, col, 2.0)


func _draw_storm_cone(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var base_angle := facing.angle()
	_draw_basic_wedge(center, radius, facing, half_angle, alpha * 0.45)
	var bolts := maxi(ribbon_count, 3)
	for i in bolts:
		var t := (float(i) + 0.5) / float(bolts)
		var ang := base_angle - half_angle + (half_angle * 2.0 * t)
		var col := main_color if i == bolts / 2 else chain_color
		col.a *= alpha
		_draw_bolt(center, center + Vector2.from_angle(ang) * radius, col, 2.6, i, alpha)


func _draw_petal_cone(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var base_angle := facing.angle()
	var petals := maxi(ribbon_count + 4, 7)
	for i in petals:
		var t := float(i) / float(maxi(petals - 1, 1))
		var ang := base_angle - half_angle + (half_angle * 2.0 * t)
		var tip := center + Vector2.from_angle(ang) * radius
		var side := Vector2.from_angle(ang + PI * 0.5) * (10.0 + float(i % 3) * 4.0)
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * 0.7
		draw_colored_polygon(PackedVector2Array([center + side, tip, center - side]), col)


func _draw_vine_cone(center: Vector2, radius: float, facing: Vector2, half_angle: float, alpha: float) -> void:
	var base_angle := facing.angle()
	var steps := 18
	var edge := PackedVector2Array()
	edge.append(center)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := base_angle - half_angle + (half_angle * 2.0 * t)
		var wave := 1.0 + 0.12 * sin(t * 12.0 + elapsed * 4.0)
		edge.append(center + Vector2.from_angle(angle) * radius * wave)
	var fill := main_color
	fill.a *= alpha * 0.28
	draw_colored_polygon(edge, fill)
	var vine := chain_color
	vine.a *= alpha * 0.8
	for i in range(1, edge.size()):
		draw_line(edge[i - 1], edge[i], vine, 2.2)
	var lashes := maxi(ribbon_count, 3)
	for s in lashes:
		var t := (float(s) + 0.5) / float(lashes)
		var ang := base_angle - half_angle + (half_angle * 2.0 * t)
		_draw_wave(center, center + Vector2.from_angle(ang) * radius, vine, 2.0, s, alpha)


func _draw_hex_field(center: Vector2, radius: float, alpha: float, geared: bool) -> void:
	var core := main_color
	core.a *= alpha * 0.12
	draw_colored_polygon(_hex_points(center, radius * 0.22), core)
	var rings := maxi(pulse_count, 2)
	for i in rings:
		var f := (float(i) + 1.0) / float(rings)
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * (0.95 - f * 0.35)
		var r := radius * (0.35 + f * 0.65)
		_draw_hex_polyline(center, r, col, 3.2 if i == rings - 1 else 2.0)
		if geared:
			_draw_gear_teeth(center, r, col, 8 + i * 2)
	# Containment spokes.
	var spokes := maxi(ribbon_count, 4)
	for s in spokes:
		var a := TAU * float(s) / float(spokes) + elapsed * 0.4
		var spoke := chain_color
		spoke.a *= alpha * 0.45
		draw_line(center + Vector2.from_angle(a) * radius * 0.2, center + Vector2.from_angle(a) * radius * 0.92, spoke, 1.4)


func _draw_fire_petals(center: Vector2, radius: float, alpha: float, pillar: bool) -> void:
	var expand := 0.4 + 0.6 * clampf(elapsed / maxf(lifetime * 0.45, 0.05), 0.0, 1.0)
	var r := radius * expand
	var glow := main_color
	glow.a *= alpha * 0.16
	draw_circle(center, r * 0.28, glow)
	var petals := maxi(pulse_count * 3 + 4, 6)
	if pillar:
		petals = maxi(petals, 10)
	for i in petals:
		var a := TAU * float(i) / float(petals) + elapsed * 1.2
		var jag := 0.72 + 0.28 * sin(elapsed * 14.0 + float(i) * 2.1)
		var tip := center + Vector2.from_angle(a) * r * jag
		if pillar and i % 2 == 0:
			tip += Vector2(0.0, -r * 0.35 * (0.5 + 0.5 * sin(elapsed * 8.0 + float(i))))
		var left := center + Vector2.from_angle(a - 0.16) * r * 0.22
		var right := center + Vector2.from_angle(a + 0.16) * r * 0.22
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * 0.62
		draw_colored_polygon(PackedVector2Array([center, left, tip, right]), col)
		draw_line(center, tip, col, 1.5)
	for p in range(pulse_count):
		var f := float(p + 1) / float(pulse_count + 1)
		var ring := chain_color
		ring.a *= alpha * (1.0 - f) * 0.75
		draw_arc(center, r * (0.4 + f * 0.6), 0.0, TAU, 48, ring, 2.2, true)


func _draw_eruption_plume(center: Vector2, radius: float, alpha: float) -> void:
	_draw_fire_petals(center, radius, alpha * 0.85, true)
	var spokes := maxi(ribbon_count, 6)
	for i in spokes:
		var a := -PI * 0.5 + (float(i) / float(spokes) - 0.5) * 1.6
		var col := chain_color
		col.a *= alpha * 0.8
		var tip := center + Vector2.from_angle(a) * radius * (0.8 + 0.4 * _noise(i))
		draw_line(center, tip, col, 3.0)
		draw_circle(tip, 6.0, col)
	for p in range(pulse_count):
		var f := float(p + 1) / float(pulse_count)
		var ring := main_color
		ring.a *= alpha * 0.4 * (1.0 - f)
		draw_arc(center, radius * f, 0.0, TAU, 40, ring, 3.0, true)


func _draw_ice_shards(center: Vector2, radius: float, alpha: float, cage: bool) -> void:
	var pale := main_color
	pale.a *= alpha * 0.2
	draw_circle(center, radius * 0.38, pale)
	var spokes := maxi(ribbon_count * 2 + 3, 6)
	for i in spokes:
		var a := TAU * float(i) / float(spokes)
		var tip := center + Vector2.from_angle(a) * radius
		var left := center + Vector2.from_angle(a - 0.09) * 14.0
		var right := center + Vector2.from_angle(a + 0.09) * 14.0
		var col := chain_color if i % 2 == 0 else main_color
		col.a *= alpha * 0.85
		draw_colored_polygon(PackedVector2Array([center, left, tip, right]), col)
		draw_line(center, tip, col, 1.6)
	if cage:
		var cage_col := chain_color
		cage_col.a *= alpha
		_draw_hex_polyline(center, radius * 0.92, cage_col, 2.6)
		var inner_cage := main_color
		inner_cage.a *= alpha * 0.7
		_draw_hex_polyline(center, radius * 0.55, inner_cage, 1.8)
	for p in range(pulse_count):
		var f := float(p + 1) / float(pulse_count + 1)
		var ring := chain_color
		ring.a *= alpha * 0.5
		draw_arc(center, radius * (0.45 + f * 0.5), 0.0, TAU, 36, ring, 1.8, true)


func _draw_freeze_field(center: Vector2, radius: float, alpha: float) -> void:
	_draw_ice_shards(center, radius, alpha, true)
	var flakes := 10 + pulse_count
	for i in flakes:
		var a := TAU * float(i) / float(flakes) + elapsed * 0.5
		var pos := center + Vector2.from_angle(a) * radius * (0.3 + 0.55 * _noise(i))
		var flake := chain_color
		flake.a *= alpha * 0.7
		draw_line(pos + Vector2(-4, 0), pos + Vector2(4, 0), flake, 1.2)
		draw_line(pos + Vector2(0, -4), pos + Vector2(0, 4), flake, 1.2)


func _draw_vine_ring(center: Vector2, radius: float, alpha: float, heavy: bool) -> void:
	var glow := main_color
	glow.a *= alpha * 0.12
	draw_circle(center, radius * 0.22, glow)
	var waves := 28 if heavy else 20
	var prev := center + Vector2.RIGHT * radius
	var outline := chain_color
	outline.a *= alpha * 0.85
	for i in range(1, waves + 1):
		var t := float(i) / float(waves)
		var a := t * TAU
		var wobble := 1.0 + 0.1 * sin(a * (6.0 if heavy else 4.0) + elapsed * 5.0)
		var node := center + Vector2.from_angle(a) * radius * wobble
		draw_line(prev, node, outline, 2.8 if heavy else 2.0)
		prev = node
	var lashes := maxi(ribbon_count, 3)
	if heavy:
		lashes = maxi(lashes, 6)
	for s in lashes:
		var a := TAU * float(s) / float(lashes)
		var vine := main_color if s % 2 == 0 else chain_color
		vine.a *= alpha * 0.7
		_draw_wave(center, center + Vector2.from_angle(a) * radius, vine, 2.2, s, alpha)
	if heavy:
		for p in range(pulse_count):
			var f := float(p + 1) / float(pulse_count + 1)
			var ring := chain_color
			ring.a *= alpha * 0.35
			draw_arc(center, radius * f, 0.0, TAU, 40, ring, 2.0, true)


func _draw_toxic_bloom(center: Vector2, radius: float, alpha: float) -> void:
	var core := main_color
	core.a *= alpha * 0.18
	draw_circle(center, radius * 0.3, core)
	var bubbles := 7 + pulse_count * 2
	for i in bubbles:
		var a := TAU * float(i) / float(bubbles) + elapsed * 0.8
		var dist := radius * (0.35 + 0.55 * _noise(i))
		var pos := center + Vector2.from_angle(a) * dist
		var blob := chain_color if i % 2 == 0 else main_color
		blob.a *= alpha * 0.55
		draw_circle(pos, 8.0 + 7.0 * _noise(i + 10), blob)
		var drip := chain_color
		drip.a *= alpha * 0.45
		draw_line(pos, pos + Vector2(0.0, 10.0 + 6.0 * _noise(i + 30)), drip, 1.4)
	for p in range(pulse_count):
		var f := float(p + 1) / float(pulse_count)
		var ring := main_color
		ring.a *= alpha * 0.4 * (1.0 - f * 0.4)
		draw_arc(center, radius * (0.4 + f * 0.55), 0.0, TAU, 36, ring, 2.2, true)


func _draw_storm_burst(center: Vector2, radius: float, alpha: float, pillar: bool) -> void:
	var core := main_color
	core.a *= alpha * 0.14
	draw_circle(center, radius * 0.18, core)
	var bolts := maxi(ribbon_count + pulse_count, 5)
	if pillar:
		bolts = maxi(bolts, 8)
	for i in bolts:
		var a := TAU * float(i) / float(bolts)
		if pillar:
			a = -PI * 0.5 + (float(i) / float(bolts) - 0.5) * 0.9
			var from := center + Vector2(0.0, -radius * (0.2 + 0.8 * _noise(i)))
			var col := chain_color if i % 2 else main_color
			col.a *= alpha
			_draw_bolt(from, center + Vector2.from_angle(a + PI * 0.5) * radius * 0.35, col, 2.8, i, alpha)
		else:
			var col := main_color if i % 2 == 0 else chain_color
			col.a *= alpha
			_draw_bolt(center, center + Vector2.from_angle(a) * radius, col, 2.4, i, alpha)
	for p in range(pulse_count):
		var f := float(p + 1) / float(pulse_count + 1)
		var ring := chain_color
		ring.a *= alpha * 0.45
		draw_arc(center, radius * f, 0.0, TAU, 40, ring, 2.0, true)


func _draw_quake_rings(center: Vector2, radius: float, alpha: float) -> void:
	var core := main_color
	core.a *= alpha * 0.1
	draw_circle(center, radius * 0.16, core)
	var rings := maxi(pulse_count + 1, 3)
	for i in rings:
		var f := (float(i) + 1.0) / float(rings)
		var r := radius * f
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * (0.9 - f * 0.4)
		var segs := 18
		var prev := center + Vector2.RIGHT * r
		for s in range(1, segs + 1):
			var a := TAU * float(s) / float(segs)
			var jagged := 1.0 + 0.08 * sin(a * 8.0 + elapsed * 10.0 + float(i))
			var node := center + Vector2.from_angle(a) * r * jagged
			draw_line(prev, node, col, 3.4 if i == 0 else 2.2)
			prev = node
	# Radial cracks.
	for c in maxi(ribbon_count, 3):
		var a := TAU * float(c) / float(maxi(ribbon_count, 3))
		var crack := chain_color
		crack.a *= alpha * 0.7
		draw_line(center, center + Vector2.from_angle(a) * radius, crack, 2.0)


func _draw_orbit_rings(center: Vector2, radius: float, alpha: float, clock: bool) -> void:
	var core := main_color
	core.a *= alpha * 0.12
	draw_circle(center, radius * 0.16, core)
	var rings := maxi(pulse_count, 2)
	for i in rings:
		var f := (float(i) + 1.0) / float(rings)
		var r := radius * (0.3 + f * 0.7)
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * 0.55
		draw_arc(center, r, 0.0, TAU, 64, col, 1.6, true)
		var dots := 8 + i * 4
		for d in dots:
			var a := TAU * float(d) / float(dots) + elapsed * (1.2 if i % 2 == 0 else -0.8)
			var dot := chain_color if d % 2 == 0 else main_color
			dot.a *= alpha * 0.85
			draw_circle(center + Vector2.from_angle(a) * r, 2.4, dot)
	if clock:
		var hand := chain_color
		hand.a *= alpha
		draw_line(center, center + Vector2.from_angle(elapsed * 2.4) * radius * 0.72, hand, 2.4)
		var hand_short := main_color
		hand_short.a *= alpha
		draw_line(center, center + Vector2.from_angle(elapsed * 0.7) * radius * 0.5, hand_short, 3.0)


func _draw_moonfall(center: Vector2, radius: float, alpha: float) -> void:
	var moons := maxi(pulse_count + 1, 3)
	for i in moons:
		var f := (float(i) + 1.0) / float(moons)
		var pos := center + Vector2(0.0, -radius * (1.0 - f) * 0.5)
		var col := main_color
		col.a *= alpha * (1.0 - f * 0.3)
		draw_arc(pos, radius * 0.22 * f, -PI * 0.2, PI * 1.1, 24, col, 3.0, true)
		draw_circle(pos, radius * 0.08 * f, col)
	_draw_orbit_rings(center, radius * 0.7, alpha * 0.6, false)


func _draw_ward_shell(center: Vector2, radius: float, alpha: float) -> void:
	var glow := main_color
	glow.a *= alpha * 0.16
	draw_circle(center, radius * 0.4, glow)
	for i in range(maxi(pulse_count, 2)):
		var f := (float(i) + 1.0) / float(maxi(pulse_count, 2) + 1)
		var col := chain_color if i % 2 else main_color
		col.a *= alpha * 0.8
		draw_arc(center, radius * f, elapsed * 2.0, elapsed * 2.0 + PI * 1.4, 28, col, 3.2, true)
		draw_arc(center, radius * f * 0.85, elapsed * -1.6, elapsed * -1.6 + PI * 1.2, 24, col, 2.2, true)


func _draw_petal_burst(center: Vector2, radius: float, alpha: float) -> void:
	var petals := maxi(ribbon_count + 4, 8)
	for i in petals:
		var a := TAU * float(i) / float(petals) + elapsed * 0.7
		var tip := center + Vector2.from_angle(a) * radius
		var side := Vector2.from_angle(a + PI * 0.5) * (12.0 + float(i % 3) * 5.0)
		var col := main_color if i % 2 == 0 else chain_color
		col.a *= alpha * 0.65
		draw_colored_polygon(PackedVector2Array([center + side * 0.2, tip, center - side * 0.2]), col)
	var glow := main_color
	glow.a *= alpha * 0.14
	draw_circle(center, radius * 0.18, glow)


func _draw_typhoon(center: Vector2, radius: float, alpha: float) -> void:
	var arms := maxi(ribbon_count, 4)
	for a_i in arms:
		var prev := center
		var col := main_color if a_i % 2 == 0 else chain_color
		col.a *= alpha * 0.75
		for s in 12:
			var t := float(s + 1) / 12.0
			var ang := elapsed * 3.0 + TAU * float(a_i) / float(arms) + t * 4.2
			var node := center + Vector2.from_angle(ang) * radius * t
			draw_line(prev, node, col, 3.0 * (1.0 - t * 0.5))
			prev = node
	var rim := chain_color
	rim.a *= alpha * 0.35
	draw_arc(center, radius * 0.9, 0.0, TAU, 48, rim, 2.0, true)


func _draw_fissure(from: Vector2, impact: Vector2, radius: float, alpha: float) -> void:
	var col := main_color
	col.a *= alpha
	_draw_bolt(from, impact, col, 4.0, 0, alpha)
	var side := Vector2(-(impact - from).y, (impact - from).x).normalized()
	for i in 5:
		var t := 0.2 + 0.15 * float(i)
		var along: Vector2 = from.lerp(impact, t)
		var crack := chain_color
		crack.a *= alpha * 0.7
		var dir := 1.0 if i % 2 == 0 else -1.0
		draw_line(along, along + side * dir * radius * (0.4 + 0.2 * float(i)), crack, 2.0)
	_draw_quake_rings(impact, radius, alpha * 0.7)


func _draw_air_strike(from: Vector2, impact: Vector2, radius: float, alpha: float) -> void:
	var col := main_color
	col.a *= alpha
	draw_line(from + Vector2(0, -radius * 2.0), impact, col, 2.2)
	for i in 3:
		var y := -radius * (1.6 - float(i) * 0.4)
		var chev := chain_color
		chev.a *= alpha * (1.0 - float(i) * 0.2)
		var p := impact + Vector2(0.0, y)
		draw_line(p + Vector2(-12.0 - float(i) * 4.0, -8.0), p, chev, 2.4)
		draw_line(p + Vector2(12.0 + float(i) * 4.0, -8.0), p, chev, 2.4)
	_draw_fire_petals(impact, radius, alpha, false)


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
		if i >= midpoints:
			node = to
		draw_line(previous, node, color, width * (1.0 - t * 0.3))
		previous = node


func _draw_shard_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width)
	var mid: Vector2 = from.lerp(to, 0.55)
	var side := Vector2(-(to - from).y, (to - from).x).normalized() * 7.0
	draw_colored_polygon(PackedVector2Array([from.lerp(to, 0.35), mid + side, to]), color)


func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float, segment_index: int) -> void:
	var dots := 8
	for i in dots:
		var t := float(i) / float(dots - 1)
		var pulse := 0.6 + 0.4 * sin(elapsed * 10.0 + float(segment_index + i))
		var c := color
		c.a *= pulse
		draw_circle(from.lerp(to, t), width * 0.7, c)


func _draw_heat_line(from: Vector2, to: Vector2, color: Color, width: float, segment_index: int, progress: float) -> void:
	var segments := 10
	var previous := from
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var node: Vector2 = from.lerp(to, t)
		node += Vector2.from_angle((to - from).angle() + PI / 2.0) * sin(t * 8.0 + elapsed * 9.0 + float(segment_index)) * (5.0 + t * 4.0)
		draw_line(previous, node, color, width * (1.1 - t * 0.4))
		previous = node


func _hex_points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(center + Vector2.from_angle(TAU * float(k) / 6.0 - PI / 6.0) * r)
	return pts


func _draw_hex_polyline(center: Vector2, r: float, color: Color, width: float) -> void:
	var pts := _hex_points(center, r)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, width, true)
	for p in pts:
		draw_circle(p, 2.4, color)


func _draw_gear_teeth(center: Vector2, r: float, color: Color, teeth: int) -> void:
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		var inner := center + Vector2.from_angle(a) * r
		var outer := center + Vector2.from_angle(a) * (r + 8.0)
		draw_line(inner, outer, color, 2.0)

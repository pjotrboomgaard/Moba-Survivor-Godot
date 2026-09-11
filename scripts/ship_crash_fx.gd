class_name ShipCrashFx
extends Node2D
## Opening cinematic: a pixel-art spaceship seen FROM BEHIND (engines glowing,
## exhaust plumes) flies fast from off-screen toward the map centre, wobbling as it
## goes, then detonates in one big red explosion. After the explosion the crater is
## revealed and the game continues.
##
## main.gd flow (opening):
##   1. cameras zoomed out to full map
##   2. ship_crash.play(start_pos, target_pos, on_impact)  -> emits impact + finished
##   3. on_impact: arena reveals the crater, explosion FX play, cameras zoom in.
##
## The ship is drawn procedurally as pixel-art (blocky body + twin engine glow +
## exhaust plume) so no external sprite asset is required.

signal impact
signal finished

var active := false
var _t := 0.0
var _pos := Vector2.ZERO
var _start := Vector2.ZERO
var _target := Vector2.ZERO
var _travel_time := 1.6       # seconds to cross the map
var _explode_time := 0.0
var _exploded := false
var _explosion_done := false
var _explosion_t := 0.0
var _on_impact: Callable = Callable()
var _explosion: Node2D = null

## Total travel time in seconds (faster = shorter).
var travel_time := 1.6
## How far off-screen the ship starts (relative to map half-extents).
const START_FACTOR := 1.4


func _ready() -> void:
	# Above obstacles (depth z ~2000-5400) so the ship + explosion paint on top.
	z_as_relative = false
	z_index = 4095
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


## Kick off the crash. `start` is the off-screen entry point, `target` the impact
## point (map centre). `on_impact` is called the moment the ship reaches the target.
func play(start: Vector2, target: Vector2, on_impact: Callable) -> void:
	if active:
		return
	active = true
	_start = start
	_target = target
	_pos = start
	_t = 0.0
	_exploded = false
	_explosion_done = false
	_explosion_t = 0.0
	_on_impact = on_impact
	travel_time = _travel_time
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	if not _exploded:
		# Travel: fast, eased slightly so it accelerates into impact.
		_t += delta
		var p := clampf(_t / travel_time, 0.0, 1.0)
		var eased := p * p * (3.0 - 2.0 * p)  # smoothstep — accelerates then eases
		_pos = _start.lerp(_target, eased)
		# Wobble: small sinusoidal offset that grows as it approaches.
		var wobble := sin(_t * 14.0) * (6.0 + p * 10.0)
		global_position = _pos + Vector2(0.0, wobble) * 0.5 + Vector2(wobble * 0.4, 0.0)
		queue_redraw()
		if p >= 1.0:
			_explode()
	else:
		# Explosion: hold the shockwave for a beat, then finish.
		_explosion_t += delta
		if _explosion_t >= 1.8:
			active = false
			visible = false
			_explosion_done = true
			queue_redraw()
			finished.emit()
		else:
			queue_redraw()


func _explode() -> void:
	_exploded = true
	_pos = _target
	global_position = _target
	if _on_impact.is_valid():
		_on_impact.call()
	_explosion_t = 0.0
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	if not _exploded:
		_draw_ship()
	else:
		_draw_explosion()


## Draw the spaceship viewed from behind, in PIXEL ART. A chunky blocky hull, two
## bright engine nozzles, and a thick exhaust plume flaring toward the camera.
## The ship is drawn ~180px tall so it stays clearly visible while the camera is
## zoomed way out (zoom 0.13). All shapes are axis-aligned rects for a pixel look.
func _draw_ship() -> void:
	var hull := Color(0.42, 0.46, 0.55)
	var hull_dark := Color(0.26, 0.28, 0.35)
	var hull_light := Color(0.66, 0.70, 0.80)
	var hull_edge := Color(0.12, 0.13, 0.17)
	# Main body: a wide blocky fuselage (rear faces the camera).
	draw_rect(Rect2(-56, -40, 112, 72), hull, true)
	# Body shading: darker lower half.
	draw_rect(Rect2(-56, 8, 112, 32), hull_dark, true)
	# Top deck highlight strip.
	draw_rect(Rect2(-48, -48, 96, 12), hull_light, true)
	# Rear top plate (the "nose" pointing away from us).
	draw_rect(Rect2(-32, -60, 64, 20), hull, true)
	draw_rect(Rect2(-32, -60, 64, 6), hull_light, true)
	# Side fins (blocky).
	draw_rect(Rect2(-76, -8, 20, 44), hull_dark, true)
	draw_rect(Rect2(56, -8, 20, 44), hull_dark, true)
	draw_rect(Rect2(-76, -8, 20, 10), hull, true)
	draw_rect(Rect2(56, -8, 20, 10), hull, true)
	# Rear window / cockpit glint (we see the back, so faint).
	draw_rect(Rect2(-16, -28, 32, 16), Color(0.35, 0.5, 0.75, 0.85), true)
	draw_rect(Rect2(-12, -24, 24, 8), Color(0.7, 0.85, 1.0, 0.9), true)
	# Crisp dark outline for contrast against the map.
	draw_rect(Rect2(-56, -40, 112, 72), hull_edge, false)
	draw_rect(Rect2(-32, -60, 64, 20), hull_edge, false)
	# Two big engine nozzles at the rear (bottom of sprite = toward camera).
	draw_rect(Rect2(-44, 32, 36, 24), Color(0.10, 0.10, 0.13), true)
	draw_rect(Rect2(8, 32, 36, 24), Color(0.10, 0.10, 0.13), true)
	# Engine glow: stacked bright squares (hot core to warm shell).
	var glow1 := Color(1.0, 0.92, 0.60, 1.0)
	var glow2 := Color(1.0, 0.55, 0.20, 1.0)
	var glow3 := Color(0.90, 0.30, 0.10, 0.9)
	for ex in [-26, 26]:
		draw_rect(Rect2(ex - 20, 52, 40, 24), glow3, true)
		draw_rect(Rect2(ex - 14, 52, 28, 24), glow2, true)
		draw_rect(Rect2(ex - 8, 52, 16, 24), glow1, true)
	# Exhaust plume: thick blocky columns flaring toward the camera (downward).
	var plume_a := Color(1.0, 0.6, 0.25, 0.75)
	var plume_b := Color(1.0, 0.82, 0.45, 0.9)
	for ex in [-26, 26]:
		draw_rect(Rect2(ex - 16, 76, 32, 38), plume_a, true)
		draw_rect(Rect2(ex - 10, 76, 20, 38), plume_b, true)
		draw_rect(Rect2(ex - 5, 76, 10, 38), Color(1.0, 0.95, 0.82, 0.9), true)
		# Plume tip flare.
		draw_rect(Rect2(ex - 20, 114, 40, 12), plume_a, true)
	# Speed trail behind the plume.
	draw_rect(Rect2(-12, 126, 24, 44), Color(1.0, 0.7, 0.4, 0.25), true)


## Big RED pixel-art explosion at the impact point — a classic retro starburst:
## chunky, spiky, asymmetric, with a dark outline, hot white core, orange middle and
## a deep-red outer shell. Phase A (0..0.55s): the starburst pops open and shimmers.
## Phase B (0.55..1.8s): it expands, thins and fades as debris + smoke linger.
func _draw_explosion() -> void:
	var t := _explosion_t
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	if t <= 0.55:
		# Phase A — the chunky starburst pops open.
		var p := t / 0.55
		# Fast pop with a slight overshoot (expand to ~1.1 then settle).
		var open := clampf(1.0 - (1.0 - p) * (1.0 - p) * 3.0, 0.0, 1.0)
		var overshoot := 1.0 + 0.12 * sin(p * PI)
		var fl := 1.0 + 0.05 * sin(t * 55.0)   # subtle flame flicker
		var outer := 440.0 * (0.3 + 0.7 * open) * overshoot * fl
		# Layers, outer (dark) -> inner (white-hot). Each is a jagged star polygon
		# with slightly different rotation so the silhouettes don't line up.
		_explosion_star(outer, 0.62, 18, 13, Color(0.30, 0.03, 0.02, 1.0))
		_explosion_star(outer * 0.88, 0.66, 16, 7, Color(0.85, 0.12, 0.04, 1.0))
		_explosion_star(outer * 0.66, 0.74, 13, 3, Color(1.0, 0.45, 0.08, 1.0))
		_explosion_star(outer * 0.42, 0.80, 11, 2, Color(1.0, 0.72, 0.25, 1.0))
		_explosion_star(outer * 0.24, 0.86, 9, 1, Color(1.0, 0.93, 0.75, 1.0))
		# White-hot solid core.
		_explosion_star(outer * 0.13, 0.9, 7, 0, Color(1.0, 1.0, 0.96, 1.0))
		# Square debris chunks flung just past the spikes.
		for i in 28:
			var ang := TAU * float(i) / 28.0 + rng.randf_range(-0.15, 0.15)
			var d := outer * (0.85 + rng.randf_range(0.0, 0.4))
			var sz := rng.randf_range(14.0, 36.0)
			var p2 := Vector2.from_angle(ang) * d
			draw_rect(Rect2(p2.x - sz / 2.0, p2.y - sz / 2.0, sz, sz),
				Color(1.0, rng.randf_range(0.4, 0.8), 0.1, 1.0), true)
		# Dark smudges at the very outer edge.
		for i in 12:
			var ang := TAU * float(i) / 12.0 + 0.18
			var d := outer * rng.randf_range(1.05, 1.3)
			var sz := rng.randf_range(22.0, 44.0)
			var p3 := Vector2.from_angle(ang) * d
			draw_rect(Rect2(p3.x - sz / 2.0, p3.y - sz / 2.0, sz, sz),
				Color(0.10, 0.08, 0.08, 0.75), true)
	else:
		# Phase B — expanding, thinning, fading.
		var bt := t - 0.55
		var expand := bt / 1.25
		var a := clampf(1.0 - expand, 0.0, 1.0)
		var outer := 440.0 * (1.0 + expand * 2.2)
		var cA := Color(0.85, 0.12, 0.04, a * 0.55)
		var cO := Color(1.0, 0.45, 0.08, a * 0.4)
		_explosion_star(outer, 0.6, 16, 5, cA)
		_explosion_star(outer * 0.7, 0.72, 11, 2, cO)
		# Debris squares flung far.
		for i in 44:
			var ang := rng.randf() * TAU
			var d := outer * rng.randf_range(0.5, 1.15)
			var sz := rng.randf_range(6.0, 22.0)
			var p2 := Vector2.from_angle(ang) * d
			draw_rect(Rect2(p2.x - sz / 2.0, p2.y - sz / 2.0, sz, sz),
				Color(1.0, rng.randf_range(0.4, 0.85), 0.15, a), true)
		# Lingering blocky smoke puffs.
		var smoke_a := clampf(0.55 - bt * 0.4, 0.0, 0.55)
		for i in 14:
			var ang := TAU * float(i) / 14.0
			var p3 := Vector2.from_angle(ang) * (outer * 0.55)
			var sz := 30.0 + bt * 40.0
			draw_rect(Rect2(p3.x - sz / 2.0, p3.y - sz / 2.0, sz, sz),
				Color(0.13, 0.11, 0.11, smoke_a), true)


## Draws a jagged, chunky star polygon ("pixel explosion" silhouette).
## `outer_r` = spike tip radius, `ratio` = inner/outer radius (lower = spikier),
## `spikes` = number of points, `seed` = deterministic per-spike jitter offset.
## Vertices are snapped to a grid so the edges read as blocky pixel-art, not smooth.
func _explosion_star(outer_r: float, ratio: float, spikes: int, seed: int, color: Color) -> void:
	if outer_r < 4.0:
		return
	var inner_r := outer_r * ratio
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + seed * 101
	var pts := PackedVector2Array()
	var total := spikes * 2
	var snap := maxf(6.0, outer_r * 0.02)   # grid size for the blocky look
	for i in total:
		var is_tip := (i % 2) == 0
		var base_ang := TAU * float(i) / float(total)
		# Per-spike length jitter so the burst is asymmetric (not a perfect star).
		var jitter := 1.0
		if is_tip:
			jitter = rng.randf_range(0.82, 1.18)
		var radius := (outer_r if is_tip else inner_r) * jitter
		var pt := Vector2.from_angle(base_ang) * radius
		# Snap to grid for chunky pixel edges.
		pt = Vector2(roundf(pt.x / snap) * snap, roundf(pt.y / snap) * snap)
		pts.append(pt)
	draw_colored_polygon(pts, color)


## Draws a chunky pixel-art starburst: `points` spikes, each spike a small cluster of
## stacked squares (so the silhouette is jagged/blocky, not a smooth star).
## `ratio` = inner radius / outer radius. Centred at the node origin.
func _pixel_starburst(outer: float, points: int, ratio: float, color: Color) -> void:
	# 2n vertices alternating outer (spike tips) and inner.
	# We draw each spike as a few stacked squares so it looks chunky/pixelated.
	var inner := outer * ratio
	var step := 6.0   # "pixel" chunk size
	var i := 0
	while i < points:
		var a_mid := TAU * (float(i) + 0.5) / float(points)
		var a_l := TAU * float(i) / float(points)
		var a_r := TAU * (float(i) + 1.0) / float(points)
		# Spike tip cluster (outer vertex).
		var tip := Vector2.from_angle(a_mid) * outer
		# Base vertices (inner).
		var bl := Vector2.from_angle(a_l) * inner
		var br := Vector2.from_angle(a_r) * inner
		# Draw the spike as stacked squares from base to tip.
		var n := int(outer / step)
		for k in range(n + 1):
			var f := float(k) / float(maxi(n, 1))
			var pos := bl.lerp(br, f * 0.5 + 0.5 * f).lerp(tip, f)
			# Simpler: lerp along the spike from base-centre to tip.
			var base_c := (bl + br) * 0.5
			var pos2 := base_c.lerp(tip, f)
			var w := step * (1.4 - f * 0.7)
			draw_rect(Rect2(pos2.x - w / 2.0, pos2.y - w / 2.0, w, w), color, true)
		# Base fill (inner edge of the star).
		var bc := (bl + br) * 0.5
		var bw := step * 1.4
		draw_rect(Rect2(bc.x - bw / 2.0, bc.y - bw / 2.0, bw, bw), color, true)
		i += 1
	# Fill the centre solidly so there is no hole.
	var cfill := outer * ratio * 0.9
	var n2 := int(cfill / step)
	for k in range(n2 + 1):
		draw_rect(Rect2(-step * 0.5, -step * 0.5, step, step), color, true)


## Draws a blocky "burst" blob: a central square plus squares placed at the 45-degree
## points and edges, approximating a rounded pixel-art circle made of blocks.
func _blocky_burst(radius: float, color: Color) -> void:
	var r := radius
	# Central filled square.
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), color, true)
	# 45-degree corner squares to round the silhouette.
	var c := r * 0.62
	var off := r * 0.42
	for p in [Vector2(off, off), Vector2(-off, off), Vector2(off, -off), Vector2(-off, -off)]:
		draw_rect(Rect2(p.x - c, p.y - c, c * 2.0, c * 2.0), color, true)
	# Mid-edge squares to fill out the diamond.
	var e := r * 0.34
	var eo := r * 0.82
	for p in [Vector2(eo, 0.0), Vector2(-eo, 0.0), Vector2(0.0, eo), Vector2(0.0, -eo)]:
		draw_rect(Rect2(p.x - e, p.y - e, e * 2.0, e * 2.0), color, true)

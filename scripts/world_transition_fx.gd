class_name WorldTransitionFx
extends Node2D

## Cinematic ring-of-fire world transition.
##
## Sits above the arena in world space (so it stays in sync with every camera during
## the zoom-out / sweep / zoom-in sequence). The NEW biome has already been rebuilt into
## the live arena underneath. This node paints the OLD biome's ground fill on top, masked
## to the OUTSIDE of an expanding fire ring — so the region inside the ring shows the new
## world while the region outside still shows the old world. As the ring grows to cover the
## whole map, the old world disappears and only the new world remains.
##
## main.gd flow:
##   1. lock players + shake
##   2. zoom cameras out to full map
##   3. rebuild arena to the new biome (live, underneath)
##   4. world_transition.begin(old_ground, center, full_radius, half_extents)
##      -> node runs its own tween and emits `finished` when the sweep completes
##   5. zoom cameras back into the players

signal finished

var old_ground := Color(0.13, 0.20, 0.12, 1.0)
var progress := 0.0                 # 0..1 ring sweep
var ring_center := Vector2.ZERO
var ring_full_radius := 5200.0
var map_half := Vector2(4200.0, 2800.0)
var active := false
var _fire_shoots: Array = []       # {dir, t, speed}
var _tween: Tween = null

const RING_DURATION := 3.2
const SOFTNESS := 240.0

func _ready() -> void:
	# Obstacles use z_as_relative=false with z_index ~2000–5400 (depth-based). We must
	# sit ABOVE all of them so the old-world overlay + fire ring paint on top of the
	# entire arena. 10000 is safely above the obstacle depth range.
	z_as_relative = false
	z_index = 4096   # max; above obstacle depth range so overlay paints on top
	# Godot only calls _draw() after a CanvasItem has requested a redraw. Force one
	# at startup so the node is always render-ready (even when idle).
	visible = false
	queue_redraw()
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin(old_color: Color, center: Vector2, full_radius: float, half_extents: Vector2) -> void:
	if active:
		return
	old_ground = old_color
	ring_center = center
	ring_full_radius = full_radius
	map_half = half_extents
	progress = 0.0
	_fire_shoots.clear()
	_spawn_shoots(48)
	active = true
	visible = true
	print("[world_transition] begin old=%s center=%s full_r=%d half=%s" % [
		str(old_color), str(center), int(full_radius), str(half_extents)])
	queue_redraw()

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "progress", 1.0, RING_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_sweep_done)


func _on_sweep_done() -> void:
	active = false
	visible = false
	queue_redraw()
	finished.emit()


func is_active() -> bool:
	return active


func _spawn_shoots(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var ang := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.14, 0.14)
		_fire_shoots.append({
			"dir": Vector2.from_angle(ang),
			"t": 0.0,
			"speed": rng.randf_range(0.7, 1.05),
		})


func _process(delta: float) -> void:
	# Advance the lava-shoot streaks each frame so they visibly streak outward.
	if active:
		for s in _fire_shoots:
			s["t"] = float(s.get("t", 0.0)) + delta * 0.85 * float(s.get("speed", 1.0))
		queue_redraw()


func _draw() -> void:
	if not active:
		return

	var cur := ring_full_radius * progress

	# 1) Old-world ground fill, masked to the OUTSIDE of the ring.
	#    Drawn as horizontal bands so each band's alpha can fade independently
	#    as the ring (a circle) sweeps past it. Bands inside the ring get alpha 0,
	#    revealing the live new arena underneath.
	var band_h := 120.0
	var left := ring_center.x - map_half.x
	var top := ring_center.y - map_half.y
	var w := map_half.x * 2.0
	var h := map_half.y * 2.0
	for y in range(int(top), int(top + h), int(band_h)):
		var ymid := y + band_h * 0.5
		var dist := ring_center.distance_to(Vector2(ring_center.x, ymid))
		var edge := clampf((dist - cur) / SOFTNESS + 0.5, 0.0, 1.0)
		if edge <= 0.01:
			continue
		var col := old_ground
		col.a = edge
		draw_rect(Rect2(left, y, w, band_h), col)

	# 2) Burning rim of the expanding fire circle.
	if cur > 1.0:
		var fade := 1.0 - progress * 0.5
		draw_arc(ring_center, cur, 0.0, TAU, 96,
			Color(1.0, 0.55, 0.18, fade), 26.0)
		draw_arc(ring_center, cur * 0.96, 0.0, TAU, 96,
			Color(1.0, 0.85, 0.5, 0.85 * fade), 10.0)
		var glow_steps := 8
		for i in glow_steps:
			var frac := float(i) / float(glow_steps)
			draw_arc(ring_center, cur * (0.55 + frac * 0.38), 0.0, TAU, 64,
				Color(1.0, 0.8, 0.35, 0.35 * (1.0 - frac) * fade), 4.0)
		# Bubbling lava specks along the rim.
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		for i in 48:
			var ang := rng.randf() * TAU
			var rr := cur * (0.99 + rng.randf_range(-0.02, 0.04))
			var sz := rng.randf_range(2.0, 6.0)
			draw_circle(ring_center + Vector2.from_angle(ang) * rr, sz,
				Color(1.0, rng.randf_range(0.4, 0.85), 0.15, rng.randf_range(0.5, 0.9) * fade))
		# Outward lava shoot streaks.
		for s in _fire_shoots:
			var st := float(s.get("t", 0.0))
			if st >= 1.0:
				continue
			var dir: Vector2 = s.get("dir", Vector2.RIGHT)
			var head := ring_center + dir * (cur * st)
			var tail := ring_center + dir * (cur * maxf(0.0, st - 0.16))
			var sfade := 1.0 - st
			draw_line(tail, head, Color(1.0, 0.6, 0.2, sfade), 4.0)
			draw_circle(head, 5.0 * sfade + 1.0, Color(1.0, 0.85, 0.4, sfade))

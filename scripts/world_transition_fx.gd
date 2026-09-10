class_name WorldTransitionFx
extends Node2D

## Fire-spread world transition. Sits above the arena (z above WorldFlash) and, over
## ~10s, reveals the NEW biome (already rebuilt underneath) through an expanding
## fire-colored circle while the OLD biome's ground still fills the outside.
##
## main.gd calls `begin(old_ground_color, new_ground_color)` then advances `progress`
## 0..1 via a tween; each frame `_draw` renders the current ring.

var old_ground := Color(0.16, 0.20, 0.13, 1.0)   # grass
var new_ground := Color(0.20, 0.09, 0.06, 1.0)   # volcano
var progress := 0.0        # 0..1 overall transition
var overlay_alpha := 0.0   # dark fade 0..1
var ring_radius := 0.0     # px radius of the "new world" hole
var crater_pos := Vector2.ZERO
var lava_shoots: Array = []  # {dir, t, speed}
var active := false

const RING_OPEN_START := 0.30  # progress at which the fire ring starts to open
const RING_FULL_AT := 0.85     # progress at which the ring has consumed the screen
const MAX_RING_RADIUS := 5200.0  # well beyond half-diagonal of the 8400x5600 map


func _ready() -> void:
	z_index = 9  # above WorldFlash (8), below Actors (20) so the new arena shows through
	visible = false


func begin(old_color: Color, new_color: Color, crater: Vector2) -> void:
	old_ground = old_color
	new_ground = new_color
	crater_pos = crater
	progress = 0.0
	overlay_alpha = 0.0
	ring_radius = 0.0
	lava_shoots.clear()
	active = true
	visible = true
	queue_redraw()


func is_active() -> bool:
	return active


func _draw() -> void:
	if not active:
		return
	# 1) dark overlay that fades in then out across the transition.
	if overlay_alpha > 0.001:
		draw_rect(Rect2(Vector2(-5200, -3600), Vector2(10400, 7200)),
			Color(0.02, 0.02, 0.04, overlay_alpha))

	if ring_radius <= 1.0:
		return

	# 2) Burning rim: the "edge" of the expanding fire circle revealing the new world.
	var rim_color := Color(1.0, 0.55, 0.18, 1.0)
	var inner_glow := Color(1.0, 0.8, 0.35, 0.35)
	draw_arc(crater_pos, ring_radius, 0.0, TAU, 96, rim_color, 26.0)
	draw_arc(crater_pos, ring_radius * 0.94, 0.0, TAU, 96,
		Color(1.0, 0.85, 0.5, 0.85), 10.0)
	var glow_steps := 8
	for i in glow_steps:
		var frac := float(i) / float(glow_steps)
		draw_arc(crater_pos, ring_radius * (0.55 + frac * 0.38), 0.0, TAU, 64,
			Color(inner_glow.r, inner_glow.g, inner_glow.b, inner_glow.a * (1.0 - frac)), 4.0)

	# 3) Bubbling lava specks along the rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var speck_count := 60
	for i in speck_count:
		var ang := rng.randf() * TAU
		var rr := ring_radius * (0.98 + rng.randf_range(-0.03, 0.05))
		var sz := rng.randf_range(2.0, 6.0)
		var c := Color(1.0, rng.randf_range(0.4, 0.85), 0.15, rng.randf_range(0.5, 0.95))
		draw_circle(crater_pos + Vector2.from_angle(ang) * rr, sz, c)

	# 4) Lava shoots: streaks flung outward from the crater during the open.
	for shoot in lava_shoots:
		var s_t: float = float(shoot.get("t", 0.0))
		if s_t >= 1.0:
			continue
		var dir: Vector2 = shoot.get("dir", Vector2.RIGHT)
		var head := crater_pos + dir * (ring_radius * s_t)
		var tail := crater_pos + dir * (ring_radius * maxf(0.0, s_t - 0.18))
		var fade := 1.0 - s_t
		draw_line(tail, head, Color(1.0, 0.6, 0.2, fade), 4.0)
		draw_circle(head, 5.0 * fade + 1.0, Color(1.0, 0.85, 0.4, fade))


## Spawn a burst of lava shoot streaks from the crater (called by main.gd during the
## "shoot lava in all directions" beat).
func spawn_lava_shoots(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var ang := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.15, 0.15)
		lava_shoots.append({
			"dir": Vector2.from_angle(ang),
			"t": 0.0,
			"speed": rng.randf_range(0.7, 1.0),
		})
	queue_redraw()


## Advance the lava-shoot streaks each frame; call from a _process hook in main.gd.
func tick_shoots(delta: float) -> void:
	if not active:
		return
	var changed := false
	for s in lava_shoots:
		var nt: float = float(s.get("t", 0.0)) + delta * 0.9 * float(s.get("speed", 1.0))
		s["t"] = nt
		changed = true
	if changed:
		queue_redraw()


func finish() -> void:
	active = false
	visible = false
	queue_redraw()

extends Node2D
## T4.11 hero-morph ring burst.
##
## A self-freed Node2D that draws an expanding, fading ring at its position for
## ~0.5s, then frees itself. Used to mark the moment the player morphs into a
## newly-bought hero (beacon / character shop). Vector art, matches the game's
## VFX style.
var _t := 0.0
const DURATION := 0.55
const START_RADIUS := 18.0
const END_RADIUS := 70.0
const THICKNESS := 4.0
const RING_COLOR := Color(0.55, 0.95, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var radius := lerpf(START_RADIUS, END_RADIUS, k)
	var alpha := 1.0 - k
	var thickness := lerpf(THICKNESS * 1.6, 1.5, k)
	# Main ring.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, RING_COLOR, thickness)
	# Inner softer ring for depth.
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 32,
			Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, alpha * 0.5), thickness * 0.6)
	# Bright flash dot at the centre that fades quickly.
	var dot_alpha := maxf(0.0, 1.0 - k * 2.0)
	if dot_alpha > 0.0:
		draw_circle(Vector2.ZERO, lerpf(14.0, 4.0, k),
				Color(0.9, 1.0, 1.0, dot_alpha))

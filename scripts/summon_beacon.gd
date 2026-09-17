class_name SummonBeacon
extends Node2D
## A summoning beacon that the player can buy in the shop. Once activated it
## projects a pulsing light pillar and lets the player open the BEACON tab in
## the shop to buy heroes to join the team.
##
## Visual: a small ground disc + a pulsing vertical light beam (vector art).

const WorldClock := preload("res://scripts/world_clock.gd")

var _pulse := 0.0
var activated := true
var beacon_world_pos := Vector2.ZERO

## The shop tab handler: main.gd sets this so the beacon can tell the HUD to
## open its BEACON tab when the player interacts with it.
var _on_interact: Callable = Callable()


func _ready() -> void:
	set_process(true)


func place(pos: Vector2) -> void:
	beacon_world_pos = pos
	global_position = pos
	z_as_relative = false
	z_index = WorldClock.depth_z(pos.y)


func _process(delta: float) -> void:
	_pulse += delta


func _draw() -> void:
	# Ground disc (a glowing ring on the ground).
	var glow := 0.55 + 0.45 * sin(_pulse * 3.0)
	draw_circle(Vector2.ZERO, 26.0, Color(0.35, 0.9, 1.0, 0.18))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(0.5, 0.95, 1.0, 0.8), 2.0)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.7, 1.0, 1.0, 0.5), 1.5)
	# Inner light dot.
	draw_circle(Vector2.ZERO, 6.0, Color(0.9, 1.0, 1.0, glow))
	# Vertical light beam (fades with height).
	var beam_top := -140.0
	var grad := draw_multiline
	# Draw beam as stacked translucent rects for a soft pillar.
	var steps := 14
	for i in steps:
		var t := float(i) / float(steps)
		var y0 := lerp(0.0, beam_top, t)
		var y1 := lerp(0.0, beam_top, t + 1.0 / float(steps))
		var w := lerp(10.0, 3.0, t)
		var a := (1.0 - t) * 0.35 * (0.7 + 0.3 * glow)
		draw_rect(Rect2(-w * 0.5, y1, w, y0 - y1), Color(0.5, 0.95, 1.0, a))
	# Top fl
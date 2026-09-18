extends Node2D
class_name CampCreepMarker

## A placeable "neutral creep camp" marker. Placed in the world editor and
## saved in the level JSON. At runtime, MinigameCampCreeps spawns a full
## neutral-camp-creep group (10 light-yellow idle creeps, 5x HP, 1.5x scale,
## invulnerable while idle, recruitable into the owner's team) at this
## position. The camp is then managed by the same MinigameCampCreeps system
## that manages the 4 corner minigame camps, so it gets the wave-mix updates
## (new enemy types introduced in later waves get mixed in) and the
## recruitment / follow / fight behaviour.
##
## Visually it reads as a neutral "recruit pool" pad: a soft light-yellow ring
## with a small inner dot, distinct from the green minigame-trigger ring.

const MARKER_ACCENT := Color("f5e0a0")


func _ready() -> void:
	add_to_group("camp_creep_marker")


func _draw() -> void:
	var c := MARKER_ACCENT
	# Soft outer pad.
	draw_circle(Vector2.ZERO, 40.0, Color(c.r, c.g, c.b, 0.12))
	# Two concentric rings so it reads as a "camp", not a single trigger.
	draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.65), 3.0)
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.40), 2.0)
	# Centre dot + a little "creep" glyph (two small filled circles side by
	# side) to hint that creeps live here.
	draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.95))
	draw_circle(Vector2(-14.0, 8.0), 3.5, Color(c.r, c.g, c.b, 0.7))
	draw_circle(Vector2(14.0, 8.0), 3.5, Color(c.r, c.g, c.b, 0.7))


## Hide the marker ring so it doesn't clutter gameplay once its camp has
## spawned. Called by MinigameCampCreeps after it reads the marker position.
func hide_for_game() -> void:
	visible = false


## Serialize for the level save file.
func to_dict() -> Dictionary:
	var pos: Array = [global_position.x, global_position.y]
	return {
		"pos": pos,
	}


## Restore a marker from a level save dictionary entry.
static func from_dict(entry: Dictionary) -> CampCreepMarker:
	var m := CampCreepMarker.new()
	var p: Array = entry.get("pos", [0.0, 0.0])
	m.global_position = Vector2(float(p[0]), float(p[1]))
	return m

extends Node2D
class_name MinigameTrigger

## A placeable "trigger" object that marks where a specific minigame should
## spawn at runtime. Placed in the world editor and saved in the level JSON.
## MinigameArea reads these triggers on start and spawns the corresponding
## minigame at each trigger's position.

## The minigame type id (index into the minigame registry, 0..15).
var minigame_index: int = 0
## Display name shown in the world editor / HUD.
var display_name: String = "Minigame"
## Accent color for the trigger marker ring.
var accent: Color = Color("8fae6a")


func _ready() -> void:
	add_to_group("minigame_trigger")


func _draw() -> void:
	# Draw a visible marker so the trigger is recognizable in the world and
	# in the editor. A dashed-style ring plus a center dot.
	var c := accent
	draw_circle(Vector2.ZERO, 46.0, Color(c.r, c.g, c.b, 0.10))
	draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.6), 3.0)
	draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.35), 2.0)
	draw_circle(Vector2.ZERO, 6.0, Color(c.r, c.g, c.b, 0.9))
	# Label drawn by editor only would be overkill; keep a subtle inner cross.
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(c.r, c.g, c.b, 0.5), 2.0)
	draw_line(Vector2(0, -12), Vector2(0, 12), Color(c.r, c.g, c.b, 0.5), 2.0)


## Serialize for the level save file.
func to_dict() -> Dictionary:
	var pos: Array = [global_position.x, global_position.y]
	return {
		"pos": pos,
		"index": minigame_index,
		"name": display_name,
		"accent": accent.to_html(false),
	}


## Restore a trigger from a level save dictionary entry.
static func from_dict(entry: Dictionary) -> MinigameTrigger:
	var t := MinigameTrigger.new()
	var p: Array = entry.get("pos", [0.0, 0.0])
	t.minigame_index = int(entry.get("index", 0))
	t.display_name = str(entry.get("name", "Minigame"))
	var accent_hex := str(entry.get("accent", "8fae6a"))
	t.accent = Color(accent_hex)
	t.global_position = Vector2(float(p[0]), float(p[1]))
	return t

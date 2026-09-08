extends CanvasLayer
class_name FogOfWar

## Warcraft/Starcraft-style vision: a soft circular veil around the local hero,
## plus a simple umbra behind nearby tree groups. Visible ground stays at authored
## pixel colors in open vision. Units behind trees are hidden in Main.

const MAX_TREES := 16

@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
	layer = 10
	if overlay != null:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = not GameRuntime.is_classic() and not GameRuntime.is_dedicated_server()


func follow_player(player: Node2D, tree_world: PackedVector2Array = PackedVector2Array()) -> void:
	if overlay == null:
		return
	if not visible or player == null or not is_instance_valid(player):
		overlay.visible = false
		return
	overlay.visible = true
	var mat := overlay.material as ShaderMaterial
	if mat == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var canvas := player.get_canvas_transform()
	var scale_x := canvas.get_scale().x
	mat.set_shader_parameter("viewport_size", vp_size)
	mat.set_shader_parameter("vision_center_px", canvas * player.global_position)
	mat.set_shader_parameter("vision_radius_px", Player.VISION_RADIUS * scale_x)
	mat.set_shader_parameter("tree_radius_px", 26.0 * scale_x)
	var origin := player.global_position
	var scored: Array = []
	for pos in tree_world:
		var dist := origin.distance_to(pos)
		if dist < Player.VISION_RADIUS + 80.0:
			scored.append({"d": dist, "p": pos})
	scored.sort_custom(func(a, b): return float(a.d) < float(b.d))
	var count := mini(MAX_TREES, scored.size())
	mat.set_shader_parameter("tree_count", count)
	for i in MAX_TREES:
		var screen := Vector2(-9999.0, -9999.0)
		if i < count:
			screen = canvas * (scored[i].p as Vector2)
		mat.set_shader_parameter("tree_px%d" % i, screen)

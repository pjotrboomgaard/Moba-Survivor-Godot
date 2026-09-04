extends Node2D

## Landmark for main.gd's proximity check (Arena.shop_stand_position()) — the actual shop UI is
## the existing HUD panel, opened/closed by main.gd's "interact_shop" (B) handling. Pixel art
## in Pjotr mode (see tools/sprite_art.gd's "shop_stand"), falls back to the original vector
## drawing in Classic mode or on a checkout that hasn't forged art yet.

const PIXEL_ZOOM := 4.0
const LIFT_PIXELS := 12.0
const WIDTH := 96.0
const HEIGHT := 64.0
const ROOF_COLOR := Color("ffcb3d")
const ROOF_OUTLINE := Color("ffe9a8")
const POST_COLOR := Color("6b4a1a")

@onready var sprite: Sprite2D = $Sprite
@onready var title_label: Label = $Title
@onready var prompt_label: Label = $Prompt
@onready var arrow_label: Label = $Arrow


func _ready() -> void:
	if not GameRuntime.is_classic():
		sprite.texture = SpriteLibrary.texture_for("shop_stand")
		sprite.scale = Vector2(PIXEL_ZOOM, PIXEL_ZOOM)
		sprite.offset = Vector2(0.0, -LIFT_PIXELS)
		if title_label != null:
			title_label.visible = false
	if prompt_label != null:
		prompt_label.visible = false
	if arrow_label != null:
		arrow_label.visible = true
		arrow_label.z_index = 8
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	if arrow_label == null:
		return
	var bob := sin(Time.get_ticks_msec() * 0.007) * 8.0
	arrow_label.position.y = -152.0 + bob
	if prompt_label != null:
		prompt_label.position.y = -102.0 + bob * 0.25


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func _draw() -> void:
	if has_sprite():
		return
	var half := WIDTH * 0.5
	draw_line(Vector2(-half + 8.0, 0.0), Vector2(-half + 8.0, HEIGHT), POST_COLOR, 6.0)
	draw_line(Vector2(half - 8.0, 0.0), Vector2(half - 8.0, HEIGHT), POST_COLOR, 6.0)
	var roof := PackedVector2Array([
		Vector2(-half, 0.0),
		Vector2(half, 0.0),
		Vector2(half - 10.0, -28.0),
		Vector2(-half + 10.0, -28.0),
	])
	draw_colored_polygon(roof, ROOF_COLOR)
	draw_polyline(roof + PackedVector2Array([roof[0]]), ROOF_OUTLINE, 3.0)
	draw_rect(Rect2(Vector2(-half + 4.0, HEIGHT - 14.0), Vector2(WIDTH - 8.0, 14.0)), POST_COLOR)
	draw_circle(Vector2.ZERO, 12.0, ROOF_COLOR)
	draw_circle(Vector2.ZERO, 12.0, ROOF_OUTLINE, false, 2.0)

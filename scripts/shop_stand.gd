extends Node2D

## Landmark for main.gd's proximity check (Arena.SHOP_STAND_POSITION) — the actual shop UI is
## the existing HUD panel, opened/closed by main.gd's "interact_shop" (B) handling. Pixel art
## in Pjotr mode (see tools/sprite_art.gd's "shop_stand"), falls back to the original vector
## drawing in Classic mode or on a checkout that hasn't forged art yet.

const PIXEL_ZOOM := 4.0
const LIFT_PIXELS := 24.0
const WIDTH := 96.0
const HEIGHT := 64.0
const ROOF_COLOR := Color("ffcb3d")
const ROOF_OUTLINE := Color("ffe9a8")
const POST_COLOR := Color("6b4a1a")
const RING_COLOR := Color("ffe08c")

@onready var sprite: Sprite2D = $Sprite
@onready var prompt_label: Label = $PromptLabel

var _in_range := false
var _ring_pulse := 0.0


func _ready() -> void:
	if not GameRuntime.is_classic():
		sprite.texture = SpriteLibrary.texture_for("shop_stand")
		sprite.scale = Vector2(PIXEL_ZOOM, PIXEL_ZOOM)
		sprite.offset = Vector2(0.0, -LIFT_PIXELS)
	prompt_label.modulate.a = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _in_range:
		return
	_ring_pulse += delta
	queue_redraw()


## Called from main.gd whenever the local player's proximity to the stand changes — drives the
## fading "Press B to shop" prompt and the pulsing range ring, both purely cosmetic/local.
func set_in_range(value: bool) -> void:
	if _in_range == value:
		return
	_in_range = value
	var fade := create_tween()
	fade.tween_property(prompt_label, "modulate:a", 1.0 if value else 0.0, 0.25)
	queue_redraw()


func has_sprite() -> bool:
	return sprite != null and sprite.texture != null


func _draw() -> void:
	if _in_range:
		# Centered on the local origin, not the sprite's visual midpoint — this has to match
		# Arena.SHOP_STAND_POSITION exactly, since that's what main.gd's distance check actually
		# uses to decide whether B works, and the ring is supposed to be that boundary made visible.
		var pulse := 0.5 + 0.5 * sin(_ring_pulse * 3.0)
		draw_arc(Vector2.ZERO, Arena.SHOP_STAND_INTERACT_RADIUS, 0.0, TAU, 48, Color(RING_COLOR, 0.35 + 0.25 * pulse), 3.0, true)
	if has_sprite():
		return
	var half := WIDTH * 0.5
	# Posts.
	draw_line(Vector2(-half + 8.0, 0.0), Vector2(-half + 8.0, HEIGHT), POST_COLOR, 6.0)
	draw_line(Vector2(half - 8.0, 0.0), Vector2(half - 8.0, HEIGHT), POST_COLOR, 6.0)
	# Awning.
	var roof := PackedVector2Array([
		Vector2(-half, 0.0),
		Vector2(half, 0.0),
		Vector2(half - 10.0, -28.0),
		Vector2(-half + 10.0, -28.0),
	])
	draw_colored_polygon(roof, ROOF_COLOR)
	draw_polyline(roof + PackedVector2Array([roof[0]]), ROOF_OUTLINE, 3.0)
	# Counter.
	draw_rect(Rect2(Vector2(-half + 4.0, HEIGHT - 14.0), Vector2(WIDTH - 8.0, 14.0)), POST_COLOR)
	# Coin.
	draw_circle(Vector2.ZERO, 12.0, ROOF_COLOR)
	draw_circle(Vector2.ZERO, 12.0, ROOF_OUTLINE, false, 2.0)

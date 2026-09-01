class_name Landmark
extends Node2D

## A biome landmark: a stand-still pad that charges while a player holds inside it, then
## fires a signature effect. Effects dispatch back to main.gd via `triggered(position)`.
## Visuals and behaviour mirror LandmarkButton (radial fill ring, hint label, cooldown
## arc, pixel sprite); this class is the canonical, world-aware version that Arena owns
## in its `landmarks: Array[Landmark]` collection.

signal triggered(position: Vector2)

const PIXEL_ZOOM := 6.0
const BODY_RADIUS := 32.0
const STAND_RADIUS := 110.0
const HINT_RADIUS := 240.0
const COOLDOWN_SECONDS := 6.0

@export var effect_id: StringName = "pulse_wipe"
@export var effect_radius := 700.0
@export var stand_seconds := 2.5
@export var effect_arg := 6.0
var sprite_name := ""

var _accum := 0.0
var _ready_to_fire := true
var _fill := 0.0  # 0..1 progress while the player holds still
var _cooldown := 0.0  # seconds left before this landmark can fire again
var _hint := ""
var _anim := 0.0

var _sprite: Sprite2D = null
var _hint_label: Label = null


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.position = Vector2(-160.0, -118.0)
	_hint_label.size = Vector2(320.0, 54.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_hint_label.add_theme_constant_override("outline_size", 4)
	_hint_label.visible = false
	add_child(_hint_label)
	_apply_visuals()
	set_process(true)
	set_process_internal(true)


func configure(sprite_id: String, effect: StringName, radius: float, seconds: float, arg: float, hint_text: String) -> void:
	sprite_name = sprite_id
	effect_id = effect
	effect_radius = maxf(80.0, radius)
	stand_seconds = maxf(0.5, seconds)
	effect_arg = arg
	_hint = hint_text
	_apply_visuals()


func _apply_visuals() -> void:
	if _sprite != null:
		_sprite.texture = SpriteLibrary.texture_for(sprite_name)
		_sprite.scale = Vector2(PIXEL_ZOOM, PIXEL_ZOOM)
		_sprite.offset = Vector2(0.0, -14.0)
	if _hint_label != null:
		_hint_label.text = _compose_hint()
		_hint_label.visible = false
	queue_redraw()


func reset() -> void:
	_accum = 0.0
	_ready_to_fire = true
	_fill = 0.0
	_cooldown = 0.0
	if _hint_label != null:
		_hint_label.visible = false
	queue_redraw()


## External trigger hook (for tests / scripted effects). Emits the shared signal so
## main.gd's single handler path runs for both player-triggered and scripted fires.
func trigger() -> void:
	triggered.emit(global_position)


func _process(delta: float) -> void:
	_anim += delta
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		# Clients render and tick cooldown visuals; the server owns firing decisions.
		queue_redraw()
		return
	var any_player_holding := false
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.health.is_dead:
			continue
		if player.global_position.distance_to(global_position) > STAND_RADIUS:
			continue
		if player.velocity.length() < 8.0 and _ready_to_fire:
			any_player_holding = true
			_accum += delta
			_fill = clampf(_accum / stand_seconds, 0.0, 1.0)
			if _accum >= stand_seconds:
				_ready_to_fire = false
				_cooldown = COOLDOWN_SECONDS
				_accum = 0.0
				_fill = 0.0
				_reset_after_cooldown()
				trigger()
				break
	if not any_player_holding and _accum > 0.0:
		_accum = maxf(0.0, _accum - delta * 2.0)
		_fill = clampf(_accum / stand_seconds, 0.0, 1.0)
	_update_hint()
	queue_redraw()


func _update_hint() -> void:
	if _hint_label == null:
		return
	var show := false
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Player and candidate.active and not candidate.health.is_dead:
			if candidate.global_position.distance_to(global_position) <= HINT_RADIUS:
				show = true
				break
	if _cooldown > 0.0:
		_hint_label.text = "%s\n(recharging…)" % _compose_hint()
	else:
		_hint_label.text = _compose_hint()
	_hint_label.visible = show


func _reset_after_cooldown() -> void:
	await get_tree().create_timer(COOLDOWN_SECONDS).timeout
	if is_inside_tree():
		reset()


func _draw() -> void:
	var accent := _accent_fallback()
	# Grounded pad: dark rim + accent ring.
	draw_circle(Vector2.ZERO, STAND_RADIUS, Color(0.04, 0.05, 0.08, 0.55))
	draw_arc(Vector2.ZERO, STAND_RADIUS, 0.0, TAU, 64, Color(accent, 0.3), 4.0, true)
	draw_arc(Vector2.ZERO, STAND_RADIUS - 8.0, 0.0, TAU, 64, Color(accent, 0.16), 2.0, true)
	# Slow ambient pulse so the landmark never reads as inert.
	var pulse_t := fmod(_anim, 3.0) / 3.0
	draw_arc(Vector2.ZERO, BODY_RADIUS + 24.0 + pulse_t * 56.0, 0.0, TAU, 56, Color(accent, (1.0 - pulse_t) * 0.4), 3.0, true)
	# Cooldown arc / fill ring so players can see spent vs charging state at a glance.
	if _cooldown > 0.0:
		var cd_frac := 1.0 - (_cooldown / COOLDOWN_SECONDS)
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + TAU * cd_frac, 48, Color(accent, 0.5), 6.0, true)
	elif _fill > 0.001 and _fill < 1.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + TAU * _fill, 48, Color("fff0a0"), 8.0, true)
	elif _fill >= 1.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, 0.0, TAU, 48, Color("fff0a0"), 8.0, true)
	# Fallback colored blob if the pixel sprite asset is missing.
	if _sprite != null and _sprite.texture == null:
		draw_circle(Vector2.ZERO, BODY_RADIUS, accent)
	# Dim the sprite on cooldown so the spent state reads at a distance.
	if _sprite != null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45) if _cooldown > 0.0 else Color.WHITE


func _compose_hint() -> String:
	match effect_id:
		"pulse_wipe":
			return "%s\nwiping minions in %dm" % [_hint, int(effect_radius / 10.0)]
		"freeze_time":
			return "%s\nfreezes enemies for %ds" % [_hint, int(effect_arg)]
		"heal_all":
			return "%s\nheals the party +%d HP" % [_hint, int(effect_arg)]
		_:
			return _hint


func _accent_fallback() -> Color:
	match effect_id:
		"pulse_wipe":
			return Color("f4c44a")
		"freeze_time":
			return Color("7db8ff")
		"heal_all":
			return Color("7fd88a")
		_:
			return Color("e8e8e8")

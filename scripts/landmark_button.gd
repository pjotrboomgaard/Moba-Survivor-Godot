class_name LandmarkButton
extends Node2D

## A biome landmark with a signature effect: stand still on it for `stand_seconds` to
## trigger. Effects dispatch back to main.gd via `triggered`. The visual tells the
## story: a standing pad around a floating pixel sprite, an animated pulse ring
## filling up while the player holds still, and a bright shockwave flash on fire.

signal triggered(landmark: LandmarkButton)

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

@onready var sprite: Sprite2D = $Sprite
@onready var zone: Area2D = $Zone
@onready var hint_label: Label = $Hint


func configure(sprite_id: String, effect: StringName, radius: float, seconds: float, arg: float, hint_text: String) -> void:
	sprite_name = sprite_id
	effect_id = effect
	effect_radius = maxf(80.0, radius)
	stand_seconds = maxf(0.5, seconds)
	effect_arg = arg
	_hint = hint_text
	if sprite != null:
		sprite.texture = SpriteLibrary.texture_for(sprite_name)
		sprite.scale = Vector2(PIXEL_ZOOM, PIXEL_ZOOM)
		sprite.offset = Vector2(0.0, -14.0)
	if zone != null:
		var shape := CircleShape2D.new()
		shape.radius = STAND_RADIUS
		zone.get_node("Shape").shape = shape
	if hint_label != null:
		hint_label.text = _compose_hint()
		hint_label.visible = false
	set_process(true)
	set_process_internal(true)
	queue_redraw()


func reset() -> void:
	_accum = 0.0
	_ready_to_fire = true
	_fill = 0.0
	_cooldown = 0.0
	if hint_label != null:
		hint_label.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	_anim += delta
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	var any_player_near := false
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		# Clients render but the server drives firing; keep visual ticking but no logic.
		queue_redraw()
		return
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var player := candidate as Player
		if not player.active or player.health.is_dead:
			continue
		var dist := player.global_position.distance_to(global_position)
		if dist <= STAND_RADIUS:
			var speed := player.velocity.length()
			if speed < 8.0 and _ready_to_fire:
				any_player_near = true
				_accum += delta
				_fill = clampf(_accum / stand_seconds, 0.0, 1.0)
				if _accum >= stand_seconds:
					_ready_to_fire = false
					_cooldown = COOLDOWN_SECONDS
					_reset_after_cooldown()
					emit_signal("triggered", self)
					break
	if not any_player_near and _accum > 0.0:
		_accum = maxf(0.0, _accum - delta * 2.0)
		_fill = clampf(_accum / stand_seconds, 0.0, 1.0)
	if hint_label != null:
		var show := false
		for candidate in get_tree().get_nodes_in_group("players"):
			if candidate is Player and candidate.active and not candidate.health.is_dead:
				if candidate.global_position.distance_to(global_position) <= HINT_RADIUS:
					show = true
					break
		if _cooldown > 0.0:
			hint_label.text = "%s\n(recharging…)" % _hint
		else:
			hint_label.text = _compose_hint()
		hint_label.visible = show
	queue_redraw()


func _reset_after_cooldown() -> void:
	await get_tree().create_timer(COOLDOWN_SECONDS).timeout
	if is_inside_tree():
		reset()


func _draw() -> void:
	var accent := _accent_fallback()
	# Grounded pad: dark ring rim + accent center dot.
	draw_circle(Vector2.ZERO, STAND_RADIUS, Color(0.04, 0.05, 0.08, 0.55))
	draw_arc(Vector2.ZERO, STAND_RADIUS, 0.0, TAU, 64, Color(accent, 0.3), 4.0, true)
	draw_arc(Vector2.ZERO, STAND_RADIUS - 8.0, 0.0, TAU, 64, Color(accent, 0.16), 2.0, true)
	# Constant slow pulse around the sprite so the landmark never reads as inert.
	var pulse_t := fmod(_anim, 3.0) / 3.0
	draw_arc(Vector2.ZERO, BODY_RADIUS + 24.0 + pulse_t * 56.0, 0.0, TAU, 56, Color(accent, (1.0 - pulse_t) * 0.4), 3.0, true)
	# Progress ring that fills while holding still — and a full-width countdown arc
	# while the landmark is on cooldown, so players can see it's spent, not broken.
	if _cooldown > 0.0:
		var cd_frac := 1.0 - (_cooldown / COOLDOWN_SECONDS)
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + TAU * cd_frac, 48, Color(accent, 0.5), 6.0, true)
	elif _fill > 0.001 and _fill < 1.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + TAU * _fill, 48, Color("fff0a0"), 8.0, true)
	elif _fill >= 1.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, 0.0, TAU, 48, Color("fff0a0"), 8.0, true)
	# Fallback colored blob when the pixel sprite is missing.
	if sprite != null and sprite.texture == null:
		draw_circle(Vector2.ZERO, BODY_RADIUS, accent)
	# Dim the sprite itself while recharging so the spent state reads at a glance.
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.45) if _cooldown > 0.0 else Color.WHITE


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

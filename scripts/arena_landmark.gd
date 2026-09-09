class_name ArenaLandmark
extends Node2D

## A biome landmark: a stand-still pad that charges while a player holds inside it, then
## fires a signature effect. Effects dispatch back to main.gd via `triggered(position)`.
## Visuals and behaviour mirror the legacy LandmarkButton (radial fill ring, hint label,
## cooldown arc, pixel sprite); this class is the canonical, world-aware version that
## Arena owns in its `landmarks: Array[ArenaLandmark]` collection.

signal triggered(position: Vector2)

const PIXEL_ZOOM := 6.0
const BODY_RADIUS := 32.0
const STAND_RADIUS := 140.0
const HINT_RADIUS := 280.0
const PAD_TILE := 16.0

## Per-effect cooldowns (seconds). Each landmark effect has a distinct, longer
## cooldown so they alternate rather than all becoming ready at the same time.
const EFFECT_COOLDOWNS: Dictionary = {
	"pulse_wipe": 90.0,
	"heal_all": 75.0,
	"freeze_time": 80.0,
	"phase_cloak": 65.0,
	"battle_frenzy": 70.0,
	"summon_minion": 85.0,
	"gold_rain": 100.0,
	"xp_boost": 88.0,
	"shield_all": 95.0,
	"speed_boost": 60.0,
	"damage_boost": 82.0,
	"revive_all": 120.0,
}
const COOLDOWN_DEFAULT := 90.0

## Return the cooldown for this landmark's effect (per-effect, so they alternate).
func _cooldown_seconds() -> float:
	return float(EFFECT_COOLDOWNS.get(str(effect_id), COOLDOWN_DEFAULT))

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


func _ready() -> void:
	add_to_group("landmarks")
	# Pads sit above grass (Arena _draw at z 0) and below Actors (heroes/creeps/VFX at 20).
	z_as_relative = false
	z_index = 2
	_ensure_children()
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


## Build Sprite + Hint children when they're missing (programmatic spawn from Arena).
func _ensure_children() -> void:
	if get_node_or_null("Sprite") == null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	if get_node_or_null("Hint") == null:
		var hint := Label.new()
		hint.name = "Hint"
		hint.position = Vector2(-180.0, -168.0)
		hint.size = Vector2(360.0, 72.0)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62, 1.0))
		hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		hint.add_theme_constant_override("outline_size", 4)
		hint.visible = false
		hint.z_as_relative = false
		hint.z_index = 30
		add_child(hint)


func _apply_visuals() -> void:
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.texture = null
		sprite.visible = false
	var hint := get_node_or_null("Hint") as Label
	if hint != null:
		hint.text = _compose_hint()
		hint.visible = false
	queue_redraw()


func reset() -> void:
	_accum = 0.0
	_ready_to_fire = true
	_fill = 0.0
	_cooldown = 0.0
	var hint := get_node_or_null("Hint") as Label
	if hint != null:
		hint.visible = false
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
		# Clients render hint + cooldown visuals; the server owns firing decisions.
		_update_hint()
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
				_cooldown = _cooldown_seconds()
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
	var hint := get_node_or_null("Hint") as Label
	if hint == null:
		return
	var show := false
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Player and candidate.active and not (candidate as Player).health.is_dead:
			if candidate.global_position.distance_to(global_position) <= HINT_RADIUS:
				show = true
				break
	if _cooldown > 0.0:
		hint.text = "%s\n(recharging…)" % _compose_hint()
	else:
		hint.text = "%s\nstand still" % _compose_hint()
	hint.visible = show


func _reset_after_cooldown() -> void:
	await get_tree().create_timer(_cooldown_seconds()).timeout
	if is_inside_tree():
		reset()


func _draw() -> void:
	var accent := _accent_fallback()
	var pad := _regular_polygon(Vector2.ZERO, STAND_RADIUS, 8)
	draw_colored_polygon(pad, Color(0.05, 0.06, 0.08, 0.82))
	draw_colored_polygon(_regular_polygon(Vector2.ZERO, STAND_RADIUS - 18.0, 8), Color(accent, 0.28))
	for index in 8:
		var a0 := TAU * float(index) / 8.0 + PI / 8.0
		var a1 := TAU * float(index + 1) / 8.0 + PI / 8.0
		draw_line(Vector2.from_angle(a0) * STAND_RADIUS, Vector2.from_angle(a1) * STAND_RADIUS, Color(accent, 0.7), 5.0)
	var pulse_t := fmod(_anim, 3.0) / 3.0
	draw_arc(Vector2.ZERO, BODY_RADIUS + 24.0 + pulse_t * 56.0, 0.0, TAU, 12, Color(accent, (1.0 - pulse_t) * 0.45), 3.0, false)
	if _cooldown > 0.0:
		var cd_frac := 1.0 - (_cooldown / _cooldown_seconds())
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + TAU * cd_frac, 16, Color(accent, 0.5), 6.0, false)
	elif _fill > 0.001 and _fill < 1.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, -PI / 2.0, -PI / 2.0 + TAU * _fill, 16, Color("fff0a0"), 8.0, false)
	elif _fill >= 1.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 18.0, 0.0, TAU, 16, Color("fff0a0"), 8.0, false)
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.visible = false
	_draw_role_letter(accent)


func _regular_polygon(center: Vector2, radius: float, facets: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := maxi(3, facets)
	for index in count:
		pts.append(center + Vector2.from_angle(TAU * float(index) / float(count) + PI / float(count)) * radius)
	return pts


func _draw_role_letter(accent: Color) -> void:
	var letter := "W"
	match effect_id:
		"heal_all":
			letter = "H"
		"freeze_time":
			letter = "F"
		"speed_surge":
			letter = "S"
		"phase_cloak":
			letter = "C"
		"battle_frenzy":
			letter = "R"
		_:
			letter = "W"
	var font := ThemeDB.fallback_font
	var size := 72
	var width := 120.0
	draw_string(font, Vector2(-width * 0.5, 28.0), letter, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0.02, 0.02, 0.03, 0.85))
	draw_string(font, Vector2(-width * 0.5, 24.0), letter, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(accent, 0.98))


func _compose_hint() -> String:
	match effect_id:
		"pulse_wipe":
			return "%s  ·  WIPE" % _hint
		"freeze_time":
			return "%s  ·  FREEZE" % _hint
		"heal_all":
			return "%s  ·  HEAL" % _hint
		"speed_surge":
			return "%s  ·  SPEED" % _hint
		"phase_cloak":
			return "%s  ·  CLOAK" % _hint
		"battle_frenzy":
			return "%s  ·  FRENZY" % _hint
		_:
			return _hint


func _wipe_verb() -> String:
	match sprite_name:
		"tw_factory_landmark_pylon":
			return "molten pulse wipes minions"
		"tw_volcano_landmark_arch":
			return "rift pulse wipes minions"
		"tw_docks_landmark_bell":
			return "verdant bell wipes minions"
		"tw_grass_landmark_bell":
			return "grove bell wipes minions"
		"tw_docks_landmark_lighthouse":
			return "storm pulse wipes minions"
		_:
			return "wiping minions"


func _freeze_verb() -> String:
	match sprite_name:
		"tw_factory_landmark_bay":
			return "quench-locks enemies"
		"tw_volcano_landmark_well":
			return "obsidian-locks enemies"
		"tw_ice_landmark_hollow":
			return "vines bind enemies"
		"tw_grass_landmark_stone":
			return "roots bind enemies"
		"tw_ice_landmark_glade":
			return "freezes enemies"
		_:
			return "freezes enemies"


func _heal_verb() -> String:
	match sprite_name:
		"tw_factory_landmark_vat":
			return "steam-heals the party"
		"tw_volcano_landmark_shrine":
			return "ember-heals the party"
		"tw_grass_landmark_pool":
			return "wild-heals the party"
		"tw_ice_landmark_hollow":
			return "frost-heals the party"
		"tw_docks_landmark_pool":
			return "spring-heals the party" if _hint == "Mana Spring" else "tide-heals the party"
		_:
			return "heals the party"


func _accent_fallback() -> Color:
	match sprite_name:
		"tw_factory_landmark_pylon":
			return Color("ff6a20")
		"tw_factory_landmark_vat":
			return Color("c8e8ee")
		"tw_factory_landmark_bay":
			return Color("7aa0c8")
		"tw_volcano_landmark_arch":
			return Color("c45cff")
		"tw_volcano_landmark_shrine":
			return Color("ff7a40")
		"tw_volcano_landmark_well":
			return Color("8ec8ff")
		"tw_docks_landmark_bell":
			return Color("8fd84a")
		"tw_grass_landmark_bell":
			return Color("8fd84a")
		"tw_grass_landmark_pool":
			return Color("7fd88a")
		"tw_grass_landmark_stone":
			return Color("6db86a")
		"tw_docks_landmark_pool":
			return Color("5ec8c0") if _hint == "Mana Spring" else Color("6ec8ff")
		"tw_ice_landmark_hollow":
			return Color("a8e0ff") if effect_id == "heal_all" else Color("6db86a")
		"tw_ice_landmark_glade":
			return Color("7db8ff")
		"tw_docks_landmark_lighthouse":
			return Color("f4c44a")
		"tw_factory_landmark_turbine":
			return Color("ffe066")
		"tw_volcano_landmark_totem":
			return Color("ff3020")
		"tw_grass_landmark_thicket":
			return Color("9a70ff")
		"tw_ice_landmark_rune":
			return Color("60e0ff")
	match effect_id:
		"pulse_wipe":
			return Color("f4c44a")
		"freeze_time":
			return Color("7db8ff")
		"heal_all":
			return Color("7fd88a")
		"speed_surge":
			return Color("ffe066")
		"phase_cloak":
			return Color("9a70ff")
		"battle_frenzy":
			return Color("ff3020")
		_:
			return Color("e8e8e8")

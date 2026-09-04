class_name WorldHealthBar
extends ProgressBar

@export var healthy_color := Color("45d483")
@export var warning_color := Color("f2bd4b")
@export var danger_color := Color("f05252")
@export_range(0.05, 0.5, 0.01) var danger_threshold := 0.25
@export_range(0.25, 0.9, 0.01) var healthy_threshold := 0.6
@export var secondary_color := Color("f5c542")

var fill_style: StyleBoxFlat
var secondary_bar: ProgressBar
var shield_bar: ProgressBar
var shield_fill: StyleBoxFlat


func _ready() -> void:
	var base_style := get_theme_stylebox("fill")
	if base_style is StyleBoxFlat:
		fill_style = base_style.duplicate() as StyleBoxFlat
	else:
		fill_style = StyleBoxFlat.new()
	add_theme_stylebox_override("fill", fill_style)
	fill_style.bg_color = healthy_color
	_make_secondary_bar()
	_make_shield_bar()


func _make_secondary_bar() -> void:
	secondary_bar = ProgressBar.new()
	secondary_bar.show_percentage = false
	secondary_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	secondary_bar.min_value = 0.0
	secondary_bar.max_value = 1.0
	secondary_bar.value = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.045, 0.06, 0.85)
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = secondary_color
	fill.set_corner_radius_all(2)
	secondary_bar.add_theme_stylebox_override("background", bg)
	secondary_bar.add_theme_stylebox_override("fill", fill)
	add_child(secondary_bar)
	secondary_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	secondary_bar.offset_left = 0.0
	secondary_bar.offset_right = 0.0
	secondary_bar.offset_top = -5.0
	secondary_bar.offset_bottom = -2.0


func _make_shield_bar() -> void:
	shield_bar = ProgressBar.new()
	shield_bar.show_percentage = false
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_bar.min_value = 0.0
	shield_bar.max_value = 1.0
	shield_bar.value = 1.0
	shield_bar.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12, 0.7)
	bg.set_corner_radius_all(2)
	shield_fill = StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.92, 0.94, 1.0, 1.0)
	shield_fill.set_corner_radius_all(2)
	shield_bar.add_theme_stylebox_override("background", bg)
	shield_bar.add_theme_stylebox_override("fill", shield_fill)
	add_child(shield_bar)
	shield_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shield_bar.offset_left = 0.0
	shield_bar.offset_right = 0.0
	shield_bar.offset_top = 2.0
	shield_bar.offset_bottom = 6.0


func set_identity_color(color: Color) -> void:
	healthy_color = color
	warning_color = color.lerp(Color("f2bd4b"), 0.28)
	danger_color = color.lerp(Color("f05252"), 0.45)
	if fill_style != null:
		fill_style.bg_color = healthy_color
	set_shield_color(color.lightened(0.22))


func set_shield_color(color: Color) -> void:
	if shield_fill != null:
		shield_fill.bg_color = color


func set_shield_active(on: bool) -> void:
	if shield_bar == null:
		return
	shield_bar.visible = on
	shield_bar.value = 1.0 if on else 0.0
	if not on:
		shield_bar.modulate.a = 1.0


func set_shield_flicker(show: bool) -> void:
	if shield_bar == null:
		return
	shield_bar.modulate.a = 1.0 if show else 0.12


func show_local_indicators(show: bool) -> void:
	if secondary_bar != null:
		secondary_bar.visible = show


func bind_health(health: HealthComponent) -> void:
	if not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func set_secondary_cooldown(remaining: float, cooldown_max: float) -> void:
	if secondary_bar == null:
		return
	var cap := maxf(0.01, cooldown_max)
	if remaining > 0.0:
		secondary_bar.value = clampf(remaining / cap, 0.0, 1.0)
		secondary_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		secondary_bar.value = 0.0
		secondary_bar.modulate = Color(1.0, 1.0, 1.0, 0.35)


func _on_health_changed(current_health: float, max_health: float) -> void:
	max_value = max_health
	value = current_health

	var ratio := 0.0
	if max_health > 0.0:
		ratio = clampf(current_health / max_health, 0.0, 1.0)

	if fill_style == null:
		return
	if ratio <= danger_threshold:
		fill_style.bg_color = danger_color
	elif ratio < healthy_threshold:
		var blend := inverse_lerp(danger_threshold, healthy_threshold, ratio)
		fill_style.bg_color = danger_color.lerp(warning_color, blend)
	else:
		var blend := inverse_lerp(healthy_threshold, 1.0, ratio)
		fill_style.bg_color = warning_color.lerp(healthy_color, blend)

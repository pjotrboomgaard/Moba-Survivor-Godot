class_name WorldHealthBar
extends ProgressBar

@export var healthy_color := Color("45d483")
@export var warning_color := Color("f2bd4b")
@export var danger_color := Color("f05252")
@export_range(0.05, 0.5, 0.01) var danger_threshold := 0.25
@export_range(0.25, 0.9, 0.01) var healthy_threshold := 0.6

var fill_style: StyleBoxFlat


func _ready() -> void:
	var base_style := get_theme_stylebox("fill")
	if base_style is StyleBoxFlat:
		fill_style = base_style.duplicate() as StyleBoxFlat
	else:
		fill_style = StyleBoxFlat.new()
	add_theme_stylebox_override("fill", fill_style)


func bind_health(health: HealthComponent) -> void:
	if not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current_health: float, max_health: float) -> void:
	max_value = max_health
	value = current_health

	var ratio := 0.0
	if max_health > 0.0:
		ratio = clampf(current_health / max_health, 0.0, 1.0)

	if ratio <= danger_threshold:
		fill_style.bg_color = danger_color
	elif ratio < healthy_threshold:
		var blend := inverse_lerp(danger_threshold, healthy_threshold, ratio)
		fill_style.bg_color = danger_color.lerp(warning_color, blend)
	else:
		var blend := inverse_lerp(healthy_threshold, 1.0, ratio)
		fill_style.bg_color = warning_color.lerp(healthy_color, blend)

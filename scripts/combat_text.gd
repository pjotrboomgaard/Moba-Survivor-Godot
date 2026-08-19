class_name CombatText
extends Node2D

@export var lifetime := 0.72
@export var rise_speed := 54.0

@onready var label: Label = $Label

var elapsed := 0.0


func setup(value: float, kind: String, critical: bool = false) -> void:
	var rounded_value := maxi(1, roundi(value))
	match kind:
		"heal":
			label.text = "+%d" % rounded_value
			label.modulate = Color("62e6a5")
		"xp":
			label.text = "+%d XP" % rounded_value
			label.modulate = Color("69f6bd")
		"taken":
			label.text = "-%d" % rounded_value
			label.modulate = Color("ff6b6b")
		_:
			label.text = "%d" % rounded_value
			label.modulate = Color("ffe17a") if critical else Color("eaf7ff")
	if critical:
		label.text += "!"
		label.add_theme_font_size_override("font_size", 25)
	else:
		label.add_theme_font_size_override("font_size", 18)


func _process(delta: float) -> void:
	elapsed += delta
	position.y -= rise_speed * delta
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - progress * progress
	if elapsed >= lifetime:
		queue_free()

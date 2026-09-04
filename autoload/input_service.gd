extends Node

enum InputMethod {
	KEYBOARD_MOUSE,
	CONTROLLER,
	TOUCH,
}

var current_method := InputMethod.KEYBOARD_MOUSE


func movement_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func primary_attack_held() -> bool:
	return Input.is_action_pressed("primary_attack")


func primary_attack_pressed() -> bool:
	return Input.is_action_just_pressed("primary_attack")


func secondary_attack_held() -> bool:
	return Input.is_action_pressed("secondary_attack")


func jump_pressed() -> bool:
	return Input.is_action_just_pressed("board_jump")


func ability_held() -> bool:
	return Input.is_action_pressed("ability")


const ABILITY_SLOT_ACTIONS := ["ability_1", "ability_2", "ability_3", "ability_4"]
var block_ability_slots := false


func ability_slot_held(slot: int) -> bool:
	if block_ability_slots:
		return false
	if slot < 0 or slot >= ABILITY_SLOT_ACTIONS.size():
		return false
	return Input.is_action_pressed(ABILITY_SLOT_ACTIONS[slot])


func aim_world_position(source: CanvasItem) -> Vector2:
	return source.get_global_mouse_position()


func set_virtual_movement(value: Vector2) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	if value.x < 0.0:
		Input.action_press("move_left", absf(value.x))
	elif value.x > 0.0:
		Input.action_press("move_right", value.x)
	if value.y < 0.0:
		Input.action_press("move_up", absf(value.y))
	elif value.y > 0.0:
		Input.action_press("move_down", value.y)
	current_method = InputMethod.TOUCH

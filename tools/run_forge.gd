extends SceneTree

func _init() -> void:
	var forge_script = load("res://tools/sprite_forge.gd")
	var forge = forge_script.new()
	var root = root
	root.add_child(forge)
	forge._ready()
	# _ready calls get_tree().quit() which we need to prevent
	# Instead, just call the write logic directly
	print("Forge init called")
	quit()

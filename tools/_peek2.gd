extends SceneTree
func _init() -> void:
	GameRuntime.biome_id = 0
	var a := Arena.new()
	a.name = "Arena"
	add_child(a)
	# Simulate frame so _ready fires.
	await process_frame
	print("Arena children:")
	for c in a.get_children():
		print("  ", c.name, " -> ", c.get_class())
	print("landmarks array size = ", a.landmarks.size())
	quit(0)

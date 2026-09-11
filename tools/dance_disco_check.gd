extends SceneTree

func _init() -> void:
	var base: GDScript = load("res://scripts/minigame_base.gd")
	print("base load: %s" % (base != null))
	var script: GDScript = load("res://scripts/minigame_dance_disco.gd")
	print("dance load: %s" % (script != null))
	if script != null:
		var inst = script.new()
		print("instantiated: %s" % (inst != null))
		if inst != null:
			print("duration: %f" % inst.DURATION)
			inst.queue_free()
	quit()

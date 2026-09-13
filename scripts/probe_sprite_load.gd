extends SceneTree

func _init() -> void:
	var names := ["arclight", "arclight_right", "arclight_left", "arclight_side", "arclight_back",
		"bulwark", "bulwark_right", "bulwark_left", "warden", "warden_right"]
	for n in names:
		var t: Texture2D = SpriteLibrary.texture_for(n)
		if t == null:
			print("[S] %-16s texture_for=null" % n)
		else:
			print("[S] %-16s texture_for=%dx%d path=%s" % [n, t.get_width(), t.get_height(), t.resource_path])
	quit(0)

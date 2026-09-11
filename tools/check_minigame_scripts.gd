extends SceneTree

func _init() -> void:
	var scripts := [
		"res://scripts/minigame_gem_relay.gd",
		"res://scripts/minigame_whack_rush.gd",
		"res://scripts/minigame_treasure_dash2.gd",
		"res://scripts/minigame_creep_tag.gd",
		"res://scripts/minigame_keg_toss_pro.gd",
	]
	for s in scripts:
		var res := load(s)
		if res == null:
			print("FAIL: %s (load returned null)" % s)
		elif res is GDScript and not res.can_instantiate():
			print("FAIL: %s (cannot instantiate)" % s)
		else:
			print("OK: %s" % s)
	quit()
